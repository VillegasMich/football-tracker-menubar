## MODIFIED Requirements

### Requirement: State-driven refresh cadence

The system SHALL auto-refresh matches on an interval that depends on live play: while any selected match is in-progress the store SHALL poll on a fast interval (LIVE mode, ~30–60s), and otherwise it SHALL poll on a slow interval (IDLE mode, ~5–15 min). Additionally, when a match is pinned and that pinned match is upcoming and kicks off today, the store SHALL poll on the fast (LIVE) interval so the menu bar title flips to the live score promptly at kickoff. The mode SHALL be recomputed after each fetch from the current matches and the current pin.

#### Scenario: Fast polling while a match is live
- **WHEN** at least one selected match has `MatchState` in-progress
- **THEN** the store refreshes on the fast (LIVE) interval

#### Scenario: Fast polling for a pinned upcoming match today
- **WHEN** no match is in-progress but a pinned match is upcoming and kicks off today
- **THEN** the store refreshes on the fast (LIVE) interval

#### Scenario: Back off when nothing is live
- **WHEN** no selected match is in-progress and no pinned upcoming match kicks off today
- **THEN** the store refreshes on the slow (IDLE) interval

#### Scenario: Mode transitions as play starts and ends
- **WHEN** a fetch changes whether any match is in-progress
- **THEN** the next refresh uses the interval for the new mode
