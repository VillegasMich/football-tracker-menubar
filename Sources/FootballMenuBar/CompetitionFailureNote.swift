/// The note shown under a Competition's header in the popover when its latest
/// fetch failed, or `nil` when it loaded. Pure and testable, like
/// `MatchRowPresentation`.
func competitionFailureNote(for status: CompetitionLoadStatus) -> String? {
    switch status {
    case .loaded: return nil
    case .stale: return "Couldn't update, showing last results"
    case .failedToLoad: return "Couldn't load"
    }
}
