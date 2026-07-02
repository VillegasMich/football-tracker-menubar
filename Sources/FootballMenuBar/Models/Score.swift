import Foundation

/// The current score of a match. ESPN reports each competitor's score as a
/// string; these are the parsed home/away goal counts.
struct Score: Codable, Hashable, Sendable {
    let home: Int
    let away: Int

    var display: String { "\(home) – \(away)" }
}
