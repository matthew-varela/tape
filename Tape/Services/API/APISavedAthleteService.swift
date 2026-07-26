import Foundation

/// REST implementation of `SavedAthleteServiceProtocol`.
///
/// The scout is always the authenticated caller, so none of these endpoints
/// take a user id.
final class APISavedAthleteService: SavedAthleteServiceProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchSavedAthletes() async throws -> [User] {
        try await client.get("/api/saved-athletes")
    }

    func save(athleteID: String) async throws {
        struct Body: Encodable { let athleteId: String }
        try await client.postVoid("/api/saved-athletes", body: Body(athleteId: athleteID))
    }

    func unsave(athleteID: String) async throws {
        try await client.deleteVoid("/api/saved-athletes/\(athleteID)")
    }
}
