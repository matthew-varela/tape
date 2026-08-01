import SwiftUI

/// Social profile link icons shown on athlete profiles.
enum SocialPlatform: String {
    case instagram
    case tiktok
    case snapchat

    var accessibilityLabel: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .snapchat: "Snapchat"
        }
    }

    /// Public profile URL — opens the native app via universal links when installed.
    func profileURL(handle: String) -> URL? {
        let cleaned = SocialHandle.normalize(handle)
        guard !cleaned.isEmpty else { return nil }
        switch self {
        case .instagram:
            return URL(string: "https://www.instagram.com/\(cleaned)/")
        case .tiktok:
            return URL(string: "https://www.tiktok.com/@\(cleaned)")
        case .snapchat:
            return URL(string: "https://www.snapchat.com/add/\(cleaned)")
        }
    }
}

enum SocialHandle {
    /// Strips whitespace, a leading `@`, and common profile URL prefixes.
    static func normalize(_ raw: String) -> String {
        var handle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = handle.lowercased()
        for prefix in [
            "https://www.instagram.com/",
            "http://www.instagram.com/",
            "https://instagram.com/",
            "http://instagram.com/",
            "https://www.tiktok.com/",
            "http://www.tiktok.com/",
            "https://tiktok.com/",
            "http://tiktok.com/",
            "https://www.snapchat.com/add/",
            "http://www.snapchat.com/add/",
            "https://snapchat.com/add/",
            "http://snapchat.com/add/",
            "https://www.snapchat.com/",
            "http://www.snapchat.com/",
            "https://snapchat.com/",
            "http://snapchat.com/"
        ] {
            if lower.hasPrefix(prefix) {
                handle = String(handle.dropFirst(prefix.count))
                break
            }
        }
        while handle.hasPrefix("/") { handle.removeFirst() }
        if handle.hasPrefix("@") { handle.removeFirst() }
        if let slash = handle.firstIndex(of: "/") {
            handle = String(handle[..<slash])
        }
        if let query = handle.firstIndex(of: "?") {
            handle = String(handle[..<query])
        }
        return handle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Brand-accurate social glyphs at profile size.
struct SocialPlatformIcon: View {
    let platform: SocialPlatform
    var size: CGFloat = 28

    private let tikTokCyan = Color(red: 0.27, green: 0.95, blue: 0.91)
    private let tikTokRed = Color(red: 0.98, green: 0.16, blue: 0.33)
    private let snapYellow = Color(red: 1.0, green: 0.99, blue: 0.0)

    var body: some View {
        ZStack {
            switch platform {
            case .instagram:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        AngularGradient(
                            colors: [
                                Color(red: 0.51, green: 0.23, blue: 0.73),
                                Color(red: 0.83, green: 0.18, blue: 0.48),
                                Color(red: 0.96, green: 0.31, blue: 0.28),
                                Color(red: 0.99, green: 0.69, blue: 0.17),
                                Color(red: 0.51, green: 0.23, blue: 0.73)
                            ],
                            center: .center,
                            startAngle: .degrees(210),
                            endAngle: .degrees(570)
                        )
                    )
                InstagramGlyph()
                    .strokeBorder(Color.white, lineWidth: max(1.5, size * 0.065))
                    .padding(size * 0.22)

            case .tiktok:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Color.black)
                // Cyan + magenta offsets recreate the official glitch mark.
                TikTokNoteGlyph()
                    .fill(tikTokCyan)
                    .padding(size * 0.20)
                    .offset(x: -size * 0.055, y: size * 0.02)
                TikTokNoteGlyph()
                    .fill(tikTokRed)
                    .padding(size * 0.20)
                    .offset(x: size * 0.055, y: -size * 0.02)
                TikTokNoteGlyph()
                    .fill(Color.white)
                    .padding(size * 0.20)

            case .snapchat:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(snapYellow)
                SnapchatGhostGlyph()
                    .fill(Color.black, style: FillStyle(eoFill: true))
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Glyphs

/// Instagram camera outline: rounded square, lens ring, status dot.
private struct InstagramGlyph: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        let corner = r.width * 0.28
        path.addRoundedRect(in: r, cornerSize: CGSize(width: corner, height: corner))

        let lensR = r.width * 0.24
        path.addEllipse(in: CGRect(
            x: r.midX - lensR,
            y: r.midY - lensR,
            width: lensR * 2,
            height: lensR * 2
        ))

        let dotR = r.width * 0.07
        path.addEllipse(in: CGRect(
            x: r.maxX - r.width * 0.22 - dotR,
            y: r.minY + r.height * 0.16 - dotR,
            width: dotR * 2,
            height: dotR * 2
        ))
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

/// TikTok musical-note mark (stem + oval head + top curl).
private struct TikTokNoteGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Stem — slightly right of center, rounded ends.
        let stemW = w * 0.155
        let stemLeft = rect.minX + w * 0.50
        let stemTop = rect.minY + h * 0.06
        let stemBottom = rect.minY + h * 0.70
        path.addRoundedRect(
            in: CGRect(x: stemLeft, y: stemTop, width: stemW, height: stemBottom - stemTop),
            cornerSize: CGSize(width: stemW * 0.5, height: stemW * 0.5)
        )

        // Note head — left of the stem, slightly tilted oval feel via ellipse.
        let headW = w * 0.50
        let headH = h * 0.32
        path.addEllipse(in: CGRect(
            x: stemLeft - headW * 0.82,
            y: rect.maxY - headH - h * 0.05,
            width: headW,
            height: headH
        ))

        // Flag: thick curl from top of stem up and to the right, then back.
        var flag = Path()
        let attach = CGPoint(x: stemLeft + stemW, y: stemTop + h * 0.01)
        flag.move(to: attach)
        flag.addCurve(
            to: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY + h * 0.36),
            control1: CGPoint(x: stemLeft + stemW + w * 0.22, y: stemTop - h * 0.04),
            control2: CGPoint(x: rect.maxX + w * 0.04, y: rect.minY + h * 0.12)
        )
        flag.addCurve(
            to: CGPoint(x: stemLeft + stemW, y: stemTop + h * 0.20),
            control1: CGPoint(x: rect.maxX - w * 0.10, y: rect.minY + h * 0.48),
            control2: CGPoint(x: stemLeft + stemW + w * 0.10, y: stemTop + h * 0.26)
        )
        flag.closeSubpath()
        path.addPath(flag)

        return path
    }
}

/// Snapchat ghost silhouette.
private struct SnapchatGhostGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midX = rect.midX

