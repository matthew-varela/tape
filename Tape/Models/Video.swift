import Foundation

enum VideoCategory: String, Codable, CaseIterable, Identifiable {
    case tape = "Tape"
    case culture = "Culture/NIL"

    var id: String { rawValue }
}

struct VideoTag: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let category: TagCategory

    enum TagCategory: String, Codable, CaseIterable {
        case sport
        case position
        case playType
    }
}

struct Video: Codable, Identifiable, Hashable {
    let id: String
    let athleteID: String
    let videoURL: String
    var thumbnailURL: String?
    let category: VideoCategory
    let tags: [String]
    let caption: String
    let createdAt: Date
    var isPinned: Bool

    // Denormalized athlete info for feed overlay
    let athleteName: String
    let athleteSchool: String
    let athleteGradYear: Int
    let athletePosition: String
    let athleteProfileImageURL: String?

    init(
        id: String = UUID().uuidString,
        athleteID: String,
        videoURL: String,
        thumbnailURL: String? = nil,
        category: VideoCategory = .tape,
        tags: [String] = [],
        caption: String = "",
        createdAt: Date = .now,
        isPinned: Bool = false,
        athleteName: String,
        athleteSchool: String,
        athleteGradYear: Int,
        athletePosition: String,
        athleteProfileImageURL: String? = nil
    ) {
        self.id = id
        self.athleteID = athleteID
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.category = category
        self.tags = tags
        self.caption = caption
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.athleteName = athleteName
        self.athleteSchool = athleteSchool
        self.athleteGradYear = athleteGradYear
        self.athletePosition = athletePosition
        self.athleteProfileImageURL = athleteProfileImageURL
    }
}
