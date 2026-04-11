import SwiftUI

struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var highSchool = ""
    @State private var gradYear = ""
    @State private var sport = ""
    @State private var position = ""
    @State private var state = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var fortyYardDash = ""
    @State private var gpa = ""
    @State private var isSaving = false

    private var currentUser: User? {
        if case .authenticated(let user) = authVM.authState { return user }
        return nil
    }

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    formField("Display Name", text: $displayName)
                    formField("High School", text: $highSchool)
                    formField("Graduation Year", text: $gradYear)
                        .keyboardType(.numberPad)
                    formField("Sport", text: $sport)
                    formField("Position", text: $position)
                    formField("State", text: $state)
                    formField("Height (e.g. 6'2\")", text: $height)
                    formField("Weight (lbs)", text: $weight)
                        .keyboardType(.numberPad)
                    formField("40-Yard Dash (s)", text: $fortyYardDash)
                        .keyboardType(.decimalPad)
                    formField("GPA", text: $gpa)
                        .keyboardType(.decimalPad)

                    Button {
                        isSaving = true
                        // In production: save to backend
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.tapeRed)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if let user = currentUser {
                displayName = user.displayName
                highSchool = user.highSchool ?? ""
                gradYear = user.gradYear.map(String.init) ?? ""
                sport = user.sport ?? ""
                position = user.position ?? ""
                state = user.state ?? ""
                height = user.height ?? ""
                weight = user.weight ?? ""
                fortyYardDash = user.fortyYardDash ?? ""
                gpa = user.gpa.map { String(format: "%.1f", $0) } ?? ""
            }
        }
    }

    private func formField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
    }
}
