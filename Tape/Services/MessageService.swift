import Foundation

protocol MessageServiceProtocol {
    func fetchConversations(for userID: String) async throws -> [Conversation]
    func fetchMessages(for conversationID: String) async throws -> [Message]
    func sendMessage(conversationID: String, senderID: String, text: String) async throws -> Message
    func startConversation(initiatorID: String, recipientID: String, initiatorName: String, recipientName: String, initiatorRole: UserRole) async throws -> Conversation
}

final class MockMessageService: MessageServiceProtocol {
    private var conversations = MockData.conversations
    private var messages = MockData.messages

    func fetchConversations(for userID: String) async throws -> [Conversation] {
        try await Task.sleep(for: .milliseconds(200))
        return conversations
            .filter { $0.participantIDs.contains(userID) }
            .sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    func fetchMessages(for conversationID: String) async throws -> [Message] {
        try await Task.sleep(for: .milliseconds(200))
        return messages
            .filter { $0.conversationID == conversationID }
            .sorted { $0.sentAt < $1.sentAt }
    }

    func sendMessage(conversationID: String, senderID: String, text: String) async throws -> Message {
        try await Task.sleep(for: .milliseconds(200))
        let message = Message(conversationID: conversationID, senderID: senderID, text: text)
        messages.append(message)

        if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[idx].lastMessage = text
            conversations[idx].lastMessageDate = message.sentAt
        }
        return message
    }

    func startConversation(initiatorID: String, recipientID: String, initiatorName: String, recipientName: String, initiatorRole: UserRole) async throws -> Conversation {
        try await Task.sleep(for: .milliseconds(200))
        if let existing = conversations.first(where: {
            $0.participantIDs.contains(initiatorID) && $0.participantIDs.contains(recipientID)
        }) {
            return existing
        }

        let conversation = Conversation(
            participantIDs: [initiatorID, recipientID],
            participantNames: [initiatorID: initiatorName, recipientID: recipientName],
            initiatedByRole: initiatorRole
        )
        conversations.append(conversation)
        return conversation
    }
}
