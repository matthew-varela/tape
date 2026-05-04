import AVFoundation
import PhotosUI
import SwiftUI

/// `UploadPhase` is the user-facing label for the current upload step. The
/// publishing overlay shows the raw value as a status string so the user
/// always knows what the app is doing — much more reassuring during a 30s
/// upload than a generic spinner.
enum UploadPhase: String {
    case idle = ""
    case trimming = "Trimming clip…"
    case uploadingVideo = "Uploading video…"
    case generatingThumbnail = "Processing thumbnail…"
    case uploadingThumbnail = "Uploading thumbnail…"
    case publishing = "Saving highlight…"
}

/// `UploadViewModel` orchestrates the full publish pipeline:
///
///   1. PhotosPicker hands us a temporary file URL → `processSelectedVideo`.
///   2. Optional trim via `AVAssetExportSession` (clips longer than 15s).
///   3. Upload the video file to Firebase Storage with progress callbacks.
///   4. Generate a high-resolution thumbnail at the trim midpoint.
///   5. Upload the thumbnail.
///   6. POST the metadata to the backend.
///   7. Delete the temp file.
///
/// `uploadProgress` is normalized to 0..1 across *all* steps, so the
/// `PublishingOverlay` shows a single contiguous progress bar instead of
/// several jumpy ones. The mapping is: video upload 0–0.80, thumbnail upload
/// 0.82–0.95, backend POST 0.95–1.0.
///
/// Cancellation: tapping the overlay's Cancel calls `cancelUpload()`, which
/// cancels the in-flight Task. Firebase Storage uploads are not currently
/// cancelled mid-stream — that's a follow-up enhancement.
@Observable
@MainActor
final class UploadViewModel {
    var selectedVideoURL: URL?
    var videoDuration: Double = 0
    var trimStart: Double = 0
    var trimEnd: Double = 15
    var needsTrimming: Bool = false
    var selectedCategory: VideoCategory = .tape
    var selectedTags: Set<String> = []
    var caption: String = ""
    var isPublishing = false
    var isPublished = false
    var errorMessage: String?
    var thumbnailImages: [UIImage] = []
    var uploadProgress: Double = 0
    var uploadPhase: UploadPhase = .idle

    private let videoService: VideoServiceProtocol
    private let storageService: StorageServiceProtocol
    private var uploadTask: Task<Void, Never>?

    init(
        videoService: VideoServiceProtocol = MockVideoService(),
        storageService: StorageServiceProtocol = MockStorageService()
    ) {
        self.videoService = videoService
        self.storageService = storageService
    }

    func processSelectedVideo(url: URL) async {
        selectedVideoURL = url
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            videoDuration = CMTimeGetSeconds(duration)
            needsTrimming = videoDuration > 15
            trimStart = 0
            trimEnd = min(15, videoDuration)
            await generateThumbnails(asset: asset)
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
        }
    }

    private func generateThumbnails(asset: AVAsset) async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 200)

        let duration = videoDuration
        let count = min(Int(duration * 2), 20)
        var images: [UIImage] = []

        for i in 0..<count {
            let time = CMTime(seconds: duration * Double(i) / Double(max(count, 1)), preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                images.append(UIImage(cgImage: cgImage))
            } catch {
                continue
            }
        }
        thumbnailImages = images
    }

    func trimAndExport() async -> URL? {
        guard let sourceURL = selectedVideoURL else { return nil }
        let asset = AVURLAsset(url: sourceURL)

        let startTime = CMTime(seconds: trimStart, preferredTimescale: 600)
        let endTime = CMTime(seconds: trimEnd, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            errorMessage = "Failed to create export session"
            return nil
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        } else {
            errorMessage = "Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")"
            return nil
        }
    }

    // MARK: - Thumbnail generation for upload

    private func generateUploadThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 1280)

        let midpoint: Double
        if needsTrimming {
            midpoint = (trimEnd - trimStart) / 2.0
        } else {
            midpoint = videoDuration / 2.0
        }
        let time = CMTime(seconds: max(0, midpoint), preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    // MARK: - Publish

    func publish(currentUser: User) async {
        isPublishing = true
        uploadProgress = 0
        errorMessage = nil

        defer {
            isPublishing = false
            uploadPhase = .idle
        }

        var exportedURL: URL?

        // Step 1: trim if needed
        if needsTrimming {
            uploadPhase = .trimming
            guard let trimmed = await trimAndExport() else { return }
            exportedURL = trimmed
        } else {
            exportedURL = selectedVideoURL
        }

        guard let videoFileURL = exportedURL else {
            errorMessage = "No video to publish."
            return
        }

        var videoDownloadURL: URL
        var thumbnailDownloadURL: URL?

        do {
            // Step 2: upload video to Firebase Storage (progress 0–0.80)
            uploadPhase = .uploadingVideo
            videoDownloadURL = try await storageService.uploadVideo(
                fileURL: videoFileURL,
                athleteID: currentUser.id
            ) { [weak self] fraction in
                Task { @MainActor [weak self] in
                    self?.uploadProgress = fraction * 0.80
                }
            }

            // Step 3: generate thumbnail
            uploadPhase = .generatingThumbnail
            uploadProgress = 0.82
            let thumbImage = await generateUploadThumbnail(from: videoFileURL)

            // Step 4: upload thumbnail to Firebase Storage (progress 0.82–0.95)
            if let image = thumbImage {
                uploadPhase = .uploadingThumbnail
                thumbnailDownloadURL = try await storageService.uploadThumbnail(
                    image: image,
                    athleteID: currentUser.id
                )
                uploadProgress = 0.95
            }

            // Step 5: persist via backend API
            uploadPhase = .publishing
            let video = Video(
                athleteID: currentUser.id,
                videoURL: videoDownloadURL.absoluteString,
                thumbnailURL: thumbnailDownloadURL?.absoluteString,
                category: selectedCategory,
                tags: Array(selectedTags),
                caption: caption,
                athleteName: currentUser.displayName,
                athleteSchool: currentUser.highSchool ?? "",
                athleteGradYear: currentUser.gradYear ?? 2026,
                athletePosition: currentUser.position ?? "",
                athleteProfileImageURL: currentUser.profileImageURL
            )
            try await videoService.publishVideo(video)
            uploadProgress = 1.0

            // Step 6: clean up temp files
            deleteTempFile(at: videoFileURL)

            isPublished = true
            reset()

        } catch {
            errorMessage = error.localizedDescription
            deleteTempFile(at: videoFileURL)
        }
    }

    func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil
        isPublishing = false
        uploadProgress = 0
        uploadPhase = .idle
        errorMessage = nil
    }

    func reset() {
        selectedVideoURL = nil
        videoDuration = 0
        trimStart = 0
        trimEnd = 15
        needsTrimming = false
        selectedTags = []
        caption = ""
        thumbnailImages = []
        uploadProgress = 0
        uploadPhase = .idle
        errorMessage = nil
    }

    // MARK: - Private helpers

    private func deleteTempFile(at url: URL) {
        guard url.path.contains(FileManager.default.temporaryDirectory.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
