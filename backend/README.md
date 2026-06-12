# Tape API — Backend

Java 21 / Spring Boot 3 REST API powering the Tape iOS app and a future Android app.

---

## Running locally

```bash
cd backend
mvn spring-boot:run
```

The API starts on **port 8080** by default (overridden by the `PORT` env var on Render).

Firebase is **disabled** locally — all routes are open and you can authenticate
as any user by sending the `X-Test-User-ID: <uid>` header.

---

## Running tests

```bash
cd backend
mvn test
```

Tests run with `@ActiveProfiles("local")`, which sets `tape.firebase.enabled=false`
and uses an in-memory H2 database. The test suite covers:

- Contract endpoint availability and HTTP status codes.
- Authorization rules (one user cannot access another's data).
- Pro-tier gates (viewers, pin/unpin).
- Free-tier DM cap enforcement (10 DMs/month).
- Global error shape `{ "message": "..." }`.

---

## Environment variables

| Variable | Description | Default |
|---|---|---|
| `PORT` | HTTP port | `8080` |
| `TAPE_FIREBASE_ENABLED` | Enable Firebase Admin + Bearer filter | `false` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service account JSON | — |
| `SPRING_DATASOURCE_URL` | JDBC URL for production database | H2 in-memory |
| `SPRING_DATASOURCE_USERNAME` | DB username | `sa` |
| `SPRING_DATASOURCE_PASSWORD` | DB password | _(empty)_ |
| `AWS_S3_REGION` | (Legacy, unused by mobile clients) | `us-east-1` |
| `AWS_S3_ACCESS_KEY` | (Legacy, unused by mobile clients) | — |
| `AWS_S3_SECRET_KEY` | (Legacy, unused by mobile clients) | — |
| `AWS_S3_BUCKET` | (Legacy, unused by mobile clients) | `local-dev` |

---

## Firebase setup (production / Render)

1. Generate a service account key in the Firebase console:
   **Project Settings → Service Accounts → Generate new private key**

2. In Render, add a **Secret File** mounted at `/etc/secrets/firebase-service-account.json`
   with the contents of that key.

3. Set these environment variables on Render:

   ```
   TAPE_FIREBASE_ENABLED=true
   GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/firebase-service-account.json
   ```

4. Once set, every request (except `GET /api/health`) requires a valid
   `Authorization: Bearer <Firebase ID token>` header.

---

## Authentication model

```
Mobile client (iOS or Android)
  │  Firebase SDK signs in the user
  │  getIdToken() → short-lived JWT
  │
  └─► Authorization: Bearer <JWT>
           │
           ▼
    FirebaseAuthenticationFilter
           │  verifyIdToken() → FirebaseToken
           │  uid = token.getUid()
           │
           ▼
    SecurityContextHolder (FirebaseAuthenticationToken)
           │
           ▼
    SecurityUtils.requireFirebaseUid()
    ── every controller reads identity here ──
```

- `User.id` equals the Firebase UID — no separate server-generated user id.
- Client-supplied `initiatorId`, `senderId`, `athleteId`, `ownerId` fields in
  request bodies are accepted for backward compatibility but are always
  overridden by the verified token uid.

---

## Storage

Mobile clients upload files **directly** to Firebase Storage using the Firebase
SDK. The backend only stores the resulting download URLs. There is no S3 or
presigned-URL flow for mobile clients.

```
iOS / Android  ──upload──►  Firebase Storage
                             └── download URL returned to client
Mobile client  ──POST /api/videos { videoUrl }──►  Tape API  ──store URL──►  DB
```

---

## Adding an Android client

1. Use the Firebase Android SDK to authenticate and call `getIdToken()`.
2. Send `Authorization: Bearer <token>` on every request — same as iOS.
3. Upload media to Firebase Storage with the Android SDK; post the download
   URL to `POST /api/videos` — same schema as iOS.
4. For subscriptions, call `POST /api/users/me/subscription` with
   `{ "active": true, "platform": "android", "provider": "play_billing" }`
   after a Google Play Billing purchase. The server records the platform for
   cross-platform billing history.
5. All JSON schemas, enum values (`ATHLETE`, `PRO`, etc.), error shapes
   (`{ "message": "..." }`), and endpoint paths are identical for both platforms.

See [BACKEND_CONTRACT.md](../BACKEND_CONTRACT.md) for the full API reference.

---

## Key packages

| Package | Description |
|---|---|
| `controller` | Spring MVC REST controllers — thin layer over services |
| `service` | Business logic: auth, users, videos, messaging, bookmarks, scouting |
| `entity` | JPA entities persisted to the database |
| `repository` | Spring Data JPA repositories |
| `dto` | Request/response data transfer objects |
| `security` | Firebase auth filter, token, and `SecurityUtils` |
| `config` | Firebase Admin initialization, security configuration |
| `exception` | Global exception handler — normalizes all errors to `{ "message" }` |
