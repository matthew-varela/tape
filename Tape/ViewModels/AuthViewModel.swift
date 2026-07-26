import SwiftUI

/// `AuthViewModel` is the single source of truth in the UI for who (if anyone)
/// is signed in. It glues two services together:
///
///   - `AuthServiceProtocol` (FirebaseAuth in production) — creates / signs in
///      Firebase users and emits live state-change events,
///   - `ProfileServiceProtocol` (our REST backend) — gives us the rich `User`
///      record (role, tier, profile fields).
///
/// The class is `@Observable` (Swift 5.9 macro) which means SwiftUI views
/// using `@Environment(AuthViewModel.self)` automatically re-render whenever
/// any of the stored properties below change.
@Observable
final class AuthViewModel {
    /// Drives the top-level routing in `ContentView`. Starts as `.unknown` so
    /// we don't flash the login screen during cold-launch session restore.
    var authState: AuthState = .unknown
    var errorMessage: String?
    var isLoading = false

    private let authService: AuthServiceProtocol
    private let profileService: ProfileServiceProtocol

    /// The long-running Task that owns the Firebase auth state observation.
    /// Held so we can cancel it on deinit (currently we don't deinit because
    /// the viewmodel lives for the app lifetime, but keeping the handle is a
    /// good defensive habit).
    private var observationTask: Task<Void, Never>?

    /// True while `signUp` / `signIn` / demo login are in flight. Suppresses
    /// the Firebase auth observer from racing ahead with `/me` hydration before
    /// the backend signup/signin call finishes.
    private var isPerformingCredentialAuth = false

    init(
        authService: AuthServiceProtocol = MockAuthService(),
        profileService: ProfileServiceProtocol = MockProfileService()
    ) {
        self.authService = authService
        self.profileService = profileService
    }

    // MARK: - App lifecycle

    /// Begins observing the underlying auth provider for the rest of the app's
    /// lifetime. Called once from `TapeApp` at launch. Idempotent — calling it
    /// twice is a no-op because we cancel the previous task first.
    @MainActor
    func startObserving() async {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.authService.observeAuthState() {
                switch event {
                case .signedIn:
                    // During sign-up/sign-in we set authState from the backend
                    // response directly; hydrating here would race /me ahead of
                    // POST /api/auth/signup or /signin.
                    guard !self.isPerformingCredentialAuth else { continue }
                    await self.hydrateCurrentUser()
                case .signedOut:
                    await MainActor.run { self.authState = .unauthenticated }
                }
            }
        }
    }

    /// Pulls the canonical `User` from the backend and transitions to
    /// `.authenticated`. If the backend call fails (e.g. token expired
    /// immediately, server down) we fall back to `.unauthenticated` so the UI
    /// recovers instead of being stuck on a loading spinner.
    @MainActor
    func hydrateCurrentUser() async {
        do {
            let user = try await profileService.fetchCurrentUser()
            authState = .authenticated(user)
        } catch {
            #if DEBUG
            if case APIError.badResponse(let code, let body) = error, code == 401 {
                print("AuthViewModel: failed to hydrate /me — 401. If the backend returns {\"message\":\"Not authenticated\"} (not \"Missing or invalid Authorization header\"), Firebase auth is likely disabled on the server — set TAPE_FIREBASE_ENABLED=true on Render.")
            }
            print("AuthViewModel: failed to hydrate /me — \(error.localizedDescription)")
            #endif
            authState = .unauthenticated
        }
    }

    /// Re-fetches the current user without changing auth state. Use after
    /// profile edits or subscription changes so the UI reflects the new tier
    /// or fields immediately.
    @MainActor
    func refreshCurrentUser() async {
        guard case .authenticated = authState else { return }
        do {
            let user = try await profileService.fetchCurrentUser()
            authState = .authenticated(user)
        } catch {
            // Silent failure: keep the stale user record rather than logging
            // them out over a transient network blip.
        }
    }

    /// Locally bumps a property on the current user (e.g. an optimistic DM
    /// counter increment). Server is the source of truth on next refresh.
    @MainActor
    func updateLocalUser(_ transform: (inout User) -> Void) {
        guard case .authenticated(var user) = authState else { return }
        transform(&user)
        authState = .authenticated(user)
    }

    // MARK: - Sign up / Sign in / Sign out

    func signUp(email: String, password: String, displayName: String, role: UserRole, dateOfBirth: Date) async {
        isLoading = true
        errorMessage = nil
        isPerformingCredentialAuth = true
        defer {
            isPerformingCredentialAuth = false
            isLoading = false
        }
        do {
            let user = try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName,
                role: role,
                dateOfBirth: dateOfBirth
            )
            authState = .authenticated(user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        isPerformingCredentialAuth = true
        defer {
            isPerformingCredentialAuth = false
            isLoading = false
        }
        do {
            let user = try await authService.signIn(email: email, password: password)
            authState = .authenticated(user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func signOut() {
        try? authService.signOut()
        // The Firebase listener will fire .signedOut and we'll transition.
    }

    /// Permanently deletes the signed-in user's account: removes all server data
    /// and the Firebase Auth user (server-side), then signs out locally. Returns
    /// `true` on success. On failure, sets `errorMessage` and returns `false` so
    /// the UI can keep the user on the settings screen.
    @MainActor
    @discardableResult
    func deleteAccount() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await profileService.deleteAccount()
            // Server already removed the Firebase Auth user; clear the local
            // session so the auth listener transitions us to .unauthenticated.
            try? authService.signOut()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    #if DEBUG
    /// Convenience for the demo quick-login buttons on the login screen.
    /// Tries to sign in; if the user doesn't exist yet, creates them.
    ///
    /// DEBUG-only: this and the hardcoded demo credentials are compiled out of
    /// Release builds so they never reach the App Store binary.
    func signInAsDemo(role: UserRole) async {
        isLoading = true
        errorMessage = nil
        isPerformingCredentialAuth = true
        defer {
            isPerformingCredentialAuth = false
            isLoading = false
        }

        let demoEmail: String
        let demoName: String
        let demoPassword = "TapeDemo123!"
        switch role {
        case .athlete:
            demoEmail = "demo.athlete@tape.app"
            demoName = "Demo Athlete"
        case .recruiter:
            demoEmail = "demo.recruiter@tape.app"
            demoName = "Demo Coach"
        case .brand:
            demoEmail = "demo.brand@tape.app"
            demoName = "Demo Brand"
        }

        // Demo accounts use a fixed adult date of birth.
        let demoDOB = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 946_684_800)

        do {
            let user = try await authService.signIn(email: demoEmail, password: demoPassword)
            authState = .authenticated(user)
        } catch {
            do {
                let user = try await authService.signUp(
                    email: demoEmail,
                    password: demoPassword,
                    displayName: demoName,
                    role: role,
                    dateOfBirth: demoDOB
                )
                authState = .authenticated(user)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    #endif
}
