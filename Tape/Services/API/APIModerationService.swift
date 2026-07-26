import Foundation

/// Concrete `ModerationServiceProtocol` backed by the REST API. The acting user
/// is always identified server-side from the Firebase bearer token attached by
/// `APIClient`, so these calls only carry the target of the action.
final class APIModerationService: ModerationServiceProtocol {
    private let client = APIClient.shared

    private struct ReportBody: Encodable {
        let targetType: String
        let targetId: String
        let reason: String
        let details: String?
    }

    private struct BlockBody: Encodable {
        let userId: String
    }

    /// `POST /api/reports`
    func report(targetType: ReportTargetType, targetId: String, reason: String, details: String?) async throws {
        try await client.postVoid("/api/reports", body: ReportBody(
            targetType: targetType.rawValue,
            targetId: targetId,
            reason: reason,
            details: details
        ))
    }

    /// `POST /api/blocks`
    func blockUser(_ userID: String) async throws {
        try await client.postVoid("/api/blocks", body: BlockBody(userId: userID))
    }

    /// `DELETE /api/blocks/{userId}`
    func unblockUser(_ userID: String) async throws {
        try await client.deleteVoid("/api/blocks/\(userID)")
    }

    /// `GET /api/blocks` — returns the IDs of users the caller has blocked.
    func fetchBlockedUserIDs() async throws -> [String] {
        try await client.get("/api/blocks")
    }
}
