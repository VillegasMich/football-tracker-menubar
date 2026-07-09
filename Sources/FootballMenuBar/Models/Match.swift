import Foundation

/// A single fixture: two teams, the score, lifecycle state, a human-readable
/// status detail (kickoff time, live minute, or final result) and kickoff date.
struct Match: Codable, Identifiable, Hashable, Sendable {
    let id: String
    /// ESPN slug of the league this match belongs to (e.g. `fifa.world`).
    let leagueSlug: String
    let home: Team
    let away: Team
    let score: Score
    let state: MatchState
    /// ESPN's short status text, e.g. `"37'"`, `"FT"`, or a kickoff time.
    let statusDetail: String
    let kickoff: Date

    var isLive: Bool { state == .inProgress }

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
