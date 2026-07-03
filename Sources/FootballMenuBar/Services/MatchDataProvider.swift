import Foundation

/// The seam for all match data. The store depends on this protocol, never on a
/// concrete source, so ESPN can be swapped or given a fallback (e.g.
/// football-data.org) without touching the store or views.
protocol MatchDataProvider: Sendable {
    /// Returns the matches for the given leagues on the given day. Implementations
    /// should fetch concurrently where possible and throw rather than crash on
    /// failure.
    func matches(for leagues: [League], on day: Date) async throws -> [Match]
}

/// Errors surfaced by a provider so callers can contain the failure.
enum MatchDataError: Error {
    case network(underlying: Error)
    case decoding(underlying: Error)
    case badResponse(status: Int)
}
