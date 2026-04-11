import Foundation

struct MockData {

    // MARK: - Users

    static let athletes: [User] = [
        User(id: "ath-001", email: "jdoe@example.com", displayName: "John Doe",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath001",
             highSchool: "Pioneer HS", gradYear: 2026, sport: "Football",
             position: "QB", state: "MI", height: "6'2\"", weight: "195",
             fortyYardDash: "4.65", gpa: 3.7,
             profileViewsThisWeek: 14, profileViewerIDs: ["rec-001", "rec-002"]),

        User(id: "ath-002", email: "mwilliams@example.com", displayName: "Marcus Williams",
             role: .athlete, tier: .pro,
             profileImageURL: "https://i.pravatar.cc/300?u=ath002",
             highSchool: "Lincoln HS", gradYear: 2026, sport: "Football",
             position: "WR", state: "TX", height: "6'0\"", weight: "180",
             fortyYardDash: "4.42", gpa: 3.5,
             profileViewsThisWeek: 22, profileViewerIDs: ["rec-001", "rec-003", "brand-001"]),

        User(id: "ath-003", email: "tjohnson@example.com", displayName: "Tyler Johnson",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath003",
             highSchool: "Westfield HS", gradYear: 2027, sport: "Football",
             position: "RB", state: "CA", height: "5'11\"", weight: "205",
             fortyYardDash: "4.50", gpa: 3.2,
             profileViewsThisWeek: 8, profileViewerIDs: ["rec-002"]),

        User(id: "ath-004", email: "csmith@example.com", displayName: "Chris Smith",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath004",
             highSchool: "East Central HS", gradYear: 2026, sport: "Basketball",
             position: "PG", state: "OH", height: "6'1\"", weight: "175",
             fortyYardDash: nil, gpa: 3.9,
             profileViewsThisWeek: 5, profileViewerIDs: []),

        User(id: "ath-005", email: "dlee@example.com", displayName: "Derek Lee",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath005",
             highSchool: "Mater Dei HS", gradYear: 2026, sport: "Football",
             position: "DE", state: "CA", height: "6'4\"", weight: "240",
             fortyYardDash: "4.72", gpa: 3.1,
             profileViewsThisWeek: 18, profileViewerIDs: ["rec-001", "rec-003"]),

        User(id: "ath-006", email: "jbrown@example.com", displayName: "Jamal Brown",
             role: .athlete, tier: .pro,
             profileImageURL: "https://i.pravatar.cc/300?u=ath006",
             highSchool: "DeMatha Catholic", gradYear: 2027, sport: "Football",
             position: "CB", state: "MD", height: "5'11\"", weight: "175",
             fortyYardDash: "4.38", gpa: 3.6,
             profileViewsThisWeek: 31, profileViewerIDs: ["rec-001", "rec-002", "rec-003"]),

        User(id: "ath-007", email: "rgarcia@example.com", displayName: "Ryan Garcia",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath007",
             highSchool: "IMG Academy", gradYear: 2026, sport: "Football",
             position: "OT", state: "FL", height: "6'5\"", weight: "290",
             fortyYardDash: "5.10", gpa: 3.3,
             profileViewsThisWeek: 12, profileViewerIDs: ["rec-002"]),

        User(id: "ath-008", email: "kthomas@example.com", displayName: "Kyle Thomas",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath008",
             highSchool: "St. Thomas Aquinas", gradYear: 2027, sport: "Football",
             position: "S", state: "FL", height: "6'0\"", weight: "190",
             fortyYardDash: "4.48", gpa: 3.4,
             profileViewsThisWeek: 9, profileViewerIDs: []),

        User(id: "ath-009", email: "adavis@example.com", displayName: "Andre Davis",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath009",
             highSchool: "North Shore HS", gradYear: 2026, sport: "Football",
             position: "LB", state: "TX", height: "6'2\"", weight: "225",
             fortyYardDash: "4.55", gpa: 3.0,
             profileViewsThisWeek: 11, profileViewerIDs: ["rec-003"]),

        User(id: "ath-010", email: "nwilson@example.com", displayName: "Noah Wilson",
             role: .athlete, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=ath010",
             highSchool: "Southlake Carroll", gradYear: 2027, sport: "Football",
             position: "TE", state: "TX", height: "6'4\"", weight: "230",
             fortyYardDash: "4.68", gpa: 3.8,
             profileViewsThisWeek: 7, profileViewerIDs: [])
    ]

