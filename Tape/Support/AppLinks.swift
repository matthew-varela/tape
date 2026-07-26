import Foundation

/// Central place for the app's external legal / support links.
enum AppLinks {
    static let termsOfService = URL(string: "https://watchtape.app/terms")!
    static let privacyPolicy = URL(string: "https://watchtape.app/privacy")!

    /// Opens the user's mail client pre-addressed to support.
    static let support = URL(string: "mailto:support@tape.app")!
}
