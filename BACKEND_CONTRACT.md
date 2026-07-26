# Tape Backend Contract

This document is the source of truth for every HTTP endpoint the iOS and
future Android clients expect. The base URL configured in `APIClient.swift` is:

```
https://tape-cf2k.onrender.com
```

## Conventions

- All requests carry an `Authorization: Bearer <Firebase ID token>` header.
  The server resolves the calling user from the token's Firebase UID claim.
- `User.id` equals the Firebase UID. There is no separate server-generated
  user id — this keeps auth identity and app identity in sync across platforms.
- All requests/responses are JSON. Dates are ISO-8601 strings (with or
  without fractional seconds — the client accepts both).
- Enum values (`UserRole`, `SubscriptionTier`, `VideoCategory`) are sent
  uppercase: `ATHLETE`, `RECRUITER`, `BRAND`, `FREE`, `PRO`, `TAPE`, `CULTURE`.
- Errors respond with a non-2xx status and a JSON body `{ "message": "..." }`.
  The client surfaces `message` to the user.
- **Authorization rule:** callers can only mutate resources they own. Any
  client-supplied `initiatorId`, `senderId`, `athleteId`, or `ownerId` field
  in a request body is accepted for documentation purposes but is overridden
  by the verified token identity on the server. Both iOS and Android must
  therefore send a valid Bearer token; they must never forge another user's id.

---

## Health

### `GET /api/health`

Public (no auth required). Returns server status.

Response: `{ "status": "UP" }`

---

## Auth

### `POST /api/auth/signup`

Called after the client successfully creates a Firebase auth user. The server
mints the persistent `User` record using the **token uid** as the user id.
The `firebaseUid` field in the body is accepted for documentation purposes
but the server derives identity from the verified Bearer token.

Request:
```json
{
  "displayName": "string",
  "role": "ATHLETE | RECRUITER | BRAND",
  "dateOfBirth": "yyyy-MM-dd"
}
```

`dateOfBirth` is required (age gating). The response `User` includes a derived
`minor` boolean (true when under 18).

Response: `User`

Errors:
- `400` — `dateOfBirth` missing/invalid, or the user is under 13.
- `409` — a user with that Firebase UID already exists.

### `POST /api/auth/signin`

Called after Firebase sign-in succeeds. The server looks up and returns the
user record for the authenticated token. The `email` body field is ignored
server-side; identity comes from the token.

Request:
```json
{ "email": "string" }
```

Response: `User`

Errors:
- `404` — no user record exists yet (client should call `/signup` first).

---

## Users / Profiles

### `GET /api/users/me`

Returns the canonical `User` record for the authenticated caller.
Used at app launch and after profile edits or subscription changes.

Response: `User`

### `DELETE /api/users/me`

Permanently deletes the authenticated caller's account and all associated data
(videos, bookmarks, conversations, messages, profile views, scouting boards,
subscription, block/report rows), plus their Firebase Auth user. Required for
App Store compliance. Returns `204 No Content`.

### `GET /api/users/{id}`

Returns a public `User` by id. Returns 404 if the user does not exist.

Response: `User`

### `GET /api/users?role=ATHLETE`

List endpoint; primarily used as a fallback for the search screen.

Response: `[User]`

### `GET /api/users/search`

Server-side filtered search across all users.

Query parameters (all optional):
- `q`        — free text matched against display name, school, and sport
- `role`     — `ATHLETE | RECRUITER | BRAND`
- `position` — e.g. `QB`
- `state`    — 2-letter state code
- `sport`    — e.g. `Football`

Response: `[User]`

### `PUT /api/users/{id}`

Updates the caller's own profile. `{id}` must match the authenticated Firebase
UID; the server returns `403` if it does not.

Request: Partial or full `User` JSON — only non-null fields are applied.

Response: Updated `User`

### `GET /api/users/{id}/viewers`

Returns the users who viewed the athlete's profile this week.
**Pro feature** — the server returns `403` for FREE-tier callers.

Response: `[User]`

### `POST /api/users/{id}/dm-sent`

Legacy client hook kept for backward compatibility. The DM counter is now
enforced server-side when a message is sent; this endpoint is a no-op that
always returns 204 for valid authenticated callers.

