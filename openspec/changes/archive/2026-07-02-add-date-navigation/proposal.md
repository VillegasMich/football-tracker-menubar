## Why

The popover only ever shows a single, fuzzy slice of time. The app fetches ESPN's default scoreboard (no date param), which returns ESPN's "current matchday" — often the *next* fixture, not today — and then filters it to "today only." Users can't look back at yesterday's results or ahead to upcoming fixtures, and off-season the popover is effectively empty. ESPN's scoreboard endpoint accepts an explicit `?dates=YYYYMMDD` (single day) and `?dates=YYYYMMDD-YYYYMMDD` (range) parameter for past and future dates, so date browsing is fully feasible and, as a bonus, makes "today" deterministic instead of relying on ESPN's vague default.

## What Changes

- Add a **date stepper** to the popover header (◀ / current day / ▶) letting the user move one calendar day at a time, backward and forward, with no fixed bound. A "Today" affordance jumps back to the current day.
- Fetch **per date**: stepping to a new day issues a fresh ESPN request for that day's `?dates=` value. Each step shows a loading state (network round-trip).
- **Decouple the pinned match / menu bar title from the browsed date.** The title tracks the pinned match via its own snapshot feed, refreshed on the live/idle cadence keyed to the pinned match's own day — browsing to another date must not empty or freeze the ticker. **BREAKING** (internal): the title stops resolving the pin out of the browse feed.
- **Relevant-match window becomes "the selected day, defaulting to today"** instead of "today only." Finished matches from a browsed past day are now shown (when that day is selected), not excluded.
- **Cadence** now auto-refreshes the browse feed only when the *browsed* day has live matches, while the ticker feed keeps its own live/idle cadence for the pinned match independent of browsing.
- **Persist the pinned match's day** (alongside its id) so the ticker can be restored by re-fetching that day on launch.
- **Day boundary:** v1 queries the single UTC day matching the selected local date (simple); late-night local kickoffs that fall on the next UTC day are a known edge to revisit.

## Capabilities

### New Capabilities
- `date-navigation`: browsing matches by calendar day — the selected-date model, the header stepper and its controls (previous/next/today), unbounded past & future navigation, per-date fetching, and the per-step loading state.

### Modified Capabilities
- `match-data`: the `MatchDataProvider` abstraction and its ESPN implementation gain a **date** parameter, fetching a specific day's scoreboard via `?dates=YYYYMMDD` instead of the default "current" scoreboard.
- `menu-bar-display`: the "relevant-match window" requirement changes from "today only" to "the selected day (default today)"; the header gains the date stepper; the empty state reflects the browsed day rather than "today."
- `score-refresh`: the cadence is redefined around two feeds — a browse feed (auto-refreshed only while the browsed day is live) and a ticker feed for the pinned match (live/idle cadence, independent of the browsed date).
- `match-pinning`: the menu bar title reads a pinned-match **snapshot** decoupled from the browse feed, and persistence extends to the pinned match's **day** so the ticker restores after relaunch.

## Impact

- **Code:**
  - `Services/MatchDataProvider.swift`, `Services/ESPNProvider.swift` — add date parameter, build `?dates=` query.
  - `Store/MatchStore.swift` — add `selectedDate`, per-date `refresh`, `pinnedSnapshot` + its own refresh, cadence rework, extended pin persistence, `visibleMatches` keyed to selected day.
  - `Views/MatchListView.swift` — header date stepper + controls, per-step loading state, browsed-day empty-state copy.
  - `MenuBarTitle.swift` — title reads `pinnedSnapshot` rather than the browse-resolved pin.
- **External API:** additional ESPN scoreboard calls (one per league per browsed day); no new dependency, still key-less.
- **Persistence:** an extra `UserDefaults` value for the pinned match's day.
- **Docs:** `AGENTS.md` product goals already imply date browsing is out of scope today; no change required, though it remains stale on other points.
