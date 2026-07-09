## Why

After a match ends, the popover shows the final score but offers no way to actually watch what happened. Users who missed the game want the highlights, and today they have to leave the app and search manually. A one-click path from a finished row to a highlights video closes that gap without adding any paid API or key.

## What Changes

- Add an inline **Highlights** control (a small play/film icon) to the right side of a match row, rendered **only** when the match is finished.
- Clicking it opens the user's default browser to a YouTube search deep-link for that fixture (e.g. `https://www.youtube.com/results?search_query=Everton+vs+Fulham+highlights`).
- Upcoming and in-progress rows show no such control — the icon is strictly gated on finished state.
- No new data source, dependency, or API key: the URL is composed from the two team names already present on the `Match`, and opening it uses the system browser.

## Capabilities

### New Capabilities
- `match-highlights`: the presence/gating of a per-row highlights control on finished matches, and the composition and opening of a YouTube search URL for that fixture.

### Modified Capabilities
<!-- None. The highlights control is additive; it does not change existing row, data, or navigation requirements. -->

## Impact

- **Views**: `MatchRow` in `Sources/FootballMenuBar/Views/MatchListView.swift` gains the conditional highlights icon and the open action.
- **Models/logic**: URL composition from `Match.home.name` / `Match.away.name`; no schema change to `Match`. ESPN's `links` array remains unused.
- **Platform**: uses `NSWorkspace.shared.open(_:)` to launch the default browser; no entitlement or capability changes.
- **Dependencies**: none added.
