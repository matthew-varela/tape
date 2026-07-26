import SwiftUI

/// An athlete's ranked shortlist of programs, shown as a horizontal rail of
/// logos with the top choice called out.
struct TopSchoolsRow: View {
    let schoolIDs: [String]

    private var schools: [School] { SchoolCatalog.schools(ids: schoolIDs) }

    var body: some View {
        if !schools.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.tapeRed)
                    Text("Top Schools")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(schools.enumerated()), id: \.element.id) { index, school in
                            VStack(spacing: 6) {
                                SchoolLogo(school: school, size: 52)
                                    .overlay(alignment: .topTrailing) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Color.tapeRed, in: Circle())
                                            .overlay(Circle().stroke(Color.tapeDarkBg, lineWidth: 2))
                                            .offset(x: 4, y: -4)
                                    }
                                Text(school.abbreviation)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 60)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

/// Prominent coach affiliation: school logo + name, team (mascot), and the
/// coaching position they set on their profile.
struct CoachSchoolBanner: View {
    let schoolID: String?
    var position: String? = nil

    var body: some View {
        if let school = SchoolCatalog.school(id: schoolID) {
            HStack(alignment: .center, spacing: 16) {
                SchoolLogo(school: school, size: 64)

                VStack(alignment: .leading, spacing: 6) {
                    labeledLine(label: "School", value: school.name, emphasize: true)
                    labeledLine(label: "Team", value: school.mascot, emphasize: false)
                    if let position, !position.isEmpty {
                        labeledLine(label: "Position", value: position, emphasize: false)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [school.tint.opacity(0.9), school.tint.opacity(0.28)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText(school: school))
        }
    }

    private func labeledLine(label: String, value: String, emphasize: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .kerning(0.6)
            Text(value)
                .font(emphasize ? .title3.bold() : .subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    private func accessibilityText(school: School) -> String {
        var parts = ["School \(school.name)", "Team \(school.mascot)"]
        if let position, !position.isEmpty {
            parts.append("Position \(position)")
        }
        return parts.joined(separator: ", ")
    }
}
