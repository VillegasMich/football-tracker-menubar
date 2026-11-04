import Foundation
import Testing
@testable import FootballMenuBar

@Suite("Primary Source decoding")
struct ESPNProviderTests {
    @Test("A Finished Match decodes with its teams, score, status and kickoff")
    func finishedMatch() async throws {
        // Premier League, 1 Nov 2026: Liverpool 0–1 Arsenal, full time.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: premierLeague, on: localDay(2026, 11, 1))

        let match = try #require(matches.only)
        #expect(match.id == "401879246")
        #expect(match.competitionSlug == "eng.1")
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

        let matches = try await provider.matches(in: faCupQualifying, on: localDay(2026, 8, 11))

        let match = try #require(matches.first { $0.id == "401906752" })
        #expect(match.state == .postponed)
    }

    @Test("A Cancelled Match decodes as Cancelled, not Finished")
    func cancelledMatch() async throws {
        // FA Cup qualifying, 8 Aug 2026: Boro Rangers at Marske United,
        // `STATUS_CANCELED` with state `post` and `completed: false`.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: faCupQualifying, on: localDay(2026, 8, 8))

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

        let matches = try await provider.matches(in: peruLiga1, on: localDay(2025, 11, 8))

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

        let matches = try await provider.matches(in: nationalLeague, on: localDay(2026, 12, 15))

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

        let matches = try await provider.matches(in: editedStatus, on: localDay(2026, 12, 15))

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

        let matches = try await provider.matches(in: faCupQualifying, on: localDay(2026, 8, 11))

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

        let matches = try await provider.matches(in: championsLeague, on: localDay(2026, 5, 30))

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

        let matches = try await provider.matches(in: faCupQualifying, on: localDay(2026, 8, 11))

        let match = try #require(matches.first { $0.id == "401906755" })
        #expect(match.penaltyShootout == nil)
    }

    @Test("Upcoming Matches whose kickoff the Primary Source hasn't confirmed decode with an unconfirmed kickoff")
    func unconfirmedKickoffs() async throws {
        // Carabao Cup quarter-finals, 15 Dec 2026: Crystal Palace v Sunderland,
        // Fleetwood Town v Everton, Liverpool v AFC Bournemouth and Manchester
        // City v Bradford City, all at a nominal 20:00Z with `timeValid: false`
        // and shortDetail `TBD`.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: carabaoCup, on: localDay(2026, 12, 15))

        #expect(Set(matches.map(\.id)) == ["401932163", "401932186", "401932187", "401932185"])
        for match in matches {
            #expect(match.state == .upcoming)
            #expect(!match.isKickoffConfirmed)
        }
        let liverpool = try #require(matches.first { $0.id == "401932187" })
        #expect(liverpool.home.name == "Liverpool")
        #expect(liverpool.away.name == "AFC Bournemouth")
    }

    @Test("A Match whose teams are both placeholders produces no Match")
    func bothPlaceholderTeamsDropped() async throws {
        // Coppa Italia, 3 Feb 2027: four quarter-finals, each `TBD Home`
        // (team id 131556) v `TBD Away` (team id 131554), `timeValid: false`.
        // No real day mixes these with a real Match; see the edited fixture
        // below for that.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: coppaItalia, on: localDay(2027, 2, 3))

        #expect(matches.isEmpty)
    }

    @Test("A Match with one placeholder team is kept, while both-placeholder Matches in the same response are dropped")
    func onePlaceholderTeamKept() async throws {
        // EDITED fixture, not a verbatim response: the real Coppa Italia
        // response above (3 Feb 2027) with only Match 401912254's home
        // competitor (`TBD Home`) replaced by AS Roma's, copied from the real
        // Coppa Italia Match 401912496. The other three Matches are unchanged.
        // No real one-placeholder Match has been observed.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: editedTeams, on: localDay(2027, 2, 3))

        let match = try #require(matches.only)
        #expect(match.id == "401912254")
        #expect(match.home.name == "AS Roma")
        #expect(match.state == .upcoming)
        #expect(!match.isKickoffConfirmed)
    }

    @Test("A Match's single placeholder team shows as plain TBD, not the Primary Source's TBD Away")
    func singlePlaceholderTeamIsTBD() async throws {
        // Same EDITED fixture as above: AS Roma v the Primary Source's
        // placeholder `TBD Away` (team id 131554, abbreviation `TBD Away`,
        // empty logo).
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: editedTeams, on: localDay(2027, 2, 3))

