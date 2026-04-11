import AVFoundation
import SwiftUI

struct VideoTrimmerView: View {
    @Bindable var uploadVM: UploadViewModel
    let onDone: () -> Void

    @State private var player: AVPlayer?
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false

    private var trimDuration: Double {
        uploadVM.trimEnd - uploadVM.trimStart
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Trim Your Clip")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Select a 5-15 second window")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Video preview
            if let player {
                VideoPlayerView(player: player)
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Duration indicator
            Text(String(format: "%.1fs selected", trimDuration))
                .font(.headline)
                .foregroundStyle(trimDuration >= 5 && trimDuration <= 15 ? Color.tapeRed : Color.red)

            // Thumbnail strip with trim handles
            thumbnailStrip
                .padding(.horizontal, 8)

            // Time labels
            HStack {
                Text(formatTime(uploadVM.trimStart))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(uploadVM.trimEnd))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onDone) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(trimDuration >= 5 && trimDuration <= 15 ? Color.tapeRed : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(trimDuration < 5 || trimDuration > 15)
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .onAppear {
            if let url = uploadVM.selectedVideoURL {
                player = AVPlayer(url: url)
            }
        }
    }

    private var thumbnailStrip: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width - 32
            let duration = uploadVM.videoDuration
            let startFraction = uploadVM.trimStart / duration
            let endFraction = uploadVM.trimEnd / duration

            ZStack(alignment: .leading) {
                // Thumbnail images
                HStack(spacing: 0) {
                    ForEach(Array(uploadVM.thumbnailImages.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: totalWidth / CGFloat(max(uploadVM.thumbnailImages.count, 1)))
                            .clipped()
                    }
                }
                .frame(width: totalWidth, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)

                // Dimming outside selection
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 16 + totalWidth * startFraction)
                    Spacer()
                }

                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 16 + totalWidth * (1 - endFraction))
                }

                // Start handle
                trimHandle(fraction: startFraction, totalWidth: totalWidth, isStart: true)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newFraction = max(0, min(value.location.x - 16, totalWidth)) / totalWidth
                                let newTime = newFraction * duration
                                if uploadVM.trimEnd - newTime >= 5 {
                                    uploadVM.trimStart = max(0, newTime)
                                }
                            }
                    )

                // End handle
                trimHandle(fraction: endFraction, totalWidth: totalWidth, isStart: false)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newFraction = max(0, min(value.location.x - 16, totalWidth)) / totalWidth
                                let newTime = newFraction * duration
                                if newTime - uploadVM.trimStart >= 5 && newTime - uploadVM.trimStart <= 15 {
                                    uploadVM.trimEnd = min(duration, newTime)
                                }
                            }
                    )

                // Selection border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.tapeRed, lineWidth: 3)
                    .frame(
                        width: totalWidth * (endFraction - startFraction),
                        height: 56
                    )
                    .offset(x: 16 + totalWidth * startFraction)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 56)
    }

    private func trimHandle(fraction: Double, totalWidth: Double, isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.tapeRed)
            .frame(width: 14, height: 56)
            .overlay {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 2, height: 20)
            }
            .offset(x: 16 + totalWidth * fraction - (isStart ? 14 : 0))
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, ms)
    }
}
