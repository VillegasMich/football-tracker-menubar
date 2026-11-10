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
- **Choose from 37 Competitions** — Leagues and Cups from England, Spain,
  Germany, Italy, France and beyond, plus UEFA, the Americas and FIFA; the
  World Cup, Premier League and Champions League are followed out of the box
- **Custom team abbreviations** — right-click any team to set your own
  abbreviation, used wherever a crest isn't available
- **Refresh setting** — Battery Saver, Balanced, or Aggressive. Each
  Competition refreshes at its own rate: the Live rate while something in it
  is changing or about to, the Idle rate otherwise. With the popover closed,
  only the Pinned Match's Competition is refreshed (nothing without a pin);
  opening the popover, waking the Mac or reconnecting to the network
  refreshes straight away
- **Zero Dock footprint** — runs as a background `.accessory` app

## Requirements

- macOS 13 or later
- To build from source: Xcode with Swift 6, selected with `xcode-select`. On
  macOS 27 the Command Line Tools alone can't build the app: the SDK's
  SwiftUI needs a macro plugin that ships only with Xcode

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
./dev.sh
```

This builds **FootballMenuBar Dev**, a separate copy of the app with its own
bundle ID (`com.local.footballmenubar.dev`) and its own settings, installs it
at `~/Applications/FootballMenuBar Dev.app` and launches it. It runs alongside
an installed Football Menu Bar: running `./dev.sh` again quits and relaunches
only the dev copy, never the installed app. Use `./dev.sh --no-launch` to
build and install it without launching it.

A ⚽ icon appears in the menu bar. The app has no Dock icon (it runs as an
`.accessory` app). Use **Quit** in the menu to stop it.

`swift run` isn't supported: without an app bundle the app crashes at launch
when it sets up notifications.

### Build a standalone app

To build the release app (bundle ID `com.local.footballmenubar`, the same app
the Homebrew cask installs):

```sh
./build.sh                 # version 1.0.0
VERSION=1.2.3 ./build.sh   # version 1.2.3
```

This produces `FootballMenuBar.app` in the project root, with `VERSION` as
its version, plus `FootballMenuBar-${VERSION}.zip` for a GitHub Release (the
release workflow sets `VERSION` from the pushed tag). Launch it with:

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

To launch it automatically at login, turn on **Open at login** in the app's
Settings window (see below). It appears under **System Settings → General →
Login Items → Open at Login**, where it can also be removed.

## Settings

Open the **Settings** window from the gear icon in the popover footer (the app
is a Dock-less accessory, so there's no Dock menu). It offers:

- **Competitions** — choose your Followed Competitions from 37, grouped by
  region (collapsed until you expand one). The popover shows only those, in
  the curated order, and at least one stays followed
- **Open at login** — start Football Menu Bar automatically when you log in.
  Off by default. The switch reflects **System Settings → General → Login
  Items**, so removing the entry there turns it off here too, and the app never
  re-adds itself on its own
- **Update frequency** — pick a Refresh setting (Battery Saver / Balanced /
  Aggressive); each sets a Live rate and an Idle rate
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
| `Sources/FootballMenuBar/Store/MatchStore.swift` | Match data store and the refresh loop: each Competition at its own rate, only what's visible or pinned |
| `Sources/FootballMenuBar/Services/ESPNProvider.swift` | Fetches live match data from ESPN's scoreboard API |
| `Sources/FootballMenuBar/Services/NetworkRecoveryMonitor.swift` | Notices the network coming back, so the app refreshes straight away |
| `Sources/FootballMenuBar/Models/Competition.swift` | The catalogue of 37 Competitions, grouped by region, and the default Followed Competitions |

## Data Source

Match data is fetched from ESPN's public scoreboard endpoints. This project
is not affiliated with or endorsed by ESPN.
