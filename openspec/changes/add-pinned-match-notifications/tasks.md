## 1. Packaging: make notification delivery possible

- [ ] 1.1 Add `UserNotifications` framework usage (import) to the code that will post notifications
- [ ] 1.2 Update `build.sh` to re-sign the assembled bundle: `codesign --force --sign - --identifier com.local.footballmenubar FootballMenuBar.app`
- [ ] 1.3 Manually verify delivery: build the bundle, run it (not `swift run`), post a test notification, confirm it appears in Notification Center and `UNUserNotificationCenter.current()` does not crash

## 2. Settings model and UI

- [ ] 2.1 Add `notificationsEnabled`, `notifyOnKickoff`, `notifyOnGoal` to `AppSettings` as `UserDefaults`-backed `@Published` toggles, each defaulting to on via `object(forKey:) as? Bool ?? true` (mirror `showLiveIndicator`)
- [ ] 2.2 Add distinct `UserDefaults` keys for the three settings under the existing `Key` enum
- [ ] 2.3 Add a "Notifications" section to `SettingsView` with the master toggle and the two sub-toggles nested/disabled under it (mirror the live-indicator subordinate pattern)

## 3. Notification authorization + posting service

- [ ] 3.1 Create a `MatchNotifier` (or similarly named) type that requests `UNUserNotificationCenter` authorization and posts notifications; skip posting when authorization is not granted
- [ ] 3.2 Request authorization when the master toggle is first enabled, and on launch if already enabled
- [ ] 3.3 Implement `postKickoff(for:)` — title/body naming the two teams of the match
- [ ] 3.4 Implement `postGoal(for:scoringSide:)` — body identifies the match, the scoring team, and the new current score
- [ ] 3.5 Ensure notifications carry no action category and no click handler (informational only)

## 4. Transition detection (baseline diff)

- [ ] 4.1 Add a `baseline: Match?` to the notifier and an `evaluate(_ new: Match?)` entry point
- [ ] 4.2 Implement the rule set: nil-new clears baseline; nil-baseline seeds; differing id re-seeds; all seed-only paths do not notify
- [ ] 4.3 Implement kickoff detection: baseline `upcoming` → new `inProgress` (respecting `notifyOnKickoff` and master toggle)
- [ ] 4.4 Implement goal detection: score increase on home or away while live (respecting `notifyOnGoal` and master toggle); at most one notification per evaluation
- [ ] 4.5 Implement score-decrease handling: no notification, silently update baseline
- [ ] 4.6 Always update the baseline after each evaluation, including while an event type is disabled, so re-enabling does not replay missed events

## 5. Wire the notifier into `MatchStore`

- [ ] 5.1 Inject the notifier into `MatchStore` (construct it in `AppDelegate` alongside settings/store)
- [ ] 5.2 Funnel all `pinnedSnapshot` writes through one private `setPinnedSnapshot(_:source:)` with a `SnapshotSource { seed, poll }` flag
- [ ] 5.3 `pin(_:)` and `restorePinnedSnapshot()` write with `.seed` (baseline updated, no notify); `refreshTicker()` ticks and `updateSnapshotFromBrowse(_:)` write with `.poll`
- [ ] 5.4 On `.poll` writes, call `notifier.evaluate(newSnapshot)`; on `.seed` writes, seed the baseline without notifying
- [ ] 5.5 On `unpin()`, clear the notifier baseline

## 6. Verification

- [ ] 6.1 Manual: pin an upcoming match near kickoff; confirm one kickoff notification at the upcoming→live flip and none on launch/pin
- [ ] 6.2 Manual: with a pinned live match, confirm a goal notification naming the correct team and new score when the score increases
- [ ] 6.3 Manual: confirm no phantom notifications on launch while a pinned match is already live, and no notification when re-pinning to a different match
- [ ] 6.4 Manual: toggle master off → no notifications; toggle goals off while kickoff on → only kickoff fires
- [ ] 6.5 Manual: confirm clicking a delivered notification does nothing
- [ ] 6.6 Confirm `swift build -c release` succeeds and the re-signed bundle runs
