import Foundation

/// `AuthState` is the three-way switch the whole app uses to decide what to
/// show. We need a `unknown` state because at cold launch the Firebase SDK
/// hasn't yet told us whether a session is restored — without a third state we
/// would briefly flash the login screen on every launch even for signed-in
/// users.
enum AuthState: Equatable {
    case unknown
    case unauthenticated
    case authenticated(User)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown): return true
        case (.unauthenticated, .unauthenticated): return true
        case (.authenticated(let a), .authenticated(let b)): return a.id == b.id
        default: return false
        }
    }
}

/// `AuthEvent` is what the Firebase auth state listener emits. The viewmodel
/// translates these into transitions between `AuthState` cases.
enum AuthEvent {
    /// A signed-in Firebase user was detected. The viewmodel should fetch the
    /// rich `User` record from the backend (`/api/users/me`) and transition to
    /// `.authenticated`.
    case signedIn
    /// No Firebase session. Transition to `.unauthenticated`.
    case signedOut
}

/// Auth concerns: sign up, sign in, sign out, retrieving the cached current
/// user, and — importantly — observing the live Firebase auth state across
/// app launches. The observer is what allows session restore.
protocol AuthServiceProtocol {
    func signUp(email: String, password: String, displayName: String, role: UserRole) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() throws
    func currentUser() -> User?

    /// Returns an `AsyncStream` that fires every time the underlying auth
    /// provider's user changes (cold-launch restore, manual sign-in, manual
    /// sign-out, token refresh, account deletion). The viewmodel awaits this
    /// stream for the entire app lifetime.
    func observeAuthState() -> AsyncStream<AuthEvent>
}

// MARK: - MockAuthService

/// Test/preview substitute. The auth state stream emits a single `.signedIn`
/// after a tiny delay so previews behave roughly like the real app.
final class MockAuthService: AuthServiceProtocol {
    private var loggedInUser: User?

    func signUp(email: String, password: String, displayName: String, role: UserRole) async throws -> User {
        try await Task.sleep(for: .milliseconds(500))
        let user = User(email: email, displayName: displayName, role: role)
        loggedInUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        try await Task.sleep(for: .milliseconds(500))
        let user = MockData.recruiters[0]
        loggedInUser = user
        return user
    }

    func signOut() throws {
        loggedInUser = nil
    }

    func currentUser() -> User? {
        loggedInUser
    }

    func observeAuthState() -> AsyncStream<AuthEvent> {
        AsyncStream { continuation in
            continuation.yield(.signedOut)
            continuation.finish()
        }
    }
}
