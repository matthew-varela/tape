import SwiftUI

@Observable
final class InboxViewModel {
    var conversations: [Conversation] = []
    var currentMessages: [Message] = []
    var isLoading = false
    var errorMessage: String?

    private let messageService: MessageServiceProtocol

    init(messageService: MessageServiceProtocol = MockMessageService()) {
        self.messageService = messageService
    }

    func loadConversations(userID: String) async {
        isLoading = true
        do {
            conversations = try await messageService.fetchConversations(for: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMessages(conversationID: String) async {
        do {
            currentMessages = try await messageService.fetchMessages(for: conversationID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendMessage(conversationID: String, senderID: String, text: String) async {
        do {
            let message = try await messageService.sendMessage(conversationID: conversationID, senderID: senderID, text: text)
            currentMessages.append(message)
            if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
                conversations[idx].lastMessage = text
                conversations[idx].lastMessageDate = message.sentAt
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startConversation(initiator: User, recipientID: String, recipientName: String) async -> Conversation? {
        do {
            let conversation = try await messageService.startConversation(
                initiatorID: initiator.id,
                recipientID: recipientID,
                initiatorName: initiator.displayName,
                recipientName: recipientName,
                initiatorRole: initiator.role
            )
            if !conversations.contains(where: { $0.id == conversation.id }) {
                conversations.insert(conversation, at: 0)
            }
            return conversation
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func canInitiateMessage(currentUser: User) -> Bool {
        guard currentUser.role == .recruiter || currentUser.role == .brand else { return false }
        if currentUser.tier == .free && currentUser.dmsSentThisMonth >= 10 { return false }
        return true
    }
}
