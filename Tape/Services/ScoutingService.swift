import Foundation

/// `ScoutingServiceProtocol` is the API contract for managing recruiters' and
/// brands' "scouting boards" — named lists of athletes they are tracking.
///
/// Mirrors the shape of `VideoServiceProtocol` and friends so view models can
/// be written the same way: take a protocol in init, swap to a mock for
/// previews, swap to the API impl for production.
protocol ScoutingServiceProtocol {
    /// Returns every board owned by the calling user.
    func fetchBoards(ownerID: String) async throws -> [ScoutingBoard]

    /// Creates a new empty board with the given name. Returns the saved board
    /// (with the server-issued ID and createdAt timestamp).
    func createBoard(name: String, ownerID: String) async throws -> ScoutingBoard

    /// Renames a board. Returns the updated board.
    func renameBoard(boardID: String, newName: String) async throws -> ScoutingBoard

    /// Deletes a board (and its membership).
    func deleteBoard(boardID: String) async throws

    /// Adds an athlete to a board. Returns the updated board.
    func addAthlete(boardID: String, athleteID: String) async throws -> ScoutingBoard

    /// Removes an athlete from a board. Returns the updated board.
    func removeAthlete(boardID: String, athleteID: String) async throws -> ScoutingBoard
}

// MARK: - MockScoutingService

/// Backed by `MockData.scoutingBoards`. Mutations live only in memory.
final class MockScoutingService: ScoutingServiceProtocol {
    private var boards = MockData.scoutingBoards

    func fetchBoards(ownerID: String) async throws -> [ScoutingBoard] {
        try await Task.sleep(for: .milliseconds(150))
        return boards.filter { $0.ownerID == ownerID }
    }

    func createBoard(name: String, ownerID: String) async throws -> ScoutingBoard {
        try await Task.sleep(for: .milliseconds(150))
        let board = ScoutingBoard(ownerID: ownerID, name: name)
        boards.append(board)
        return board
    }

    func renameBoard(boardID: String, newName: String) async throws -> ScoutingBoard {
        try await Task.sleep(for: .milliseconds(100))
        guard let idx = boards.firstIndex(where: { $0.id == boardID }) else {
            throw ScoutingServiceError.boardNotFound
        }
        boards[idx].name = newName
        return boards[idx]
    }

    func deleteBoard(boardID: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        boards.removeAll { $0.id == boardID }
    }

    func addAthlete(boardID: String, athleteID: String) async throws -> ScoutingBoard {
        try await Task.sleep(for: .milliseconds(100))
        guard let idx = boards.firstIndex(where: { $0.id == boardID }) else {
            throw ScoutingServiceError.boardNotFound
        }
        if !boards[idx].athleteIDs.contains(athleteID) {
            boards[idx].athleteIDs.append(athleteID)
        }
        return boards[idx]
    }

    func removeAthlete(boardID: String, athleteID: String) async throws -> ScoutingBoard {
        try await Task.sleep(for: .milliseconds(100))
        guard let idx = boards.firstIndex(where: { $0.id == boardID }) else {
            throw ScoutingServiceError.boardNotFound
        }
        boards[idx].athleteIDs.removeAll { $0 == athleteID }
        return boards[idx]
    }
}

enum ScoutingServiceError: LocalizedError {
    case boardNotFound

    var errorDescription: String? {
        switch self {
        case .boardNotFound: "Scouting board not found."
        }
    }
}
