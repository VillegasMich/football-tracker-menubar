import Foundation
import Testing
@testable import FootballMenuBar

@Suite("Menu bar title")
struct MenuBarTitleTests {
    @Test("No Pinned Match gives no title")
    func noPinnedMatch() {
        #expect(MenuBarTitle.text(for: nil) == nil)
    }

    @Test("An Upcoming Match shows the local kickoff time between the abbreviations")
    func upcomingShowsKickoffTime() {
        // 19:00 UTC on 1 Nov 2026 is 20:00 in Madrid (CET, UTC+1).
        let match = makeMatch(state: .upcoming, statusDetail: "", kickoff: utc("2026-11-01T19:00Z"))

        #expect(MenuBarTitle.text(for: match, locale: britishEnglish, timeZone: madrid) == "ARS 20:00 CHE")
    }

    @Test("A Live Match shows the Match score between the abbreviations")
    func liveShowsScore() {
        let match = makeMatch(state: .inProgress, statusDetail: "63'", score: Score(home: 1, away: 0))

        #expect(MenuBarTitle.text(for: match) == "ARS 1 – 0 CHE")
    }

    @Test("A Finished Match shows the Match score between the abbreviations")
    func finishedShowsScore() {
        let match = makeMatch(state: .finished, statusDetail: "FT", score: Score(home: 2, away: 3))

        #expect(MenuBarTitle.text(for: match) == "ARS 2 – 3 CHE")
    }

    @Test("Abbreviation overrides replace the Primary Source's abbreviations, uppercased")
    func abbreviationOverrides() {
        let match = makeMatch(state: .finished, statusDetail: "FT", score: Score(home: 2, away: 3))
        let overrides = ["359": "gunners"]

        let title = MenuBarTitle.text(for: match) { overrides[$0.id] ?? $0.abbreviation }

        #expect(title == "GUNNERS 2 – 3 CHE")
    }

    @Test("The logo-mode title uses the same middle segment")
    func logoModeMiddleSegment() {
        let live = makeMatch(state: .inProgress, statusDetail: "63'", score: Score(home: 1, away: 0))
        let upcoming = makeMatch(state: .upcoming, statusDetail: "", kickoff: utc("2026-11-01T19:00Z"))

        #expect(MenuBarTitle.middle(for: live) == "1 – 0")
        #expect(MenuBarTitle.middle(for: upcoming, locale: britishEnglish, timeZone: madrid) == "20:00")
    }
}