Request: empty body.
Response: 204 No Content.

### `POST /api/users/me/subscription`

Sync hook called after a StoreKit (iOS) or Play Billing (Android) purchase,
refund, or renewal. The server updates the caller's `tier` and records the
platform so billing history remains cross-platform.

Request:
```json
{ "active": true }
```
Response: 204 No Content.

---

## Videos

### `GET /api/videos/feed?page={n}&size=10`

Paginated discover feed. Returns at most 10 videos at a time; client paginates
by incrementing `page`.

Response: `[Video]`

### `GET /api/videos/feed/following?page={n}&size=10`

Same shape as the discover feed, restricted to athletes the caller follows.
Returns an empty array when the caller follows nobody — the client shows a
"find people to follow" empty state rather than falling back to discover.

Response: `[Video]`

### `POST /api/videos/{id}/view`

Records one play. Views are counted **per play, not per unique viewer** — the
same person watching a clip 100 times is 100 views, including the athlete
watching their own clip. Clients call this every time a clip becomes the active
one in the feed. Returns `204 No Content`.

### `GET /api/videos?athleteId={id}&category=TAPE|CULTURE`

Lists an athlete's videos sorted pinned-first, then newest-first.
`category` is optional.

Response: `[Video]`

### `GET /api/videos/search`

Filtered video search (recruiter/brand feature).

Query parameters (all optional):
- `position`
- `state`
- `sport`
- `gradYear`
- `minGpa`

Response: `[Video]`

### `POST /api/videos`

Persists video metadata after the client uploads the file and thumbnail to
Firebase Storage. The body carries the Firebase Storage download URLs. The
`athleteId` in the body is ignored — the authenticated caller is the athlete.

Request:
```json
{
  "videoUrl": "https://...",
  "thumbnailUrl": "https://...",
  "category": "TAPE | CULTURE",
  "tags": ["string"],
  "caption": "string"
}
```

Response: `Video`

### `PUT /api/videos/{id}/pin`

Pins a video so it shows first in the athlete's profile grid.
**Pro feature** — returns `403` for FREE-tier callers. Caller must own the video.

Response: `Video` (with `isPinned = true`).

### `PUT /api/videos/{id}/unpin`

Removes the pin on a video.
**Pro feature** — returns `403` for FREE-tier callers. Caller must own the video.

Response: `Video` (with `isPinned = false`).

---

## Bookmarks

### `GET /api/users/{id}/bookmarks`

Returns the IDs of videos the user has saved. Caller must be the same user.

Response:
```json
{ "videoIds": ["string"] }
```

### `GET /api/users/{id}/bookmarks/videos`

Returns full `Video` records for the user's saved clips, newest save first, so
the profile's Saved tab renders in one request. Caller must be the same user.

Response: `[Video]`

### `POST /api/users/{id}/bookmarks`

Adds a bookmark. Caller must be the same user.

Request:
```json
{ "videoId": "string" }
```
Response: 204 No Content.

### `DELETE /api/users/{id}/bookmarks/{videoId}`

Removes a bookmark. Caller must be the same user.

Response: 204 No Content.

---

## Saved Players

A recruiter's or brand's flat shortlist of athletes — the profile equivalent of
a video bookmark. Distinct from scouting boards, which are named, deliberately
organised groups. The scout is always the authenticated caller, so none of these
routes take a user id.

### `GET /api/saved-athletes`

The caller's saved athletes, newest save first.

Response: `[User]`

### `POST /api/saved-athletes`

Saves a player. Idempotent — saving an already-saved athlete is a no-op.
`403` if the caller is an athlete or either party has blocked the other;
`400` if the target is not an athlete.

Request:
```json
{ "athleteId": "string" }
```
Response: 204 No Content.

### `DELETE /api/saved-athletes/{athleteId}`

Removes a player from the shortlist. Idempotent.

Response: 204 No Content.

---

## Schools

School identity is **not** stored in Postgres. The catalog of FBS programs
(name, mascot, conference, brand color, logo URL) ships with each client as a
static bundled asset — `Tape/Resources/fbs-schools.json` on iOS — and the
database persists only the selected ids (`User.schoolId`,
`User.targetSchoolIds`).

