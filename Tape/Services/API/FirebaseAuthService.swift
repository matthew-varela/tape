import FirebaseAuth
import Foundation

/// Production `AuthServiceProtocol` implementation that talks to Firebase Auth
/// for credentials and to our own backend for the rich profile record.
///
/// Firebase Auth manages:
///   - Email/password validation,
///   - Token issuance and refresh,
///   - Persisting the session in the keychain across launches.
///
/// Our backend manages:
///   - The full `User` record (role, tier, profile fields, counters),
///   - Mapping a Firebase UID to our internal user ID.
///
/// On sign up we create the Firebase user first and then tell the backend
/// "here's a new Firebase UID, please mint a User record for it".
final class FirebaseAuthService: AuthServiceProtocol {
    private let client = APIClient.shared

    func signUp(email: String, password: String, displayName: String, role: UserRole, dateOfBirth: Date) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)

        // Set the displayName on the Firebase profile so any non-backend code
        // (analytics, push notifications) sees a friendly name.
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()

        struct SignUpBody: Encodable {
            let firebaseUid: String
            let email: String
            let displayName: String
            let role: String
            let dateOfBirth: String
        }

        let body = SignUpBody(
            firebaseUid: result.user.uid,
            email: email,
            displayName: displayName,
            role: role.rawValue.uppercased(),
            dateOfBirth: Self.isoDateFormatter.string(from: dateOfBirth)
        )

        let user: User = try await client.post("/api/auth/signup", body: body)
        return user
    }

    /// Formats a date as ISO `yyyy-MM-dd` (date only) for the backend's
    /// `LocalDate dateOfBirth` field. Fixed locale/timezone so the calendar day
    /// the user picked is preserved regardless of device settings.
    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)

        // We send the email to the backend so it can look up the User row.
        // The bearer token (attached automatically by APIClient) proves it's
        // actually this user calling.
        let body = ["email": result.user.email ?? email]
        let user: User = try await client.post("/api/auth/signin", body: body)
        return user
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Synchronous best-effort access to a *partial* User. Used in places where
    /// we want a quick avatar/name fallback before the full backend record is
    /// loaded. Anywhere that needs the canonical record should call
    /// `ProfileService.fetchCurrentUser()`.
    func currentUser() -> User? {
        guard let fbUser = Auth.auth().currentUser else { return nil }
        return User(
            id: fbUser.uid,
            email: fbUser.email ?? "",
            displayName: fbUser.displayName ?? "",
            role: .athlete
        )
    }

    /// Bridges Firebase's callback-style state listener into a Swift
    /// `AsyncStream` so the viewmodel can `for await` the events.
    ///
    /// `addStateDidChangeListener` fires:
    ///   - Once on registration with the *currently restored* session (or nil).
    ///   - Whenever the user signs in / out / has their token revoked.
    ///
    /// We yield `.signedIn` if there's a Firebase user, `.signedOut` otherwise.
    /// The `onTermination` block detaches the listener when the consumer
    /// cancels the stream (e.g. on app teardown) to prevent leaks.
    func observeAuthState() -> AsyncStream<AuthEvent> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                if user != nil {
                    continuation.yield(.signedIn)
                } else {
                    continuation.yield(.signedOut)
                }
            }
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
}
