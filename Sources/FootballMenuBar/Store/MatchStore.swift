import Foundation
import Combine

/// Observable store that keeps matches current for the selected leagues and
/// auto-refreshes on a cadence driven by live play. Injected into the SwiftUI
/// environment for views to read.
///
/// It maintains two logically separate feeds:
/// - the **browse feed** (`matches`) for `selectedDate`, powering the popover;
/// - the **ticker feed** (`pinnedSnapshot`) for the pinned match, powering the
///   menu bar title independently of which day is browsed.
///
/// Uses `ObservableObject` rather than the `@Observable` macro to keep the
/// macOS 13 deployment floor (the macro requires macOS 14).
@MainActor
final class MatchStore: ObservableObject {
    /// Fast poll while something relevant is in-progress.
    static let liveInterval: UInt64 = 45_000_000_000       // 45s
    /// Lazy poll when nothing is live.
    static let idleInterval: UInt64 = 600_000_000_000      // 10 min

    /// `UserDefaults` keys under which the pin is persisted.
    private static let pinnedMatchIDKey = "pinnedMatchID"
    private static let pinnedMatchDayKey = "pinnedMatchDay"

    /// Persists the pinned match's day as `yyyy-MM-dd` (local) so the ticker can
    /// be restored by re-fetching that day on launch.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Browse feed
    @Published private(set) var matches: [Match] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    /// True while a date step's fetch is in flight — distinct from `isRefreshing`
    /// so the view can keep the prior day's list visible during a step.
    @Published private(set) var isSteppingDate = false
    @Published private(set) var hasLoadedOnce = false
    /// The day currently being browsed; defaults to today, not persisted.
    @Published private(set) var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Ticker feed
    /// Id of the single pinned match, or nil. Persisted so the pin survives
    /// relaunch.
    @Published private(set) var pinnedMatchID: String?
    /// Last-known data for the pinned match — the source of truth for the menu
    /// bar title. `nil` ⇒ the ⚽ fallback.
    @Published private(set) var pinnedSnapshot: Match?
    /// The pinned match's day, used to fetch its ticker feed. `nil` for a legacy
    /// pin with no persisted day (treated as today at restore time).
    private var pinnedMatchDay: Date?

    let leagues: [League]
    private let provider: MatchDataProvider
    private let defaults: UserDefaults
    private var pollingTask: Task<Void, Never>?

    init(provider: MatchDataProvider,
         leagues: [League] = League.supported,
         defaults: UserDefaults = .standard) {
        self.provider = provider
        self.leagues = leagues
        self.defaults = defaults
        self.pinnedMatchID = defaults.string(forKey: Self.pinnedMatchIDKey)
        if let dayString = defaults.string(forKey: Self.pinnedMatchDayKey) {
            self.pinnedMatchDay = Self.dayKeyFormatter.date(from: dayString)
        }
    }

    /// True while at least one browsed match is being played — one of the
    /// reasons to poll on the fast cadence, and it refreshes the browse feed.
    var hasLiveMatch: Bool { matches.contains(where: \.isLive) }

    /// True when the selected day is the current local day.
    var isViewingToday: Bool { Calendar.current.isDate(selectedDate, inSameDayAs: Date()) }

    // MARK: - Pinning

    /// Pin a match, replacing any previously pinned one (single-select). Seeds
    /// the ticker snapshot immediately so the title updates without a fetch.
    func pin(_ match: Match) {
        pinnedMatchID = match.id
        pinnedMatchDay = Calendar.current.startOfDay(for: match.kickoff)
        pinnedSnapshot = match
        persistPin()
    }

    /// Clear the pin, leaving no match pinned.
    func unpin() {
        pinnedMatchID = nil
        pinnedMatchDay = nil
        pinnedSnapshot = nil
        persistPin()
    }

    /// Pin the match if it isn't already pinned, otherwise unpin it.
    func togglePin(_ match: Match) {
        if pinnedMatchID == match.id { unpin() } else { pin(match) }
    }

    private func persistPin() {
        if let id = pinnedMatchID {
            defaults.set(id, forKey: Self.pinnedMatchIDKey)
            if let day = pinnedMatchDay {
                defaults.set(Self.dayKeyFormatter.string(from: day), forKey: Self.pinnedMatchDayKey)
            }
        } else {
            defaults.removeObject(forKey: Self.pinnedMatchIDKey)
            defaults.removeObject(forKey: Self.pinnedMatchDayKey)
        }
    }

    /// True when the pinned match is upcoming and kicks off today — a reason to
    /// poll on the fast cadence so the menu bar title flips to live at kickoff.
    var pinnedUpcomingKicksOffToday: Bool {
        guard let match = pinnedSnapshot, match.state == .upcoming else { return false }
        return Calendar.current.isDateInToday(match.kickoff)
    }

    /// The day whose fetch feeds the ticker: the pinned match's day, or today
    /// for a legacy pin without a persisted day.
    private var pinnedDay: Date {
        pinnedMatchDay ?? Calendar.current.startOfDay(for: Date())
    }

    /// True when the browsed day is the pinned match's day, so a single fetch
    /// serves both feeds (collapse optimization).
    private var pinnedDayIsBrowsed: Bool {
        pinnedMatchID != nil && Calendar.current.isDate(pinnedDay, inSameDayAs: selectedDate)
    }

    // MARK: - Visible matches

