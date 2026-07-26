import Foundation

/// REST implementation of `FollowServiceProtocol`. The follower is always the
/// bearer-token caller, so only the target user is sent.
final class APIFollowService: FollowServiceProtocol {
    private let client = APIClient.shared

    private struct FollowBody: Encodable {
        let userId: String
    }

    /// `POST /api/follows`
    func follow(_ userID: String) async throws {
        try await client.postVoid("/api/follows", body: FollowBody(userId: userID))
    }

    /// `DELETE /api/follows/{userId}`
    func unfollow(_ userID: String) async throws {
        try await client.deleteVoid("/api/follows/\(userID)")
    }

    /// `GET /api/follows/following`
    func fetchFollowingIDs() async throws -> [String] {
        try await client.get("/api/follows/following")
    }

    /// `GET /api/follows/{userId}/counts`
    func fetchCounts(for userID: String) async throws -> FollowCounts {
        try await client.get("/api/follows/\(userID)/counts")
    }
}
