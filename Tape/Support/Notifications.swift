import Foundation

extension Notification.Name {
    /// Posted after a clip is successfully published. The feed listens so a
    /// video you just uploaded appears without relaunching the app.
    static let tapeVideoPublished = Notification.Name("tape.videoPublished")
}
