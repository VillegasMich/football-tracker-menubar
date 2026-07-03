## MODIFIED Requirements

### Requirement: Selected browsing date

The system SHALL maintain a single selected date that determines which day's matches the popover shows. The selected date SHALL default to the current local day when the app launches and SHALL NOT persist across restarts (browsing is transient). Because browsing is transient, the system SHALL also reset the selected date to the current local day each time the popover is opened, refreshing the browse feed for that day, so every open starts on today rather than the last-browsed day. Resetting when the selected date is already today SHALL be a no-op that does not trigger a redundant fetch.

#### Scenario: Defaults to today on launch
- **WHEN** the app launches
- **THEN** the selected date is the current local day
- **AND** the popover shows that day's matches

#### Scenario: Selected date is not restored across restarts
- **WHEN** the user has browsed to a different day and then relaunches the app
- **THEN** the selected date resets to the current local day

#### Scenario: Reopening resets to today after browsing away
- **WHEN** the user browses to a different day, closes the popover, and reopens it
- **THEN** the selected date is the current local day
- **AND** the popover shows today's matches

#### Scenario: Reopening while already on today does not refetch
- **WHEN** the popover is opened while the selected date is already the current local day
- **THEN** the selected date stays today
- **AND** no redundant browse fetch is triggered by the reset

#### Scenario: Reopening does not affect the pinned match
- **WHEN** a match is pinned and the user reopens the popover after browsing to another day
- **THEN** the selected date resets to today
- **AND** the pinned match and its menu bar ticker are unchanged
