# Tape Backend Contract

This document is the source of truth for every HTTP endpoint the iOS client
expects. The base URL configured in `APIClient.swift` is:

```
https://tape-cf2k.onrender.com
```

## Conventions

- All requests carry an `Authorization: Bearer <Firebase ID token>` header.
  The server resolves the calling user from the token's `firebase_uid` claim.
- All requests/responses are JSON. Dates are ISO-8601 strings (with or
  without fractional seconds — the client accepts both).
- Enum values (`UserRole`, `SubscriptionTier`, `VideoCategory`) are sent
  uppercase: `ATHLETE`, `RECRUITER`, `BRAND`, `FREE`, `PRO`, `TAPE`,
  `CULTURE`.
- IDs are server-generated UUID strings.
- Errors should respond with a non-2xx status and a JSON body
  `{ "message": "..." }`. The client surfaces `message` to the user.

---

## Auth

### `POST /api/auth/signup`

Called after the client successfully creates a Firebase auth user. The server
mints the persistent `User` record.

Request:
```json
{
  "firebaseUid": "string",
  "email": "string",
  "displayName": "string",
  "role": "ATHLETE | RECRUITER | BRAND"
}
```

Response: `User`

### `POST /api/auth/signin`

Called after Firebase sign-in succeeds. The server returns the latest copy of
the user record. (The bearer token authenticates the caller, so the body is
just an extra hint.)

Request:
```json
{ "email": "string" }
```

Response: `User`

---

## Users / Profiles

### `GET /api/users/me`

Returns the canonical `User` record for the caller. Used at app launch and
after profile edits / subscription changes to refresh the in-memory state.

Response: `User`

### `GET /api/users/{id}`

Returns a public `User` by id. Returns 404 if the user does not exist.

### `GET /api/users?role=ATHLETE`

List endpoint; primarily used as a fallback for the search screen.

Response: `[User]`

### `GET /api/users/search`

Server-side full-text + filtered search.

Query parameters (all optional):
- `q`         — free text
- `role`      — `ATHLETE | RECRUITER | BRAND`
- `position`  — e.g. `QB`
- `state`     — 2-letter state code
- `sport`     — e.g. `Football`

Response: `[User]`

### `PUT /api/users/{id}`

Updates the user's profile. Body is the full `User` record. Returns the
saved record.

### `GET /api/users/{id}/viewers`

Returns the people who viewed the athlete's profile this week.
**Pro feature** — server should return 403 for free callers (the client
shows a paywall instead).

Response: `[User]`

### `POST /api/users/{id}/dm-sent`

Increments the `dmsSentThisMonth` counter on the user. Called by the iOS
client immediately after a recruiter/brand sends a DM, so the free-tier
10-DMs-per-month cap is enforceable instantly.

Request: empty body.
Response: 204 No Content.

### `POST /api/users/me/subscription`

Sync hook called by the iOS `SubscriptionManager` after a StoreKit
purchase / refund / renewal. The server should update `tier`, but treat
StoreKit as the ultimate source of truth.

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

Lists an athlete's videos. `category` is optional.

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

Persists video metadata after the iOS client has uploaded the file and
thumbnail to Firebase Storage. The body carries the storage URLs.

Request:
```json
{
  "athleteId": "string",
  "videoUrl": "https://...",
  "thumbnailUrl": "https://...",
  "category": "TAPE | CULTURE",
  "tags": ["string"],
  "caption": "string"
}
```

Response: `Video`

### `PUT /api/videos/{id}/pin`

Pins a video so it shows first in the athlete's profile grid. **Pro feature.**

Response: `Video` (with `isPinned = true`).

### `PUT /api/videos/{id}/unpin`

Removes the pin.

Response: `Video` (with `isPinned = false`).

---

## Bookmarks

### `GET /api/users/{id}/bookmarks`

Returns the IDs of videos the user has saved.

Response:
```json
{ "videoIds": ["string"] }
```

### `POST /api/users/{id}/bookmarks`

Adds a bookmark.

Request:
```json
{ "videoId": "string" }
```
Response: 204 No Content.

### `DELETE /api/users/{id}/bookmarks/{videoId}`

Removes a bookmark.

Response: 204 No Content.

---

## Scouting Boards

### `GET /api/scouting-boards?ownerId={id}`

All boards for a recruiter/brand.

Response: `[ScoutingBoard]` (with nested `owner` and `athletes` objects).

### `POST /api/scouting-boards`

Creates a new board.

Request:
```json
{ "ownerId": "string", "name": "string" }
```

Response: `ScoutingBoard`.

### `PATCH /api/scouting-boards/{id}`

Renames a board.

Request:
```json
{ "name": "string" }
```

Response: `ScoutingBoard`.

### `DELETE /api/scouting-boards/{id}`

Deletes a board.

Response: 204 No Content.

### `POST /api/scouting-boards/{id}/athletes`

Adds an athlete to the board.

Request:
```json
{ "athleteId": "string" }
```

Response: `ScoutingBoard`.

### `DELETE /api/scouting-boards/{id}/athletes/{athleteId}`

Removes an athlete.

Response: `ScoutingBoard`.

---

## Messaging

### `GET /api/conversations?userId={id}`

All threads the user is in, sorted by `lastMessageDate` desc.

Response: `[Conversation]`.

### `GET /api/conversations/{id}/messages`

All messages in a conversation, oldest → newest.

Response: `[Message]`.

### `POST /api/conversations/{id}/messages`

Sends a new message.

Request:
```json
{ "senderId": "string", "text": "string" }
```

Response: `Message`.

### `POST /api/conversations`

Creates (or returns the existing) thread between two users. Idempotent.

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
  "id": "string",
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
  "profileViewsThisWeek": 0,
  "profileViewerIDs": ["string"],
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

The server should return a nested form for ergonomics:
```json
{
  "id": "string",
  "name": "string",
  "createdAt": "2026-01-01T00:00:00Z",
  "owner": { "id": "string" },
  "athletes": [ { "id": "string" } ]
}
```

The client also accepts a flat form (`ownerId`, `athleteIds`) for tests.

---

## Storage

Video files and avatar images are uploaded directly to Firebase Storage by
the iOS client. The download URLs returned by Firebase are sent to the
backend in the `POST /api/videos` and `PUT /api/users/{id}` payloads — the
server never proxies media bytes.

Object paths:
- Videos:   `videos/{athleteId}/{uuid}.mp4`
- Thumbs:   `thumbnails/{athleteId}/{uuid}.jpg`
- Avatars:  `profileImages/{userId}/{uuid}.jpg`
