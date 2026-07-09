## ADDED Requirements

### Requirement: Notification configuration

The settings SHALL expose a master "enable notifications" toggle and, dependent on it, two subordinate toggles: "kickoff notifications" and "goal notifications". All three SHALL default to on. The subordinate toggles SHALL have no effect while the master toggle is off, and the UI SHALL present them as subordinate to (nested under) the master toggle. The settings SHALL persist all three values in `UserDefaults` so choices survive relaunch, and an unknown or absent persisted value SHALL fall back to the default (on) rather than crashing. The values exposed by these settings SHALL gate notification posting per the `match-notifications` capability.

#### Scenario: Notification toggles default on
- **WHEN** the app launches with no persisted notification settings
- **THEN** the master, kickoff, and goal toggles are all on

#### Scenario: Subordinate toggles are subordinate to master
- **WHEN** the master "enable notifications" toggle is off
- **THEN** the kickoff and goal toggles have no effect on notification posting
- **AND** the UI presents them as disabled or nested under the master toggle

#### Scenario: Notification settings persist across relaunch
- **WHEN** the user changes a notification toggle and the app is relaunched
- **THEN** the changed value is restored from `UserDefaults` on launch

#### Scenario: Toggles gate notifications
- **WHEN** the user changes any notification toggle
- **THEN** notification posting for the pinned match reflects the new choice, per the `match-notifications` capability
