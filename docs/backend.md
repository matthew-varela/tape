# Backend

Java 21, Spring Boot 3.4, PostgreSQL, deployed on Render. The iOS app is the
only client today; an Android client would use the identical contract.

For running it locally, environment variables, Firebase setup, and deployment,
see [`backend/README.md`](../backend/README.md). For request and response
shapes, see [`BACKEND_CONTRACT.md`](../BACKEND_CONTRACT.md). This document is
the map: what every file is, and what the schema looks like.

---

## Layering

```
controller/   thin HTTP layer — routes, status codes, no logic
service/      all business logic, authorization, and validation
repository/   Spring Data JPA queries
entity/       JPA entities, one per table
dto/          request and response shapes
security/     Firebase token verification and caller identity
config/       Firebase Admin, security chain, S3
exception/    normalizes every error to { "message": "..." }
```

Two rules hold throughout:

**Identity comes from the token, never the body.** Every controller calls
`SecurityUtils.requireFirebaseUid()`. Request fields like `ownerId`,
`senderId`, `initiatorId`, and `athleteId` are still accepted so older clients
don't break, but they're overwritten with the verified UID. Spoofing another
user by editing a request body isn't possible.

**`User.id` *is* the Firebase UID.** There's no separate server-side user ID
and no mapping table, so any token identifies a row directly.

---

## Files

### Entry point and infrastructure

| File | What it does |
|---|---|
| `TapeApiApplication.java` | Spring Boot entry point |
| `web/HealthController.java` | `GET /api/health` — the only unauthenticated route; used by Render's health check |
| `exception/GlobalExceptionHandler.java` | Turns every exception into `{ "message": "..." }` so clients never have to parse two error formats |

### Security

| File | What it does |
|---|---|
| `security/FirebaseAuthenticationFilter.java` | Verifies the `Authorization: Bearer` token with Firebase Admin and populates the security context. When Firebase is disabled it honors an `X-Test-User-ID` header for local development — that header is ignored whenever Firebase is on |
| `security/FirebaseAuthenticationToken.java` | The `Authentication` wrapper holding the decoded token |
| `security/SecurityUtils.java` | `requireFirebaseUid()` — the single way any code learns who's calling |
| `config/SecurityConfig.java` | Stateless chain, CSRF and form login disabled; everything but the public paths requires a token |
| `config/FirebaseConfig.java` | Initializes Firebase Admin from the service account credentials |
| `config/TapeFirebaseProperties.java` | Binds `tape.firebase.*` — the enabled flag and public path list |

### Auth and accounts

| File | What it does |
|---|---|
| `controller/AuthController.java` | `POST /api/auth/signup` and `/signin` |
| `service/FirebaseAccountService.java` | Deletes the Firebase Auth account when a user deletes their Tape account, so the email can be reused |
| `dto/SignUpRequest.java` | Signup payload including role and date of birth |

### Feature services

Each of these is documented in the feature doc it belongs to, listed here so
the package is complete:

| Area | Files | Doc |
|---|---|---|
| Users, profiles, bookmarks | `UserController`, `UserService`, `UserRepository`, `User`, `ProfileView`, `ProfileViewRepository`, `Bookmark`, `BookmarkRepository`, `BookmarkResponse` | [profiles.md](profiles.md) |
| Follows | `FollowController`, `FollowService`, `FollowRepository`, `Follow`, `FollowRequest`, `FollowCountsResponse` | [profiles.md](profiles.md) |
| Videos | `VideoController`, `VideoService`, `VideoRepository`, `Video`, `VideoFeedResponse`, `VideoPublishRequest`, `VideoCategory` | [feed.md](feed.md), [upload.md](upload.md) |
| Messaging | `ConversationController`, `MessageService`, `ConversationRepository`, `MessageRepository`, `Conversation`, `Message`, and their DTOs | [messaging.md](messaging.md) |
| Recruiting | `ScoutingBoardController`, `ScoutingBoardService`, `ScoutingBoardRepository`, `ScoutingBoard`, `SavedAthleteController`, `SavedAthleteService`, `SavedAthleteRepository`, `SavedAthlete`, `SavedAthleteRequest` | [recruiting.md](recruiting.md) |
| Moderation | `ModerationController`, `ModerationService`, `BlockRepository`, `ReportRepository`, `Block`, `Report`, `ReportRequest`, `BlockRequest`, `ReportTargetType` | [moderation.md](moderation.md) |
| Subscriptions | `SubscriptionRepository`, `Subscription`, `SubscriptionSyncRequest`, `SubscriptionTier` | [subscriptions.md](subscriptions.md) |

### Legacy

| File | What it does |
|---|---|
| `controller/UploadController.java` · `service/S3Service.java` · `config/S3Config.java` | A presigned-URL upload flow from before media moved to Firebase Storage. No client calls it. It stays because removing it means a migration for anyone still on an old build; delete once those are gone |

---

## Database

Flyway owns the schema; Hibernate runs in `validate` mode and only checks that
the entities match. Migrations live in
`backend/src/main/resources/db/migration/`.

| Table | Holds |
|---|---|
| `users` | Identity, role, tier, athlete vitals, recruiter org fields, social handles |
| `videos` · `video_tags` | Clips and their tags |
| `bookmarks` | Saved clips |
| `conversations` · `messages` | Threads and messages |
| `profile_views` | Who viewed whom, when |
| `scouting_boards` · `scouting_board_athletes` | Boards and membership |
| `saved_athletes` | Recruiter shortlists |
| `subscriptions` | Pro state per user |
| `follows` | The social graph |
| `blocks` · `reports` | Moderation |
| `athlete_target_schools` | An athlete's ranked school list |

School identity is *not* in the database. Both clients ship a static catalog
keyed by ESPN team ID, and the database stores only the ID. The picker is
instant, and adding or renaming a school never needs a migration.

### Migrations

| Version | Change |
|---|---|
| `V1__baseline.sql` | Full schema at first release |
| `V2__moderation.sql` | `blocks` and `reports` |
| `V3__user_date_of_birth.sql` | Age gating; nullable so existing rows stay valid |
| `V4__follows_and_view_counts.sql` | `follows` and per-video view counters |
| `V5__schools_and_saved_athletes.sql` | School affiliations and `saved_athletes` |
| `V6__social_handles.sql` | Instagram and TikTok |
| `V7__snapchat_handle.sql` | Snapchat |

**Never edit an applied migration**, including the baseline — add a new
`V{n}__description.sql`. The production database predates Flyway, so
`baseline-on-migrate` is on with `baseline-version=1`: the existing tables are
marked applied and V2 onward run normally.

---

## Tests

`TapeApiApplicationTests.java` runs under the `local` profile against in-memory
H2 with Flyway off and Hibernate `create-drop`, since the migrations are
PostgreSQL-flavored. It covers endpoint availability and status codes,
cross-user authorization, the Pro gates, the free DM cap, and the error shape.

```bash
cd backend && mvn test
```

---

## Deployment

Render, from `backend/`. `Dockerfile` and `Procfile` define the runtime,
`system.properties` pins the Java version, and the Firebase service account
arrives as a mounted secret file. Setting `TAPE_FIREBASE_ENABLED=true` is what
turns authentication on — without it every route is public, which is correct
locally and catastrophic in production. Verify it after any environment change.
