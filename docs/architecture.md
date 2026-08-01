# Architecture

## The shape of the iOS app

Four layers, each depending only on the one below it:

```
Views (SwiftUI)
   ↓ reads state from, sends intent to
ViewModels (@Observable, @MainActor)
   ↓ calls
Services (protocol + API impl + Mock impl)
   ↓ uses
APIClient / Firebase SDKs
```

**Views** never call the network. **View models** never know whether a service
talks to REST, Firebase, or an in-memory array.

### Why every service is a protocol

Each service family is declared as a protocol with two implementations: an
`API*` class that makes real calls, and a `Mock*` class backed by `MockData`.
View models take the protocol in their initializer, so previews and tests can
substitute the mock without touching production code.

View model initializers default to the mock implementation for preview
convenience. **Every production call site passes the real service explicitly**
— if you add a new screen, pass an `API*` service or it will silently render
fake data.

### State management

The app uses Swift's Observation framework (`@Observable`), not Combine's
`ObservableObject`. View models are `@Observable @MainActor final class`, held
by views as `@State`, and shared down the tree via `.environment(...)`.

Three objects live in the environment for the whole app lifetime:
`AuthViewModel`, `SubscriptionManager`, and `DeepLinkRouter`.

### Cross-screen updates

Tabs each own their own view model instance, so one tab can't see another's
state. Where a change in one tab has to be reflected in another, the change is
broadcast through `NotificationCenter` (see `Support/Notifications.swift`).

---

## App entry and routing

| File | What it does |
|---|---|
| `Tape/App/TapeApp.swift` | `@main` entry point: configures Firebase, builds `AuthViewModel`, injects the shared environment objects, starts auth-state and StoreKit observation, and routes incoming deep links |
| `Tape/App/ContentView.swift` | Top-level switch on auth state (loading / login / tabs), the `MainTabView` chrome, the recruiter-and-brand profile tab, and presentation of deep-linked clips |

`MainTabView` shows Feed, Upload (athletes only), Inbox, Search, and Profile.
The Profile tab routes by role: athletes see their public profile, recruiters
and brands see an org-info screen.

---

## Models

Plain `Codable` structs shared by every layer. Each one has a custom
`init(from:)` that tolerates missing or differently-shaped fields, so a backend
change can't crash the client.

| File | What it holds |
|---|---|
| `Tape/Models/User.swift` | The single user type for all three roles: identity, athlete vitals, recruiter org fields, social handles, tier, and target schools |
| `Tape/Models/Video.swift` | One published clip, with the athlete's name, school, position and avatar denormalized onto it so the feed needs no join; also `VideoCategory` and `VideoTag` |
| `Tape/Models/Message.swift` | `Conversation` (a two-person thread with denormalized participant info) and `Message` |
| `Tape/Models/ScoutingBoard.swift` | A recruiter's named list of athlete IDs; decodes both the server's nested shape and the flat mock shape |
| `Tape/Models/School.swift` | `School` plus `SchoolCatalog`, which loads FBS programs and their colors from the bundled `fbs-schools.json` |

---

## Networking

| File | What it does |
|---|---|
| `Tape/Services/API/APIClient.swift` | The single HTTP client: builds URLs, attaches the Firebase ID token, encodes and decodes JSON, and turns non-2xx responses into `APIError` |

Every `API*` service is a thin wrapper over `APIClient`. All request and
response shapes are documented in [`BACKEND_CONTRACT.md`](../BACKEND_CONTRACT.md).

---

## Shared support code

| File | What it does |
|---|---|
| `Tape/Support/Notifications.swift` | The app's `Notification.Name` constants: clip published, bookmarks changed, scouting boards changed |
| `Tape/Support/AppLinks.swift` | External URLs (legal pages, support, subscription management), the share-link builder, and `DeepLink` URL parsing |
| `Tape/Support/DeepLinkRouter.swift` | Turns an incoming URL into presentable state by fetching the clip it points at |
| `Tape/Support/AudioSession.swift` | Configures `AVAudioSession` so feed audio plays even with the ringer switch silenced |
| `Tape/Support/TagCatalog.swift` | The bundled catalog of upload tags, grouped by sport, position, and play type |
| `Tape/Utilities/Extensions.swift` | Shared extensions: the `Color.tape*` palette, relative date formatting, and other small helpers |
| `Tape/Utilities/VideoCache.swift` | An actor that caches `AVPlayerItem` instances so a clip already scrolled past doesn't re-download |
| `Tape/Services/Mock/MockData.swift` | In-memory fixtures — users, videos, conversations, boards — backing every `Mock*` service and SwiftUI preview |

---

## Reusable components

| File | What it does |
|---|---|
| `Tape/Components/ErrorToast.swift` | `.errorToast(_:)` for a self-dismissing failure banner and `.errorAlert(_:)` for failures the user must acknowledge; used to surface view models' `errorMessage` |
| `Tape/Components/ActionButton.swift` | The circular icon-plus-label button used on the feed's right-hand action rail |
| `Tape/Components/VideoThumbnailTile.swift` | A grid tile for one clip: thumbnail, play count, duration |
| `Tape/Components/AsyncVideoThumbnail.swift` | Generates a still from a video URL when a clip has no stored thumbnail |
| `Tape/Components/SchoolLogo.swift` | Renders a school's logo with its brand colors, falling back to a monogram |
| `Tape/Components/VideoShareSheet.swift` | The share bottom sheet — see [sharing.md](sharing.md) |
| `Tape/Components/ProPaywallSheet.swift` | The subscription upsell — see [subscriptions.md](subscriptions.md) |

---

## Resources

| File | What it is |
|---|---|
| `Tape/Resources/Info.plist` | Bundle config: permission strings, the `tape://` URL scheme, orientation, and App Transport Security |
| `Tape/Resources/GoogleService-Info.plist` | Firebase project configuration |
| `Tape/Resources/Configuration.storekit` | Local StoreKit config so subscriptions can be tested in the simulator |
| `Tape/Resources/fbs-schools.json` | FBS program list with names and brand colors, loaded by `SchoolCatalog` |
| `Tape/Resources/Assets.xcassets` | App icon, accent color, and image assets |
| `project.yml` | XcodeGen spec — the project file is generated, so edit this and run `xcodegen generate` rather than editing `Tape.xcodeproj` |
