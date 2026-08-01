import SwiftUI
import Kingfisher

/// Recruiters and brands organize athletes into "scouting boards" — named
/// folders of bookmarked players. The view shows a horizontal pill of board
/// names at the top and a 2-column grid of athletes for the selected board.
///
/// All board mutations (create, delete, add/remove athlete) round-trip through
/// `ScoutingViewModel` to the backend. The View only ever drives intent.
struct ScoutingBoardView: View {
    let currentUser: User
    @State private var scoutingVM = ScoutingViewModel(
        scoutingService: APIScoutingService(),
        profileService: APIProfileService()
    )
    @State private var selectedBoard: ScoutingBoard?
    @State private var showNewBoardSheet = false
    @State private var newBoardName = ""
    @State private var navigateToAthlete: String?
    @State private var showPaywall = false
    /// Board being renamed, if any.
    @State private var renameTarget: ScoutingBoard?
    @State private var renameText = ""
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                if scoutingVM.isLoading && scoutingVM.boards.isEmpty {
                    ProgressView().tint(.white)
                } else if scoutingVM.boards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            boardPicker
                            if scoutingVM.bookmarkedAthletes.isEmpty {
                                emptyBoardState
                            } else {
                                athleteGrid
                            }
                        }
                        .padding(.top, 8)
                    }
                    .refreshable {
                        await scoutingVM.loadBoards(ownerID: currentUser.id)
                        await scoutingVM.loadBookmarkedAthletes(for: selectedBoard?.id)
                    }
                }
            }
            .navigationTitle("Scouting Board")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if subscriptionManager.hasPro(currentUser) {
                            showNewBoardSheet = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(Color.tapeRed)
                    }
                }
            }
            .task {
                await scoutingVM.loadBoards(ownerID: currentUser.id)
                if selectedBoard == nil { selectedBoard = scoutingVM.boards.first }
                await scoutingVM.loadBookmarkedAthletes(for: selectedBoard?.id)
            }
            .alert("New Board", isPresented: $showNewBoardSheet) {
                TextField("Board name", text: $newBoardName)
                Button("Create") {
                    let name = newBoardName.trimmingCharacters(in: .whitespaces)
                    newBoardName = ""
                    guard !name.isEmpty else { return }
                    Task {
                        await scoutingVM.createBoard(name: name, ownerID: currentUser.id)
                        // A board created from an empty state should be the
                        // one on screen afterwards.
                        if selectedBoard == nil {
                            selectedBoard = scoutingVM.boards.first
                            await scoutingVM.loadBookmarkedAthletes(for: selectedBoard?.id)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { newBoardName = "" }
            }
            .alert(
                "Rename Board",
                isPresented: Binding(
                    get: { renameTarget != nil },
                    set: { if !$0 { renameTarget = nil } }
                )
            ) {
                TextField("Board name", text: $renameText)
                Button("Save") {
                    guard let board = renameTarget else { return }
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    renameTarget = nil
                    guard !name.isEmpty, name != board.name else { return }
                    Task {
                        await scoutingVM.renameBoard(boardID: board.id, newName: name)
                        if selectedBoard?.id == board.id {
                            selectedBoard = scoutingVM.boards.first { $0.id == board.id }
                        }
                    }
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
            }
            .navigationDestination(item: $navigateToAthlete) { athleteID in
                AthleteProfileView(athleteID: athleteID, currentUser: currentUser)
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallSheet(userRole: currentUser.role)
            }
            .onReceive(NotificationCenter.default.publisher(for: .tapeScoutingBoardsChanged)) { _ in
                Task {
                    await scoutingVM.loadBoards(ownerID: currentUser.id)
                    await scoutingVM.loadBookmarkedAthletes(for: selectedBoard?.id)
                }
            }
            .errorToast($scoutingVM.errorMessage)
        }
    }

    /// Shown when the recruiter has no boards at all.
    ///
    /// The previous copy told people to "bookmark athletes from the feed",
    /// which was wrong in two ways: the feed's bookmark button saves *videos*,
    /// and boards need to exist before anything can go on them. Athletes are
    /// added from their profile.
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.square.on.square")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No boards yet")
                .font(.title3)
                .foregroundStyle(.white)
            Text("Boards group the athletes you're tracking.\nCreate one, then add players from their profile.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Create a Board") {
                if subscriptionManager.hasPro(currentUser) {
                    showNewBoardSheet = true
                } else {
                    showPaywall = true
                }
            }
            .fontWeight(.semibold)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.tapeRed)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .padding(.top, 8)
        }
    }

    /// Shown when a board exists but has nobody on it.
    private var emptyBoardState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.square.badge.camera")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("This board is empty")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Open an athlete's profile and tap the folder button to add them to a board.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink {
                SavedPlayersView(currentUser: currentUser)
            } label: {
                Text("Browse Saved Players")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.tapeCardBg)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 40)
    }

    private var boardPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(scoutingVM.boards) { board in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedBoard = board
                        }
                        Task {
                            await scoutingVM.loadBookmarkedAthletes(for: board.id)
                        }
                    } label: {
                        Text(board.name)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedBoard?.id == board.id ? Color.tapeRed : Color.tapeCardBg)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .contextMenu {
                        Button {
                            renameTarget = board
                            renameText = board.name
                        } label: {
                            Label("Rename Board", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            Task {
                                await scoutingVM.deleteBoard(boardID: board.id)
                                // The picker can't stay pointed at a board
                                // that no longer exists.
                                if selectedBoard?.id == board.id {
                                    selectedBoard = scoutingVM.boards.first
                                    await scoutingVM.loadBookmarkedAthletes(for: selectedBoard?.id)
                                }
                            }
                        } label: {
                            Label("Delete Board", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var athleteGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(scoutingVM.bookmarkedAthletes) { athlete in
                BookmarkedAthleteCard(athlete: athlete) {
                    navigateToAthlete = athlete.id
                }
                .contextMenu {
                    if let board = selectedBoard {
                        Button(role: .destructive) {
                            Task {
                                await scoutingVM.removeAthlete(
                                    boardID: board.id,
                                    athleteID: athlete.id
                                )
                                await scoutingVM.loadBookmarkedAthletes(for: board.id)
                            }
                        } label: {
                            Label("Remove from \(board.name)", systemImage: "xmark.circle")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
