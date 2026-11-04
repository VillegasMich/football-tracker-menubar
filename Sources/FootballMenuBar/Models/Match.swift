import Foundation

/// A single fixture: two teams, the score, lifecycle state, a human-readable
/// status detail (kickoff time, live minute, or final result) and kickoff date.
struct Match: Codable, Identifiable, Hashable, Sendable {
    let id: String
    /// ESPN slug of the league this match belongs to (e.g. `fifa.world`).
    let leagueSlug: String
    let home: Team
    let away: Team
    /// Goals scored in play, extra time included. Never changed by Penalty
    /// Shootout kicks.
    let score: Score
    /// The Penalty Shootout result, if the Match went to one; `nil` otherwise.
    let penaltyShootout: PenaltyShootout?
    let state: MatchState
    /// ESPN's short status text, e.g. `"37'"`, `"FT"`, or a kickoff time.
    let statusDetail: String
    let kickoff: Date
    /// Whether the Primary Source has confirmed the kickoff time. An
    /// unconfirmed kickoff is only a nominal time (e.g. 20:00Z for every
    /// Carabao Cup quarter-final), shown to the user as "TBD".
    let isKickoffConfirmed: Bool

    /// What the user sees for something the Primary Source hasn't decided
    /// yet: an unconfirmed kickoff time, or a placeholder team's name and
    /// abbreviation.
    static let toBeDecidedLabel = "TBD"

    var isLive: Bool { state == .inProgress }

    /// The Penalty Shootout that decided this Match, once it is Finished;
    /// `nil` before then and for every Match without one.
    var decidingPenaltyShootout: PenaltyShootout? {
        state == .finished ? penaltyShootout : nil
    }

    /// A YouTube search URL for this fixture's highlights, e.g.
    /// `https://www.youtube.com/results?search_query=Everton%20vs%20Fulham%20highlights`.
    /// Built with `URLComponents`/`URLQueryItem` so spaces and non-ASCII club
    /// names (e.g. `Atlético Madrid`) are percent-encoded into a valid URL. This
    /// is a search results page, not a specific video, so it works for every
    /// finished fixture without an API key. Force-unwrap is safe: the host is a
    /// constant and `URLQueryItem` encodes the only user-derived input.
    var highlightsSearchURL: URL {
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: "\(home.name) vs \(away.name) highlights")
        ]
        return components.url!
    }
}
