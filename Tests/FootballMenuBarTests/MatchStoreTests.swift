import Foundation
import Testing
@testable import FootballMenuBar

/// The match store, driven through a fake data source with settings on a
/// throwaway `UserDefaults` suite. Each test gets its own suite.
@MainActor
@Suite("Match store")
final class MatchStoreTests {
    private let suiteName = "MatchStoreTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let provider = FakeMatchDataProvider()
    /// The time the store sees: noon today, unless a test moves it.
    private let clock = TestClock(today.addingTimeInterval(12 * 3600))

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// A store following the Premier League and the Champions League.
    private func makeStore() -> MatchStore {
        let settings = AppSettings(defaults: defaults)
        settings.unfollow(worldCup)
        return MatchStore(provider: provider,
                          defaults: defaults,
                          settings: settings,
                          notifier: nil,
                          now: { [clock] in clock.now })
    }

    // MARK: - Followed Competitions

    @Test("On first launch the Followed Competitions are the three defaults, and only they are requested")
    func firstLaunchFollowsDefaults() async {
        let store = MatchStore(provider: provider, defaults: defaults,
                               settings: AppSettings(defaults: defaults), notifier: nil,
                               now: { [clock] in clock.now })

        await store.loadInitial()

        #expect(store.settings.followedCompetitions.map(\.displayName)
                == ["Premier League", "Champions League", "World Cup"])
        #expect(provider.requestedSlugs == [["eng.1", "uefa.champions", "fifa.world"]])
    }

    @Test("Following and unfollowing persists across launches")
    func followingPersists() {
        let settings = AppSettings(defaults: defaults)

        settings.follow(laLiga)
        settings.unfollow(worldCup)

        #expect(AppSettings(defaults: defaults).followedCompetitions.map(\.displayName)
                == ["Premier League", "LaLiga", "Champions League"])
    }

    @Test("Unknown stored slugs are ignored")
    func unknownSlugsIgnored() {
        defaults.set(["eng.fa_qual", "esp.1", "gone.1"], forKey: followedCompetitionsKey)

        #expect(AppSettings(defaults: defaults).followedCompetitions == [laLiga])
    }

    @Test("The defaults apply when no stored slug is valid")
    func defaultsWhenNothingValid() {
        defaults.set(["gone.1"], forKey: followedCompetitionsKey)

        #expect(AppSettings(defaults: defaults).followedCompetitions.map(\.displayName)
                == ["Premier League", "Champions League", "World Cup"])
    }

    @Test("Unfollowing the last Followed Competition is refused")
    func lastCompetitionCannotBeUnfollowed() {
        let settings = AppSettings(defaults: defaults)
        settings.unfollow(worldCup)
        settings.unfollow(championsLeague)
        #expect(settings.canUnfollow(premierLeague) == false)

        settings.unfollow(premierLeague)

        #expect(settings.followedCompetitions == [premierLeague])
        #expect(AppSettings(defaults: defaults).followedCompetitions == [premierLeague])
    }

    @Test("A Followed Competition can be unfollowed while another is followed")
    func competitionCanBeUnfollowedWhileAnotherIsFollowed() {
        let settings = AppSettings(defaults: defaults)

        #expect(settings.isFollowed(worldCup))
        #expect(settings.canUnfollow(worldCup))
        #expect(!settings.isFollowed(laLiga))
    }

    @Test("Following a Competition refreshes the browsed day straight away, including it")
    func followingRefreshes() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(laLiga, with: [barcelonaRealMadrid])
        await store.loadInitial()

        store.settings.follow(laLiga)
        await store.followedCompetitionsRefresh?.value

        #expect(provider.requestedSlugs.last == ["eng.1", "esp.1", "uefa.champions"])
        #expect(store.matchesByCompetition.map(\.competition) == [premierLeague, laLiga])
        #expect(store.matchesByCompetition.map(\.matches) == [[arsenalChelsea], [barcelonaRealMadrid]])
    }

    @Test("Unfollowing a Competition removes its Matches from the list straight away")
    func unfollowingRemovesMatches() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.loadInitial()

        store.settings.unfollow(championsLeague)

        #expect(store.matchesByCompetition.map(\.competition) == [premierLeague])
        #expect(store.matches == [arsenalChelsea])
        await store.followedCompetitionsRefresh?.value
        #expect(provider.requestedSlugs.last == ["eng.1"])
        #expect(store.matches == [arsenalChelsea])
    }

    @Test("Sections are listed in catalogue order, regardless of follow order")
    func sectionsInCatalogueOrder() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [parisBayern])
        provider.succeed(worldCup, with: [brazilFrance])
        provider.succeed(laLiga, with: [barcelonaRealMadrid])
        await store.loadInitial()

        store.settings.follow(worldCup)
        await store.followedCompetitionsRefresh?.value
        store.settings.follow(laLiga)
        await store.followedCompetitionsRefresh?.value

        #expect(store.matchesByCompetition.map(\.competition.displayName)
                == ["Premier League", "LaLiga", "Champions League", "World Cup"])
    }

    // MARK: - A Competition that fails

    @Test("A failed Competition keeps its last Matches and is marked stale, while the others update")
    func failedCompetitionGoesStale() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.loadInitial()

        provider.fail(premierLeague)
        provider.succeed(championsLeague, with: [parisBayernLive])
        await store.refresh()

        let sections = store.matchesByCompetition
        #expect(sections.map(\.competition) == [premierLeague, championsLeague])
        #expect(sections.map(\.status) == [.stale, .loaded])
        #expect(sections.map(\.matches) == [[arsenalChelsea], [parisBayernLive]])
        #expect(store.errorMessage == nil)
    }

    @Test("A Competition that fails with no data for the day is shown as failed to load, with no Matches")
    func competitionWithNoDataFailsToLoad() async {
        let store = makeStore()
        provider.fail(premierLeague)
        provider.succeed(championsLeague, with: [parisBayern])

        await store.loadInitial()

        let sections = store.matchesByCompetition
        #expect(sections.map(\.competition) == [premierLeague, championsLeague])
        #expect(sections.map(\.status) == [.failedToLoad, .loaded])
        #expect(sections.map(\.matches) == [[], [parisBayern]])
    }

    @Test("A Competition's mark clears on its next successful fetch")
    func markClearsOnSuccess() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.fail(championsLeague)
        await store.loadInitial()
        provider.fail(premierLeague)
        await store.refresh()

        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.refresh()

        let sections = store.matchesByCompetition
        #expect(sections.map(\.status) == [.loaded, .loaded])
        #expect(sections.map(\.matches) == [[arsenalChelsea], [parisBayern]])
    }

    @Test("A Competition known to have no Matches that day stays hidden when a later fetch fails")
    func emptyCompetitionStaysHiddenOnFailure() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [])
        await store.loadInitial()

        provider.fail(championsLeague)
        await store.refresh()

        #expect(store.matchesByCompetition.map(\.competition) == [premierLeague])
        #expect(store.errorMessage == nil)
    }

    // MARK: - Full-screen error

    @Test("The full-screen error shows when every Competition failed and nothing is loaded")
    func fullScreenErrorWhenEverythingFailed() async {
        let store = makeStore()
        provider.fail(premierLeague)
        provider.fail(championsLeague)

        await store.loadInitial()

        #expect(store.errorMessage == "Couldn't reach the scores service.")
        #expect(store.matches.isEmpty)
    }

    @Test("No full-screen error when every Competition failed but earlier Matches are still shown")
    func noFullScreenErrorWithStaleMatches() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        await store.loadInitial()

        provider.fail(premierLeague)
        provider.fail(championsLeague)
        await store.refresh()

        #expect(store.errorMessage == nil)
        #expect(store.matchesByCompetition.map(\.status) == [.stale])
    }

    @Test("No full-screen error when only some Competitions failed, even with nothing loaded")
    func noFullScreenErrorWhenSomeSucceeded() async {
        let store = makeStore()
        provider.fail(premierLeague)
        provider.succeed(championsLeague, with: [])

        await store.loadInitial()

        #expect(store.errorMessage == nil)
        #expect(store.matchesByCompetition.map(\.status) == [.failedToLoad])
    }

    @Test("The full-screen error clears once a Competition loads again")
    func fullScreenErrorClearsOnRetry() async {
        let store = makeStore()
        provider.fail(premierLeague)
        provider.fail(championsLeague)
        await store.loadInitial()

        provider.succeed(premierLeague, with: [arsenalChelsea])
        await store.refresh()

        #expect(store.errorMessage == nil)
        #expect(store.matches == [arsenalChelsea])
    }

    // MARK: - Pinned Match

    @Test("The Pinned Match survives a failure of its Competition, and is cleared after a successful fetch without it")
    func pinnedMatchOnBrowsedDay() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.loadInitial()
        store.pin(arsenalChelsea)

        provider.fail(premierLeague)
        await store.refresh()
        #expect(store.pinnedSnapshot == arsenalChelsea)

        provider.succeed(premierLeague, with: [])
        await store.refresh()
        #expect(store.pinnedSnapshot == nil)
    }

    @Test("A Pinned Match on another day survives a failure of its Competition, and is cleared after a successful fetch without it")
    func pinnedMatchOnAnotherDay() async {
        let store = makeStore()
        store.pin(yesterdayArsenalChelsea)

        provider.fail(premierLeague)
        provider.succeed(championsLeague, with: [])
        await store.loadInitial()
        #expect(store.pinnedSnapshot == yesterdayArsenalChelsea)

        provider.succeed(premierLeague, with: [])
        provider.fail(championsLeague)
        await store.loadInitial()
        #expect(store.pinnedSnapshot == nil)
    }

    @Test("A restored pin with no snapshot yet stays without one while its Competition fails, and gets one once it loads")
    func restoredPinWithoutSnapshot() async {
        makeStore().pin(yesterdayArsenalChelsea)
        let store = makeStore()
        #expect(store.pinnedMatchID == yesterdayArsenalChelsea.id)

        provider.fail(premierLeague)
        await store.loadInitial()
        #expect(store.pinnedSnapshot == nil)

        provider.succeed(premierLeague, with: [yesterdayArsenalChelsea])
        await store.loadInitial()
        #expect(store.pinnedSnapshot == yesterdayArsenalChelsea)
    }

    @Test("Unfollowing the Pinned Match's Competition keeps the pin, while its Matches leave the list")
    func unfollowingPinnedMatchCompetitionKeepsPin() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.loadInitial()
        store.pin(arsenalChelsea)

        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value
        await store.refresh()

        #expect(store.pinnedSnapshot == arsenalChelsea)
        #expect(store.matches == [parisBayern])
    }

    // MARK: - Pinned Match outside the Followed Competitions

    @Test("An unfollowed Pinned Match's Competition is still requested for the ticker, while its Matches stay out of the list")
    func unfollowedPinnedCompetitionStillRequested() async {
        let store = makeStore()
        store.pin(arsenalChelsea)
        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value

        provider.succeed(premierLeague, with: [arsenalChelseaLive])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.loadInitial()

        #expect(provider.requestedSlugs.suffix(2) == [["uefa.champions", "eng.1"], ["uefa.champions"]])
        #expect(store.pinnedMatchID == arsenalChelsea.id)
        #expect(store.pinnedSnapshot == arsenalChelseaLive)
        #expect(store.matches == [parisBayern])
        #expect(store.matchesByCompetition.map(\.competition) == [championsLeague])
    }

    @Test("The Pinned Match's Competition is saved with the pin, so a new store still requests it while it isn't followed")
    func pinnedCompetitionPersists() async {
        let first = makeStore()
        first.pin(arsenalChelsea)
        first.settings.unfollow(premierLeague)
        await first.followedCompetitionsRefresh?.value

        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelseaLive])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.loadInitial()

        #expect(provider.requestedSlugs.suffix(2) == [["uefa.champions", "eng.1"], ["uefa.champions"]])
        #expect(store.pinnedSnapshot == arsenalChelseaLive)
        #expect(store.matches == [parisBayern])
    }

    @Test("After unpinning, the unfollowed Competition is no longer requested")
    func unpinStopsRequestingUnfollowedCompetition() async {
        let store = makeStore()
        store.pin(arsenalChelsea)
        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value

        store.unpin()
        await store.loadInitial()
        await makeStore().loadInitial()

        #expect(provider.requestedSlugs == [["uefa.champions"], ["uefa.champions"], ["uefa.champions"]])
    }

    @Test("Once the Pinned Match's day is over, its unfollowed Competition is no longer requested, and the snapshot keeps its last value")
    func pastDayStopsRequestingUnfollowedCompetition() async {
        let store = makeStore()
        store.pin(yesterdayArsenalChelsea)
        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value

        await store.tick()

        #expect(provider.requestedSlugs == [["uefa.champions"], ["uefa.champions"], ["uefa.champions"]])
        #expect(store.pinnedMatchID == yesterdayArsenalChelsea.id)
        #expect(store.pinnedSnapshot == yesterdayArsenalChelsea)
    }

    @Test("A pin of an unfollowed Competition is requested on ticks during its day, and no longer once the clock passes midnight")
    func clockPassingMidnightStopsRequestingUnfollowedCompetition() async {
        let store = makeStore()
        store.pin(arsenalChelsea)
        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value
        provider.succeed(premierLeague, with: [arsenalChelseaLive])

        await store.tick()
        #expect(provider.requestedSlugs.suffix(2) == [["eng.1"], ["uefa.champions"]])
        #expect(store.pinnedSnapshot == arsenalChelseaLive)

        clock.advance(by: 12 * 3600 + 60)
        await store.tick()

        #expect(provider.requestedSlugs.last == ["uefa.champions"])
        #expect(store.pinnedSnapshot == arsenalChelseaLive)
    }

    @Test("After a relaunch, the restore requests a past-day Pinned Match's unfollowed Competition once, so the snapshot shows its last state, while ticks don't")
    func relaunchRestoresPastDayPinOfUnfollowedCompetition() async {
        let first = makeStore()
        first.pin(yesterdayArsenalChelsea)
        first.settings.unfollow(premierLeague)
        await first.followedCompetitionsRefresh?.value

        let store = makeStore()
        provider.succeed(premierLeague, with: [yesterdayArsenalChelsea])
        await store.loadInitial()

        #expect(provider.requestedSlugs.suffix(2) == [["uefa.champions", "eng.1"], ["uefa.champions"]])
        #expect(store.pinnedSnapshot == yesterdayArsenalChelsea)

        await store.tick()

        #expect(provider.requestedSlugs.suffix(2) == [["uefa.champions"], ["uefa.champions"]])
        #expect(store.pinnedSnapshot == yesterdayArsenalChelsea)
    }

    @Test("A pin saved without its Competition is restored from the Followed Competitions, and its Competition is saved once found")
    func pinWithoutCompetitionRestoredFromFollowed() async {
        defaults.set(arsenalChelsea.id, forKey: pinnedMatchIDKey)
        defaults.set(dayKey(todayKickoff), forKey: pinnedMatchDayKey)
        provider.succeed(premierLeague, with: [arsenalChelsea])
        let store = makeStore()

        await store.loadInitial()

        #expect(provider.requestedSlugs.first == ["eng.1", "uefa.champions"])
        #expect(store.pinnedSnapshot == arsenalChelsea)

        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value
        let relaunched = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelseaLive])
        await relaunched.loadInitial()

        #expect(provider.requestedSlugs.suffix(2) == [["uefa.champions", "eng.1"], ["uefa.champions"]])
        #expect(relaunched.pinnedSnapshot == arsenalChelseaLive)
    }

    @Test("A pin saved without its day saves the Match's day once found, so its unfollowed Competition stops being requested after that day")
    func pinWithoutDayStopsRequestingAfterItsDay() async {
        defaults.set(yesterdayArsenalChelsea.id, forKey: pinnedMatchIDKey)
        provider.succeed(premierLeague, with: [yesterdayArsenalChelsea])
        let store = makeStore()
        await store.loadInitial()
        #expect(store.pinnedSnapshot == yesterdayArsenalChelsea)

        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value
        await makeStore().tick()

        #expect(provider.requestedSlugs.suffix(3) == [["uefa.champions"], ["uefa.champions"], ["uefa.champions"]])
    }

    @Test("A refresh tick while browsing the pinned day still fetches the unfollowed Pinned Match's Competition, alone, for the ticker")
    func tickOnPinnedDayFetchesUnfollowedCompetition() async {
        let store = makeStore()
        store.pin(arsenalChelsea)
        store.settings.unfollow(premierLeague)
        await store.followedCompetitionsRefresh?.value

        provider.succeed(premierLeague, with: [arsenalChelseaLive])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.tick()

        #expect(provider.requestedSlugs.suffix(2) == [["eng.1"], ["uefa.champions"]])
        #expect(store.pinnedSnapshot == arsenalChelseaLive)
        #expect(store.matchesByCompetition.map(\.competition) == [championsLeague])
    }

    // MARK: - Browsed day

    @Test("A new day starts with no last Matches: a failure there is failed to load, not stale")
    func newDayStartsFresh() async {
        let store = makeStore()
        provider.succeed(premierLeague, with: [arsenalChelsea])
        provider.succeed(championsLeague, with: [parisBayern])
        await store.loadInitial()

        provider.fail(premierLeague)
        await store.stepDay(by: 1)

        let sections = store.matchesByCompetition
        #expect(sections.map(\.competition) == [premierLeague, championsLeague])
        #expect(sections.map(\.status) == [.failedToLoad, .loaded])
        #expect(sections.map(\.matches) == [[], [parisBayern]])
    }
}

