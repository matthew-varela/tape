import Foundation

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

protocol AuthServiceProtocol {
    func signUp(email: String, password: String, displayName: String, role: UserRole) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() throws
    func currentUser() -> User?
}

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
        // Return a mock recruiter for demo purposes
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
}
