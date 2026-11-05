import Foundation
import Combine

/// Observable store that keeps matches current for the Followed Competitions and
/// auto-refreshes on a cadence driven by live play. Injected into the SwiftUI
/// environment for views to read.
///
/// It maintains two logically separate feeds:
/// - the **browse feed** (`matches`) for `selectedDate`, powering the popover.
///   Each Competition loads independently: one that fails keeps its last
///   Matches for that day, and its load status says so;
/// - the **ticker feed** (`pinnedSnapshot`) for the pinned match, powering the
///   menu bar title independently of which day is browsed.
///
/// Uses `ObservableObject` rather than the `@Observable` macro to keep the
/// macOS 13 deployment floor (the macro requires macOS 14).
@MainActor
final class MatchStore: ObservableObject {
    /// `UserDefaults` keys under which the pin is persisted.
    private static let pinnedMatchIDKey = "pinnedMatchID"
    private static let pinnedMatchDayKey = "pinnedMatchDay"
    private static let pinnedMatchCompetitionSlugKey = "pinnedMatchCompetitionSlug"

    /// Persists the pinned match's day as `yyyy-MM-dd` (local) so the ticker can
    /// be restored by re-fetching that day on launch.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Browse feed
    /// The browsed day's Matches: each Competition's from its last successful
    /// fetch that day, in Competition order.
    @Published private(set) var matches: [Match] = []
    /// Set only when every requested Competition failed and no Matches are
    /// loaded for the browsed day: the full-screen error.
    @Published private(set) var errorMessage: String?
    /// Each Competition's load status for the browsed day, by slug.
    @Published private(set) var loadStatusBySlug: [String: CompetitionLoadStatus] = [:]
    /// Each Competition's Matches from its last successful fetch of
    /// `lastMatchesDay`, by slug. A Competition with no successful fetch that
    /// day has no entry.
    private var lastMatchesBySlug: [String: [Match]] = [:]
    /// The day `lastMatchesBySlug` belongs to.
    private var lastMatchesDay: Date?
    @Published private(set) var isRefreshing = false
    /// True while a date step's fetch is in flight — distinct from `isRefreshing`
    /// so the view can keep the prior day's list visible during a step.
    @Published private(set) var isSteppingDate = false
    @Published private(set) var hasLoadedOnce = false
    /// The day currently being browsed; defaults to today, not persisted.
    @Published private(set) var selectedDate: Date

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
    /// The slug of the Pinned Match's Competition, so the ticker can fetch it
    /// while it isn't followed. `nil` for a pin saved before the Competition
    /// was stored: such a pin is looked up among the Followed Competitions.
    private var pinnedMatchCompetitionSlug: String?

    /// The Followed Competitions, in catalogue order: what is requested and
    /// listed.
    @Published private(set) var followedCompetitions: [Competition]
    private let provider: MatchDataProvider
    private let defaults: UserDefaults
    /// The current time, for every time rule: today, the browsed and pinned
    /// days, due kickoffs and the Pinned Match's day being over. The real
    /// clock outside tests.
    private let now: @MainActor () -> Date
    /// User configuration; the poll loop reads the cadence from it each tick.
    let settings: AppSettings
    /// Posts pinned-match notifications. Optional so tests/previews can omit it.
    private let notifier: MatchNotifier?
    private var pollingTask: Task<Void, Never>?
    private var followedCompetitionsSubscription: AnyCancellable?
    /// The refresh started by the latest change of the Followed Competitions;
    /// awaitable so tests can wait for it.
    private(set) var followedCompetitionsRefresh: Task<Void, Never>?
    /// Set when the Followed Competitions change during a refresh, so that
    /// refresh runs once more with them instead of the change being dropped.
    private var refreshPending = false

    /// Which feed a refresh served: the browse feed or the ticker feed.
    private enum Feed: Hashable { case browse, ticker }
    /// A Competition refreshed for one feed on one day.
    private struct RefreshKey: Hashable {
        let feed: Feed
        let slug: String
        let day: Date
    }
    /// When each Competition was last requested, per feed and day. Only the
    /// browsed day and the pinned day are kept.
    private var lastRefreshes: [RefreshKey: Date] = [:]
    /// When a fetch last showed each Match Live, by Match id, for as long as
    /// it can still keep an Abandoned Match's Competition on the Live rate.
    /// In memory only.
    private var lastSeenLiveByMatchID: [String: Date] = [:]

