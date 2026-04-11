import AVFoundation
import SwiftUI

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
