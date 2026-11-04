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

/// Today's kickoff, so a Pinned Match's day is the browsed day.
private let todayKickoff = Calendar.current.startOfDay(for: Date()).addingTimeInterval(20 * 3600)

private let arsenalChelsea = makeMatch(id: "1", competitionSlug: "eng.1", state: .upcoming,
                                       statusDetail: "8:00 PM", kickoff: todayKickoff)
private let bayern = Team(id: "132", name: "Bayern Munich", abbreviation: "BAY", logoURL: nil)
private let parisBayern = makeMatch(id: "2", competitionSlug: "uefa.champions", state: .upcoming,
                                    statusDetail: "8:00 PM", kickoff: todayKickoff,
                                    home: paris, away: bayern)
private let parisBayernLive = makeMatch(id: "2", competitionSlug: "uefa.champions", state: .inProgress,
                                        statusDetail: "12'", score: Score(home: 1, away: 0),
                                        kickoff: todayKickoff, home: paris, away: bayern)