    /// Distinguishes a snapshot write that reflects live observation (a poll
    /// tick, which may notify) from one that merely seeds the pinned match (pin,
    /// launch restore, unpin — never notifies).
    private enum SnapshotSource { case seed, poll }

    init(provider: MatchDataProvider,
         defaults: UserDefaults = .standard,
         settings: AppSettings = AppSettings(),
         notifier: MatchNotifier? = nil,
         now: @escaping @MainActor () -> Date = { Date() }) {
        self.provider = provider
        self.now = now
        self.selectedDate = Calendar.current.startOfDay(for: now())
        self.followedCompetitions = settings.followedCompetitions
        self.defaults = defaults
        self.settings = settings
        self.notifier = notifier
        self.pinnedMatchID = defaults.string(forKey: Self.pinnedMatchIDKey)
        if let dayString = defaults.string(forKey: Self.pinnedMatchDayKey) {
            self.pinnedMatchDay = Self.dayKeyFormatter.date(from: dayString)
        }
        self.pinnedMatchCompetitionSlug = defaults.string(forKey: Self.pinnedMatchCompetitionSlugKey)
        // `@Published` emits before the property changes, so the new value is
        // taken from the emission. Settings change on the main actor.
        followedCompetitionsSubscription = settings.$followedCompetitions
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] followed in
                MainActor.assumeIsolated { self?.followedCompetitionsChanged(to: followed) }
            }
    }

    // MARK: - Followed Competitions

    /// Follow a new selection: an unfollowed Competition's Matches and status
    /// leave the list at once, and the browsed day is refreshed straight away
    /// so a newly followed Competition's Matches appear.
    private func followedCompetitionsChanged(to followed: [Competition]) {
        followedCompetitions = followed
        let followedSlugs = Set(followed.map(\.slug))
        lastMatchesBySlug = lastMatchesBySlug.filter { followedSlugs.contains($0.key) }
        loadStatusBySlug = loadStatusBySlug.filter { followedSlugs.contains($0.key) }
        matches = followed.flatMap { lastMatchesBySlug[$0.slug] ?? [] }
        followedCompetitionsRefresh = Task { [weak self] in
            guard let self else { return }
            if self.isRefreshing { self.refreshPending = true } else { await self.refresh() }
        }
    }

    /// True while at least one browsed match is being played: the browse feed
    /// keeps refreshing then, even on a day other than today.
    var hasLiveMatch: Bool { matches.contains(where: \.isLive) }

    /// The start of the current local day.
    private var today: Date { Calendar.current.startOfDay(for: now()) }

    /// True when the selected day is the current local day.
    var isViewingToday: Bool { Calendar.current.isDate(selectedDate, inSameDayAs: now()) }

    // MARK: - Pinning

    /// Pin a match, replacing any previously pinned one (single-select). Seeds
    /// the ticker snapshot immediately so the title updates without a fetch.
    func pin(_ match: Match) {
        pinnedMatchID = match.id
        pinnedMatchDay = Calendar.current.startOfDay(for: match.kickoff)
        pinnedMatchCompetitionSlug = match.competitionSlug
        setPinnedSnapshot(match, source: .seed)
        persistPin()
    }

    /// Clear the pin, leaving no match pinned.
    func unpin() {
        pinnedMatchID = nil
        pinnedMatchDay = nil
        pinnedMatchCompetitionSlug = nil
        setPinnedSnapshot(nil, source: .seed)
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
            if let slug = pinnedMatchCompetitionSlug {
                defaults.set(slug, forKey: Self.pinnedMatchCompetitionSlugKey)
            }
        } else {
            defaults.removeObject(forKey: Self.pinnedMatchIDKey)
            defaults.removeObject(forKey: Self.pinnedMatchDayKey)
            defaults.removeObject(forKey: Self.pinnedMatchCompetitionSlugKey)
        }
    }

    /// The day whose fetch feeds the ticker: the pinned match's day, or today
    /// for a legacy pin without a persisted day.
    private var pinnedDay: Date {
        pinnedMatchDay ?? today
    }

    /// The Pinned Match's Competition while it isn't followed, whatever its
    /// day. Its Matches never reach the list.
    private var pinnedCompetitionIfUnfollowed: Competition? {
        guard pinnedMatchID != nil, let slug = pinnedMatchCompetitionSlug,
              !followedCompetitions.contains(where: { $0.slug == slug })
        else { return nil }
        return Competition.inCatalogue(slugs: [slug]).first
    }

    /// The Pinned Match's unfollowed Competition while its day isn't over: the
    /// ticker keeps fetching it on top of the Followed Competitions.
    private var unfollowedPinnedCompetition: Competition? {
        guard pinnedDay >= today else { return nil }
        return pinnedCompetitionIfUnfollowed
    }

    /// The Competitions the ticker fetch requests: the Pinned Match's own,
    /// unless it isn't followed and its day is over. A pin whose Competition
    /// isn't known yet is looked for among the Followed Competitions.
    private var tickerCompetitions: [Competition] {
        guard pinnedMatchID != nil else { return [] }
        guard let slug = pinnedMatchCompetitionSlug ?? pinnedSnapshot?.competitionSlug else {
            return followedCompetitions
        }
        if let followed = followedCompetitions.first(where: { $0.slug == slug }) {
            return [followed]
        }
        return unfollowedPinnedCompetition.map { [$0] } ?? []
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

    /// Matches grouped by Competition in catalogue order, with
    /// each Competition's load status, for display. A Competition with no
    /// Matches is left out unless it failed to load, so the list can say so.
    var matchesByCompetition: [(competition: Competition, status: CompetitionLoadStatus, matches: [Match])] {
        let visible = visibleMatches
        return followedCompetitions.compactMap { competition in
            let group = visible
                .filter { $0.competitionSlug == competition.slug }
                .sorted(by: Self.displayOrder)
            let status = loadStatusBySlug[competition.slug] ?? .loaded
            guard !group.isEmpty || status == .failedToLoad else { return nil }
            return (competition, status, group)
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
        let today = self.today
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
                // Worked out afresh each step, so a change of the Refresh
                // setting takes effect no later than the next one.
                let delay = self.nextRefreshDelay()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { break }
                await self.tick()
            }
        }
    }

    /// One refresh tick of the polling loop (internal, not private, so tests
    /// can drive it): keep the pinned ticker live regardless of the browsed
    /// day, and refresh the browse feed while the browsed day is today or has a
    /// live match. Refreshing today (not just a live day) is what lets a
    /// scheduled match flip to live on its own — a day of purely upcoming
    /// matches would otherwise never re-fetch and so never observe kickoff. When
    /// the browsed day is the pinned day, the browse fetch also updates the
    /// snapshot from the Followed Competitions, so the ticker fetch requests
    /// only the Pinned Match's unfollowed Competition, if any.
    func tick() async {
        let now = now()
        let browseDue = browseSchedule.filter { $0.dueAt <= now }.map(\.competition)
        let coveredByBrowse = pinnedDayIsBrowsed ? Set(browseDue.map(\.slug)) : []
        let tickerDue = tickerSchedule
            .filter { $0.dueAt <= now && !coveredByBrowse.contains($0.competition.slug) }
            .map(\.competition)
        if !tickerDue.isEmpty {
            await refreshTicker(requesting: tickerDue, source: .poll)
        }
        if !browseDue.isEmpty {
            await refresh(requesting: browseDue)
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

    /// Fetch every Followed Competition for the selected day, immediately,
    /// whatever their rates.
    func refresh() async {
        await refresh(requesting: nil)
    }

    /// Fetch `due` for the selected day, or every Followed Competition when
    /// `nil`. A change of the Followed Competitions during the fetch refetches
    /// all of them.
    private func refresh(requesting due: [Competition]?) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var requested = due
        repeat {
            refreshPending = false
            await loadBrowse(for: selectedDate, requesting: requested ?? followedCompetitions)
            requested = nil
        } while refreshPending
    }

    /// Load the browse feed for `target`, every Followed Competition unless
    /// `requested` says otherwise. Results are discarded if the selected day
    /// changed while the fetch was in flight (out-of-order guard).
    private func loadBrowse(for target: Date, requesting requested: [Competition]? = nil) async {
        let requested = requested ?? followedCompetitions
        let requestedAt = now()
        let results = await provider.matches(for: requested, on: target)
        noteLiveMatches(in: results, at: requestedAt)
        guard Calendar.current.isDate(target, inSameDayAs: selectedDate) else { return }
        recordRefresh(of: requested, feed: .browse, day: target, at: requestedAt)
        applyBrowseResults(results, requested: requested, for: target)
        if pinnedMatchID != nil, pinnedDayIsBrowsed {
            recordRefresh(of: requested, feed: .ticker, day: target, at: requestedAt)
        }
        updateSnapshotFromBrowse(results)
        hasLoadedOnce = true
    }

    /// Merge one fetch of `day` into the browse feed. A Competition that
    /// succeeded shows its new Matches. One that failed keeps the Matches of
    /// its last success that day (stale), or, with no success that day yet,
    /// is marked failed to load. A new day starts with no last Matches.
    ///
    /// Only the `requested` Competitions that are still followed are merged:
    /// the selection may have changed while the fetch was in flight, and a
    /// Competition followed since then keeps its state until its own fetch.
    private func applyBrowseResults(_ results: CompetitionResults, requested: [Competition], for day: Date) {
        // On the same day, earlier successes and statuses still stand.
        let isSameDay = lastMatchesDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
        if !isSameDay {
            lastMatchesBySlug = [:]
            lastMatchesDay = day
        }

        let followedSlugs = Set(followedCompetitions.map(\.slug))
        var statuses = isSameDay ? loadStatusBySlug : [:]
        var firstFailure: MatchDataError?
        for competition in requested where followedSlugs.contains(competition.slug) {
            let slug = competition.slug
            if case .success(let fetched)? = results[slug] {
                lastMatchesBySlug[slug] = fetched
                statuses[slug] = .loaded
            } else {
                if case .failure(let error)? = results[slug], firstFailure == nil {
                    firstFailure = error
                }
                statuses[slug] = lastMatchesBySlug[slug] == nil ? .failedToLoad : .stale
            }
        }

        matches = followedCompetitions.flatMap { lastMatchesBySlug[$0.slug] ?? [] }
        loadStatusBySlug = statuses
        let everyCompetitionFailed = !statuses.isEmpty && !statuses.values.contains(.loaded)
        errorMessage = everyCompetitionFailed && matches.isEmpty ? Self.describe(firstFailure) : nil
    }

    // MARK: - Each Competition's rate

    /// A Competition the polling loop refreshes, and when it is next due.
    private typealias ScheduledRefresh = (competition: Competition, dueAt: Date)

    /// The Followed Competitions on the browsed day, while the browse feed
    /// refreshes on its own: when the browsed day is today or has a Live Match.
    private var browseSchedule: [ScheduledRefresh] {
        guard isViewingToday || hasLiveMatch else { return [] }
        return followedCompetitions.map { competition in
            let liveRate = wantsLiveRate(browseMatches(of: competition.slug))
            return (competition, dueAt(RefreshKey(feed: .browse, slug: competition.slug, day: selectedDate),
                                       liveRate: liveRate))
        }
    }

    /// The ticker's Competitions on the pinned day, at the rate the Pinned
    /// Match's Competition's Matches give.
    private var tickerSchedule: [ScheduledRefresh] {
        let day = pinnedDay
        let liveRate = wantsLiveRate(pinnedSnapshot.map { [$0] } ?? [])
        return tickerCompetitions.map { competition in
            (competition, dueAt(RefreshKey(feed: .ticker, slug: competition.slug, day: day),
                                liveRate: liveRate))
        }
    }

    /// How long the polling loop waits before its next refresh step (internal,
    /// not private, so tests can check it): until the next Competition is due,
    /// and at most one Idle-rate interval, so a change that time alone brings,
    /// such as the browsed day becoming today, is still noticed.
    func nextRefreshDelay() -> TimeInterval {
        let now = now()
        let idleRate = TimeInterval(settings.cadence.idleInterval) / 1_000_000_000
        let nextDue = (browseSchedule + tickerSchedule).map(\.dueAt).min() ?? .distantFuture
        let next = min(nextDue, now.addingTimeInterval(idleRate))
        return max(next.timeIntervalSince(now), Self.minimumRefreshDelay)
    }

    /// The shortest wait between two refresh steps, so a Competition due
    /// straight away doesn't spin the loop.
    private static let minimumRefreshDelay: TimeInterval = 1

    /// The Competition's last-known Matches on the browsed day: none when it
    /// failed to load.
    private func browseMatches(of slug: String) -> [Match] {
        guard let lastMatchesDay, Calendar.current.isDate(lastMatchesDay, inSameDayAs: selectedDate)
        else { return [] }
        return lastMatchesBySlug[slug] ?? []
    }

    /// How long before a confirmed kickoff its Competition goes on the Live rate.
    private static let kickoffWindowBefore: TimeInterval = 5 * 60
    /// How long after a confirmed kickoff its Competition stays on the Live
    /// rate while the Match isn't Live yet.
    private static let kickoffWindowAfter: TimeInterval = 30 * 60
    /// How long after an Abandoned Match was last seen Live its Competition
    /// stays on the Live rate, so a restart is noticed promptly.
    private static let abandonedWindow: TimeInterval = 60 * 60

    /// True when a Competition with these Matches uses the Live rate: one of
    /// them is Live, is Upcoming within its confirmed kickoff's window, or is
    /// Abandoned less than an hour after it was last seen Live.
    private func wantsLiveRate(_ matches: [Match]) -> Bool {
        let now = now()
        return matches.contains { match in
            switch match.state {
            case .inProgress:
                return true
            case .upcoming:
                return match.isKickoffConfirmed
                    && match.kickoff.addingTimeInterval(-Self.kickoffWindowBefore) <= now
                    && now <= match.kickoff.addingTimeInterval(Self.kickoffWindowAfter)
            case .abandoned:
                guard let seen = lastSeenLiveByMatchID[match.id] else { return false }
                return now.timeIntervalSince(seen) < Self.abandonedWindow
            case .finished, .postponed, .cancelled:
                return false
            }
        }
    }

    /// When the Competition under `key` is next due: its rate's interval after
    /// its last refresh, or straight away if it has none.
    private func dueAt(_ key: RefreshKey, liveRate: Bool) -> Date {
        guard let last = lastRefreshes[key] else { return .distantPast }
        let refreshSetting = settings.cadence
        let interval = liveRate ? refreshSetting.liveInterval : refreshSetting.idleInterval
        return last.addingTimeInterval(TimeInterval(interval) / 1_000_000_000)
    }

    /// Remember which fetched Matches are Live at `time`, forgetting those
    /// seen Live too long ago to matter.
    private func noteLiveMatches(in results: CompetitionResults, at time: Date) {
        lastSeenLiveByMatchID = lastSeenLiveByMatchID.filter {
            time.timeIntervalSince($0.value) < Self.abandonedWindow
        }
        for case .success(let fetched) in results.values {
            for match in fetched where match.isLive {
                lastSeenLiveByMatchID[match.id] = time
            }
        }
    }

    /// Remember that `competitions` were requested for `feed` on `day` at
    /// `time`, forgetting days that are neither browsed nor pinned.
    private func recordRefresh(of competitions: [Competition], feed: Feed, day: Date, at time: Date) {
        let day = Calendar.current.startOfDay(for: day)
        let keptDays = [selectedDate, pinnedDay].map { Calendar.current.startOfDay(for: $0) }
        lastRefreshes = lastRefreshes.filter { keptDays.contains($0.key.day) }
        for competition in competitions {
            lastRefreshes[RefreshKey(feed: feed, slug: competition.slug, day: day)] = time
        }
    }

    // MARK: - Ticker feed

    /// Restore the pinned ticker on launch by fetching the pinned match's day.
    /// This is a seed, not live observation, so it must never notify.
    ///
    /// The Pinned Match's unfollowed Competition is requested even when its day
    /// is over, once, so the menu bar shows its last-known state again; ticks
    /// stop requesting it after that day.
    private func restorePinnedSnapshot() async {
        guard pinnedMatchID != nil else { return }
        let competitions = followedCompetitions + (pinnedCompetitionIfUnfollowed.map { [$0] } ?? [])
        await refreshTicker(requesting: competitions, source: .seed)
    }

    /// Fetch `competitions` on the Pinned Match's day and update its snapshot
    /// (see `updateSnapshot(from:id:source:)`). `source` distinguishes the
    /// launch seed from a live poll tick for notification purposes.
    private func refreshTicker(requesting competitions: [Competition], source: SnapshotSource) async {
        guard let id = pinnedMatchID else { setPinnedSnapshot(nil, source: source); return }
        let day = pinnedDay
        let requestedAt = now()
        let results = await provider.matches(for: competitions, on: day)
        noteLiveMatches(in: results, at: requestedAt)
        recordRefresh(of: competitions, feed: .ticker, day: day, at: requestedAt)
        updateSnapshot(from: results, id: id, source: source)
    }

    /// When browsing the pinned match's own day, treat the browse fetch as
    /// authoritative for the snapshot, under the same rule as the ticker. When
    /// browsing another day, leave the snapshot untouched. Browse refreshes are
    /// live observation, so they go through as a poll.
    private func updateSnapshotFromBrowse(_ results: CompetitionResults) {
        guard let id = pinnedMatchID, pinnedDayIsBrowsed else { return }
        updateSnapshot(from: results, id: id, source: .poll)
    }

    /// Update the snapshot of the Pinned Match `id` from a fetch of its day.
    /// Only a successful fetch of the snapshot's own Competition decides: it
    /// replaces the snapshot, or clears it (⇒ ⚽) when the Match is no longer
    /// there. A failure of that Competition keeps the last snapshot. With no
    /// snapshot yet, the Match is looked for in every Competition that loaded;
    /// once found, a pin saved without its Competition or day saves them from
    /// then on, so the extra fetch of an unfollowed Competition can end.
    private func updateSnapshot(from results: CompetitionResults, id: String, source: SnapshotSource) {
        if let snapshot = pinnedSnapshot {
            guard case .success(let fetched)? = results[snapshot.competitionSlug] else { return }
            setPinnedSnapshot(fetched.first { $0.id == id }, source: source)
        } else {
            let found = results.values.lazy
                .compactMap { try? $0.get().first { $0.id == id } }
                .first
            guard let found else { return }
            setPinnedSnapshot(found, source: source)
            if pinnedMatchCompetitionSlug == nil || pinnedMatchDay == nil {
                pinnedMatchCompetitionSlug = pinnedMatchCompetitionSlug ?? found.competitionSlug
                pinnedMatchDay = pinnedMatchDay ?? Calendar.current.startOfDay(for: found.kickoff)
                persistPin()
            }
        }
    }

    /// The single choke point for writing `pinnedSnapshot`. Drives the notifier:
    /// a `.seed` write updates its baseline silently; a `.poll` write is
    /// evaluated for kickoff/goal notifications.
    private func setPinnedSnapshot(_ new: Match?, source: SnapshotSource) {
        pinnedSnapshot = new
        switch source {
        case .seed: notifier?.seed(new)
        case .poll: notifier?.evaluate(new)
        }
    }

    // MARK: - Helpers

    /// Live matches first, then upcoming, then finished (Postponed and
    /// Cancelled sort with finished); within each, by kickoff.
    private static func displayOrder(_ a: Match, _ b: Match) -> Bool {
        func rank(_ s: MatchState) -> Int {
            switch s { case .inProgress: return 0; case .upcoming: return 1; case .finished, .postponed, .cancelled, .abandoned: return 2 }
        }
        if rank(a.state) != rank(b.state) { return rank(a.state) < rank(b.state) }
        return a.kickoff < b.kickoff
    }

    /// User text for the full-screen error. `nil` when the data source gave no
    /// reason (it left a requested Competition out).
    private static func describe(_ error: MatchDataError?) -> String {
        switch error {
        case .network: return "Couldn't reach the scores service."
        case .decoding: return "Received an unexpected response."
        case .badResponse(let status): return "Scores service error (\(status))."
        case nil: return "Something went wrong fetching scores."
        }
    }
}
