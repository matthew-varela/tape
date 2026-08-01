# Subscriptions — Tape Pro

## The product

One auto-renewing monthly subscription, `com.tape.pro.monthly`, sold through
StoreKit 2. Adding annual or lifetime tiers later means appending to
`SubscriptionManager.productIDs`; everything else loads whatever is in that
list.

## What Pro unlocks

| Feature | Free | Pro |
|---|---|---|
| Search stream (filter clips by athlete attributes) | locked | unlocked |
| Direct messages per month (recruiters and brands) | 10 | unlimited |
| Scouting boards | locked | unlimited |
| Profile viewers — who looked at you | count only | full list |
| Read receipts | hidden | shown |
| Pinning a clip to the top of your grid | locked | unlocked |

## Two sources of truth

The backend `User.tier` is authoritative across devices, but only updates after
`POST /api/users/me/subscription` succeeds and `/me` is refetched — and that
sync is best-effort. StoreKit's entitlement is authoritative on *this* device
and is correct the instant a purchase completes.

`SubscriptionManager.hasPro(_:)` treats either as sufficient. That's a
deliberate asymmetry: briefly granting Pro to someone whose backend record
hasn't caught up is much cheaper than charging someone and then showing them a
paywall for what they just bought. Every gate in the app calls `hasPro(_:)`
rather than reading `user.tier` directly, so this rule lives in exactly one
place.

## Transactions arriving from elsewhere

A background task runs for the app's lifetime watching `Transaction.updates`.
Purchases don't only arrive through `purchase()` — Family Sharing, Ask to Buy
approval, sandbox renewals, and purchases made on another device all show up
here. Without the listener, a user could pay and see nothing change.

**Restore Purchases** lives in Settings. Apple requires it for any app selling
subscriptions, and review rejects builds without it.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Services/Subscription/SubscriptionManager.swift` | Product loading, purchase, restore, entitlement refresh, the transaction listener, `hasPro(_:)`, and backend tier sync |
| `Tape/Components/ProPaywallSheet.swift` | The upsell sheet: feature list, price from StoreKit, purchase and restore buttons, and links to the legal pages |
| `Tape/Views/Settings/SettingsView.swift` | Plan row, Upgrade or Manage Subscription, and Restore Purchases |
| `Tape/Resources/Configuration.storekit` | Local StoreKit config so purchases work in the simulator without App Store Connect |
| `Tape/App/TapeApp.swift` | Starts the manager at launch and injects it into the environment |

Gates live in `FeedView` (Search stream), `ChatThreadView` and
`InboxViewModel` (DM cap), `ScoutingBoardView` (board count), and
`AthleteProfileView` (viewers, pinning).

### Backend

| File | What it does |
|---|---|
| `controller/UserController.java` | `POST /api/users/me/subscription` |
| `service/UserService.java` | Flips `User.tier` and upserts the subscription record |
| `repository/SubscriptionRepository.java` | Subscription rows by user |
| `entity/Subscription.java` | Tier, active flag, and timestamps |
| `enums/SubscriptionTier.java` | `FREE`, `PRO` |
| `dto/SubscriptionSyncRequest.java` | `{ active }` |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/users/me/subscription` | Sync entitlement state — `{ active }` |
| GET | `/api/users/me` | Refetched after a sync so gating UI updates |

---

## Before shipping

Receipts are not verified server-side. The backend trusts the client's
`{ active }` flag, which means a determined user could grant themselves Pro by
calling the endpoint directly. That's acceptable for TestFlight, but before
paid launch the backend should validate against Apple's
`verifyReceipt`/App Store Server API and handle server-to-server notifications
so cancellations and refunds downgrade the tier without the app running.
