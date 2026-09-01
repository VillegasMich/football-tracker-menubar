## Context

See `proposal.md` — Why, for motivation.

Constraints that shape the approach:

- The package's deployment floor is `macOS 13` (`Package.swift`), set because `MenuBarExtra` requires it. `SMAppService` also arrives in macOS 13, so it is available unconditionally with no `if #available` branching.
- The app is an accessory app (`LSUIElement`) with no Dock icon. Its settings window is hosted in AppKit by `SettingsWindowManager`, which already conforms to `NSWindowDelegate` — a ready hook for "the window came to the front".
- `AppSettings` is a plain `UserDefaults`-backed `ObservableObject`: every existing setting is fully owned by the app, with a single source of truth. Launch-at-login is the first setting whose real state lives outside the app, in LaunchServices, and which the user can change from System Settings without the app knowing.
- Releases are built by `build.sh` and signed **ad hoc** (`codesign --sign -`), then distributed as a Homebrew cask that installs to `/Applications` and is upgraded by replacing the bundle in place.
- There is no runnable test target (no Xcode in the development environment), so verification is manual, against a built bundle.

## Goals / Non-Goals

**Goals:**

- A registration that survives the app being upgraded through Homebrew, without the user having to notice or re-toggle anything in the app.
- A toggle that never lies: what it shows always matches what LaunchServices actually holds, including after the user changes it in System Settings.
- Every state that is not plain on/off — pending approval, unavailable, failed — is legible in the UI rather than silent.

**Non-Goals:**

- Obtaining a Developer ID signature. It would remove the re-approval prompt (see Risks), but it costs money and CI secrets, and it is a distribution decision independent of this feature.
- Registering any helper agent or daemon, or doing any work at login beyond launching the app itself.
- Migrating the app's other settings to a two-layer state model. The pattern introduced here is specific to state the OS owns.

## Decisions

### Use `SMAppService.mainApp`

Register the main app itself, via `SMAppService.mainApp.register()` / `.unregister()`, reading `.status` for the current state.

*Alternatives considered:*

- **`SMLoginItemSetEnabled` with a helper bundle** — deprecated, and requires shipping a second bundle inside `Contents/Library/LoginItems`, complicating `build.sh` for no gain at this deployment floor.
- **Writing a `LaunchAgent` plist into `~/Library/LaunchAgents`** — rejected for two reasons. It puts the app in the *"Allow in the Background"* section of Login Items as an opaque background item, when the requirement is to appear in *"Open at Login"* as the app itself (see `specs/launch-at-login/spec.md` — "Registration appears as an application in Login Items"). It also makes the app the permanent owner of a plist's lifecycle and of the path baked into it.

`SMAppService.agent` and `.daemon` are wrong for the same reason as the LaunchAgent: they land in the background-items list.

### Two-layer state: persisted intent, OS actual

Persist a `UserDefaults` boolean recording only what the user asked for, and read `SMAppService.mainApp.status` for what is actually true. The toggle renders from `status`, never from the persisted value alone.

The alternative — a single `@Published var launchAtLogin: Bool` with a `didSet` writing to `UserDefaults`, matching every other setting in `AppSettings` — was rejected: it would show "on" indefinitely after the user removed the login item in System Settings.

The persisted intent is still needed, and is not redundant with `status`: it is the only way to distinguish "the user wants this and the registration went missing" (re-register) from "the user never asked for this" (do nothing) when `status` reports `notRegistered` at launch.

### Reconcile on launch and on settings-window focus

Two reconciliation points, chosen because they are the two moments the app can observe drift:

| Trigger | Purpose |
|---|---|
| Launch, from `AppDelegate` | Catch a registration lost to a bundle replacement (upgrade) and restore it; adopt an externally added registration as intent. |
| Settings window becomes key, via the existing `NSWindowDelegate` on `SettingsWindowManager` | Catch a change the user made in System Settings while the window was open or in the background, so the toggle is correct whenever it is being looked at. |

Polling `status` on a timer was rejected as disproportionate for a value that only matters while the settings window is visible.

### A dedicated controller, not a field on `AppSettings`

Put the `SMAppService` interaction, the bundle check, and the reconciliation in a small `@MainActor` `ObservableObject` of its own, constructed by `AppDelegate` and injected into the environment alongside the existing objects. This mirrors how `MatchNotifier` is a service that reads `AppSettings` rather than living inside it, and keeps `AppSettings` what it is today: a plain defaults store with no OS coupling.

### Detect the unbundled case by bundle extension

Gate availability on `Bundle.main.bundleURL.pathExtension == "app"`. `dev.sh` builds a real bundle, so the normal development loop keeps the toggle live; only a bare `swift run` from `.build` hits the disabled path. This turns an unexplained registration error into a legible caption.

### `Package.swift` is unchanged

`ServiceManagement` is a system framework reached by `import ServiceManagement`; it is not a package dependency and the macOS 13 platform floor already covers it.

## Risks / Trade-offs

- **Ad-hoc signing gives every release a new identity → the login item must be re-approved after each `brew upgrade --cask`.** An ad-hoc signature carries no Team ID, so the designated requirement is pinned to the bundle's `cdhash`. Each `build.sh` run produces a new `cdhash`, so LaunchServices treats each release as a different application claiming the same bundle id, and the previous registration goes stale. → *Mitigated, not solved*, by the launch-time reconciliation: the app silently re-registers itself, so the feature keeps working, at the cost of one "Login item added" notification and possibly one approval per upgrade. This is an accepted cost of ad-hoc distribution; a Developer ID signature is the real fix and is a Non-Goal here. The README must state it so the prompt is not read as a bug.
- **Registration may fail outright under an ad-hoc signature.** Ad-hoc identities are the historically fragile case for `SMAppService`, and a cask-installed copy may additionally carry a quarantine attribute. → Verify empirically against an installed, ad-hoc-signed bundle as the first implementation task; if it fails there, the feature's viability — not just its polish — is in question, and that finding should come before any UI work. The non-fatal-failure requirement in the spec means a failure degrades to a toggle that will not stay on, rather than a crash.
- **Stale entries can accumulate in the background-task database** for `cdhash` values no longer on disk, since the app cannot unregister a build that has already been replaced. → Not addressable from inside the app; the user can remove leftovers from System Settings. Low impact: entries point at a path that still resolves to the current app.
- **Reconciliation adopting an external registration as intent can surprise.** If the user adds the login item from System Settings, the app flips its persisted intent to on. → This is the intended reading of "the OS is the source of truth", and the toggle visibly shows on, so the state is never hidden.
- **`status` is read at two moments only**, so a change made in System Settings while the settings window is already frontmost is not picked up until it is refocused. → Accepted; the window is small and modal in practice, and the alternative is polling.

## Migration Plan

No migration. The feature is additive and defaults off, so an existing install is unaffected until the user opts in. Rollback is removing the Startup section and the controller; any login item a user registered would then persist until removed from System Settings, so a rollback release should unregister on launch if one is ever needed.
