# Tape — Documentation

Tape is a recruiting and highlight-sharing platform for high school athletes,
college recruiters, and brands. Athletes post short clips; recruiters discover,
shortlist, and message them.

Two codebases:

| | Stack | Location |
|---|---|---|
| **iOS app** | Swift 5.9, SwiftUI, iOS 17+ | `Tape/` |
| **API** | Java 21, Spring Boot 3.4, PostgreSQL | `backend/` |

---

## Start here

| Doc | What's in it |
|---|---|
| [architecture.md](architecture.md) | How the app is layered, shared infrastructure, models, and reusable components |
| [backend.md](backend.md) | Every backend file, the database schema, migrations, security, config, and deployment |

## Features

Each doc covers one feature end to end — the screens, the view model, the
client service, and the endpoints behind it.

| Doc | Covers |
|---|---|
| [auth.md](auth.md) | Sign up, sign in, session restore, age gating, account deletion |
| [feed.md](feed.md) | The vertical video feed, playback, prefetching, filters, view counts |
| [upload.md](upload.md) | Picking, trimming, tagging, and publishing a clip |
| [profiles.md](profiles.md) | Athlete and recruiter profiles, vitals, editing, follows, profile views |
| [search.md](search.md) | People search and filters |
| [messaging.md](messaging.md) | Inbox, chat threads, polling, DM caps, read receipts |
| [recruiting.md](recruiting.md) | Saved players and scouting boards |
| [moderation.md](moderation.md) | Reporting, blocking, and unblocking |
| [subscriptions.md](subscriptions.md) | Tape Pro, StoreKit, the paywall, and what's gated |
| [sharing.md](sharing.md) | Share sheet, deep links, and universal link setup |

## Operations

| Doc | Covers |
|---|---|
| [legal/](legal/) | Privacy Policy and Terms of Service, plus how to publish them |
| [deeplinks/](deeplinks/) | The `apple-app-site-association` file for universal links |
| [../BACKEND_CONTRACT.md](../BACKEND_CONTRACT.md) | Full HTTP contract: request/response shapes for every endpoint |
| [../backend/README.md](../backend/README.md) | Running the API locally, Firebase setup, deployment |

---

## Conventions used in these docs

Each feature doc has the same three sections:

1. **How it works** — the flow in a few sentences.
2. **Files** — every file involved, one line each.
3. **Endpoints** — the API routes the feature calls.

Files are listed once, in the doc where they primarily belong. Shared
infrastructure lives in [architecture.md](architecture.md).
