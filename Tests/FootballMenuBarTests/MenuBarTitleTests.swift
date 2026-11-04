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

    @Test("Postponed and Cancelled Matches show the status word in place of the score",
          arguments: [
              (MatchState.postponed, "Postponed", "ARS Postponed CHE"),
              (.cancelled, "Canceled", "ARS Cancelled CHE"),
          ])
    func postponedAndCancelledShowStatusWord(state: MatchState, primarySourceDetail: String, title: String) {
        let match = makeMatch(state: state, statusDetail: primarySourceDetail, score: Score(home: 0, away: 0))

        #expect(MenuBarTitle.text(for: match) == title)
    }

    @Test("An Abandoned Match shows its partial score, then (Abd) after the away abbreviation")
    func abandonedShowsScoreAndAbd() {
        let match = makeMatch(state: .abandoned, statusDetail: "ABN", score: Score(home: 1, away: 0))

        #expect(MenuBarTitle.text(for: match) == "ARS 1 – 0 CHE (Abd)")
    }

    @Test("A Match decided by a Penalty Shootout shows the Match score, then the shootout result after the away abbreviation")
    func penaltyShootoutShowsScoreAndResult() {
        // The 2026 Champions League final: Paris Saint-Germain 1–1 Arsenal,
        // Paris Saint-Germain won the Penalty Shootout 4–3.
        let match = makeMatch(state: .finished, statusDetail: "FT-Pens",
                              score: Score(home: 1, away: 1),
                              penaltyShootout: PenaltyShootout(home: 4, away: 3),
                              home: paris, away: arsenal)

        #expect(MenuBarTitle.text(for: match) == "PSG 1 – 1 ARS (4–3p)")
    }

    @Test("The logo-mode title shows a Penalty Shootout Match's score, then the shootout result after the away team")
    func logoModePenaltyShootout() {
        let match = makeMatch(state: .finished, statusDetail: "FT-Pens",
                              score: Score(home: 1, away: 1),
                              penaltyShootout: PenaltyShootout(home: 4, away: 3),
                              home: paris, away: arsenal)

        #expect(MenuBarTitle.middle(for: match) == "1 – 1")
        #expect(MenuBarTitle.suffix(for: match) == "(4–3p)")
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

    @Test("The logo-mode title shows the status word for Postponed and Cancelled Matches",
          arguments: [
              (MatchState.postponed, "Postponed", "Postponed"),
              (.cancelled, "Canceled", "Cancelled"),
          ])
    func logoModeMiddleSegmentPostponedAndCancelled(state: MatchState, primarySourceDetail: String,
                                                    middle: String) {
        let match = makeMatch(state: state, statusDetail: primarySourceDetail)

        #expect(MenuBarTitle.middle(for: match) == middle)
    }

    @Test("The logo-mode title shows an Abandoned Match's partial score, then (Abd) after the away team")
    func logoModeAbandoned() {
        let match = makeMatch(state: .abandoned, statusDetail: "ABN", score: Score(home: 1, away: 0))

        #expect(MenuBarTitle.middle(for: match) == "1 – 0")
        #expect(MenuBarTitle.suffix(for: match) == "(Abd)")
    }

    @Test("Without a Penalty Shootout, only an Abandoned Match has a title suffix",
          arguments: [MatchState.upcoming, .inProgress, .finished, .postponed, .cancelled])
    func noSuffixOtherwise(state: MatchState) {
        let match = makeMatch(state: state, statusDetail: "")

        #expect(MenuBarTitle.suffix(for: match) == nil)
    }
}
