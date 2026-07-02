## 1. Data model & provider (logos)

- [x] 1.1 Add `let logoURL: URL?` to `Team` (Models/Team.swift), keeping it `Codable`/`Hashable`/`Sendable`
- [x] 1.2 Decode ESPN's team `logo` field in `ESPNProvider`'s `TeamDTO` and map it to `URL(string:)` when building `Team` (both home and away)
- [x] 1.3 Confirm a missing/invalid `logo` yields `logoURL == nil` without failing decode

## 2. Pin state in MatchStore

- [x] 2.1 Add `@Published private(set) var pinnedMatchID: String?`, loaded from `UserDefaults` on init under a single key
- [x] 2.2 Add `pin(_:)`, `unpin()`, `togglePin(_:)` methods that update `pinnedMatchID` and persist to `UserDefaults`
- [x] 2.3 Add derived `var pinnedMatch: Match?` resolving `pinnedMatchID` against current `matches` (nil when absent)
- [x] 2.4 Extend the cadence decision to use LIVE mode when `hasLiveMatch` OR the pinned match is `.upcoming` and kicks off today (add a `pinnedUpcomingKicksOffToday` helper)

## 3. Menu bar title

- [x] 3.1 Add a pure helper mapping a pinned `Match?` to an optional title string — `"ABBR score ABBR"` for live/finished, `"ABBR kickoffTime ABBR"` for upcoming, `nil` when no pin/absent
- [x] 3.2 Format the upcoming kickoff time via a shared formatter in the user's locale/timezone (short time)

## 4. App scene wiring (observation)

- [x] 4.1 Own `MatchStore` in `AppDelegate` (revised from `@StateObject` in the App to avoid a launch-ordering hazard); label observes it via an `@ObservedObject` subview
- [x] 4.2 Make the `MenuBarExtra` label read `store.pinnedMatch`: render `Text(title)` when the helper returns a string, else `Image(systemName: "soccerball")`
- [x] 4.3 Inject the same store instance into `MatchListView` with `.environmentObject(store)`
- [x] 4.4 Verify polling still starts on launch and stops on terminate with the popover closed

## 5. Popover rows (logos + pin control)

- [x] 5.1 Add a `@MainActor` in-memory `ImageCache` (`[URL: NSImage]`) that loads a logo once and reuses it
- [x] 5.2 Add a `TeamLogoView` that shows the cached logo at row size, falling back to `Text(team.abbreviation.uppercased())` on nil URL or load failure
- [x] 5.3 Update `MatchRow` to show each team's `TeamLogoView` alongside the team name
- [x] 5.4 Add a pin/unpin control to `MatchRow` that calls `store.togglePin(match)` and shows a pinned (active) state when `match.id == store.pinnedMatchID`

## 6. Verify

- [x] 6.1 `swift build` succeeds; `swift run` launches without crashing (logo decode wired + compiled; visual rendering to eyeball in the menu bar)
- [x] 6.2 Title logic verified against real code: live/finished show score, upcoming shows kickoff, and the title is a pure function of `pinnedMatch` (updates on refresh); nil → ⚽
- [x] 6.3 Pin persists across a fresh store instance (== relaunch) and falls back to ⚽ when the pinned match is absent from the feed — verified via harness on real sources
