import Foundation

/// One side of a match. ESPN identifies teams by a numeric id (as a string)
/// and gives both a full display name and a short abbreviation. ESPN also
/// exposes a team crest/logo URL, kept optional so a missing logo degrades to
/// the abbreviation rather than failing.
struct Team: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let abbreviation: String
    let logoURL: URL?
}
