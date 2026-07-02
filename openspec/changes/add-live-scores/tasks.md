## 1. Models

- [ ] 1.1 Create `Models/` and add `MatchState` (upcoming/in-progress/finished) mapping from ESPN `pre`/`in`/`post`
- [ ] 1.2 Add Codable value types `Team`, `Score`, `Match` (two teams, score, state, status detail, kickoff date)
- [ ] 1.3 Add `League` value type (ESPN slug + display name) and the v1 supported-league table: `fifa.world`, `eng.1`, `uefa.champions`

## 2. Match data provider (Services)

- [ ] 2.1 Define the `MatchDataProvider` protocol: `matches(for: [League]) async throws -> [Match]`
- [ ] 2.2 Add `ESPNProvider` with the scoreboard URL builder for a given slug (`site.api.espn.com/apis/site/v2/sports/soccer/{slug}/scoreboard`)
- [ ] 2.3 Implement ESPN response decoding (Codable DTOs) and map into the app models, deriving `MatchState` from `state`
- [ ] 2.4 Fetch multiple leagues concurrently and merge; throw a typed error on network/decode failure (do not crash)

## 3. Vertical slice — one live score end-to-end

- [ ] 3.1 Fetch `fifa.world` via `ESPNProvider` and log/print the parsed matches to confirm live World Cup data decodes
- [ ] 3.2 Render a single match's score in the menu bar (temporary view) to prove the full pipe before building the real UI

## 4. Auto-refreshing store

- [ ] 4.1 Add an `@Observable` store holding selected leagues + current matches + last-fetch error, backed by a `MatchDataProvider`
- [ ] 4.2 Implement a `refresh()` that fetches and updates observable state (clearing prior error on success)
- [ ] 4.3 Add the state-driven polling loop: LIVE interval (~30–60s) when any match is in-progress, IDLE (~5–15 min) otherwise, recomputing mode after each fetch
- [ ] 4.4 Support manual immediate refresh that then resumes the interval

## 5. Menu bar match-list UI (Views)

- [ ] 5.1 Build a match-list view grouped by league showing teams, score, and status detail
- [ ] 5.2 Visually distinguish in-progress matches from upcoming/finished
- [ ] 5.3 Add empty state (no matches / off-season) and error state with a retry action
- [ ] 5.4 Add in-popover Refresh (immediate) and Quit controls

## 6. App integration

- [ ] 6.1 Switch `MenuBarExtra` to `.menuBarExtraStyle(.window)`, keep the ⚽ label
- [ ] 6.2 Instantiate the store with `ESPNProvider`, inject it into the SwiftUI environment, replace `MenuContent` with the match-list view
- [ ] 6.3 Start the refresh loop on launch and stop it cleanly on quit

## 7. Verification

- [ ] 7.1 `swift build` clean; `swift run` shows live World Cup matches in the menu bar
- [ ] 7.2 Confirm LIVE↔IDLE cadence behaves (fast while a World Cup match is `in`, lazy when none live)
- [ ] 7.3 Confirm off-season leagues (`eng.1`, `uefa.champions`) render the empty state without errors
