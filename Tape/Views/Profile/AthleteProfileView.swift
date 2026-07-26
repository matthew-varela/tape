import AVFoundation
import SwiftUI
import Kingfisher

/// `AthleteProfileView` shows a single athlete's profile: photo, vitals,
/// videos (split into Tape and Culture/NIL tabs), and — when viewing your
/// own profile — analytics like profile viewers.
///
/// Sections of the profile grid. `saved` is the viewer's own bookmarked clips
/// and is therefore only offered on their own profile.
enum ProfileTab: String, CaseIterable, Identifiable {
    case tape = "Tape"
    case culture = "Culture"
    case saved = "Saved"

    var id: String { rawValue }
    var title: String { rawValue }

    var emptyMessage: String {
        switch self {
        case .tape: "No tape yet"
        case .culture: "No culture clips yet"
        case .saved: "Nothing saved yet — tap Save on any clip in the feed"
        }
    }
}

/// Two key Pro-gated interactions live here:
///   - Pinning your own clip (long-press the tile),
///   - Tapping the profile-views badge to see exactly who viewed you.
struct AthleteProfileView: View {
    let athleteID: String
    let currentUser: User
    @State private var profileVM = ProfileViewModel(
        profileService: APIProfileService(),
        videoService: APIVideoService(),
        followService: APIFollowService(),
        savedAthleteService: APISavedAthleteService()
    )
    @State private var inboxVM = InboxViewModel(messageService: APIMessageService())
    @State private var selectedTab: ProfileTab = .tape
    @State private var selectedVideo: Video?
    @State private var navigateToChat: Conversation?
    @State private var showPaywall = false
    @State private var showViewersSheet = false

    // Moderation
    private let moderationService = APIModerationService()
    @Environment(\.dismiss) private var dismiss
    @State private var showReportDialog = false
    @State private var showBlockDialog = false
    @State private var showReportConfirmation = false

    private var isOwnProfile: Bool { currentUser.id == athleteID }

    /// Recruiters and brands can shortlist athletes; athletes cannot.
    private var canSaveAthlete: Bool {
        !isOwnProfile && currentUser.role != .athlete && profileVM.athlete?.role == .athlete
    }

