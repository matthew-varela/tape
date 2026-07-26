import Foundation

/// Social counters for one profile, as returned by
/// `GET /api/follows/{userId}/counts`. `isFollowing` is relative to the
/// signed-in caller.
struct FollowCounts: Codable, Equatable {
    var followers: Int
    var following: Int
    var isFollowing: Bool

    static let empty = FollowCounts(followers: 0, following: 0, isFollowing: false)
}

/// Follows are one-directional and need no approval, matching how public
/// accounts work on TikTok and Instagram.
protocol FollowServiceProtocol {
    func follow(_ userID: String) async throws
    func unfollow(_ userID: String) async throws

    /// IDs the signed-in user follows. Cached client-side so the feed and
    /// profile can render follow state without a request per row.
    func fetchFollowingIDs() async throws -> [String]

    func fetchCounts(for userID: String) async throws -> FollowCounts
}

// MARK: - MockFollowService

final class MockFollowService: FollowServiceProtocol {
    private var following: Set<String> = []

    func follow(_ userID: String) async throws {
        try await Task.sleep(for: .milliseconds(120))
        following.insert(userID)
    }

    func unfollow(_ userID: String) async throws {
        try await Task.sleep(for: .milliseconds(120))
        following.remove(userID)
    }

    func fetchFollowingIDs() async throws -> [String] {
        try await Task.sleep(for: .milliseconds(80))
        return Array(following)
    }

    func fetchCounts(for userID: String) async throws -> FollowCounts {
        try await Task.sleep(for: .milliseconds(80))
        return FollowCounts(
            followers: following.contains(userID) ? 1 : 0,
            following: 0,
            isFollowing: following.contains(userID)
        )
    }
}
