# football-menubar-app

A macOS menu bar app built with SwiftUI's `MenuBarExtra`.

<img width="36" height="26" alt="Screenshot 2026-07-03 at 9 05 51 AM" src="https://github.com/user-attachments/assets/1e219ce8-c7f5-40b5-ad27-0ac91b126820" />
<img width="213" height="155" alt="Screenshot 2026-07-03 at 9 06 09 AM" src="https://github.com/user-attachments/assets/c5bb3129-2889-4909-944f-b8def897d00c" />
<img width="121" height="158" alt="Screenshot 2026-07-03 at 9 05 59 AM" src="https://github.com/user-attachments/assets/b456bfac-0786-4f96-bf4b-d2f3425ac942" />


## Requirements
- macOS 13 or later
- Swift 6 toolchain (no full Xcode required)

## Run (development)

```sh
swift run
```

A ⚽ icon appears in the menu bar. The app has no Dock icon (it runs as an
`.accessory` app). Use **Quit** in the menu to stop it, or press `Ctrl-C` in
the terminal that launched it.

## Build a standalone app

To get an app you can launch and leave running (no terminal attached), build
an `.app` bundle:

```sh
./build.sh
```

This produces `FootballMenuBar.app` in the project root. Launch it with:

```sh
open FootballMenuBar.app
```

The ⚽ icon stays in the menu bar and the app keeps running even after you
close the terminal. Use **Quit** in the menu to stop it.

### Install it (optional)

Move the bundle into `/Applications` so it shows up in Spotlight/Launchpad:

```sh
mv FootballMenuBar.app /Applications/
open /Applications/FootballMenuBar.app
```

To launch it automatically at login, add it under
**System Settings → General → Login Items → Open at Login**.

## Settings

Open the **Settings** window from the gear icon in the popover footer (the app
is a Dock-less accessory, so there's no Dock menu). It offers:

- **Update frequency** — pick a refresh cadence preset (Battery Saver / Balanced
  / Aggressive); each maps to a bounded live/idle poll interval.
- **Menu bar live indicator** — show a red pill on the pinned match's menu bar
  title while it's live, optionally including the match minute.

**Team abbreviations** are edited contextually: right-click a team in the
popover to set a custom abbreviation (used in the menu bar title and wherever a
logo isn't available) or reset it to the ESPN default. All settings persist
across relaunches.

## Project layout

| File | Purpose |
| --- | --- |
| `Sources/FootballMenuBar/FootballMenuBarApp.swift` | App entry point, `AppDelegate` (hides the Dock icon), the menu bar label, and the `Settings` scene |
| `Sources/FootballMenuBar/Views/MatchListView.swift` | The popover: match rows, footer controls, and the abbreviation context menu |
| `Sources/FootballMenuBar/Views/SettingsView.swift` | The Settings window contents |
| `Sources/FootballMenuBar/Settings/AppSettings.swift` | Persisted, observable user configuration |
| `Sources/FootballMenuBar/Store/MatchStore.swift` | Match data store and the state-driven refresh loop |
