# football-menubar-app

A macOS **menu bar app** that shows football (soccer) matches and **live results**.
The user picks which **leagues** they care about, and the menu bar surfaces
matches and scores from just those leagues.

## Product goals
- Live and upcoming match results for a set of supported leagues.
- A settings/selection UI where the user chooses which leagues to follow.
- Lightweight, glanceable menu bar presence — quick to open, no Dock icon.
- Auto-refreshing scores at a sensible interval while matches are live.

## Tech stack
- **Language:** Swift 6 (toolchain only — full Xcode is NOT installed).
- **UI:** SwiftUI, using the `MenuBarExtra` scene (macOS 13+).
- **Build system:** Swift Package Manager (executable target). No `.xcodeproj`.
- **App style:** `.accessory` activation policy → menu bar only, no Dock icon.

## Build & run
```sh
swift build      # compile
swift run        # launch (⚽ appears in the menu bar)
```
There is no test target yet. When adding one, use `swift test`.

## Project layout
| Path | Purpose |
| --- | --- |
| `Package.swift` | SPM manifest, macOS 13+ executable target |
| `Sources/FootballMenuBar/FootballMenuBarApp.swift` | `@main` entry + `AppDelegate` (hides Dock icon) |
| `Sources/FootballMenuBar/MenuContent.swift` | Menu bar dropdown contents |

Suggested structure as the app grows (not yet created):
- `Models/` — `League`, `Match`, `Team`, `Score` value types.
- `Services/` — API client for fetching fixtures/live scores.
- `Store/` — observable app state (selected leagues, cached matches).
- `Views/` — SwiftUI views (menu content, league picker / settings).

## Conventions
- Prefer value types (`struct`) and `Codable` for API models.
- Keep app state in an `@Observable` / `ObservableObject` store injected via
  the SwiftUI environment; avoid globals and singletons where practical.
- Networking is `async/await` with `URLSession`; no third-party deps unless a
  clear need is discussed first.
- Persist the user's selected leagues (e.g. `UserDefaults`) so choices survive
  restarts.
- Switch `MenuBarExtra` to `.menuBarExtraStyle(.window)` when a richer popover
  UI (match lists, league picker) is needed instead of a plain dropdown menu.

## Open decisions / TODO
- Choose a football data API (e.g. football-data.org, API-Football) and how the
  API key is supplied/stored. Not yet selected.
- Define the initial set of supported leagues.
- Decide the live-score refresh cadence and how to back off when idle.