    /// The Saved tab holds the viewer's own bookmarks, so it's meaningless on
    /// someone else's profile.
    private var tabs: [ProfileTab] {
        isOwnProfile ? ProfileTab.allCases : [.tape, .culture]
    }

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
                            followRow(athlete)
                            if athlete.role == .athlete {
                                VitalsDashboard(athlete: athlete)
                                TopSchoolsRow(schoolIDs: athlete.targetSchoolIDs)
                            } else {
                                CoachSchoolBanner(schoolID: athlete.schoolId, position: athlete.title)
                            }
                            actionButtons(athlete)
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
                await profileVM.loadFollowCounts(athleteID: athleteID)
                if canSaveAthlete {
                    await profileVM.loadSavedState(athleteID: athleteID)
                }
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
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) { showReportDialog = true } label: {
                                Label("Report User", systemImage: "flag")
                            }
                            Button(role: .destructive) { showBlockDialog = true } label: {
                                Label("Block User", systemImage: "hand.raised")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
                ProfileViewersSheet(viewers: profileVM.profileViewers, currentUser: currentUser)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Report User", isPresented: $showReportDialog, titleVisibility: .visible) {
                ForEach(ModerationReason.all, id: \.self) { reason in
                    Button(reason) { submitReport(reason: reason) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Why are you reporting this user?")
            }
            .confirmationDialog("Block \(profileVM.athlete?.displayName ?? "User")?",
                                isPresented: $showBlockDialog, titleVisibility: .visible) {
                Button("Block", role: .destructive) { submitBlock() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You won't see their content and they won't be able to message you.")
            }
            .alert("Thanks for reporting", isPresented: $showReportConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Our team will review this user.")
            }
        }
    }

    // MARK: - Moderation actions

    private func submitReport(reason: String) {
        Task {
            try? await moderationService.report(
                targetType: .user,
                targetId: athleteID,
                reason: reason,
                details: nil
            )
            await MainActor.run { showReportConfirmation = true }
        }
    }

    private func submitBlock() {
        Task {
            try? await moderationService.blockUser(athleteID)
            await MainActor.run { dismiss() }
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

            // Coaches with a school get School/Team/Position in the banner
            // below — don't double up a weaker subtitle here.
            if athlete.role == .athlete || SchoolCatalog.school(id: athlete.schoolId) == nil {
                Text(athlete.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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

    // MARK: - Follow

    /// Follower/following counters plus the follow button. Counters are always
    /// visible; the button only appears on other people's profiles.
    private func followRow(_ athlete: User) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 32) {
                countPill(value: profileVM.followCounts.followers, label: "Followers")
                countPill(value: profileVM.followCounts.following, label: "Following")
            }

            if !isOwnProfile {
                Button {
                    Task { await profileVM.toggleFollow(athleteID: athleteID) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        profileVM.followCounts.isFollowing ? "Following" : "Follow",
                        systemImage: profileVM.followCounts.isFollowing ? "checkmark" : "plus"
                    )
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(profileVM.followCounts.isFollowing ? Color.tapeCardBg : Color.tapeRed)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                profileVM.followCounts.isFollowing ? Color.white.opacity(0.2) : .clear,
                                lineWidth: 1
                            )
                    }
                }
                .padding(.horizontal, 20)
            } else {
                // Own profile: Edit sits here so athletes don't have to dig
                // through Settings just to change a photo or vitals.
                NavigationLink {
                    EditProfileView()
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.tapeCardBg)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }

    private func countPill(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Save-player and message actions.
    ///
    /// Messaging stays recruiter-only because the backend refuses conversations
    /// started by athletes — many are minors. Everything else on this screen is
    /// identical regardless of who's looking.
    @ViewBuilder
    private func actionButtons(_ athlete: User) -> some View {
        let canMessage = currentUser.role != .athlete
            && currentUser.id != athlete.id
            && athlete.role == .athlete

        if canMessage || canSaveAthlete {
            HStack(spacing: 12) {
                if canMessage {
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
                        Label("Message", systemImage: "bubble.left.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tapeRed)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if canSaveAthlete {
                    Button {
                        Task { await profileVM.toggleSavedAthlete(athleteID: athleteID) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(
                            profileVM.isAthleteSaved ? "Saved" : "Save",
                            systemImage: profileVM.isAthleteSaved ? "bookmark.fill" : "bookmark"
                        )
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.tapeCardBg)
                        .foregroundStyle(profileVM.isAthleteSaved ? Color.tapeRed : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var mediaTabs: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = tab
                    }
                    if tab == .saved {
                        Task { await profileVM.loadSavedVideos(userID: currentUser.id) }
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.tapeRed : .clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var visibleVideos: [Video] {
        switch selectedTab {
        case .tape: profileVM.tapeVideos
        case .culture: profileVM.cultureVideos
        case .saved: profileVM.savedVideos
        }
    }

    @ViewBuilder
    private var mediaGrid: some View {
        let videos = visibleVideos

        if videos.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: selectedTab == .saved ? "bookmark" : "film")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(selectedTab.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(videos) { video in
                    VideoThumbnailTile(video: video)
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
                            // Saved clips can belong to anyone, so pinning
                            // only applies to the profile's own tabs.
                            if isOwnProfile && selectedTab != .saved {
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
                        .accessibilityLabel("Clip by \(video.athleteName), \(video.viewCount) views")
                }
            }
            .padding(.top, 8)
        }
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
    let currentUser: User
    @Environment(\.dismiss) private var dismiss
    @State private var selectedViewerID: String?

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
                        Button {
                            selectedViewerID = user.id
                        } label: {
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
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
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
            .navigationDestination(item: $selectedViewerID) { userID in
                AthleteProfileView(athleteID: userID, currentUser: currentUser)
            }
        }
    }
}

// MARK: - FullScreenVideoPlayer

/// Full-screen looping player opened from a profile grid tile. Mirrors the
/// feed's gestures: tap anywhere to pause/resume, speaker button to mute.
struct FullScreenVideoPlayer: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var isPaused = false
    @State private var isMuted = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }

            if isPaused {
                Image(systemName: "play.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.75))
                    .shadow(radius: 8)
                    .allowsHitTesting(false)
            }

            VStack {
                HStack(spacing: 16) {
                    Spacer()

                    Button {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(isMuted ? "Unmute" : "Mute")

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityLabel("Close")
                }
                .padding()

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                    Text("\(video.viewCountLabel) views")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 32)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let player else { return }
            if isPaused { player.play() } else { player.pause() }
            isPaused.toggle()
        }
        .onAppear {
            AudioSession.activatePlayback()
            guard let url = URL(string: video.videoURL) else { return }
            let p = AVPlayer(url: url)
            player = p
            p.play()
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                p.seek(to: .zero)
                p.play()
            }
        }
        .onDisappear {
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
            }
            loopObserver = nil
            player?.pause()
            player = nil
        }
    }
}
