import Foundation

extension Notification.Name {
    /// Posted after a clip is successfully published. The feed listens so a
    /// video you just uploaded appears without relaunching the app.
    static let tapeVideoPublished = Notification.Name("tape.videoPublished")

    /// Posted after a bookmark is added or removed anywhere in the app.
    ///
    /// Saving happens in the feed but the results show up on the profile's
    /// Saved tab — two different tabs, each with its own view model, neither
    /// aware of the other. Broadcasting the change is what keeps the Saved tab
    /// from showing a stale list until the app is relaunched.
    static let tapeBookmarksChanged = Notification.Name("tape.bookmarksChanged")

    /// Posted after an athlete is added to or removed from a scouting board.
    /// Boards are edited from an athlete's profile, so the board screen needs
    /// telling that the list it's showing has changed underneath it.
    static let tapeScoutingBoardsChanged = Notification.Name("tape.scoutingBoardsChanged")
}
