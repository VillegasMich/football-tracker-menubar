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
    /// Kicked off but was stopped and not completed. Keeps the score from
    /// when play stopped.
    case abandoned

    /// Our own word for a status, shown in place of the Primary Source's
    /// detail: "Postponed", "Cancelled" (the Primary Source spells it
    /// "Canceled") or "Abandoned" (the Primary Source's `ABN` or `Susp`).
    /// `nil` for every other status.
    var statusWord: String? {
        switch self {
        case .postponed: return "Postponed"
        case .cancelled: return "Cancelled"
        case .abandoned: return "Abandoned"
        case .upcoming, .inProgress, .finished: return nil
        }
    }

    /// Maps an ESPN status type to a `MatchState`. The one place this mapping
    /// lives:
    /// - `STATUS_POSTPONED` → Postponed; `STATUS_CANCELED` → Cancelled. Both
    ///   arrive with state `post` and `completed: false`.
    /// - state `in` → Live for every other name, `STATUS_SUSPENDED` included,
    ///   so a Match that resumes after a stoppage is Live again.
    /// - `STATUS_ABANDONED` or `STATUS_SUSPENDED` in state `post` → Abandoned.
    ///   Both arrive with `completed: false` and the score from when play
    ///   stopped: a stopped Match that has not resumed counts as Abandoned.
    /// - state `post` → Finished only with `completed: true`.
    /// - anything else, including an unknown name in state `post`, →
    ///   Upcoming, so a shape change never crashes the app or drops a Match.
    init(espnName: String?, state: String, completed: Bool?) {
        switch (espnName, state, completed) {
        case ("STATUS_POSTPONED", _, _): self = .postponed
        case ("STATUS_CANCELED", _, _): self = .cancelled
        case (_, "in", _): self = .inProgress
        case ("STATUS_ABANDONED", "post", _), ("STATUS_SUSPENDED", "post", _): self = .abandoned
        case (_, "post", true?): self = .finished
        default: self = .upcoming
        }
    }
}