    /// Matches to show for the selected day. The browse feed is already scoped
    /// to `selectedDate` by the fetch, so it is shown as-is — which also keeps
    /// the prior day's list visible during a step until the new day replaces it,
    /// rather than flashing empty the moment `selectedDate` changes.
    var visibleMatches: [Match] { matches }

    /// Matches grouped by league in the supported-league order, for display.
    var matchesByLeague: [(league: League, matches: [Match])] {
        let visible = visibleMatches
        return leagues.compactMap { league in
            let group = visible
                .filter { $0.leagueSlug == league.slug }
                .sorted(by: Self.displayOrder)
            return group.isEmpty ? nil : (league, group)
        }
    }

    // MARK: - Date navigation

    /// Step the selected day by `days` (e.g. -1 previous, +1 next) and load it.
    func stepDay(by days: Int) async {
        guard !isSteppingDate else { return }
        let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        selectedDate = newDate
        await stepLoad(newDate)
    }

    /// Return the selected day to today and load it.
    func goToToday() async {
        let today = Calendar.current.startOfDay(for: Date())
        guard !Calendar.current.isDate(selectedDate, inSameDayAs: today) else { return }
        selectedDate = today
        await stepLoad(today)
    }

    private func stepLoad(_ target: Date) async {
        isSteppingDate = true
        defer { isSteppingDate = false }
        await loadBrowse(for: target)
    }

    // MARK: - Refresh loop

    /// Begin the auto-refresh loop: seed the ticker, load the browse feed, then
    /// tick on an interval that depends on whether anything relevant is live.
    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.loadInitial()
            while !Task.isCancelled {
                let interval = self.wantsLiveCadence ? Self.liveInterval : Self.idleInterval
                try? await Task.sleep(nanoseconds: interval)
                if Task.isCancelled { break }
                await self.tick()
            }
        }
    }

    /// Fast (LIVE) cadence applies while the pinned match is in-progress, while
    /// a pinned match is about to kick off today, or while the browsed day has a
    /// live match.
    var wantsLiveCadence: Bool {
        (pinnedSnapshot?.isLive ?? false) || pinnedUpcomingKicksOffToday || hasLiveMatch
    }

    /// One refresh tick: keep the pinned ticker live regardless of the browsed
    /// day, and refresh the browse feed only while the browsed day is live. When
    /// the browsed day is the pinned day, the browse fetch also updates the
    /// snapshot, so the separate ticker fetch is skipped.
    private func tick() async {
        let browseWillRefresh = hasLiveMatch
        if !(browseWillRefresh && pinnedDayIsBrowsed) {
            await refreshTicker()
        }
        if browseWillRefresh {
            await refresh()
        }
    }

    /// Seed the pinned ticker, then load the browse feed for the selected day.
    /// Awaitable so the initial load can be driven directly (e.g. from tests).
    func loadInitial() async {
        await restorePinnedSnapshot()
        await refresh()
    }

    /// Stop the auto-refresh loop (e.g. on quit).
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Fetch the browse feed for the selected day, immediately.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadBrowse(for: selectedDate)
    }

    /// Load the browse feed for `target`. Results are discarded if the selected
    /// day changed while the fetch was in flight (out-of-order guard).
    private func loadBrowse(for target: Date) async {
        do {
            let fetched = try await provider.matches(for: leagues, on: target)
            guard Calendar.current.isDate(target, inSameDayAs: selectedDate) else { return }
            matches = fetched
            errorMessage = nil
            updateSnapshotFromBrowse(fetched)
        } catch {
            guard Calendar.current.isDate(target, inSameDayAs: selectedDate) else { return }
            errorMessage = Self.describe(error)
        }
        hasLoadedOnce = true
    }

    // MARK: - Ticker feed

    /// Restore the pinned ticker on launch by fetching the pinned match's day.
    private func restorePinnedSnapshot() async {
        guard pinnedMatchID != nil else { return }
        await refreshTicker()
    }

    /// Fetch the pinned match's day and update its snapshot. A successful fetch
    /// that no longer contains the pinned id clears the snapshot (⇒ ⚽); a
    /// transient failure keeps the last snapshot.
    private func refreshTicker() async {
        guard let id = pinnedMatchID else { pinnedSnapshot = nil; return }
        do {
            let fetched = try await provider.matches(for: leagues, on: pinnedDay)
            pinnedSnapshot = fetched.first { $0.id == id }
        } catch {
            // Keep the last-known snapshot on a transient failure.
        }
    }

    /// When browsing the pinned match's own day, treat the browse fetch as
    /// authoritative for the snapshot (including clearing it if the match is
    /// absent). When browsing another day, leave the snapshot untouched.
    private func updateSnapshotFromBrowse(_ fetched: [Match]) {
        guard let id = pinnedMatchID, pinnedDayIsBrowsed else { return }
        pinnedSnapshot = fetched.first { $0.id == id }
    }

    // MARK: - Helpers

    /// Live matches first, then upcoming, then finished; within each, by kickoff.
    private static func displayOrder(_ a: Match, _ b: Match) -> Bool {
        func rank(_ s: MatchState) -> Int {
            switch s { case .inProgress: return 0; case .upcoming: return 1; case .finished: return 2 }
        }
        if rank(a.state) != rank(b.state) { return rank(a.state) < rank(b.state) }
        return a.kickoff < b.kickoff
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case MatchDataError.network: return "Couldn't reach the scores service."
        case MatchDataError.decoding: return "Received an unexpected response."
        case MatchDataError.badResponse(let status): return "Scores service error (\(status))."
        default: return "Something went wrong fetching scores."
        }
    }
}
