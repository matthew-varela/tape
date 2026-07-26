import SwiftUI

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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile header
                        VStack(spacing: 12) {
                            if let urlString = currentUser.profileImageURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundStyle(.secondary)
                                }
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

                            Text(currentUser.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(currentUser.role.displayName)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.tapeRed.opacity(0.2))
                                .foregroundStyle(Color.tapeRed)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 20)

                        // Scouting boards shortcut
                        if currentUser.role == .recruiter || currentUser.role == .brand {
                            NavigationLink {
                                ScoutingBoardView(currentUser: currentUser)
                            } label: {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(Color.tapeRed)
                                    Text("My Scouting Boards")
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.tapeCardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 20)
                        }

                        // Account info
                        VStack(spacing: 1) {
                            infoRow(icon: "envelope.fill", label: "Email", value: currentUser.email)
                            if let org = currentUser.organization {
                                infoRow(icon: "building.2.fill", label: "Organization", value: org)
                            }
                            if let title = currentUser.title {
                                infoRow(icon: "briefcase.fill", label: "Title", value: title)
                            }
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
        }
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
