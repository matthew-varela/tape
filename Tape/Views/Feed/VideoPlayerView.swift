import AVFoundation
import SwiftUI

/// `VideoPlayerView` is a thin SwiftUI wrapper around an `AVPlayerLayer`.
/// We need a UIViewRepresentable here because SwiftUI's built-in
/// `VideoPlayer` always shows playback controls, which we don't want for
/// the auto-playing feed.
///
/// `PlayerUIView` overrides `layerClass` so the view's backing layer *is*
/// the `AVPlayerLayer`, which avoids an extra sublayer hierarchy and
/// improves scrolling performance.
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}

/// `VideoPlayerManager` owns the `AVPlayer` instances for the currently
/// visible feed cells. Two responsibilities:
///   1. Lazily build a player per video URL (and reuse it if the cell
///      reappears).
///   2. Ensure exactly one player is unmuted-and-playing at a time. As cells
///      scroll on/off screen, `play(videoID:)` pauses the previously active
///      player.
///
/// Looping: each player gets a `AVPlayerItemDidPlayToEndTime` observer that
/// seeks to zero and replays — gives us the TikTok-style infinite loop
/// without us managing a `Timer`.
///
/// Cleanup: `cleanup(keepingIDs:)` lets the feed call "I'm only currently
/// near these N video IDs, you can drop the rest" so memory stays flat
/// during long scroll sessions.
@Observable
final class VideoPlayerManager {
    private(set) var players: [String: AVPlayer] = [:]
    private var loopObservers: [String: Any] = [:]
    var activeVideoID: String?

    func player(for video: Video) -> AVPlayer {
        if let existing = players[video.id] {
            return existing
        }
        guard let url = URL(string: video.videoURL) else {
            return AVPlayer()
        }
        let player = AVPlayer(url: url)
        player.isMuted = false
        players[video.id] = player

        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        loopObservers[video.id] = observer

        return player
    }

    func play(videoID: String) {
        if activeVideoID != videoID {
            if let currentID = activeVideoID {
                players[currentID]?.pause()
            }
            activeVideoID = videoID
        }
        players[videoID]?.seek(to: .zero)
        players[videoID]?.play()
    }

    func pause(videoID: String) {
        players[videoID]?.pause()
    }

    func pauseAll() {
        for (_, player) in players {
            player.pause()
        }
        activeVideoID = nil
    }

    func cleanup(keepingIDs: Set<String>) {
        let toRemove = players.keys.filter { !keepingIDs.contains($0) }
        for id in toRemove {
            players[id]?.pause()
            players[id]?.replaceCurrentItem(with: nil)
            if let observer = loopObservers[id] {
                NotificationCenter.default.removeObserver(observer)
            }
            players.removeValue(forKey: id)
            loopObservers.removeValue(forKey: id)
        }
    }

    deinit {
        for (_, observer) in loopObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
