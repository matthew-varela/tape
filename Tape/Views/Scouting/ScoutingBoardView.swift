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
                            athleteGrid
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
                        if currentUser.tier == .free {
                            showPaywall = true
                        } else {
                            showNewBoardSheet = true
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
                    }
                }
                Button("Cancel", role: .cancel) { newBoardName = "" }
            }
            .navigationDestination(item: $navigateToAthlete) { athleteID in
                AthleteProfileView(athleteID: athleteID, currentUser: currentUser)
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallSheet(userRole: currentUser.role)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.square.on.square")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No saved athletes yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Bookmark athletes from the feed\nto see them here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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
                        Button(role: .destructive) {
                            Task { await scoutingVM.deleteBoard(boardID: board.id) }
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
