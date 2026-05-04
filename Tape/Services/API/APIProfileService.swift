import Foundation

/// Concrete `ProfileServiceProtocol` that talks to the production REST backend
/// over HTTPS. Every call goes through `APIClient.shared`, which:
///   - prepends the base URL,
///   - JSON-encodes request bodies and decodes responses,
///   - attaches the Firebase ID token as `Authorization: Bearer …`,
///   - turns non-2xx responses into `APIError` instances.
final class APIProfileService: ProfileServiceProtocol {
    private let client = APIClient.shared

    /// `GET /api/users/me`
    /// The bearer token identifies the caller, so no path params are needed.
    func fetchCurrentUser() async throws -> User {
        try await client.get("/api/users/me")
    }

    /// `GET /api/users/{id}`
    /// Returns nil if the server responds 404 (we surface that as `APIError`
    /// and convert here).
    func fetchAthlete(id: String) async throws -> User? {
        do {
            let user: User = try await client.get("/api/users/\(id)")
            return user
        } catch APIError.badResponse(let status, _) where status == 404 {
            return nil
        }
    }

    /// `GET /api/users?role=ATHLETE` — bulk list used by the search screen as a
    /// fallback when no query is typed.
    func fetchAthletes() async throws -> [User] {
        try await client.get("/api/users", query: ["role": "ATHLETE"])
    }

    /// `GET /api/users/search?...` — server-side full text + filters.
    /// We omit any filter that's nil or empty so the URL stays clean and the
    /// server can apply defaults.
    func searchUsers(
        query: String?,
        role: UserRole?,
        position: String?,
        state: String?,
        sport: String?
    ) async throws -> [User] {
        var params: [String: String] = [:]
        if let q = query, !q.isEmpty { params["q"] = q }
        if let role { params["role"] = role.rawValue.uppercased() }
        if let p = position, !p.isEmpty { params["position"] = p }
        if let s = state, !s.isEmpty { params["state"] = s }
        if let sp = sport, !sp.isEmpty { params["sport"] = sp }
        return try await client.get("/api/users/search", query: params)
    }

    /// `GET /api/users/{id}/viewers` — Pro feature; backend should 403 for free
    /// users and we surface the error to the caller.
    func fetchProfileViewers(for athleteID: String) async throws -> [User] {
        try await client.get("/api/users/\(athleteID)/viewers")
    }

    /// `PUT /api/users/{id}` — full record update. Backend echoes the saved
    /// record back; we drop the response value because the caller refreshes
    /// via `fetchCurrentUser()` to get the canonical state.
    func updateProfile(_ user: User) async throws {
        let _: User = try await client.put("/api/users/\(user.id)", body: user)
    }
}
