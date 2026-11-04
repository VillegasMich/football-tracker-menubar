import Testing
@testable import FootballMenuBar

/// The fixed catalogue of Competitions a user can follow, checked against the
/// table in the Followed Competitions spec (#18).
@Suite("Competition catalogue")
struct CompetitionCatalogueTests {
    @Test("The catalogue lists the spec's 37 Competitions, in order, with their names and regions")
    func catalogueMatchesSpec() {
        let expected: [(slug: String, name: String, region: String)] = [
            ("eng.1", "Premier League", "England"),
            ("eng.2", "Championship", "England"),
            ("eng.3", "League One", "England"),
            ("eng.4", "League Two", "England"),
            ("eng.fa", "FA Cup", "England"),
            ("eng.league_cup", "Carabao Cup", "England"),
            ("eng.charity", "Community Shield", "England"),
            ("eng.w.1", "Women's Super League", "England"),
            ("esp.1", "LaLiga", "Spain"),
            ("esp.copa_del_rey", "Copa del Rey", "Spain"),
            ("ger.1", "Bundesliga", "Germany"),
            ("ger.dfb_pokal", "DFB-Pokal", "Germany"),
            ("ita.1", "Serie A", "Italy"),
            ("ita.coppa_italia", "Coppa Italia", "Italy"),
            ("fra.1", "Ligue 1", "France"),
            ("fra.coupe_de_france", "Coupe de France", "France"),
            ("por.1", "Primeira Liga", "Rest of the world"),
            ("ned.1", "Eredivisie", "Rest of the world"),
            ("sco.1", "Scottish Premiership", "Rest of the world"),
            ("tur.1", "Süper Lig", "Rest of the world"),
            ("bel.1", "Belgian Pro League", "Rest of the world"),
            ("ksa.1", "Saudi Pro League", "Rest of the world"),
            ("uefa.champions", "Champions League", "UEFA"),
            ("uefa.europa", "Europa League", "UEFA"),
            ("uefa.europa.conf", "Conference League", "UEFA"),
            ("uefa.nations", "Nations League", "UEFA"),
            ("uefa.super_cup", "Super Cup", "UEFA"),
            ("uefa.euro", "Euro", "UEFA"),
            ("usa.1", "MLS", "Americas"),
            ("mex.1", "Liga MX", "Americas"),
            ("bra.1", "Brasileirão", "Americas"),
            ("arg.1", "Argentine Liga Profesional", "Americas"),
            ("conmebol.libertadores", "Copa Libertadores", "Americas"),
            ("conmebol.sudamericana", "Copa Sudamericana", "Americas"),
            ("conmebol.america", "Copa América", "Americas"),
            ("fifa.world", "World Cup", "FIFA"),
            ("fifa.cwc", "Club World Cup", "FIFA"),
        ]

        let catalogue = Competition.catalogue
        #expect(catalogue.count == 37)
        #expect(Set(catalogue.map(\.slug)).count == 37)
        #expect(catalogue.map(\.slug) == expected.map(\.slug))
        #expect(catalogue.map(\.displayName) == expected.map(\.name))
        #expect(catalogue.map(\.region.displayName) == expected.map(\.region))
    }

    @Test("The regions are listed in the spec's order")
    func regionOrder() {
        #expect(Competition.Region.allCases.map(\.displayName) == [
            "England", "Spain", "Germany", "Italy", "France",
            "Rest of the world", "UEFA", "Americas", "FIFA",
        ])
    }

    @Test("The default Followed Competitions are the World Cup, Premier League and Champions League")
    func defaults() {
        #expect(Set(Competition.defaultFollowed.map(\.slug)) == ["fifa.world", "eng.1", "uefa.champions"])
    }
}
