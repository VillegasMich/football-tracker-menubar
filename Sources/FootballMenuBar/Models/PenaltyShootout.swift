import Foundation

/// The result of a Penalty Shootout: the kicks each team scored. Kept apart
/// from the Match score, which shootout kicks never change.
struct PenaltyShootout: Codable, Hashable, Sendable {
    let home: Int
    let away: Int

    /// Kicks scored in home–away order, e.g. `4–3`.
    var display: String { "\(home)–\(away)" }

    /// The side that scored more kicks, or `nil` while level.
    var winner: Side? {
        if home > away { return .home }
        if away > home { return .away }
        return nil
    }
}
