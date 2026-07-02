# menu-bar-display Specification

## Purpose

Defines how matches are presented in the menu bar popover, including grouping, empty/error states, the relevant-match window, and menu bar controls.

## Requirements

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

### Requirement: Relevant-match window

The system SHALL only display matches relevant to the current day: any in-progress match, plus matches kicking off from the start of today through a configurable upcoming horizon (default: today only). Finished matches from previous days and fixtures beyond the horizon SHALL be excluded.

#### Scenario: Today's matches shown
- **WHEN** a match is live, or kicks off today
- **THEN** it appears in the popover

#### Scenario: Past finished matches hidden
- **WHEN** a match finished on a previous day
- **THEN** it does not appear in the popover

#### Scenario: Far-future fixtures hidden
- **WHEN** an upcoming match kicks off beyond the upcoming horizon (e.g. an out-of-season league's next fixture weeks away)
- **THEN** it does not appear in the popover
- **AND** its league section is omitted if it has no other matches to show

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
