import Foundation

/// A football competition, keyed by its ESPN scoreboard slug. Each league maps
/// to one scoreboard request: `.../soccer/{slug}/scoreboard`.
struct League: Codable, Identifiable, Hashable, Sendable {
    /// ESPN slug, e.g. `fifa.world`. Doubles as the stable identity.
    let slug: String
    let displayName: String

    var id: String { slug }
}

extension League {
    /// The hardcoded v1 supported-league set. The World Cup is the priority
    /// (live now); the Premier League and Champions League resume in the
    /// autumn. A user-facing picker is a follow-up change.
    static let supported: [League] = [
        League(slug: "fifa.world", displayName: "World Cup"),
        League(slug: "eng.1", displayName: "Premier League"),
        League(slug: "uefa.champions", displayName: "Champions League"),
    ]
}
