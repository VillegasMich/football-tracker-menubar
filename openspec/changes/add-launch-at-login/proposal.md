## Why

Football Menu Bar is a passive, always-on accessory app: it is only useful while it is running, and a user who wants live scores in their menu bar wants them every day without relaunching the app by hand after each reboot. Today there is no way to have it start automatically — the user must open it manually every login.

## What Changes

- Add an **Open at login** toggle to the settings window, in a new **Startup** section above **Refresh**.
- Register the app with `SMAppService.mainApp` (macOS 13+, matching the existing deployment floor) so it appears in **System Settings → General → Login Items → Open at Login** as the app itself — not as an opaque background item.
- Default the setting to **off**, so the app never adds itself to Login Items without the user asking.
- Treat the operating system as the source of truth for whether the app actually launches at login, and `UserDefaults` only as the user's remembered *intent*. Reconcile the two on launch and whenever the settings window comes to the front, so a change made in System Settings is reflected in the toggle rather than silently contradicting it.
- Surface the `requiresApproval` state with an explanatory caption and an **Open Login Items…** button that deep-links to the correct System Settings pane.
- Disable the toggle, with an explanation, when the app is not running from an `.app` bundle (a bare `swift run`), where registration cannot succeed.
- Document in the README that, because releases are ad-hoc signed, the app's code-signing identity changes with every build, so `brew upgrade --cask` re-registers the login item and macOS asks the user to approve it again.

No breaking changes: the feature is additive and defaults off, so existing installs behave exactly as before until the user opts in.

## Capabilities

### New Capabilities
- `launch-at-login`: Whether the app registers itself to start automatically at login — the user-facing toggle and its default, the two-layer intent/actual state model and its reconciliation, the approval and not-registered states and how they are surfaced, and the unbundled case where registration is unavailable.

### Modified Capabilities
<!-- None. The new capability owns its own persistence and its own section of the
     settings window; no existing requirement in `app-settings` changes behavior. -->

## Impact

- **New dependency**: `ServiceManagement` (system framework). No `Package.swift` change — no new package dependency, and `SMAppService.mainApp` is available unconditionally at the existing macOS 13 floor.
- **New code**: a controller that wraps `SMAppService`, owns the intent/actual reconciliation, and publishes the observable state the toggle renders.
- **`Sources/FootballMenuBar/FootballMenuBarApp.swift`**: `AppDelegate` constructs the controller and triggers the launch-time reconciliation.
- **`Sources/FootballMenuBar/Settings/SettingsWindowManager.swift`**: refresh the registration status when the settings window becomes key, using the existing `NSWindowDelegate` conformance.
- **`Sources/FootballMenuBar/Views/SettingsView.swift`**: new **Startup** section.
- **`Sources/FootballMenuBar/Settings/AppSettings.swift`**: unchanged if the controller owns its own `UserDefaults` intent key; otherwise one new key alongside the existing ones.
- **`README.md`**: note the re-approval prompt after `brew upgrade --cask`.
- **Accepted cost, not a defect**: ad-hoc signing gives each release a new `cdhash`, so LaunchServices treats each build as a distinct application and the login item must be re-approved after every upgrade. A Developer ID signature would remove this, and is explicitly out of scope here.
- **Not testable in this environment**: registration behavior can only be verified by running the built bundle; the repo has no runnable test target.
