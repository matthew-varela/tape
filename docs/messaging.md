# Messaging

## How it works

One-to-one threads between recruiters or brands and athletes.

**Athletes cannot start conversations.** Only recruiters and brands can, and
the backend enforces it rather than trusting the client. Many athletes on Tape
are minors, so this is a safety rule, not a product tier.

There are no WebSockets or push notifications yet. Both the inbox and open
threads poll every 8 seconds, which feels live enough without hammering the
server, and pull-to-refresh covers impatient users. Polling tasks are held as
properties so they can be cancelled the moment a view disappears.

Both merge functions compare incoming data against what's on screen and only
mutate when something actually changed, so a poll cycle that returns identical
data doesn't cause SwiftUI to re-diff the list.

### DM cap

Free recruiters and brands are capped at 10 direct messages per month. The
server enforces the cap and returns 403; the app checks it locally too — when
opening a thread and again before sending — so the user sees the paywall
instead of a rejected send.

### Read receipts

Opening a thread calls `POST /api/conversations/{id}/read`, which marks the
*other* participant's messages as read. Your own messages are never touched, so
a sender can't manufacture a receipt for themselves. This also clears the
inbox unread badge.

Receipts are displayed to **Pro** users only; the marking happens for everyone,
because it's what drives unread counts.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Views/Inbox/InboxListView.swift` | Conversation list with avatars, last message, timestamps, and unread badges; starts and stops list polling |
| `Tape/Views/Inbox/ChatThreadView.swift` | A single thread: message bubbles, auto-scroll to newest, input bar, DM-cap check, mark-read on open, and report/block |
| `Tape/ViewModels/InboxViewModel.swift` | Conversations and messages, both polling loops, send, start conversation, mark read, and the `canInitiateMessage` cap check |
| `Tape/Services/MessageService.swift` | `MessageServiceProtocol` and `MockMessageService`: fetch conversations and messages, mark read, send, start thread |
| `Tape/Services/API/APIMessageService.swift` | REST implementation of the above |
| `Tape/Models/Message.swift` | `Conversation` and `Message` — see [architecture.md](architecture.md) |

### Backend

| File | What it does |
|---|---|
| `controller/ConversationController.java` | List conversations, start a thread, list messages, mark read, send |
| `service/MessageService.java` | Thread creation with the athlete-initiation ban, the free-tier DM cap, mark-read, and response mapping |
| `repository/ConversationRepository.java` | Lookup by participant pair or single participant |
| `repository/MessageRepository.java` | Messages by thread, unread counts, and the bulk mark-read update |
| `entity/Conversation.java` | A two-participant thread with a denormalized last-message summary |
| `entity/Message.java` | One message: sender, text, timestamp, read flag |
| `dto/ConversationResponse.java` | Thread summary with participant names, avatars, last message, and unread count |
| `dto/MessageResponse.java` · `dto/SendMessageRequest.java` · `dto/StartConversationRequest.java` | Message and thread payloads; legacy `senderId` and `initiatorId` fields are accepted but ignored |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/conversations` | The caller's threads, excluding blocked participants |
| POST | `/api/conversations` | Create or return the existing thread; 403 if the caller is an athlete |
| GET | `/api/conversations/{id}/messages` | Messages oldest to newest; participants only |
| POST | `/api/conversations/{id}/read` | Mark the other participant's messages read; idempotent |
| POST | `/api/conversations/{id}/messages` | Send; 403 once a free user hits 10 this month |
| POST | `/api/users/{id}/dm-sent` | Legacy counter acknowledgement, now a no-op |

---

## Known limitation

Polling means up to 8 seconds of delay on a new message, and no notification
when the app is closed. Push notifications are the natural next step; the
service protocol deliberately hides the transport, so swapping polling for
WebSockets or FCM only means changing the implementation, not any caller.
