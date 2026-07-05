## ADDED Requirements

### Requirement: Per-team abbreviation override storage

The system SHALL let the user define an abbreviation override for a team, keyed by the team's stable ESPN id, and SHALL persist the set of overrides in `UserDefaults` so they survive relaunch. Setting an override for a team SHALL replace any prior override for that same team. Clearing an override SHALL remove it, restoring the team's source (ESPN) abbreviation. An empty or whitespace-only override SHALL be treated as clearing it.

#### Scenario: Override persists across relaunch
- **WHEN** the user sets an abbreviation override for a team and the app is relaunched
- **THEN** the override is restored and still applies after launch

#### Scenario: Setting replaces a prior override
- **WHEN** a team already has an override and the user sets a new one for that team
- **THEN** the new override replaces the previous one

#### Scenario: Clearing restores the source abbreviation
- **WHEN** the user clears a team's override
- **THEN** the override is removed
- **AND** the team's ESPN-provided abbreviation is used again

#### Scenario: Empty override clears rather than blanks
- **WHEN** the user sets an override that is empty or only whitespace
- **THEN** it is treated as clearing the override rather than storing a blank abbreviation

### Requirement: Contextual editing of a team's abbreviation

The system SHALL let the user edit a team's abbreviation override contextually from the popover — by right-clicking (context menu) a team in a match row — providing a way to enter a new abbreviation and a way to reset to the ESPN default.

#### Scenario: Set an override from a match row
- **WHEN** the user opens the context menu on a team in a match row and enters a new abbreviation
- **THEN** that team gains the entered abbreviation as its override

#### Scenario: Reset to default from a match row
- **WHEN** the user opens the context menu on a team that has an override and chooses to reset it
- **THEN** the override is cleared and the team reverts to its ESPN abbreviation

#### Scenario: Edit the pinned match's abbreviations from settings
- **WHEN** a match is pinned and the user opens the settings window
- **THEN** the settings offer an editable abbreviation field for each of the pinned match's two teams, each showing the current override (or the ESPN default as a placeholder) and a reset control
- **AND** editing a field updates that team's override, and clearing it resets to the ESPN default

#### Scenario: No pinned match to edit in settings
- **WHEN** no match is pinned and the user opens the settings window
- **THEN** the settings indicate that a match must be pinned to customize its menu bar abbreviations

### Requirement: Effective abbreviation applied wherever displayed

The system SHALL resolve a team's displayed abbreviation through the override map — using the override when one exists for that team's id, and the ESPN-provided abbreviation otherwise — everywhere an abbreviation is shown, including the pinned-match menu bar title and the `TeamLogoView` logo/flag fallback in popover rows. A change to a team's override SHALL be reflected the next time that team's abbreviation is rendered, without an app relaunch.

#### Scenario: Overridden abbreviation in the menu bar title
- **WHEN** the pinned match's home or away team has an override and the menu bar title is rendered
- **THEN** the title shows the override in place of the ESPN abbreviation

#### Scenario: Overridden abbreviation in the row fallback
- **WHEN** a team's logo is missing or fails to load and the team has an override
- **THEN** the row shows the override (uppercased) in place of the ESPN abbreviation

#### Scenario: No override falls through to ESPN
- **WHEN** a team has no override
- **THEN** its ESPN-provided abbreviation is displayed unchanged

#### Scenario: Override change reflected without relaunch
- **WHEN** the user sets or clears a team's override while the app is running
- **THEN** the next render of that team's abbreviation reflects the change
