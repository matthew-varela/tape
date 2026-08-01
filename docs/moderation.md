# Moderation

## Why it exists

App Store Guideline 1.2 requires apps with user-generated content to offer a
way to report objectionable content, block abusive users, and act on reports.
Tape carries clips of minors, so this is the part of the app most likely to be
scrutinized in review.

## Reporting

Reachable anywhere content appears: the feed overlay, athlete profiles, and
chat threads. Reports target a `VIDEO`, `USER`, or `MESSAGE`, carry a reason
and optional free-text detail, and are written to a `reports` table for manual
review — there's no automated takedown.

Video reasons are category-aware. A clip in the **Tape** tab can be reported as
"Not sports-related" and a **Culture/NIL** clip as "Not NIL / Culture related",
in addition to the shared safety reasons. Miscategorized clips are the most
common problem, and a generic "Inappropriate content" wouldn't capture that.

## Blocking

Blocking is symmetric in effect. The server computes a hidden set of *everyone
you blocked plus everyone who blocked you*, and applies it to the feed, search,
conversation lists, and single-video lookups. A blocked user's clip returns 404
rather than a 403, so blocking isn't observable from the outside.

Blocking is idempotent, and blocking yourself returns 400.

Unblocking lives in **Settings → Blocked Accounts**. The block list stores IDs
only, so the screen resolves each one to a profile to show names and avatars —
a list of opaque IDs would be useless.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Services/ModerationService.swift` | `ReportTargetType`, the `ModerationReason` catalog including the category-aware video reasons, `ModerationServiceProtocol`, and the mock |
| `Tape/Services/API/APIModerationService.swift` | REST implementation of report, block, unblock, and the block list |
| `Tape/Views/Settings/BlockedUsersView.swift` | The blocked-accounts screen: resolves IDs to profiles, unblocks, empty state |
| `Tape/Views/Feed/VideoOverlayView.swift` | Report and block from the feed |
| `Tape/Views/Profile/AthleteProfileView.swift` | Report and block from a profile |
| `Tape/Views/Inbox/ChatThreadView.swift` | Report and block from a thread |

### Backend

| File | What it does |
|---|---|
| `controller/ModerationController.java` | Report, list blocks, block, unblock |
| `service/ModerationService.java` | Block lifecycle, `getHiddenUserIds` (both directions), `isEitherBlocked`, and report persistence |
| `repository/BlockRepository.java` | Block rows, blocked and blocker ID lists, existence checks |
| `repository/ReportRepository.java` | Report persistence |
| `entity/Block.java` | A directed block edge |
| `entity/Report.java` | Reporter, target type and ID, reason, details, timestamp |
| `enums/ReportTargetType.java` | `VIDEO`, `USER`, `MESSAGE` |
| `dto/ReportRequest.java` · `dto/BlockRequest.java` | Request payloads |

Enforcement is not centralized in one place — each service applies the hidden
set itself. `VideoService` filters the feed and single lookups, `UserService`
filters search results, `MessageService` filters conversations, and
`FollowService` refuses follows between blocked users.

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/reports` | File a report — `{ targetType, targetId, reason, details? }` |
| GET | `/api/blocks` | IDs the caller has blocked |
| POST | `/api/blocks` | Block — `{ userId }`; idempotent, 400 on self |
| DELETE | `/api/blocks/{userId}` | Unblock; idempotent |

---

## Not built yet

Reports accumulate in the database with no admin surface — reviewing them means
querying Postgres directly. A moderation dashboard, or at minimum an alert when
a single video crosses a report threshold, is the obvious next step. Worth
having a plan for it before the user base grows enough to make manual review
impractical.
