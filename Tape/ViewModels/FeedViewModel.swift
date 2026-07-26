import SwiftUI

/// The three ways the feed can be presented:
///   - `.discover`  — everything, newest first (default for everyone)
///   - `.following` — only athletes the signed-in user follows
///   - `.search`    — filtered list driven by the FeedFilterSheet (recruiters)
enum FeedMode: String, CaseIterable {
    case discover = "For You"
    case following = "Following"
    case search = "Search"
}

/// Drives the vertical-scrolling video feed:
///   1. Paginated data loading from the backend (10 items at a time) for the
///      discover and following streams, tracked independently so switching
///      tabs doesn't discard either one's scroll position.
///   2. Bookmark and follow state for the signed-in user, persisted via the
///      API with an optimistic-UI pattern (mutate first, roll back on error).
///   3. One-per-session view counting.
@Observable
@MainActor
final class FeedViewModel {
    var videos: [Video] = []
    var followingVideos: [Video] = []
    var filteredVideos: [Video] = []
    var feedMode: FeedMode = .discover
    var filters = FeedFilters()
    var isLoading = false
    var errorMessage: String?
    var currentIndex: Int = 0

    /// Set of video IDs the current user has bookmarked. Read-heavy, so we
    /// keep it as an in-memory set for O(1) lookups in `isBookmarked(_:)`.
    var bookmarkedVideoIDs: Set<String> = []

    /// IDs of athletes the signed-in user follows.
    var followingUserIDs: Set<String> = []

    private let videoService: VideoServiceProtocol
    private let followService: FollowServiceProtocol

    private var discoverPage = 0
    private var discoverHasMore = true
    private var followingPage = 0
    private var followingHasMore = true

    private static let pageSize = 10

    init(
        videoService: VideoServiceProtocol = MockVideoService(),
        followService: FollowServiceProtocol = MockFollowService()
    ) {
        self.videoService = videoService
        self.followService = followService
    }

    var displayedVideos: [Video] {
        switch feedMode {
        case .discover: videos
        case .following: followingVideos
        case .search: filteredVideos
        }
    }

    // MARK: - Feed loading

    func loadInitialFeed() async {
        guard videos.isEmpty else { return }
        isLoading = true
        do {
            videos = try await videoService.fetchFeedVideos(page: 0)
            discoverPage = 0
            discoverHasMore = videos.count >= Self.pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadFollowingFeed() async {
        guard followingVideos.isEmpty else { return }
        isLoading = true
        do {
            followingVideos = try await videoService.fetchFollowingFeedVideos(page: 0)
            followingPage = 0
            followingHasMore = followingVideos.count >= Self.pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Appends the next page for whichever stream is on screen.
    ///
    /// The page cursor only advances on success, so a dropped request retries
    /// the same page instead of skipping past it — the bug that used to make
    /// clips disappear from the feed after a flaky response.
    func loadNextPage() async {
        guard !isLoading else { return }

        switch feedMode {
        case .discover:
            guard discoverHasMore else { return }
            isLoading = true
            do {
                let next = discoverPage + 1
                let fetched = try await videoService.fetchFeedVideos(page: next)
                discoverPage = next
                discoverHasMore = fetched.count >= Self.pageSize
                videos = merge(fetched, into: videos)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false

        case .following:
            guard followingHasMore else { return }
            isLoading = true
            do {
                let next = followingPage + 1
                let fetched = try await videoService.fetchFollowingFeedVideos(page: next)
                followingPage = next
                followingHasMore = fetched.count >= Self.pageSize
                followingVideos = merge(fetched, into: followingVideos)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false

        case .search:
            // Filtered results come back as one complete list.
            return
        }
    }

    /// Full reload of the current stream. Backs pull-to-refresh and the
    /// post-upload refresh so a clip you just published shows up immediately.
    func refresh() async {
        switch feedMode {
        case .discover:
            discoverPage = 0
            discoverHasMore = true
            videos = []
            await loadInitialFeed()
        case .following:
            followingPage = 0
            followingHasMore = true
            followingVideos = []
            await loadFollowingFeed()
        case .search:
            await applyFilters()
        }
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

    /// Appends only clips we don't already have. The backend orders by
    /// `createdAt`, so a clip published mid-scroll can shift pages and repeat;
    /// deduplicating by ID keeps SwiftUI's `ForEach` identity stable.
    private func merge(_ fetched: [Video], into existing: [Video]) -> [Video] {
        let known = Set(existing.map(\.id))
        return existing + fetched.filter { !known.contains($0.id) }
    }

    // MARK: - View counting

    /// Counts one play. Views are not deduplicated by viewer — watching the
    /// same clip ten times is ten views, the way play counts work everywhere
    /// else. Failures are swallowed; a missed analytics ping should never
    /// interrupt playback.
    func recordView(_ video: Video) async {
        bumpViewCount(for: video.id)
        do {
            try await videoService.recordView(videoID: video.id)
        } catch {
            // Non-fatal.
        }
    }

    private func bumpViewCount(for videoID: String) {
        if let i = videos.firstIndex(where: { $0.id == videoID }) { videos[i].viewCount += 1 }
        if let i = followingVideos.firstIndex(where: { $0.id == videoID }) { followingVideos[i].viewCount += 1 }
        if let i = filteredVideos.firstIndex(where: { $0.id == videoID }) { filteredVideos[i].viewCount += 1 }
    }

    // MARK: - Following

    func loadFollowing() async {
        do {
            followingUserIDs = Set(try await followService.fetchFollowingIDs())
        } catch {
            // Swallow: an empty set is a fine fallback.
        }
    }

    func isFollowing(_ userID: String) -> Bool {
        followingUserIDs.contains(userID)
    }

    /// Optimistic follow toggle. On success the following stream is invalidated
    /// so it reflects the new set the next time that tab is opened.
    func toggleFollow(userID: String) async {
        let wasFollowing = followingUserIDs.contains(userID)
        if wasFollowing {
            followingUserIDs.remove(userID)
        } else {
            followingUserIDs.insert(userID)
        }

        do {
            if wasFollowing {
                try await followService.unfollow(userID)
            } else {
                try await followService.follow(userID)
            }
            invalidateFollowingFeed()
        } catch {
            if wasFollowing {
                followingUserIDs.insert(userID)
            } else {
                followingUserIDs.remove(userID)
            }
            errorMessage = error.localizedDescription
        }
    }

    private func invalidateFollowingFeed() {
        followingVideos = []
        followingPage = 0
        followingHasMore = true
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

    // MARK: - Moderation

    /// Removes all of an athlete's videos from the in-memory feed for instant
    /// feedback after blocking. The server also filters blocked users, so a
    /// subsequent reload stays consistent.
    func hideAthlete(_ athleteID: String) {
        videos.removeAll { $0.athleteID == athleteID }
        followingVideos.removeAll { $0.athleteID == athleteID }
        filteredVideos.removeAll { $0.athleteID == athleteID }
    }
}
