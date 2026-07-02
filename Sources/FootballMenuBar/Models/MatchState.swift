import Foundation

/// High-level lifecycle of a match, derived from ESPN's per-event
/// `status.type.state` values (`pre` / `in` / `post`).
enum MatchState: String, Codable, Sendable {
    case upcoming
    case inProgress
    case finished

    /// Maps an ESPN `state` string to a `MatchState`. Unknown values are
    /// treated as `upcoming` so a shape change never crashes the app.
    init(espnState: String) {
        switch espnState {
        case "in": self = .inProgress
        case "post": self = .finished
        default: self = .upcoming
        }
    }
}
