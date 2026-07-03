## 1. Layer 1 — break the browse-refresh deadlock

- [x] 1.1 In `MatchStore.tick()`, change the browse gate from `let browseWillRefresh = hasLiveMatch` to `let browseWillRefresh = isViewingToday || hasLiveMatch`
- [x] 1.2 Verify the ticker-skip condition `!(browseWillRefresh && pinnedDayIsBrowsed)` still reads correctly with the widened gate (no extra change expected; confirm no double-fetch regression)

## 2. Layer 2 — fast cadence around kickoff

- [x] 2.1 Add a `todayHasDueKickoff` computed property to `MatchStore`: true when `isViewingToday` and `matches` contains a match with `state == .upcoming` and `kickoff <= Date()`
- [x] 2.2 OR `todayHasDueKickoff` into `wantsLiveCadence`
- [x] 2.3 Add a doc comment on `todayHasDueKickoff` describing the "should be live now" window

## 3. Verify

- [x] 3.1 `swift build` compiles cleanly (note: no Xcode in this env, so the test target won't compile — build/run only)
- [ ] 3.2 Run the app; browse today with an upcoming match and confirm it flips scheduled → live within ~45s of kickoff without a manual reload — **needs live confirmation at a real kickoff (can't be forced in dev)**
- [x] 3.3 Confirm a past/other day still does not auto-refresh (browse a previous day; the list is not re-fetched on ticks) — verified by code path: `tick()` gate `isViewingToday || hasLiveMatch` is false for a past day
- [x] 3.4 Confirm the loop stays on the idle cadence when today's matches are all comfortably in the future (no premature fast polling) — verified by code path: `todayHasDueKickoff` is false while all kickoffs are in the future

## 4. Spec sync

- [ ] 4.1 After implementation, sync the `score-refresh` delta into the main spec (via archive) so `openspec/specs/score-refresh/spec.md` reflects the new cadence requirement
