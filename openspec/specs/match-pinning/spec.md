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

The system SHALL persist the pinned match's identity (in `UserDefaults`) so that the pin is restored when the app relaunches.

#### Scenario: Pin restored after restart
- **WHEN** a match is pinned and the app is relaunched
- **THEN** the same match is still pinned once matches are loaded

#### Scenario: No pin persisted
- **WHEN** no match is pinned and the app is relaunched
- **THEN** no match is pinned after launch

### Requirement: Menu bar title reflects the pinned match

When a match is pinned and present in the current feed, the system SHALL render the menu bar title as a text ticker for that match: the home and away team abbreviations together with content that reflects the match state — the current score while in-progress, the kickoff time while upcoming, and the final score when finished. The title SHALL update as the pinned match's data refreshes.

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

### Requirement: Fallback title when nothing is pinned

The system SHALL display the ⚽ soccerball as the menu bar title when no match is pinned, or when the pinned match is not present in the current feed (e.g. it has rolled out of the relevant-match window).

#### Scenario: No match pinned
- **WHEN** no match is pinned
- **THEN** the menu bar title shows the ⚽ soccerball

#### Scenario: Pinned match absent from the feed
- **WHEN** a match is pinned but is not present in the current matches
- **THEN** the menu bar title shows the ⚽ soccerball
