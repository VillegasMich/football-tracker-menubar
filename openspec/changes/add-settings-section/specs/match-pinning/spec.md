## MODIFIED Requirements

### Requirement: Menu bar title reflects the pinned match

When a match is pinned, the system SHALL render the menu bar title as a text ticker for that match, driven by the pinned match's own snapshot (the ticker feed) independent of which day the user is browsing. The ticker SHALL show the home and away team abbreviations together with content that reflects the match state — the current score while in-progress, the kickoff time while upcoming, and the final score when finished — and SHALL update as the pinned match's data refreshes. The abbreviations shown SHALL be the effective (overridden) abbreviations per the `team-abbreviation-overrides` capability. While the pinned match is in-progress AND the "show live indicator" setting is on (per the `app-settings` capability), the title SHALL additionally render a live status indicator styled after the popover's live pill; when the "include match minute" setting is also on, that indicator SHALL include the match minute/status detail, and otherwise it SHALL be a compact indicator without the minute. When the "show live indicator" setting is off, the title SHALL render as before with no live indicator.

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

#### Scenario: Live indicator with match minute
- **WHEN** the pinned match is in-progress and both "show live indicator" and "include match minute" are on
- **THEN** the title renders a live indicator that includes the match minute/status detail alongside the score

#### Scenario: Live indicator without match minute
- **WHEN** the pinned match is in-progress, "show live indicator" is on, and "include match minute" is off
- **THEN** the title renders a compact live indicator without the match minute

#### Scenario: Live indicator disabled
- **WHEN** the pinned match is in-progress and "show live indicator" is off
- **THEN** the title shows the abbreviations and score with no live indicator

#### Scenario: Indicator only while in-progress
- **WHEN** the pinned match is upcoming or finished
- **THEN** the title shows no live indicator regardless of the live-indicator settings

#### Scenario: Overridden abbreviations in the title
- **WHEN** the pinned match's home or away team has an abbreviation override
- **THEN** the title uses the override in place of the ESPN abbreviation
