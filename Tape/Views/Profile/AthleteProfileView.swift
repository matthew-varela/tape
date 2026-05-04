import AVFoundation
import SwiftUI
import Kingfisher

/// `AthleteProfileView` shows a single athlete's profile: photo, vitals,
/// videos (split into Tape and Culture/NIL tabs), and — when viewing your
/// own profile — analytics like profile viewers.
///
/// Two key Pro-gated interactions live here:
///   - Pinning your own clip (long-press the tile),
///   - Tapping the profile-views badge to see exactly who viewed you.
struct AthleteProfileView: View {
    let athleteID: String
    let currentUser: User
    @State private var profileVM = ProfileViewModel(
        profileService: APIProfileService(),
        videoService: APIVideoService()
    )
    @State private var inboxVM = InboxViewModel(messageService: APIMessageService())
    @State private var selectedTab: VideoCategory = .tape
    @State private var selectedVideo: Video?
    @State private var navigateToChat: Conversation?
    @State private var showPaywall = false
    @State private var showViewersSheet = false

    private var isOwnProfile: Bool { currentUser.id == athleteID }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                if profileVM.isLoading && profileVM.athlete == nil {
                    ProgressView().tint(.white)
                } else if let athlete = profileVM.athlete {
                    ScrollView {
                        VStack(spacing: 0) {
                            profileHeader(athlete)
                            VitalsDashboard(athlete: athlete)
                            messageButton(athlete)
                            mediaTabs
                            mediaGrid
                        }
                    }
                } else {
                    Text("Athlete not found")
                        .foregroundStyle(.secondary)
                }
            }
            .task {
                await profileVM.loadProfile(athleteID: athleteID)
                if isOwnProfile {
                    // Profile viewers list is only relevant for the owner.
                    // Backend should 403 if anyone else asks; we still load
                    // it eagerly so the sheet is instant when they open it.
                    await profileVM.loadProfileViewers(athleteID: athleteID)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if isOwnProfile {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedVideo) { video in
                FullScreenVideoPlayer(video: video)
            }
            .navigationDestination(item: $navigateToChat) { conversation in
                ChatThreadView(conversation: conversation, currentUser: currentUser)
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallSheet(userRole: currentUser.role)
            }
            .sheet(isPresented: $showViewersSheet) {
                ProfileViewersSheet(viewers: profileVM.profileViewers)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Header

    private func profileHeader(_ athlete: User) -> some View {
        VStack(spacing: 12) {
            if let urlString = athlete.profileImageURL, let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.tapeRed, lineWidth: 3))
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
            }

            Text(athlete.displayName)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(athlete.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Profile views badge: tappable for the owner. Free → paywall;
            // Pro → list sheet.
            if isOwnProfile {
                Button {
                    if currentUser.tier == .pro {
                        showViewersSheet = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                        Text("\(athlete.profileViewsThisWeek) profile views this week")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.tapeRed)
                }
            }
        }
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private func messageButton(_ athlete: User) -> some View {
        if currentUser.role != .athlete && currentUser.id != athlete.id {
            Button {
                Task {
                    if let conv = await inboxVM.startConversation(
                        initiator: currentUser,
                        recipientID: athlete.id,
                        recipientName: athlete.displayName
                    ) {
                        navigateToChat = conv
                    }
                }
            } label: {
                Label("Message Player", systemImage: "bubble.left.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.tapeRed)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var mediaTabs: some View {
        HStack(spacing: 0) {
            ForEach(VideoCategory.allCases) { category in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = category
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(category.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedTab == category ? .white : .secondary)
                        Rectangle()
                            .fill(selectedTab == category ? Color.tapeRed : .clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var mediaGrid: some View {
        let videos = selectedTab == .tape ? profileVM.tapeVideos : profileVM.cultureVideos
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(videos) { video in
                AsyncVideoThumbnail(videoURL: video.videoURL)
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if video.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(4)
                        }
                    }
                    .onTapGesture {
                        selectedVideo = video
                    }
                    .contextMenu {
                        if isOwnProfile {
                            Button {
                                handlePinTap(video: video)
                            } label: {
                                if video.isPinned {
                                    Label("Unpin", systemImage: "pin.slash.fill")
                                } else {
                                    Label("Pin to Top", systemImage: "pin.fill")
                                }
                            }
                        }
                    }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Pin handling

    private func handlePinTap(video: Video) {
        // Pinning is a Pro feature for athletes. Free users see the paywall.
        if currentUser.tier == .free {
            showPaywall = true
            return
        }
        Task {
            if video.isPinned {
                await profileVM.unpin(video: video)
            } else {
                await profileVM.pin(video: video)
            }
        }
    }
}

// MARK: - ProfileViewersSheet

/// Pro-only sheet that shows exactly who viewed the athlete's profile this
/// week. Backend returns a list of `User` records ordered by most-recent view.
private struct ProfileViewersSheet: View {
    let viewers: [User]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                if viewers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No views yet this week")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(viewers) { user in
                        HStack(spacing: 14) {
                            if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(user.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color.tapeCardBg)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Profile Viewers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - FullScreenVideoPlayer

struct FullScreenVideoPlayer: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            if let url = URL(string: video.videoURL) {
                let p = AVPlayer(url: url)
                player = p
                p.play()
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: p.currentItem,
                    queue: .main
                ) { _ in
                    p.seek(to: .zero)
                    p.play()
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
