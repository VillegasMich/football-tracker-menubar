## 1. Reset browse date on open

- [x] 1.1 Reset the selected date to today on open via `store.goToToday()` (per design D1/D2). First tried `.onAppear` on `MatchListView` — it does not fire on reopen for `.window` MenuBarExtra, so replaced with an `NSWindow.didBecomeKeyNotification` observer in `AppDelegate`.
- [x] 1.2 Confirm `goToToday()` remains idempotent when already on today (guards on `isDate(selectedDate, inSameDayAs:)`, no refetch) so a normal open costs nothing (design D3). Adjust only if the guard is missing.

## 2. Verify

- [x] 2.1 Build with `swift build` and launch `.build/debug/FootballMenuBar`; confirm it runs as a menu-bar accessory without crashing. (Built clean; ran ~4s without crashing.)
- [~] 2.2 Manually verify: browse to a past/future day, close the popover, reopen — it shows today. Open again while already on today — no visible reload flash. With a match pinned, reopening after browsing away leaves the menu bar ticker unchanged. (No Xcode here, so this is manual — see project memory. Requires interactive popover clicking; left for the user to confirm.)
