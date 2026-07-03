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

The system SHALL render a clear non-crashing state when the selected day has no matches (e.g. an off-day, or an off-season league returns an empty scoreboard) or when fetching failed. The empty state SHALL refer to the selected day rather than implying "today," and SHALL offer a way back to today when the selected day is not today.

#### Scenario: No matches on the selected day
- **WHEN** the selected leagues return no matches for the selected day
- **THEN** the popover shows an explanatory empty state naming the selected day rather than a blank or broken view
- **AND** when the selected day is not today, it offers a way to return to today

#### Scenario: Fetch failed
- **WHEN** the latest fetch failed and no matches are available to show
- **THEN** the popover shows an error state with a way to retry

### Requirement: Relevant-match window

The system SHALL display the matches for the currently selected day (per the `date-navigation` capability), grouped by league. The selected day defaults to today. When the selected day is today, any in-progress match SHALL also be shown even if the data source reports it under an adjacent day. Matches that do not belong to the selected day SHALL be excluded.

#### Scenario: Selected day's matches shown
- **WHEN** a day is selected
- **THEN** the popover shows the matches scheduled for that day

#### Scenario: Past day shows its finished matches
- **WHEN** the user selects a past day
- **THEN** that day's finished matches are shown
- **AND** they are not excluded merely for having finished

#### Scenario: Live match always shown on today
- **WHEN** the selected day is today and a match is in-progress
- **THEN** it appears in the popover

#### Scenario: Other days' matches excluded
- **WHEN** a match does not belong to the selected day and is not a live match on today
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
