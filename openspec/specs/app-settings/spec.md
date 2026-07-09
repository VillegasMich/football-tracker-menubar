# app-settings Specification

## Purpose

Defines the app's global configuration: a persisted, observable settings model and the native `Settings` scene that hosts it — the refresh-cadence preset, the menu bar live-indicator and team-logo options, and the notification toggles — with defaults and persistence for an accessory (Dock-less) menu bar app.

## Requirements

### Requirement: Persisted settings model

The system SHALL provide an observable settings model that holds the user's global configuration and persists it in `UserDefaults` so choices survive relaunch. The model SHALL expose the configured refresh-cadence preset and the menu bar live-indicator options. Each setting SHALL have a defined default used when nothing is persisted, and unknown or out-of-range persisted values SHALL fall back to that default rather than crashing.

#### Scenario: Settings persist across relaunch
- **WHEN** the user changes a setting and the app is relaunched
- **THEN** the changed value is restored from `UserDefaults` on launch

#### Scenario: Defaults on first launch
- **WHEN** the app launches with no persisted settings
- **THEN** each setting takes its defined default value

#### Scenario: Corrupt or unknown persisted value
- **WHEN** a persisted setting holds a value that is unknown or out of range
- **THEN** the model falls back to that setting's default without crashing

### Requirement: Settings window for the accessory app

The system SHALL provide a native SwiftUI `Settings` scene as the home for global configuration, and SHALL make it openable even though the app runs under the `.accessory` activation policy with no Dock icon. The settings window SHALL group the refresh-cadence control and the menu bar live-indicator controls.

#### Scenario: Open settings from the menu bar app
- **WHEN** the user invokes the settings command (e.g. from a control in the popover or the standard ⌘, shortcut)
- **THEN** the settings window opens and comes to the foreground
- **AND** the app remains a menu bar accessory app with no Dock icon afterward

#### Scenario: Settings controls reflect current values
- **WHEN** the settings window is open
- **THEN** each control shows the currently persisted value
- **AND** changing a control updates the persisted setting immediately

### Requirement: Refresh cadence configuration

The settings SHALL let the user choose the refresh cadence from a small set of named presets, each mapping to a bounded pair of live and idle poll intervals. Every preset's live interval SHALL be no shorter than a defined live floor and its idle interval no shorter than a defined idle floor, so the unofficial data endpoint is not polled abusively. The default preset SHALL preserve the app's existing cadence.

#### Scenario: Preset selection maps to intervals
- **WHEN** the user selects a cadence preset
- **THEN** the settings expose that preset's live and idle intervals for the store to use

#### Scenario: Intervals respect the floors
- **WHEN** any preset is selected
- **THEN** its live interval is not shorter than the live floor
- **AND** its idle interval is not shorter than the idle floor

#### Scenario: Default preserves existing behavior
- **WHEN** no cadence preset has been chosen
- **THEN** the effective intervals equal the app's prior fixed live and idle intervals

### Requirement: Menu bar live-indicator configuration

The settings SHALL expose two related toggles governing the pinned-match menu bar title: a "show live indicator" toggle and, dependent on it, an "include match minute" toggle. The match-minute toggle SHALL have no effect while the live-indicator toggle is off, and the UI SHALL present it as subordinate to (nested under) the live-indicator toggle.

#### Scenario: Match-minute toggle is subordinate
- **WHEN** the "show live indicator" toggle is off
- **THEN** the "include match minute" toggle has no effect on the menu bar title
- **AND** the UI presents it as disabled or nested under the live-indicator toggle

#### Scenario: Toggles drive the menu bar title
- **WHEN** the user changes either toggle
- **THEN** the pinned-match menu bar title reflects the new choice on the next render, per the `match-pinning` capability

### Requirement: Team logos in the menu bar configuration

The settings SHALL expose a "show team logos" toggle that controls whether the pinned-match menu bar title displays team crests/logos in place of the text abbreviations. It SHALL default to off (text abbreviations), preserving the prior menu bar appearance.

#### Scenario: Logos toggle default
- **WHEN** no value has been persisted for the team-logos setting
- **THEN** it defaults to off and the menu bar title shows text abbreviations

#### Scenario: Logos toggle drives the menu bar title
- **WHEN** the user turns the team-logos setting on
- **THEN** the pinned-match menu bar title shows the teams' logos on the next render, per the `match-pinning` capability

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
