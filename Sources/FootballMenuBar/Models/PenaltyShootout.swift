import Foundation

/// One side of a Match.
enum Side: String, Codable, Hashable, Sendable {
    case home
    case away
}

/// The result of a Penalty Shootout: the kicks each team scored. Kept apart
/// from the Match score, which shootout kicks never change.
struct PenaltyShootout: Codable, Hashable, Sendable {
    let home: Int
    let away: Int

    /// The side that scored more kicks, or `nil` while level.
    var winner: Side? {
        if home > away { return .home }
        if away > home { return .away }
        return nil
    }
}
