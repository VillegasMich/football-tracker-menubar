import Foundation

/// The seam for all match data. The store depends on this protocol, never on a
/// concrete source, so ESPN can be swapped or given a Backup Source without
/// touching the store or views.
protocol MatchDataProvider: Sendable {
    /// Returns, for each requested Competition, its Matches on the given day or
    /// its failure. One Competition failing never prevents the others' results.
    /// Implementations should fetch concurrently where possible and never crash
    /// on failure.
    func matches(for competitions: [Competition], on day: Date) async -> CompetitionResults
}

/// Each requested Competition's outcome, keyed by its slug: its Matches, or
/// the reason they couldn't be fetched.
typealias CompetitionResults = [String: Result<[Match], MatchDataError>]

/// Errors surfaced by a provider so callers can contain the failure.
enum MatchDataError: Error {
    case network(underlying: Error)
    case decoding(underlying: Error)
    case badResponse(status: Int)
}