        // Domed head
        path.move(to: CGPoint(x: midX, y: rect.minY + h * 0.02))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.42),
            control1: CGPoint(x: midX - w * 0.42, y: rect.minY + h * 0.02),
            control2: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.22)
        )
        // Left arm bump
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.14, y: rect.minY + h * 0.62),
            control1: CGPoint(x: rect.minX - w * 0.02, y: rect.minY + h * 0.50),
            control2: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.58)
        )
        // Left side down to scalloped hem
        path.addLine(to: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.82))

        // Three bottom scallops
        path.addQuadCurve(
            to: CGPoint(x: midX - w * 0.18, y: rect.minY + h * 0.82),
            control: CGPoint(x: midX - w * 0.30, y: rect.maxY + h * 0.02)
        )
        path.addQuadCurve(
            to: CGPoint(x: midX + w * 0.18, y: rect.minY + h * 0.82),
            control: CGPoint(x: midX, y: rect.maxY + h * 0.02)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - w * 0.16, y: rect.minY + h * 0.82),
            control: CGPoint(x: midX + w * 0.30, y: rect.maxY + h * 0.02)
        )

        // Right side up
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.14, y: rect.minY + h * 0.62))
        // Right arm bump
        path.addCurve(
            to: CGPoint(x: rect.maxX - w * 0.08, y: rect.minY + h * 0.42),
            control1: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY + h * 0.58),
            control2: CGPoint(x: rect.maxX + w * 0.02, y: rect.minY + h * 0.50)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: rect.minY + h * 0.02),
            control1: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY + h * 0.22),
            control2: CGPoint(x: midX + w * 0.42, y: rect.minY + h * 0.02)
        )
        path.closeSubpath()

        // Eyes (cutouts via even-odd)
        let eyeW = w * 0.12
        let eyeH = h * 0.14
        let eyeY = rect.minY + h * 0.36
        path.addEllipse(in: CGRect(x: midX - w * 0.22, y: eyeY, width: eyeW, height: eyeH))
        path.addEllipse(in: CGRect(x: midX + w * 0.10, y: eyeY, width: eyeW, height: eyeH))

        return path
    }
}
