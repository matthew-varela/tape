# Profiles

## How it works

One screen serves every profile, and it changes based on two questions: whose
profile is this, and who's looking.

An **athlete profile** shows the photo, vitals dashboard, target schools,
social links, follower counts, and a grid of clips split into Tape and
Culture/NIL tabs. Viewing your own profile adds a third **Saved** tab of
bookmarked clips and a profile-views badge.

**Recruiters and brands** get a different profile tab entirely
(`CoachBrandProfileView` in `ContentView.swift`): org info, school banner, plan,
and shortcuts into Saved Players and Scouting Boards.

Loading is parallelized — the athlete record and both video categories are
fetched concurrently with `async let`, which is roughly three times faster than
awaiting them in sequence.

### The Saved tab

Refetches every time it's opened rather than caching after the first load.
Bookmarks are added from the feed, a different tab entirely, so a cached list
is stale the moment the user saves something — which is exactly when they come
looking for it. The existing list stays on screen during the refetch so
reopening doesn't flash empty, and the screen also listens for
`.tapeBookmarksChanged` so a save made while the tab is open is reflected
immediately.

### Profile views

Every profile fetch records a view. Athletes see a count; **Pro** athletes can
tap it to see exactly who viewed them, within a 7-day window.

### Pinning

Pro athletes can long-press one of their own clips to pin it to the top of the
grid. Free users get the paywall. Pinning is disabled on the Saved tab, since
saved clips belong to other people.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Views/Profile/AthleteProfileView.swift` | The profile screen — header, follow row, action buttons, media tabs and grid, pin handling, report and block, the profile-viewers sheet, and `FullScreenVideoPlayer` for tapping a tile |
| `Tape/Views/Profile/VitalsDashboard.swift` | The athlete measurables panel: height, weight, forty time, GPA, grad year, position |
| `Tape/Views/Profile/SchoolShowcase.swift` | `TopSchoolsRow` for an athlete's ranked target schools and `CoachSchoolBanner` for a recruiter's program |
| `Tape/Views/Profile/SchoolPickerView.swift` | Searchable FBS school picker used when editing a profile |
| `Tape/Views/Profile/SocialPlatformIcon.swift` | Instagram, TikTok, and Snapchat icons linking out to the athlete's handles |
| `Tape/Views/Profile/MediaGridView.swift` | A standalone reusable clip grid |
| `Tape/Views/Settings/EditProfileView.swift` | Editing: avatar upload, vitals, org fields, social handles, and target schools |
| `Tape/ViewModels/ProfileViewModel.swift` | Loads the profile, both video categories, saved clips, follow counts, profile viewers, and shortlist state; handles follow, shortlist, and pin toggles |
| `Tape/Services/ProfileService.swift` | `ProfileServiceProtocol` and `MockProfileService`: current user, athlete lookup, athlete list, search, profile viewers, update, delete |
| `Tape/Services/API/APIProfileService.swift` | REST implementation of the above |
| `Tape/Services/FollowService.swift` | `FollowServiceProtocol`, `FollowCounts`, and the mock |
| `Tape/Services/API/APIFollowService.swift` | REST implementation of follow, unfollow, following IDs, and counts |
| `Tape/Components/VideoThumbnailTile.swift` | The grid tile |

### Backend

| File | What it does |
|---|---|
| `controller/UserController.java` | Profile read and update, search, profile views and viewers, bookmarks, subscription sync, account deletion |
| `service/UserService.java` | User lifecycle: signup, updates, search, bookmarks, profile views, subscription sync, and cascading deletion |
| `repository/UserRepository.java` | User lookups plus the athlete structured-search query |
| `repository/ProfileViewRepository.java` | Recent viewers within a 7-day window, and viewer counts |
| `repository/BookmarkRepository.java` | Bookmark rows with uniqueness checks and cascade deletes |
| `entity/User.java` | The user row: identity, role, tier, athlete vitals, recruiter fields, social handles, ranked target schools |
| `entity/ProfileView.java` | One record of who viewed whom and when |
| `entity/Bookmark.java` | A user-to-video save, unique per pair |
| `controller/FollowController.java` | Follow, unfollow, following IDs, and follower/following counts |
| `service/FollowService.java` | The social graph, with block checks |
| `repository/FollowRepository.java` | Follow edges, ID lists, and counts |
| `entity/Follow.java` | A directed follow edge |
| `dto/FollowRequest.java` · `dto/FollowCountsResponse.java` | Follow payload and the counts response including caller-relative `isFollowing` |
| `dto/BookmarkResponse.java` | Wrapper listing bookmarked video IDs |
| `enums/UserRole.java` | `ATHLETE`, `RECRUITER`, `BRAND` |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/users/{id}` | Public profile |
| PUT | `/api/users/{id}` | Update own profile (403 for anyone else) |
| GET | `/api/users?role=` | List users by role |
| GET | `/api/users/{id}/view-count` | Distinct viewers in the last 7 days |
| GET | `/api/users/{id}/viewers` | Who viewed this profile (Pro) |
| POST | `/api/users/{id}/views` | Record a profile view |
| GET | `/api/users/{id}/bookmarks` | Saved video IDs (owner only) |
| GET | `/api/users/{id}/bookmarks/videos` | Full saved clips (owner only) |
| POST | `/api/users/{id}/bookmarks` | Save a clip |
| DELETE | `/api/users/{id}/bookmarks/{videoId}` | Unsave a clip |
| GET | `/api/follows/following` | IDs the caller follows |
| POST | `/api/follows` · DELETE `/api/follows/{userId}` | Follow and unfollow (both idempotent) |
| GET | `/api/follows/{userId}/counts` | Follower and following counts |
