import SwiftUI

/// Final step of the upload flow. The user picks a category, adds tags, and
/// writes a caption. Tapping Publish kicks off `UploadViewModel.publish`
/// which runs the trim → upload → thumbnail → backend pipeline.
///
/// While publishing we cover the form with a `PublishingOverlay` (defined
/// at the bottom of this file) that shows phase, progress, and a cancel
/// button. The form remains in the view tree but is non-interactive
/// (`allowsHitTesting(false)`) so the user can't double-tap publish.
struct TagSelectionView: View {
    @Bindable var uploadVM: UploadViewModel
    let onPublish: () -> Void
    /// The uploader's sport, used to narrow the position and play-type chips
    /// to ones that make sense for them. `nil` shows everything.
    var sport: String?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    categorySection
                    captionSection
                    tagsSection
                    publishButton
                    errorLabel
                }
                .padding(20)
            }
            .allowsHitTesting(!uploadVM.isPublishing)

            if uploadVM.isPublishing {
                PublishingOverlay(uploadVM: uploadVM)
            }
        }
    }

    // MARK: - Sections

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.headline)
                .foregroundStyle(.white)

            Picker("Category", selection: $uploadVM.selectedCategory) {
                ForEach(VideoCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Caption")
                .font(.headline)
                .foregroundStyle(.white)

            TextField("Describe your highlight...", text: $uploadVM.caption, axis: .vertical)
                .lineLimit(3...5)
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
    }

    private var tagsSection: some View {
        ForEach(VideoTag.TagCategory.allCases, id: \.self) { category in
            // Sport chips are always the full list — that's the field the
            // narrowing is based on.
            let tags = category == .sport
                ? TagCatalog.tags(in: category)
                : TagCatalog.tags(in: category, sport: sport)
            VStack(alignment: .leading, spacing: 10) {
                Text(category.rawValue.capitalized)
                    .font(.headline)
                    .foregroundStyle(.white)

                FlowLayout(spacing: 8) {
                    ForEach(tags) { tag in
                        let isSelected = uploadVM.selectedTags.contains(tag.label)
                        Button {
                            if isSelected {
                                uploadVM.selectedTags.remove(tag.label)
                            } else {
                                uploadVM.selectedTags.insert(tag.label)
                            }
                        } label: {
                            Text(tag.label)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.tapeRed : Color.tapeCardBg)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var publishButton: some View {
        Button(action: onPublish) {
            Text("Publish Highlight")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(uploadVM.selectedTags.isEmpty ? Color.gray : Color.tapeRed)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(uploadVM.selectedTags.isEmpty)
    }

    private var errorLabel: some View {
        Group {
            if let error = uploadVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Publishing Overlay

private struct PublishingOverlay: View {
    @Bindable var uploadVM: UploadViewModel
    @State private var showCancelConfirm = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.tapeRed)
                        .symbolEffect(.pulse)

                    Text(uploadVM.uploadPhase.rawValue)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .animation(.easeInOut, value: uploadVM.uploadPhase)
                }

                VStack(spacing: 10) {
                    ProgressView(value: uploadVM.uploadProgress)
                        .progressViewStyle(TapeProgressViewStyle())

                    Text("\(Int(uploadVM.uploadProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)

                Button {
                    showCancelConfirm = true
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                }
            }
        }
        .confirmationDialog(
            "Cancel Upload?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel Upload", role: .destructive) {
                uploadVM.cancelUpload()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("The video will not be published.")
        }
    }
}

// MARK: - Progress View Style

private struct TapeProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        let fraction = configuration.fractionCompleted ?? 0

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.tapeCardBg)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.tapeRed)
                    .frame(width: geo.size.width * fraction, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
