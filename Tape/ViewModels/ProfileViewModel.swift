import SwiftUI

/// `ProfileViewModel` powers the athlete profile screen. It loads the
/// athlete's record plus their videos (split by category) plus, when the
/// signed-in user is viewing their *own* profile, the list of recent
/// profile viewers.
///
/// Concurrency note: the three loads at view appear (`athlete`, `tape`,
/// `culture`) happen in parallel via `async let` — Swift fires the requests
/// simultaneously and `await`s them at the join point. This is roughly 3x
/// faster than awaiting each call sequentially.
@Observable
@MainActor
final class ProfileViewModel {
    var athlete: User?
    var tapeVideos: [Video] = []
    var cultureVideos: [Video] = []
    var savedVideos: [Video] = []
    var profileViewers: [User] = []
    var followCounts: FollowCounts = .empty
    /// Whether the signed-in recruiter has this athlete on their shortlist.
    var isAthleteSaved = false
    var isLoading = false
    var errorMessage: String?

    private let profileService: ProfileServiceProtocol
    private let videoService: VideoServiceProtocol
    private let followService: FollowServiceProtocol
    private let savedAthleteService: SavedAthleteServiceProtocol

    init(
        profileService: ProfileServiceProtocol = MockProfileService(),
        videoService: VideoServiceProtocol = MockVideoService(),
        followService: FollowServiceProtocol = MockFollowService(),
        savedAthleteService: SavedAthleteServiceProtocol = MockSavedAthleteService()
    ) {
        self.profileService = profileService
        self.videoService = videoService
        self.followService = followService
        self.savedAthleteService = savedAthleteService
    }

    func loadProfile(athleteID: String) async {
        isLoading = true
        do {
            async let fetchedAthlete = profileService.fetchAthlete(id: athleteID)
            async let fetchedTape = videoService.fetchVideos(for: athleteID, category: .tape)
            async let fetchedCulture = videoService.fetchVideos(for: athleteID, category: .culture)

            athlete = try await fetchedAthlete
            tapeVideos = sortPinnedFirst(try await fetchedTape)
            cultureVideos = sortPinnedFirst(try await fetchedCulture)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadFollowCounts(athleteID: String) async {
        do {
            followCounts = try await followService.fetchCounts(for: athleteID)
        } catch {
            // Swallow: the profile still renders without social counters.
        }
    }

    /// Optimistic follow toggle so the button flips instantly; the counter is
    /// adjusted alongside it and rolled back together on failure.
    func toggleFollow(athleteID: String) async {
        let previous = followCounts
        followCounts.isFollowing.toggle()
        followCounts.followers += followCounts.isFollowing ? 1 : -1

        do {
            if previous.isFollowing {
                try await followService.unfollow(athleteID)
            } else {
                try await followService.follow(athleteID)
            }
        } catch {
            followCounts = previous
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Saved

    /// Clips the signed-in user has bookmarked. Owner-only, so this is loaded
    /// lazily when the Saved tab is first opened.
    func loadSavedVideos(userID: String) async {
        guard savedVideos.isEmpty else { return }
        do {
            savedVideos = try await videoService.fetchBookmarkedVideos(userID: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshSavedVideos(userID: String) async {
        savedVideos = []
        await loadSavedVideos(userID: userID)
    }

    func loadSavedState(athleteID: String) async {
        let saved = (try? await savedAthleteService.fetchSavedAthletes()) ?? []
        isAthleteSaved = saved.contains { $0.id == athleteID }
    }

    /// Optimistic shortlist toggle, rolled back if the write fails.
    func toggleSavedAthlete(athleteID: String) async {
        let wasSaved = isAthleteSaved
        isAthleteSaved.toggle()
        do {
            if wasSaved {
                try await savedAthleteService.unsave(athleteID: athleteID)
            } else {
                try await savedAthleteService.save(athleteID: athleteID)
            }
        } catch {
            isAthleteSaved = wasSaved
            errorMessage = error.localizedDescription
        }
    }

    func loadProfileViewers(athleteID: String) async {
        do {
            profileViewers = try await profileService.fetchProfileViewers(for: athleteID)
        } catch {
            // Swallow: viewers list is a soft Pro feature; the count itself
            // comes back on the User record so the badge still renders.
        }
    }

    // MARK: - Pin / Unpin

    func pin(video: Video) async {
        do {
            try await videoService.pinVideo(videoID: video.id)
            applyPin(videoID: video.id, pinned: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unpin(video: Video) async {
        do {
            try await videoService.unpinVideo(videoID: video.id)
            applyPin(videoID: video.id, pinned: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func applyPin(videoID: String, pinned: Bool) {
        if let i = tapeVideos.firstIndex(where: { $0.id == videoID }) {
            tapeVideos[i].isPinned = pinned
            tapeVideos = sortPinnedFirst(tapeVideos)
        }
        if let i = cultureVideos.firstIndex(where: { $0.id == videoID }) {
            cultureVideos[i].isPinned = pinned
            cultureVideos = sortPinnedFirst(cultureVideos)
        }
    }

    private func sortPinnedFirst(_ videos: [Video]) -> [Video] {
        videos.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
