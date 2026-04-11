import SwiftUI

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

struct MainTabView: View {
    let currentUser: User
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        TabView {
            FeedView(currentUser: currentUser)
                .tabItem { Label("Feed", systemImage: "play.circle.fill") }

            if currentUser.role == .athlete {
                UploadView(currentUser: currentUser)
                    .tabItem { Label("Upload", systemImage: "plus.circle.fill") }
            }

            if currentUser.role == .athlete {
                AthleteProfileView(athleteID: currentUser.id, currentUser: currentUser)
                    .tabItem { Label("Profile", systemImage: "person.fill") }
            }

            if currentUser.role == .recruiter || currentUser.role == .brand {
                ScoutingBoardView(currentUser: currentUser)
                    .tabItem { Label("Scouting", systemImage: "star.fill") }
            }

            InboxListView(currentUser: currentUser)
                .tabItem { Label("Inbox", systemImage: "bubble.left.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.tapeRed)
    }
}
