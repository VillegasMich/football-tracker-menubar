import Foundation

/// A football Competition, keyed by its ESPN scoreboard slug. Each Competition maps
/// to one scoreboard request: `.../soccer/{slug}/scoreboard`.
struct Competition: Codable, Identifiable, Hashable, Sendable {
    /// ESPN slug, e.g. `fifa.world`. Doubles as the stable identity.
    let slug: String
    let displayName: String
    /// The group the Competition is listed under in the Competition picker.
    let region: Region

    var id: String { slug }

    /// The groups of the catalogue, in the order the picker lists them.
    enum Region: String, CaseIterable, Codable, Hashable, Sendable {
        case england, spain, germany, italy, france, restOfTheWorld, uefa, americas, fifa

        var displayName: String {
            switch self {
            case .england: return "England"
            case .spain: return "Spain"
            case .germany: return "Germany"
            case .italy: return "Italy"
            case .france: return "France"
            case .restOfTheWorld: return "Rest of the world"
            case .uefa: return "UEFA"
            case .americas: return "Americas"
            case .fifa: return "FIFA"
            }
        }
    }
}

extension Competition {
    /// Every Competition a user can follow, in the curated order the match list
    /// and the picker use. Slugs were verified against the Primary Source;
    /// qualifying rounds are left out.
    static let catalogue: [Competition] = [
        Competition(slug: "eng.1", displayName: "Premier League", region: .england),
        Competition(slug: "eng.2", displayName: "Championship", region: .england),
        Competition(slug: "eng.3", displayName: "League One", region: .england),
        Competition(slug: "eng.4", displayName: "League Two", region: .england),
        Competition(slug: "eng.fa", displayName: "FA Cup", region: .england),
        Competition(slug: "eng.league_cup", displayName: "Carabao Cup", region: .england),
        Competition(slug: "eng.charity", displayName: "Community Shield", region: .england),
        Competition(slug: "eng.w.1", displayName: "Women's Super League", region: .england),
        Competition(slug: "esp.1", displayName: "LaLiga", region: .spain),
        Competition(slug: "esp.copa_del_rey", displayName: "Copa del Rey", region: .spain),
        Competition(slug: "ger.1", displayName: "Bundesliga", region: .germany),
        Competition(slug: "ger.dfb_pokal", displayName: "DFB-Pokal", region: .germany),
        Competition(slug: "ita.1", displayName: "Serie A", region: .italy),
        Competition(slug: "ita.coppa_italia", displayName: "Coppa Italia", region: .italy),
        Competition(slug: "fra.1", displayName: "Ligue 1", region: .france),
        Competition(slug: "fra.coupe_de_france", displayName: "Coupe de France", region: .france),
        Competition(slug: "por.1", displayName: "Primeira Liga", region: .restOfTheWorld),
        Competition(slug: "ned.1", displayName: "Eredivisie", region: .restOfTheWorld),
        Competition(slug: "sco.1", displayName: "Scottish Premiership", region: .restOfTheWorld),
        Competition(slug: "tur.1", displayName: "Süper Lig", region: .restOfTheWorld),
        Competition(slug: "bel.1", displayName: "Belgian Pro League", region: .restOfTheWorld),
        Competition(slug: "ksa.1", displayName: "Saudi Pro League", region: .restOfTheWorld),
        Competition(slug: "uefa.champions", displayName: "Champions League", region: .uefa),
        Competition(slug: "uefa.europa", displayName: "Europa League", region: .uefa),
        Competition(slug: "uefa.europa.conf", displayName: "Conference League", region: .uefa),
        Competition(slug: "uefa.nations", displayName: "Nations League", region: .uefa),
        Competition(slug: "uefa.super_cup", displayName: "Super Cup", region: .uefa),
        Competition(slug: "uefa.euro", displayName: "Euro", region: .uefa),
        Competition(slug: "usa.1", displayName: "MLS", region: .americas),
        Competition(slug: "mex.1", displayName: "Liga MX", region: .americas),
        Competition(slug: "bra.1", displayName: "Brasileirão", region: .americas),
        Competition(slug: "arg.1", displayName: "Argentine Liga Profesional", region: .americas),
        Competition(slug: "conmebol.libertadores", displayName: "Copa Libertadores", region: .americas),
        Competition(slug: "conmebol.sudamericana", displayName: "Copa Sudamericana", region: .americas),
        Competition(slug: "conmebol.america", displayName: "Copa América", region: .americas),
        Competition(slug: "fifa.world", displayName: "World Cup", region: .fifa),
        Competition(slug: "fifa.cwc", displayName: "Club World Cup", region: .fifa),
    ]

    /// The Followed Competitions on first launch, and whenever nothing valid
    /// is stored: the three the app showed before the picker existed, in
    /// catalogue order.
    static let defaultFollowed: [Competition] = catalogue.filter {
        ["fifa.world", "eng.1", "uefa.champions"].contains($0.slug)
    }
}
