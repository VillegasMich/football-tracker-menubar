## 1. Data model & provider (logos)

- [ ] 1.1 Add `let logoURL: URL?` to `Team` (Models/Team.swift), keeping it `Codable`/`Hashable`/`Sendable`
- [ ] 1.2 Decode ESPN's team `logo` field in `ESPNProvider`'s `TeamDTO` and map it to `URL(string:)` when building `Team` (both home and away)
- [ ] 1.3 Confirm a missing/invalid `logo` yields `logoURL == nil` without failing decode

## 2. Pin state in MatchStore

- [ ] 2.1 Add `@Published private(set) var pinnedMatchID: String?`, loaded from `UserDefaults` on init under a single key
- [ ] 2.2 Add `pin(_:)`, `unpin()`, `togglePin(_:)` methods that update `pinnedMatchID` and persist to `UserDefaults`
- [ ] 2.3 Add derived `var pinnedMatch: Match?` resolving `pinnedMatchID` against current `matches` (nil when absent)
- [ ] 2.4 Extend the cadence decision to use LIVE mode when `hasLiveMatch` OR the pinned match is `.upcoming` and kicks off today (add a `pinnedUpcomingKicksOffToday` helper)

## 3. Menu bar title

- [ ] 3.1 Add a pure helper mapping a pinned `Match?` to an optional title string — `"ABBR score ABBR"` for live/finished, `"ABBR kickoffTime ABBR"` for upcoming, `nil` when no pin/absent
- [ ] 3.2 Format the upcoming kickoff time via a shared formatter in the user's locale/timezone (short time)

## 4. App scene wiring (observation)

- [ ] 4.1 Own `MatchStore` in `FootballMenuBarApp` via `@StateObject`; hand the same instance to `AppDelegate` for `start()`/`stop()` lifecycle
- [ ] 4.2 Make the `MenuBarExtra` label read `store.pinnedMatch`: render `Text(title)` when the helper returns a string, else `Image(systemName: "soccerball")`
- [ ] 4.3 Inject the same store instance into `MatchListView` with `.environmentObject(store)`
- [ ] 4.4 Verify polling still starts on launch and stops on terminate with the popover closed

## 5. Popover rows (logos + pin control)

- [ ] 5.1 Add a `@MainActor` in-memory `ImageCache` (`[URL: NSImage]`) that loads a logo once and reuses it
- [ ] 5.2 Add a `TeamLogoView` that shows the cached logo at row size, falling back to `Text(team.abbreviation.uppercased())` on nil URL or load failure
- [ ] 5.3 Update `MatchRow` to show each team's `TeamLogoView` alongside the team name
- [ ] 5.4 Add a pin/unpin control to `MatchRow` that calls `store.togglePin(match)` and shows a pinned (active) state when `match.id == store.pinnedMatchID`

## 6. Verify

- [ ] 6.1 `swift build` succeeds; `swift run` shows logos in rows with abbreviation fallback where logos are missing
- [ ] 6.2 Pinning a match updates the menu bar title; the title updates on refresh; unpinning restores ⚽
- [ ] 6.3 Pin survives quit/relaunch (persisted); a pinned match that rolls out of the feed falls back to ⚽
