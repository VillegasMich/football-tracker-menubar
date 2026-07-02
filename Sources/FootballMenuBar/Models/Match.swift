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
}
