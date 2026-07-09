# match-notifications Specification

## Purpose

Defines native macOS notifications for the pinned match: posting kickoff and goal notifications derived from observed snapshot transitions, avoiding phantom notifications on launch/pin/re-pin, requesting delivery authorization, and gating everything on the user's notification settings.

## Requirements

### Requirement: Pinned-match kickoff notification

The system SHALL post a native macOS notification when the pinned match transitions from an upcoming state to an in-progress state, and only for the pinned match. The notification SHALL name the two teams of the match that kicked off. The system SHALL NOT post a kickoff notification for any non-pinned match.

#### Scenario: Pinned match kicks off
- **WHEN** the pinned match is observed as upcoming on one refresh and in-progress on the next
- **THEN** a notification is posted naming the two teams of that match

#### Scenario: Non-pinned match kicks off
- **WHEN** a match that is not pinned transitions from upcoming to in-progress
- **THEN** no notification is posted

#### Scenario: No pinned match
- **WHEN** no match is pinned
- **THEN** no kickoff notification is posted regardless of any match's state changes

### Requirement: Pinned-match goal notification

The system SHALL post a native macOS notification when the pinned match's score increases while the match is in-progress, and only for the pinned match. The notification SHALL identify the match, the team that scored (the side whose goal count increased), and the new current score. A single refresh that shows more than one additional goal SHALL post at most one notification reflecting the new current score.

#### Scenario: Home team scores
- **WHEN** the pinned live match's home score increases between two consecutive refreshes
- **THEN** a notification is posted identifying the match, indicating the home team scored, and showing the new current score

#### Scenario: Away team scores
- **WHEN** the pinned live match's away score increases between two consecutive refreshes
- **THEN** a notification is posted identifying the match, indicating the away team scored, and showing the new current score

#### Scenario: Multiple goals in one refresh
- **WHEN** the pinned live match's score increases by more than one goal between two consecutive refreshes
- **THEN** at most one notification is posted reflecting the new current score

#### Scenario: Score decrease (correction / VAR)
- **WHEN** the pinned match's score decreases between two consecutive refreshes
- **THEN** no notification is posted
- **AND** the decreased score becomes the new baseline for future comparisons

### Requirement: Transition detection without phantom notifications

The system SHALL detect notification-worthy events by comparing each newly observed pinned-match snapshot against a retained baseline snapshot, and SHALL update the baseline after each comparison. The system SHALL NOT post a notification when a baseline is first established or when the pinned match identity changes; these SHALL only seed the baseline. This ensures that launching the app, pinning a match, or re-pinning to a different match never produces a notification for events that occurred before or outside of live observation.

#### Scenario: First snapshot after launch
- **WHEN** the pinned match's snapshot is first established on launch (including a match already in-progress)
- **THEN** the baseline is seeded and no notification is posted

#### Scenario: User pins a match
- **WHEN** the user pins a match
- **THEN** the baseline is seeded from that match and no notification is posted

#### Scenario: User re-pins to a different match
- **WHEN** the pinned match identity changes to a different match
- **THEN** the baseline is reset to the new match and no notification is posted for the switch

#### Scenario: Transient refresh failure
- **WHEN** a refresh fails and the pinned snapshot is unchanged
- **THEN** no notification is posted

### Requirement: Notification authorization

The system SHALL request the user's authorization to deliver notifications before it can post them, and SHALL do so when notifications are first enabled. If authorization is denied, the system SHALL NOT post notifications and SHALL NOT crash or repeatedly interrupt the user.

#### Scenario: Authorization granted
- **WHEN** notifications are enabled and the user grants authorization
- **THEN** subsequent kickoff and goal events for the pinned match post notifications

#### Scenario: Authorization denied
- **WHEN** notifications are enabled but the user denies authorization
- **THEN** no notifications are posted and the app continues to run normally

### Requirement: Notifications gated by settings

The system SHALL post notifications only for event types that are enabled in settings. When the master notifications setting is off, the system SHALL post no notifications of any type. When the master setting is on, kickoff notifications SHALL be posted only if the kickoff setting is on, and goal notifications only if the goal setting is on. While an event type is disabled, the baseline SHALL still be maintained so that re-enabling does not retroactively fire notifications for events missed while disabled.

#### Scenario: Master toggle off
- **WHEN** the master notifications setting is off
- **THEN** no kickoff or goal notification is posted

#### Scenario: Kickoff enabled, goals disabled
- **WHEN** the kickoff setting is on and the goal setting is off
- **THEN** kickoff events post notifications and goal events do not

#### Scenario: Re-enabling does not replay missed events
- **WHEN** an event type is turned off, an event of that type occurs, and the type is turned back on
- **THEN** no notification is posted for the event that occurred while the type was off

### Requirement: Notifications are informational only

A delivered notification SHALL NOT perform any action when the user clicks or interacts with it beyond the system default of dismissing it.

#### Scenario: User clicks a notification
- **WHEN** the user clicks a delivered kickoff or goal notification
- **THEN** no application action is triggered
