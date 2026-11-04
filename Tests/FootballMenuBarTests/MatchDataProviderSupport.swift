import Foundation
@testable import FootballMenuBar

extension MatchDataProvider {
    /// The Matches of a single Competition on a day, throwing that
    /// Competition's failure.
    func matches(in competition: Competition, on day: Date) async throws -> [Match] {
        let results = await matches(for: [competition], on: day)
        guard let result = results[competition.slug] else {
            throw MissingOutcome(slug: competition.slug)
        }
        return try result.get()
    }
}

/// The data source left out a Competition it was asked for.
struct MissingOutcome: Error {
    let slug: String
}
