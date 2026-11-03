import Foundation
import Testing
@testable import FootballMenuBar

@Suite("Primary Source decoding")
struct ESPNProviderTests {
    @Test("A Finished Match decodes with its teams, score, status and kickoff")
    func finishedMatch() async throws {
        // Premier League, 1 Nov 2026: Liverpool 0–1 Arsenal, full time.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [premierLeague], on: localDay(2026, 11, 1))

        let match = try #require(matches.only)
        #expect(match.id == "401879246")
        #expect(match.leagueSlug == "eng.1")
        #expect(match.home == Team(id: "364", name: "Liverpool", abbreviation: "LIV",
                                   logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/364.png")))
        #expect(match.away == Team(id: "359", name: "Arsenal", abbreviation: "ARS",
                                   logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/359.png")))
        #expect(match.score == Score(home: 0, away: 1))
        #expect(match.state == .finished)
        #expect(match.statusDetail == "FT")
        #expect(match.kickoff == utc("2026-11-01T16:30Z"))
    }
}

private let premierLeague = League(slug: "eng.1", displayName: "Premier League")

fileprivate extension Array {
    /// The single element, or `nil` when there are zero or several.
    var only: Element? { count == 1 ? first : nil }
}
