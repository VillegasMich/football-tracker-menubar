# match-pinning Specification

## Purpose

Defines pinning a single match so the menu bar title becomes a live text ticker for it, including the single-pin invariant, persistence of the selection, the title's state-driven content, and the ⚽ fallback.

## Requirements

### Requirement: Pin a single match

The system SHALL allow the user to pin exactly one match at a time. Pinning is single-select: pinning a match SHALL replace any previously pinned match. The user SHALL be able to unpin the currently pinned match, leaving no match pinned.

#### Scenario: Pin a match
- **WHEN** the user pins a match while no match is pinned
- **THEN** that match becomes the pinned match

#### Scenario: Pinning replaces the previous pin
- **WHEN** a match is already pinned and the user pins a different match
- **THEN** the newly pinned match replaces it
- **AND** only one match is pinned at any time

#### Scenario: Unpin the pinned match
- **WHEN** the user unpins the currently pinned match
- **THEN** no match is pinned

### Requirement: Pinned selection persists across restarts

The system SHALL persist the pinned match's identity together with the pinned match's day (in `UserDefaults`) so that the pin — and its menu bar ticker — can be restored when the app relaunches. On launch, if a pin is persisted, the system SHALL fetch the pinned match's day to repopulate the ticker without requiring the user to browse to that day.

#### Scenario: Pin and ticker restored after restart
- **WHEN** a match is pinned and the app is relaunched
- **THEN** the same match is still pinned
- **AND** the menu bar ticker is restored by fetching the pinned match's persisted day, without the user browsing to it

#### Scenario: No pin persisted
- **WHEN** no match is pinned and the app is relaunched
- **THEN** no match is pinned after launch

#### Scenario: Legacy pin without a persisted day
- **WHEN** a pin persisted by an earlier version has no stored day
- **THEN** the app treats the pinned match's day as today for the purpose of restoring the ticker
- **AND** does not crash or clear the pin

### Requirement: Menu bar title reflects the pinned match

When a match is pinned, the system SHALL render the menu bar title as a text ticker for that match, driven by the pinned match's own snapshot (the ticker feed) independent of which day the user is browsing. The ticker SHALL show the home and away team abbreviations together with content that reflects the match state — the current score while in-progress, the kickoff time while upcoming, and the final score when finished — and SHALL update as the pinned match's data refreshes.

#### Scenario: Live pinned match shows the score
- **WHEN** the pinned match is in-progress
- **THEN** the menu bar title shows the home and away abbreviations and the current score

#### Scenario: Upcoming pinned match shows the kickoff time
- **WHEN** the pinned match is upcoming
- **THEN** the menu bar title shows the home and away abbreviations and the kickoff time

#### Scenario: Finished pinned match shows the final score
- **WHEN** the pinned match is finished
- **THEN** the menu bar title shows the home and away abbreviations and the final score

#### Scenario: Title updates on refresh
- **WHEN** the pinned match's score changes on a refresh
- **THEN** the menu bar title updates to reflect the new score without reopening the popover

#### Scenario: Title unaffected by browsing another day
- **WHEN** the user browses to a day other than the pinned match's day
- **THEN** the menu bar title continues to show the pinned match's ticker from its snapshot
- **AND** does not fall back to the soccerball merely because the pinned match is absent from the browsed day

### Requirement: Fallback title when nothing is pinned

The system SHALL display the ⚽ soccerball as the menu bar title when no match is pinned, or when the pinned match can no longer be resolved from its own day's feed (e.g. it was postponed or removed from the schedule).

#### Scenario: No match pinned
- **WHEN** no match is pinned
- **THEN** the menu bar title shows the ⚽ soccerball

#### Scenario: Pinned match no longer on its day
- **WHEN** a match is pinned but is no longer present in a fetch of its own day
- **THEN** the menu bar title shows the ⚽ soccerball
