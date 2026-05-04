import SwiftUI

/// Small icon-over-label button used by the feed's right-rail (bookmark,
/// share). The drop shadow keeps the white text readable on top of any
/// underlying video frame.
struct ActionButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isActive ? Color.tapeRed : Color.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
    }
}
