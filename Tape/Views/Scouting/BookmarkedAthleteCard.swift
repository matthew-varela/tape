import SwiftUI
import Kingfisher

struct BookmarkedAthleteCard: View {
    let athlete: User
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                if let urlString = athlete.profileImageURL, let url = URL(string: urlString) {
                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(athlete.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(athlete.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    if let height = athlete.height {
                        statPill(height)
                    }
                    if let pos = athlete.position {
                        statPill(pos)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.tapeCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.tapeDarkBg)
            .foregroundStyle(Color.tapeRed)
            .clipShape(Capsule())
    }
}
