import Kingfisher
import SwiftUI

/// Lists everyone the signed-in user has blocked and lets them undo it.
///
/// Blocking was reachable from the feed, profiles, and chat, but there was no
/// way back — a mistaken block was permanent from the user's point of view
/// even though the backend has always supported unblocking. App Review also
/// looks for this on apps with user-generated content.
struct BlockedUsersView: View {
    @State private var users: [User] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    /// IDs with an unblock request in flight, so their row can show progress
    /// and can't be tapped twice.
    @State private var unblocking: Set<String> = []

    private let moderationService: ModerationServiceProtocol
    private let profileService: ProfileServiceProtocol

    init(
        moderationService: ModerationServiceProtocol = APIModerationService(),
        profileService: ProfileServiceProtocol = APIProfileService()
    ) {
        self.moderationService = moderationService
        self.profileService = profileService
    }

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if users.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(users) { user in
                            row(user)
                                .listRowBackground(Color.tapeCardBg)
                        }
                    } footer: {
                        Text("Unblocking lets this person see your content and message you again.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .errorToast($errorMessage)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No blocked users")
                .font(.headline)
                .foregroundStyle(.white)
            Text("People you block won't appear in your feed, search, or inbox.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func row(_ user: User) -> some View {
        HStack(spacing: 12) {
            avatar(user)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(user.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await unblock(user) }
            } label: {
                if unblocking.contains(user.id) {
                    ProgressView().tint(.white)
                } else {
                    Text("Unblock")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.tapeRed)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(unblocking.contains(user.id))
        }
        .padding(.vertical, 4)
    }

    private func avatar(_ user: User) -> some View {
        Group {
            if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                KFImage(url).resizable().scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ids = try await moderationService.fetchBlockedUserIDs()
            guard !ids.isEmpty else {
                users = []
                return
            }

            // No batch lookup endpoint exists, so fetch each in parallel. A
            // blocked list is small by nature, and a profile that 404s (a
            // deleted account) is simply dropped rather than failing the
            // whole screen.
            users = await withTaskGroup(of: User?.self) { group in
                for id in ids {
                    group.addTask { try? await profileService.fetchAthlete(id: id) }
                }
                var found: [User] = []
                for await user in group {
                    if let user { found.append(user) }
                }
                return found.sorted { $0.displayName < $1.displayName }
            }
        } catch {
            errorMessage = "Couldn't load your blocked list."
        }
    }

    private func unblock(_ user: User) async {
        unblocking.insert(user.id)
        defer { unblocking.remove(user.id) }

        do {
            try await moderationService.unblockUser(user.id)
            withAnimation {
                users.removeAll { $0.id == user.id }
            }
        } catch {
            errorMessage = "Couldn't unblock \(user.displayName). Try again."
        }
    }
}
