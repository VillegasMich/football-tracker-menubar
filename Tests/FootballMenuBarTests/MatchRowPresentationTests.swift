import Foundation
import Testing
@testable import FootballMenuBar

@Suite("Match row presentation")
struct MatchRowPresentationTests {
    @Test("An Upcoming Match shows its local kickoff time")
    func upcomingShowsLocalKickoffTime() {
        // 19:00 UTC on 1 Nov 2026 is 20:00 in Madrid (CET, UTC+1).
        let match = makeMatch(state: .upcoming, statusDetail: "Sun, November 1st at 2:00 PM EST",
                              kickoff: utc("2026-11-01T19:00Z"))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == "20:00")
        #expect(!row.isLiveStyle)
    }

    @Test("A Live Match shows the live detail in the Live style")
    func liveShowsLiveDetailInLiveStyle() {
        let match = makeMatch(state: .inProgress, statusDetail: "63'", score: Score(home: 1, away: 0))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == "63'")
        #expect(row.isLiveStyle)
    }

    @Test("An Upcoming Match without a kickoff date shows the Primary Source's detail")
    func upcomingWithoutKickoffShowsDetail() {
        // `.distantFuture` is what decoding yields when the kickoff can't be parsed.
        let match = makeMatch(state: .upcoming, statusDetail: "Sun, November 1st at 2:00 PM EST",
                              kickoff: .distantFuture)

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == "Sun, November 1st at 2:00 PM EST")
        #expect(!row.isLiveStyle)
    }

    @Test("A Finished Match shows the Primary Source's detail, not in the Live style")
    func finishedShowsDetail() {
        let match = makeMatch(state: .finished, statusDetail: "FT", score: Score(home: 2, away: 1))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == "FT")
        #expect(!row.isLiveStyle)
    }

    @Test("An Upcoming Match shows a dash instead of a score")
    func upcomingShowsDash() {
        let match = makeMatch(state: .upcoming, statusDetail: "", score: Score(home: 0, away: 0))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.score == .dash)
    }

    @Test("Live and Finished Matches show the home and away goals",
          arguments: [MatchState.inProgress, .finished])
    func liveAndFinishedShowGoals(state: MatchState) {
        let match = makeMatch(state: state, statusDetail: "", score: Score(home: 2, away: 1))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.score == .goals(home: "2", away: "1"))
    }

    @Test("Only a Finished Match offers highlights",
          arguments: [(MatchState.upcoming, false), (.inProgress, false), (.finished, true)])
    func highlightsOnlyForFinished(state: MatchState, offersHighlights: Bool) {
        let match = makeMatch(state: state, statusDetail: "")

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.offersHighlights == offersHighlights)
    }

    @Test("Postponed and Cancelled Matches show the status word as badge and a dash, with no highlights and not in the Live style",
          arguments: [
              // The Primary Source's own short details, as seen in real responses.
              (MatchState.postponed, "Postponed", "Postponed"),
              (.cancelled, "Canceled", "Cancelled"),
          ])
    func postponedAndCancelled(state: MatchState, primarySourceDetail: String, badge: String) {
        let match = makeMatch(state: state, statusDetail: primarySourceDetail,
                              score: Score(home: 0, away: 0))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == badge)
        #expect(row.score == .dash)
        #expect(!row.offersHighlights)
        #expect(!row.isLiveStyle)
    }

    @Test("An Abandoned Match shows its partial score and an Abandoned badge, with no highlights and not in the Live style")
    func abandoned() {
        // `ABN` is the Primary Source's own short detail, as seen in real responses.
        let match = makeMatch(state: .abandoned, statusDetail: "ABN", score: Score(home: 1, away: 0))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.score == .goals(home: "1", away: "0"))
        #expect(row.badgeText == "Abandoned")
        #expect(!row.offersHighlights)
        #expect(!row.isLiveStyle)
    }

    @Test("A Match decided by a Penalty Shootout shows the shootout result as badge, emphasises the winner and offers highlights")
    func penaltyShootoutWinner() {
        // The 2026 Champions League final: Paris Saint-Germain 1–1 Arsenal,
        // Paris Saint-Germain won the Penalty Shootout 4–3.
        let match = makeMatch(state: .finished, statusDetail: "FT-Pens",
                              score: Score(home: 1, away: 1),
                              penaltyShootout: PenaltyShootout(home: 4, away: 3),
                              home: paris, away: arsenal)

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == "4–3 pens")
        #expect(row.score == .goals(home: "1", away: "1"))
        #expect(row.emphasisedTeam == .home)
        #expect(row.offersHighlights)
        #expect(!row.isLiveStyle)
    }

    @Test("An away win in a Penalty Shootout emphasises the away team, with the badge in home–away order")
    func penaltyShootoutAwayWinner() {
        // Aberdeen B 1–1 Queen's Park, 3 Nov 2026: Queen's Park (away) won
        // the Penalty Shootout 4–2.
        let match = makeMatch(state: .finished, statusDetail: "FT-Pens",
                              score: Score(home: 1, away: 1),
                              penaltyShootout: PenaltyShootout(home: 2, away: 4),
                              home: Team(id: "fixture-home", name: "Aberdeen B", abbreviation: "ABE", logoURL: nil),
                              away: Team(id: "fixture-away", name: "Queen's Park", abbreviation: "QP", logoURL: nil))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == "2–4 pens")
        #expect(row.emphasisedTeam == .away)
    }

    @Test("A Match that went to extra time without a Penalty Shootout still shows AET and emphasises no team")
    func extraTimeWithoutPenalties() {
        let match = makeMatch(state: .finished, statusDetail: "AET", score: Score(home: 3, away: 1))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.badgeText == "AET")
        #expect(row.emphasisedTeam == nil)
        #expect(row.offersHighlights)
    }

    @Test("Without a Penalty Shootout, no team is emphasised", arguments: [MatchState.upcoming, .inProgress, .finished])
    func noTeamEmphasised(state: MatchState) {
        let match = makeMatch(state: state, statusDetail: "", score: Score(home: 3, away: 0))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.emphasisedTeam == nil)
    }
}
