import Foundation

/// `Conversation` represents a 1-on-1 thread (today; group threads would
/// require expanding this). It denormalizes participant names and avatars so
/// the inbox list can render without follow-up user lookups.
///
/// `participantImageURLs` is `[String: String?]` rather than `[String: String]`
/// because the backend may emit an image URL or `null` per participant. We
/// preserve the `null` so the UI can show a placeholder when there's no
/// avatar set yet.
struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let participantIDs: [String]
    let participantNames: [String: String]
    let participantImageURLs: [String: String?]
    var lastMessage: String
    var lastMessageDate: Date
    var unreadCount: Int
    let initiatedByRole: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case participantIDs = "participantIds"
        case participantNames
        case participantImageURLs = "participantImageUrls"
        case lastMessage, lastMessageDate, unreadCount, initiatedByRole
    }

    init(
        id: String = UUID().uuidString,
        participantIDs: [String],
        participantNames: [String: String],
        participantImageURLs: [String: String?] = [:],
        lastMessage: String = "",
        lastMessageDate: Date = .now,
        unreadCount: Int = 0,
        initiatedByRole: UserRole = .recruiter
    ) {
        self.id = id
        self.participantIDs = participantIDs
        self.participantNames = participantNames
        self.participantImageURLs = participantImageURLs
        self.lastMessage = lastMessage
        self.lastMessageDate = lastMessageDate
        self.unreadCount = unreadCount
        self.initiatedByRole = initiatedByRole
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        participantIDs = try c.decodeIfPresent([String].self, forKey: .participantIDs) ?? []
        participantNames = try c.decodeIfPresent([String: String].self, forKey: .participantNames) ?? [:]

        // Backend sends [String: String]; we promote to [String: String?] so
        // the rest of the app deals with one shape.
        if let urls = try? c.decode([String: String].self, forKey: .participantImageURLs) {
            participantImageURLs = urls.mapValues { Optional($0) }
        } else {
            participantImageURLs = [:]
        }

        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage) ?? ""
        lastMessageDate = try c.decodeIfPresent(Date.self, forKey: .lastMessageDate) ?? .now
        unreadCount = try c.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        initiatedByRole = try c.decodeIfPresent(UserRole.self, forKey: .initiatedByRole) ?? .recruiter
    }

    /// The other person in this thread — used to open their profile from the
    /// inbox or chat title.
    func otherParticipantID(currentUserID: String) -> String {
        participantIDs.first { $0 != currentUserID } ?? ""
    }

    /// Looks up the *other* participant's display name. The inbox list and
    /// chat title both use this so a thread shows "Jane Coach", never "you".
    func otherParticipantName(currentUserID: String) -> String {
        let otherID = otherParticipantID(currentUserID: currentUserID)
        return participantNames[otherID] ?? "Unknown"
    }

    /// Same idea for the avatar URL (returns nil if the other participant
    /// has no image set).
    func otherParticipantImageURL(currentUserID: String) -> String? {
        let otherID = otherParticipantID(currentUserID: currentUserID)
        return participantImageURLs[otherID] ?? nil
    }
}

/// Single message inside a `Conversation`. `isRead` powers the read-receipt
/// checkmark for Pro users.
struct Message: Codable, Identifiable, Hashable {
    let id: String
    let conversationID: String
    let senderID: String
    let text: String
    let sentAt: Date
    var isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversationId"
        case senderID = "senderId"
        case text, sentAt, isRead
    }

    init(
        id: String = UUID().uuidString,
        conversationID: String,
        senderID: String,
        text: String,
        sentAt: Date = .now,
        isRead: Bool = false
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.text = text
        self.sentAt = sentAt
        self.isRead = isRead
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        conversationID = try c.decode(String.self, forKey: .conversationID)
        senderID = try c.decode(String.self, forKey: .senderID)
        text = try c.decode(String.self, forKey: .text)
        sentAt = try c.decodeIfPresent(Date.self, forKey: .sentAt) ?? .now
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
    }
}
