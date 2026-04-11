import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var showPaywall = false

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
                        Label("Notifications", systemImage: "bell.badge")
                            .foregroundStyle(.white)
                        Label("Privacy", systemImage: "lock.shield")
                            .foregroundStyle(.white)
                        Label("Help & Support", systemImage: "questionmark.circle")
                            .foregroundStyle(.white)
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
        }
    }
}
