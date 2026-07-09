## Context

The popover renders matches as `MatchRow` views inside `MatchListView`. Each row already has all the data needed for highlights — two `Team` values with `name`, and a `MatchState` (`upcoming` / `inProgress` / `finished`). Finished matches show a `FT`-style status badge but offer no follow-up action.

During exploration we probed ESPN's scoreboard response: it does carry a per-event `links` array, and *sometimes* a `highlights` rel, but only for marquee fixtures (e.g. the Champions League final), and those point to `espn.com/soccer/video/...` pages whose playback is geo-restricted. A YouTube search deep-link, by contrast, works for every finished fixture with no key and no geo hole. The user chose the YouTube approach for all cases, so this design deliberately ignores the ESPN `links` array.

## Goals / Non-Goals

**Goals:**
- One click from a finished match row to that fixture's highlights, in the user's browser.
- Zero new dependencies, no API key, no secret management — consistent with the app's "free, unofficial ESPN endpoint" ethos.
- Strict gating: the control exists only for finished matches.

**Non-Goals:**
- Resolving and opening a *specific* video (would require the YouTube Data API, a key, and quota). We open a search results page and let the user pick.
- Embedding or playing video inside the app.
- Using ESPN's `highlights`/`summary` links or changing the `Match` model or `ESPNProvider`.
- Any settings/toggle for the feature — it is always on for finished rows.

## Decisions

**1. YouTube search deep-link, composed from team names.**
The destination is `https://www.youtube.com/results?search_query=<home> vs <away> highlights`, with the query percent-encoded via `URLComponents`/`URLQueryItem` (not manual string building) so club names with spaces or accents (`Atlético Madrid`) produce a valid URL. `URLQueryItem` handles the encoding; we let it, rather than hand-rolling `addingPercentEncoding`.
- *Alternative considered — YouTube Data API for the top video:* rejected; needs a key + quota, adds secret management to a menu-bar app for marginal UX gain.
- *Alternative considered — ESPN `highlights` link:* rejected; present only for big matches, and geo-locked playback.

**2. Open via `NSWorkspace.shared.open(_:)`.**
Standard AppKit way to hand a URL to the default browser. No entitlement changes, no async, synchronous fire-and-forget from the button action.

**3. Composition lives in a small, testable helper, not inline in the view.**
Put URL composition in a pure function (e.g. `Match.highlightsSearchURL` or a free function taking home/away names) so it is unit-testable without SwiftUI. The button action calls the helper then `NSWorkspace.open`. This keeps the view thin and the encoding logic verifiable. (Note the environment constraint: tests can't compile without full Xcode, so the helper stays trivially reviewable even if the test target can't run here.)

**4. Inline trailing icon, rendered conditionally.**
Add the control to `MatchRow` after the existing status badge, wrapped in `if match.state == .finished`. Use an SF Symbol such as `play.rectangle` / `play.circle`, `.buttonStyle(.borderless)`, `.secondary` foreground, with a `.help("Watch highlights")` tooltip — matching the existing borderless icon-button idiom (pin, refresh, settings) already in the file.

## Risks / Trade-offs

- **Upload lag** → A match that just went final may have few or no highlight uploads yet. Mitigation: a search page degrades gracefully (shows whatever exists / related clips) rather than a dead end; nothing to block on.
- **Search page, not a guaranteed clip** → user lands on results and picks. Accepted trade-off in exchange for universal coverage and zero keys.
- **YouTube results URL shape could change** → low likelihood; `results?search_query=` has been stable for years, and it is isolated to one helper if it ever needs updating.
- **Row visual density in 320px width** → the icon only appears on finished rows (a subset at any time), and sits in the trailing stack; minimal added clutter.
