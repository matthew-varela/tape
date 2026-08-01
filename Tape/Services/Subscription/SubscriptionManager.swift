import Foundation
import StoreKit

/// `SubscriptionManager` wraps Apple's StoreKit 2 framework so the rest of the
/// app never has to deal with raw `Product`, `Transaction`, or
/// `VerificationResult` types. It exposes:
///
///   - `products`: the loaded `Product` objects (from the `.storekit` config in
///      simulator or App Store Connect on device),
///   - `isSubscribed`: whether the user currently has an active entitlement,
///   - `purchase(_:)`: a single async function to buy a product,
///   - `restore()`: triggers Apple's "restore purchases" flow.
///
/// We also run a background `Task` for the lifetime of the app
/// (`listenForTransactions`) which catches transactions that arrive from
/// outside the purchase call: Family Sharing, Ask to Buy approval, parental
/// approval, sandbox renewals, transactions made on another device, etc.
///
/// On a successful purchase we tell the backend ("hey, the user has Pro now")
/// and we ask `AuthViewModel` to refresh `/api/users/me` so all gating UI
/// (read receipts, advanced filters, etc.) updates immediately.
@Observable
@MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    /// The product IDs configured in App Store Connect. Today we ship one
    /// product; add more entries here when we introduce annual or lifetime
    /// SKUs and StoreKit will load them all at once.
    static let productIDs: [String] = [
        "com.tape.pro.monthly"
    ]

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var purchaseInFlight = false
    private(set) var lastError: String?

    private var transactionListener: Task<Void, Never>?
    private weak var authVM: AuthViewModel?

    private init() {}

    // MARK: - Lifecycle

    /// Called once at app launch from `RootView`. Loads products, fetches the
    /// current entitlement state, and starts the long-running transaction
    /// listener.
    func start(authVM: AuthViewModel) async {
        self.authVM = authVM
        transactionListener?.cancel()
        transactionListener = listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    /// Loads the configured products from the App Store (or the local
    /// `.storekit` config in simulator). Failure is non-fatal — the paywall
    /// will show a localized error string instead of disappearing.
    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Re-checks `Transaction.currentEntitlements` and updates `isSubscribed`.
    /// `currentEntitlements` is StoreKit's source of truth: it reflects every
    /// purchase the user has made, including renewals and refunds.
    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID) {
                isSubscribed = true
                await syncBackendTier(active: true)
                return
            }
        }
        isSubscribed = false
        await syncBackendTier(active: false)
    }

    /// Triggers a purchase. Returns `true` only when StoreKit reports
    /// `.success(.verified(_))`. Caller is responsible for any UI on `true`
    /// (e.g. dismissing the paywall sheet).
    func purchase(_ product: Product) async -> Bool {
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                } else {
                    lastError = "We couldn't verify the purchase. Please try again."
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                lastError = "Purchase pending approval (Ask to Buy / Family)."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Triggers Apple's "Restore Purchases" flow. Required for every app that
    /// sells in-app subscriptions per App Review guidelines.
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private

    /// Spawns the long-running listener that catches transactions arriving
    /// outside `purchase()`. Without this, a sandbox renewal or a Family
    /// Sharing entitlement would silently fail to update the UI.
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    /// Whether `user` should get Pro features right now.
    ///
    /// Two sources can disagree. The backend tier on the `User` record is
    /// authoritative across devices, but it only updates once
    /// `POST /api/users/me/subscription` succeeds and `/me` is refetched — and
    /// that sync is best-effort. StoreKit's entitlement is authoritative on
    /// this device and is correct the instant a purchase completes.
    ///
    /// Taking either as sufficient means a paying user is never shown a
    /// paywall for something they just bought because a background sync lost
    /// the network. The reverse mistake — briefly granting Pro to someone
    /// whose backend record hasn't caught up — is far cheaper than charging
    /// someone and then locking them out.
    func hasPro(_ user: User) -> Bool {
        user.tier == .pro || isSubscribed
    }

    /// Tells the backend the user's subscription state changed. Best-effort —
    /// StoreKit is the source of truth on device, so a failed sync will just
    /// be retried on the next entitlement refresh.
    private func syncBackendTier(active: Bool) async {
        struct Body: Encodable { let active: Bool }
        do {
            try await APIClient.shared.postVoid(
                "/api/users/me/subscription",
                body: Body(active: active)
            )
            await authVM?.refreshCurrentUser()
        } catch {
            // Silent — the local entitlement is still authoritative.
        }
    }
}
