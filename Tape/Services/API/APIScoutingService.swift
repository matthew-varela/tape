import Foundation

/// REST-backed scouting board implementation. Endpoints (see
/// `BACKEND_CONTRACT.md`):
///   - `GET    /api/scouting-boards?ownerId={id}`      list
///   - `POST   /api/scouting-boards`                    create
///   - `PATCH  /api/scouting-boards/{id}`               rename
///   - `DELETE /api/scouting-boards/{id}`               delete
///   - `POST   /api/scouting-boards/{id}/athletes`      add athlete
///   - `DELETE /api/scouting-boards/{id}/athletes/{aid}` remove athlete
final class APIScoutingService: ScoutingServiceProtocol {
    private let client = APIClient.shared

    func fetchBoards(ownerID: String) async throws -> [ScoutingBoard] {
        try await client.get("/api/scouting-boards", query: ["ownerId": ownerID])
    }

    func createBoard(name: String, ownerID: String) async throws -> ScoutingBoard {
        struct Body: Encodable { let ownerId: String; let name: String }
        return try await client.post("/api/scouting-boards", body: Body(ownerId: ownerID, name: name))
    }

    func renameBoard(boardID: String, newName: String) async throws -> ScoutingBoard {
        struct Body: Encodable { let name: String }
        return try await client.patch("/api/scouting-boards/\(boardID)", body: Body(name: newName))
    }

    func deleteBoard(boardID: String) async throws {
        try await client.deleteVoid("/api/scouting-boards/\(boardID)")
    }

    func addAthlete(boardID: String, athleteID: String) async throws -> ScoutingBoard {
        struct Body: Encodable { let athleteId: String }
        return try await client.post(
            "/api/scouting-boards/\(boardID)/athletes",
            body: Body(athleteId: athleteID)
        )
    }

    func removeAthlete(boardID: String, athleteID: String) async throws -> ScoutingBoard {
        try await client.delete("/api/scouting-boards/\(boardID)/athletes/\(athleteID)")
    }
}
