## Context

See `proposal.md` — Why, for motivation.

Constraints that shape the approach:

- The package's deployment floor is `macOS 13` (`Package.swift`), set because `MenuBarExtra` requires it. `SMAppService` also arrives in macOS 13, so it is available unconditionally with no `if #available` branching.
- The app is an accessory app (`LSUIElement`) with no Dock icon. Its settings window is hosted in AppKit by `SettingsWindowManager`, which already conforms to `NSWindowDelegate` — a ready hook for "the window came to the front".
- `AppSettings` is a plain `UserDefaults`-backed `ObservableObject`: every existing setting is fully owned by the app, with a single source of truth. Launch-at-login is the first setting whose real state lives outside the app, in LaunchServices, and which the user can change from System Settings without the app knowing.
- Releases are built by `build.sh` and signed **ad hoc** (`codesign --sign -`), then distributed as a Homebrew cask that installs to `/Applications` and is upgraded by replacing the bundle in place.
- There is no runnable test target (no Xcode in the development environment), so verification is manual, against a built bundle.

### Measured behavior (change task 1, run against an ad-hoc-signed bundle)

The approach below rests on findings measured on a real bundle rather than inferred from the signing setup. An earlier revision of this document predicted that ad-hoc signing would break registration across upgrades; that prediction was wrong, and the tasks that existed to work around it have been removed.

| Question | Measured result |
|---|---|
| Does `register()` work under an ad-hoc signature? | Yes — `notRegistered → register() → enabled`, no error thrown. |
| Is `register()` safe to call when already enabled? | Yes — idempotent, no duplicate entry created. |
| Does a new `cdhash` (i.e. an upgrade) invalidate the registration? | **No.** A genuinely different binary at the same path still reports `enabled`. |
| What identifies a registration, then? | The bundle identifier and path — **not** the `cdhash`, even though the ad-hoc designated requirement is a bare `cdhash` pin with no identifier clause and no Team ID. |
| Does `status` see login items the user added by hand in System Settings? | Yes — a manually added login item reports `enabled`. |
| Is `requiresApproval` reached on a first registration? | Not observed; registration went straight to `enabled`. |
| Does a Homebrew-installed copy carry a quarantine attribute? | No — the cask install had none. |

## Goals / Non-Goals

**Goals:**

- A toggle that never lies: what it shows always matches what LaunchServices actually holds, including after the user changes it in System Settings.
- Every state that is not plain on/off — pending approval, unavailable, failed — is legible in the UI rather than silent.
- The user's own decisions about their login items are never silently overridden by the app.

**Non-Goals:**

- Obtaining a Developer ID signature. Ad-hoc signing was measured to be sufficient for this feature, so a certificate buys nothing here; it remains a distribution decision on its own merits.
- Registering any helper agent or daemon, or doing any work at login beyond launching the app itself.
- Migrating the app's other settings to a two-layer state model. The pattern introduced here is specific to state the OS owns.
- Repairing a registration the user removed. See "Reconciliation is adopt-only".

## Decisions

### Use `SMAppService.mainApp`

Register the main app itself, via `SMAppService.mainApp.register()` / `.unregister()`, reading `.status` for the current state.

*Alternatives considered:*

- **`SMLoginItemSetEnabled` with a helper bundle** — deprecated, and requires shipping a second bundle inside `Contents/Library/LoginItems`, complicating `build.sh` for no gain at this deployment floor.
- **Writing a `LaunchAgent` plist into `~/Library/LaunchAgents`** — rejected for two reasons. It puts the app in the *"Allow in the Background"* section of Login Items as an opaque background item, when the requirement is to appear in *"Open at Login"* as the app itself (see `specs/launch-at-login/spec.md` — "Registration appears as an application in Login Items"). It also makes the app the permanent owner of a plist's lifecycle and of the path baked into it.

`SMAppService.agent` and `.daemon` are wrong for the same reason as the LaunchAgent: they land in the background-items list.

### Two-layer state: persisted intent, OS actual

