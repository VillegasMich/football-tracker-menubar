## Why

A scheduled match never flips to live on its own: the browse feed only auto-refreshes while it *already* contains a live match, so a day of upcoming fixtures stays frozen and can never discover that one kicked off. Users have to manually reload (or step the date) to see "scheduled" become "live", which defeats the point of a live scores menu bar app.

## What Changes

- **Break the chicken-and-egg browse-refresh gate (Layer 1)**: auto-refresh the browse feed on each tick when the browsed day is **today** OR already has a live match, instead of only when it already has a live match. This is what actually lets a scheduled match become live without a manual reload.
- **Catch kickoff quickly (Layer 2)**: extend the fast (LIVE) cadence to also apply when today has an **upcoming match whose kickoff time has been reached** but the feed still reports it as upcoming — the "should be live now" window — so a kickoff is picked up within one fast interval (~45s) rather than up to a full idle interval (~10 min).
- Refine the cadence spec so "browsing a non-live day stays on the slow interval" applies to days **other than today**; today with only upcoming matches now refreshes (fast when a kickoff is due, slow otherwise).

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `score-refresh`: The state-driven refresh cadence requirement changes so (a) the browse feed auto-refreshes while the browsed day is today (not only while it has a live match), and (b) a today upcoming match whose kickoff time has passed but still reads upcoming is a reason for the fast interval.

## Impact

- `Sources/FootballMenuBar/Store/MatchStore.swift`:
  - `tick()` — browse-refresh gate widens from `hasLiveMatch` to `isViewingToday || hasLiveMatch`.
  - `wantsLiveCadence` — add a "today has an upcoming match at/after kickoff" condition (new helper, e.g. `todayHasDueKickoff`).
- No API, model, or provider changes; no persistence changes. Behavior-only change to polling.
- Slightly more frequent fetches when viewing today (bounded by the existing idle interval when no kickoff is due, fast interval only around kickoffs), consistent with the app's existing live cadence.
