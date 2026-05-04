import UIKit

/// Abstraction for object storage. In production this is `FirebaseStorageService`
/// which uses the Firebase Storage SDK to put bytes in our Google Cloud Storage
/// bucket and returns a public download URL. In previews/tests we use
/// `MockStorageService` to return synthetic URLs without a network round trip.
protocol StorageServiceProtocol {
    /// Uploads a video file (already on disk) and reports progress between 0
    /// and 1 via the callback. Returns the public HTTPS URL the backend should
    /// store on the Video record.
    func uploadVideo(
        fileURL: URL,
        athleteID: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL

    /// Uploads a single thumbnail JPEG. Returns the public HTTPS URL.
    func uploadThumbnail(
        image: UIKit.UIImage,
        athleteID: String
    ) async throws -> URL

    /// Uploads a profile avatar JPEG. Path: `profileImages/{userID}/{uuid}.jpg`.
    /// We re-upload to a new UUID rather than overwriting so CDN caches and
    /// SwiftUI image caches don't keep serving the old picture.
    func uploadProfileImage(
        image: UIKit.UIImage,
        userID: String
    ) async throws -> URL
}

final class MockStorageService: StorageServiceProtocol {
    func uploadVideo(
        fileURL: URL,
        athleteID: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        for i in 1...10 {
            try await Task.sleep(for: .milliseconds(80))
            onProgress(Double(i) / 10.0)
        }
        return URL(string: "https://example.com/videos/\(athleteID)/mock.mp4")!
    }

    func uploadThumbnail(
        image: UIKit.UIImage,
        athleteID: String
    ) async throws -> URL {
        try await Task.sleep(for: .milliseconds(200))
        return URL(string: "https://example.com/thumbnails/\(athleteID)/mock.jpg")!
    }

    func uploadProfileImage(
        image: UIKit.UIImage,
        userID: String
    ) async throws -> URL {
        try await Task.sleep(for: .milliseconds(200))
        return URL(string: "https://example.com/profileImages/\(userID)/mock.jpg")!
    }
}
