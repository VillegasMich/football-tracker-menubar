import Foundation

/// `MatchDataProvider` backed by ESPN's unofficial scoreboard endpoint:
/// `site.api.espn.com/apis/site/v2/sports/soccer/{slug}/scoreboard`.
/// Free, no API key. All ESPN-specific shape lives here so the risk of the
/// unofficial endpoint changing is contained to this one file.
struct ESPNProvider: MatchDataProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Scoreboard URL for a league on a specific day. The `dates=` query is the
    /// one place the day→endpoint mapping lives: it maps the day to the single
    /// `YYYYMMDD` of its local calendar date, so the query matches the date the
    /// user sees in the header. A future fix for late-night kickoffs that ESPN
    /// files under an adjacent day (design D5) can widen this to a 2-day range
    /// here without touching callers.
    private func scoreboardURL(slug: String, day: Date) -> URL {
        var components = URLComponents(string: "https://site.api.espn.com/apis/site/v2/sports/soccer/\(slug)/scoreboard")!
        components.queryItems = [URLQueryItem(name: "dates", value: Self.espnDay(day))]
        return components.url!
    }

    /// Formats a day as ESPN's `YYYYMMDD` using its local calendar date.
    private static func espnDay(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: day)
    }

    func matches(for leagues: [League], on day: Date) async throws -> [Match] {
        // One scoreboard call per league, fetched concurrently and merged.
        try await withThrowingTaskGroup(of: [Match].self) { group in
            for league in leagues {
                group.addTask { try await self.matches(for: league, on: day) }
            }
            var all: [Match] = []
            for try await leagueMatches in group {
                all.append(contentsOf: leagueMatches)
            }
            return all
        }
    }

    private func matches(for league: League, on day: Date) async throws -> [Match] {
        let request = URLRequest(url: scoreboardURL(slug: league.slug, day: day))
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MatchDataError.network(underlying: error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw MatchDataError.badResponse(status: http.statusCode)
        }

        let payload: Scoreboard
        do {
            payload = try JSONDecoder().decode(Scoreboard.self, from: data)
        } catch {
            throw MatchDataError.decoding(underlying: error)
        }

        return payload.events.compactMap { $0.toMatch(leagueSlug: league.slug) }
    }
}

// MARK: - ESPN response DTOs (private to this file)

private struct Scoreboard: Decodable {
    let events: [Event]
}

private struct Event: Decodable {
    let id: String
    let date: String
    let status: Status
    let competitions: [Competition]

    struct Status: Decodable {
        let type: StatusType
        struct StatusType: Decodable {
            let state: String
            let shortDetail: String?
            let detail: String?
        }
    }

    struct Competition: Decodable {
        let competitors: [Competitor]
        struct Competitor: Decodable {
            let homeAway: String
            let score: String?
            let team: TeamDTO
            struct TeamDTO: Decodable {
                let id: String
                let displayName: String
                let abbreviation: String?
                /// ESPN team crest URL, e.g.
                /// `https://a.espncdn.com/i/teamlogos/soccer/500/359.png`.
                /// Absent for some teams; `URL(string:)` also yields nil on a
                /// malformed value, so a missing logo is non-fatal.
                let logo: String?
            }
        }
    }

    /// Maps an ESPN event to the app's `Match`, or nil if it lacks the two
    /// competitors we require.
    func toMatch(leagueSlug: String) -> Match? {
        guard let competition = competitions.first else { return nil }
        guard
            let homeC = competition.competitors.first(where: { $0.homeAway == "home" }),
            let awayC = competition.competitors.first(where: { $0.homeAway == "away" })
        else { return nil }

        let home = Team(id: homeC.team.id,
                        name: homeC.team.displayName,
                        abbreviation: homeC.team.abbreviation ?? "",
                        logoURL: homeC.team.logo.flatMap(URL.init(string:)))
        let away = Team(id: awayC.team.id,
                        name: awayC.team.displayName,
                        abbreviation: awayC.team.abbreviation ?? "",
                        logoURL: awayC.team.logo.flatMap(URL.init(string:)))
        let score = Score(home: Int(homeC.score ?? "") ?? 0,
                          away: Int(awayC.score ?? "") ?? 0)

        return Match(
            id: id,
            leagueSlug: leagueSlug,
            home: home,
            away: away,
            score: score,
            state: MatchState(espnState: status.type.state),
            statusDetail: status.type.shortDetail ?? status.type.detail ?? "",
            kickoff: Self.parseDate(date) ?? .distantFuture
        )
    }

    /// ESPN dates come as ISO8601 with or without seconds (e.g.
    /// `2026-07-02T19:00Z`). Try both, and full ISO8601 as a fallback.
    private static func parseDate(_ string: String) -> Date? {
        for format in ["yyyy-MM-dd'T'HH:mm'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'"] {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = format
            if let d = f.date(from: string) { return d }
        }
        return ISO8601DateFormatter().date(from: string)
    }
}
