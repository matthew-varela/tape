import SwiftUI

@Observable
final class ScoutingViewModel {
    var boards: [ScoutingBoard] = []
    var bookmarkedAthletes: [User] = []
    var isLoading = false
    var errorMessage: String?

    private let profileService: ProfileServiceProtocol

    init(profileService: ProfileServiceProtocol = MockProfileService()) {
        self.profileService = profileService
        self.boards = MockData.scoutingBoards
    }

    func loadBookmarkedAthletes(for boardID: String? = nil) async {
        isLoading = true
        let athleteIDs: [String]
        if let boardID, let board = boards.first(where: { $0.id == boardID }) {
            athleteIDs = board.athleteIDs
        } else {
            athleteIDs = Array(Set(boards.flatMap(\.athleteIDs)))
        }

        do {
            let allAthletes = try await profileService.fetchAthletes()
            bookmarkedAthletes = allAthletes.filter { athleteIDs.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addToBoard(athleteID: String, boardID: String? = nil) {
        if let boardID {
            if let idx = boards.firstIndex(where: { $0.id == boardID }) {
                if !boards[idx].athleteIDs.contains(athleteID) {
                    boards[idx].athleteIDs.append(athleteID)
                }
            }
        } else if let idx = boards.indices.first {
            if !boards[idx].athleteIDs.contains(athleteID) {
                boards[idx].athleteIDs.append(athleteID)
            }
        }
    }

    func removeFromBoard(athleteID: String, boardID: String) {
        if let idx = boards.firstIndex(where: { $0.id == boardID }) {
            boards[idx].athleteIDs.removeAll { $0 == athleteID }
        }
    }

    func createBoard(name: String, ownerID: String) {
        let board = ScoutingBoard(ownerID: ownerID, name: name)
        boards.append(board)
    }
}