Persist a `UserDefaults` boolean recording what the user asked for, and read `SMAppService.mainApp.status` for what is actually true. The toggle renders from `status`, never from the persisted value alone.

The alternative — a single `@Published var launchAtLogin: Bool` with a `didSet` writing to `UserDefaults`, matching every other setting in `AppSettings` — was rejected: it would show "on" indefinitely after the user removed the login item in System Settings. This is not hypothetical; `status` was measured to reflect login items added and removed outside the app.

### Reconciliation is adopt-only

At launch, when `status` disagrees with the persisted intent, **the app adopts `status` as the new intent and changes nothing about the registration**. It never registers or unregisters on the user's behalf at launch.

This is a reversal from an earlier revision, which re-registered when intent was on but `status` was not `enabled`. That rule existed solely to repair registrations believed lost to upgrades. Since upgrades were measured not to lose them, the realistic way to reach "intent on, status notRegistered" is *the user deliberately removing the login item in System Settings* — and re-registering would silently override that choice. Adopting is both simpler and the only defensible behavior.

The persisted intent is therefore not a repair instruction; it is what the toggle was last known to be, used to detect drift and to keep the stored value honest.

### Refresh status when the settings window becomes key

`status` is re-read at two moments, the two the app can observe:

| Trigger | Purpose |
|---|---|
| Launch, from `AppDelegate` | Establish the initial state and adopt any drift into the persisted intent. |
| Settings window becomes key, via the existing `NSWindowDelegate` on `SettingsWindowManager` | Catch a change the user made in System Settings while the window was open or in the background, so the toggle is correct whenever it is being looked at. |

Polling `status` on a timer was rejected as disproportionate for a value that only matters while the settings window is visible.

### A dedicated controller, not a field on `AppSettings`

Put the `SMAppService` interaction, the bundle check, and the reconciliation in a small `@MainActor` `ObservableObject` of its own, constructed by `AppDelegate` and injected into the environment alongside the existing objects. This mirrors how `MatchNotifier` is a service that reads `AppSettings` rather than living inside it, and keeps `AppSettings` what it is today: a plain defaults store with no OS coupling.

### Detect the unbundled case by bundle extension

Gate availability on `Bundle.main.bundleURL.pathExtension == "app"`. `dev.sh` builds a real bundle, so the normal development loop keeps the toggle live; only a bare `swift run` from `.build` hits the disabled path. This turns an unexplained registration error into a legible caption.

### `Package.swift` is unchanged

`ServiceManagement` is a system framework reached by `import ServiceManagement`; it is not a package dependency and the macOS 13 platform floor already covers it.

## Risks / Trade-offs

- **`requiresApproval` is specified but was never reached during testing.** It arises when the user has previously disabled the item, which the spike did not reproduce. → The UI for it must still be built, since the state is reachable in normal use, but it ships less exercised than the rest. Keep its handling simple: a caption and a button to the correct System Settings pane.
- **Registering from a bundle at an unexpected path rewrites where the login item points.** Measured during the spike: registering from a development copy repointed an existing login item away from `/Applications`. → Real users only ever run the installed copy, so this is a development hazard rather than a shipping one. It is a second reason the unbundled guard matters, and a reason not to run a registering build from a scratch directory.
- **Stale entries can accumulate in the background-task database** for bundles no longer on disk, since the app cannot unregister a copy that has already been deleted. → Low impact and not addressable from inside the app; the user can remove leftovers from System Settings.
- **Reconciliation adopting an external registration as intent can surprise.** If the user adds the login item from System Settings, the app flips its persisted intent to on. → This is the intended reading of "the OS is the source of truth", and the toggle visibly shows on, so the state is never hidden.
- **`status` is read at two moments only**, so a change made in System Settings while the settings window is already frontmost is not picked up until it is refocused. → Accepted; the alternative is polling.

## Migration Plan

No migration. The feature is additive and defaults off, so an existing install is unaffected until the user opts in. Rollback is removing the Startup section and the controller; any login item a user registered would then persist until removed from System Settings, so a rollback release should unregister on launch if one is ever needed.
