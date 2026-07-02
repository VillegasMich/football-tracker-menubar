## Context

The app is a SwiftUI `MenuBarExtra` executable (Swift 6, SPM, `.accessory` activation policy — menu bar only, no Dock icon). Today it renders a placeholder `Refresh`/`Quit` menu with no data. AGENTS.md sets the conventions this design follows: Codable value types, async/await + `URLSession`, no third-party dependencies, an observable store injected via the SwiftUI environment, and persistence of user choices where relevant.

Three product decisions were settled during exploration and are the basis for this design: (1) the data provider, (2) the v1 league set, and (3) the refresh cadence. This document records the reasoning so it survives the change.

## Goals / Non-Goals

**Goals:**
- Fetch live + upcoming matches for a small fixed league set and show them, glanceably, in the menu bar.
- Auto-refresh fast while matches are live, and back off when nothing is playing.
- Isolate the (unofficial) data source behind a protocol so it can be swapped or given a fallback without touching the store or views.
- Land a working vertical slice — one live World Cup score in the menu bar — before building any settings UI.

**Non-Goals (v1):**
- A user-facing league picker. Leagues are hardcoded; a selection UI is a follow-up.
- A second provider (football-data.org) implementation. The protocol is designed for it, but no fallback code ships in v1.
- Match detail views, notifications, standings/tables, or per-event timelines. Scores and status only.
- Second-by-second accuracy guarantees. Near-real-time via polling is the target.

## Decisions

### Decision 1: ESPN's unofficial scoreboard API as the live source
Use `https://site.api.espn.com/apis/site/v2/sports/soccer/{slug}/scoreboard`.

Rationale:
- **Free, no signup, no API key** → eliminates the "how is the key supplied/stored" open question entirely.
- **Genuinely real-time**, which is the stated priority.
- **No practical rate ceiling** for a single-user polling client (be polite).

Alternatives considered:
- **football-data.org** — official, well-documented, stable contract, and can fetch all leagues in one `/matches` call. But its free tier delays real-time livescores behind a €12/mo add-on — it is weakest on exactly the axis we care about. Kept as the intended **future fallback** (see Decision 4).
- **API-Football** — best breadth (1,200+ leagues) and true in-play events, but the free tier is capped at **100 requests/day**, which cannot sustain live polling. Ruled out.

### Decision 2: `MatchDataProvider` protocol as the seam
All match data flows through a protocol, e.g.:

```
protocol MatchDataProvider {
    func matches(for leagues: [League]) async throws -> [Match]
}
```

`ESPNProvider` is the sole v1 implementation. The store depends on the protocol, never on ESPN directly. This is the containment boundary for ESPN's unofficial-endpoint risk and the drop-in point for the football-data.org fallback later.

### Decision 3: State-driven refresh cadence
ESPN returns a per-event `state` of `pre` / `in` / `post`. The store derives its polling interval from the matches it holds:

```
        any selected match `in`?
            │
      yes ──┴── no
      ▼         ▼
   LIVE       IDLE
   ~30–60s    ~5–15 min
```

No separate schedule to maintain — the data the app already fetches drives the cadence. Refresh runs as an async task loop keyed off the current mode; the mode is recomputed after every fetch.

### Decision 4: League set is a hardcoded slug table (v1)
A `League` value type carries an ESPN slug and a display name. v1 ships three: `fifa.world` (World Cup — priority, live now), `eng.1` (Premier League), `uefa.champions` (Champions League). Each league = one scoreboard call; the store fetches them concurrently and merges. Making the set user-selectable is a later change that only swaps the source of the league array (hardcoded → persisted selection).

### Decision 5: `.window` menu bar style
Switch `MenuBarExtra` from `.menu` to `.menuBarExtraStyle(.window)` so the dropdown can host a scrollable SwiftUI match list grouped by league, rather than flat menu items. The menu bar label stays the ⚽ icon.

## Risks / Trade-offs

- **ESPN endpoint is unofficial and unversioned; its JSON shape can change without notice.** → Confine all ESPN-specific parsing to `ESPNProvider` behind `MatchDataProvider`; a parse failure surfaces as a clean error the store can show, and the football-data.org fallback slots in without touching store/views.
- **Per-league fan-out (N calls per poll).** → With a 3-league v1 and polite intervals this is trivial; fetch concurrently. If the league set grows large, revisit (football-data.org's single-call model becomes attractive).
- **Off-season leagues return empty scoreboards.** → Expected and correct; the UI must render an "no matches" / next-fixture state gracefully rather than assuming data.
- **Polling drains nothing meaningful, but a tight LIVE interval on a laptop is wasteful when the popover is closed.** → Acceptable for v1; a future optimization could slow polling further when the popover isn't open.

## Open Questions

1. **Leagues hardcoded vs. user-selectable.** v1 is hardcoded (Decision 4). When the picker lands, selected leagues persist to `UserDefaults`; the store already consumes a `[League]`, so only its source changes. Deferred.
2. **Fallback trigger to football-data.org.** Manual (a setting) vs. automatic (on repeated ESPN parse/network failure)? Design note only — no fallback code in v1. Leaning automatic-on-failure so the app self-heals if ESPN breaks, but undecided.
