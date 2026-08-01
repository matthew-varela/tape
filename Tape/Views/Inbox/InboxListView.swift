import SwiftUI
import Kingfisher

/// `InboxListView` is the conversation list. It loads the user's threads on
/// appear, then polls every 8 seconds via `InboxViewModel` so new messages
/// from other participants surface without a manual refresh. Pull-to-refresh
/// fires the same fetch immediately for users who don't want to wait for
/// the next poll cycle.
struct InboxListView: View {
    let currentUser: User
    @State private var inboxVM = InboxViewModel(messageService: APIMessageService())
    @State private var selectedConversation: Conversation?
    @State private var navigateToProfile: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                if inboxVM.isLoading && inboxVM.conversations.isEmpty {
                    ProgressView().tint(.white)
                } else if inboxVM.conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No messages yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        if currentUser.role == .athlete {
                            Text("Coaches and brands will reach out to you here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                } else {
                    conversationList
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                // Initial load + start polling. The .task modifier
                // automatically cancels its closure when the view disappears,
                // so we explicitly stop polling on the way out as well to
                // shut down the spawned Task immediately.
                await inboxVM.loadConversations(userID: currentUser.id)
                inboxVM.startConversationPolling(userID: currentUser.id)
            }
            .onDisappear {
                inboxVM.stopPolling()
            }
            .refreshable {
                await inboxVM.loadConversations(userID: currentUser.id)
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatThreadView(conversation: conversation, currentUser: currentUser)
            }
            .navigationDestination(item: $navigateToProfile) { userID in
                AthleteProfileView(athleteID: userID, currentUser: currentUser)
            }
            .errorToast($inboxVM.errorMessage)
        }
    }

    private var conversationList: some View {
        List {
            ForEach(inboxVM.conversations) { conversation in
                conversationRow(conversation)
                    .listRowBackground(Color.tapeCardBg)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        let otherID = conversation.otherParticipantID(currentUserID: currentUser.id)

        return HStack(spacing: 14) {
            // Avatar opens their profile; the rest of the row opens the chat.
            Button {
                navigateToProfile = otherID
            } label: {
                avatar(for: conversation)
            }
            .buttonStyle(.plain)

            Button {
                selectedConversation = conversation
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.otherParticipantName(currentUserID: currentUser.id))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(conversation.lastMessageDate.relativeFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(conversation.lastMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.tapeRed)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func avatar(for conversation: Conversation) -> some View {
        let imageURL = conversation.otherParticipantImageURL(currentUserID: currentUser.id)
        if let urlString = imageURL, let url = URL(string: urlString) {
            KFImage(url)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
        }
    }
}
