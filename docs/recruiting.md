# Recruiting

Two tools for recruiters and brands, deliberately kept separate.

**Saved Players** is a single flat shortlist — one tap from any athlete
profile, no decisions required. It's the recruiting equivalent of bookmarking a
video.

**Scouting Boards** are named lists you build on purpose: "2027 QBs", "Spring
Visits", "Texas Trip". An athlete can belong to several boards at once.

Athletes see neither. Both tabs only appear for the recruiter and brand roles.

---

## Saved Players

The saved list is the source of truth on the server, so it's fetched fresh
rather than reconstructed locally. Swiping a row opens **Add to Board**, which
is the intended path from a loose shortlist into an organized one. Saving is
idempotent: saving an athlete who's already saved is a no-op rather than an
error, so a double tap can't produce a duplicate or a failure.

## Scouting Boards

Boards are Pro-only. Free users can browse the tab but the create button opens
the paywall.

Boards store athlete IDs, not athlete records, so a board never serves a stale
name or grad year — profiles are fetched fresh and in parallel when the board
opens. Renaming is inline. Deleting a board removes the board and its
membership, never the athletes themselves.

Because boards are edited from several places — a board screen, an athlete
profile, a swipe on Saved Players — any membership change posts
`.tapeScoutingBoardsChanged`, and the board screen reloads when it hears it.
Without that, editing from a profile would leave an already-open board showing
the old roster.

Every board endpoint takes the owner from the auth token, not the request body.
A `ownerId` query parameter is still accepted on the list endpoint for older
clients, but it's ignored.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Views/Scouting/ScoutingBoardView.swift` | Board list and detail: create, rename, delete, remove an athlete, Pro gating, empty states, and the boards-changed listener |
| `Tape/Views/Scouting/AddToBoardSheet.swift` | The sheet for putting an athlete on boards, including creating one inline |
| `Tape/Views/Scouting/SavedPlayersView.swift` | The shortlist, with swipe-to-add-to-board and swipe-to-remove |
| `Tape/Views/Scouting/BookmarkedAthleteCard.swift` | The athlete row used in both |
| `Tape/ViewModels/ScoutingViewModel.swift` | Board CRUD and membership; resolves athlete IDs into profiles in parallel |
| `Tape/ViewModels/SavedPlayersViewModel.swift` | Loads, saves, and removes shortlisted athletes |
| `Tape/Services/ScoutingService.swift` | `ScoutingServiceProtocol`, `MockScoutingService`, `ScoutingServiceError` |
| `Tape/Services/API/APIScoutingService.swift` | REST implementation of the board endpoints |
| `Tape/Services/SavedAthleteService.swift` | `SavedAthleteServiceProtocol` and its mock |
| `Tape/Services/API/APISavedAthleteService.swift` | REST implementation of the shortlist |
| `Tape/Models/ScoutingBoard.swift` | The board model: name, owner, athlete IDs, created date |
| `Tape/Support/Notifications.swift` | Declares `.tapeScoutingBoardsChanged` |

### Backend

| File | What it does |
|---|---|
| `controller/ScoutingBoardController.java` | Board CRUD and membership routes |
| `service/ScoutingBoardService.java` | Ownership checks on every mutation, and membership add/remove |
| `repository/ScoutingBoardRepository.java` | Boards by owner |
| `entity/ScoutingBoard.java` | Board row with athlete IDs in an element-collection table |
| `controller/SavedAthleteController.java` | Shortlist routes |
| `service/SavedAthleteService.java` | Idempotent save, unsave, and listing newest-first |
| `repository/SavedAthleteRepository.java` | Shortlist rows by owner, with existence checks |
| `entity/SavedAthlete.java` | One recruiter-to-athlete save |
| `dto/SavedAthleteRequest.java` | `{ athleteId }` |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/scouting-boards` | The caller's boards |
| POST | `/api/scouting-boards` | Create a board — `{ name }` |
| PATCH | `/api/scouting-boards/{id}` | Rename — `{ name }` |
| DELETE | `/api/scouting-boards/{id}` | Delete the board and its membership |
| POST | `/api/scouting-boards/{id}/athletes` | Add an athlete — `{ athleteId }` |
| DELETE | `/api/scouting-boards/{id}/athletes/{athleteId}` | Remove an athlete |
| GET | `/api/saved-athletes` | The shortlist, newest first |
| POST | `/api/saved-athletes` | Save — `{ athleteId }`, idempotent |
| DELETE | `/api/saved-athletes/{athleteId}` | Unsave |

Every mutation returns 403 if the caller doesn't own the board.
