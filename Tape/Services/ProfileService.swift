import Foundation

/// `ProfileServiceProtocol` is the abstraction every part of the app uses when it
/// needs user profile data — looking up an athlete, listing all athletes, fetching
/// the currently signed-in user, fetching the people who viewed a profile, or
/// saving edits.
///
/// Why a protocol? So views and view models depend on an interface, not on a
/// concrete network class. In tests and SwiftUI previews we can substitute
/// `MockProfileService` (declared below) without touching production code.
/// In the real app `APIProfileService` (in Services/API) is what gets injected.
protocol ProfileServiceProtocol {
    /// Fetches the *currently authenticated* user via the bearer token attached
    /// by `APIClient`. The server identifies who you are from the token, so this
    /// call takes no arguments. Returns the freshest copy of the user record
    /// (tier, profile counters, etc).
    func fetchCurrentUser() async throws -> User

    /// Looks up a single athlete by ID. Returns `nil` if the server returns 404.
    /// Used everywhere we deep-link into a profile.
    func fetchAthlete(id: String) async throws -> User?

    /// Returns all athletes the server is willing to list (used by the search
    /// screen as a fallback list when no query is entered).
    func fetchAthletes() async throws -> [User]

    /// Returns athletes/coaches matching the provided filters. The backend does
    /// the heavy lifting; the client just passes the criteria through.
    /// Any nil/empty parameter is omitted from the query string.
    func searchUsers(
        query: String?,
        role: UserRole?,
        position: String?,
        state: String?,
        sport: String?
    ) async throws -> [User]

    /// Returns the people who have viewed an athlete's profile. Pro feature.
    func fetchProfileViewers(for athleteID: String) async throws -> [User]

    /// Persists edits to the user's profile. The server is the source of truth
    /// — call `fetchCurrentUser()` afterward if you need the canonical record.
    func updateProfile(_ user: User) async throws

    /// Permanently deletes the authenticated user's account and all associated
    /// data on the server (and their Firebase Auth user). Required for App Store
    /// compliance. Caller is responsible for signing out afterward.
    func deleteAccount() async throws
}

// MARK: - MockProfileService

/// In-memory stand-in for the real network service. Backed by `MockData` so
/// previews and tests can render real-looking profile cards without a server.
/// Each call simulates a small network delay so loading spinners get exercised.
final class MockProfileService: ProfileServiceProtocol {
    private var athletes = MockData.athletes
    private var allUsers = MockData.allUsers

    func fetchCurrentUser() async throws -> User {
        try await Task.sleep(for: .milliseconds(150))
        // Mock: just return the first athlete as "me".
        return MockData.athletes[0]
    }

    func fetchAthlete(id: String) async throws -> User? {
        try await Task.sleep(for: .milliseconds(200))
        return athletes.first { $0.id == id } ?? allUsers.first { $0.id == id }
    }

    func fetchAthletes() async throws -> [User] {
        try await Task.sleep(for: .milliseconds(200))
        return athletes
    }

    func searchUsers(
        query: String?,
        role: UserRole?,
        position: String?,
        state: String?,
        sport: String?
    ) async throws -> [User] {
        try await Task.sleep(for: .milliseconds(200))
        var results = allUsers
        if let q = query?.lowercased(), !q.isEmpty {
            results = results.filter { user in
                user.displayName.lowercased().contains(q)
                    || (user.highSchool?.lowercased().contains(q) ?? false)
                    || (user.organization?.lowercased().contains(q) ?? false)
                    || (user.position?.lowercased().contains(q) ?? false)
            }
        }
        if let role { results = results.filter { $0.role == role } }
        if let p = position, !p.isEmpty { results = results.filter { $0.position == p } }
        if let s = state, !s.isEmpty { results = results.filter { $0.state == s } }
        if let sp = sport, !sp.isEmpty { results = results.filter { $0.sport == sp } }
        return results
    }

    func fetchProfileViewers(for athleteID: String) async throws -> [User] {
        try await Task.sleep(for: .milliseconds(200))
        guard let athlete = athletes.first(where: { $0.id == athleteID }) else { return [] }
        return athlete.profileViewerIDs.compactMap { viewerID in
            allUsers.first { $0.id == viewerID }
        }
    }

    func updateProfile(_ user: User) async throws {
        try await Task.sleep(for: .milliseconds(300))
        if let index = athletes.firstIndex(where: { $0.id == user.id }) {
            athletes[index] = user
        }
        if let index = allUsers.firstIndex(where: { $0.id == user.id }) {
            allUsers[index] = user
        }
    }

    func deleteAccount() async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}
