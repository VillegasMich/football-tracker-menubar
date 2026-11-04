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

    /// The word shown in place of a score for a Match that was never played:
    /// "Postponed" or "Cancelled" (the Primary Source spells it "Canceled").
    /// `nil` for every other status.
    var unplayedStatusWord: String? {
        switch self {
        case .postponed: return "Postponed"
        case .cancelled: return "Cancelled"
        case .upcoming, .inProgress, .finished, .abandoned: return nil
        }
    }

    /// Maps an ESPN status type to a `MatchState`. The one place this mapping
    /// lives:
    /// - `STATUS_POSTPONED` → Postponed; `STATUS_CANCELED` → Cancelled. Both
    ///   arrive with state `post` and `completed: false`.
    /// - state `in` → Live, whatever the name, so a suspended Match that
    ///   resumes is Live again.
    /// - `STATUS_ABANDONED` or `STATUS_SUSPENDED` in state `post` → Abandoned.
    ///   Both arrive with `completed: false` and the score from when play
    ///   stopped. A suspended Match the Primary Source has stopped, and not
    ///   yet resumed, counts as Abandoned.
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
