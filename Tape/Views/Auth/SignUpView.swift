import SwiftUI

/// `SignUpView` collects the new account fields and creates the user via
/// `AuthViewModel.signUp`. Server hands back the canonical `User`, the auth
/// listener fires, and the app routes to the main tabs automatically.
struct SignUpView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedRole: UserRole = .athlete
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now

    /// Minimum age to create an account (COPPA floor).
    private let minimumAge = 13

    private var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now).year ?? 0
    }

    private var isOldEnough: Bool { age >= minimumAge }

    /// Combined name sent to the backend as `displayName`.
    private var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Earliest and latest selectable birth dates (no future dates; sane floor).
    private var dobRange: ClosedRange<Date> {
        let latest = Date.now
        let earliest = Calendar.current.date(byAdding: .year, value: -100, to: latest) ?? latest
        return earliest...latest
    }

    private var isFormValid: Bool {
        !email.isEmpty
            && !password.isEmpty
            && password == confirmPassword
            && !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isOldEnough
    }

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header
                    rolePicker
                    formFields
                    errorText
                    submitButton
                }
                .padding(24)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { authVM.clearError() }
        .onChange(of: email) { _, _ in authVM.clearError() }
        .onChange(of: password) { _, _ in authVM.clearError() }
        .onChange(of: confirmPassword) { _, _ in authVM.clearError() }
        .onChange(of: firstName) { _, _ in authVM.clearError() }
        .onChange(of: lastName) { _, _ in authVM.clearError() }
    }

    // MARK: - Subviews

    private var header: some View {
        Text("Create Account")
            .font(.largeTitle.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I am a...")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(UserRole.allCases) { role in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedRole = role
                    }
                } label: {
                    roleRow(role)
                }
            }
        }
    }

    private func roleRow(_ role: UserRole) -> some View {
        HStack(spacing: 16) {
            Image(systemName: role.icon)
                .font(.title2)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(role.displayName)
                    .font(.headline)
                Text(role.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(selectedRole == role ? Color.tapeRed : Color.secondary)
        }
        .padding()
        .background(selectedRole == role ? Color.tapeRed.opacity(0.15) : Color.tapeCardBg)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedRole == role ? Color.tapeRed : .clear, lineWidth: 2)
        )
    }

    private var formFields: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                    .padding()
                    .background(Color.tapeCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)

                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
                    .padding()
                    .background(Color.tapeCardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .autocorrectionDisabled()
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)

            SecureField("Confirm Password", text: $confirmPassword)
                .textContentType(.password)
                .autocorrectionDisabled()
                .padding()
                .background(Color.tapeCardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)

            if password != confirmPassword && !confirmPassword.isEmpty {
                Text("Passwords don't match")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            DatePicker(
                selection: $dateOfBirth,
                in: dobRange,
                displayedComponents: .date
            ) {
                Text("Date of Birth")
                    .foregroundStyle(.white)
            }
            .datePickerStyle(.compact)
            .tint(Color.tapeRed)
            .padding()
            .background(Color.tapeCardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)

            if !isOldEnough {
                Text("You must be at least \(minimumAge) years old to use Tape.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = authVM.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var submitButton: some View {
        Button {
            Task {
                await authVM.signUp(
                    email: email,
                    password: password,
                    displayName: fullName,
                    role: selectedRole,
                    dateOfBirth: dateOfBirth
                )
            }
        } label: {
            Group {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? Color.tapeRed : Color.tapeRed.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isFormValid || authVM.isLoading)
    }
}
