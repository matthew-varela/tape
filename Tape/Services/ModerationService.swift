import Foundation

/// The kind of content being reported. Raw values match the backend
/// `ReportTargetType` enum exactly.
enum ReportTargetType: String, Codable {
    case video = "VIDEO"
    case user = "USER"
    case message = "MESSAGE"
}

/// Canonical report reasons for dialogs across feed, profile, and chat.
///
/// Video reports include a category-specific option first so Tape clips can be
/// flagged as non-sports and Culture/NIL clips as off-topic for that tab.
enum ModerationReason {
    /// Shared safety reasons used for users and as the base for videos.
    static let general: [String] = [
        "Inappropriate content",
        "Harassment or bullying",
        "Spam or misleading",
        "Nudity or sexual content",
        "Violence or dangerous acts",
        "Other"
    ]

    /// Alias kept for call sites that report people (profile, chat).
    static var all: [String] { general }

    /// Reasons for reporting a video, tailored to Tape vs Culture/NIL.
    static func forVideo(_ category: VideoCategory) -> [String] {
        [categoryMismatchReason(for: category)] + general
    }

    static func categoryMismatchReason(for category: VideoCategory) -> String {
        switch category {
        case .tape:
            return "Not sports-related"
        case .culture:
            return "Not NIL / Culture related"
        }
    }
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
