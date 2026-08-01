import SwiftUI

/// Instagram / TikTok profile link icons used on athlete profiles.
enum SocialPlatform: String {
    case instagram
    case tiktok

    /// Builds a public profile URL that opens the app via universal links when
    /// installed, otherwise falls back to the mobile web profile.
    func profileURL(handle: String) -> URL? {
        let cleaned = SocialHandle.normalize(handle)
        guard !cleaned.isEmpty else { return nil }
        switch self {
        case .instagram:
            return URL(string: "https://www.instagram.com/\(cleaned)/")
        case .tiktok:
            return URL(string: "https://www.tiktok.com/@\(cleaned)")
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
            "http://tiktok.com/"
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

/// Compact branded glyph. Instagram gets the classic gradient camera mark;
/// TikTok gets the note with cyan/red offset.
struct SocialPlatformIcon: View {
    let platform: SocialPlatform
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            switch platform {
            case .instagram:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.51, green: 0.23, blue: 0.73),
                                Color(red: 0.88, green: 0.19, blue: 0.42),
                                Color(red: 0.99, green: 0.55, blue: 0.18)
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                InstagramGlyph()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.22)
            case .tiktok:
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Color.black)
                TikTokGlyph()
                    .fill(Color(red: 0.25, green: 0.94, blue: 0.91).opacity(0.9))
                    .padding(size * 0.22)
                    .offset(x: -size * 0.04, y: size * 0.02)
                TikTokGlyph()
                    .fill(Color(red: 0.99, green: 0.17, blue: 0.33).opacity(0.9))
                    .padding(size * 0.22)
                    .offset(x: size * 0.04, y: -size * 0.02)
                TikTokGlyph()
                    .fill(Color.white)
                    .padding(size * 0.22)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct InstagramGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.08
        let camera = rect.insetBy(dx: inset, dy: inset)
        path.addRoundedRect(
            in: camera,
            cornerSize: CGSize(width: camera.width * 0.28, height: camera.height * 0.28)
        )
        let lensR = camera.width * 0.22
        path.addEllipse(in: CGRect(
            x: camera.midX - lensR,
            y: camera.midY - lensR,
            width: lensR * 2,
            height: lensR * 2
        ))
        let dotR = camera.width * 0.06
        path.addEllipse(in: CGRect(
            x: camera.maxX - camera.width * 0.22 - dotR,
            y: camera.minY + camera.height * 0.14 - dotR,
            width: dotR * 2,
            height: dotR * 2
        ))
        return path
    }
}

private struct TikTokGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stemW = rect.width * 0.18
        let stemX = rect.midX - stemW * 0.15
        path.addRoundedRect(
            in: CGRect(x: stemX, y: rect.minY + rect.height * 0.08, width: stemW, height: rect.height * 0.62),
            cornerSize: CGSize(width: stemW / 2, height: stemW / 2)
        )
        // Note head
        let headW = rect.width * 0.42
        let headH = rect.height * 0.34
        path.addEllipse(in: CGRect(
            x: stemX - headW * 0.55,
            y: rect.maxY - headH - rect.height * 0.06,
            width: headW,
            height: headH
        ))
        // Flag curl off the stem
        var flag = Path()
        flag.move(to: CGPoint(x: stemX + stemW, y: rect.minY + rect.height * 0.12))
        flag.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.38),
            control: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.08)
        )
        flag.addQuadCurve(
            to: CGPoint(x: stemX + stemW, y: rect.minY + rect.height * 0.32),
            control: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.28)
        )
        path.addPath(flag)
        return path
    }
}
