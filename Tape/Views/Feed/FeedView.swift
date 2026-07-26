import Combine
import SwiftUI

/// `FeedView` is the vertical-paging video feed (TikTok-style). Everyone gets
/// a "For You" and a "Following" stream; recruiters/brands can additionally
/// toggle into a filtered search stream. Bookmarking, following, sharing, and
/// profile navigation all live on the `VideoOverlayView` floating on top of
/// each player.
///
/// Two pieces of state on this view that are easy to confuse:
///   - `feedVM` owns the data (videos, filters, bookmarks, follows).
///   - `playerManager` owns AVPlayer instances plus the shared mute and
///     play/pause state, and ensures only the visible cell is playing.
struct FeedView: View {
    let currentUser: User
    @State private var feedVM = FeedViewModel(
        videoService: APIVideoService(),
        followService: APIFollowService()
    )
    @State private var playerManager = VideoPlayerManager()
    /// The clip the scroll view is currently settled on. Source of truth for
    /// which player is allowed to run.
    @State private var visibleVideoID: String?
    @State private var showFilters = false
    @State private var showPaywall = false
    @State private var navigateToProfile: String?
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    // Moderation
    private let moderationService = APIModerationService()
    @State private var reportTargetVideo: Video?
    @State private var blockTargetVideo: Video?
    @State private var showReportConfirmation = false

