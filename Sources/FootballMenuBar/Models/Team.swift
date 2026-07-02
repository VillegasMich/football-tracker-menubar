import Foundation

/// One side of a match. ESPN identifies teams by a numeric id (as a string)
/// and gives both a full display name and a short abbreviation.
struct Team: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let abbreviation: String
}
