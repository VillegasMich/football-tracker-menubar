import Foundation

/// Builds the menu bar title text for the pinned match. Pure and testable:
/// state formatting lives here, isolated from SwiftUI. Returns `nil` when the
/// caller should fall back to the ⚽ soccerball (no pin, or pinned match absent
/// from the feed).
enum MenuBarTitle {
    /// Title for the pinned match, or `nil` when there is nothing to show.
    /// - live / finished: `"ARS 1 – 0 CHE"` (abbreviations + score)
    /// - upcoming: `"ARS 7:00 PM CHE"` (abbreviations + kickoff time), or
    ///   `"ARS TBD CHE"` when the kickoff is unconfirmed
    /// - postponed / cancelled: `"ARS Postponed CHE"`, `"ARS Cancelled CHE"`
    /// - abandoned: `"ARS 1 – 0 CHE (Abd)"` (score from when play stopped)
    /// - finished after a Penalty Shootout: `"PSG 1 – 1 ARS (4–3p)"`
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
        let title = "\(home) \(middle(for: match, locale: locale, timeZone: timeZone)) \(away)"
        guard let suffix = suffix(for: match) else { return title }
        return "\(title) \(suffix)"
    }

    /// The segment after the away team, shared by the text title and the
    /// logo-mode title: `"(Abd)"` for an Abandoned Match, the Penalty
    /// Shootout result in home–away order (e.g. `"(4–3p)"`) for a Finished
    /// Match decided by one, `nil` otherwise.
    static func suffix(for match: Match) -> String? {
        if match.state == .abandoned { return "(Abd)" }
        return match.decidingPenaltyShootout.map { "(\($0.display)p)" }
    }

    /// The state-dependent middle segment shared by the text title and the
    /// logo-mode title: the score while in-progress, finished or abandoned, the
    /// kickoff time while upcoming ("TBD" while that time is unconfirmed), and
    /// the status word when postponed or cancelled.
    static func middle(for match: Match,
                       locale: Locale = .autoupdatingCurrent,
                       timeZone: TimeZone = .autoupdatingCurrent) -> String {
        switch match.state {
        case .upcoming:
            guard match.isKickoffConfirmed else { return Match.unconfirmedKickoffLabel }
            // Short, locale-aware kickoff time, e.g. `7:00 PM`.
            let f = DateFormatter()
            f.locale = locale
            f.timeZone = timeZone
            f.dateStyle = .none
            f.timeStyle = .short
            return f.string(from: match.kickoff)
        case .inProgress, .finished, .abandoned:
            return match.score.display
        case .postponed, .cancelled:
            return match.state.statusWord ?? match.statusDetail
        }
    }
}
