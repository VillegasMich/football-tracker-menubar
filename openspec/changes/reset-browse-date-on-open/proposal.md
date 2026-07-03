## Why

The selected browsing date persists in the long-lived store, so after the user steps to another day and closes the popover, reopening it still shows that stale day instead of today. Browsing is meant to be transient: opening the menu should reliably present the current day's matches without the user first having to press "Today."

## What Changes

- Reopening the popover SHALL reset the selected date to the current local day and refresh the browse feed, so every open starts on today.
- The reset reuses the existing return-to-today path, which already no-ops (no refetch) when the selected day is already today — so a normal open (already on today) costs nothing.
- The pinned match and its menu bar ticker are unaffected; only the browse feed's selected day resets.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `date-navigation`: The "Selected browsing date" requirement gains a reset-on-open behavior — the selected date returns to today each time the popover is opened, in addition to the existing launch default and no-persist-across-restart behavior.

## Impact

- `Sources/FootballMenuBar/Views/MatchListView.swift`: add an on-open hook that calls the store's return-to-today path.
- `Sources/FootballMenuBar/Store/MatchStore.swift`: no new logic expected — reuses `goToToday()` (idempotent when already on today). A dedicated entry point may be added for clarity if the view can't cleanly detect "open."
- No API, dependency, or data-model changes. Menu bar title / pinning behavior unchanged.
