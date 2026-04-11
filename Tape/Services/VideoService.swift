import Foundation

protocol VideoServiceProtocol {
    func fetchFeedVideos(page: Int) async throws -> [Video]
    func fetchVideos(for athleteID: String) async throws -> [Video]
    func fetchVideos(for athleteID: String, category: VideoCategory) async throws -> [Video]
    func fetchFilteredVideos(filters: FeedFilters) async throws -> [Video]
    func publishVideo(_ video: Video) async throws
}

struct FeedFilters: Equatable {
    var position: String?
    var state: String?
    var minHeight: String?
    var minGPA: Double?
    var sport: String?
    var gradYear: Int?
}

final class MockVideoService: VideoServiceProtocol {
    private var videos = MockData.videos

    func fetchFeedVideos(page: Int) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(300))
        let pageSize = 10
        let start = page * pageSize
        guard start < videos.count else { return [] }
        let end = min(start + pageSize, videos.count)
        return Array(videos[start..<end])
    }

    func fetchVideos(for athleteID: String) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(200))
        return videos.filter { $0.athleteID == athleteID }
    }

    func fetchVideos(for athleteID: String, category: VideoCategory) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(200))
        return videos.filter { $0.athleteID == athleteID && $0.category == category }
    }

    func fetchFilteredVideos(filters: FeedFilters) async throws -> [Video] {
        try await Task.sleep(for: .milliseconds(300))
        let matchingAthleteIDs = Set(MockData.athletes.filter { athlete in
            if let pos = filters.position, !pos.isEmpty, athlete.position != pos { return false }
            if let st = filters.state, !st.isEmpty, athlete.state != st { return false }
            if let gpa = filters.minGPA, (athlete.gpa ?? 0) < gpa { return false }
            if let sport = filters.sport, !sport.isEmpty, athlete.sport != sport { return false }
            if let year = filters.gradYear, athlete.gradYear != year { return false }
            return true
        }.map(\.id))

        return videos.filter { matchingAthleteIDs.contains($0.athleteID) }
    }

    func publishVideo(_ video: Video) async throws {
        try await Task.sleep(for: .milliseconds(500))
        videos.insert(video, at: 0)
    }
}
