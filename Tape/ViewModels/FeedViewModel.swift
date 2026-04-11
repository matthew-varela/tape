import SwiftUI

enum FeedMode: String, CaseIterable {
    case discover = "For You"
    case search = "Search"
}

@Observable
final class FeedViewModel {
    var videos: [Video] = []
    var filteredVideos: [Video] = []
    var feedMode: FeedMode = .discover
    var filters = FeedFilters()
    var isLoading = false
    var errorMessage: String?
    var currentIndex: Int = 0
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

    func toggleBookmark(videoID: String) {
        if bookmarkedVideoIDs.contains(videoID) {
            bookmarkedVideoIDs.remove(videoID)
        } else {
            bookmarkedVideoIDs.insert(videoID)
        }
    }

    func isBookmarked(_ videoID: String) -> Bool {
        bookmarkedVideoIDs.contains(videoID)
    }
}
