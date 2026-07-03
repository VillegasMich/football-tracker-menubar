# date-navigation Specification

## Purpose

Defines browsing matches by calendar day: the selected-date model, the header stepper and its controls (previous / next / today), unbounded past and future navigation, per-date fetching, the per-step loading state, and the invariant that browsing never affects the pinned match.

## Requirements

### Requirement: Selected browsing date

The system SHALL maintain a single selected date that determines which day's matches the popover shows. The selected date SHALL default to the current local day when the app launches and SHALL NOT persist across restarts (browsing is transient).

#### Scenario: Defaults to today on launch
- **WHEN** the app launches
- **THEN** the selected date is the current local day
- **AND** the popover shows that day's matches

#### Scenario: Selected date is not restored across restarts
- **WHEN** the user has browsed to a different day and then relaunches the app
- **THEN** the selected date resets to the current local day

### Requirement: Step to adjacent days

The system SHALL provide previous and next controls that move the selected date backward and forward by exactly one calendar day. Navigation SHALL be unbounded in both directions — arbitrarily far into the past and future — limited only by what the data source returns for a given day.

#### Scenario: Step backward one day
- **WHEN** the user activates the previous control
- **THEN** the selected date moves back by one calendar day
- **AND** the popover shows that day's matches

#### Scenario: Step forward one day
- **WHEN** the user activates the next control
- **THEN** the selected date moves forward by one calendar day
- **AND** the popover shows that day's matches

#### Scenario: Navigation is unbounded
- **WHEN** the user steps repeatedly in either direction
- **THEN** there is no fixed limit imposed by the app on how far the selected date can move

### Requirement: Return to today

The system SHALL provide a control to return the selected date to the current local day. The control SHALL be available whenever the selected date is not the current day, and SHALL double as the current-day indicator.

#### Scenario: Jump back to today
- **WHEN** the selected date is not the current day and the user activates the return-to-today control
- **THEN** the selected date becomes the current local day
- **AND** the popover shows today's matches

#### Scenario: Today indicated when current
- **WHEN** the selected date is the current local day
- **THEN** the header indicates the day is today

### Requirement: Per-date fetch with loading state

Changing the selected date SHALL trigger a fresh fetch of that day's matches through the `MatchDataProvider`. While the fetch is in flight the system SHALL show a loading state and keep the previously shown day's list visible until the new results arrive, rather than flashing an empty popover. The stepper controls SHALL not initiate a new step while a step fetch is already in flight.

#### Scenario: Loading state during a step
- **WHEN** the user changes the selected date
- **THEN** the system fetches that day's matches
- **AND** shows a loading indicator until the fetch completes

#### Scenario: Previous list retained until new data arrives
- **WHEN** a step fetch is in flight
- **THEN** the popover continues to show the prior day's list rather than an empty view
- **AND** replaces it once the new day's matches load

#### Scenario: Out-of-order results ignored
- **WHEN** a step fetch completes for a day that is no longer the selected date
- **THEN** its results are discarded and do not replace the current day's list

### Requirement: Browsing does not affect the pinned match

The selected date SHALL be independent of the pinned match. Changing the selected date SHALL NOT change which match is pinned, and SHALL NOT alter the menu bar title, which continues to reflect the pinned match per the `match-pinning` capability.

#### Scenario: Browsing away from the pinned match's day
- **WHEN** a match is pinned and the user browses to a different day
- **THEN** the pinned match remains pinned
- **AND** the menu bar title continues to reflect the pinned match, not the browsed day
