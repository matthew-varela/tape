import Foundation

/// Resolves incoming deep links into something the UI can present.
///
/// A shared link carries only a video id, so the clip has to be fetched before
/// anything can be shown. This object owns that round trip and exposes the
/// result as presentable state, which keeps `TapeApp` free of any networking.
@Observable
@MainActor
final class DeepLinkRouter {
    /// Set once a shared clip has been fetched. Presented full screen.
    var presentedVideo: Video?
    /// True while a shared link is being resolved, so the UI can show a spinner
    /// instead of appearing to ignore the tap.
    private(set) var isResolving = false
    /// Set when a link can't be opened — deleted clip, blocked athlete, or no
    /// connection.
    var errorMessage: String?

    private let videoService: VideoServiceProtocol

    init(videoService: VideoServiceProtocol = APIVideoService()) {
        self.videoService = videoService
    }

    /// Entry point for `onOpenURL`. Unrecognized URLs are ignored rather than
    /// surfaced as errors — the app shouldn't complain about a link it was
    /// never meant to handle.
    func handle(url: URL) {
        guard let link = DeepLink(url: url) else { return }
        switch link {
        case .video(let id):
            Task { await openVideo(id: id) }
        }
    }

    private func openVideo(id: String) async {
        isResolving = true
        defer { isResolving = false }

        do {
            presentedVideo = try await videoService.fetchVideo(id: id)
        } catch {
            // The server returns 404 both for a deleted clip and for one whose
            // athlete is blocked, so this message covers both without
            // revealing which.
            errorMessage = "That clip isn't available anymore."
        }
    }
}
