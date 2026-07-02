## Why

The app is currently an empty menu bar skeleton (a `Refresh`/`Quit` dropdown with no data). To deliver the product goal — glanceable live and upcoming football scores — it needs a real data source, a model of matches, an auto-refresh loop that reacts to live play, and a menu bar surface that shows scores. The 2026 FIFA World Cup is live right now, giving us real live data to build and validate against today.

## What Changes

- Introduce a `MatchDataProvider` protocol as the seam for all match data, with an `ESPNProvider` implementation that reads ESPN's unofficial scoreboard endpoint (`site.api.espn.com/apis/site/v2/sports/soccer/{slug}/scoreboard`) — free, no signup, no API key, genuinely real-time.
- Add Codable value-type models: `League`, `Match`, `Team`, `Score`, and a `MatchState` (pre/in/post) derived from ESPN's `state` field.
- Ship a hardcoded v1 league set keyed by ESPN slug: `fifa.world` (World Cup, priority/live), `eng.1` (Premier League), `uefa.champions` (Champions League). Each selected league is one scoreboard call.
- Add an `@Observable` store that fetches matches across the selected leagues and exposes them to SwiftUI via the environment.
- Add a state-driven refresh loop: poll fast (~30–60s, LIVE mode) whenever any selected match is `in`, and back off to a lazy tick (~5–15 min, IDLE mode) otherwise.
- Replace the placeholder menu contents with a match list grouped by league showing team names, score, and status (kickoff time / live minute / final). Likely switch `MenuBarExtra` from `.menu` to `.window` for a richer popover.
- Non-goals for v1 (recorded, deferred): a user-facing league picker (leagues stay hardcoded), and a football-data.org fallback provider (the protocol makes it a drop-in later).

## Capabilities

### New Capabilities
- `match-data`: Fetching football match/score data from a pluggable provider — the `MatchDataProvider` protocol, the ESPN implementation, the supported-league slug table, and the Codable models the rest of the app consumes.
- `score-refresh`: The auto-refreshing store that keeps matches current, including the state-driven cadence (fast while any match is live, lazy when idle).
- `menu-bar-display`: The menu bar surface that presents matches and scores grouped by league in a glanceable form.

### Modified Capabilities
<!-- None — this is the first feature; no existing specs. -->

## Impact

- **New code:** `Models/` (League, Match, Team, Score, MatchState), `Services/` (MatchDataProvider protocol + ESPNProvider), `Store/` (observable match store + refresh loop), `Views/` (match list menu content).
- **Modified code:** `FootballMenuBarApp.swift` (inject the store; likely switch to `.menuBarExtraStyle(.window)`), `MenuContent.swift` (replaced by the match-list view).
- **Dependencies:** none added — `async/await` + `URLSession` only, per project conventions.
- **External:** depends on ESPN's unofficial endpoint (unversioned, can change without notice); the `MatchDataProvider` seam contains that risk to a single file.
