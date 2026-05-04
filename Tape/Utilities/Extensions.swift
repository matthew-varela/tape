import SwiftUI

/// App-wide ergonomics: brand colors, date helpers, keyboard dismissal.
/// Keeping these in one file means visual tokens are easy to find and tweak
/// without grepping the codebase.

extension Color {
    /// Primary brand color. Backed by `AccentColor` in the asset catalog so
    /// changing it propagates to every system control automatically.
    static let tapeRed = Color("AccentColor")

    /// Background color for the dark UI. Slightly off-black so pure black
    /// elements (video, OLED bezel) appear distinct against the chrome.
    static let tapeDarkBg = Color(uiColor: UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1))

    /// Card surface color used by inputs, list rows, and modal bodies.
    static let tapeCardBg = Color(uiColor: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
}

extension Date {
    /// Renders a date as "5m" / "2h" / "3d" relative to now. Used everywhere
    /// timestamps appear (chat bubbles, message previews, video captions).
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

extension View {
    /// Manually dismisses the software keyboard. Used by the "tap outside"
    /// gesture in forms.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
