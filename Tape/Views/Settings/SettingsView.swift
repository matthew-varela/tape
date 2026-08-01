import SwiftUI

/// `SettingsView` is the gear-icon menu accessible from the profile tab. It
/// shows account info, lets the user navigate into edit profile, manage
/// their subscription (open the paywall), and sign out.
struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    private var currentUser: User? {
        if case .authenticated(let user) = authVM.authState { return user }
        return nil
    }

    /// True when the user has Pro by either source of truth. The backend tier
    /// can trail a fresh purchase until `/me` is refetched, so the StoreKit
    /// entitlement counts too.
    private var isPro: Bool {
        guard let currentUser else { return false }
        return subscriptionManager.hasPro(currentUser)
    }

    /// Marketing version and build straight from the bundle, so a shipped
    /// build can never disagree with what this screen claims.
    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Tape v\(version) (\(build))"
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

                                Text(isPro ? "PRO" : "FREE")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(isPro ? Color.tapeRed : Color.tapeCardBg)
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
                        if isPro {
                            // Apple requires subscribers to be able to reach
                            // their subscription management; there is no
                            // in-app way to change a plan, so link out.
                            Link(destination: AppLinks.manageSubscription) {
                                Label("Manage Subscription", systemImage: "crown.fill")
                                    .foregroundStyle(Color.tapeRed)
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                Label("Upgrade to Pro", systemImage: "crown.fill")
                                    .foregroundStyle(Color.tapeRed)
                            }
                        }

                        Button {
                            Task { await subscriptionManager.restore() }
                        } label: {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                                .foregroundStyle(.white)
                        }
                    } header: {
                        Text("Subscription")
                    }
                    .listRowBackground(Color.tapeCardBg)

                    Section {
                        NavigationLink {
                            EditProfileView()
                        } label: {
                            Label(
                                currentUser?.role == .athlete ? "Edit Profile & Vitals" : "Edit Profile",
                                systemImage: "pencil.circle"
                            )
                            .foregroundStyle(.white)
                        }
                    } header: {
                        Text("Profile")
                    }
                    .listRowBackground(Color.tapeCardBg)

                    // Safety
                    Section {
                        NavigationLink {
                            BlockedUsersView()
                        } label: {
                            Label("Blocked Users", systemImage: "hand.raised")
                                .foregroundStyle(.white)
                        }
                    } header: {
                        Text("Safety")
                    } footer: {
                        Text("People you block can't message you and won't appear in your feed or search.")
                    }
                    .listRowBackground(Color.tapeCardBg)

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
                            Text(versionLabel)
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
                    Task {
                        // A failed deletion used to leave the user staring at
                        // an unchanged screen with no idea it hadn't worked.
                        if await authVM.deleteAccount() == false {
                            deleteError = authVM.errorMessage
                                ?? "We couldn't delete your account. Please try again."
                        }
                    }
                }
            } message: {
                Text("This permanently deletes your account and all of your data. This action cannot be undone.")
            }
            .errorAlert($deleteError, title: "Couldn't Delete Account")
        }
    }
}
