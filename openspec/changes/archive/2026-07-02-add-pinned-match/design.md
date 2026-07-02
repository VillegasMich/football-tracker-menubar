## Context

The app is a SwiftUI `MenuBarExtra` (macOS 13+, SPM executable, no Xcode). `MatchStore` (`ObservableObject`, `@MainActor`) owns match data and a state-driven polling loop; it is created in `AppDelegate` and injected into the popover content (`MatchListView`) via `.environmentObject`. The `MenuBarExtra` label is currently a static `systemImage: "soccerball"` declared in the `App` scene body, which does **not** observe the store. `Team` already carries `id`/`name`/`abbreviation`; ESPN's scoreboard team payload additionally exposes a `logo` PNG URL (confirmed: `https://a.espncdn.com/i/teamlogos/soccer/500/{id}.png`), which the current DTO ignores.

This change makes the menu bar title a live ticker for a single user-pinned match and adds team logos to the popover rows.

## Goals / Non-Goals

**Goals:**
- Pin exactly one match; persist it across restarts.
- Drive the `MenuBarExtra` label from the pinned match, updating on refresh.
- Show team logos in popover rows with an uppercase-abbreviation fallback.
- Reuse the existing polling loop; only extend the cadence decision.

**Non-Goals:**
- Logos or images in the menu bar title (text only, for legibility at ~18px).
- Multiple simultaneous pins or rotating the title between matches.
- Team colors, flags beyond ESPN's `logo`, or a settings/league-picker UI.
- Disk/persistent image caching (in-memory only).

## Decisions

### Pin state lives in `MatchStore`, keyed by match id, persisted to `UserDefaults`

Add `@Published private(set) var pinnedMatchID: String?` plus `pin(_:)` / `unpin()` / `togglePin(_:)` and a derived `var pinnedMatch: Match?` (looks up `pinnedMatchID` in `matches`; nil if absent). Persist the id under a single `UserDefaults` key, read on init, written on change.

- **Why id, not the `Match`:** matches are re-fetched every cycle; storing the id and resolving against the live feed keeps the pinned match's score current and naturally yields the ⚧-fallback when it rolls out of the feed.
- **Why in the store:** the store is already the single `@MainActor` source of truth injected into views, and the cadence logic (which now depends on the pin) lives there too.
- **Alternative considered:** a separate `PinStore`. Rejected — it would need to observe `matches` to resolve the pinned match and duplicate persistence wiring for one value.

### Make the label observe the store so it re-renders

This is the load-bearing change. The label must react to `store.objectWillChange`. Keep the store **owned by the `AppDelegate`** (so it exists at `applicationDidFinishLaunching` and polling starts at launch), and render the label in a small `@ObservedObject` subview (`MenuBarLabel(store: appDelegate.store)`) that reads `store.pinnedMatch`. Inject the same instance into `MatchListView` via `.environmentObject`.

- **Why:** `@NSApplicationDelegateAdaptor` does not make the delegate's `@Published` changes re-evaluate the scene body; a static label would stay stale. An `@ObservedObject` subview does re-render.
- **Why delegate ownership over `@StateObject` in the App (revised during apply):** the original plan owned the store as `@StateObject` in the `App` and handed it to the delegate. That creates an ordering hazard — `applicationDidFinishLaunching` (which calls `start()`) can fire before the scene hands the instance over, and `.onAppear` isn't valid on a `Scene`. Delegate ownership keeps the store alive at launch for `start()`/`stop()` while the `@ObservedObject` subview still gets live updates. Same spec behavior, no ordering fragility.

### Label content is a pure function of the pinned match

A small helper (e.g. `MenuBarTitle.text(for: Match?) -> String?`) maps the pinned match to a title string, returning nil when the fallback ⚽ should show. Formats:

```
live      →  "ARS 1 – 0 CHE"
upcoming  →  "ARS 19:00 CHE"     (kickoff in the user's locale/timezone, short time)
finished  →  "ARS 2 – 1 CHE"
nil/absent → (nil → label renders Image(systemName: "soccerball"))
```

The scene picks `Text(title)` when non-nil, else `Image(systemName: "soccerball")`. Keeping this a pure, testable function isolates formatting from SwiftUI.

### Team logo: optional URL on the model, in-memory cache + fallback view

- `Team` gains `let logoURL: URL?`. `ESPNProvider`'s `TeamDTO` decodes `logo` (String) and maps to `URL(string:)`.
- A `TeamLogoView` renders the logo at row size; a tiny `@MainActor` `ImageCache` (`[URL: NSImage]`, actor or `@MainActor` class) loads-once and reuses. On nil URL or load failure it renders `Text(team.abbreviation.uppercased())`.
- **Why a manual cache over `AsyncImage`:** `AsyncImage` re-issues the request each time the popover (and view) is recreated; the menu bar popover is torn down on close, so logos would re-fetch on every open. A small keyed cache avoids that.
- **Alternative considered:** `AsyncImage` for v1 simplicity — acceptable but wasteful given the open/close churn; the cache is a few lines.

### Cadence: pinned upcoming-today also triggers LIVE mode

Extend the mode decision from `hasLiveMatch` to `hasLiveMatch || pinnedUpcomingKicksOffToday`, where the latter checks the pinned match is `.upcoming` and its `kickoff` is within today. Keeps the single-loop design; only the interval selection changes.

## Risks / Trade-offs

- **Unofficial ESPN `logo` field may change or 404** → logo rendering already degrades to the abbreviation fallback, so a missing/broken URL is non-fatal; all ESPN shape stays contained in `ESPNProvider`.
- **Scene re-ownership could regress the refresh lifecycle** → keep `start()`/`stop()` driven by the delegate's `applicationDidFinishLaunching`/`applicationWillTerminate`, just operating on the scene-owned instance; verify polling still runs with the popover closed.
- **Label width in the menu bar** → abbreviations + score are short (`"ARS 1 – 0 CHE"`); acceptable. If ESPN ever returns an empty abbreviation the title could look bare, but that is an existing data-quality edge, not introduced here.
- **In-memory cache grows unbounded** → bounded in practice by the small number of teams in the relevant-match window; no eviction needed for v1.
- **Title timezone for upcoming** → format kickoff in the user's locale/timezone via a shared formatter to avoid UTC confusion.

## Open Questions

- Score separator in the title: `"1 – 0"` (en dash) vs `"1-0"`. Leaning en dash for readability; not load-bearing.
- Whether to also show a live indicator (e.g. trailing `●`) in the title. Deferred — text-only is the committed scope; can be added later without spec change.
