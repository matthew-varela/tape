import SwiftUI

struct TagSelectionView: View {
    @Bindable var uploadVM: UploadViewModel
    let onPublish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Category picker
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

                // Caption
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

                // Tags by category
                ForEach(VideoTag.TagCategory.allCases, id: \.self) { category in
                    let tags = MockData.availableTags.filter { $0.category == category }
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

                // Publish button
                Button {
                    onPublish()
                } label: {
                    Group {
                        if uploadVM.isPublishing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Publish Highlight")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(uploadVM.selectedTags.isEmpty ? Color.gray : Color.tapeRed)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(uploadVM.selectedTags.isEmpty || uploadVM.isPublishing)

                if let error = uploadVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
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
