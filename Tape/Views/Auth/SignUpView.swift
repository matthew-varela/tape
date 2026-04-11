import SwiftUI

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var selectedRole: UserRole = .athlete

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && !displayName.isEmpty
    }

    var body: some View {
        ZStack {
            Color.tapeDarkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Text("Create Account")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Role picker
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
                        }
                    }

                    // Form fields
                    VStack(spacing: 14) {
                        TextField("Full Name", text: $displayName)
                            .textContentType(.name)
                            .padding()
                            .background(Color.tapeCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)

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
                            .padding()
                            .background(Color.tapeCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color.tapeCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)

                        if password != confirmPassword && !confirmPassword.isEmpty {
                            Text("Passwords don't match")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            await authVM.signUp(
                                email: email,
                                password: password,
                                displayName: displayName,
                                role: selectedRole
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
                .padding(24)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
