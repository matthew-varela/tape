import FirebaseStorage
import UIKit
import UniformTypeIdentifiers

final class FirebaseStorageService: StorageServiceProtocol {
    private let storage = Storage.storage()

    func uploadVideo(
        fileURL: URL,
        athleteID: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard !athleteID.isEmpty else { throw StorageUploadError.missingOwner }
        try Self.validateLocalFile(at: fileURL)

        // Keep the real container extension. Clips picked from the library are
        // QuickTime (.mov); only trimmed exports are actually .mp4. Uploading a
        // .mov as "video/mp4" produces files that some players refuse to open.
        let ext = fileURL.pathExtension.isEmpty ? "mp4" : fileURL.pathExtension.lowercased()
        let ref = storage.reference().child("videos/\(athleteID)/\(UUID().uuidString).\(ext)")

        let metadata = StorageMetadata()
        metadata.contentType = Self.mimeType(forExtension: ext, fallback: "video/mp4")

        let task = ref.putFile(from: fileURL, metadata: metadata)
        return try await resolveDownloadURL(for: ref, task: task, onProgress: onProgress)
    }

    func uploadThumbnail(
        image: UIImage,
        athleteID: String
    ) async throws -> URL {
        guard !athleteID.isEmpty else { throw StorageUploadError.missingOwner }
        return try await uploadJPEG(
            image: image,
            path: "thumbnails/\(athleteID)/\(UUID().uuidString).jpg",
            quality: 0.75
        )
    }

    func uploadProfileImage(
        image: UIImage,
        userID: String
    ) async throws -> URL {
        guard !userID.isEmpty else { throw StorageUploadError.missingOwner }
        // Avatars get a slightly higher compression quality because they're
        // shown more prominently than thumbnails.
        return try await uploadJPEG(
            image: image,
            path: "profileImages/\(userID)/\(UUID().uuidString).jpg",
            quality: 0.85
        )
    }

    // MARK: - Helpers

    /// Shared JPEG upload routine. Encodes the image, writes it to the given
    /// storage path, then resolves the public download URL.
    private func uploadJPEG(
        image: UIImage,
        path: String,
        quality: CGFloat
    ) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StorageUploadError.thumbnailEncodingFailed
        }

        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let task = ref.putData(data, metadata: metadata)
        return try await resolveDownloadURL(for: ref, task: task, onProgress: nil)
    }

    /// Bridges a Firebase upload task into async/await and then resolves the
    /// object's download URL.
    ///
    /// `ResumeGuard` matters here: Firebase can deliver both a terminal state
    /// and a late duplicate, and resuming a checked continuation twice traps
    /// the process. The guard makes the first terminal event the only one.
    private func resolveDownloadURL(
        for ref: StorageReference,
        task: StorageUploadTask,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        let guardrail = ResumeGuard()
        let path = ref.fullPath

        return try await withCheckedThrowingContinuation { continuation in
            if let onProgress {
                task.observe(.progress) { snapshot in
                    guard let progress = snapshot.progress, progress.totalUnitCount > 0 else { return }
                    onProgress(Double(progress.completedUnitCount) / Double(progress.totalUnitCount))
                }
            }

            task.observe(.success) { _ in
                guard guardrail.claim() else { return }
                ref.downloadURL { url, error in
                    if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(
                            throwing: StorageUploadError.downloadURLFailed(path: path, underlying: error)
                        )
                    }
                }
            }

            task.observe(.failure) { snapshot in
                guard guardrail.claim() else { return }
                continuation.resume(
                    throwing: StorageUploadError.uploadFailed(path: path, underlying: snapshot.error)
                )
            }
        }
    }

    /// Fails fast when the clip we were handed is gone or empty. Without this
    /// the upload "succeeds" against a zero-byte body and the confusing error
    /// only shows up later when the object is read back.
    private static func validateLocalFile(at url: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw StorageUploadError.localFileMissing
        }
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else {
            throw StorageUploadError.localFileEmpty
        }
    }

    private static func mimeType(forExtension ext: String, fallback: String) -> String {
        UTType(filenameExtension: ext)?.preferredMIMEType ?? fallback
    }
}

/// Serializes the "who resumed the continuation" decision across Firebase's
/// callback queues.
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

enum StorageUploadError: LocalizedError {
    case missingOwner
    case localFileMissing
    case localFileEmpty
    case uploadFailed(path: String, underlying: Error?)
    case downloadURLFailed(path: String, underlying: Error?)
    case thumbnailEncodingFailed

    var errorDescription: String? {
        switch self {
        case .missingOwner:
            "You need to be signed in to upload. Please sign out and back in, then try again."
        case .localFileMissing:
            "That clip is no longer available on this device. Pick the video again."
        case .localFileEmpty:
            "That clip came through empty. Pick the video again."
        case .uploadFailed(let path, let underlying):
            Self.describe(underlying, path: path, whileUploading: true)
        case .downloadURLFailed(let path, let underlying):
            Self.describe(underlying, path: path, whileUploading: false)
        case .thumbnailEncodingFailed:
            "Failed to process the thumbnail image."
        }
    }

    /// Turns Firebase's terse Storage errors into something that points at the
    /// actual cause — nearly always Storage security rules or an unprovisioned
    /// bucket rather than anything the person using the app can fix.
    private static func describe(_ error: Error?, path: String, whileUploading: Bool) -> String {
        let stage = whileUploading ? "Upload failed" : "Upload finished but the file could not be read back"

        guard let nsError = error as NSError?, nsError.domain == StorageErrorDomain else {
            let detail = error?.localizedDescription ?? "Unknown error"
            return "\(stage) for “\(path)”. \(detail)"
        }

        switch StorageErrorCode(rawValue: nsError.code) {
        case .objectNotFound:
            return "\(stage): Firebase Storage reports no object at “\(path)”. Check that Storage is set up for this Firebase project and that its security rules let the signed-in user read and write this path."
        case .unauthorized, .unauthenticated:
            return "\(stage): Firebase Storage denied access to “\(path)”. Update your Storage security rules to allow the signed-in user to write to their own folder."
        case .bucketNotFound, .projectNotFound:
            return "\(stage): the Firebase Storage bucket in GoogleService-Info.plist doesn't exist. Enable Storage in the Firebase console and re-download the plist."
        case .quotaExceeded:
            return "\(stage): the Firebase Storage quota for this project is exhausted."
        case .retryLimitExceeded:
            return "\(stage): the connection was too slow to finish. Try again on a stronger network."
        default:
            return "\(stage) for “\(path)”. \(nsError.localizedDescription)"
        }
    }
}
