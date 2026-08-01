import Foundation

/// The tags an athlete can attach to a clip at upload time.
///
/// This lives in the app rather than behind an API endpoint on purpose: the
/// list is small, changes rarely, and an athlete mid-upload should never be
/// blocked by a network round trip to find out what a "QB" is. It moved out of
/// `MockData` because the upload screen was reading it from there in
/// production — the one place mock data had leaked into a shipping code path.
///
/// Tags are grouped so the picker can render one row of chips per group.
enum TagCatalog {
    static let all: [VideoTag] = sports + positions + playTypes

    static func tags(in category: VideoTag.TagCategory) -> [VideoTag] {
        all.filter { $0.category == category }
    }

    /// Position and play-type tags relevant to a sport, plus anything not tied
    /// to one. A football player shouldn't have to scroll past "Three-Pointer"
    /// to find "Pick Six".
    static func tags(in category: VideoTag.TagCategory, sport: String?) -> [VideoTag] {
        let candidates = tags(in: category)
        guard let sport, let relevant = sportTagIDs[sport] else { return candidates }
        return candidates.filter { relevant.contains($0.id) }
    }

    // MARK: - Sports

    static let sports: [VideoTag] = [
        VideoTag(id: "tag-fb", label: "Football", category: .sport),
        VideoTag(id: "tag-bb", label: "Basketball", category: .sport),
        VideoTag(id: "tag-bs", label: "Baseball", category: .sport),
        VideoTag(id: "tag-sc", label: "Soccer", category: .sport),
        VideoTag(id: "tag-tk", label: "Track & Field", category: .sport),
    ]

    // MARK: - Positions

    static let positions: [VideoTag] = [
        // Football
        VideoTag(id: "tag-qb", label: "QB", category: .position),
        VideoTag(id: "tag-wr", label: "WR", category: .position),
        VideoTag(id: "tag-rb", label: "RB", category: .position),
        VideoTag(id: "tag-te", label: "TE", category: .position),
        VideoTag(id: "tag-ol", label: "OL", category: .position),
        VideoTag(id: "tag-dl", label: "DL", category: .position),
        VideoTag(id: "tag-lb", label: "LB", category: .position),
        VideoTag(id: "tag-cb", label: "CB", category: .position),
        VideoTag(id: "tag-s", label: "S", category: .position),
        VideoTag(id: "tag-k", label: "K/P", category: .position),

        // Basketball
        VideoTag(id: "tag-pg", label: "PG", category: .position),
        VideoTag(id: "tag-sg", label: "SG", category: .position),
        VideoTag(id: "tag-sf", label: "SF", category: .position),
        VideoTag(id: "tag-pf", label: "PF", category: .position),
        VideoTag(id: "tag-c", label: "C", category: .position),

        // Baseball
        VideoTag(id: "tag-pitcher", label: "Pitcher", category: .position),
        VideoTag(id: "tag-catcher", label: "Catcher", category: .position),
        VideoTag(id: "tag-infield", label: "Infield", category: .position),
        VideoTag(id: "tag-outfield", label: "Outfield", category: .position),

        // Soccer
        VideoTag(id: "tag-gk", label: "Goalkeeper", category: .position),
        VideoTag(id: "tag-def", label: "Defender", category: .position),
        VideoTag(id: "tag-mid", label: "Midfielder", category: .position),
        VideoTag(id: "tag-fwd", label: "Forward", category: .position),

        // Track & Field
        VideoTag(id: "tag-sprint", label: "Sprints", category: .position),
        VideoTag(id: "tag-distance", label: "Distance", category: .position),
        VideoTag(id: "tag-jumps", label: "Jumps", category: .position),
        VideoTag(id: "tag-throws", label: "Throws", category: .position),
        VideoTag(id: "tag-hurdles", label: "Hurdles", category: .position),
    ]

    // MARK: - Play types

    static let playTypes: [VideoTag] = [
        // Football
        VideoTag(id: "tag-dp", label: "Deep Pass", category: .playType),
        VideoTag(id: "tag-rtd", label: "Rushing TD", category: .playType),
        VideoTag(id: "tag-p6", label: "Pick Six", category: .playType),
        VideoTag(id: "tag-sk", label: "Sack", category: .playType),
        VideoTag(id: "tag-sp", label: "Screen Pass", category: .playType),
        VideoTag(id: "tag-int", label: "Interception", category: .playType),
        VideoTag(id: "tag-tackle", label: "Big Hit", category: .playType),

        // Basketball
        VideoTag(id: "tag-dunk", label: "Dunk", category: .playType),
        VideoTag(id: "tag-three", label: "Three-Pointer", category: .playType),
        VideoTag(id: "tag-assist", label: "Assist", category: .playType),
        VideoTag(id: "tag-block", label: "Block", category: .playType),
        VideoTag(id: "tag-crossover", label: "Crossover", category: .playType),

        // Baseball
        VideoTag(id: "tag-hr", label: "Home Run", category: .playType),
        VideoTag(id: "tag-strikeout", label: "Strikeout", category: .playType),
        VideoTag(id: "tag-dplay", label: "Double Play", category: .playType),
        VideoTag(id: "tag-steal", label: "Stolen Base", category: .playType),

        // Soccer
        VideoTag(id: "tag-goal", label: "Goal", category: .playType),
        VideoTag(id: "tag-save", label: "Save", category: .playType),
        VideoTag(id: "tag-freekick", label: "Free Kick", category: .playType),
        VideoTag(id: "tag-nutmeg", label: "Nutmeg", category: .playType),

        // Track & Field
        VideoTag(id: "tag-pr", label: "Personal Record", category: .playType),
        VideoTag(id: "tag-finish", label: "Race Finish", category: .playType),

        // Any sport
        VideoTag(id: "tag-workout", label: "Workout", category: .playType),
        VideoTag(id: "tag-combine", label: "Combine", category: .playType),
    ]

    /// Which position and play-type tags belong to each sport. Anything not
    /// listed under a sport is treated as sport-agnostic and always shown.
    private static let sportTagIDs: [String: Set<String>] = [
        "Football": [
            "tag-qb", "tag-wr", "tag-rb", "tag-te", "tag-ol", "tag-dl",
            "tag-lb", "tag-cb", "tag-s", "tag-k",
            "tag-dp", "tag-rtd", "tag-p6", "tag-sk", "tag-sp", "tag-int",
            "tag-tackle", "tag-workout", "tag-combine",
        ],
        "Basketball": [
            "tag-pg", "tag-sg", "tag-sf", "tag-pf", "tag-c",
            "tag-dunk", "tag-three", "tag-assist", "tag-block", "tag-crossover",
            "tag-workout", "tag-combine",
        ],
        "Baseball": [
            "tag-pitcher", "tag-catcher", "tag-infield", "tag-outfield",
            "tag-hr", "tag-strikeout", "tag-dplay", "tag-steal",
            "tag-workout", "tag-combine",
        ],
        "Soccer": [
            "tag-gk", "tag-def", "tag-mid", "tag-fwd",
            "tag-goal", "tag-save", "tag-freekick", "tag-nutmeg",
            "tag-workout", "tag-combine",
        ],
        "Track & Field": [
            "tag-sprint", "tag-distance", "tag-jumps", "tag-throws", "tag-hurdles",
            "tag-pr", "tag-finish", "tag-workout", "tag-combine",
        ],
    ]
}
