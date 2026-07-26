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
                if let first = feedVM.displayedVideos.first {
                    playerManager.makeActive(videoID: first.id)
                }
            }
            .onChange(of: feedVM.feedMode) { _, mode in
                playerManager.pauseAll()
                if mode == .following {
                    Task { await feedVM.loadFollowingFeed() }
                }
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
                    ForEach(ModerationReason.all, id: \.self) { reason in
                        Button(reason) { submitReport(video: video, reason: reason) }
                    }
                    Button("Cancel", role: .cancel) { reportTargetVideo = nil }
                }
            } message: {
                Text("Why are you reporting this video?")
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

    private var verticalFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(feedVM.displayedVideos.enumerated()), id: \.element.id) { index, video in
                    feedCell(video: video, index: index)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(video.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea()
        .refreshable { await feedVM.refresh() }
    }

    private func feedCell(video: Video, index: Int) -> some View {
        ZStack {
            VideoPlayerView(player: playerManager.player(for: video))
                .onAppear {
                    playerManager.makeActive(videoID: video.id)
                    feedVM.currentIndex = index

                    playerManager.cleanup(keepingIDs: nearbyVideoIDs(around: index))

                    Task { await feedVM.recordView(video) }

                    // Prefetch well before the end so scrolling never stalls.
                    if index >= feedVM.displayedVideos.count - 3 {
                        Task { await feedVM.loadNextPage() }
                    }
                }
                .onDisappear {
                    playerManager.pause(videoID: video.id)
                }

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
