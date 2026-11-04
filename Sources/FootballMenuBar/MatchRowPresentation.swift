import Foundation

/// What a single Match row in the popover shows. Pure and testable, like
/// `MenuBarTitle`: every display decision lives here, and `MatchRow` only
/// renders the result.
struct MatchRowPresentation {
    /// The score column: a dash, or each team's goals on its own line.
    enum ScoreText: Equatable {
        case dash
        case goals(home: String, away: String)
    }

    /// One side of a Match.
    enum Side: Equatable {
        case home
        case away
    }

    /// Text of the status badge. For Upcoming Matches the Primary Source's
    /// detail is unreliable (often just a date), so the local kickoff time
    /// (e.g. `7:00 PM`) is shown instead when the kickoff is known.
    let badgeText: String
    /// Whether the row uses the Live style (red badge, bold score).
    let isLiveStyle: Bool
    /// The score column.
    let score: ScoreText
    /// The team shown with emphasis, if any. Always `nil` for now; a Penalty
    /// Shootout winner will use it (#7).
    let emphasisedTeam: Side?
    /// Whether the row offers the highlights button.
    let offersHighlights: Bool

    /// - Parameters:
    ///   - locale: formats the kickoff time. Tests pass a fixed one.
    ///   - timeZone: the kickoff time is shown in this zone. Tests pass a fixed one.
    init(match: Match,
         locale: Locale = .autoupdatingCurrent,
         timeZone: TimeZone = .autoupdatingCurrent) {
        isLiveStyle = match.isLive
        emphasisedTeam = nil
        offersHighlights = match.state == .finished
        switch match.state {
        case .upcoming:
            score = .dash
            if match.kickoff != .distantFuture {
                let f = DateFormatter()
                f.locale = locale
                f.timeZone = timeZone
                f.setLocalizedDateFormatFromTemplate("j mm")
                badgeText = f.string(from: match.kickoff)
            } else {
                badgeText = match.statusDetail
            }
        case .inProgress, .finished, .abandoned:
            score = .goals(home: "\(match.score.home)", away: "\(match.score.away)")
            badgeText = match.statusDetail
        case .postponed, .cancelled:
            // Never played, so no score; our own word, not the Primary Source's.
            score = .dash
            badgeText = match.state.unplayedStatusWord ?? match.statusDetail
        }
    }
}
