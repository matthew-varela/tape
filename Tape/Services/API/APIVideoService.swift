import Foundation

/// REST implementation of `VideoServiceProtocol`. All paths and shapes are
/// documented in `BACKEND_CONTRACT.md`.
final class APIVideoService: VideoServiceProtocol {
    private let client = APIClient.shared

    // MARK: - Reads

    func fetchFeedVideos(page: Int) async throws -> [Video] {
        try await client.get("/api/videos/feed", query: [
            "page": String(page),
            "size": "10"
        ])
    }

    func fetchFollowingFeedVideos(page: Int) async throws -> [Video] {
        try await client.get("/api/videos/feed/following", query: [
            "page": String(page),
            "size": "10"
        ])
    }

    func recordView(videoID: String) async throws {
        struct Empty: Encodable {}
        try await client.postVoid("/api/videos/\(videoID)/view", body: Empty())
    }

    func fetchVideo(id: String) async throws -> Video {
        try await client.get("/api/videos/\(id)")
    }

    func fetchVideos(for athleteID: String) async throws -> [Video] {
        try await client.get("/api/videos", query: ["athleteId": athleteID])
    }

    func fetchVideos(for athleteID: String, category: VideoCategory) async throws -> [Video] {
        let categoryValue: String
        switch category {
        case .tape: categoryValue = "TAPE"
        case .culture: categoryValue = "CULTURE"
        }
        return try await client.get("/api/videos", query: [
            "athleteId": athleteID,
            "category": categoryValue
        ])
    }

    func fetchFilteredVideos(filters: FeedFilters) async throws -> [Video] {
        var query: [String: String] = [:]
        if let position = filters.position, !position.isEmpty { query["position"] = position }
        if let state = filters.state, !state.isEmpty { query["state"] = state }
        if let sport = filters.sport, !sport.isEmpty { query["sport"] = sport }
        if let gradYear = filters.gradYear { query["gradYear"] = String(gradYear) }
        if let minGPA = filters.minGPA { query["minGpa"] = String(minGPA) }
        return try await client.get("/api/videos/search", query: query)
    }

    // MARK: - Publish

    func publishVideo(_ video: Video) async throws {
        struct PublishBody: Encodable {
            let athleteId: String
            let videoUrl: String
            let thumbnailUrl: String?
            let category: String
            let tags: [String]
            let caption: String
        }

        let categoryValue: String
        switch video.category {
        case .tape: categoryValue = "TAPE"
        case .culture: categoryValue = "CULTURE"
        }

        let body = PublishBody(
            athleteId: video.athleteID,
            videoUrl: video.videoURL,
            thumbnailUrl: video.thumbnailURL,
            category: categoryValue,
            tags: video.tags,
            caption: video.caption
        )

        let _: Video = try await client.post("/api/videos", body: body)
    }

    // MARK: - Bookmarks

    func fetchBookmarks(userID: String) async throws -> [String] {
        struct Wrapper: Decodable { let videoIds: [String] }
        let wrapped: Wrapper = try await client.get("/api/users/\(userID)/bookmarks")
        return wrapped.videoIds
    }

    func fetchBookmarkedVideos(userID: String) async throws -> [Video] {
        try await client.get("/api/users/\(userID)/bookmarks/videos")
    }

    func addBookmark(userID: String, videoID: String) async throws {
        struct Body: Encodable { let videoId: String }
        try await client.postVoid(
            "/api/users/\(userID)/bookmarks",
            body: Body(videoId: videoID)
        )
    }

    func removeBookmark(userID: String, videoID: String) async throws {
        try await client.deleteVoid("/api/users/\(userID)/bookmarks/\(videoID)")
    }

    // MARK: - Pin / Unpin

    func pinVideo(videoID: String) async throws {
        let _: Video = try await client.putEmpty("/api/videos/\(videoID)/pin")
    }

    func unpinVideo(videoID: String) async throws {
        let _: Video = try await client.putEmpty("/api/videos/\(videoID)/unpin")
    }
}
