import Foundation
import Combine

/// Observable store that keeps matches current for the selected leagues and
/// auto-refreshes on a cadence driven by live play. Injected into the SwiftUI
/// environment for views to read.
///
/// Uses `ObservableObject` rather than the `@Observable` macro to keep the
/// macOS 13 deployment floor (the macro requires macOS 14).
@MainActor
final class MatchStore: ObservableObject {
    /// Fast poll while any match is in-progress.
    static let liveInterval: UInt64 = 45_000_000_000       // 45s
    /// Lazy poll when nothing is live.
    static let idleInterval: UInt64 = 600_000_000_000      // 10 min
    /// How many days of upcoming fixtures to show beyond today. `0` = today
    /// only; raise to include near-future fixtures.
    static let upcomingHorizonDays = 0

    /// `UserDefaults` key under which the pinned match id is persisted.
    private static let pinnedMatchIDKey = "pinnedMatchID"

    @Published private(set) var matches: [Match] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasLoadedOnce = false
    /// Id of the single pinned match, or nil. Persisted so the pin survives
    /// relaunch; resolved against `matches` via `pinnedMatch`.
    @Published private(set) var pinnedMatchID: String?

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
    }

    /// True while at least one match is being played — also drives the cadence.
    var hasLiveMatch: Bool { matches.contains(where: \.isLive) }

    // MARK: - Pinning

    /// The pinned match resolved against the current feed, or nil when nothing
    /// is pinned or the pinned match is no longer present (e.g. it rolled out
    /// of the relevant-match window).
    var pinnedMatch: Match? {
        guard let id = pinnedMatchID else { return nil }
        return matches.first { $0.id == id }
    }

    /// Pin a match, replacing any previously pinned one (single-select).
    func pin(_ match: Match) { setPinnedMatchID(match.id) }

    /// Clear the pin, leaving no match pinned.
    func unpin() { setPinnedMatchID(nil) }

    /// Pin the match if it isn't already pinned, otherwise unpin it.
    func togglePin(_ match: Match) {
        setPinnedMatchID(pinnedMatchID == match.id ? nil : match.id)
    }

    private func setPinnedMatchID(_ id: String?) {
        pinnedMatchID = id
        if let id {
            defaults.set(id, forKey: Self.pinnedMatchIDKey)
        } else {
            defaults.removeObject(forKey: Self.pinnedMatchIDKey)
        }
    }

    /// True when a pinned match is upcoming and kicks off today — a reason to
    /// poll on the fast cadence so the menu bar title flips to live at kickoff.
    var pinnedUpcomingKicksOffToday: Bool {
        guard let match = pinnedMatch, match.state == .upcoming else { return false }
        return Calendar.current.isDateInToday(match.kickoff)
    }

    /// Matches relevant to show right now: any live match, plus matches
    /// kicking off from the start of today through the upcoming horizon.
    /// Excludes finished games from previous days and fixtures further out.
    var visibleMatches: [Match] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let horizonEnd = calendar.date(byAdding: .day,
                                       value: Self.upcomingHorizonDays + 1,
                                       to: startOfToday) ?? startOfToday
        return matches.filter { match in
            if match.isLive { return true }
            return match.kickoff >= startOfToday && match.kickoff < horizonEnd
        }
    }

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

    /// Begin the auto-refresh loop: refresh, then sleep for an interval that
    /// depends on whether anything is live, and repeat.
    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                guard let self else { return }
                let interval = self.wantsLiveCadence ? Self.liveInterval : Self.idleInterval
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    /// Fast (LIVE) cadence applies while any match is in-progress, or while a
    /// pinned match is about to kick off today.
    var wantsLiveCadence: Bool { hasLiveMatch || pinnedUpcomingKicksOffToday }

    /// Stop the auto-refresh loop (e.g. on quit).
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Fetch once, immediately, regardless of the polling interval.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false; hasLoadedOnce = true }
        do {
            let fetched = try await provider.matches(for: leagues)
            matches = fetched
            errorMessage = nil
        } catch {
            errorMessage = Self.describe(error)
        }
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
