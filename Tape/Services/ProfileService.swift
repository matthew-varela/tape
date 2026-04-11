import Foundation

protocol ProfileServiceProtocol {
    func fetchAthlete(id: String) async throws -> User?
    func fetchAthletes() async throws -> [User]
    func fetchProfileViewers(for athleteID: String) async throws -> [User]
    func updateProfile(_ user: User) async throws
}

final class MockProfileService: ProfileServiceProtocol {
    private var athletes = MockData.athletes

    func fetchAthlete(id: String) async throws -> User? {
        try await Task.sleep(for: .milliseconds(200))
        return athletes.first { $0.id == id }
    }

    func fetchAthletes() async throws -> [User] {
        try await Task.sleep(for: .milliseconds(200))
        return athletes
    }

    func fetchProfileViewers(for athleteID: String) async throws -> [User] {
        try await Task.sleep(for: .milliseconds(200))
        guard let athlete = athletes.first(where: { $0.id == athleteID }) else { return [] }
        let allUsers = MockData.allUsers
        return athlete.profileViewerIDs.compactMap { viewerID in
            allUsers.first { $0.id == viewerID }
        }
    }

    func updateProfile(_ user: User) async throws {
        try await Task.sleep(for: .milliseconds(300))
        if let index = athletes.firstIndex(where: { $0.id == user.id }) {
            athletes[index] = user
        }
    }
}
