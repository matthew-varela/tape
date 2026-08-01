import Kingfisher
import SwiftUI

/// Bottom sheet shown when the share button on a clip is tapped.
///
/// It exists instead of going straight to `UIActivityViewController` for two
/// reasons: the viewer gets to confirm *which* clip they're about to send
/// before a share destination takes over the screen, and copying the link —
/// by far the most common action — becomes one tap rather than a scroll
/// through the system activity row.
struct VideoShareSheet: View {
    let video: Video

    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var didCopy = false

    private var shareURL: URL? { AppLinks.shareURL(videoID: video.id) }

    /// What gets handed to the system sheet. The caption gives the recipient
    /// context in apps that show text alongside the link.
    private var shareMessage: String {
        let subject = video.athleteName.isEmpty ? "this clip" : "\(video.athleteName)'s clip"
        return "Watch \(subject) on Tape"
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            preview
            Divider().overlay(Color.white.opacity(0.1))
            actions
        }
        .background(Color.tapeCardBg)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.tapeCardBg)
        .sheet(isPresented: $showSystemShare) {
            if let shareURL {
                ShareSheet(activityItems: [shareMessage, shareURL])
            }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(width: 36, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 18)
    }

    private var preview: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(video.athleteName.isEmpty ? "Tape clip" : video.athleteName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !video.caption.isEmpty {
                    Text(video.caption)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var subtitle: String {
        [video.athleteSchool, video.athletePosition]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var thumbnail: some View {
        Group {
            if let urlString = video.thumbnailURL, let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.overlay {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 56, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actions: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: didCopy ? "checkmark" : "link",
                label: didCopy ? "Copied" : "Copy Link",
                tint: didCopy ? .green : .white,
                action: copyLink
            )

            actionButton(
                icon: "square.and.arrow.up",
                label: "Share to…",
                tint: .white
            ) {
                showSystemShare = true
            }

            actionButton(
                icon: "message.fill",
                label: "Messages",
                tint: .white,
                action: shareToMessages
            )
        }
        .padding(.vertical, 24)
        .disabled(shareURL == nil)
        .opacity(shareURL == nil ? 0.4 : 1)
    }

    private func actionButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1), in: Circle())
                    .contentTransition(.symbolEffect(.replace))

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func copyLink() {
        guard let shareURL else { return }
        UIPasteboard.general.url = shareURL
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.2)) { didCopy = true }
    }

    /// Opens Messages pre-filled. `sms:` can't carry a body on every iOS
    /// version, so the link goes in the body where supported and the system
    /// sheet remains the fallback.
    private func shareToMessages() {
        guard let shareURL else { return }
        let body = "\(shareMessage) \(shareURL.absoluteString)"
        let encoded = body.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        ) ?? ""

        guard let smsURL = URL(string: "sms:&body=\(encoded)"),
              UIApplication.shared.canOpenURL(smsURL) else {
            showSystemShare = true
            return
        }
        UIApplication.shared.open(smsURL)
        dismiss()
    }
}
