# Authentication

## How it works

Firebase handles credentials; the Tape backend handles identity. Signing up
creates a Firebase Auth user on the device, then calls
`POST /api/auth/signup` with that user's ID token — the backend creates a
`User` row keyed to the Firebase UID it verifies from the token, never from
anything the client sends.

From then on every request carries the Firebase ID token as a bearer header,
and the server resolves who you are from it. Client-supplied user IDs in
request bodies are accepted for backward compatibility but always ignored.

`AuthViewModel` observes Firebase's auth-state stream for the app's lifetime,
so a cold launch restores the session automatically and a token expiring
signs the user out everywhere at once.

### Age gating

Date of birth is required at signup. Accounts under 13 are rejected by the
server, and users under 18 are flagged as minors — which is what drives the
rule that athletes cannot initiate conversations. See [messaging.md](messaging.md).

### Account deletion

Required by App Review for any app with accounts. `DELETE /api/users/me`
cascades through every table the user appears in — videos, bookmarks,
conversations and messages, profile views, boards, saved athletes, follows,
blocks, reports, subscription — and then deletes the Firebase Auth user.
The app signs out afterward.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/ViewModels/AuthViewModel.swift` | Owns `authState` (unknown / unauthenticated / authenticated), observes Firebase auth changes, and handles sign up, sign in, sign out, `/me` refresh, and account deletion |
| `Tape/Services/AuthService.swift` | `AuthServiceProtocol` plus `MockAuthService`; defines sign up, sign in, sign out, and the auth-state stream |
| `Tape/Services/API/FirebaseAuthService.swift` | Production implementation on top of the Firebase Auth SDK, including ID-token retrieval for `APIClient` |
| `Tape/Services/ProfileService.swift` | Declares `fetchCurrentUser()` and `deleteAccount()` alongside the profile methods — see [profiles.md](profiles.md) |
| `Tape/Views/Auth/LoginView.swift` | Email and password sign-in screen with validation and error display |
| `Tape/Views/Auth/SignUpView.swift` | Account creation: email, password, display name, role picker, and date of birth with the 13+ check |
| `Tape/Views/Settings/SettingsView.swift` | Hosts sign out and the delete-account confirmation — see [subscriptions.md](subscriptions.md) for the rest of this screen |

### Backend

| File | What it does |
|---|---|
| `controller/AuthController.java` | Signup and signin endpoints, both keyed to the verified Firebase UID |
| `security/FirebaseAuthenticationFilter.java` | Verifies the bearer token on every request and populates the security context; in local mode accepts an `X-Test-User-ID` header instead |
| `security/FirebaseAuthenticationToken.java` | The Spring Security authentication object whose principal is the Firebase UID |
| `security/SecurityUtils.java` | `requireFirebaseUid()` — the one way controllers and services learn who is calling; throws 401 when unauthenticated |
| `config/SecurityConfig.java` | Stateless filter chain; enforces the Firebase filter when enabled, permits all when disabled for local development |
| `config/FirebaseConfig.java` | Initializes the Firebase Admin SDK from Application Default Credentials |
| `config/TapeFirebaseProperties.java` | Binds `tape.firebase.enabled` and the list of public paths |
| `service/FirebaseAccountService.java` | Deletes the Firebase Auth user after the database record is gone; a no-op when Firebase is disabled |
| `dto/SignUpRequest.java` | Validated signup payload: display name, role, required date of birth |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/auth/signup` | Create the `User` row for a newly registered Firebase user |
| POST | `/api/auth/signin` | Return the existing user for an authenticated Firebase UID |
| GET | `/api/users/me` | The caller's own profile; also used to refresh tier after a purchase |
| DELETE | `/api/users/me` | Permanently delete the account and all associated data |
