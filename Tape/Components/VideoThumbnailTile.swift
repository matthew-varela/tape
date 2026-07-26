import SwiftUI
import Kingfisher

/// One tile in a profile's video grid.
///
/// Every tile is locked to the same 9:16 portrait ratio regardless of the
/// source clip's dimensions, which is what keeps the grid looking even the way
/// TikTok's and Instagram's do. The ratio is driven by a clear placeholder
/// rather than by the image itself — sizing a grid cell from its loaded image
/// is what previously let a landscape clip render a taller or shorter tile than
/// its neighbours.
///
/// Prefers the uploaded `thumbnailURL` and only falls back to deriving a poster
/// frame from the video when a clip predates the thumbnail pipeline.
struct VideoThumbnailTile: View {
    let video: Video
    var showsViewCount = true

    var body: some View {
        Color.tapeCardBg
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .overlay {
                if let urlString = video.thumbnailURL, let url = URL(string: urlString) {
                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                } else {
                    AsyncVideoThumbnail(videoURL: video.videoURL)
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if showsViewCount {
                    viewCountBadge
                }
            }
            .contentShape(Rectangle())
    }

    private var viewCountBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 9, weight: .bold))
            Text(video.viewCountLabel)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 2)
        .padding(6)
        .accessibilityLabel("\(video.viewCount) views")
    }
}
