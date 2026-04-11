import SwiftUI
import Kingfisher

struct InboxListView: View {
    let currentUser: User
    @State private var inboxVM = InboxViewModel()
    @State private var selectedConversation: Conversation?
    @State private var showPaywall = false

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
                await inboxVM.loadConversations(userID: currentUser.id)
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatThreadView(conversation: conversation, currentUser: currentUser)
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallSheet(userRole: currentUser.role)
            }
        }
    }

    private var conversationList: some View {
        List {
            ForEach(inboxVM.conversations) { conversation in
                Button {
                    selectedConversation = conversation
                } label: {
                    conversationRow(conversation)
                }
                .listRowBackground(Color.tapeCardBg)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 14) {
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
            }

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
        .padding(.vertical, 4)
    }
}
