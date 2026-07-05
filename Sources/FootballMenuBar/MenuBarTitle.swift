import Foundation

/// Builds the menu bar title text for the pinned match. Pure and testable:
/// state formatting lives here, isolated from SwiftUI. Returns `nil` when the
/// caller should fall back to the ⚽ soccerball (no pin, or pinned match absent
/// from the feed).
enum MenuBarTitle {
    /// Short, locale/timezone-aware kickoff time formatter (e.g. `7:00 PM`).
    private static let kickoffFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    /// Title for the pinned match, or `nil` when there is nothing to show.
    /// - live / finished: `"ARS 1 – 0 CHE"` (abbreviations + score)
    /// - upcoming: `"ARS 7:00 PM CHE"` (abbreviations + kickoff time)
    ///
    /// `abbreviation` resolves each team's displayed abbreviation, so callers can
    /// route it through the per-team overrides. Defaults to the team's own
    /// abbreviation, keeping this function pure and independently testable.
    static func text(for match: Match?,
                     abbreviation: (Team) -> String = { $0.abbreviation }) -> String? {
        guard let match else { return nil }
        let home = abbreviation(match.home).uppercased()
        let away = abbreviation(match.away).uppercased()
        return "\(home) \(middle(for: match)) \(away)"
    }

    /// The state-dependent middle segment shared by the text title and the
    /// logo-mode title: the score while in-progress/finished, the kickoff time
    /// while upcoming.
    static func middle(for match: Match) -> String {
        switch match.state {
        case .upcoming:
            return kickoffFormatter.string(from: match.kickoff)
        case .inProgress, .finished:
            return match.score.display
        }
    }
}
