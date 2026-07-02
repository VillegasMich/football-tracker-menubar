## MODIFIED Requirements

### Requirement: Pluggable match data provider

The system SHALL access all football match data through a `MatchDataProvider` abstraction, so the concrete data source can be replaced or supplemented without changing the store or views. The provider SHALL accept a set of leagues and a specific day, and return the matches for those leagues on that day.

#### Scenario: Store depends only on the abstraction
- **WHEN** the store fetches matches
- **THEN** it calls the `MatchDataProvider` interface
- **AND** it has no compile-time dependency on any specific data source (e.g. ESPN)

#### Scenario: Provider returns matches for requested leagues on the requested day
- **WHEN** the provider is asked for matches for a set of leagues on a given day
- **THEN** it returns the matches belonging to those leagues scheduled for that day and no others

### Requirement: ESPN provider implementation

The system SHALL provide an ESPN-backed implementation of `MatchDataProvider` that reads the ESPN scoreboard endpoint `site.api.espn.com/apis/site/v2/sports/soccer/{slug}/scoreboard` for each requested league using `async/await` and `URLSession`, with no API key. For a requested day the provider SHALL pass that day to the endpoint via the `dates=YYYYMMDD` query parameter (UTC), rather than relying on the endpoint's default "current" scoreboard.

#### Scenario: Fetch a league scoreboard for a specific day
- **WHEN** the ESPN provider fetches a league identified by ESPN slug `fifa.world` for a given day
- **THEN** it requests the scoreboard endpoint for that slug with `dates=YYYYMMDD` set to that day
- **AND** it decodes the response into the app's match models

#### Scenario: Multiple leagues fetched per request
- **WHEN** the provider is asked for matches across several leagues on a day
- **THEN** it issues one scoreboard request per league for that day
- **AND** merges the results into a single collection of matches

#### Scenario: Past and future days are fetchable
- **WHEN** the provider is asked for a day in the past or the future
- **THEN** it requests that day via `dates=YYYYMMDD` and returns the matches the endpoint reports for it (including finished matches for past days)

#### Scenario: Endpoint failure is surfaced, not crashed
- **WHEN** a scoreboard request fails (network error or a response that cannot be decoded)
- **THEN** the provider throws an error rather than crashing
- **AND** the failure is attributable to the provider so it can be contained or replaced
