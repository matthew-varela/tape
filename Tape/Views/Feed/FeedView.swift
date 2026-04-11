import SwiftUI

struct FeedView: View {
    let currentUser: User
    @State private var feedVM = FeedViewModel()
    @State private var playerManager = VideoPlayerManager()
    @State private var showFilters = false
    @State private var navigateToProfile: String?
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if feedVM.isLoading && feedVM.displayedVideos.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if feedVM.displayedVideos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No videos yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    verticalFeed
                }

                // Feed mode toggle for recruiters/brands
                if currentUser.role == .recruiter || currentUser.role == .brand {
                    VStack {
                        feedModeToggle
                        Spacer()
                    }
                }
            }
            .task {
                await feedVM.loadInitialFeed()
                if let first = feedVM.displayedVideos.first {
                    playerManager.play(videoID: first.id)
                }
            }
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
        }
    }

    private var feedModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(FeedMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        feedVM.feedMode = mode
                    }
                    if mode == .search {
                        if currentUser.tier == .free {
                            // Will be gated by paywall in Phase 8
                        }
                        showFilters = true
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.bold())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .foregroundStyle(feedVM.feedMode == mode ? .white : .white.opacity(0.6))
                }
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
                    ZStack {
                        let player = playerManager.player(for: video)
                        VideoPlayerView(player: player)
                            .onAppear {
                                playerManager.play(videoID: video.id)
                                feedVM.currentIndex = index

                                let keepIDs = nearbyVideoIDs(around: index)
                                playerManager.cleanup(keepingIDs: keepIDs)

                                if index >= feedVM.displayedVideos.count - 3 {
                                    Task { await feedVM.loadNextPage() }
                                }
                            }
                            .onDisappear {
                                playerManager.pause(videoID: video.id)
                            }

                        VideoOverlayView(
                            video: video,
                            isBookmarked: feedVM.isBookmarked(video.id),
                            onProfileTap: {
                                navigateToProfile = video.athleteID
                            },
                            onBookmarkTap: {
                                feedVM.toggleBookmark(videoID: video.id)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            },
                            onShareTap: {
                                shareURL = URL(string: "tape://video/\(video.id)")
                                showShareSheet = true
                            }
                        )
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(video.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea()
    }

    private func nearbyVideoIDs(around index: Int) -> Set<String> {
        let videos = feedVM.displayedVideos
        let range = max(0, index - 1)...min(videos.count - 1, index + 2)
        return Set(range.map { videos[$0].id })
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
