import Foundation

/// The kind of content being reported. Raw values match the backend
/// `ReportTargetType` enum exactly.
enum ReportTargetType: String, Codable {
    case video = "VIDEO"
    case user = "USER"
    case message = "MESSAGE"
}

/// Canonical list of report reasons shown in the report dialogs. Centralized so
/// the feed, profile, and chat screens stay consistent.
enum ModerationReason {
    static let all: [String] = [
        "Inappropriate content",
        "Harassment or bullying",
        "Spam or misleading",
        "Nudity or sexual content",
        "Violence or dangerous acts",
        "Other"
    ]
}

/// Abstraction for user-generated-content safety actions: reporting content and
/// blocking/unblocking users. `APIModerationService` is the production
/// implementation; `MockModerationService` backs previews and tests.
protocol ModerationServiceProtocol {
    func report(targetType: ReportTargetType, targetId: String, reason: String, details: String?) async throws
    func blockUser(_ userID: String) async throws
    func unblockUser(_ userID: String) async throws
    func fetchBlockedUserIDs() async throws -> [String]
}

// MARK: - MockModerationService

/// In-memory stand-in used by SwiftUI previews. Keeps a local set of blocked
/// IDs so previews behave plausibly without a backend.
final class MockModerationService: ModerationServiceProtocol {
    private var blocked: Set<String> = []

    func report(targetType: ReportTargetType, targetId: String, reason: String, details: String?) async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    func blockUser(_ userID: String) async throws {
        try await Task.sleep(for: .milliseconds(150))
        blocked.insert(userID)
    }

    func unblockUser(_ userID: String) async throws {
        try await Task.sleep(for: .milliseconds(150))
        blocked.remove(userID)
    }

    func fetchBlockedUserIDs() async throws -> [String] {
        try await Task.sleep(for: .milliseconds(150))
        return Array(blocked)
    }
}
