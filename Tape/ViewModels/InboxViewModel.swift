import SwiftUI

/// `InboxViewModel` owns the messaging data and the polling loops that keep it
/// fresh. Two views share this class:
///   - `InboxListView` polls the conversation list,
///   - `ChatThreadView` polls a single thread's messages.
///
/// We don't have WebSockets or push updates yet, so polling every 8 seconds
/// gives the user a live-feeling inbox without overloading the backend. Pull-
/// to-refresh on the list complements polling for impatient users.
@Observable
@MainActor
final class InboxViewModel {
    var conversations: [Conversation] = []
    var currentMessages: [Message] = []
    var isLoading = false
    var errorMessage: String?

    private let messageService: MessageServiceProtocol

    /// The two polling Tasks. We keep them as properties so we can cancel them
    /// when the view disappears or when polling moves to a new conversation.
    private var conversationPollingTask: Task<Void, Never>?
    private var messagePollingTask: Task<Void, Never>?

    /// How long to wait between poll cycles. 8 seconds is a balance between
    /// "feels live" and "doesn't burn battery / hammer the server".
    private let pollInterval: Duration = .seconds(8)

    init(messageService: MessageServiceProtocol = MockMessageService()) {
        self.messageService = messageService
    }

    deinit {
        conversationPollingTask?.cancel()
        messagePollingTask?.cancel()
    }

    // MARK: - One-shot loads

    func loadConversations(userID: String) async {
        isLoading = conversations.isEmpty
        do {
            let fetched = try await messageService.fetchConversations(for: userID)
            mergeConversations(fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMessages(conversationID: String) async {
        do {
            let fetched = try await messageService.fetchMessages(for: conversationID)
            mergeMessages(fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Polling

    /// Begins refetching the user's conversations every `pollInterval`. Idempotent
    /// — calling it again cancels the previous loop. Safe to call from `.task`.
    func startConversationPolling(userID: String) {
        conversationPollingTask?.cancel()
        conversationPollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: self.pollInterval)
                    guard !Task.isCancelled else { return }
                    let fetched = try await self.messageService.fetchConversations(for: userID)
                    await MainActor.run { self.mergeConversations(fetched) }
                } catch is CancellationError {
                    return
                } catch {
                    // Swallow transient network errors — keep polling so when
                    // the network recovers we automatically resume.
                }
            }
        }
    }

    /// Begins refetching a single conversation's messages every `pollInterval`.
    func startMessagePolling(conversationID: String) {
        messagePollingTask?.cancel()
        messagePollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: self.pollInterval)
                    guard !Task.isCancelled else { return }
                    let fetched = try await self.messageService.fetchMessages(for: conversationID)
                    await MainActor.run { self.mergeMessages(fetched) }
                } catch is CancellationError {
                    return
                } catch {
                    // Same as above — keep trying.
                }
            }
        }
    }

    func stopPolling() {
        conversationPollingTask?.cancel()
        messagePollingTask?.cancel()
        conversationPollingTask = nil
        messagePollingTask = nil
    }

    // MARK: - Mutation

    func sendMessage(conversationID: String, senderID: String, text: String) async {
        do {
            let message = try await messageService.sendMessage(
                conversationID: conversationID,
                senderID: senderID,
                text: text
            )
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

    // MARK: - Private merges

    /// Replaces the conversation list with the freshly fetched batch but keeps
    /// our existing array if the contents are identical — that prevents
    /// SwiftUI from re-diffing the List on every poll cycle when nothing
    /// actually changed.
    private func mergeConversations(_ fetched: [Conversation]) {
        guard fetched != conversations else { return }
        conversations = fetched
    }

    /// Same idea for messages: only mutate when the server returned something
    /// new. We compare by ID set to avoid date-sensitivity from the server.
    private func mergeMessages(_ fetched: [Message]) {
        let currentIDs = Set(currentMessages.map(\.id))
        let fetchedIDs = Set(fetched.map(\.id))
        guard currentIDs != fetchedIDs else { return }
        currentMessages = fetched
    }
}
