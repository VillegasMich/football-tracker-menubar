## Why

Today every user-facing behaviour is hardcoded: the refresh cadence lives as fixed constants in `MatchStore`, team abbreviations come straight from ESPN with no way to correct wrong or unwanted codes, and the menu bar title cannot show the live minute/indicator that the dropdown already displays for in-progress matches. Users have asked to tune the poll rate, fix team abbreviations, and surface the live status pill in the menu bar itself. There is currently no settings surface at all, so this change introduces one and wires the first three configurable behaviours through it.

## What Changes

- **Add a settings surface.** Introduce a persisted, `UserDefaults`-backed settings model and a native SwiftUI `Settings` scene (opened with ⌘,) as the home for global configuration, reachable from the accessory (Dock-less) menu bar app.
- **Configurable refresh cadence.** Replace the hardcoded live (~45s) and idle (~10min) intervals in `MatchStore` with user-selectable presets (e.g. Battery Saver / Balanced / Aggressive), each mapping to a bounded live/idle interval pair with sensible floors to protect the unofficial ESPN endpoint. The live-vs-idle *mode* logic is unchanged; only the durations become configurable.
- **Per-team abbreviation overrides.** Let the user correct a team's abbreviation (keyed by ESPN's stable team id), persisted across launches and edited contextually by right-clicking a team in the dropdown. The effective (overridden) abbreviation is used everywhere abbreviations are shown — the menu bar title and the `TeamLogoView` flag/logo fallback.
- **Configurable live status pill in the menu bar.** When the pinned match is in-progress, mirror the dropdown's red status pill into the menu bar title, gated by two nested settings: "show live indicator" and, under it, "include match minute (clock)". Scope is the pinned match only (the menu bar is inherently pinned-only); the dropdown's per-row pill behaviour is unchanged.
- **Optional team logos in the menu bar.** A "show team logos" setting swaps the pinned match's text abbreviations in the menu bar title for the team crests/flags (as shown in the dropdown rows), falling back to the abbreviation for a team whose logo is unavailable.

## Capabilities

### New Capabilities
- `app-settings`: A persisted settings model and the native `Settings` scene that hosts global configuration for an accessory menu bar app — including the refresh-cadence preset selection and the menu bar live-indicator toggles, with defaults and persistence.
- `team-abbreviation-overrides`: Per-team abbreviation overrides keyed by stable team id — their storage/persistence, contextual (right-click) editing to set and clear them, and application of the effective abbreviation wherever a team's abbreviation is displayed.

### Modified Capabilities
- `score-refresh`: The state-driven refresh cadence's fast/slow interval durations become the currently configured values (bounded by floors) rather than fixed constants; the mode-selection logic is unchanged.
- `match-pinning`: The pinned-match menu bar title MAY additionally render a live status pill (a red indicator, optionally including the match minute) while the pinned match is in-progress, per the user's settings; and the abbreviations it shows are the effective (overridden) ones.

## Impact

- **Code**: New settings model + `Settings` scene wiring in `FootballMenuBarApp.swift`; `MatchStore` reads configured intervals instead of `static let` constants; `MenuBarTitle`/`MenuBarLabel` gain the optional live pill and consult overrides; `TeamLogoView` fallback and the menu bar title resolve abbreviations through the override map; `MatchRow` gains a right-click context menu to edit a team's abbreviation.
- **Persistence**: New `UserDefaults` keys for the settings model and the abbreviation-override map, alongside the existing pin keys.
- **Platform/tooling**: `Settings` scene must work under the `.accessory` activation policy on the macOS 13 floor. No new dependencies. Tests cannot compile in the CommandLineTools-only environment (`swift build`/`run` still work).
- **Risk**: A colored red capsule may not render cleanly in the ~22pt `MenuBarExtra` bar; the design must define fallback tiers (colored text, emoji indicator) — see `design.md`.
