## Context

The app is a SwiftUI `MenuBarExtra` accessory app (macOS 13 floor, Swift 6, no full Xcode — tests can't compile in the CommandLineTools-only environment; `swift build`/`run` work). There is no settings layer today: refresh cadence lives as `static let liveInterval`/`idleInterval` on `MatchStore`, team abbreviations come straight from ESPN via `Team.abbreviation`, and the menu bar title (`MenuBarTitle.text` → `MenuBarLabel`) shows only text with no live indicator. The only persisted state is the pin (two `UserDefaults` keys owned by `MatchStore`). This change adds the first configuration surface and routes three behaviours through it.

Key existing seams this design leans on:
- `MatchStore.start()` already recomputes `wantsLiveCadence ? liveInterval : idleInterval` **every loop iteration**, so making the durations instance values read from settings makes cadence changes take effect on the next tick with no extra plumbing.
- `MenuBarTitle` is a pure, testable formatter isolated from SwiftUI — the natural place to compose the title, but it returns a `String`, which constrains how a colored pill can be rendered (see Decisions).
- `TeamLogoView.fallback` and `MenuBarTitle` are the only two readers of `Team.abbreviation`.

## Goals / Non-Goals

**Goals:**
- A single persisted, observable settings model (`UserDefaults`-backed) that both the store and the views can read.
- A native `Settings` scene reachable from the accessory app for global config (cadence preset + live-indicator toggles).
- Per-team abbreviation overrides keyed by stable ESPN team id, edited contextually via right-click, applied everywhere abbreviations render.
- A configurable live status indicator in the pinned-match menu bar title that mirrors the dropdown's red pill, scoped to the pinned match.

**Non-Goals:**
- No league picker, no theming, no per-match notification settings — only the three behaviours in the proposal.
- No free-form seconds field for cadence in v1 (presets only).
- No settings sync/iCloud; `UserDefaults.standard` only.
- No change to the dropdown's per-row pill behaviour, nor to the live-vs-idle *mode* logic.
- No change to how abbreviations are sourced from ESPN (overrides are a display-time transform).

## Decisions

### D1 — Settings live in a dedicated observable `AppSettings`, not in `MatchStore`

Introduce `AppSettings: ObservableObject` (owned by `AppDelegate` alongside `store`, injected into the environment) rather than piling more `UserDefaults` access into `MatchStore`. Rationale: the settings are read by multiple consumers (store for cadence, label/title for the pill, views for overrides), and keeping them in one observable keeps `MatchStore` focused on match data. `ObservableObject` (not `@Observable`) to hold the macOS 13 floor, consistent with `MatchStore`.

The store needs cadence values; give it a reference to `AppSettings` (constructor injection, defaulting for tests) and have it read `settings.liveInterval`/`idleInterval` inside the poll loop. Because the loop already re-reads each iteration, no observation wiring is needed for cadence.

**Alternative considered:** store cadence directly on `MatchStore`. Rejected — spreads persistence across two owners and couples the store to `UserDefaults` shape.

### D2 — Cadence as named presets mapping to bounded interval pairs

Model cadence as an enum (`RefreshCadence`: e.g. `.batterySaver`, `.balanced`, `.aggressive`) persisted by raw string. Each case maps to a `(live, idle)` nanosecond pair. `.balanced` is the default and equals today's 45s / 10min so behaviour is unchanged out of the box. Floors are enforced by construction (the enum can't express a sub-floor value), which satisfies the `app-settings` floor requirement without runtime clamping. Suggested table:

| Preset | Live | Idle |
| --- | --- | --- |
| Battery Saver | 90s | 30min |
| Balanced (default) | 45s | 10min |
| Aggressive | 20s | 5min |

**Alternative considered:** free-form seconds with runtime clamping. Rejected for v1 — more UI, more validation, and invites abusive polling of the unofficial ESPN endpoint. Presets encode the floors intrinsically. Can be added later without breaking the enum (add a `.custom(live:idle:)`).

### D3 — Menu bar live pill: render tiers, and moving beyond a `String` title

