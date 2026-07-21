<div align="center">

<img width="120" height="120" alt="Football Menu Bar icon" src="https://github.com/user-attachments/assets/decd8857-2304-4efd-99fb-07dd4dc47184" />

# Football Menu Bar

Live football scores, right in your macOS menu bar.

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black?logo=apple)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](#requirements)

<img width="213" height="155" alt="Match popover showing live scores" src="https://github.com/user-attachments/assets/c5bb3129-2889-4909-944f-b8def897d00c" />
<img width="121" height="158" alt="Match list with team logos" src="https://github.com/user-attachments/assets/b456bfac-0786-4f96-bf4b-d2f3425ac942" />

</div>

Football Menu Bar is a lightweight, native SwiftUI app that lives in your menu
bar and keeps you updated on live matches — no Dock icon, no browser tab, no
distractions. Built entirely on `MenuBarExtra`, it polls ESPN's scoreboard and
surfaces scores, kickoff times, and live match minutes at a glance.

## Features

- **Live scores at a glance** — click the menu bar icon for a popover with
  today's matches, scores, and status
- **Menu bar live indicator** — pin a match and show a red "live" pill (with
  the match minute) directly in the menu bar title
- **World Cup, Premier League & Champions League** coverage out of the box
- **Custom team abbreviations** — right-click any team to set your own
  abbreviation, used wherever a crest isn't available
- **Configurable refresh cadence** — Battery Saver, Balanced, or Aggressive
  polling presets
- **Zero Dock footprint** — runs as a background `.accessory` app

## Requirements

- macOS 13 or later
- Swift 6 toolchain (no full Xcode install required)

## Getting Started

### Install with Homebrew

The easiest way to install Football Menu Bar is through my Homebrew tap:

```sh
brew tap VillegasMich/tap
brew install --cask football-menubar
```

This drops `FootballMenuBar.app` into `/Applications`. Launch it from Spotlight
or with `open -a FootballMenuBar`.

Update to the latest release at any time with:

```sh
brew upgrade --cask football-menubar
```

Uninstall (optionally removing saved settings) with:

```sh
brew uninstall --cask football-menubar
brew uninstall --zap --cask football-menubar   # also removes preferences
```

### Run in development

```sh
swift run
```

A ⚽ icon appears in the menu bar. The app has no Dock icon (it runs as an
`.accessory` app). Use **Quit** in the menu to stop it, or press `Ctrl-C` in
the terminal that launched it.

### Build a standalone app

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

- **Update frequency** — pick a refresh cadence preset (Battery Saver /
  Balanced / Aggressive); each maps to a bounded live/idle poll interval
- **Menu bar live indicator** — show a red pill on the pinned match's menu bar
  title while it's live, optionally including the match minute

**Team abbreviations** are edited contextually: right-click a team in the
popover to set a custom abbreviation (used in the menu bar title and wherever
a logo isn't available) or reset it to the ESPN default. All settings persist
across relaunches.

## Project Layout

| File | Purpose |
| --- | --- |
| `Sources/FootballMenuBar/FootballMenuBarApp.swift` | App entry point, `AppDelegate` (hides the Dock icon), the menu bar label, and the `Settings` scene |
| `Sources/FootballMenuBar/Views/MatchListView.swift` | The popover: match rows, footer controls, and the abbreviation context menu |
| `Sources/FootballMenuBar/Views/SettingsView.swift` | The Settings window contents |
| `Sources/FootballMenuBar/Settings/AppSettings.swift` | Persisted, observable user configuration |
| `Sources/FootballMenuBar/Store/MatchStore.swift` | Match data store and the state-driven refresh loop |
| `Sources/FootballMenuBar/Services/ESPNProvider.swift` | Fetches live match data from ESPN's scoreboard API |
| `Sources/FootballMenuBar/Models/League.swift` | Supported leagues (World Cup, Premier League, Champions League) |

## Data Source

Match data is fetched from ESPN's public scoreboard endpoints. This project
is not affiliated with or endorsed by ESPN.
