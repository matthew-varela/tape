import SwiftUI

/// Lets a recruiter or brand put an athlete on one or more scouting boards.
///
/// The backend has always supported board membership, and boards could be
/// created and deleted, but nothing in the app ever called `addAthlete` — so
/// every board stayed permanently empty. This sheet is the missing entry
/// point, and it's presented from wherever a recruiter actually encounters an
/// athlete: their profile, and the Saved Players shortlist.
///
/// Membership is shown as a checklist rather than a one-shot picker because an
/// athlete legitimately belongs on several boards ("2026 Targets" and "Visit
/// Invites"), and because it doubles as the only place to see which boards an
/// athlete is already on.
struct AddToBoardSheet: View {
    let athleteID: String
    let athleteName: String
    let currentUser: User

    @Environment(\.dismiss) private var dismiss
    @State private var scoutingVM = ScoutingViewModel(
        scoutingService: APIScoutingService(),
        profileService: APIProfileService()
    )
    @State private var showNewBoardAlert = false
    @State private var newBoardName = ""
    /// Board IDs with a membership change in flight.
    @State private var pending: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                if scoutingVM.isLoading && scoutingVM.boards.isEmpty {
                    ProgressView().tint(.white)
                } else if scoutingVM.boards.isEmpty {
                    emptyState
                } else {
                    boardList
                }
            }
            .navigationTitle("Add to Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewBoardAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(Color.tapeRed)
                    }
                    .accessibilityLabel("New board")
                }
            }
            .task { await scoutingVM.loadBoards(ownerID: currentUser.id) }
            .alert("New Board", isPresented: $showNewBoardAlert) {
                TextField("Board name", text: $newBoardName)
                Button("Create") { createBoard() }
                Button("Cancel", role: .cancel) { newBoardName = "" }
            } message: {
                Text("\(athleteName) will be added to it.")
            }
            .errorToast($scoutingVM.errorMessage)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No boards yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Boards group athletes you're tracking, like \"2026 QBs\" or \"Visit Invites\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Create a Board") { showNewBoardAlert = true }
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.tapeRed)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding(.top, 8)
        }
    }

    private var boardList: some View {
        List {
            Section {
                ForEach(scoutingVM.boards) { board in
                    row(board)
                        .listRowBackground(Color.tapeCardBg)
                }
            } footer: {
                Text("Tap a board to add or remove \(athleteName).")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(_ board: ScoutingBoard) -> some View {
        let isOnBoard = board.athleteIDs.contains(athleteID)

        return Button {
            Task { await toggle(board: board, isOnBoard: isOnBoard) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(board.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(board.athleteIDs.count == 1 ? "1 athlete" : "\(board.athleteIDs.count) athletes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if pending.contains(board.id) {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: isOnBoard ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isOnBoard ? Color.tapeRed : .secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(pending.contains(board.id))
        .accessibilityAddTraits(isOnBoard ? [.isButton, .isSelected] : .isButton)
    }

    private func toggle(board: ScoutingBoard, isOnBoard: Bool) async {
        pending.insert(board.id)
        defer { pending.remove(board.id) }

        if isOnBoard {
            await scoutingVM.removeAthlete(boardID: board.id, athleteID: athleteID)
        } else {
            await scoutingVM.addAthlete(boardID: board.id, athleteID: athleteID)
        }
        NotificationCenter.default.post(name: .tapeScoutingBoardsChanged, object: nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func createBoard() {
        let name = newBoardName.trimmingCharacters(in: .whitespaces)
        newBoardName = ""
        guard !name.isEmpty else { return }

        Task {
            await scoutingVM.createBoard(name: name, ownerID: currentUser.id)
            // Put the athlete on the board they just made for them — creating
            // a board from this sheet has no other purpose.
            if let created = scoutingVM.boards.last(where: { $0.name == name }) {
                await scoutingVM.addAthlete(boardID: created.id, athleteID: athleteID)
            }
        }
    }
}
