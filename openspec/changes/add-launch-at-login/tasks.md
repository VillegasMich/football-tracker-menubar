## 1. De-risk: does registration work under an ad-hoc signature?

- [x] 1.1 Build and install a bundle the way a user gets one — `./build.sh`, then copy `FootballMenuBar.app` to `/Applications` — and confirm the ad-hoc signature is intact by verifying `codesign -dv /Applications/FootballMenuBar.app` reports the `com.local.footballmenubar` identifier with an ad-hoc signature
- [x] 1.2 From a temporary throwaway call in `AppDelegate` (removed before the real implementation lands), invoke `SMAppService.mainApp.register()` in that installed bundle and verify it does not throw, recording the resulting `SMAppService.mainApp.status`
- [ ] 1.3 Verify the app appears in System Settings → General → Login Items under **Open at Login** (not "Allow in the Background"), listed with the app's name and icon — this is the `specs/launch-at-login/spec.md` requirement "Registration appears as an application in Login Items"
- [x] 1.4 Verify the upgrade path: rebuild with `./build.sh` (producing a new `cdhash`), replace `/Applications/FootballMenuBar.app`, relaunch, and record what `status` reports — confirming the `notRegistered`/`notFound` behavior the reconciliation in section 3 is designed for
- [x] 1.5 If 1.2 or 1.3 fails under an ad-hoc signature, stop and report the finding before building the UI — per `design.md` — Risks, this determines the feature's viability, not just its polish

## 2. Login-item controller

- [x] 2.1 Add `Sources/FootballMenuBar/Settings/LaunchAtLoginController.swift` — a `@MainActor` `ObservableObject` importing `ServiceManagement`, owning its own `UserDefaults` intent key and a published representation of the current registration state — and verify `swift build` succeeds
- [x] 2.2 Implement the availability check (`Bundle.main.bundleURL.pathExtension == "app"`) and verify it reports unavailable under `swift run` and available under `./dev.sh`
- [x] 2.3 Implement `refreshStatus()`, reading `SMAppService.mainApp.status` into the published state, mapping each case (`enabled`, `requiresApproval`, `notRegistered`, `notFound`) to a distinct rendered state, and verify by logging the state after a manual register/unregister
- [ ] 2.4 Implement enable/disable, calling `register()`/`unregister()`, persisting the user's intent, and refreshing status afterward so the published state reflects what the OS actually holds — verify the toggle state after each call matches System Settings
- [x] 2.5 Make failures non-fatal: catch registration/unregistration errors, leave the app running, and refresh status so the published state shows the OS's actual state — verify by attempting to register from an unbundled `swift run` build and confirming no crash

## 3. Reconciliation and wiring

- [x] 3.1 Implement adopt-only launch reconciliation: read `status`, and when it disagrees with the persisted intent, update the intent to match the OS without registering or unregistering — verify by removing the login item in System Settings, relaunching, and confirming the toggle reads off and no login item reappears
- [x] 3.2 Call the reconciliation from `AppDelegate` in `FootballMenuBarApp.swift`, constructing the controller alongside `settings`/`notifier`/`store` and injecting it into the environment — verify the app launches and the settings window renders the correct initial state
- [x] 3.3 Refresh status when the settings window becomes key, using the existing `NSWindowDelegate` conformance on `SettingsWindowManager` — verify by disabling the login item in System Settings while the window is in the background, then refocusing the window and confirming the toggle updates

## 4. Settings UI

- [x] 4.1 Add a **Startup** section to `SettingsView` above **Refresh**, with an "Open at login" toggle bound to the controller — verify it appears in the settings window and that toggling it changes the entry in System Settings → Login Items
- [x] 4.2 Disable the toggle with an explanatory caption when the app is not running from an `.app` bundle — verify under `swift run` that the toggle is greyed out with the caption shown, and under `./dev.sh` that it is enabled
- [x] 4.3 Show the pending-approval caption and an "Open Login Items…" button calling `SMAppService.openSystemSettingsLoginItems()` when status is `requiresApproval` — verify the button opens the Login Items pane, and that the caption disappears after approving and refocusing the window
- [x] 4.4 Verify the section matches the surrounding conventions — `.font(.caption)` / `.foregroundStyle(.secondary)` captions and the existing `Form`/`Section` grouping — and that the window still lays out at its fixed 360pt width

## 5. Documentation and cleanup

- [x] 5.1 Remove the temporary registration call added in task 1.2 and verify `swift build` succeeds with no leftover scaffolding
- [x] 5.2 Add a README note that the app can be set to open at login from Settings, and that the setting is managed in System Settings → General → Login Items — verify the note matches the shipped UI wording
- [x] 5.3 Run `openspec validate --strict add-launch-at-login` and verify it passes
- [ ] 5.4 End-to-end verification: with the toggle on, log out and back in, and confirm the app starts automatically with its menu bar item present