The dropdown pill is a red `Capsule` with white text (`MatchRow.statusBadge`). The menu bar title is currently a `String` from `MenuBarTitle.text`. A colored capsule cannot be expressed as a `String`, so `MenuBarLabel` must build a *view* when the pill is shown, while still using `MenuBarTitle` for the textual core ("ARS 1–0 CHE"). Plan:
- Keep `MenuBarTitle` as the pure text composer (now taking the effective abbreviations and returning the score/time core).
- `MenuBarLabel` composes an `HStack` of that text plus, when live + enabled, the indicator view.
- **The rendering of a colored capsule in the ~22pt menu bar is an unverified risk** (`MenuBarExtra` bridges into an `NSStatusItem`; template rendering may strip color). Define fallback tiers, to be chosen by a quick spike during implementation:
  1. Red `Capsule` + white minute text (exact dropdown match) — preferred.
  2. Colored text minute (`.foregroundStyle(.red) "37'"`) with no capsule.
  3. Emoji indicator (`🔴`) which always renders in color, ± minute text.

The "include match minute" toggle selects between showing `statusDetail` inside the indicator vs. a minute-less compact dot. Width is a concern; the minute-less mode exists partly to keep the bar short.

**Alternative considered:** always emoji `🔴`. Rejected as the default — cruder than the dropdown; but it's the guaranteed-render fallback (tier 3).

### D4 — Abbreviation overrides as a display-time resolve, keyed by ESPN team id

Store overrides as `[teamID: String]` in `AppSettings`, persisted as a `UserDefaults` dictionary. Resolution is a small function `effectiveAbbreviation(for: Team)` → override if present and non-blank, else `team.abbreviation`. Both readers (`MenuBarTitle`/label and `TeamLogoView.fallback`) call it. Team id is ESPN's stable numeric string (already the model's identity), so overrides survive across fetches and days.

Editing is contextual: a `.contextMenu` on the team line in `MatchRow` with a "Set abbreviation…" entry (small inline text field or a tiny prompt) and a "Reset to default" entry shown only when an override exists. Rationale: teams only exist in memory after a fetch — there is no master team list to populate a settings table cleanly, and right-click-in-context is discoverable and needs no empty-state UI. The `Settings` window does not need an override table in v1 (the proposal keeps overrides contextual).

**Alternative considered:** a table of "teams seen this session" in the Settings window. Rejected for v1 — empty on first launch, teams come and go, more UI for a niche edit.

**Blank handling:** an empty/whitespace override clears the entry (per spec) so users can't blank a team out.

### D5 — Opening the `Settings` scene from a `.accessory` app

Add a `Settings { SettingsView() }` scene to the `App` body. Under `.accessory` there is no menu bar app menu, so ⌘, isn't automatically routed; provide an explicit "Settings…" control (e.g. in the popover footer next to Quit) that activates the app and opens settings. Opening likely needs `NSApp.activate(ignoringOtherApps:)` plus the appropriate open-settings action for the deployment target (the `showSettingsWindow:`/`showPreferencesWindow:` selector differs by macOS version — resolve at implementation time against the macOS 13 floor). After the window closes, the app stays `.accessory`.

## Risks / Trade-offs

- **[Colored pill may not render in the menu bar]** → D3 defines a 3-tier fallback; a 15-minute spike at the start of implementation picks the tier before the title view is finalized. Worst case (tier 3 emoji) still satisfies the spec's "live indicator, optionally with minute".
- **[Menu bar width bloat]** → "ARS 1–0 CHE 37'" plus an indicator is wide. Mitigation: the minute-less compact mode, and keeping the indicator small; document that very long titles are inherent to text tickers.
- **[`Settings` scene quirks under `.accessory`]** → D5; provide an explicit open control rather than relying on the standard menu item, and verify activation on macOS 13.
- **[Cadence read races the poll loop]** → the loop reads settings each iteration on the main actor (`MatchStore` is `@MainActor`); a change is picked up next tick with no torn state. No mitigation needed beyond keeping reads on the main actor.
- **[Tests can't compile here]** → verification is via `swift build` + manual run (`swift run`), consistent with the existing project constraint; keep new logic (cadence mapping, `effectiveAbbreviation`, title composition) in pure functions so it's trivially testable once a test host is available.

## Open Questions

- Final defaults for the two live-indicator toggles: ship with the indicator **on** (the feature's point) or **off** (conservative, opt-in)? Leaning on: indicator on, minute on, to match the dropdown — revisit if the pill spike disappoints.
- Exact preset names/values (D2 table) — placeholders pending a preference.
- Whether the Settings window should also list existing overrides for bulk reset (deferred out of v1 by D4).
