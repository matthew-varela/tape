import FirebaseCore
import SwiftUI

/// `TapeApp` is the SwiftUI entry point. The `@main` attribute marks it as the
/// program's launch object — iOS will instantiate exactly one of these per app
/// lifecycle and invoke `body` to build the scene graph.
///
/// At startup we:
///   1. Configure Firebase from `GoogleService-Info.plist`,
///   2. Build the singleton `AuthViewModel` with production services,
///   3. Inject the `SubscriptionManager` into the environment so any view can
///      check `isSubscribed` or trigger purchases without prop-drilling,
///   4. Kick off two long-running observation Tasks — one for Firebase auth
///      state, one for StoreKit transactions,
///   5. Route incoming deep links (shared clip URLs) through `DeepLinkRouter`.
@main
struct TapeApp: App {
    @State private var authViewModel: AuthViewModel
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var deepLinkRouter = DeepLinkRouter()

    init() {
        FirebaseApp.configure()
        _authViewModel = State(
            initialValue: AuthViewModel(
                authService: FirebaseAuthService(),
                profileService: APIProfileService()
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(subscriptionManager)
                .environment(deepLinkRouter)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    deepLinkRouter.handle(url: url)
                }
                .task {
                    // Begin Firebase auth state observation. Long-running for
                    // the entire app lifetime; cancellation happens
                    // automatically when the scene is destroyed.
                    await authViewModel.startObserving()
                }
                .task {
                    // Load StoreKit products + start the transaction listener.
                    // This must run early so external transactions (Family
                    // Sharing, Ask to Buy) are caught the moment they arrive.
                    await subscriptionManager.start(authVM: authViewModel)
                }
        }
    }
}
