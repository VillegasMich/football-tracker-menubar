/// How a Competition's Matches for the browsed day stand after the latest
/// fetch.
enum CompetitionLoadStatus: Equatable, Sendable {
    /// The latest fetch succeeded.
    case loaded
    /// The latest fetch failed; the Matches from the last successful fetch
    /// that day are still shown.
    case stale
    /// The latest fetch failed and there are no Matches for that day to show.
    case failedToLoad
}
