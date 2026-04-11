import AVFoundation
import SwiftUI

struct AsyncVideoThumbnail: View {
    let videoURL: String
    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                Color.tapeCardBg
                    .overlay {
                        ProgressView()
                            .tint(.secondary)
                    }
            } else {
                Color.tapeCardBg
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task {
            await generateThumbnail()
        }
    }

    private func generateThumbnail() async {
        guard let url = URL(string: videoURL) else {
            isLoading = false
            return
        }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 400)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            thumbnail = UIImage(cgImage: cgImage)
        } catch {
            // Silently fail - show placeholder
        }
        isLoading = false
    }
}
