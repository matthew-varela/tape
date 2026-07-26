import SwiftUI

/// Backs the recruiter's flat shortlist of saved athletes.
@Observable
@MainActor
final class SavedPlayersViewModel {
    var athletes: [User] = []
    var isLoading = false
    var errorMessage: String?

    private let savedAthleteService: SavedAthleteServiceProtocol

    init(savedAthleteService: SavedAthleteServiceProtocol = MockSavedAthleteService()) {
        self.savedAthleteService = savedAthleteService
    }

    func load() async {
        isLoading = true
        do {
            athletes = try await savedAthleteService.fetchSavedAthletes()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Removes optimistically so the row disappears under the swipe.
    func unsave(_ athlete: User) async {
        let previous = athletes
        athletes.removeAll { $0.id == athlete.id }
        do {
            try await savedAthleteService.unsave(athleteID: athlete.id)
        } catch {
            athletes = previous
            errorMessage = error.localizedDescription
        }
    }
}
