import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let participantIDs: [String]
    let participantNames: [String: String]
    let participantImageURLs: [String: String?]
    var lastMessage: String
    var lastMessageDate: Date
    var unreadCount: Int
    let initiatedByRole: UserRole

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

    func otherParticipantName(currentUserID: String) -> String {
        let otherID = participantIDs.first { $0 != currentUserID } ?? ""
        return participantNames[otherID] ?? "Unknown"
    }

    func otherParticipantImageURL(currentUserID: String) -> String? {
        let otherID = participantIDs.first { $0 != currentUserID } ?? ""
        return participantImageURLs[otherID] ?? nil
    }
}

struct Message: Codable, Identifiable, Hashable {
    let id: String
    let conversationID: String
    let senderID: String
    let text: String
    let sentAt: Date
    var isRead: Bool

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
}
