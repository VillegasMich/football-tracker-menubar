## Context

`MatchStore` already maintains a "ticker feed" — `pinnedSnapshot: Match?` — that is refreshed on every poll tick independently of the browsed day, and continues while the popover is closed (the store lives for the app's lifetime). This snapshot is the sole representation of the pinned match, so it is the natural and only place to detect kickoff and goal events for that match.

`pinnedSnapshot` is currently written in three places:
- `pin(_:)` — seeds it from the row the user clicked.
- `restorePinnedSnapshot()` / `refreshTicker()` — the ticker fetch (used at launch and on every tick).
- `updateSnapshotFromBrowse(_:)` — when the browsed day is the pinned day, the browse fetch is authoritative.

Only the poll-driven updates should be able to fire a notification; seeding (pin, launch restore) must not. Settings follow an established pattern in `AppSettings`: `UserDefaults`-backed `@Published` properties that default to on via `object(forKey:)` distinguishing "absent" from a stored `false`.

Constraints: macOS 13 deployment floor (`ObservableObject`, not `@Observable`); CommandLineTools-only environment (no Xcode → automated tests cannot run, per `[[no-xcode-tests-cant-run]]`); the app is packaged by `build.sh` as an ad-hoc, linker-signed bundle whose Info.plist is currently not bound into the signature.

## Goals / Non-Goals

**Goals:**
- Notify on pinned-match kickoff and goals via `UNUserNotificationCenter`.
- Never fire phantom notifications on launch, pin, or re-pin.
- Gate all posting behind settings that default on.
- Make notification delivery actually work from the `build.sh`-produced bundle.

**Non-Goals:**
- Full-time / match-end notifications.
- Notifications for non-pinned matches.
- Any click/tap action on a notification (informational only).
- Rich notifications (images, actions, sound customization) — plain title/body.
- Reconstructing intermediate scores when several goals land in one poll interval.

## Decisions

### Detect events by diffing consecutive snapshots against a retained baseline

Introduce a dedicated notifier (e.g. `MatchNotifier`) that owns a `baseline: Match?` and exposes something like `evaluate(_ newSnapshot: Match?)`. The store calls it whenever a **poll-driven** snapshot update occurs. The notifier's rule set:

```
new snapshot arrives (poll)
   ├─ new == nil            → clear baseline, no notify
   ├─ baseline == nil       → set baseline, no notify   (first sight)
   ├─ baseline.id != new.id → set baseline, no notify   (pin changed)
   └─ same match id:
        ├─ baseline.state == upcoming && new.state == inProgress  → KICKOFF
        ├─ new.home > baseline.home                                → GOAL (home)
        ├─ new.away > baseline.away                                → GOAL (away)
        ├─ score decreased                                          → no notify
        └─ (always) baseline = new
```

Goal check uses score increase only; a decrease (VAR/correction) silently re-baselines. Both-sides-increased or multi-goal jumps post one notification for the new current score. This single rule set covers launch, re-pin, and transient-failure (unchanged snapshot ⇒ no diff) without special cases.

*Alternative considered:* diff inline inside `MatchStore`. Rejected — it entangles notification policy with the store and makes the seed-vs-poll distinction easy to get wrong across three write sites.

### Funnel snapshot writes through one choke point with a source flag

Route all `pinnedSnapshot` assignments through a single private method, e.g. `setPinnedSnapshot(_ new: Match?, source: SnapshotSource)` where `source ∈ { seed, poll }`. `pin(_:)` and `restorePinnedSnapshot()` use `.seed` (which updates the baseline without notifying); `refreshTicker()` (during ticks) and `updateSnapshotFromBrowse(_:)` use `.poll`. Because the notifier already treats a first/absent baseline as seed-only, the source flag is mainly an explicit guard that the initial restore never notifies even though it shares `refreshTicker()` with poll ticks.

*Alternative considered:* rely purely on `baseline == nil` to suppress the launch notification. Works for the very first fetch, but the explicit source flag is clearer and robust if restore logic changes.

### Post via `UNUserNotificationCenter`, request authorization on first enable

Request authorization lazily the first time the master toggle transitions on (and on launch if already enabled). Denied authorization simply means posting is skipped. Notifications carry no `categoryIdentifier` with actions and no click handler, satisfying "clicking does nothing".

*Alternative considered:* deprecated `NSUserNotification` (more lenient about bundling). Rejected per the user's decision to use the modern API; the bundling issue is instead fixed directly (below).

### Fix bundle signing so `UNUserNotificationCenter.current()` resolves

`UNUserNotificationCenter.current()` requires the running process to resolve to a bundle with a valid identifier; the current ad-hoc, linker-signed bundle reports `Info.plist=not bound` and a signing identifier that differs from `CFBundleIdentifier`, which triggers a `bundleProxyForCurrentProcess is nil` crash. `build.sh` will re-sign the assembled `.app` explicitly:

```
codesign --force --sign - --identifier com.local.footballmenubar FootballMenuBar.app
```

so the bundle identifier is bound into the signature. Delivery must then be verified manually by running the bundle (not `swift run`).

### Three settings toggles mirroring the existing live-indicator pattern

Add `notificationsEnabled`, `notifyOnKickoff`, `notifyOnGoal` to `AppSettings`, each `UserDefaults`-backed and defaulting to on via `object(forKey:) as? Bool ?? true`, exactly like `showLiveIndicator`/`includeMatchMinute`. The settings UI gains a Notifications section with the two sub-toggles nested/disabled under the master, matching the existing subordinate-toggle presentation.

## Risks / Trade-offs

- **Notification delivery still fails from the bundle after re-signing** → verify manually early (deliver a test notification from the running bundle) before building UI polish; the packaging fix is a hard dependency, so it is sequenced first in tasks.
- **Authorization prompt appears for a Dock-less accessory app** → acceptable; the system presents it normally. If denied, posting is skipped silently.
- **Slow cadence misses intermediate goals** → by design we post the new current score once; the menu bar title already shows live score for detail.
- **Score "decrease then re-increase" (VAR overturn then re-award)** → each increase notifies; a corrected-away goal followed by a real one produces two notifications. Acceptable and rare.
- **Cannot run automated tests** (CommandLineTools-only) → rely on a manual verification checklist in tasks; keep the notifier logic pure/simple so it can be reasoned about and, if Xcode becomes available, unit-tested against synthetic snapshot pairs.
- **Two write sites both using `.poll`** could double-evaluate the same snapshot in one tick → the tick logic already avoids fetching both feeds for the pinned day, and re-evaluating an unchanged snapshot is a no-op (baseline already equals it), so duplicate posts are not possible.