/// Where the settings store the Followed Competitions' slugs.
private let followedCompetitionsKey = "settings.followedCompetitions"
/// Where a pin saved before its Competition was stored keeps its id and day
/// (older pins have no day).
private let pinnedMatchIDKey = "pinnedMatchID"
private let pinnedMatchDayKey = "pinnedMatchDay"

private let premierLeague = Competition(slug: "eng.1", displayName: "Premier League", region: .england)
private let championsLeague = Competition(slug: "uefa.champions", displayName: "Champions League", region: .uefa)
private let laLiga = Competition(slug: "esp.1", displayName: "LaLiga", region: .spain)
private let worldCup = Competition(slug: "fifa.world", displayName: "World Cup", region: .fifa)

/// A day as the store saves a pin's day: `yyyy-MM-dd`, local.
private func dayKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

/// The day the tests' clock starts on: the start of 4 November 2026, local.
private let today = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4))!

/// Today's kickoff, so a Pinned Match's day is the browsed day.
private let todayKickoff = today.addingTimeInterval(20 * 3600)

private var arsenalChelsea: Match {
    makeMatch(id: "1", competitionSlug: "eng.1", state: .upcoming,
              statusDetail: "8:00 PM", kickoff: todayKickoff)
}
private var arsenalChelseaLive: Match {
    makeMatch(id: "1", competitionSlug: "eng.1", state: .inProgress,
              statusDetail: "30'", score: Score(home: 1, away: 0), kickoff: todayKickoff)
}
private var yesterdayArsenalChelsea: Match {
    makeMatch(id: "3", competitionSlug: "eng.1", state: .finished,
              statusDetail: "FT", score: Score(home: 2, away: 1),
              kickoff: todayKickoff.addingTimeInterval(-24 * 3600))
}
private let bayern = Team(id: "132", name: "Bayern Munich", abbreviation: "BAY", logoURL: nil)
private var parisBayern: Match {
    makeMatch(id: "2", competitionSlug: "uefa.champions", state: .upcoming,
              statusDetail: "8:00 PM", kickoff: todayKickoff,
              home: paris, away: bayern)
}
private var barcelonaRealMadrid: Match {
    makeMatch(id: "4", competitionSlug: "esp.1", state: .upcoming,
              statusDetail: "8:00 PM", kickoff: todayKickoff,
              home: Team(id: "83", name: "Barcelona", abbreviation: "BAR", logoURL: nil),
              away: Team(id: "86", name: "Real Madrid", abbreviation: "RMA", logoURL: nil))
}
private var brazilFrance: Match {
    makeMatch(id: "5", competitionSlug: "fifa.world", state: .upcoming,
              statusDetail: "8:00 PM", kickoff: todayKickoff,
              home: Team(id: "205", name: "Brazil", abbreviation: "BRA", logoURL: nil),
              away: Team(id: "478", name: "France", abbreviation: "FRA", logoURL: nil))
}
private var parisBayernLive: Match {
    makeMatch(id: "2", competitionSlug: "uefa.champions", state: .inProgress,
              statusDetail: "12'", score: Score(home: 1, away: 0),
              kickoff: todayKickoff, home: paris, away: bayern)
}
