import Foundation

/// REST-backed messaging implementation. All five protocol methods are tiny
/// passthroughs to `APIClient`; the real work (auth header, JSON encoding,
/// status-code handling) lives there.
///
/// Endpoints documented in `BACKEND_CONTRACT.md`:
///   - `GET    /api/conversations?userId={id}`
///   - `GET    /api/conversations/{id}/messages`
///   - `POST   /api/conversations/{id}/messages`
///   - `POST   /api/conversations`
final class APIMessageService: MessageServiceProtocol {
    private let client = APIClient.shared

    func fetchConversations(for userID: String) async throws -> [Conversation] {
        try await client.get("/api/conversations", query: ["userId": userID])
    }

    func fetchMessages(for conversationID: String) async throws -> [Message] {
        try await client.get("/api/conversations/\(conversationID)/messages")
    }

    func sendMessage(conversationID: String, senderID: String, text: String) async throws -> Message {
        // Inline body type keeps the request schema co-located with the call
        // site so it's obvious which fields are sent over the wire.
        struct SendBody: Encodable {
            let senderId: String
            let text: String
        }

        let body = SendBody(senderId: senderID, text: text)
        return try await client.post("/api/conversations/\(conversationID)/messages", body: body)
    }

    func startConversation(
        initiatorID: String,
        recipientID: String,
        initiatorName: String,
        recipientName: String,
        initiatorRole: UserRole
    ) async throws -> Conversation {
        // Server idempotently returns the existing conversation if one
        // already exists between this pair.
        struct StartBody: Encodable {
            let initiatorId: String
            let recipientId: String
        }

        let body = StartBody(initiatorId: initiatorID, recipientId: recipientID)
        return try await client.post("/api/conversations", body: body)
    }
}
