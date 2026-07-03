## 1. Provider: fetch a specific day

- [x] 1.1 Change `MatchDataProvider.matches(for:)` to `matches(for:on:)` taking the day to fetch (a `Date`), updating the protocol in `Services/MatchDataProvider.swift`.
- [x] 1.2 In `ESPNProvider`, format the requested day as `dates=YYYYMMDD` (UTC, `en_US_POSIX`) and append it to the scoreboard URL query; isolate the day→query mapping in one method so a future 2-day-range fix (D5) can replace it without touching callers.
- [x] 1.3 Confirm past and future days decode (finished `post` matches for past days) and that per-league concurrency + error surfacing still hold.

## 2. Store: selected date + browse feed

- [x] 2.1 Add `selectedDate` (default `startOfDay(today)`) to `MatchStore`, not persisted.
- [x] 2.2 Add `stepDay(by:)` and `goToToday()` mutators that update `selectedDate` and trigger a browse refresh.
- [x] 2.3 Add `isViewingToday` derived flag for the header indicator / return-to-today affordance.
- [x] 2.4 Point `refresh()` at `provider.matches(for: leagues, on: selectedDate)` and store the result in `matches` (the browse feed).
- [x] 2.5 Replace `visibleMatches`' "today only" window with a filter for the selected day (keep the "always show live" allowance when `isViewingToday`).
- [x] 2.6 Guard against out-of-order step results: tag each browse fetch with its target date (or a request token) and discard results whose date is no longer `selectedDate`.
- [x] 2.7 Track a per-step loading flag distinct from the existing `isRefreshing` so the view can keep the prior list visible while a step is in flight.

## 3. Store: ticker feed + pin decoupling

- [x] 3.1 Add `pinnedSnapshot: Match?` as the source of truth for the menu bar title, replacing pin resolution out of `matches`.
- [x] 3.2 Persist the pinned match's day (`pinnedMatchDay`, `yyyy-MM-dd`) alongside `pinnedMatchID` when pinning; clear it on unpin.
- [x] 3.3 Add a ticker refresh that fetches the pinned match's day and updates `pinnedSnapshot`; set snapshot to `nil` (→ ⚽) when the pinned id is absent from its own day's fetch.
- [x] 3.4 On launch, if a pin is persisted, fetch its day once to repopulate `pinnedSnapshot`; treat a legacy pin with no stored day as "today" without crashing or clearing it.
- [x] 3.5 Update the browse refresh to opportunistically update `pinnedSnapshot` when the pinned id appears in the fetched day (collapse optimization when `selectedDate == pinnedDay`).

## 4. Store: cadence rework

- [x] 4.1 Redefine `wantsLiveCadence` as: pinned match live OR pinned upcoming-kicks-off-today OR browsed day has a live match.
- [x] 4.2 In the polling loop, refresh the ticker feed each tick (when a pin exists) and refresh the browse feed only while the browsed day is live; skip the separate ticker fetch when it collapses into the browse fetch.
- [x] 4.3 Verify mode is recomputed after each fetch from both feeds.

## 5. Menu bar title

- [x] 5.1 Point `MenuBarTitle` at `pinnedSnapshot` instead of the browse-resolved pin so the title is independent of `selectedDate`.
- [x] 5.2 Confirm the ⚽ fallback triggers only when no pin or the pinned match is absent from its own day's feed — not when merely browsing another day.

## 6. Popover UI: date stepper

- [x] 6.1 Replace the static "Football" header with a date stepper: ◀ / day label / ▶, wired to `stepDay(by:)`.
- [x] 6.2 Show the day label as "Today" (or a today indicator) when `isViewingToday`, and a tappable return-to-today control when not.
- [x] 6.3 Disable the stepper controls while a step fetch is in flight to prevent rapid-fire races; show a loading indicator during the step.
- [x] 6.4 Keep the prior day's list rendered until the new day's matches arrive (no empty flash).
- [x] 6.5 Update the empty state to name the selected day (e.g. "No matches on Jul 2") and offer a way back to today when off-today.

## 7. Tests & verification

> **Automated tests skipped (environment constraint).** This machine has
> CommandLineTools only — no full Xcode — so the toolchain ships neither
> `XCTest` nor the swift-testing `Testing` module, and a `.testTarget` cannot
> compile here. Tasks 7.1–7.3 are deferred to an Xcode/CI environment; the
> store was left test-friendly (injected `MatchDataProvider` + `UserDefaults`,
> awaitable `loadInitial()`) so they can be added later without refactoring.
> Verification for this change relies on 7.4.

- [~] 7.1 (deferred) Store test double + coverage of stepping, out-of-order guard, selected-day filtering, and cadence decisions.
- [~] 7.2 (deferred) Pin persistence + ticker restore, including legacy pin without a stored day.
- [~] 7.3 (deferred) Decoupling invariant: browsing away leaves `pinnedSnapshot`/title intact.
- [x] 7.4 Manually verify against ESPN: past day (finished scores), a future day (fixtures), and an empty day return sensible data via the `?dates=` path; app builds and launches as a menu bar accessory.
