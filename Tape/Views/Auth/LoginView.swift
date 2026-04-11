import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Logo area
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.tapeRed)
                        Text("TAPE")
                            .font(.system(size: 42, weight: .black, design: .default))
                            .foregroundStyle(.white)
                        Text("Your highlight reel. Your future.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Input fields
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color.tapeCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .textContentType(.password)
                            .padding()
                            .background(Color.tapeCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Sign in button
                    Button {
                        Task { await authVM.signIn(email: email, password: password) }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.tapeRed)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(authVM.isLoading)

                    Button("Don't have an account? Sign Up") {
                        showSignUp = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.tapeRed)

                    // Demo quick-login
                    VStack(spacing: 8) {
                        Text("Quick Demo Login")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(UserRole.allCases) { role in
                                Button {
                                    Task { await authVM.signInAsDemo(role: role) }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: role.icon)
                                            .font(.title3)
                                        Text(role.displayName)
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.tapeCardBg)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}
