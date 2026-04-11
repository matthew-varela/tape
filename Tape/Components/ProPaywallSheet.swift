import SwiftUI

struct ProPaywallSheet: View {
    let userRole: UserRole
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tapeDarkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Hero
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

                        // Features based on role
                        VStack(spacing: 14) {
                            ForEach(features, id: \.title) { feature in
                                featureRow(feature)
                            }
                        }
                        .padding(.horizontal, 4)

                        // Price
                        VStack(spacing: 8) {
                            Text("$9.99/month")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Cancel anytime")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // CTA
                        Button {
                            // StoreKit 2 integration will go here
                            dismiss()
                        } label: {
                            Text("Start Free Trial")
                                .fontWeight(.bold)
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
}

private struct ProFeature {
    let icon: String
    let title: String
    let description: String
}
