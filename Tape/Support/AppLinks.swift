import Foundation

/// Central place for the app's external links and for the links Tape itself
/// hands out when a user shares something.
enum AppLinks {
    /// Web host that backs shared links. The same host serves the legal pages.
    static let webHost = "watchtape.app"

    /// Custom scheme registered in `Info.plist` under `CFBundleURLTypes`.
    /// Used as the deep-link path that works without any server configuration.
    static let urlScheme = "tape"

    static let termsOfService = URL(string: "https://\(webHost)/terms")!
    static let privacyPolicy = URL(string: "https://\(webHost)/privacy")!

    /// Opens the user's mail client pre-addressed to support.
    static let support = URL(string: "mailto:support@\(webHost)")!

    /// Apple's subscription management screen. Subscriptions can only be
    /// changed or cancelled through Apple, so this is the only place to send
    /// an existing subscriber.
    static let manageSubscription = URL(
        string: "https://apps.apple.com/account/subscriptions"
    )!

    /// The link handed to the share sheet for a clip.
    ///
    /// Deliberately an `https` URL rather than `tape://`. A custom scheme
    /// looks broken to anyone who doesn't already have the app — most share
    /// destinations won't even make it tappable. An https link is always
    /// tappable, opens the app directly once universal links are enabled for
    /// the domain, and otherwise lands on a web page that can point people to
    /// the App Store.
    static func shareURL(videoID: String) -> URL? {
        URL(string: "https://\(webHost)/video/\(videoID)")
    }
}

/// A link into a specific piece of content inside the app.
///
/// Both supported forms resolve to the same destination:
///   - `tape://video/{id}`               — custom scheme, works today
///   - `https://watchtape.app/video/{id}` — universal link, works once the
///     domain serves an `apple-app-site-association` file and the app carries
///     the associated-domains entitlement
///
/// Parsing both here means enabling universal links later is purely a
/// configuration change, with no routing code to revisit. See
/// `docs/deeplinks/` for the setup steps.
enum DeepLink: Equatable {
    case video(id: String)

    init?(url: URL) {
        // tape://video/{id} — the id lands in `host` or `path` depending on
        // how the URL was written, so accept either.
        if url.scheme == AppLinks.urlScheme {
            let parts = ([url.host] + url.pathComponents)
                .compactMap { $0 }
                .filter { $0 != "/" && !$0.isEmpty }
            guard parts.count >= 2, parts[0] == "video" else { return nil }
            self = .video(id: parts[1])
            return
        }

        // https://watchtape.app/video/{id}
        if url.scheme == "https", url.host == AppLinks.webHost {
            let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            guard parts.count >= 2, parts[0] == "video" else { return nil }
            self = .video(id: parts[1])
            return
        }

        return nil
    }
}