Rationale: the list is static reference data that changes roughly once a year
with conference realignment. Bundling it means the picker and every profile
header render instantly with no network round trip and no join on profile reads,
and fixing a logo or a rename ships with a client update instead of a migration.
There is no `GET /api/schools` endpoint. If a third client ever needs the
catalog without a release cycle, promote the same JSON to a served static
resource; the stored ids don't change.

Ids are ESPN team ids, which is also what the logo CDN is keyed on
(`https://a.espncdn.com/i/teamlogos/ncaa/500/{id}.png`).

---

## Scouting Boards

### `GET /api/scouting-boards?ownerId={id}`

All boards for a recruiter/brand. The server uses the authenticated caller's
uid as the owner; the `ownerId` query param is accepted for forward compat
but the token takes precedence.

Response: `[ScoutingBoard]` (with nested `owner` and `athletes` objects).

### `POST /api/scouting-boards`

Creates a new board. The board owner is the authenticated caller.

Request:
```json
{ "name": "string" }
```

Response: `ScoutingBoard`.

### `PATCH /api/scouting-boards/{id}`

Renames a board. Caller must own the board.

Request:
```json
{ "name": "string" }
```

Response: `ScoutingBoard`.

### `DELETE /api/scouting-boards/{id}`

Deletes a board. Caller must own the board.

Response: 204 No Content.

### `POST /api/scouting-boards/{id}/athletes`

Adds an athlete to the board. Caller must own the board.

Request:
```json
{ "athleteId": "string" }
```

Response: `ScoutingBoard`.

### `DELETE /api/scouting-boards/{id}/athletes/{athleteId}`

Removes an athlete from the board. Caller must own the board.

Response: `ScoutingBoard`.

---

## Messaging

### `GET /api/conversations`

All threads the caller is in, sorted by `lastMessageDate` desc.

Response: `[Conversation]`.

### `GET /api/conversations/{id}/messages`

All messages in a conversation, oldest → newest.
Caller must be a participant.

Response: `[Message]`.

### `POST /api/conversations/{id}/messages`

Sends a new message. The `senderId` in the body is accepted for documentation
but the server uses the authenticated caller's uid. Free-tier users are
limited to 10 DMs per month; returns `403` once the cap is reached.

Request:
```json
{ "senderId": "string", "text": "string" }
```

Response: `Message`.

### `POST /api/conversations`

Creates (or returns the existing) thread between two users. Idempotent.
Athletes cannot initiate conversations (returns `403`).
The `initiatorId` in the body is accepted for documentation but the server
uses the authenticated caller's uid.

Request:
```json
{ "initiatorId": "string", "recipientId": "string" }
```

Response: `Conversation`.

Blocking rules: starting a conversation with (or sending a message to) a user
who is blocked in either direction returns `403`.

---

## Moderation

User-generated-content safety endpoints (App Store Guideline 1.2). Blocking is
bidirectional for visibility: blocked users are hidden from the caller's feed,
search, and inbox, and neither party can message the other.

### `POST /api/reports`

Reports a video, user, or message. The reporter is the authenticated caller.
Returns `201 Created`.

Request:
```json
{ "targetType": "VIDEO|USER|MESSAGE", "targetId": "string", "reason": "string", "details": "string (optional)" }
```

### `GET /api/blocks`

Returns the IDs of users the caller has blocked.

Response: `["userId", ...]`

### `POST /api/blocks`

Blocks a user. Idempotent. Returns `400` if blocking yourself, otherwise
`204 No Content`.

Request:
```json
{ "userId": "string" }
```

### `DELETE /api/blocks/{userId}`

Unblocks a user. Idempotent. Returns `204 No Content`.

---

## Follows

Follows are one-directional and need no approval, matching public accounts on
TikTok and Instagram. The follower is always the authenticated caller.

### `GET /api/follows/following`

IDs of the users the caller follows. The client caches this so the feed and
profile can render follow state without a request per row.

Response: `["userId"]`

### `POST /api/follows`

Follows a user. Idempotent. Returns `204 No Content`.
Returns `400` for following yourself and `403` if either party has blocked the
other.

Request:
```json
{ "userId": "string" }
```

### `DELETE /api/follows/{userId}`

Unfollows a user. Idempotent. Returns `204 No Content`.

