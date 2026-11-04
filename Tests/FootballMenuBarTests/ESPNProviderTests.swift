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

    @Test("A Postponed Match decodes as Postponed, not Finished")
    func postponedMatch() async throws {
        // FA Cup qualifying, 11 Aug 2026: Kidsgrove Athletic at Abbey Hulton
        // United, `STATUS_POSTPONED` with state `post` and `completed: false`.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [faCupQualifying], on: localDay(2026, 8, 11))

        let match = try #require(matches.first { $0.id == "401906752" })
        #expect(match.state == .postponed)
    }

    @Test("A Cancelled Match decodes as Cancelled, not Finished")
    func cancelledMatch() async throws {
        // FA Cup qualifying, 8 Aug 2026: Boro Rangers at Marske United,
        // `STATUS_CANCELED` with state `post` and `completed: false`.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [faCupQualifying], on: localDay(2026, 8, 8))

        let match = try #require(matches.only)
        #expect(match.id == "401890832")
        #expect(match.state == .cancelled)
    }

    @Test("An Abandoned Match decodes as Abandoned with the score from when play stopped")
    func abandonedMatch() async throws {
        // Liga 1 (Peru), 8 Nov 2025: Ayacucho FC 1–0 Comerciantes Unidos,
        // stopped at 90'+5' (`STATUS_ABANDONED`, state `post`,
        // `completed: false`, shortDetail `ABN`).
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [peruLiga1], on: localDay(2025, 11, 8))

        let match = try #require(matches.only)
        #expect(match.id == "760180")
        #expect(match.state == .abandoned)
        #expect(match.score == Score(home: 1, away: 0))
    }

    @Test("A stopped Match that has not resumed (`STATUS_SUSPENDED`) decodes as Abandoned with its partial score")
    func stoppedNotResumedMatch() async throws {
        // National League, dated 15 Dec 2026: Barrow 1–0 Forest Green Rovers,
        // stopped at 18' (`STATUS_SUSPENDED`, state `post`, `completed: false`,
        // shortDetail `Susp`).
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [nationalLeague], on: localDay(2026, 12, 15))

        let match = try #require(matches.only)
        #expect(match.id == "401889241")
        #expect(match.state == .abandoned)
        #expect(match.score == Score(home: 1, away: 0))
    }

    @Test("A stopped Match that has resumed (`STATUS_SUSPENDED` in state `in`) decodes as Live")
    func resumedMatch() async throws {
        // EDITED fixture, not a verbatim response: the real stopped Match
        // above (Barrow 1–0 Forest Green Rovers, 15 Dec 2026) with only the
        // event's `status.type.state` changed from `post` to `in`. The name
        // stays `STATUS_SUSPENDED`. No real resumed Match has been observed.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [editedStatus], on: localDay(2026, 12, 15))

        let match = try #require(matches.only)
        #expect(match.id == "401889241")
        #expect(match.state == .inProgress)
        #expect(match.score == Score(home: 1, away: 0))
    }

    @Test("A Match that went to extra time still decodes as Finished")
    func extraTimeMatch() async throws {
        // FA Cup qualifying, 11 Aug 2026: Worcester Raiders at Ashby Ivanhoe,
        // 3–1 after extra time (`STATUS_FINAL_AET`, `completed: true`).
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [faCupQualifying], on: localDay(2026, 8, 11))

        let match = try #require(matches.first { $0.id == "401906755" })
        #expect(match.state == .finished)
        #expect(match.score == Score(home: 3, away: 1))
        #expect(match.statusDetail == "AET")
    }

    @Test("A Match decided by a Penalty Shootout keeps its Match score and carries the shootout result apart")
    func penaltyShootoutMatch() async throws {
        // Champions League final, 30 May 2026: Paris Saint-Germain 1–1
        // Arsenal after extra time, Paris Saint-Germain won the Penalty Shootout 4–3
        // (`STATUS_FINAL_PEN`, shortDetail `FT-Pens`, `shootoutScore` 4 and 3).
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [championsLeague], on: localDay(2026, 5, 30))

        let match = try #require(matches.only)
        #expect(match.id == "401862897")
        #expect(match.home.name == "Paris Saint-Germain")
        #expect(match.away.name == "Arsenal")
        #expect(match.state == .finished)
        #expect(match.score == Score(home: 1, away: 1))
        #expect(match.penaltyShootout == PenaltyShootout(home: 4, away: 3))
        #expect(match.penaltyShootout?.winner == .home)
    }

    @Test("A Match that went to extra time without a Penalty Shootout has no Penalty Shootout result")
    func extraTimeMatchHasNoPenaltyShootout() async throws {
        // FA Cup qualifying, 11 Aug 2026: Worcester Raiders at Ashby Ivanhoe,
        // 3–1 after extra time, no `shootoutScore` on either competitor.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [faCupQualifying], on: localDay(2026, 8, 11))

        let match = try #require(matches.first { $0.id == "401906755" })
        #expect(match.penaltyShootout == nil)
    }

    @Test("A Match with an unrecognised status name is kept and decodes as Upcoming, not Finished")
    func unrecognisedStatusName() async throws {
        // EDITED fixture, not a verbatim response: the real Postponed Match
        // above (Kidsgrove Athletic at Abbey Hulton United, 11 Aug 2026) with
        // only `status.type.name` changed to the invented
        // `STATUS_UNRECOGNISED_EDITED_FOR_TEST`. State stays `post` and
        // `completed` stays false. No real unknown name has been observed.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(for: [editedStatus], on: localDay(2026, 8, 11))

        let match = try #require(matches.only)
        #expect(match.id == "401906752")
        #expect(match.state == .upcoming)
    }
}

private let premierLeague = League(slug: "eng.1", displayName: "Premier League")
private let faCupQualifying = League(slug: "eng.fa_qual", displayName: "FA Cup Qualifying")
private let peruLiga1 = League(slug: "per.1", displayName: "Liga 1 (Peru)")
private let championsLeague = League(slug: "uefa.champions", displayName: "Champions League")
private let nationalLeague = League(slug: "eng.5", displayName: "National League")
/// Test-only slug serving fixtures edited from real responses.
private let editedStatus = League(slug: "test.edited-status", displayName: "Edited status (test only)")

fileprivate extension Array {
    /// The single element, or `nil` when there are zero or several.
    var only: Element? { count == 1 ? first : nil }
}