    static let recruiters: [User] = [
        User(id: "rec-001", email: "coachm@umich.edu", displayName: "Coach Martinez",
             role: .recruiter, tier: .pro,
             profileImageURL: "https://i.pravatar.cc/300?u=rec001",
             organization: "University of Michigan", title: "Recruiting Coordinator"),

        User(id: "rec-002", email: "coachs@osu.edu", displayName: "Coach Stevens",
             role: .recruiter, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=rec002",
             organization: "Ohio State University", title: "Defensive Coordinator"),

        User(id: "rec-003", email: "coachw@bama.edu", displayName: "Coach Washington",
             role: .recruiter, tier: .pro,
             profileImageURL: "https://i.pravatar.cc/300?u=rec003",
             organization: "University of Alabama", title: "Head Coach")
    ]

    static let brands: [User] = [
        User(id: "brand-001", email: "nil@gatorade.com", displayName: "Gatorade NIL",
             role: .brand, tier: .pro,
             profileImageURL: "https://i.pravatar.cc/300?u=brand001",
             organization: "Gatorade", title: "NIL Partnerships"),

        User(id: "brand-002", email: "nil@underarmour.com", displayName: "Under Armour NIL",
             role: .brand, tier: .free,
             profileImageURL: "https://i.pravatar.cc/300?u=brand002",
             organization: "Under Armour", title: "NIL Partnerships")
    ]

    static var allUsers: [User] { athletes + recruiters + brands }

    // MARK: - Videos

    static let sampleVideoURLs = [
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
    ]

    static let videos: [Video] = {
        var vids: [Video] = []
        let playTypes = ["Deep Pass", "Rushing TD", "Pick Six", "Sack", "Screen Pass",
                         "Punt Return", "Goal Line Stand", "Interception", "Hurdle", "Stiff Arm"]

        for (index, athlete) in athletes.enumerated() {
            let tapeVideo = Video(
                id: "vid-tape-\(index + 1)",
                athleteID: athlete.id,
                videoURL: sampleVideoURLs[index % sampleVideoURLs.count],
                category: .tape,
                tags: [athlete.sport ?? "Football", athlete.position ?? "", playTypes[index]],
                caption: "\(playTypes[index]) vs. rival game",
                createdAt: Date().addingTimeInterval(Double(-index * 86400)),
                isPinned: index == 1,
                athleteName: athlete.displayName,
                athleteSchool: athlete.highSchool ?? "",
                athleteGradYear: athlete.gradYear ?? 2026,
                athletePosition: athlete.position ?? "",
                athleteProfileImageURL: athlete.profileImageURL
            )
            vids.append(tapeVideo)

            let cultureVideo = Video(
                id: "vid-culture-\(index + 1)",
                athleteID: athlete.id,
                videoURL: sampleVideoURLs[(index + 2) % sampleVideoURLs.count],
                category: .culture,
                tags: ["Workout", "Personality"],
                caption: "Game day prep 💪",
                createdAt: Date().addingTimeInterval(Double(-(index * 86400 + 43200))),
                athleteName: athlete.displayName,
                athleteSchool: athlete.highSchool ?? "",
                athleteGradYear: athlete.gradYear ?? 2026,
                athletePosition: athlete.position ?? "",
                athleteProfileImageURL: athlete.profileImageURL
            )
            vids.append(cultureVideo)
        }
        return vids
    }()

    // MARK: - Conversations & Messages

    static let conversations: [Conversation] = [
        Conversation(
            id: "conv-001",
            participantIDs: ["rec-001", "ath-001"],
            participantNames: ["rec-001": "Coach Martinez", "ath-001": "John Doe"],
            participantImageURLs: ["rec-001": "https://i.pravatar.cc/300?u=rec001", "ath-001": "https://i.pravatar.cc/300?u=ath001"],
            lastMessage: "Impressive tape, John. Let's set up a call.",
            lastMessageDate: Date().addingTimeInterval(-3600),
            unreadCount: 1,
            initiatedByRole: .recruiter
        ),
        Conversation(
            id: "conv-002",
            participantIDs: ["rec-003", "ath-002"],
            participantNames: ["rec-003": "Coach Washington", "ath-002": "Marcus Williams"],
            participantImageURLs: ["rec-003": "https://i.pravatar.cc/300?u=rec003", "ath-002": "https://i.pravatar.cc/300?u=ath002"],
            lastMessage: "We'd love to have you visit campus this spring.",
            lastMessageDate: Date().addingTimeInterval(-7200),
            unreadCount: 0,
            initiatedByRole: .recruiter
        ),
        Conversation(
            id: "conv-003",
            participantIDs: ["brand-001", "ath-002"],
            participantNames: ["brand-001": "Gatorade NIL", "ath-002": "Marcus Williams"],
            participantImageURLs: ["brand-001": "https://i.pravatar.cc/300?u=brand001", "ath-002": "https://i.pravatar.cc/300?u=ath002"],
            lastMessage: "We have an NIL opportunity we'd like to discuss.",
            lastMessageDate: Date().addingTimeInterval(-14400),
            unreadCount: 2,
            initiatedByRole: .brand
        )
    ]

