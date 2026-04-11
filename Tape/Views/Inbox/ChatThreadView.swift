import SwiftUI

struct ChatThreadView: View {
    let conversation: Conversation
    let currentUser: User
    @State private var inboxVM = InboxViewModel()
    @State private var messageText = ""
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
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

                // Input bar
                inputBar
            }
        }
        .navigationTitle(conversation.otherParticipantName(currentUserID: currentUser.id))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await inboxVM.loadMessages(conversationID: conversation.id)
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
                guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let text = messageText
                messageText = ""
                Task {
                    await inboxVM.sendMessage(
                        conversationID: conversation.id,
                        senderID: currentUser.id,
                        text: text
                    )
                }
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
}
