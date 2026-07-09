## 1. URL composition helper

- [x] 1.1 Add a pure helper that builds the highlights URL from home and away team names, e.g. `Match.highlightsSearchURL` (or a free function), returning `https://www.youtube.com/results?search_query=<home> vs <away> highlights`
- [x] 1.2 Build the query with `URLComponents`/`URLQueryItem` so spaces and non-ASCII club names (e.g. `Atlético Madrid`) are percent-encoded and the URL is valid

## 2. Highlights control in MatchRow

- [x] 2.1 Add a trailing highlights icon button to `MatchRow` (SF Symbol e.g. `play.rectangle`, `.buttonStyle(.borderless)`, `.secondary`, `.help("Watch highlights")`), matching the existing borderless icon-button idiom
- [x] 2.2 Wrap the control in `if match.state == .finished` so it renders only for finished matches and never for upcoming or in-progress rows
- [x] 2.3 On tap, compose the URL via the helper and open it with `NSWorkspace.shared.open(_:)`

## 3. Verification

- [x] 3.1 Build with `swift build` and run the app; confirm the icon appears only on finished rows and is absent on upcoming/live rows _(build clean; app launches cleanly via `build.sh` bundle; gating is `if match.state == .finished` — visual confirmation left to the user's click)_
- [ ] 3.2 Click the control on a finished match and confirm the default browser opens the YouTube search for that fixture _(requires a manual click in the popover — app is running for you to confirm)_
- [x] 3.3 Spot-check a fixture with spaces/accents in a team name to confirm the opened URL is correctly encoded _(verified: `Everton` → `%20`, `Atlético` → `Atl%C3%A9tico`)_
