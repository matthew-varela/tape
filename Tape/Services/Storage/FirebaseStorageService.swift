import FirebaseStorage
import UIKit

final class FirebaseStorageService: StorageServiceProtocol {
    private let storage = Storage.storage()

    func uploadVideo(
        fileURL: URL,
        athleteID: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let filename = "\(UUID().uuidString).mp4"
        let ref = storage.reference().child("videos/\(athleteID)/\(filename)")

        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"

        return try await withCheckedThrowingContinuation { continuation in
            let task = ref.putFile(from: fileURL, metadata: metadata)

            task.observe(.progress) { snapshot in
                guard let progress = snapshot.progress, progress.totalUnitCount > 0 else { return }
                let fraction = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                onProgress(fraction)
            }

            task.observe(.success) { _ in
                ref.downloadURL { url, error in
                    if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: error ?? StorageUploadError.downloadURLFailed)
                    }
                }
            }

            task.observe(.failure) { snapshot in
                continuation.resume(throwing: snapshot.error ?? StorageUploadError.uploadFailed)
            }
        }
    }

    func uploadThumbnail(
        image: UIImage,
        athleteID: String
    ) async throws -> URL {
        try await uploadJPEG(
            image: image,
            path: "thumbnails/\(athleteID)/\(UUID().uuidString).jpg",
            quality: 0.75
        )
    }

    func uploadProfileImage(
        image: UIImage,
        userID: String
    ) async throws -> URL {
        // Avatars get a slightly higher compression quality because they're
        // shown more prominently than thumbnails.
        try await uploadJPEG(
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

        return try await withCheckedThrowingContinuation { continuation in
            let task = ref.putData(data, metadata: metadata)

            task.observe(.success) { _ in
                ref.downloadURL { url, error in
                    if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: error ?? StorageUploadError.downloadURLFailed)
                    }
                }
            }

            task.observe(.failure) { snapshot in
                continuation.resume(throwing: snapshot.error ?? StorageUploadError.uploadFailed)
            }
        }
    }
}

enum StorageUploadError: LocalizedError {
    case uploadFailed
    case downloadURLFailed
    case thumbnailEncodingFailed

    var errorDescription: String? {
        switch self {
        case .uploadFailed: "The upload failed. Please check your connection and try again."
        case .downloadURLFailed: "Could not retrieve the upload URL. Please try again."
        case .thumbnailEncodingFailed: "Failed to process the thumbnail image."
        }
    }
}
