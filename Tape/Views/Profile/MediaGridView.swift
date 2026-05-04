import SwiftUI

/// Generic 3-column grid of video thumbnails. Used as a building block by
/// the profile screen. Tapping a tile fires the `onVideoTap` callback so the
/// containing view can decide what "open" means (full-screen player,
/// navigation to a detail screen, etc).
struct MediaGridView: View {
    let videos: [Video]
    let onVideoTap: (Video) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(videos) { video in
                AsyncVideoThumbnail(videoURL: video.videoURL)
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if video.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(Color.tapeRed)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .padding(4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onVideoTap(video)
                    }
            }
        }
    }
}