    /// Recruiters and brands get the extra filtered-search stream; athletes
    /// only ever see the two social streams.
    private var availableModes: [FeedMode] {
        currentUser.role == .athlete
            ? [.discover, .following]
            : FeedMode.allCases
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                if feedVM.isLoading && feedVM.displayedVideos.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if feedVM.displayedVideos.isEmpty {
                    emptyState
                } else {
                    verticalFeed
                }

                feedModeToggle
            }
            .task {
                // Feed audio must survive the ringer switch being silenced.
                AudioSession.activatePlayback()
                await feedVM.loadInitialFeed()
                await feedVM.loadBookmarks(userID: currentUser.id)
                await feedVM.loadFollowing()
                // Setting the anchor is enough — the scroll position binding
                // fires `activate` for us. Calling it here too would count the
                // first clip's view twice.
                visibleVideoID = feedVM.displayedVideos.first?.id
            }
            .onChange(of: feedVM.feedMode) { _, mode in
                playerManager.pauseAll()
                // The new stream has its own cells; drop the old anchor so the
                // scroll position binding can't point at a clip that no longer
                // exists in the list.
                visibleVideoID = nil
                if mode == .following {
                    Task { await feedVM.loadFollowingFeed() }
                }
            }
            .onChange(of: feedVM.displayedVideos.map(\.id)) { _, ids in
                // First page of a stream (or a refresh) landing: start the top
                // clip, since no scroll happens to trigger the position change.
                // Appending a page leaves the anchor valid, so it's a no-op.
                if let anchor = visibleVideoID, ids.contains(anchor) { return }
                visibleVideoID = ids.first
            }
            .onReceive(NotificationCenter.default.publisher(for: .tapeVideoPublished)) { _ in
                Task { await feedVM.refresh() }
            }
            // Leaving the tab (or pushing a profile) must not leave audio
            // playing behind the screen the viewer is actually looking at.
            .onDisappear { playerManager.pauseAll() }
            .onAppear { playerManager.resumeActive() }
            .sheet(isPresented: $showFilters) {
                FeedFilterSheet(filters: $feedVM.filters) {
                    Task { await feedVM.applyFilters() }
                }
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(item: $navigateToProfile) { athleteID in
                AthleteProfileView(athleteID: athleteID, currentUser: currentUser)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallSheet(userRole: currentUser.role)
            }
            .confirmationDialog(
                "Report Video",
                isPresented: Binding(
                    get: { reportTargetVideo != nil },
                    set: { if !$0 { reportTargetVideo = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let video = reportTargetVideo {
                    ForEach(ModerationReason.forVideo(video.category), id: \.self) { reason in
                        Button(reason) { submitReport(video: video, reason: reason) }
                    }
                    Button("Cancel", role: .cancel) { reportTargetVideo = nil }
                }
            } message: {
                Text(reportDialogMessage)
            }
            .confirmationDialog(
                "Block \(blockTargetVideo?.athleteName ?? "Athlete")?",
                isPresented: Binding(
                    get: { blockTargetVideo != nil },
                    set: { if !$0 { blockTargetVideo = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let video = blockTargetVideo {
                    Button("Block", role: .destructive) { submitBlock(video: video) }
                    Button("Cancel", role: .cancel) { blockTargetVideo = nil }
                }
            } message: {
                Text("You won't see their videos and they won't be able to message you.")
            }
            .alert("Thanks for reporting", isPresented: $showReportConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Our team will review this content.")
            }
        }
    }

    private var reportDialogMessage: String {
        guard let video = reportTargetVideo else {
            return "Why are you reporting this video?"
        }
        switch video.category {
        case .tape:
            return "Why are you reporting this Tape clip?"
        case .culture:
            return "Why are you reporting this Culture / NIL clip?"
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: feedVM.feedMode == .following ? "person.2" : "film.stack")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text(feedVM.feedMode == .following ? "No clips from people you follow" : "No videos yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(emptyStateHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if feedVM.feedMode == .following {
                Button("Browse For You") {
                    withAnimation(.spring(duration: 0.3)) { feedVM.feedMode = .discover }
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.tapeRed)
            }
        }
        .padding(40)
    }

    private var emptyStateHint: String {
        switch feedVM.feedMode {
        case .following: "Follow athletes and their newest clips land here."
        case .search: "No athletes matched those filters. Try widening them."
        case .discover: "New highlights show up here as athletes post them."
        }
    }

    // MARK: - Moderation actions

    private func submitReport(video: Video, reason: String) {
        reportTargetVideo = nil
        Task {
            try? await moderationService.report(
                targetType: .video,
                targetId: video.id,
                reason: reason,
                details: nil
            )
            await MainActor.run { showReportConfirmation = true }
        }
    }

    private func submitBlock(video: Video) {
        let athleteID = video.athleteID
        blockTargetVideo = nil
        Task {
            try? await moderationService.blockUser(athleteID)
            await MainActor.run { feedVM.hideAthlete(athleteID) }
        }
    }

    private var feedModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(availableModes, id: \.self) { mode in
                Button {
                    if mode == .search && currentUser.tier == .free {
                        // Filtered search is a Pro feature for recruiters/brands.
                        // Don't switch into it; show the paywall instead.
                        showPaywall = true
                        return
                    }
                    withAnimation(.spring(duration: 0.3)) {
                        feedVM.feedMode = mode
                    }
                    if mode == .search {
                        showFilters = true
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.bold())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .foregroundStyle(feedVM.feedMode == mode ? .white : .white.opacity(0.6))
                }
                .accessibilityAddTraits(feedVM.feedMode == mode ? .isSelected : [])
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 8)
    }

    /// Playback is driven by `scrollPosition`, which reports the cell the feed
    /// is actually settled on. Per-cell `onAppear` was the wrong signal: a
    /// `LazyVStack` instantiates cells before they're on screen, so the clip
    /// below the visible one would start itself and play its audio over the top
    /// of whatever the viewer was actually looking at.
    private var verticalFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(feedVM.displayedVideos) { video in
                    feedCell(video: video)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(video.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleVideoID)
        .ignoresSafeArea()
        .refreshable { await feedVM.refresh() }
        .onChange(of: visibleVideoID) { _, newID in
            guard let newID else { return }
            activate(videoID: newID)
        }
    }

    /// Single place that reacts to the feed settling on a clip: start it, stop
    /// everything else, count the view, warm the neighbours, and page ahead.
    private func activate(videoID: String) {
        playerManager.makeActive(videoID: videoID)

        let videos = feedVM.displayedVideos
        guard let index = videos.firstIndex(where: { $0.id == videoID }) else { return }
        feedVM.currentIndex = index

        Task { await feedVM.recordView(videos[index]) }

        // Warm the next clip so it isn't buffering when it's scrolled to.
        if index + 1 < videos.count {
            playerManager.prepare(videos[index + 1])
        }
        playerManager.cleanup(keepingIDs: nearbyVideoIDs(around: index))

        // Prefetch well before the end so scrolling never stalls.
        if index >= videos.count - 3 {
            Task { await feedVM.loadNextPage() }
        }
    }

    private func feedCell(video: Video) -> some View {
        ZStack {
            VideoPlayerView(player: playerManager.player(for: video))

            // Paused indicator, shown only for the clip the viewer paused.
            if playerManager.isPaused && playerManager.activeVideoID == video.id {
                Image(systemName: "play.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.75))
                    .shadow(radius: 8)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            VideoOverlayView(
                video: video,
                isBookmarked: feedVM.isBookmarked(video.id),
                isFollowing: feedVM.isFollowing(video.athleteID),
                canFollow: video.athleteID != currentUser.id,
                isMuted: playerManager.isMuted,
                onProfileTap: {
                    navigateToProfile = video.athleteID
                },
                onFollowTap: {
                    Task { await feedVM.toggleFollow(userID: video.athleteID) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                },
                onBookmarkTap: {
                    Task {
                        await feedVM.toggleBookmark(
                            videoID: video.id,
                            userID: currentUser.id
                        )
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                },
                onShareTap: {
                    shareURL = URL(string: "tape://video/\(video.id)")
                    showShareSheet = true
                },
                onMuteTap: {
                    playerManager.toggleMute()
                },
                onReportTap: {
                    reportTargetVideo = video
                },
                onBlockTap: {
                    blockTargetVideo = video
                }
            )
        }
        // Taps anywhere that isn't a control pause/resume the clip. Buttons and
        // menus inside the overlay consume their own taps first.
        .onTapGesture {
            playerManager.togglePlayPause()
        }
    }

    private func nearbyVideoIDs(around index: Int) -> Set<String> {
        let videos = feedVM.displayedVideos
        guard !videos.isEmpty else { return [] }
        let lower = max(0, index - 1)
        let upper = min(videos.count - 1, index + 2)
        guard lower <= upper else { return [] }
        return Set((lower...upper).map { videos[$0].id })
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
