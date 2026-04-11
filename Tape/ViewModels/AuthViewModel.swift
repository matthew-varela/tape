import SwiftUI

@Observable
final class AuthViewModel {
    var authState: AuthState = .unauthenticated
    var errorMessage: String?
    var isLoading = false

    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = MockAuthService()) {
        self.authService = authService
    }

    func signUp(email: String, password: String, displayName: String, role: UserRole) async {
        isLoading = true
        errorMessage = nil
        do {
            let user = try await authService.signUp(email: email, password: password, displayName: displayName, role: role)
            authState = .authenticated(user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let user = try await authService.signIn(email: email, password: password)
            authState = .authenticated(user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        try? authService.signOut()
        authState = .unauthenticated
    }

    func signInAsDemo(role: UserRole) async {
        isLoading = true
        let user: User
        switch role {
        case .athlete:
            user = MockData.athletes[0]
        case .recruiter:
            user = MockData.recruiters[0]
        case .brand:
            user = MockData.brands[0]
        }
        try? await Task.sleep(for: .milliseconds(300))
        authState = .authenticated(user)
        isLoading = false
    }
}
