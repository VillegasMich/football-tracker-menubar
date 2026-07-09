## 1. URL composition helper

- [ ] 1.1 Add a pure helper that builds the highlights URL from home and away team names, e.g. `Match.highlightsSearchURL` (or a free function), returning `https://www.youtube.com/results?search_query=<home> vs <away> highlights`
- [ ] 1.2 Build the query with `URLComponents`/`URLQueryItem` so spaces and non-ASCII club names (e.g. `Atlético Madrid`) are percent-encoded and the URL is valid

## 2. Highlights control in MatchRow

- [ ] 2.1 Add a trailing highlights icon button to `MatchRow` (SF Symbol e.g. `play.rectangle`, `.buttonStyle(.borderless)`, `.secondary`, `.help("Watch highlights")`), matching the existing borderless icon-button idiom
- [ ] 2.2 Wrap the control in `if match.state == .finished` so it renders only for finished matches and never for upcoming or in-progress rows
- [ ] 2.3 On tap, compose the URL via the helper and open it with `NSWorkspace.shared.open(_:)`

## 3. Verification

- [ ] 3.1 Build with `swift build` and run the app; confirm the icon appears only on finished rows and is absent on upcoming/live rows
- [ ] 3.2 Click the control on a finished match and confirm the default browser opens the YouTube search for that fixture
- [ ] 3.3 Spot-check a fixture with spaces/accents in a team name to confirm the opened URL is correctly encoded
