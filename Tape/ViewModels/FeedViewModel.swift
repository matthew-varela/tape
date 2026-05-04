import SwiftUI

/// Two distinct ways the feed can be presented:
///   - `.discover` — chronological/recommended scroll (default for everyone)
///   - `.search`   — filtered list driven by the FeedFilterSheet (recruiters)
enum FeedMode: String, CaseIterable {
    case discover = "For You"
    case search = "Search"
}

/// Drives the vertical-scrolling video feed. Two responsibilities:
///   1. Paginated data loading from the backend (10 items at a time).
///   2. Bookmark state for the signed-in user, persisted via the API with
///      an optimistic-UI pattern (mutate first, roll back on error).
@Observable
@MainActor
final class FeedViewModel {
    var videos: [Video] = []
    var filteredVideos: [Video] = []
    var feedMode: FeedMode = .discover
    var filters = FeedFilters()
    var isLoading = false
    var errorMessage: String?
    var currentIndex: Int = 0

    /// Set of video IDs the current user has bookmarked. Read-heavy, so we
    /// keep it as an in-memory set for O(1) lookups in `isBookmarked(_:)`.
    var bookmarkedVideoIDs: Set<String> = []

    private let videoService: VideoServiceProtocol
    private var currentPage = 0
    private var hasMorePages = true

    init(videoService: VideoServiceProtocol = MockVideoService()) {
        self.videoService = videoService
    }

    var displayedVideos: [Video] {
        feedMode == .discover ? videos : filteredVideos
    }

    // MARK: - Feed loading

    func loadInitialFeed() async {
        guard videos.isEmpty else { return }
        isLoading = true
        do {
            let fetched = try await videoService.fetchFeedVideos(page: 0)
            videos = fetched
            currentPage = 0
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard hasMorePages, !isLoading else { return }
        isLoading = true
        currentPage += 1
        do {
            let fetched = try await videoService.fetchFeedVideos(page: currentPage)
            if fetched.isEmpty {
                hasMorePages = false
            } else {
                videos.append(contentsOf: fetched)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func applyFilters() async {
        isLoading = true
        do {
            filteredVideos = try await videoService.fetchFilteredVideos(filters: filters)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Bookmarks

    /// Loads the user's saved videos from the backend. Called once on view
    /// appear so `isBookmarked()` returns the correct value as soon as cells
    /// render.
    func loadBookmarks(userID: String) async {
        do {
            let ids = try await videoService.fetchBookmarks(userID: userID)
            bookmarkedVideoIDs = Set(ids)
        } catch {
            // Swallow: an empty bookmark set is a fine fallback.
        }
    }

    /// Optimistic toggle: flip the bit locally, fire the network call, and
    /// roll back on error. This is the standard pattern for instant-feeling
    /// like/save UI without waiting on the round trip.
    func toggleBookmark(videoID: String, userID: String) async {
        let wasBookmarked = bookmarkedVideoIDs.contains(videoID)
        if wasBookmarked {
            bookmarkedVideoIDs.remove(videoID)
        } else {
            bookmarkedVideoIDs.insert(videoID)
        }

        do {
            if wasBookmarked {
                try await videoService.removeBookmark(userID: userID, videoID: videoID)
            } else {
                try await videoService.addBookmark(userID: userID, videoID: videoID)
            }
        } catch {
            // Rollback so the UI matches reality.
            if wasBookmarked {
                bookmarkedVideoIDs.insert(videoID)
            } else {
                bookmarkedVideoIDs.remove(videoID)
            }
            errorMessage = error.localizedDescription
        }
    }

    func isBookmarked(_ videoID: String) -> Bool {
        bookmarkedVideoIDs.contains(videoID)
    }
}
