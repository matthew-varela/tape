import SwiftUI

/// Searchable FBS school picker.
///
/// Serves both sides of the marketplace: athletes pick a ranked shortlist of
/// programs they want to play for (`maxSelection > 1`), recruiters pick the one
/// program they coach for (`maxSelection == 1`).
struct SchoolPickerView: View {
    let title: String
    let maxSelection: Int
    @Binding var selection: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [School] { SchoolCatalog.search(query) }

    private var selectedSchools: [School] { SchoolCatalog.schools(ids: selection) }

    private var isAtLimit: Bool { selection.count >= maxSelection }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                List {
                    if maxSelection > 1 && !selectedSchools.isEmpty {
                        Section {
                            // Ranking uses explicit promote/remove buttons
                            // rather than drag-to-reorder: `onMove` needs the
                            // whole List in edit mode, which would also swallow
                            // taps on the picker rows below.
                            ForEach(Array(selectedSchools.enumerated()), id: \.element.id) { index, school in
                                RankedSchoolRow(
                                    school: school,
                                    index: index,
                                    onPromote: { promote(index) },
                                    onRemove: { selection.remove(at: index) }
                                )
                            }
                            .listRowBackground(Color.tapeCardBg)
                        } header: {
                            Text("Your top \(selection.count) — #1 is your first choice")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        ForEach(results) { school in
                            let isSelected = selection.contains(school.id)
                            Button {
                                toggle(school)
                            } label: {
                                SchoolRow(school: school, isSelected: isSelected)
                            }
                            .disabled(!isSelected && isAtLimit && maxSelection > 1)
                            .opacity(!isSelected && isAtLimit && maxSelection > 1 ? 0.4 : 1)
                            .listRowBackground(Color.tapeCardBg)
                        }
                    } header: {
                        Text(maxSelection > 1 ? "All FBS schools" : "Select your school")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $query, prompt: "Search schools")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.tapeRed)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Extracted so the picker body stays inside the type-checker's budget.
    private struct RankedSchoolRow: View {
        let school: School
        let index: Int
        let onPromote: () -> Void
        let onRemove: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                SchoolRow(school: school, rank: index + 1)

                Button(action: onPromote) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(index == 0 ? Color.secondary : Color.white)
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                .accessibilityLabel("Move \(school.name) up")

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(school.name)")
            }
        }
    }

    private func promote(_ index: Int) {
        guard index > 0 else { return }
        selection.swapAt(index, index - 1)
    }

    private func toggle(_ school: School) {
        if let index = selection.firstIndex(of: school.id) {
            selection.remove(at: index)
        } else if maxSelection == 1 {
            selection = [school.id]
            dismiss()
        } else if !isAtLimit {
            selection.append(school.id)
        }
    }
}