        let match = try #require(matches.only)
        #expect(match.away == Team(id: "131554", name: "TBD", abbreviation: "TBD", logoURL: nil))
        #expect(match.home == Team(id: "104", name: "AS Roma", abbreviation: "ROMA",
                                   logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/104.png")))
    }

    @Test("A kickoff the Primary Source has confirmed decodes as confirmed")
    func confirmedKickoff() async throws {
        // Premier League, 1 Nov 2026: Liverpool 0–1 Arsenal, `timeValid: true`.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: premierLeague, on: localDay(2026, 11, 1))

        let match = try #require(matches.only)
        #expect(match.isKickoffConfirmed)
    }

    @Test("A kickoff without the Primary Source's confirmation flag counts as confirmed")
    func kickoffWithoutFlagIsConfirmed() async throws {
        // EDITED fixture, not a verbatim response: the real Premier League
        // response above (Liverpool 0–1 Arsenal, 1 Nov 2026) with only the
        // competition's `timeValid` flag removed. Every real response seen so
        // far carries the flag.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: editedKickoff, on: localDay(2026, 11, 1))

        let match = try #require(matches.only)
        #expect(match.id == "401879246")
        #expect(match.isKickoffConfirmed)
    }

    @Test("A Match with an unrecognised status name is kept and decodes as Upcoming, not Finished")
    func unrecognisedStatusName() async throws {
        // EDITED fixture, not a verbatim response: the real Postponed Match
        // above (Kidsgrove Athletic at Abbey Hulton United, 11 Aug 2026) with
        // only `status.type.name` changed to the invented
        // `STATUS_UNRECOGNISED_EDITED_FOR_TEST`. State stays `post` and
        // `completed` stays false. No real unknown name has been observed.
        let provider = ESPNProvider(session: .espnFixtures)

        let matches = try await provider.matches(in: editedStatus, on: localDay(2026, 8, 11))

        let match = try #require(matches.only)
        #expect(match.id == "401906752")
        #expect(match.state == .upcoming)
    }

    @Test("In one call, a Competition that loads succeeds while one that fails is reported as failed")
    func perCompetitionOutcome() async throws {
        // Premier League has a saved response for 1 Nov 2026; the Champions
        // League has none, so the stub answers it with HTTP 404.
        let provider = ESPNProvider(session: .espnFixtures)

        let results = await provider.matches(for: [premierLeague, championsLeague],
                                              on: localDay(2026, 11, 1))

        #expect(results.count == 2)
        let premierLeagueMatches = try #require(try results[premierLeague.slug]?.get())
        #expect(premierLeagueMatches.map(\.id) == ["401879246"])
        let championsLeagueResult = try #require(results[championsLeague.slug])
        guard case .failure(.badResponse(status: 404)) = championsLeagueResult else {
            Issue.record("Expected a 404 failure, got \(championsLeagueResult)")
            return
        }
    }

    @Test("Every scoreboard request asks for up to 1000 Matches")
    func requestsAskForUpTo1000Matches() async {
        // Without `limit`, the Primary Source returns at most 100 events.
        let log = RequestLog()
        let provider = ESPNProvider(session: .espnFixtures(recordingInto: log))

        _ = await provider.matches(for: [premierLeague, championsLeague], on: localDay(2026, 11, 1))

        let limits = log.urls.map { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "limit" }?.value
        }
        #expect(limits == ["1000", "1000"])
    }
}

private let premierLeague = Competition(slug: "eng.1", displayName: "Premier League")
private let faCupQualifying = Competition(slug: "eng.fa_qual", displayName: "FA Cup Qualifying")
private let peruLiga1 = Competition(slug: "per.1", displayName: "Liga 1 (Peru)")
private let championsLeague = Competition(slug: "uefa.champions", displayName: "Champions League")
private let nationalLeague = Competition(slug: "eng.5", displayName: "National League")
private let carabaoCup = Competition(slug: "eng.league_cup", displayName: "Carabao Cup")
private let coppaItalia = Competition(slug: "ita.coppa_italia", displayName: "Coppa Italia")
/// Test-only slug serving fixtures edited from real responses.
private let editedStatus = Competition(slug: "test.edited-status", displayName: "Edited status (test only)")
/// Test-only slug serving a real response with one placeholder team replaced.
private let editedTeams = Competition(slug: "test.edited-teams", displayName: "Edited teams (test only)")
/// Test-only slug serving a real response with its `timeValid` flag removed.
private let editedKickoff = Competition(slug: "test.edited-kickoff", displayName: "Edited kickoff (test only)")

fileprivate extension Array {
    /// The single element, or `nil` when there are zero or several.
    var only: Element? { count == 1 ? first : nil }
}
