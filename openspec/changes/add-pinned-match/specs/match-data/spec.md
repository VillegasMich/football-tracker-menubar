## MODIFIED Requirements

### Requirement: Match data models

The system SHALL represent match data as Codable value types: `League`, `Match`, `Team`, `Score`, and a `MatchState`. `MatchState` SHALL distinguish upcoming, in-progress, and finished matches, derived from ESPN's per-event `state` values `pre`, `in`, and `post`. `Team` SHALL carry an optional logo URL, populated from the ESPN scoreboard team payload when present.

#### Scenario: State derived from ESPN event state
- **WHEN** an ESPN event reports `state` of `pre`, `in`, or `post`
- **THEN** the corresponding `Match` has `MatchState` of upcoming, in-progress, or finished respectively

#### Scenario: A match carries teams, score, and status
- **WHEN** a match is decoded from a scoreboard response
- **THEN** it exposes its two teams, the current score, and a status detail (kickoff time, live minute, or final result)

#### Scenario: Team logo URL decoded when present
- **WHEN** an ESPN team payload includes a `logo` URL
- **THEN** the decoded `Team` carries that logo URL

#### Scenario: Team logo URL absent
- **WHEN** an ESPN team payload has no `logo` URL
- **THEN** the decoded `Team` has no logo URL and remains valid
