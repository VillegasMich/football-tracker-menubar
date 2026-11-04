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

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeStore() -> MatchStore {
        MatchStore(provider: provider,
                   competitions: [premierLeague, championsLeague],
                   defaults: defaults,
                   settings: AppSettings(defaults: defaults),
                   notifier: nil)
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

private let premierLeague = Competition(slug: "eng.1", displayName: "Premier League")
private let championsLeague = Competition(slug: "uefa.champions", displayName: "Champions League")

/// Today's kickoff, so a Pinned Match's day is the browsed day. Computed on
/// each use, so it is today for whichever test reads it.
private var todayKickoff: Date {
    Calendar.current.startOfDay(for: Date()).addingTimeInterval(20 * 3600)
}

private var arsenalChelsea: Match {
    makeMatch(id: "1", competitionSlug: "eng.1", state: .upcoming,
              statusDetail: "8:00 PM", kickoff: todayKickoff)
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
private var parisBayernLive: Match {
    makeMatch(id: "2", competitionSlug: "uefa.champions", state: .inProgress,
              statusDetail: "12'", score: Score(home: 1, away: 0),
              kickoff: todayKickoff, home: paris, away: bayern)
}
