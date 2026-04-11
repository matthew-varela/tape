import Foundation

struct ScoutingBoard: Codable, Identifiable, Hashable {
    let id: String
    let ownerID: String
    var name: String
    var athleteIDs: [String]
    var createdAt: Date

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
}
