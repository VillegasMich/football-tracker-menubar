## Why

The menu bar currently shows a static ⚽ icon, so following one specific match means opening the popover and scanning the list repeatedly. Letting the user pin a single match and surface it right in the menu bar title turns the app into a glanceable live ticker for the game they actually care about.

## What Changes

- Add a **pin affordance** to each match row in the popover; pinning is single-select — pinning a new match replaces any previously pinned one.
- When a match is pinned, the **menu bar title** becomes a text ticker for it: home/away abbreviations plus score, reflecting the match state (live score, kickoff time when upcoming, final score when finished). With nothing pinned — or when the pinned match is no longer in the feed — the title falls back to the ⚽ soccerball.
- **Persist** the pinned match id in `UserDefaults` so the pin survives app restarts.
- Add **team logos to the popover rows** (dropdown only, not the menu bar title): loaded asynchronously from ESPN's per-team `logo` URL and cached in memory, with the uppercased team abbreviation as fallback when a logo is missing or fails to load.
- Extend the **refresh cadence** so a pinned upcoming match kicking off today also drives the fast (LIVE) polling interval, letting the title flip to the live score promptly at kickoff.
- Hoist `MatchStore` observation to the `App` scene so the `MenuBarExtra` label re-renders when matches refresh (currently the label is a static, unobserved image).

## Capabilities

### New Capabilities
- `match-pinning`: pin exactly one match at a time, persist the selection, and render the menu bar title as a live text ticker for the pinned match with a ⚽ fallback.

### Modified Capabilities
- `menu-bar-display`: match rows gain team logos (with uppercase-abbreviation fallback) and a pin/unpin control; the menu bar label is no longer unconditionally ⚽ — its content is defined by the `match-pinning` capability.
- `score-refresh`: the fast/slow cadence decision additionally treats a pinned upcoming match kicking off today as a reason to poll on the fast (LIVE) interval.
- `match-data`: the `Team` model gains an optional logo URL, decoded from the ESPN scoreboard team payload.

## Impact

- **Models**: `Team` gains an optional logo URL field.
- **Provider**: `ESPNProvider` decodes the existing `logo` field on each competitor's team.
- **Store**: `MatchStore` gains persisted single-pin state (`pinnedMatchID`), a pin/unpin API, a derived pinned-match accessor, and cadence logic that accounts for a pinned upcoming fixture.
- **App scene**: `FootballMenuBarApp` observes the store so the `MenuBarExtra` label updates; the label switches from a static `systemImage` to state-driven title content.
- **Views**: `MatchListView`'s row gains a logo view (with abbreviation fallback) and a pin toggle; a small async image cache/loader is introduced.
- **Persistence**: one new `UserDefaults` key for the pinned match id.
- **External**: no new dependency or API key; reuses ESPN logo URLs already present in the scoreboard response.
