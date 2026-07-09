## Context

`MatchStore` is owned by `AppDelegate` and lives for the whole app lifetime (so polling continues with the popover closed). `selectedDate` is seeded to today once, at construction, and thereafter only the user's stepper/`goToToday()` change it. `MenuBarExtra` uses `.window` style; its content view (`MatchListView`) is not reconstructed per open, and there is currently no hook that fires when the popover is shown. Result: the last-browsed day survives a close/reopen.

The fix needs a reliable "the popover just opened" signal to invoke the existing return-to-today path.

## Goals / Non-Goals

**Goals:**
- Every popover open presents today's matches.
- Reuse the existing, already-idempotent `goToToday()` so an open that's already on today does no extra fetch.
- Leave the pinned ticker, polling cadence, and all other behavior untouched.

**Non-Goals:**
- No "remember my place for N minutes" grace period (user chose always-reset).
- No change to launch/restart behavior (already resets via store reconstruction).
- No change to how stepping or manual refresh work.

## Decisions

### D1 — Detect "open" via the popover window becoming key, not `.onAppear`

`.window`-style `MenuBarExtra` does not expose an open/closed binding. The two candidates are:

1. **`.onAppear` on `MatchListView`'s root VStack.**
2. **Observe `NSWindow.didBecomeKeyNotification` in `AppDelegate`** and reset when the popover window becomes key.

**Chosen: (2), after (1) failed in testing.** `.onAppear` was tried first (simplest, view-local) but the `.window`-style `MenuBarExtra` creates its SwiftUI content **once and reuses the window across opens**, so `.onAppear` fires only on first creation — reopening after browsing away kept the stale day. The reliable signal is the popover window becoming key: this accessory app has no other windows, so `didBecomeKeyNotification` corresponds to the popover opening and fires on every open. The observer lives in `AppDelegate` (which already owns the store) and calls `store.goToToday()`. The reset is still driven through the store, so a spurious/duplicate key notification is at worst a redundant idempotent call, never a wrong day. Trade-off: it reaches into AppKit, but that is unavoidable given MenuBarExtra exposes no presentation binding.

### D2 — Reset through `goToToday()`, add no new store logic

`goToToday()` already guards `isDate(selectedDate, inSameDayAs: today)` and returns without fetching when already on today; otherwise it sets `selectedDate` and reloads the browse feed. That is exactly the on-open semantics, so the view calls it directly:

```swift
.onAppear { Task { await store.goToToday() } }
```

Alternative considered: a dedicated `resetToTodayOnOpen()` entry point. Rejected as needless — it would duplicate `goToToday()`'s guard-and-load with no behavioral difference.

### D3 — Idempotence carries the correctness

Because `goToToday()` no-ops when already on today, calling it on every open (the common case: user is already on today) is free. Only after the user has browsed away does the call do real work: reset the label and refetch today. This also means we don't need to be precise about *how often* `.onAppear` fires.

## Risks / Trade-offs

- **`.onAppear` does not fire on reopen under `.window` MenuBarExtra** → This is what broke the first attempt; resolved by switching to `didBecomeKeyNotification` (D1). Extra key notifications are harmless idempotent calls (D3); a missed fire is the only real failure mode, verified manually against the running app (no Xcode here for automated UI tests).
- **A refetch on open adds a brief loading state after browsing away** → Acceptable and expected; it's the same load the user would trigger with the "Today" button, and today's data is what they want on open anyway.
- **Losing the browsed day on an accidental close** → Intentional per the user's "always reset" choice; browsing is transient by design.

## Open Questions

None.
