## Context

`MatchStore` today holds a single `matches: [Match]` array fetched from ESPN's default scoreboard (no date param), and derives everything from it: `visibleMatches` filters to "today," `pinnedMatch` resolves the pin out of that same array, and `wantsLiveCadence` reads liveness from it. The menu bar title is a live ticker for the pinned match; the popover lists today's matches grouped by league.

Two facts drive this design:

1. **ESPN supports explicit dates.** `?dates=YYYYMMDD` returns a single UTC day (including past finished games); `?dates=YYYYMMDD-YYYYMMDD` returns a range. The default (no param) returns ESPN's "current matchday," which is often the *next* fixture rather than today — the current app's implicit "today" is therefore fuzzy.
2. **The pin must not follow the browse.** If browsing to another day replaces `store.matches`, the pin can no longer be resolved from it and the live ticker collapses to ⚽ — a regression against `match-pinning`. So the browse view and the pin/title must draw from separate data.

The decisions below were settled during exploration: **fetch-per-date** (not a cached window), and a **pin/title decoupled from the browsed date**.

## Goals / Non-Goals

**Goals:**
- Step backward/forward one calendar day at a time in the popover, unbounded in both directions.
- Make "today" deterministic by always querying an explicit date.
- Keep the pinned-match menu bar ticker live and correct regardless of which day is being browsed.
- Keep auto-refresh proportionate: fast only when something relevant is actually live.

**Non-Goals:**
- A date picker / calendar UI (stepper only for v1).
- Caching or prefetching adjacent days (accepted: each step is a fresh fetch).
- Multi-day ranges in the popover (one day at a time).
- Correct handling of late-night local kickoffs that spill into the next UTC day (known edge, deferred — see Risks).
- User-selectable leagues (unchanged, still `League.supported`).

## Decisions

### D1: Two feeds in the store — browse feed and ticker feed

The store gains a second logical data path:

```
selectedDate ───► BROWSE FEED   provider.matches(on: selectedDate)      ─► matches        ─► popover list
pinnedMatchID ──► TICKER FEED   provider.matches(on: pinnedDay)         ─► pinnedSnapshot ─► menu bar title
```

- **`matches: [Match]`** — the browse feed, for `selectedDate`. Refetched on every date step and on manual refresh. Powers `visibleMatches` / `matchesByLeague`.
- **`pinnedSnapshot: Match?`** — last-known data for the pinned match, refreshed on the live/idle cadence keyed to the pinned match's own day. Powers the title. `nil` ⇒ ⚽.
- **Collapse optimization:** when `selectedDate == pinnedDay`, one fetch serves both — the browse refresh updates `pinnedSnapshot` opportunistically whenever the pinned id appears in the fetched matches, and the separate ticker fetch is skipped for that tick.

*Why:* the pin's whole value is a live ticker independent of what the user is looking at. A single shared array cannot be both "the day I'm browsing" and "the pinned match's day" once those differ.

*Alternative considered — single array, freeze title when browsing away:* keep one `matches` array; when browsing off the pinned day, show the pinned match's last-known score frozen. Rejected: a live pinned match would stop updating in the menu bar the moment you peek at another day — the common "pin my team, glance at tomorrow's fixtures" flow breaks.

*Alternative considered — cached window (±N days), filter locally:* rejected in exploration; the user wants unbounded past/future, which a bounded window can't serve without on-demand fetching anyway.

### D2: `selectedDate` is store state; the provider takes a date

`MatchDataProvider.matches(for:)` becomes `matches(for:on:)` taking the day to fetch. `ESPNProvider` maps the date to `?dates=YYYYMMDD` (UTC, `en_US_POSIX`). `selectedDate` lives on the store (defaults to `startOfDay(today)`), with `stepDay(by:)`, `goToToday()` mutators that set it and trigger a browse refresh.

*Why on the store, not the view:* refresh cadence and the collapse optimization both need to know the browsed day; keeping it in the view would fragment that logic.

### D3: Cadence keyed to actual liveness of each feed

`wantsLiveCadence` is redefined as: **the pinned match is live or kicks off today (ticker feed), OR the browsed day currently has a live match (browse feed).** The polling loop each tick refreshes the ticker feed (when a pin exists) and refreshes the browse feed only when the browsed day has live matches. Browsing a finished past day or a future fixture list does no polling.

*Why:* preserves the existing "fast only while it matters" intent, now that "what matters" splits across two feeds. Prevents a browsed past day from either freezing the ticker or triggering pointless fast polling.

### D4: Persist the pinned match's day, restore the ticker on launch

Persistence extends from `pinnedMatchID` to also store the pinned match's kickoff day (`pinnedMatchDay`, `yyyy-MM-dd`). On launch, if a pin is persisted, fetch that day once to repopulate `pinnedSnapshot` so the ticker is correct before/without the user opening the popover.

*Why:* with the pin decoupled from the browse feed, launching straight onto "today" would otherwise leave the ticker blank until the user happened to browse to the pinned match's day.

*Alternative considered — persist a full `Match` snapshot:* rejected; the snapshot goes stale immediately (scores change) and re-fetching the day is cheap and authoritative. Only the day is needed to know what to fetch.

### D5: Single UTC day for v1

`?dates=` uses `YYYYMMDD` in UTC. v1 queries the single UTC day equal to the selected *local* date. Accepted imprecision: a kickoff at, say, 23:00 local that is 00:xx next-day UTC can appear under the "wrong" arrow. The correct fix (request a 2-day UTC range and filter to the local day) is deferred behind a clearly isolated seam in `ESPNProvider` so it can be swapped without touching the store or views.

## Risks / Trade-offs

- **Every arrow press is a network round-trip** → show a per-step loading state (spinner or dimmed prior list); disable the stepper while in flight to avoid rapid-fire races. Keep the previous day's list visible until the new one arrives to avoid the popover flashing empty.
- **Rapid stepping races (out-of-order responses)** → tag each browse fetch with its target date (or a request token) and ignore results that don't match the current `selectedDate`.
- **UTC/local day mismatch (D5)** → documented edge; isolated in the provider for a later range-based fix.
- **Two feeds can double ESPN calls** when browsing away from the pinned day → bounded (one extra call per league per tick, only while a pin exists); the collapse optimization removes it whenever `selectedDate == pinnedDay`.
- **Off-season empty days** are now genuinely empty (deterministic date) rather than showing ESPN's next-matchday guess → this is intended; the empty state must read in terms of the browsed day ("No matches on Jul 2"), with the "Today" affordance as the way back.

## Migration Plan

Additive and internal; no user data migration. Existing persisted `pinnedMatchID` remains valid — on first launch after the change, `pinnedMatchDay` is absent, so the ticker restore falls back to fetching *today* for the pin (correct for a pin made on a current/live match; a stale cross-day pin simply resolves once its day is browsed or on next pin). No rollback concerns beyond reverting the code; the extra `UserDefaults` key is ignored by the old build.

## Open Questions

- Should the stepper expose a small "jump to today" control always, or only when off-today? (Leaning: show only when off-today, doubling as the current-day indicator.)
- Is there any desire to remember the last-browsed date across launches, or always reset to today on launch? (Leaning: always reset to today — browsing is transient.)
