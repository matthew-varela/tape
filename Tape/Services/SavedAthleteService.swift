import Foundation

/// Recruiter/brand shortlist of athletes — the profile equivalent of
/// bookmarking a video.
///
/// Distinct from `ScoutingServiceProtocol`: boards are named, organised lists
/// you build deliberately, this is a single one-tap save from any profile.
protocol SavedAthleteServiceProtocol {
    /// The caller's saved athletes, newest save first.
    func fetchSavedAthletes() async throws -> [User]

    /// Idempotent — saving an already-saved athlete is a no-op.
    func save(athleteID: String) async throws

    func unsave(athleteID: String) async throws
}

/// In-memory implementation for previews and tests.
final class MockSavedAthleteService: SavedAthleteServiceProtocol {
    private var saved: [User] = []

    func fetchSavedAthletes() async throws -> [User] {
        try await Task.sleep(for: .milliseconds(120))
        return saved
    }

    func save(athleteID: String) async throws {
        try await Task.sleep(for: .milliseconds(80))
        guard !saved.contains(where: { $0.id == athleteID }),
              let athlete = MockData.athletes.first(where: { $0.id == athleteID })
        else { return }
        saved.insert(athlete, at: 0)
    }

    func unsave(athleteID: String) async throws {
        try await Task.sleep(for: .milliseconds(80))
        saved.removeAll { $0.id == athleteID }
    }
}
