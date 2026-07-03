## 1. Settings model & persistence

- [ ] 1.1 Add `RefreshCadence` enum (`.batterySaver`/`.balanced`/`.aggressive`) with a `(liveInterval, idleInterval)` nanosecond mapping; `.balanced` returns today's 45s / 10min. Persist by raw string.
- [ ] 1.2 Create `AppSettings: ObservableObject` (`@MainActor`) backed by `UserDefaults` (injectable for tests), exposing published `cadence`, `showLiveIndicator`, `includeMatchMinute`, and `abbreviationOverrides: [String: String]`.
- [ ] 1.3 Define defaults (cadence `.balanced`, indicator on, minute on) and make unknown/out-of-range persisted values fall back to defaults without crashing.
- [ ] 1.4 Add `effectiveAbbreviation(for: Team) -> String` on `AppSettings` (override when present & non-blank, else `team.abbreviation`); trimming a blank override clears the entry.
- [ ] 1.5 Add override mutators: `setAbbreviation(_:for:)` (empty/whitespace clears) and `clearAbbreviation(for:)`, persisting the dictionary.

## 2. Wire settings into the store (configurable cadence)

- [ ] 2.1 Inject `AppSettings` into `MatchStore.init` (default provided so existing call sites/tests compile); own it from `AppDelegate` alongside `store`.
- [ ] 2.2 Replace `static let liveInterval`/`idleInterval` reads in the poll loop with `settings.cadence` interval values, read each iteration so a change applies on the next tick.
- [ ] 2.3 Verify the live-vs-idle mode logic (`wantsLiveCadence`, etc.) is otherwise unchanged.

## 3. Settings scene & open control

- [ ] 3.1 Add a `Settings { SettingsView() }` scene to `FootballMenuBarApp` and inject `AppSettings` into its environment.
- [ ] 3.2 Build `SettingsView`: a cadence preset picker and the two nested live-indicator toggles (match-minute disabled/nested when the indicator toggle is off), each bound to `AppSettings` and reflecting current values.
- [ ] 3.3 Add a "Settings…" control to the popover footer that activates the app (`NSApp.activate`) and opens the settings window under the `.accessory` policy on the macOS 13 floor; confirm the app stays Dock-less afterward.

## 4. Menu bar live pill (spike + build)

- [ ] 4.1 Spike: render a red `Capsule` + white minute text in the `MenuBarExtra` label and confirm it shows in color at ~22pt; pick render tier (1 capsule → 2 colored text → 3 emoji) per design D3.
- [ ] 4.2 Refactor `MenuBarTitle` to compose the textual core from the effective abbreviations (score/time), keeping it a pure function.
- [ ] 4.3 Update `MenuBarLabel` to build an `HStack` of the text core plus, when the pinned match is in-progress and `showLiveIndicator` is on, the chosen live indicator; include `statusDetail` when `includeMatchMinute` is on, else a compact minute-less indicator.
- [ ] 4.4 Ensure no indicator renders when the pinned match is upcoming/finished or the indicator toggle is off, and the ⚽ fallback is unaffected.

## 5. Abbreviation overrides in the UI

- [ ] 5.1 Resolve `TeamLogoView.fallback` through `AppSettings.effectiveAbbreviation(for:)` (uppercased) instead of `team.abbreviation` directly.
- [ ] 5.2 Confirm the menu bar title (task 4.2) also uses the effective abbreviation for both teams.
- [ ] 5.3 Add a `.contextMenu` on the team line in `MatchRow`: "Set abbreviation…" (enter a new value) and "Reset to default" (shown only when an override exists), calling the `AppSettings` mutators.
- [ ] 5.4 Verify an override change re-renders the affected abbreviation without relaunch (title and row fallback).

## 6. Verify

- [ ] 6.1 `swift build` cleanly; `swift run` and manually verify: cadence preset change takes effect, settings persist across relaunch, live pill appears/toggles for a pinned live match, and setting/resetting a team abbreviation updates the title and row fallback.
- [ ] 6.2 Update README "Next steps"/docs to mention the new Settings window and the three configurable behaviours.
- [ ] 6.3 Keep pure logic (cadence mapping, `effectiveAbbreviation`, title composition) free of SwiftUI so it stays unit-testable once a test host is available (tests can't compile in this CommandLineTools-only env).
