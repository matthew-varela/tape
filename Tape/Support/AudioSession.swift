import AVFoundation

/// Feed video needs the `.playback` audio category. The default category is
/// `.soloAmbient`, which silences all audio whenever the ringer switch is set
/// to silent — the usual reason a video feed appears to have no sound at all.
///
/// Activation is deliberately deferred until a video surface actually appears
/// rather than done at launch, so opening the app doesn't stop music the user
/// already had playing.
enum AudioSession {
    static func activatePlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("AudioSession: could not activate playback — \(error.localizedDescription)")
            #endif
        }
    }
}
