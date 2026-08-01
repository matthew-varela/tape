import SwiftUI

/// Drives the Scouting Board screen. State is synchronized with the backend
/// through `ScoutingServiceProtocol` (production: `APIScoutingService`).
///
/// We hold two services because:
///   - `scoutingService` manages the boards (named lists of athlete IDs),
///   - `profileService` resolves those IDs into full `User` records to render.
@Observable
@MainActor
final class ScoutingViewModel {
    var boards: [ScoutingBoard] = []
    var bookmarkedAthletes: [User] = []
    var isLoading = false
    var errorMessage: String?

    private let scoutingService: ScoutingServiceProtocol
    private let profileService: ProfileServiceProtocol

    init(
        scoutingService: ScoutingServiceProtocol = MockScoutingService(),
        profileService: ProfileServiceProtocol = MockProfileService()
    ) {
        self.scoutingService = scoutingService
        self.profileService = profileService
    }

    // MARK: - Boards

    /// Loads all boards owned by the current user. Idempotent — call from
    /// `.task` and on pull-to-refresh.
    func loadBoards(ownerID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            boards = try await scoutingService.fetchBoards(ownerID: ownerID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createBoard(name: String, ownerID: String) async {
        do {
            let board = try await scoutingService.createBoard(name: name, ownerID: ownerID)
            boards.append(board)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameBoard(boardID: String, newName: String) async {
        do {
            let updated = try await scoutingService.renameBoard(boardID: boardID, newName: newName)
            replace(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBoard(boardID: String) async {
        do {
            try await scoutingService.deleteBoard(boardID: boardID)
            boards.removeAll { $0.id == boardID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addAthlete(boardID: String, athleteID: String) async {
        do {
            let updated = try await scoutingService.addAthlete(boardID: boardID, athleteID: athleteID)
            replace(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeAthlete(boardID: String, athleteID: String) async {
        do {
            let updated = try await scoutingService.removeAthlete(boardID: boardID, athleteID: athleteID)
            replace(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Athlete resolution

    /// Resolves the athlete IDs on a board (or across all boards) into full
    /// `User` records.
    ///
    /// Each ID is fetched directly rather than pulling the whole athlete
    /// directory and filtering it locally. The old approach silently dropped
    /// anyone the directory endpoint didn't happen to return — which becomes
    /// wrong the moment that list is paginated or capped — and it downloaded
    /// every athlete on the platform to display a handful.
    func loadBookmarkedAthletes(for boardID: String? = nil) async {
        let athleteIDs: [String]
        if let boardID, let board = boards.first(where: { $0.id == boardID }) {
            athleteIDs = board.athleteIDs
        } else {
            athleteIDs = Array(Set(boards.flatMap(\.athleteIDs)))
        }
        guard !athleteIDs.isEmpty else {
            bookmarkedAthletes = []
            return
        }

        // Board order is meaningless to the user, so present alphabetically.
        // A profile that fails to resolve (deleted account) is skipped rather
        // than failing the whole board.
        let resolved = await withTaskGroup(of: User?.self) { group in
            for id in athleteIDs {
                group.addTask { [profileService] in
                    try? await profileService.fetchAthlete(id: id)
                }
            }
            var found: [User] = []
            for await athlete in group {
                if let athlete { found.append(athlete) }
            }
            return found
        }

        bookmarkedAthletes = resolved.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Helpers

    private func replace(_ board: ScoutingBoard) {
        if let idx = boards.firstIndex(where: { $0.id == board.id }) {
            boards[idx] = board
        } else {
            boards.append(board)
        }
    }
}
