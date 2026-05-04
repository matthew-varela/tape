import Foundation

/// `ScoutingBoard` is a recruiter's named list of athletes ("QB Targets",
/// "2026 Watchlist"). Locally we only carry the *IDs* of athletes; the
/// recruiter UI joins those against the user records it already has cached.
///
/// The backend, on the other hand, returns nested objects (`owner`,
/// `athletes`) for ergonomic API consumption. We support both encodings via
/// the custom `init(from:)` below so the same struct decodes either shape.
struct ScoutingBoard: Codable, Identifiable, Hashable {
    let id: String
    let ownerID: String
    var name: String
    var athleteIDs: [String]
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, createdAt
        case ownerID = "ownerId"
        case athleteIDs = "athleteIds"
        // Backend nesting:
        case owner, athletes
    }

    init(
        id: String = UUID().uuidString,
        ownerID: String,
        name: String = "My Board",
        athleteIDs: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.athleteIDs = athleteIDs
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now

        // Owner: nested object first (server) → flat ID (mocks).
        if let owner = try? c.decode(NestedUser.self, forKey: .owner) {
            ownerID = owner.id
        } else {
            ownerID = try c.decode(String.self, forKey: .ownerID)
        }

        // Athletes: nested array first (server) → flat IDs (mocks).
        if let athletes = try? c.decode([NestedUser].self, forKey: .athletes) {
            athleteIDs = athletes.map(\.id)
        } else {
            athleteIDs = try c.decodeIfPresent([String].self, forKey: .athleteIDs) ?? []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerID, forKey: .ownerID)
        try c.encode(name, forKey: .name)
        try c.encode(athleteIDs, forKey: .athleteIDs)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

/// Lightweight stand-in used only to grab IDs out of the server's nested
/// payloads. Marked `private` so it doesn't leak into other files.
private struct NestedUser: Decodable {
    let id: String
}
