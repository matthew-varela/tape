import SwiftUI

struct VitalsDashboard: View {
    let athlete: User

    private var vitals: [(label: String, value: String)] {
        var items: [(String, String)] = []
        if let h = athlete.height { items.append(("Height", h)) }
        if let w = athlete.weight { items.append(("Weight", "\(w) lbs")) }
        if let forty = athlete.fortyYardDash { items.append(("40-Yard", "\(forty)s")) }
        if let school = athlete.highSchool { items.append(("School", school)) }
        if let year = athlete.gradYear { items.append(("Class", "'\(String(year).suffix(2))")) }
        if let gpa = athlete.gpa { items.append(("GPA", String(format: "%.1f", gpa))) }
        return items
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(vitals, id: \.label) { vital in
                VStack(spacing: 6) {
                    Text(vital.value)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Text(vital.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
