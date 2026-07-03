## MODIFIED Requirements

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

### Requirement: Empty and error states

The system SHALL render a clear non-crashing state when the selected day has no matches (e.g. an off-day, or an off-season league returns an empty scoreboard) or when fetching failed. The empty state SHALL refer to the selected day rather than implying "today," and SHALL offer a way back to today when the selected day is not today.

#### Scenario: No matches on the selected day
- **WHEN** the selected leagues return no matches for the selected day
- **THEN** the popover shows an explanatory empty state naming the selected day rather than a blank or broken view
- **AND** when the selected day is not today, it offers a way to return to today

#### Scenario: Fetch failed
- **WHEN** the latest fetch failed and no matches are available to show
- **THEN** the popover shows an error state with a way to retry
