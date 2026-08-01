import SwiftUI
import Kingfisher

/// A recruiter's flat list of saved athletes, newest save first.
///
/// Scouting boards are for deliberately organising prospects into named
/// groups; this is the low-friction "save it before I lose it" list built from
/// the bookmark button on any athlete profile.
struct SavedPlayersView: View {
    let currentUser: User

    @State private var viewModel = SavedPlayersViewModel(
        savedAthleteService: APISavedAthleteService()
    )
    @State private var selectedAthleteID: String?
    /// Athlete whose board picker is open, if any.
    @State private var addToBoardTarget: User?

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            if viewModel.isLoading && viewModel.athletes.isEmpty {
                ProgressView().tint(.white)
            } else if viewModel.athletes.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.athletes) { athlete in
                        Button {
                            selectedAthleteID = athlete.id
                        } label: {
                            athleteRow(athlete)
                        }
                        .listRowBackground(Color.tapeCardBg)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.unsave(athlete) }
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                addToBoardTarget = athlete
                            } label: {
                                Label("Add to Board", systemImage: "folder.badge.plus")
                            }
                            .tint(Color.tapeRed)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Saved Players")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
        .navigationDestination(item: $selectedAthleteID) { id in
            AthleteProfileView(athleteID: id, currentUser: currentUser)
        }
        .sheet(item: $addToBoardTarget) { athlete in
            AddToBoardSheet(
                athleteID: athlete.id,
                athleteName: athlete.displayName,
                currentUser: currentUser
            )
        }
        .errorToast($viewModel.errorMessage)
    }

    private func athleteRow(_ athlete: User) -> some View {
        HStack(spacing: 12) {
            if let urlString = athlete.profileImageURL, let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(athlete.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(athlete.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // The programs this athlete is targeting — the fastest read on
            // whether they're a realistic fit.
            HStack(spacing: -8) {
                ForEach(SchoolCatalog.schools(ids: athlete.targetSchoolIDs).prefix(3)) { school in
                    SchoolLogo(school: school, size: 26)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No saved players")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tap Save on any player's profile to keep them here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
