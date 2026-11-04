import Foundation
@testable import FootballMenuBar

/// Builds Matches for presentation tests. The defaults are an ordinary
/// Premier League Match between Arsenal and Chelsea; each test overrides only
/// what it cares about.
func makeMatch(state: MatchState,
               statusDetail: String,
               score: Score = Score(home: 0, away: 0),
               penaltyShootout: PenaltyShootout? = nil,
               kickoff: Date = utc("2026-11-01T19:00Z"),
               home: Team = Team(id: "359", name: "Arsenal", abbreviation: "ARS", logoURL: nil),
               away: Team = Team(id: "363", name: "Chelsea", abbreviation: "CHE", logoURL: nil)) -> Match {
    Match(id: "740001",
          leagueSlug: "eng.1",
          home: home,
          away: away,
          score: score,
          penaltyShootout: penaltyShootout,
          state: state,
          statusDetail: statusDetail,
          kickoff: kickoff)
}

/// Parses `yyyy-MM-dd'T'HH:mm'Z'` as a UTC instant.
func utc(_ string: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
    return f.date(from: string)!
}

/// The teams of the 2026 Champions League final, as the Primary Source names them.
let paris = Team(id: "160", name: "Paris Saint-Germain", abbreviation: "PSG", logoURL: nil)
let arsenal = Team(id: "359", name: "Arsenal", abbreviation: "ARS", logoURL: nil)

let madrid = TimeZone(identifier: "Europe/Madrid")!
let britishEnglish = Locale(identifier: "en_GB")
