# football-menubar-app

A macOS **menu bar app** that shows football (soccer) matches and **live results**.
The user picks which **Competitions** they follow, and the menu bar surfaces
matches and scores from just those Competitions.

## Product goals
- Live and upcoming match results for a curated set of Competitions.
- A settings/selection UI where the user chooses which Competitions to follow.
- Lightweight, glanceable menu bar presence — quick to open, no Dock icon.
- Auto-refreshing scores, each Competition at its own rate (the Live rate
  while something in it is changing or about to, the Idle rate otherwise),
  refreshing only what's visible: the list while the popover is open, the
  Pinned Match's Competition otherwise.

## Tech stack
- **Language:** Swift 6.
- **Toolchain:** full Xcode is required, selected with `xcode-select`
  (`xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`). The
  macOS 27 SDK implements SwiftUI's `@State` as a macro whose plugin
  (`libSwiftUIMacros`) ships only with Xcode, so with the Command Line Tools
  selected the build fails with "plugin for module 'SwiftUIMacros' not found".
- **UI:** SwiftUI, using the `MenuBarExtra` scene (macOS 13+).
- **Build system:** Swift Package Manager (executable target). No `.xcodeproj`.
- **App style:** `.accessory` activation policy → menu bar only, no Dock icon.

## Build & run
```sh
swift build              # compile
./dev.sh                 # build, install and (re)launch "FootballMenuBar Dev"
./dev.sh --no-launch     # build and install the dev copy without launching it
VERSION=1.2.3 ./build.sh # release build: FootballMenuBar.app + FootballMenuBar-1.2.3.zip
```
Run the app with `./dev.sh`, not `swift run`: a bare binary has no app
bundle, so `UNUserNotificationCenter.current()` asserts and the app crashes
at launch.

The dev and release builds are separate apps, so a dev copy runs alongside an
installed FootballMenuBar without disturbing it:

| | `./dev.sh` (dev) | `./build.sh` (release) |
| --- | --- | --- |
| Name | "FootballMenuBar Dev" | "FootballMenuBar" (displayed "Football Menu Bar") |
| Bundle ID | `com.local.footballmenubar.dev` | `com.local.footballmenubar` |
| Output | `~/Applications/FootballMenuBar Dev.app` | `FootballMenuBar.app` and `FootballMenuBar-${VERSION}.zip` in the repo root (both git-ignored) |
| Version | `VERSION`, default `1.0.0` | `VERSION`, default `1.0.0`; the release workflow sets it from the tag |

- Each has its own settings, since `UserDefaults` follow the bundle ID.
- Both are signed ad-hoc with the bundle ID as identifier, which
  notifications need.
- `./dev.sh` always installs to the same place, so macOS keeps remembering
  its menu bar slot. Before replacing it, it quits only a running dev copy,
  matched by its executable path; the installed app is never quit.

## Tests
```sh
./test.sh                     # run the whole suite (Swift Testing)
./test.sh --filter <name>     # run matching tests; extra args go to `swift test`
```
Use `./test.sh`, not plain `swift test`. With Xcode selected (required, see
Tech stack) it is plain `swift test`. It still supports the Command Line Tools
on SDKs that build without Xcode: there, `swift test` fails with "no such
module 'Testing'" because Swift Testing lives in the CLT's Developer
directory, which SwiftPM doesn't search, so the script adds that framework
path (compile, link and rpath) when the active developer directory is the
Command Line Tools. Tests live in `Tests/FootballMenuBarTests` and must run offline:
responses from the Primary Source are saved real JSON files under
`Tests/FootballMenuBarTests/Fixtures/ESPN/{slug}/{YYYYMMDD}.json`, served to
`ESPNProvider` through a stub `URLSession`.

## Project layout
| Path | Purpose |
| --- | --- |
| `Package.swift` | SPM manifest, macOS 13+ executable target and test target |
| `test.sh` | Runs the test suite (see Tests) |
| `dev.sh` | Builds, installs and launches the dev copy (see Build & run) |
| `build.sh` | Builds the release app and its zip (see Build & run) |
| `scripts/bundle-app.sh` | Shared by `dev.sh` and `build.sh`: builds, assembles and signs an app bundle for a given identity |
| `Sources/FootballMenuBar/MenuBarTitle.swift` | Pure builder for the Pinned Match's menu bar title |
| `Sources/FootballMenuBar/MatchRowPresentation.swift` | Pure presentation of a single Match row |
| `Sources/FootballMenuBar/CompetitionFailureNote.swift` | Pure wording of the note under a Competition that failed to update |
| `Tests/FootballMenuBarTests/` | Swift Testing suite and saved Primary Source responses |
| `Sources/FootballMenuBar/FootballMenuBarApp.swift` | `@main` entry + `AppDelegate` (hides Dock icon; tells the store when the popover opens or closes, the Mac wakes and the network comes back) |
| `Sources/FootballMenuBar/Store/MatchStore.swift` | Match store and its refresh loop: each Competition at its own rate, only what's visible or pinned; `refreshNow()` after waking or reconnecting |
| `Sources/FootballMenuBar/Services/NetworkRecoveryMonitor.swift` | Notices the network coming back after being unavailable (not the first path at launch) |
| `Sources/FootballMenuBar/MenuContent.swift` | Menu bar dropdown contents |

Suggested structure as the app grows (not yet created):
- `Models/` — `Competition`, `Match`, `Team`, `Score` value types.
- `Services/` — API client for fetching fixtures/live scores.
- `Store/` — observable app state (Followed Competitions, cached matches).
- `Views/` — SwiftUI views (menu content, Competition picker / settings).

## Conventions
- Prefer value types (`struct`) and `Codable` for API models.
- Keep app state in an `@Observable` / `ObservableObject` store injected via
  the SwiftUI environment; avoid globals and singletons where practical.
- Networking is `async/await` with `URLSession`; no third-party deps unless a
  clear need is discussed first.
- Persist the user's Followed Competitions (e.g. `UserDefaults`) so choices survive
  restarts.
- Switch `MenuBarExtra` to `.menuBarExtraStyle(.window)` when a richer popover
  UI (match lists, Competition picker) is needed instead of a plain dropdown menu.

## Open decisions / TODO
- ~~Choose a football data API.~~ Decided: ESPN is the Primary Source, with
  OpenLigaDB as a Backup Source for German Competitions. See
  `docs/adr/0001-espn-primary-source-openligadb-backup.md`.
- ~~Define the initial set of supported leagues.~~ Decided: a curated list of 37
  Competitions, specified in the Followed Competitions spec (GitHub issue).
- ~~Decide the live-score refresh cadence and how to back off when idle.~~
  Decided: each Competition refreshes at the Live rate or Idle rate of the
  Refresh setting; only the list while the popover is open, otherwise only
  the Pinned Match's Competition (nothing without a pin); straight away when
  the popover opens, the Mac wakes or the network comes back. Specified in
  the Smarter polling spec (GitHub issue #28).

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues (`VillegasMich/football-tracker-menubar`), managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Specs

New specs live as GitHub issues (see above). `openspec/` is a frozen historical
record: do not update it or use the `/opsx:*` commands for new work.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
