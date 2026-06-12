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
  "role": "ATHLETE | RECRUITER | BRAND"
}
```

Response: `User`

Errors:
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
  "organization": "string?",
  "title": "string?",
  "dmsSentThisMonth": 0
}
```

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
