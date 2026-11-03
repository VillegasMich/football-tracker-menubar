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

    @Test("No team is emphasised", arguments: [MatchState.upcoming, .inProgress, .finished])
    func noTeamEmphasised(state: MatchState) {
        let match = makeMatch(state: state, statusDetail: "", score: Score(home: 3, away: 0))

        let row = MatchRowPresentation(match: match, locale: britishEnglish, timeZone: madrid)

        #expect(row.emphasisedTeam == nil)
    }
}
