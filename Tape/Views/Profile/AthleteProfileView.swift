import AVFoundation
import SwiftUI
import Kingfisher

struct AthleteProfileView: View {
    let athleteID: String
    let currentUser: User
    @State private var profileVM = ProfileViewModel()
    @State private var inboxVM = InboxViewModel()
    @State private var selectedTab: VideoCategory = .tape
    @State private var selectedVideo: Video?
    @State private var navigateToChat: Conversation?
    @State private var showPaywall = false

    var body: some View {
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(item: $selectedVideo) { video in
            FullScreenVideoPlayer(video: video)
        }
        .navigationDestination(item: $navigateToChat) { conversation in
            ChatThreadView(conversation: conversation, currentUser: currentUser)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallSheet(userRole: currentUser.role)
        }
    }

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

            // Profile views
            if currentUser.id == athlete.id {
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                    Text("\(athlete.profileViewsThisWeek) profile views this week")
                }
                .font(.caption)
                .foregroundStyle(Color.tapeRed)
                .onTapGesture {
                    if currentUser.tier == .free {
                        showPaywall = true
                    }
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
            }
        }
        .padding(.top, 8)
    }
}

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
