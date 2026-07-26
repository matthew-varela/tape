import SwiftUI
import Kingfisher

/// `VideoOverlayView` is the floating chrome on top of each feed cell —
/// athlete name, tags, caption, and the right-rail action buttons (profile,
/// follow, save, share, mute). The overlay is layered over an `AVPlayer` and
/// uses a dark gradient at the bottom to keep text legible regardless of the
/// underlying video colors.
///
/// Each action receives a closure rather than calling into a view model
/// directly, which keeps this view trivially previewable.
struct VideoOverlayView: View {
    let video: Video
    let isBookmarked: Bool
    let isFollowing: Bool
    /// False on your own clips, where a follow button makes no sense.
    let canFollow: Bool
    let isMuted: Bool
    let onProfileTap: () -> Void
    let onFollowTap: () -> Void
    let onBookmarkTap: () -> Void
    let onShareTap: () -> Void
    let onMuteTap: () -> Void
    let onReportTap: () -> Void
    let onBlockTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Gradient scrim at the bottom third
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.8)],
                startPoint: .top,
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
                VStack(spacing: 22) {
                    avatarWithFollowBadge

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

                    ActionButton(
                        icon: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        label: isMuted ? "Muted" : "Sound",
                        action: onMuteTap
                    )

                    viewCountBadge

                    // Moderation: report content / block the athlete. Required
                    // for user-generated-content apps on the App Store.
                    Menu {
                        Button(role: .destructive, action: onReportTap) {
                            Label("Report Video", systemImage: "flag")
                        }
                        Button(role: .destructive, action: onBlockTap) {
                            Label("Block Athlete", systemImage: "hand.raised")
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 22, weight: .semibold))
                                .frame(height: 28)
                            Text("More")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                    }
                    .accessibilityLabel("More options")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
    }

    /// Avatar with the small follow affordance tucked into its bottom edge,
    /// the same placement TikTok and Reels use.
    private var avatarWithFollowBadge: some View {
        Button(action: onProfileTap) {
            Group {
                if let urlString = video.athleteProfileImageURL, let url = URL(string: urlString) {
                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 46))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .bottom) {
                if canFollow {
                    Button(action: onFollowTap) {
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(isFollowing ? Color.gray : Color.tapeRed, in: Circle())
                            .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .offset(y: 11)
                    .accessibilityLabel(isFollowing ? "Unfollow \(video.athleteName)" : "Follow \(video.athleteName)")
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(video.athleteName)'s profile")
        // Room for the badge that hangs below the avatar.
        .padding(.bottom, canFollow ? 8 : 0)
    }

    private var viewCountBadge: some View {
        VStack(spacing: 4) {
            Image(systemName: "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .frame(height: 28)
            Text(video.viewCountLabel)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .accessibilityLabel("\(video.viewCount) views")
    }
}
