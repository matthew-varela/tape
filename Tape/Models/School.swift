import Foundation
import SwiftUI

/// One FBS program.
///
/// Schools are static reference data, so the catalog ships with the app as a
/// bundled JSON file rather than living in Postgres. The database stores only
/// the selected `id`s (`User.schoolId`, `User.targetSchoolIDs`), which keeps
/// the picker instant, avoids a join on every profile read, and means renaming
/// a program or fixing a logo never needs a migration.
///
/// `id` is the ESPN team id, which is also what the logo CDN is keyed on.
struct School: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let mascot: String
    let abbreviation: String
    let conference: String
    let primaryColor: String
    let logoURL: String

    enum CodingKeys: String, CodingKey {
        case id, name, mascot, abbreviation, conference, primaryColor
        case logoURL = "logoUrl"
    }

    var logo: URL? { URL(string: logoURL) }

    /// Brand color, used behind the logo so light marks stay visible on the
    /// app's dark background.
    var tint: Color { Color(hex: primaryColor) ?? .tapeCardBg }
}

/// Loads and indexes the bundled school catalog.
///
/// The file is read once on first access and kept for the process lifetime —
/// it's ~30KB and every profile render needs lookups by id.
enum SchoolCatalog {
    static let all: [School] = load()

    private static let byID: [String: School] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static func school(id: String?) -> School? {
        guard let id else { return nil }
        return byID[id]
    }

    static func schools(ids: [String]) -> [School] {
        ids.compactMap { byID[$0] }
    }

    /// Case- and diacritic-insensitive match across name, mascot, abbreviation,
    /// and conference so "cinci", "buckeyes", and "SEC" all find something.
    static func search(_ query: String) -> [School] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { school in
            [school.name, school.mascot, school.abbreviation, school.conference].contains {
                $0.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    private static func load() -> [School] {
        guard let url = Bundle.main.url(forResource: "fbs-schools", withExtension: "json") else {
            assertionFailure("fbs-schools.json is missing from the app bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([School].self, from: data)
        } catch {
            assertionFailure("fbs-schools.json could not be decoded: \(error)")
            return []
        }
    }
}

extension Color {
    /// Parses the `#rrggbb` strings used in the school catalog.
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
