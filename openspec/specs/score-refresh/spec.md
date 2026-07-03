# score-refresh Specification

## Purpose

Defines the observable match store, its state-driven auto-refresh cadence, and user-triggered manual refresh.

## Requirements

### Requirement: Observable match store

The system SHALL provide an observable store that fetches matches through the `MatchDataProvider`, holds the current matches for the selected day, and is injected into the SwiftUI environment for views to read. The store SHALL maintain two logically separate feeds: a browse feed for the selected day (powering the popover list) and a ticker feed for the pinned match (powering the menu bar title, per `match-pinning`). Changing the selected day SHALL affect only the browse feed.

#### Scenario: Matches exposed to views
- **WHEN** the store completes a browse fetch
- **THEN** the fetched matches for the selected day become observable state
- **AND** views reading the store from the environment update to reflect them

#### Scenario: Browse and ticker feeds are independent
- **WHEN** the selected day changes to a day other than the pinned match's day
- **THEN** the browse feed updates to the new day
- **AND** the ticker feed for the pinned match is unaffected

#### Scenario: Fetch error is observable
- **WHEN** a fetch fails
- **THEN** the store exposes an error/empty state rather than crashing or hanging
- **AND** a subsequent successful fetch clears it

### Requirement: State-driven refresh cadence

The system SHALL auto-refresh on an interval that depends on live play across both feeds. The store SHALL poll on a fast interval (LIVE mode, ~30–60s) when the pinned match is in-progress, when a pinned match is upcoming and kicks off today, or when the currently browsed day has an in-progress match; otherwise it SHALL poll on a slow interval (IDLE mode, ~5–15 min). On each fast/slow tick the store SHALL refresh the ticker feed for the pinned match (keeping the menu bar title live regardless of the browsed day), and SHALL refresh the browse feed only while the browsed day has a live match. When the browsed day equals the pinned match's day, a single fetch MAY serve both feeds. The mode SHALL be recomputed after each fetch.

#### Scenario: Fast polling while the pinned match is live
- **WHEN** the pinned match is in-progress
- **THEN** the store refreshes on the fast (LIVE) interval
- **AND** the ticker feed is refreshed so the menu bar title stays current even while another day is browsed

#### Scenario: Fast polling for a pinned upcoming match today
- **WHEN** no match is in-progress but a pinned match is upcoming and kicks off today
- **THEN** the store refreshes on the fast (LIVE) interval

#### Scenario: Fast polling while the browsed day is live
- **WHEN** the currently browsed day has an in-progress match
- **THEN** the store refreshes on the fast (LIVE) interval
- **AND** the browse feed is refreshed so the visible list stays current

#### Scenario: Browsing a non-live day does not force fast polling
- **WHEN** the browsed day has no in-progress match and no pinned match is live or kicking off today
- **THEN** the store refreshes on the slow (IDLE) interval
- **AND** the browse feed is not auto-refreshed for that day

#### Scenario: Back off when nothing is live
- **WHEN** the pinned match is neither in-progress nor upcoming-today and no browsed match is in-progress
- **THEN** the store refreshes on the slow (IDLE) interval

### Requirement: Manual refresh

The system SHALL allow the user to trigger an immediate refresh regardless of the current polling interval.

#### Scenario: User refreshes on demand
- **WHEN** the user triggers a manual refresh
- **THEN** the store fetches immediately
- **AND** resumes its state-driven interval afterward
