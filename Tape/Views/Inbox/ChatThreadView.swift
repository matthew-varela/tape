import SwiftUI

/// Single-conversation chat screen. Displays the message bubbles, polls for
/// updates from the other participant, and writes new messages.
///
/// Sending also bumps the recruiter/brand "DMs sent this month" counter via
/// `POST /api/users/{id}/dm-sent`. We update the counter locally on the
/// `User` object in `AuthViewModel` so the gating UI reacts immediately —
/// the next `/me` refresh confirms the server's view.
struct ChatThreadView: View {
    let conversation: Conversation
    let currentUser: User
    @Environment(AuthViewModel.self) private var authVM
    @State private var inboxVM = InboxViewModel(messageService: APIMessageService())
    @State private var messageText = ""
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(inboxVM.currentMessages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: inboxVM.currentMessages.count) { _, _ in
                        if let last = inboxVM.currentMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider().background(Color.tapeCardBg)

                inputBar
            }
        }
        .navigationTitle(conversation.otherParticipantName(currentUserID: currentUser.id))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await inboxVM.loadMessages(conversationID: conversation.id)
            inboxVM.startMessagePolling(conversationID: conversation.id)
        }
        .onDisappear {
            inboxVM.stopPolling()
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallSheet(userRole: currentUser.role)
        }
    }

    private func messageBubble(_ message: Message) -> some View {
        let isFromMe = message.senderID == currentUser.id
        return HStack {
            if isFromMe { Spacer(minLength: 60) }
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromMe ? Color.tapeRed : Color.tapeCardBg)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 4) {
                    Text(message.sentAt.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isFromMe && currentUser.tier == .pro && message.isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.tapeRed)
                    }
                }
            }
            if !isFromMe { Spacer(minLength: 60) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $messageText)
                .padding(12)
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)

            Button {
                handleSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(messageText.isEmpty ? Color.secondary : Color.tapeRed)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.tapeDarkBg)
    }

    // MARK: - Send

    private func handleSend() {
        let trimmed = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Free-tier recruiters/brands: enforce the 10-DMs-per-month cap before
        // we even try to send. The server enforces the same rule; this is
        // just a faster local check so the user gets the paywall instead of
        // a 403 from the API.
        let isPaidRole = currentUser.role == .recruiter || currentUser.role == .brand
        if isPaidRole, currentUser.tier == .free, currentUser.dmsSentThisMonth >= 10 {
            showPaywall = true
            return
        }

        messageText = ""
        Task {
            await inboxVM.sendMessage(
                conversationID: conversation.id,
                senderID: currentUser.id,
                text: trimmed
            )
            // After a successful send, bump the per-month DM counter so the
            // free-tier cap reflects reality immediately. Recruiter/brand
            // only — athletes don't have a counter.
            if isPaidRole {
                await recordDMSent()
            }
        }
    }

    private func recordDMSent() async {
        struct Empty: Encodable {}
        // Best-effort: if this fails (network blip, server down) we will
        // re-sync on the next /api/users/me refresh.
        try? await APIClient.shared.postVoid(
            "/api/users/\(currentUser.id)/dm-sent",
            body: Empty()
        )
        await MainActor.run {
            authVM.updateLocalUser { $0.dmsSentThisMonth += 1 }
        }
    }
}
