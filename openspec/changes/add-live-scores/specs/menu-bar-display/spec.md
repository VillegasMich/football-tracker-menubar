## ADDED Requirements

### Requirement: Match list in the menu bar popover

The system SHALL present the current matches in the menu bar popover, grouped by league, each match showing its two teams, the score, and a status detail. The `MenuBarExtra` SHALL use the window style so the content can be a scrollable SwiftUI view rather than flat menu items.

#### Scenario: Matches grouped by league
- **WHEN** the popover opens and matches are available
- **THEN** matches are listed grouped under their league's display name

#### Scenario: Each match shows teams, score, and status
- **WHEN** a match is displayed
- **THEN** it shows both team names, the current score, and a status detail (kickoff time if upcoming, live minute if in-progress, final if finished)

#### Scenario: Live matches are distinguishable
- **WHEN** a match is in-progress
- **THEN** it is visually distinguishable from upcoming and finished matches

### Requirement: Empty and error states

The system SHALL render a clear non-crashing state when there are no matches (e.g. an off-season league returns an empty scoreboard) or when fetching failed.

#### Scenario: No matches to show
- **WHEN** the selected leagues return no matches
- **THEN** the popover shows an explanatory empty state rather than a blank or broken view

#### Scenario: Fetch failed
- **WHEN** the latest fetch failed and no cached matches are available
- **THEN** the popover shows an error state with a way to retry

### Requirement: Menu bar controls

The system SHALL keep the ⚽ menu bar label and provide, within the popover, controls to refresh now and to quit the app.

#### Scenario: Refresh and quit available
- **WHEN** the popover is open
- **THEN** it offers a Refresh control that triggers an immediate refresh
- **AND** a Quit control that terminates the app
