import SwiftUI

extension Color {
    static let tapeRed = Color("AccentColor")
    static let tapeDarkBg = Color(uiColor: UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1))
    static let tapeCardBg = Color(uiColor: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
}

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
