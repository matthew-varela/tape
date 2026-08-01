# Search

## How it works

A people finder across athletes, coaches, and brands. Filtering happens
server-side on `/api/users/search`, so the app never downloads the full user
directory.

Typing is debounced by 300ms. The in-flight search is tracked as a `Task` and
cancelled whenever the query or filters change — cancellation makes
`Task.sleep` throw, so a superseded search bails before it ever reaches the
network.

Available filters: role, position, state, and sport. An empty query returns a
default list rather than nothing, so the screen is useful before anyone types.

When a search fails, the previous results stay on screen — they're still the
most useful thing available — but a banner says so, rather than leaving the
user to assume nothing matched.

> Not to be confused with the feed's **Search** stream, which filters *clips*
> by athlete attributes and is Pro-gated. See [feed.md](feed.md).

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Views/Search/SearchView.swift` | The whole screen: search bar, active-filter chips, debounced search, results list, and `SearchFilters`, `SearchResultRow`, and `SearchFilterSheet` |
| `Tape/Services/ProfileService.swift` | Declares `searchUsers(query:role:position:state:sport:)` — see [profiles.md](profiles.md) |
| `Tape/Services/API/APIProfileService.swift` | Builds the query string, omitting empty parameters |

### Backend

| File | What it does |
|---|---|
| `controller/UserController.java` | `GET /api/users/search` |
| `service/UserService.java` | Applies the filters and excludes blocked users in either direction |
| `repository/UserRepository.java` | The general search and athlete structured-search queries |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/users/search?q=&role=&position=&state=&sport=` | Server-side people search; every parameter is optional |
