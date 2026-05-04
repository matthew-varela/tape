import Foundation

/// `VideoCategory` splits an athlete's clips into two surfaces shown on their
/// profile: gameplay footage ("Tape") and lifestyle/NIL content ("Culture").
/// The backend stores the value uppercased; we accept both forms for safety.
enum VideoCategory: String, Codable, CaseIterable, Identifiable {
    case tape = "Tape"
    case culture = "Culture/NIL"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let value = VideoCategory(rawValue: raw) {
            self = value
        } else {
            switch raw.uppercased() {
            case "TAPE": self = .tape
            case "CULTURE", "CULTURE_NIL": self = .culture
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown VideoCategory: \(raw)"
                )
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .tape: try container.encode("TAPE")
        case .culture: try container.encode("CULTURE")
        }
    }
}

/// `VideoTag` represents a chip in the upload tag selector. Tags are grouped
/// by `TagCategory` (sport / position / playType) so the UI can render each
/// group as its own row of chips.
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

/// `Video` is one published clip. It carries everything the feed and profile
/// grid need to render without an extra round trip — the athlete's name,
/// school, position, and avatar are denormalized onto the row so the feed
/// doesn't need a join.
///
/// `videoURL` and `thumbnailURL` are public HTTPS URLs returned by the
/// upload pipeline (Firebase Storage download URLs in production).
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

    let athleteName: String
    let athleteSchool: String
    let athleteGradYear: Int
    let athletePosition: String
    let athleteProfileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case athleteID = "athleteId"
        case videoURL = "videoUrl"
        case thumbnailURL = "thumbnailUrl"
        case category, tags, caption, createdAt, isPinned
        case athleteName, athleteSchool, athleteGradYear, athletePosition
        case athleteProfileImageURL = "athleteProfileImageUrl"
    }

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        athleteID = try c.decode(String.self, forKey: .athleteID)
        videoURL = try c.decode(String.self, forKey: .videoURL)
        thumbnailURL = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
        category = try c.decodeIfPresent(VideoCategory.self, forKey: .category) ?? .tape
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        caption = try c.decodeIfPresent(String.self, forKey: .caption) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        athleteName = try c.decodeIfPresent(String.self, forKey: .athleteName) ?? ""
        athleteSchool = try c.decodeIfPresent(String.self, forKey: .athleteSchool) ?? ""
        athleteGradYear = try c.decodeIfPresent(Int.self, forKey: .athleteGradYear) ?? 2026
        athletePosition = try c.decodeIfPresent(String.self, forKey: .athletePosition) ?? ""
        athleteProfileImageURL = try c.decodeIfPresent(String.self, forKey: .athleteProfileImageURL)
    }
}
