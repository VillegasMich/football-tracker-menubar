import Foundation

/// Builds the menu bar title text for the pinned match. Pure and testable:
/// state formatting lives here, isolated from SwiftUI. Returns `nil` when the
/// caller should fall back to the ⚽ soccerball (no pin, or pinned match absent
/// from the feed).
enum MenuBarTitle {
    /// Title for the pinned match, or `nil` when there is nothing to show.
    /// - live / finished: `"ARS 1 – 0 CHE"` (abbreviations + score)
    /// - upcoming: `"ARS 7:00 PM CHE"` (abbreviations + kickoff time)
    /// - postponed / cancelled: `"ARS Postponed CHE"`, `"ARS Cancelled CHE"`
    ///
    /// `abbreviation` resolves each team's displayed abbreviation, so callers can
    /// route it through the per-team overrides. Defaults to the team's own
    /// abbreviation, keeping this function pure and independently testable.
    /// `locale` and `timeZone` format the kickoff time; tests pass fixed ones.
    static func text(for match: Match?,
                     locale: Locale = .autoupdatingCurrent,
                     timeZone: TimeZone = .autoupdatingCurrent,
                     abbreviation: (Team) -> String = { $0.abbreviation }) -> String? {
        guard let match else { return nil }
        let home = abbreviation(match.home).uppercased()
        let away = abbreviation(match.away).uppercased()
        return "\(home) \(middle(for: match, locale: locale, timeZone: timeZone)) \(away)"
    }

    /// The state-dependent middle segment shared by the text title and the
    /// logo-mode title: the score while in-progress/finished, the kickoff time
    /// while upcoming, and the status word when postponed or cancelled.
    static func middle(for match: Match,
                       locale: Locale = .autoupdatingCurrent,
                       timeZone: TimeZone = .autoupdatingCurrent) -> String {
        switch match.state {
        case .upcoming:
            // Short, locale-aware kickoff time, e.g. `7:00 PM`.
            let f = DateFormatter()
            f.locale = locale
            f.timeZone = timeZone
            f.dateStyle = .none
            f.timeStyle = .short
            return f.string(from: match.kickoff)
        case .inProgress, .finished:
            return match.score.display
        case .postponed, .cancelled:
            return match.state.unplayedStatusWord ?? match.statusDetail
        }
    }
}
