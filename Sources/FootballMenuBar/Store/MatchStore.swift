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

    @Published private(set) var matches: [Match] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasLoadedOnce = false

    let leagues: [League]
    private let provider: MatchDataProvider
    private var pollingTask: Task<Void, Never>?

    init(provider: MatchDataProvider, leagues: [League] = League.supported) {
        self.provider = provider
        self.leagues = leagues
    }

    /// True while at least one match is being played — also drives the cadence.
    var hasLiveMatch: Bool { matches.contains(where: \.isLive) }

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
                let interval = self.hasLiveMatch ? Self.liveInterval : Self.idleInterval
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

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
