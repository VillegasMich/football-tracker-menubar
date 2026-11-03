import Foundation

/// High-level lifecycle of a match, derived from ESPN's per-event
/// `status.type` (its `name`, coarse `state` and `completed` flag).
enum MatchState: String, Codable, Sendable {
    case upcoming
    case inProgress
    case finished
    /// Moved to a later, possibly unknown, date without being played.
    case postponed
    /// Will not be played at all.
    case cancelled

    /// Maps an ESPN status type to a `MatchState`. The one place this mapping
    /// lives:
    /// - `STATUS_POSTPONED` → Postponed; `STATUS_CANCELED` → Cancelled. Both
    ///   arrive with state `post` and `completed: false`.
    /// - state `post` → Finished only with `completed: true`.
    /// - state `in` → Live.
    /// - anything else, including an unknown name in state `post`, →
    ///   Upcoming, so a shape change never crashes the app or drops a Match.
    init(espnName: String?, state: String, completed: Bool?) {
        switch (espnName, state, completed) {
        case ("STATUS_POSTPONED", _, _): self = .postponed
        case ("STATUS_CANCELED", _, _): self = .cancelled
        case (_, "in", _): self = .inProgress
        case (_, "post", true?): self = .finished
        default: self = .upcoming
        }
    }
}
