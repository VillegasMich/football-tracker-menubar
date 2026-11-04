import Foundation
@testable import FootballMenuBar

/// A data source whose outcome per Competition each test sets, and can change
/// between fetches. A Competition with no outcome set succeeds with no
/// Matches. The day asked for is ignored. Records the Competitions of every
/// request, in the order they were asked for.
final class FakeMatchDataProvider: MatchDataProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [String: Result<[Match], MatchDataError>] = [:]
    private var requests: [[String]] = []

    /// The slugs of each request so far, one array per request.
    var requestedSlugs: [[String]] { lock.withLock { requests } }

    /// The Competition's next fetches return these Matches.
    func succeed(_ competition: Competition, with matches: [Match]) {
        lock.withLock { outcomes[competition.slug] = .success(matches) }
    }

    /// The Competition's next fetches fail, as on a network error.
    func fail(_ competition: Competition) {
        lock.withLock {
            outcomes[competition.slug] = .failure(.network(underlying: URLError(.notConnectedToInternet)))
        }
    }

    func matches(for competitions: [Competition], on day: Date) async -> CompetitionResults {
        lock.withLock {
            requests.append(competitions.map(\.slug))
            return Dictionary(uniqueKeysWithValues: competitions.map {
                ($0.slug, outcomes[$0.slug] ?? .success([]))
            })
        }
    }
}
