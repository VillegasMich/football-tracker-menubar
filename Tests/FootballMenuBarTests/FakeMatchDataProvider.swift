import Foundation
@testable import FootballMenuBar

/// A data source whose outcome per Competition each test sets, and can change
/// between fetches. A Competition with no outcome set succeeds with no
/// Matches. The day asked for is ignored. Records the Competitions of every
/// request, in the order they were asked for. A request can be held in
/// flight, to see what happens meanwhile.
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

    // MARK: - Holding a request in flight

    private var holdsNextRequest = false
    private var isHoldingRequest = false
    private var heldRequest: CheckedContinuation<Void, Never>?
    private var heldRequestWaiter: CheckedContinuation<Void, Never>?

    /// The next request stays in flight, with its outcome already taken,
    /// until `releaseHeldRequest()`.
    func holdNextRequest() {
        lock.withLock { holdsNextRequest = true }
    }

    /// Returns once the held request is in flight.
    func heldRequestArrived() async {
        await withCheckedContinuation { waiter in
            let arrived = lock.withLock {
                if isHoldingRequest { return true }
                heldRequestWaiter = waiter
                return false
            }
            if arrived { waiter.resume() }
        }
    }

    /// Lets the held request return.
    func releaseHeldRequest() {
        let held = lock.withLock {
            isHoldingRequest = false
            defer { heldRequest = nil }
            return heldRequest
        }
        held?.resume()
    }

    func matches(for competitions: [Competition], on day: Date) async -> CompetitionResults {
        let (results, holds) = lock.withLock {
            requests.append(competitions.map(\.slug))
            let results = Dictionary(uniqueKeysWithValues: competitions.map {
                ($0.slug, outcomes[$0.slug] ?? .success([]))
            })
            defer { holdsNextRequest = false }
            return (results, holdsNextRequest)
        }
        if holds {
            await withCheckedContinuation { held in
                let waiter = lock.withLock {
                    heldRequest = held
                    isHoldingRequest = true
                    defer { heldRequestWaiter = nil }
                    return heldRequestWaiter
                }
                waiter?.resume()
            }
        }
        return results
    }
}
