## MODIFIED Requirements

### Requirement: State-driven refresh cadence

The system SHALL auto-refresh on an interval that depends on live play across both feeds. The store SHALL poll on a fast interval (LIVE mode, ~30–60s) when the pinned match is in-progress, when a pinned match is upcoming and kicks off today, when the currently browsed day has an in-progress match, or when the currently browsed day is today and has an upcoming match whose kickoff time has been reached but which the feed still reports as upcoming (the "kickoff due" window); otherwise it SHALL poll on a slow interval (IDLE mode, ~5–15 min). On each fast/slow tick the store SHALL refresh the ticker feed for the pinned match (keeping the menu bar title live regardless of the browsed day), and SHALL refresh the browse feed while the browsed day is today OR has a live match. When the browsed day equals the pinned match's day, a single fetch MAY serve both feeds. The mode SHALL be recomputed after each fetch.

#### Scenario: Fast polling while the pinned match is live
- **WHEN** the pinned match is in-progress
- **THEN** the store refreshes on the fast (LIVE) interval
- **AND** the ticker feed is refreshed so the menu bar title stays current even while another day is browsed

#### Scenario: Fast polling for a pinned upcoming match today
- **WHEN** no match is in-progress but a pinned match is upcoming and kicks off today
- **THEN** the store refreshes on the fast (LIVE) interval

#### Scenario: Fast polling while the browsed day is live
- **WHEN** the currently browsed day has an in-progress match
- **THEN** the store refreshes on the fast (LIVE) interval
- **AND** the browse feed is refreshed so the visible list stays current

#### Scenario: Fast polling when a kickoff is due today
- **WHEN** the browsed day is today and has a match whose kickoff time has been reached but which the feed still reports as upcoming
- **THEN** the store refreshes on the fast (LIVE) interval
- **AND** the browse feed is refreshed so the match flips from scheduled to live within one fast interval without a manual reload

#### Scenario: Browse feed refreshes while viewing today with only upcoming matches
- **WHEN** the browsed day is today and all its matches are upcoming (none in-progress)
- **THEN** the browse feed is auto-refreshed on each tick
- **AND** a match that kicks off becomes live in the list without a manual reload

#### Scenario: Browsing a non-today day does not force fast polling
- **WHEN** the browsed day is a day other than today, has no in-progress match, and no pinned match is live or kicking off today
- **THEN** the store refreshes on the slow (IDLE) interval
- **AND** the browse feed is not auto-refreshed for that day

#### Scenario: Back off when nothing is live and no kickoff is due
- **WHEN** the pinned match is neither in-progress nor upcoming-today, no browsed match is in-progress, and today has no upcoming match whose kickoff time has been reached
- **THEN** the store refreshes on the slow (IDLE) interval
