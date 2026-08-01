# Sharing and deep links

## Sharing a clip

The share button in the feed and in the profile's full-screen player opens
`VideoShareSheet` — a bottom sheet showing the clip's thumbnail, the athlete's
name, and the caption, with three actions: copy link, send to Messages, and
open the system share sheet for everything else.

The preview matters. Recruiters share clips into group chats, and a sheet that
confirms *which* clip is going out prevents sending the wrong one.

## The link format

Shared links are `https://watchtape.app/video/{id}`, not `tape://video/{id}`.

A custom scheme looks broken to anyone who doesn't have the app installed —
most share destinations won't even render it as a tappable link. An https link
is always tappable, opens the app directly once universal links are live, and
otherwise lands on a web page that can send the recipient to the App Store.
Since the whole point of sharing is reaching people who *don't* have Tape yet,
the custom scheme would defeat the feature.

## Handling an incoming link

`DeepLink.init?(url:)` parses both forms and resolves them to the same
destination, so turning universal links on later is purely configuration — no
routing code changes. For the custom scheme it accepts the ID from either the
host or the path component, since `tape://video/123` and `tape:/video/123`
parse differently but users and share targets produce both.

`TapeApp` receives the URL through `onOpenURL` and hands it to
`DeepLinkRouter`, which fetches the video and publishes it. `ContentView`
presents it in a full-screen cover, shows a spinner while the fetch is in
flight, and alerts if the clip is gone or the poster is blocked. A deleted clip
returns 404 and produces a readable message rather than a silent no-op — a link
that appears to do nothing reads as a broken app.

## Universal links setup

Two things are still required and neither is code:

1. Serve `docs/deeplinks/apple-app-site-association` at
   `https://watchtape.app/.well-known/apple-app-site-association`, over HTTPS,
   with `Content-Type: application/json` and **no** `.json` extension. Replace
   `REPLACE_WITH_TEAM_ID` with the Apple Developer Team ID first.
2. Add the Associated Domains capability in Xcode with
   `applinks:watchtape.app`.

Until both are done, https links open Safari and only `tape://` reaches the
app. Everything on the app side already works.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Support/AppLinks.swift` | The host and scheme constants, legal and support URLs, `shareURL(videoID:)`, and the `DeepLink` parser |
| `Tape/Components/VideoShareSheet.swift` | The share sheet: preview, copy link, Messages, and the system share sheet |
| `Tape/Support/DeepLinkRouter.swift` | Resolves an incoming link to a video and exposes the resolving and error state |
| `Tape/App/TapeApp.swift` | `onOpenURL` — hands incoming URLs to the router |
| `Tape/App/ContentView.swift` | Presents the resolved clip, the loading overlay, and the failure alert |
| `Tape/Resources/Info.plist` | Registers the `tape` scheme under `CFBundleURLTypes` |
| `docs/deeplinks/apple-app-site-association` | The file the web host must serve |

### Backend

| File | What it does |
|---|---|
| `controller/VideoController.java` | `GET /api/videos/{id}` — the single-clip lookup a deep link resolves against |
| `service/VideoService.java` | Returns 404 for a missing clip *or* a blocked poster, so blocks aren't observable |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/videos/{id}` | Resolve a shared link; 404 if missing or blocked |

---

## Not built yet

Nothing serves `https://watchtape.app/video/{id}` in a browser. Someone without
the app currently gets a 404 instead of a landing page. A minimal page with the
thumbnail, Open Graph tags so the link unfurls in iMessage and Twitter, and an
App Store button would make shared links do real acquisition work.
