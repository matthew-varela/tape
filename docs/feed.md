# Feed

## How it works

A vertical paging feed of full-screen clips. Three streams share one screen:

- **For You** — everything, newest first
- **Following** — only athletes the user follows
- **Search** — filtered results, recruiters and brands on Pro only

Each stream paginates independently at 10 clips per page and keeps its own
cursor, so switching tabs doesn't reset your place. The page cursor only
advances on a successful response, so a dropped request retries the same page
rather than skipping it.

### What drives playback

Playback follows `scrollPosition` — the cell the scroll view has actually
settled on — not each cell's `onAppear`. A `LazyVStack` builds cells before
they're visible, so `onAppear` used to start the clip below the one being
watched and play its audio over the top.

On iOS 18, playback additionally waits for the scroll to come to a complete
stop (`onScrollPhaseChange`). Starting a decoder mid-swipe was what made
scrolling feel like it caught.

### Prefetching

`VideoPlayerManager` keeps players alive for the four clips on either side of
the current one, each buffered to a few seconds via
`preferredForwardBufferDuration`. The radius is deliberately modest: the cost
is `2 × radius + 1` live players, and iOS starts starving video decode
pipelines somewhere around 16 simultaneous ones — crowding that ceiling stalls
the whole feed rather than one clip.

Warming and teardown are deferred off the main thread and rescheduled on every
swipe, so the work never lands during a paging animation.

### Poster frames

A clip that hasn't buffered shows its thumbnail, cross-fading to video once the
layer reports `isReadyForDisplay`. The two can't simply be swapped: thumbnails
are generated from the middle of a clip while playback starts at zero, so the
images never match and a hard swap reads as a glitch.

### View counts

Counted per play, not per unique viewer — watching the same clip ten times is
ten views. Recorded after playback settles, and deliberately not on the main
path, since a missed analytics ping should never interrupt playback.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Views/Feed/FeedView.swift` | The feed screen: stream toggle, paging scroll view, activation and prefetch scheduling, report and block dialogs, and the share sheet |
| `Tape/Views/Feed/VideoPlayerView.swift` | `VideoPlayerManager` (owns every `AVPlayer`, mute and play/pause state, and which clip is active) plus the `UIViewRepresentable` that hosts the player layer and reports readiness |
| `Tape/Views/Feed/VideoOverlayView.swift` | The chrome over each clip: athlete info, caption, tags, and the follow, bookmark, share, mute, and more-options rail |
| `Tape/Views/Feed/FeedFilterSheet.swift` | Filter sheet for the search stream — position, state, sport, grad year, minimum GPA |
| `Tape/ViewModels/FeedViewModel.swift` | Owns all three streams and their pagination, bookmark and follow state, view counting, and the local hide-athlete-after-block behavior |
| `Tape/Services/VideoService.swift` | `VideoServiceProtocol` and `MockVideoService`: feeds, single-clip lookup, athlete clips, filtered search, publish, bookmarks, pins; also declares `FeedFilters` |
| `Tape/Services/API/APIVideoService.swift` | REST implementation of the above |
| `Tape/Support/AudioSession.swift` | Keeps feed audio audible with the ringer switch silenced |
| `Tape/Utilities/VideoCache.swift` | Actor-backed `AVPlayerItem` cache |
| `Tape/Components/ActionButton.swift` | The action-rail button style |

### Backend

| File | What it does |
|---|---|
| `controller/VideoController.java` | Feed, following feed, single video, athlete videos, filtered search, publish, view counting, and pin/unpin |
| `service/VideoService.java` | Feed queries with block filtering, publish, view increments, the Pro-and-owner pin gate, and DTO mapping |
| `repository/VideoRepository.java` | Paginated feed queries, block-excluded variants, athlete lookups, and the atomic view-count increment |
| `entity/Video.java` | The clip row: URL, thumbnail, category, tags, caption, pin flag, view count |
| `dto/VideoFeedResponse.java` | The feed row, with athlete profile fields denormalized onto it |
| `dto/VideoPublishRequest.java` | Publish payload — see [upload.md](upload.md) |
| `enums/VideoCategory.java` | `TAPE` or `CULTURE` |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/videos/feed?page=&size=` | Discover stream, excluding blocked users |
| GET | `/api/videos/feed/following?page=&size=` | Clips from followed athletes only |
| GET | `/api/videos/{id}` | One clip — backs shared links, see [sharing.md](sharing.md) |
| GET | `/api/videos?athleteId=&category=` | An athlete's clips, pinned first |
| GET | `/api/videos/search` | Filtered search by athlete attributes (Pro) |
| POST | `/api/videos/{id}/view` | Record one play |
| PUT | `/api/videos/{id}/pin` · `/unpin` | Pin a clip to the profile grid (Pro, owner only) |
