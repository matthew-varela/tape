import SwiftUI

/// Transient banner for failures the user should know about but that shouldn't
/// interrupt what they're doing.
///
/// Every view model in the app already records failures into an
/// `errorMessage` property; before this existed, almost none of those were
/// rendered, so a save that failed or a search that timed out looked exactly
/// like nothing happening. An alert would be too heavy for that — the feed
/// can't stop dead because one bookmark write lost the network — so this
/// auto-dismisses and stays out of the way.
///
/// Use `.errorAlert(_:)` instead where the user must acknowledge the failure
/// before continuing, such as an account deletion that didn't go through.
private struct ErrorToastModifier: ViewModifier {
    @Binding var message: String?
    /// Extra bottom inset for screens with a tab bar or floating controls.
    var bottomPadding: CGFloat

    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    banner(message)
                        .padding(.horizontal, 16)
                        .padding(.bottom, bottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: message)
            .onChange(of: message) { _, newValue in
                dismissTask?.cancel()
                guard newValue != nil else { return }
                dismissTask = Task {
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    message = nil
                }
            }
            .onDisappear {
                dismissTask?.cancel()
                dismissTask = nil
            }
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.tapeRed)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.tapeRed.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .contentShape(Rectangle())
        .onTapGesture { message = nil }
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel("Error: \(text)")
    }
}

extension View {
    /// Shows `message` as a self-dismissing banner along the bottom edge.
    /// Binding is cleared when the banner goes away, so the same failure can
    /// be reported again later.
    func errorToast(_ message: Binding<String?>, bottomPadding: CGFloat = 24) -> some View {
        modifier(ErrorToastModifier(message: message, bottomPadding: bottomPadding))
    }

    /// Blocking variant for failures the user needs to acknowledge before
    /// carrying on.
    func errorAlert(
        _ message: Binding<String?>,
        title: String = "Something went wrong"
    ) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
