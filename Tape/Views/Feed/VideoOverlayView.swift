import SwiftUI
import Kingfisher

struct VideoOverlayView: View {
    let video: Video
    let isBookmarked: Bool
    let onProfileTap: () -> Void
    let onBookmarkTap: () -> Void
    let onShareTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Gradient scrim at the bottom
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            HStack(alignment: .bottom) {
                // Bottom left: athlete info
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.athleteName)
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    Text("\(video.athleteSchool) '\(String(video.athleteGradYear).suffix(2)) | \(video.athletePosition)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    if !video.caption.isEmpty {
                        Text(video.caption)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    // Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(video.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column: action buttons
                VStack(spacing: 24) {
                    // Profile picture
                    Button(action: onProfileTap) {
                        if let urlString = video.athleteProfileImageURL, let url = URL(string: urlString) {
                            KFImage(url)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                    }

                    ActionButton(
                        icon: isBookmarked ? "bookmark.fill" : "bookmark",
                        label: "Save",
                        isActive: isBookmarked,
                        action: onBookmarkTap
                    )

                    ActionButton(
                        icon: "arrowshape.turn.up.right.fill",
                        label: "Share",
                        action: onShareTap
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
