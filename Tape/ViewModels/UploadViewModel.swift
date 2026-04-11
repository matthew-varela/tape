import AVFoundation
import PhotosUI
import SwiftUI

@Observable
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

    private let videoService: VideoServiceProtocol

    init(videoService: VideoServiceProtocol = MockVideoService()) {
        self.videoService = videoService
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
            let time = CMTime(seconds: duration * Double(i) / Double(count), preferredTimescale: 600)
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

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            errorMessage = "Failed to create export session"
            return nil
        }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
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

    func publish(currentUser: User) async {
        isPublishing = true
        defer { isPublishing = false }

        var finalURL = selectedVideoURL
        if needsTrimming {
            finalURL = await trimAndExport()
        }

        guard let url = finalURL else {
            errorMessage = "No video to publish"
            return
        }

        let video = Video(
            athleteID: currentUser.id,
            videoURL: url.absoluteString,
            category: selectedCategory,
            tags: Array(selectedTags),
            caption: caption,
            athleteName: currentUser.displayName,
            athleteSchool: currentUser.highSchool ?? "",
            athleteGradYear: currentUser.gradYear ?? 2026,
            athletePosition: currentUser.position ?? "",
            athleteProfileImageURL: currentUser.profileImageURL
        )

        do {
            try await videoService.publishVideo(video)
            isPublished = true
            reset()
        } catch {
            errorMessage = error.localizedDescription
        }
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
    }
}
