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
        // Reassigning the same player detaches and reattaches the layer, which
        // blanks the current frame. SwiftUI calls this on every update, so the
        // identity check is what keeps scrolling from flashing black.
        guard uiView.playerLayer.player !== player else { return }
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
/// visible feed cells. Three responsibilities:
///   1. Lazily build a player per video URL (and reuse it if the cell
///      reappears).
///   2. Ensure exactly one player is playing at a time. As cells scroll
///      on/off screen, `makeActive(videoID:)` pauses the previously active
///      player.
///   3. Own the feed's shared mute and play/pause state so the speaker button
///      and tap-to-pause behave the same across every cell.
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
    /// Deliberately not observed. `player(for:)` is called from `body` while
    /// SwiftUI renders a cell, and writing to observed state during rendering
    /// invalidates the view mid-update. Views don't need to react to this
    /// dictionary anyway — they receive the player as a return value.
    @ObservationIgnored private var players: [String: AVPlayer] = [:]
    @ObservationIgnored private var loopObservers: [String: Any] = [:]

    var activeVideoID: String?

    /// Mute preference survives relaunches the way it does in other feeds.
    private(set) var isMuted: Bool
    /// True only when the viewer explicitly tapped to pause the active clip.
    private(set) var isPaused = false

    private static let muteDefaultsKey = "feed.audio.muted"

    init() {
        isMuted = UserDefaults.standard.bool(forKey: Self.muteDefaultsKey)
    }

    func player(for video: Video) -> AVPlayer {
        if let existing = players[video.id] {
            return existing
        }
        guard let url = URL(string: video.videoURL) else {
            return AVPlayer()
        }
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
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

    /// Makes one clip the playing one.
    ///
    /// Every other player is stopped, not just the previously active one.
    /// Pausing only the last-known-active player left any clip that had been
    /// started by an off-screen cell running, which is how audio from the clip
    /// above or below kept playing over the one on screen.
    func makeActive(videoID: String) {
        let changed = activeVideoID != videoID

        for (id, player) in players where id != videoID {
            player.pause()
        }

        if changed {
            activeVideoID = videoID
            isPaused = false
            players[videoID]?.seek(to: .zero)
        }
        players[videoID]?.isMuted = isMuted
        players[videoID]?.play()
    }

    /// Warms a player so the clip has buffered by the time it's scrolled to.
    func prepare(_ video: Video) {
        _ = player(for: video)
    }

    /// Resumes the active clip after the feed comes back on screen (tab switch,
    /// or returning from a pushed profile), unless the viewer had paused it.
    func resumeActive() {
        guard !isPaused, let id = activeVideoID else { return }
        players[id]?.play()
    }

    func pause(videoID: String) {
        players[videoID]?.pause()
    }

    /// Stops every player but remembers which clip was active so `resumeActive`
    /// can pick the feed back up where the viewer left it.
    func pauseAll() {
        for (_, player) in players {
            player.pause()
        }
    }

    /// Tap-to-pause on the active clip.
    func togglePlayPause() {
        guard let id = activeVideoID, let player = players[id] else { return }
        if isPaused {
            player.play()
        } else {
            player.pause()
        }
        isPaused.toggle()
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: Self.muteDefaultsKey)
        for (_, player) in players {
            player.isMuted = isMuted
        }
    }

    /// Tears down players outside the given window.
    ///
    /// The active clip is never evicted regardless of what's passed in. Tearing
    /// down the on-screen player calls `replaceCurrentItem(with: nil)` on a
    /// layer that's still mounted, which leaves a permanently black cell while
    /// some other player keeps producing sound.
    func cleanup(keepingIDs: Set<String>) {
        var keep = keepingIDs
        if let activeVideoID {
            keep.insert(activeVideoID)
        }
        let toRemove = players.keys.filter { !keep.contains($0) }
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
