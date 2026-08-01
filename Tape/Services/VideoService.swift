import Foundation

/// `VideoServiceProtocol` is the contract for everything related to video
/// records: feeds, profile sections, search, publish, bookmarks, and pins.
///
/// All methods are `async throws` so call sites can present spinners and
/// surface errors. Implementations live alongside other service families:
///   - `MockVideoService`  (in-memory, for tests/previews)
///   - `APIVideoService`   (production REST calls)
protocol VideoServiceProtocol {
    func fetchFeedVideos(page: Int) async throws -> [Video]

    /// Feed limited to athletes the signed-in user follows. Returns an empty
    /// page when they follow nobody.
    func fetchFollowingFeedVideos(page: Int) async throws -> [Video]

    /// Records one play. Counted per play, not per unique viewer.
    func recordView(videoID: String) async throws

    /// Single clip by id. Backs shared links, where all the recipient has is
    /// the video id. Throws if the clip was deleted or its athlete is blocked.
    func fetchVideo(id: String) async throws -> Video

    func fetchVideos(for athleteID: String) async throws -> [Video]
    func fetchVideos(for athleteID: String, category: VideoCategory) async throws -> [Video]
    func fetchFilteredVideos(filters: FeedFilters) async throws -> [Video]
    func publishVideo(_ video: Video) async throws

    // MARK: Bookmarks (per-user)
    /// Returns the list of video IDs the user has saved.
    func fetchBookmarks(userID: String) async throws -> [String]

    /// Full records for the user's saved clips, newest save first, so the
    /// profile's Saved tab can render a grid directly.
    func fetchBookmarkedVideos(userID: String) async throws -> [Video]

    /// Persists a bookmark.
    func addBookmark(userID: String, videoID: String) async throws

    /// Removes a bookmark.
    func removeBookmark(userID: String, videoID: String) async throws

    // MARK: Pins (athlete chooses one or more clips to feature)
    /// Pins the given video to the top of the athlete's profile grid.
    func pinVideo(videoID: String) async throws

    /// Removes the pin.
    func unpinVideo(videoID: String) async throws
}

/// Used by the recruiter "search the feed" flow on `/api/videos/search`. Each
/// optional field becomes a query parameter.
struct FeedFilters: Equatable {
    var position: String?
    var state: String?
    var minHeight: String?
    var minGPA: Double?
    var sport: String?
    var gradYear: Int?
}

// MARK: - MockVideoService

/// In-memory implementation. Used by previews and unit tests. Bookmarks and
/// pin state are tracked in dictionaries scoped to this instance.
final class MockVideoService: VideoServiceProtocol {
    private var videos = MockData.videos
    private var bookmarks: [String: Set<String>] = [:]

    func fetchFeedVideos(page: Int) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(300))
        let pageSize = 10
        let start = page * pageSize
        guard start < videos.count else { return [] }
        let end = min(start + pageSize, videos.count)
        return Array(videos[start..<end])
    }

    func fetchFollowingFeedVideos(page: Int) async throws -> [Video] {
        try await fetchFeedVideos(page: page)
    }

    func recordView(videoID: String) async throws {
        try await Task.sleep(for: .milliseconds(40))
        if let i = videos.firstIndex(where: { $0.id == videoID }) {
            videos[i].viewCount += 1
        }
    }

    func fetchVideo(id: String) async throws -> Video {
        try await Task.sleep(for: .milliseconds(120))
        guard let video = videos.first(where: { $0.id == id }) else {
            throw NSError(
                domain: "MockVideoService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Video not found"]
            )
        }
        return video
    }

    func fetchVideos(for athleteID: String) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(200))
        return videos.filter { $0.athleteID == athleteID }
    }

    func fetchVideos(for athleteID: String, category: VideoCategory) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(200))
        return videos.filter { $0.athleteID == athleteID && $0.category == category }
    }

    func fetchFilteredVideos(filters: FeedFilters) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(300))
        let matchingAthleteIDs = Set(MockData.athletes.filter { athlete in
            if let pos = filters.position, !pos.isEmpty, athlete.position != pos { return false }
            if let st = filters.state, !st.isEmpty, athlete.state != st { return false }
            if let gpa = filters.minGPA, (athlete.gpa ?? 0) < gpa { return false }
            if let sport = filters.sport, !sport.isEmpty, athlete.sport != sport { return false }
            if let year = filters.gradYear, athlete.gradYear != year { return false }
            return true
        }.map(\.id))

        return videos.filter { matchingAthleteIDs.contains($0.athleteID) }
    }

    func publishVideo(_ video: Video) async throws {
        try await Task.sleep(for: .milliseconds(500))
        videos.insert(video, at: 0)
    }

    func fetchBookmarks(userID: String) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(100))
        return Array(bookmarks[userID] ?? [])
    }

    func fetchBookmarkedVideos(userID: String) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(100))
        let saved = bookmarks[userID] ?? []
        return videos.filter { saved.contains($0.id) }
    }

    func addBookmark(userID: String, videoID: String) async throws {
        try await Task.sleep(for: .milliseconds(80))
        bookmarks[userID, default: []].insert(videoID)
    }

    func removeBookmark(userID: String, videoID: String) async throws {
        try await Task.sleep(for: .milliseconds(80))
        bookmarks[userID]?.remove(videoID)
    }

    func pinVideo(videoID: String) async throws {
        try await Task.sleep(for: .milliseconds(80))
        if let i = videos.firstIndex(where: { $0.id == videoID }) {
            videos[i].isPinned = true
        }
    }

    func unpinVideo(videoID: String) async throws {
        try await Task.sleep(for: .milliseconds(80))
        if let i = videos.firstIndex(where: { $0.id == videoID }) {
            videos[i].isPinned = false
        }
    }
}
