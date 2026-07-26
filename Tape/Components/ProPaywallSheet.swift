import StoreKit
import SwiftUI

/// `ProPaywallSheet` is the in-app purchase entry point for "Tape Pro". It
/// reads available products from `SubscriptionManager` (loaded at app launch)
/// and triggers `purchase()` when the user taps the CTA.
///
/// The two states it can present:
///   - `loading`: products haven't arrived yet — show a spinner.
///   - `loaded`: render the price + features for the configured product.
///
/// On a successful purchase we dismiss the sheet; failures show inline.
struct ProPaywallSheet: View {
    let userRole: UserRole
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        hero
                        featuresList
                        priceBlock
                        ctaButton
                        restoreButton

                        if let localError {
                            Text(localError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        subscriptionDisclosure

                        Button("Maybe Later") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            // If we got here before products finished loading at launch, give
            // them another nudge so the price renders correctly.
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
        }
    }

    // MARK: - Subviews

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)
            Text("Upgrade to Tape Pro")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Unlock powerful features to level up your game")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var featuresList: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.title) { feature in
                featureRow(feature)
            }
        }
        .padding(.horizontal, 4)
    }

    private var priceBlock: some View {
        VStack(spacing: 8) {
            if let product = monthlyProduct {
                Text("\(product.displayPrice)/month")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                ProgressView().tint(.white)
            }
            Text("Cancel anytime")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var ctaButton: some View {
        Button(action: { Task { await purchase() } }) {
            Group {
                if subscriptionManager.purchaseInFlight {
                    ProgressView().tint(.white)
                } else {
                    Text(monthlyProduct == nil ? "Loading…" : "Start Free Trial")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.tapeRed, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 4)
        .disabled(monthlyProduct == nil || subscriptionManager.purchaseInFlight)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await subscriptionManager.restore() }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    /// Apple-required auto-renewable subscription disclosure: what's being sold,
    /// price/renewal terms, and links to Terms (EULA) and Privacy Policy.
    private var subscriptionDisclosure: some View {
        VStack(spacing: 8) {
            Text("Tape Pro — \(monthlyProduct?.displayPrice ?? "$9.99")/month after a 1-week free trial. Payment is charged to your Apple ID at the end of the trial. The subscription auto-renews monthly unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: AppLinks.termsOfService)
                Text("·").foregroundStyle(.secondary)
                Link("Privacy Policy", destination: AppLinks.privacyPolicy)
            }
            .font(.caption2)
            .tint(Color.tapeRed)
        }
        .padding(.top, 4)
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.tapeRed.opacity(0.15))
                .foregroundStyle(Color.tapeRed)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.tapeCardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var monthlyProduct: Product? {
        subscriptionManager.products.first { $0.id == "com.tape.pro.monthly" }
    }

    private func purchase() async {
        guard let product = monthlyProduct else { return }
        localError = nil
        let success = await subscriptionManager.purchase(product)
        if success {
            dismiss()
        } else if let err = subscriptionManager.lastError {
            localError = err
        }
    }

    private var features: [ProFeature] {
        switch userRole {
        case .athlete:
            return [
                ProFeature(icon: "eye.fill", title: "Who Viewed My Profile", description: "See exact names and schools of coaches viewing your tape"),
                ProFeature(icon: "checkmark.circle.fill", title: "Read Receipts", description: "Know when coaches have read your messages"),
                ProFeature(icon: "pin.fill", title: "Pin Highlights", description: "Pin your best clip to the top of your profile grid"),
            ]
        case .recruiter, .brand:
            return [
                ProFeature(icon: "line.3.horizontal.decrease.circle.fill", title: "Advanced Filters", description: "Search by position, state, height, GPA and more"),
                ProFeature(icon: "bubble.left.and.bubble.right.fill", title: "Unlimited Messaging", description: "No cap on direct messages to athletes"),
                ProFeature(icon: "folder.fill", title: "Custom Boards", description: "Organize scouting boards into custom folders"),
            ]
        }
    }
}

private struct ProFeature {
    let icon: String
    let title: String
    let description: String
}