### `GET /api/follows/{userId}/counts`

Social counters for one profile. `isFollowing` is relative to the caller.

Response:
```json
{
  "followers": 0,
  "following": 0,
  "isFollowing": false
}
```

---

## Schemas

### `User`
```json
{
  "id": "string (Firebase UID)",
  "email": "string",
  "displayName": "string",
  "role": "ATHLETE | RECRUITER | BRAND",
  "tier": "FREE | PRO",
  "dateOfBirth": "yyyy-MM-dd?",
  "minor": false,
  "profileImageUrl": "string?",
  "highSchool": "string?",
  "gradYear": 2026,
  "sport": "string?",
  "position": "string?",
  "state": "string?",
  "height": "string?",
  "weight": "string?",
  "fortyYardDash": "string?",
  "gpa": 3.8,
  "targetSchoolIds": ["string"],
  "organization": "string?",
  "title": "string?",
  "schoolId": "string?",
  "dmsSentThisMonth": 0
}
```

`targetSchoolIds` (athletes) is a **ranked** list — index 0 is the athlete's top
choice. `schoolId` (recruiters) is the program they coach for. Both hold ids
from the static school catalog described under [Schools](#schools); the server
never validates them against a table, so clients must tolerate an unknown id by
rendering nothing rather than erroring.

### `Video`
```json
{
  "id": "string",
  "athleteId": "string",
  "videoUrl": "https://...",
  "thumbnailUrl": "https://...",
  "category": "TAPE | CULTURE",
  "tags": ["string"],
  "caption": "string",
  "createdAt": "2026-01-01T00:00:00Z",
  "isPinned": false,
  "viewCount": 0,
  "athleteName": "string",
  "athleteSchool": "string",
  "athleteGradYear": 2026,
  "athletePosition": "string",
  "athleteProfileImageUrl": "string?"
}
```

### `Conversation`
```json
{
  "id": "string",
  "participantIds": ["string"],
  "participantNames": { "userId": "displayName" },
  "participantImageUrls": { "userId": "https://..." },
  "lastMessage": "string",
  "lastMessageDate": "2026-01-01T00:00:00Z",
  "unreadCount": 0,
  "initiatedByRole": "RECRUITER | BRAND"
}
```

### `Message`
```json
{
  "id": "string",
  "conversationId": "string",
  "senderId": "string",
  "text": "string",
  "sentAt": "2026-01-01T00:00:00Z",
  "isRead": false
}
```

### `ScoutingBoard`
```json
{
  "id": "string",
  "name": "string",
  "createdAt": "2026-01-01T00:00:00Z",
  "owner": { "id": "string" },
  "athletes": [ { "id": "string" } ]
}
```

---

## Storage

Video files and avatar images are uploaded **directly to Firebase Storage**
by the iOS or Android client using the Firebase SDK. The download URLs
returned by Firebase are sent to the backend in `POST /api/videos` and
`PUT /api/users/{id}` payloads — the server never proxies media bytes.

Object paths:
- Videos:    `videos/{athleteId}/{uuid}.mp4`
- Thumbs:    `thumbnails/{athleteId}/{uuid}.jpg`
- Avatars:   `profileImages/{userId}/{uuid}.jpg`

There is no S3 / presigned-URL upload path for mobile clients.

---

## Error Responses

All errors return a JSON body:
```json
{ "message": "Human-readable explanation" }
```

Common status codes:
- `400` — invalid request body or parameters
- `401` — missing or invalid Bearer token
- `403` — valid token but insufficient permissions or tier
- `404` — resource not found
- `409` — conflict (e.g. user already exists)
- `500` — unexpected server error

---

## Cross-Platform Notes

The backend is designed to be platform-neutral. When an Android client is added:

1. Use the same `Authorization: Bearer <Firebase ID token>` header with the
   Firebase Android SDK.
2. Upload media to Firebase Storage using the Android SDK; post the resulting
   download URL to the same `POST /api/videos` endpoint.
3. For subscriptions, call `POST /api/users/me/subscription` after a Google
   Play Billing purchase. The server records the platform so billing history
   is cross-platform.
4. All JSON schemas, enum values, and error shapes are identical — no
   platform-specific endpoints or response variations exist.
