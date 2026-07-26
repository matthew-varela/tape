import SwiftUI

/// `SettingsView` is the gear-icon menu accessible from the profile tab. It
/// shows account info, lets the user navigate into edit profile, manage
/// their subscription (open the paywall), and sign out.
struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false

    private var currentUser: User? {
        if case .authenticated(let user) = authVM.authState { return user }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                List {
                    // Account section
                    Section {
                        if let user = currentUser {
                            HStack(spacing: 14) {
                                Image(systemName: user.role.icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Color.tapeRed.opacity(0.2))
                                    .foregroundStyle(Color.tapeRed)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(user.tier == .pro ? "PRO" : "FREE")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(user.tier == .pro ? Color.tapeRed : Color.tapeCardBg)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    } header: {
                        Text("Account")
                    }
                    .listRowBackground(Color.tapeCardBg)

                    // Subscription
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "crown.fill")
                                .foregroundStyle(Color.tapeRed)
                        }
                    } header: {
                        Text("Subscription")
                    }
                    .listRowBackground(Color.tapeCardBg)

                    if currentUser?.role == .athlete {
                        Section {
                            NavigationLink {
                                EditProfileView()
                            } label: {
                                Label("Edit Profile & Vitals", systemImage: "pencil.circle")
                                    .foregroundStyle(.white)
                            }
                        } header: {
                            Text("Profile")
                        }
                        .listRowBackground(Color.tapeCardBg)
                    }

                    // App
                    Section {
                        Link(destination: AppLinks.privacyPolicy) {
                            Label("Privacy Policy", systemImage: "lock.shield")
                                .foregroundStyle(.white)
                        }
                        Link(destination: AppLinks.termsOfService) {
                            Label("Terms of Service", systemImage: "doc.text")
                                .foregroundStyle(.white)
                        }
                        Link(destination: AppLinks.support) {
                            Label("Help & Support", systemImage: "questionmark.circle")
                                .foregroundStyle(.white)
                        }
                    } header: {
                        Text("App")
                    }
                    .listRowBackground(Color.tapeCardBg)

                    // Sign out
                    Section {
                        Button(role: .destructive) {
                            authVM.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .listRowBackground(Color.tapeCardBg)

                    // Account deletion (App Store requirement for account-based apps)
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                        .disabled(authVM.isLoading)
                    } footer: {
                        Text("Permanently deletes your account, profile, videos, messages, and all associated data. This cannot be undone.")
                    }
                    .listRowBackground(Color.tapeCardBg)

                    // Version
                    Section {
                        HStack {
                            Spacer()
                            Text("Tape v1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                if let user = currentUser {
                    ProPaywallSheet(userRole: user.role)
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await authVM.deleteAccount() }
                }
            } message: {
                Text("This permanently deletes your account and all of your data. This action cannot be undone.")
            }
        }
    }
}
