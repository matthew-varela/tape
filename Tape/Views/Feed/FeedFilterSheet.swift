import SwiftUI

struct FeedFilterSheet: View {
    @Binding var filters: FeedFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let positions = ["", "QB", "WR", "RB", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
    private let states = ["", "AL", "CA", "FL", "GA", "IL", "MD", "MI", "NY", "OH", "PA", "TX"]
    private let sports = ["", "Football", "Basketball", "Baseball", "Soccer", "Track & Field"]
    private let gradYears = [nil, 2025, 2026, 2027, 2028]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        filterSection("Sport") {
                            Picker("Sport", selection: Binding(
                                get: { filters.sport ?? "" },
                                set: { filters.sport = $0.isEmpty ? nil : $0 }
                            )) {
                                ForEach(sports, id: \.self) { s in
                                    Text(s.isEmpty ? "Any" : s).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        filterSection("Position") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                                ForEach(positions, id: \.self) { pos in
                                    let isSelected = filters.position == (pos.isEmpty ? nil : pos)
                                    Button {
                                        filters.position = pos.isEmpty ? nil : pos
                                    } label: {
                                        Text(pos.isEmpty ? "Any" : pos)
                                            .font(.subheadline.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? Color.tapeRed : Color.tapeCardBg)
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }

                        filterSection("State") {
                            Picker("State", selection: Binding(
                                get: { filters.state ?? "" },
                                set: { filters.state = $0.isEmpty ? nil : $0 }
                            )) {
                                ForEach(states, id: \.self) { s in
                                    Text(s.isEmpty ? "Any" : s).tag(s)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .background(Color.tapeCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        filterSection("Grad Year") {
                            Picker("Grad Year", selection: Binding(
                                get: { filters.gradYear },
                                set: { filters.gradYear = $0 }
                            )) {
                                Text("Any").tag(nil as Int?)
                                ForEach(gradYears.compactMap({ $0 }), id: \.self) { year in
                                    Text(String(year)).tag(year as Int?)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        filterSection("Minimum GPA") {
                            HStack {
                                Slider(
                                    value: Binding(
                                        get: { filters.minGPA ?? 0 },
                                        set: { filters.minGPA = $0 > 0 ? $0 : nil }
                                    ),
                                    in: 0...4.0,
                                    step: 0.1
                                )
                                .tint(Color.tapeRed)
                                Text(String(format: "%.1f", filters.minGPA ?? 0))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 40)
                            }
                        }

                        Button {
                            onApply()
                            dismiss()
                        } label: {
                            Text("Apply Filters")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.tapeRed)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button("Reset All") {
                            filters = FeedFilters()
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filter Athletes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            content()
        }
    }
}