    static let messages: [Message] = [
        Message(id: "msg-001", conversationID: "conv-001", senderID: "rec-001",
                text: "Hey John, I saw your highlight reel. Really impressive arm talent.",
                sentAt: Date().addingTimeInterval(-7200), isRead: true),
        Message(id: "msg-002", conversationID: "conv-001", senderID: "ath-001",
                text: "Thank you Coach! I've been working hard this offseason.",
                sentAt: Date().addingTimeInterval(-5400), isRead: true),
        Message(id: "msg-003", conversationID: "conv-001", senderID: "rec-001",
                text: "Impressive tape, John. Let's set up a call.",
                sentAt: Date().addingTimeInterval(-3600), isRead: false),

        Message(id: "msg-004", conversationID: "conv-002", senderID: "rec-003",
                text: "Marcus, your film stands out. Speed kills and you have it.",
                sentAt: Date().addingTimeInterval(-10800), isRead: true),
        Message(id: "msg-005", conversationID: "conv-002", senderID: "ath-002",
                text: "Appreciate that Coach! Alabama is my dream school.",
                sentAt: Date().addingTimeInterval(-9000), isRead: true),
        Message(id: "msg-006", conversationID: "conv-002", senderID: "rec-003",
                text: "We'd love to have you visit campus this spring.",
                sentAt: Date().addingTimeInterval(-7200), isRead: true),

        Message(id: "msg-007", conversationID: "conv-003", senderID: "brand-001",
                text: "Hi Marcus! Your content is exactly what our brand is looking for.",
                sentAt: Date().addingTimeInterval(-18000), isRead: true),
        Message(id: "msg-008", conversationID: "conv-003", senderID: "brand-001",
                text: "We have an NIL opportunity we'd like to discuss.",
                sentAt: Date().addingTimeInterval(-14400), isRead: false),
    ]

    // MARK: - Scouting Boards

    static let scoutingBoards: [ScoutingBoard] = [
        ScoutingBoard(id: "board-001", ownerID: "rec-001", name: "Top QBs 2026",
                      athleteIDs: ["ath-001"], createdAt: Date().addingTimeInterval(-86400 * 7)),
        ScoutingBoard(id: "board-002", ownerID: "rec-001", name: "Skill Positions",
                      athleteIDs: ["ath-002", "ath-003"], createdAt: Date().addingTimeInterval(-86400 * 3)),
    ]

    // MARK: - Tags

    static let availableTags: [VideoTag] = [
        VideoTag(id: "tag-fb", label: "Football", category: .sport),
        VideoTag(id: "tag-bb", label: "Basketball", category: .sport),
        VideoTag(id: "tag-bs", label: "Baseball", category: .sport),
        VideoTag(id: "tag-sc", label: "Soccer", category: .sport),
        VideoTag(id: "tag-tk", label: "Track & Field", category: .sport),

        VideoTag(id: "tag-qb", label: "QB", category: .position),
        VideoTag(id: "tag-wr", label: "WR", category: .position),
        VideoTag(id: "tag-rb", label: "RB", category: .position),
        VideoTag(id: "tag-te", label: "TE", category: .position),
        VideoTag(id: "tag-ol", label: "OL", category: .position),
        VideoTag(id: "tag-dl", label: "DL", category: .position),
        VideoTag(id: "tag-lb", label: "LB", category: .position),
        VideoTag(id: "tag-cb", label: "CB", category: .position),
        VideoTag(id: "tag-s", label: "S", category: .position),
        VideoTag(id: "tag-pg", label: "PG", category: .position),

        VideoTag(id: "tag-dp", label: "Deep Pass", category: .playType),
        VideoTag(id: "tag-rtd", label: "Rushing TD", category: .playType),
        VideoTag(id: "tag-p6", label: "Pick Six", category: .playType),
        VideoTag(id: "tag-sk", label: "Sack", category: .playType),
        VideoTag(id: "tag-sp", label: "Screen Pass", category: .playType),
        VideoTag(id: "tag-int", label: "Interception", category: .playType),
        VideoTag(id: "tag-dunk", label: "Dunk", category: .playType),
    ]
}
