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
    static func text(for match: Match?) -> String? {
        guard let match else { return nil }
        let home = match.home.abbreviation.uppercased()
        let away = match.away.abbreviation.uppercased()
        let middle: String
        switch match.state {
        case .upcoming:
            middle = kickoffFormatter.string(from: match.kickoff)
        case .inProgress, .finished:
            middle = match.score.display
        }
        return "\(home) \(middle) \(away)"
    }
}
