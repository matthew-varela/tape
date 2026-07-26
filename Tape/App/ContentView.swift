import SwiftUI
import Kingfisher

/// `ContentView` is the top-level routing switch. It reads the auth state
/// from the environment and shows one of three things:
///
///   - `.unknown`         → loading spinner (cold-launch session restore in
///                          progress)
///   - `.unauthenticated` → login screen
///   - `.authenticated`   → the main tab interface
///
/// We animate transitions with a 0.3s ease so going from spinner to login or
/// login to tabs doesn't feel abrupt.
struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        Group {
            switch authVM.authState {
            case .unknown:
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tapeDarkBg)
            case .unauthenticated:
                LoginView()
            case .authenticated(let user):
                MainTabView(currentUser: user)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.authState)
    }
}

/// `MainTabView` is the post-login chrome. Gating mostly happens *inside* each
/// tab (for example athletes can't open recruiter-only filters in Search); the
/// one exception is Upload, which is hidden entirely for recruiters and brands
/// rather than shown as a tab that only ever explains itself.
struct MainTabView: View {
    let currentUser: User
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        TabView {
            FeedView(currentUser: currentUser)
                .tabItem { Label("Feed", systemImage: "house.fill") }

            if currentUser.role == .athlete {
                UploadView(currentUser: currentUser)
                    .tabItem { Label("Upload", systemImage: "plus.circle.fill") }
            }

            InboxListView(currentUser: currentUser)
                .tabItem { Label("Inbox", systemImage: "bubble.left.fill") }

            SearchView(currentUser: currentUser)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            ProfileTabView(currentUser: currentUser)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(Color.tapeRed)
    }
}

/// Routes the Profile tab to the correct screen based on role. Athletes see
/// their public-facing profile (so the experience matches what coaches see);
/// recruiters and brands see a settings-style screen with their org info
/// and a shortcut into scouting boards.
struct ProfileTabView: View {
    let currentUser: User

    var body: some View {
        switch currentUser.role {
        case .athlete:
            AthleteProfileView(athleteID: currentUser.id, currentUser: currentUser)
        case .recruiter, .brand:
            CoachBrandProfileView(currentUser: currentUser)
        }
    }
}

/// Recruiter / brand profile tab. Shows org info, plan, and a shortcut into
/// scouting boards. Settings live behind the gear icon top right.
struct CoachBrandProfileView: View {
    let currentUser: User
    @Environment(AuthViewModel.self) private var authVM

    @State private var savedVM = SavedPlayersViewModel(
        savedAthleteService: APISavedAthleteService()
    )

    private var school: School? { SchoolCatalog.school(id: currentUser.schoolId) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile header
                        VStack(spacing: 12) {
                            if let urlString = currentUser.profileImageURL, let url = URL(string: urlString) {
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

                            Text(currentUser.displayName)
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text(currentUser.role.displayName)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.tapeRed.opacity(0.2))
                                .foregroundStyle(Color.tapeRed)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 20)

                        // School / team / position — the main identity signal
                        // for a coach. Edit Profile is how this gets set and
                        // persisted.
                        if school != nil {
                            CoachSchoolBanner(
                                schoolID: currentUser.schoolId,
                                position: currentUser.title
                            )
                        } else {
                            Text("Add your school and coaching position so athletes know who you are.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        NavigationLink {
                            EditProfileView()
                        } label: {
                            Label(
                                school == nil ? "Set Up Profile" : "Edit Profile",
                                systemImage: "pencil"
                            )
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(school == nil ? Color.tapeRed : Color.tapeCardBg)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        school == nil ? Color.clear : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .padding(.horizontal, 20)

                        // Scouting boards shortcut
                        if currentUser.role == .recruiter || currentUser.role == .brand {
                            NavigationLink {
                                SavedPlayersView(currentUser: currentUser)
                            } label: {
                                shortcutRow(icon: "bookmark.fill", title: "Saved Players",
                                            badge: savedVM.athletes.isEmpty ? nil : "\(savedVM.athletes.count)")
                            }
                            .padding(.horizontal, 20)

                            NavigationLink {
                                ScoutingBoardView(currentUser: currentUser)
                            } label: {
                                shortcutRow(icon: "star.fill", title: "My Scouting Boards", badge: nil)
                            }
                            .padding(.horizontal, 20)
                        }

                        // Account info
                        VStack(spacing: 1) {
                            infoRow(icon: "envelope.fill", label: "Email", value: currentUser.email)
                            infoRow(icon: "crown.fill", label: "Plan",
                                    value: currentUser.tier == .pro ? "Pro" : "Free")
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .task {
                await savedVM.load()
            }
        }
    }

    private func shortcutRow(icon: String, title: String, badge: String?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.tapeRed)
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.tapeRed.opacity(0.2))
                    .foregroundStyle(Color.tapeRed)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.tapeCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.tapeRed)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding()
        .background(Color.tapeCardBg)
    }
}
