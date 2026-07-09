# match-highlights Specification

## Purpose

Let users jump from a finished match to its highlights by opening a YouTube search for that fixture in their default browser, without embedding video or requiring any API key or account.

## Requirements

### Requirement: Highlights control gated on finished matches

The system SHALL render a highlights control on a match row **only** when that match's state is finished. A match that is upcoming or in progress SHALL NOT render the control. The control SHALL be a compact icon placed on the trailing (right) side of the row so it does not displace the existing team, score, and status content.

#### Scenario: Finished match shows the control
- **WHEN** a match row is rendered for a match whose state is finished
- **THEN** the row shows a highlights control on its trailing side

#### Scenario: Upcoming match hides the control
- **WHEN** a match row is rendered for a match whose state is upcoming
- **THEN** no highlights control is shown on that row

#### Scenario: In-progress match hides the control
- **WHEN** a match row is rendered for a match whose state is in progress
- **THEN** no highlights control is shown on that row

### Requirement: Opening highlights in the default browser

The system SHALL, when the user activates the highlights control, open the user's default web browser to a YouTube search results page for that fixture. The app SHALL NOT embed or play video itself, and SHALL NOT require any API key, account, or network call of its own to perform the open.

#### Scenario: Activating the control opens the browser
- **WHEN** the user clicks the highlights control on a finished match
- **THEN** the default browser opens to a YouTube search results page for that match

### Requirement: YouTube search query composed from the fixture

The system SHALL compose the highlights destination as a YouTube search URL of the form `https://www.youtube.com/results?search_query=<query>`, where `<query>` is built from the match's home team name, the away team name, and a highlights keyword (e.g. `<home> vs <away> highlights`). Team names SHALL be percent-encoded so that spaces and non-ASCII characters in club names produce a valid URL.

#### Scenario: Query contains both teams and the highlights keyword
- **WHEN** the highlights URL is composed for a finished match between two teams
- **THEN** the resulting URL is a `youtube.com/results` search whose query includes both the home and away team names and a highlights keyword

#### Scenario: Team names with spaces and accents are encoded
- **WHEN** a team name contains spaces or non-ASCII characters (e.g. `Atlético Madrid`)
- **THEN** the composed URL percent-encodes those characters so the URL is valid and opens successfully
