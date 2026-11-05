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
- **Language:** Swift 6 (toolchain only — full Xcode is NOT installed).
- **UI:** SwiftUI, using the `MenuBarExtra` scene (macOS 13+).
- **Build system:** Swift Package Manager (executable target). No `.xcodeproj`.
- **App style:** `.accessory` activation policy → menu bar only, no Dock icon.

## Build & run
```sh
swift build      # compile
swift run        # launch (⚽ appears in the menu bar)
```

## Tests
```sh
./test.sh                     # run the whole suite (Swift Testing)
./test.sh --filter <name>     # run matching tests; extra args go to `swift test`
```
Use `./test.sh`, not plain `swift test`. With only the Command Line Tools
installed, `swift test` fails with "no such module 'Testing'" because Swift
Testing lives in the CLT's Developer directory, which SwiftPM doesn't search.
The script adds that framework path (compile, link and rpath) when the active
developer directory is the Command Line Tools, and is plain `swift test` with
full Xcode. Tests live in `Tests/FootballMenuBarTests` and must run offline:
responses from the Primary Source are saved real JSON files under
`Tests/FootballMenuBarTests/Fixtures/ESPN/{slug}/{YYYYMMDD}.json`, served to
`ESPNProvider` through a stub `URLSession`.

## Project layout
| Path | Purpose |
| --- | --- |
| `Package.swift` | SPM manifest, macOS 13+ executable target and test target |
| `test.sh` | Runs the test suite (see Tests) |
| `Sources/FootballMenuBar/MenuBarTitle.swift` | Pure builder for the Pinned Match's menu bar title |
| `Sources/FootballMenuBar/MatchRowPresentation.swift` | Pure presentation of a single Match row |
| `Sources/FootballMenuBar/CompetitionFailureNote.swift` | Pure wording of the note under a Competition that failed to update |
| `Tests/FootballMenuBarTests/` | Swift Testing suite and saved Primary Source responses |
| `Sources/FootballMenuBar/FootballMenuBarApp.swift` | `@main` entry + `AppDelegate` (hides Dock icon; tells the store when the popover opens or closes, the Mac wakes and the network comes back) |
| `Sources/FootballMenuBar/Store/MatchStore.swift` | Match store and its refresh loop: each Competition at its own rate, only what's visible or pinned; `refreshNow()` after waking or reconnecting |
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
