import SwiftUI

@Observable
final class ProfileViewModel {
    var athlete: User?
    var tapeVideos: [Video] = []
    var cultureVideos: [Video] = []
    var profileViewers: [User] = []
    var isLoading = false
    var errorMessage: String?

    private let profileService: ProfileServiceProtocol
    private let videoService: VideoServiceProtocol

    init(
        profileService: ProfileServiceProtocol = MockProfileService(),
        videoService: VideoServiceProtocol = MockVideoService()
    ) {
        self.profileService = profileService
        self.videoService = videoService
    }

    func loadProfile(athleteID: String) async {
        isLoading = true
        do {
            async let fetchedAthlete = profileService.fetchAthlete(id: athleteID)
            async let fetchedTape = videoService.fetchVideos(for: athleteID, category: .tape)
            async let fetchedCulture = videoService.fetchVideos(for: athleteID, category: .culture)

            athlete = try await fetchedAthlete
            tapeVideos = try await fetchedTape
            cultureVideos = try await fetchedCulture
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadProfileViewers(athleteID: String) async {
        do {
            profileViewers = try await profileService.fetchProfileViewers(for: athleteID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
