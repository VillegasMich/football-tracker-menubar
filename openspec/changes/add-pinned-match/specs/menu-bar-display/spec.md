## ADDED Requirements

### Requirement: Team logos in match rows

Each match row in the popover SHALL display each team's logo when available, loaded asynchronously from the team's logo URL and cached in memory to avoid re-fetching. When a logo is missing, still loading, or fails to load, the row SHALL fall back to the team's abbreviation rendered in uppercase. Logos SHALL appear in the popover rows only, not in the menu bar title.

#### Scenario: Logo shown when available
- **WHEN** a team in a displayed row has a logo URL and the image loads
- **THEN** the row shows the team's logo

#### Scenario: Fallback to uppercase abbreviation
- **WHEN** a team has no logo URL, or its logo fails to load
- **THEN** the row shows the team's abbreviation in uppercase in place of the logo

#### Scenario: Logos cached across popover opens
- **WHEN** a logo has already been loaded once
- **THEN** reopening the popover reuses the cached image rather than re-fetching it

### Requirement: Pin control in match rows

Each match row SHALL provide a control to pin or unpin that match. The control SHALL indicate whether the row's match is the currently pinned one.

#### Scenario: Pin from a row
- **WHEN** the user activates the pin control on an unpinned row
- **THEN** that match becomes the pinned match

#### Scenario: Pinned row is indicated
- **WHEN** a row's match is the currently pinned match
- **THEN** its pin control is shown in a pinned (active) state distinct from unpinned rows

#### Scenario: Unpin from the pinned row
- **WHEN** the user activates the pin control on the currently pinned row
- **THEN** the match is unpinned

## MODIFIED Requirements

### Requirement: Menu bar controls

The system SHALL provide, within the popover, controls to refresh now and to quit the app. The menu bar label SHALL be defined by the `match-pinning` capability: it shows a text ticker for the pinned match when one is pinned and present in the feed, and otherwise falls back to the ⚽ soccerball.

#### Scenario: Refresh and quit available
- **WHEN** the popover is open
- **THEN** it offers a Refresh control that triggers an immediate refresh
- **AND** a Quit control that terminates the app

#### Scenario: Label reflects pin state
- **WHEN** no match is pinned
- **THEN** the menu bar label shows the ⚽ soccerball
- **AND** when a match is pinned and present in the feed, the label shows the pinned-match ticker instead
