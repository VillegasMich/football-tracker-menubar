## 1. Settings model & persistence

- [x] 1.1 Add `RefreshCadence` enum (`.batterySaver`/`.balanced`/`.aggressive`) with a `(liveInterval, idleInterval)` nanosecond mapping; `.balanced` returns today's 45s / 10min. Persist by raw string.
- [x] 1.2 Create `AppSettings: ObservableObject` (`@MainActor`) backed by `UserDefaults` (injectable for tests), exposing published `cadence`, `showLiveIndicator`, `includeMatchMinute`, and `abbreviationOverrides: [String: String]`.
- [x] 1.3 Define defaults (cadence `.balanced`, indicator on, minute on) and make unknown/out-of-range persisted values fall back to defaults without crashing.
- [x] 1.4 Add `effectiveAbbreviation(for: Team) -> String` on `AppSettings` (override when present & non-blank, else `team.abbreviation`); trimming a blank override clears the entry.
- [x] 1.5 Add override mutators: `setAbbreviation(_:for:)` (empty/whitespace clears) and `clearAbbreviation(for:)`, persisting the dictionary.

## 2. Wire settings into the store (configurable cadence)

- [x] 2.1 Inject `AppSettings` into `MatchStore.init` (default provided so existing call sites/tests compile); own it from `AppDelegate` alongside `store`.
- [x] 2.2 Replace `static let liveInterval`/`idleInterval` reads in the poll loop with `settings.cadence` interval values, read each iteration so a change applies on the next tick.
- [x] 2.3 Verify the live-vs-idle mode logic (`wantsLiveCadence`, etc.) is otherwise unchanged.

## 3. Settings scene & open control

- [x] 3.1 Add a `Settings { SettingsView() }` scene to `FootballMenuBarApp` and inject `AppSettings` into its environment.
- [x] 3.2 Build `SettingsView`: a cadence preset picker and the two nested live-indicator toggles (match-minute disabled/nested when the indicator toggle is off), each bound to `AppSettings` and reflecting current values.
- [x] 3.3 Add a "Settings…" control to the popover footer that activates the app (`NSApp.activate`) and opens the settings window under the `.accessory` policy on the macOS 13 floor; confirm the app stays Dock-less afterward.

## 4. Menu bar live pill (spike + build)

- [x] 4.1 Spike: implemented render **tier 1** (red `Capsule` + white minute text) per design D3. Compiles; **visual confirmation at ~22pt still needs a human at the menu bar** — fall back to tier 2 (colored text) / tier 3 (🔴 emoji) if color doesn't render.
- [x] 4.2 Refactor `MenuBarTitle` to compose the textual core from the effective abbreviations (score/time), keeping it a pure function.
- [x] 4.3 Update `MenuBarLabel` to build an `HStack` of the text core plus, when the pinned match is in-progress and `showLiveIndicator` is on, the chosen live indicator; include `statusDetail` when `includeMatchMinute` is on, else a compact minute-less indicator.
- [x] 4.4 Ensure no indicator renders when the pinned match is upcoming/finished or the indicator toggle is off, and the ⚽ fallback is unaffected.

## 5. Abbreviation overrides in the UI

- [x] 5.1 Resolve `TeamLogoView.fallback` through `AppSettings.effectiveAbbreviation(for:)` (uppercased) instead of `team.abbreviation` directly.
- [x] 5.2 Confirm the menu bar title (task 4.2) also uses the effective abbreviation for both teams.
- [x] 5.3 Add a `.contextMenu` on the team line in `MatchRow`: "Set abbreviation…" (enter a new value) and "Reset to default" (shown only when an override exists), calling the `AppSettings` mutators.
- [x] 5.4 Verify an override change re-renders the affected abbreviation without relaunch (title and row fallback). — wired via `@Published`/`@EnvironmentObject`; runtime confirmation folded into 6.1.
- [x] 5.5 Add a "Pinned match abbreviations" section to `SettingsView` with an editable, live-applying abbreviation field (+ reset) per team of the pinned match; inject the store into the `Settings` scene. Shows a hint when nothing is pinned.

## 6. Team logos in the menu bar

- [x] 6.1a Add a `showTeamLogos` setting (default off) to `AppSettings` and a "Show team logos" toggle in `SettingsView`.
- [x] 6.1b Render the pinned match's crests in the menu bar title when enabled, falling back to the effective abbreviation per team.
- [x] 6.1c Fix `LogoCache` to coalesce concurrent requests for the same URL (await a shared task) instead of returning `nil` to the second caller — which left the menu bar crest blank while the popover held the same URL in flight.
- [x] 6.1d Composite the whole logo-mode title (both crests + score + pill) into a single `NSImage`: a `MenuBarExtra` label renders only one image reliably, so two separate crest views left the second blank. Pre-size crests via `NSImage` drawing (the label ignores SwiftUI `.frame` on images).

## 7. Verify

- [x] 7.1 `swift build` passes cleanly; app built via `build.sh`, run, and manually verified: Settings opens (via `SettingsLink`), cadence/toggles work, abbreviation overrides update the title and row fallback (context menu + Settings editor), and both team logos render in the menu bar with correct sizing.
- [x] 6.2 Update README to document the new Settings window and the three configurable behaviours.
- [x] 6.3 Keep pure logic (cadence mapping, `effectiveAbbreviation`, title composition) free of SwiftUI so it stays unit-testable once a test host is available (tests can't compile in this CommandLineTools-only env).
