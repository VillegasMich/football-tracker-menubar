## Context

The auto-refresh loop lives in `MatchStore`. Two pieces govern it:

- `wantsLiveCadence` picks the sleep interval between ticks (fast `liveInterval` = 45s vs. slow `idleInterval` = 10 min).
- `tick()` decides, per tick, whether to refresh the ticker feed and/or the browse feed.

Today `tick()` gates the browse refresh on `hasLiveMatch` (the browse feed already containing an in-progress match):

```swift
let browseWillRefresh = hasLiveMatch
if browseWillRefresh { await refresh() }
```

Because `hasLiveMatch` reads the current `matches`, a day of purely upcoming fixtures never refreshes, so it can never observe a match going live — a chicken-and-egg deadlock. The only escape hatches are the manual refresh button and date steps, both of which call `loadBrowse` unconditionally. Separately, with no pinned match kicking off today the loop sits on the 10-min idle interval, so even after Layer 1 the flip could lag up to ~10 min.

## Goals / Non-Goals

**Goals:**
- A scheduled match on today's browsed day flips to live automatically, without a manual reload.
- The flip is observed within one fast interval (~45s) of kickoff, not up to a full idle interval.
- Keep the "don't churn on static days" behavior: past/other days still don't auto-refresh.

**Non-Goals:**
- No change to intervals, provider, models, or persistence.
- No always-on hard polling; fast cadence stays scoped to when something is (or should be) happening.
- No change to the pinned-ticker logic beyond what naturally follows.

## Decisions

### Layer 1 — widen the browse-refresh gate to `isViewingToday || hasLiveMatch`

`tick()` becomes:

```swift
let browseWillRefresh = isViewingToday || hasLiveMatch
```

`isViewingToday` already exists on the store. Today is the only day whose matches can transition (start, go live, finish) relative to what was last fetched, so it is the correct trigger. `hasLiveMatch` is retained so the rare case of browsing a *non-today* day that still has a live match (e.g. a late-running fixture viewed just after midnight) keeps refreshing. This alone breaks the deadlock.

*Alternative considered:* refresh the browse feed on every tick regardless of day. Rejected — it would re-fetch static past/future days for no benefit and contradicts the existing "browsing a non-live day doesn't auto-refresh" requirement.

### Layer 2 — add a "kickoff due today" reason to `wantsLiveCadence`

Introduce a computed helper on the store:

```swift
/// True when the browsed day is today and holds an upcoming match whose
/// kickoff time has already passed but which the feed still reports as
/// upcoming — the window where it should be flipping to live.
var todayHasDueKickoff: Bool {
    isViewingToday && matches.contains {
        $0.state == .upcoming && $0.kickoff <= Date()
    }
}
```

and OR it into the cadence:

```swift
var wantsLiveCadence: Bool {
    (pinnedSnapshot?.isLive ?? false)
        || pinnedUpcomingKicksOffToday
        || hasLiveMatch
        || todayHasDueKickoff
}
```

This keeps the loop idle while today's matches are still comfortably in the future, then switches to the 45s cadence exactly around kickoff, so the flip (driven by Layer 1's refresh) lands within one fast tick. Once ESPN reports the match as `in`, `hasLiveMatch` keeps the fast cadence going, so `todayHasDueKickoff` naturally hands off.

*Alternatives considered:*
- *(a) Always fast-poll today.* Simpler, but hammers the API/battery all day for a day that may not kick off for hours.
- *(c) Fix only Layer 1, leave idle interval.* Flip becomes automatic but can lag up to ~10 min — acceptable correctness, poor liveness for a live-scores app. Chosen (b) balances both.

## Risks / Trade-offs

- **[Slightly more fetches when viewing today]** → Bounded: idle cadence still applies until a kickoff is actually due; fast cadence only around kickoffs and live play, matching existing live behavior.
- **[Clock/timezone skew making `kickoff <= Date()` fire early/late]** → Low impact: worst case the fast cadence starts a tick early or the flip lags one tick; `kickoff` is an absolute `Date`, compared against `Date()`, so no timezone math is involved.
- **[A perpetually-upcoming match whose kickoff has passed (data glitch / postponed fixture reported as pre)]** → Would hold the fast cadence while today is browsed. Acceptable and self-limited to today; the popover typically isn't open continuously, and closing/relaunching is unaffected.

## Migration Plan

Behavior-only change to `MatchStore`; no data, API, or persistence migration. Ships by replacing the store logic. Rollback is reverting the two edits (the `tick()` gate and the `wantsLiveCadence`/helper addition).
