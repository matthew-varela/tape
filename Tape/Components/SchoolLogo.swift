import SwiftUI
import Kingfisher

/// A school's logo on a disc of its brand color.
///
/// Many college marks are white or very light, so they vanish against the
/// app's dark background. Tinting the disc with the school's primary color
/// keeps every logo legible without per-school special-casing.
struct SchoolLogo: View {
    let school: School
    var size: CGFloat = 40

    var body: some View {
        KFImage(school.logo)
            .resizable()
            .scaledToFit()
            .padding(size * 0.14)
            .frame(width: size, height: size)
            .background(school.tint.opacity(0.9))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

/// Logo plus name, used in pickers and list rows.
struct SchoolRow: View {
    let school: School
    var isSelected: Bool = false
    /// Position in an athlete's ranked shortlist, if any.
    var rank: Int?

    var body: some View {
        HStack(spacing: 12) {
            SchoolLogo(school: school, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(school.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(school.mascot) · \(school.conference)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let rank {
                Text("#\(rank)")
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.tapeRed)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.tapeRed)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
