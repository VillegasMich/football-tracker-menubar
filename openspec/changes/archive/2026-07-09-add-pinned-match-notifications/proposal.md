## Why

The app tracks a single pinned match in the menu bar, but the user has to keep glancing at the title to notice anything happened. Surfacing the two moments that matter — the match kicking off and goals being scored — as native macOS notifications lets the user look away and still be told when their match starts and when the score changes.

## What Changes

- Post a native macOS notification (via `UNUserNotificationCenter`) when the **pinned** match kicks off — its state transitions `upcoming → inProgress`.
- Post a notification when the **pinned** match's score **increases** while live, naming the match, the team that scored, and the new current score.
- Notifications apply to the pinned match only. Non-pinned matches are never diffed and never notify.
- Add settings toggles gating this: a master "Enable notifications" toggle plus subordinate "Kickoff" and "Goals" toggles, all default-on, persisted like the existing settings.
- Request notification authorization from the user the first time notifications are enabled.
- Clicking a delivered notification does nothing (informational only).
- No full-time / match-end notification.
- Package fix: re-sign the app bundle in `build.sh` with an explicit `--identifier` so `UNUserNotificationCenter.current()` resolves the bundle at runtime instead of crashing.

## Capabilities

### New Capabilities
- `match-notifications`: When and what the app notifies for the pinned match (kickoff and goal events), how transitions are detected without firing phantom notifications on launch/pin/re-pin, score-decrease (VAR) handling, notification authorization, and the gating by settings.

### Modified Capabilities
- `app-settings`: Adds a new requirement for the notification toggles (master enable + subordinate kickoff/goals), their defaults, persistence, and subordinate UI relationship.

## Impact

- **New code**: a notification service that requests authorization and posts kickoff/goal notifications; a diff/baseline mechanism driven off the store's `pinnedSnapshot` updates.
- **Modified code**: `MatchStore` (funnel `pinnedSnapshot` writes through one choke point that distinguishes seed vs poll, and drive the notifier); `AppSettings` (three new persisted toggles); the settings UI (a Notifications section).
- **Build/packaging**: `build.sh` gains an explicit ad-hoc re-sign with `--identifier com.local.footballmenubar` so notification delivery works from the bundle; a manual delivery-verification step is required since the CommandLineTools-only environment cannot run tests.
- **New dependency**: the `UserNotifications` system framework.
- **Permissions**: the app will prompt for notification authorization on first enable.
