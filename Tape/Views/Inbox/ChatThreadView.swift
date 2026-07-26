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
    @Environment(\.dismiss) private var dismiss
    @State private var inboxVM = InboxViewModel(messageService: APIMessageService())
    @State private var messageText = ""
    @State private var showPaywall = false

    // Moderation
    private let moderationService = APIModerationService()
    @State private var showReportDialog = false
    @State private var showBlockDialog = false
    @State private var showReportConfirmation = false

    private var otherParticipantID: String {
        conversation.participantIDs.first { $0 != currentUser.id } ?? ""
    }

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { showReportDialog = true } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button(role: .destructive) { showBlockDialog = true } label: {
                        Label("Block User", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
        }
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
        .confirmationDialog("Report", isPresented: $showReportDialog, titleVisibility: .visible) {
            ForEach(ModerationReason.all, id: \.self) { reason in
                Button(reason) { submitReport(reason: reason) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Why are you reporting this conversation?")
        }
        .confirmationDialog("Block \(conversation.otherParticipantName(currentUserID: currentUser.id))?",
                            isPresented: $showBlockDialog, titleVisibility: .visible) {
            Button("Block", role: .destructive) { submitBlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't be able to message each other and won't see each other's content.")
        }
        .alert("Thanks for reporting", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Our team will review this conversation.")
        }
    }

    // MARK: - Moderation actions

    private func submitReport(reason: String) {
        Task {
            try? await moderationService.report(
                targetType: .user,
                targetId: otherParticipantID,
                reason: reason,
                details: nil
            )
            await MainActor.run { showReportConfirmation = true }
        }
    }

    private func submitBlock() {
        Task {
            try? await moderationService.blockUser(otherParticipantID)
            inboxVM.stopPolling()
            await MainActor.run { dismiss() }
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
