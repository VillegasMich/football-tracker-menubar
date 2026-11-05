# Football Menu Bar

A macOS menu bar app that shows live and upcoming football Matches from the Competitions a user follows.

## Language

**Competition**:
Any organised football tournament the app can show, whether a League, a Cup, or an international tournament such as the World Cup.
_Avoid_: League (as the umbrella term), tournament

**League**:
A Competition in which teams play each other across a season and are ranked in a table, such as LaLiga or the Bundesliga.
_Avoid_: division

**Cup**:
A Competition decided by knockout rounds, such as the FA Cup, Carabao Cup or DFB-Pokal.
_Avoid_: trophy, knockout

**Match**:
A single contest between two teams within a Competition.
_Avoid_: game, event, fixture

**Followed Competitions**:
The set of Competitions a user has chosen to see in the app.
_Avoid_: selected leagues, favourites, subscriptions

**Pinned Match**:
The single Match the user has chosen to track in the menu bar title.
_Avoid_: favourite match, ticker match

## Match status

**Upcoming**:
A Match that has not kicked off yet.
_Avoid_: scheduled, pre

**Live**:
A Match currently being played, including extra time and a Penalty Shootout.
_Avoid_: in progress, in play

**Finished**:
A Match that was played to its conclusion.
_Avoid_: final, post, completed

**Postponed**:
A Match moved to a later, possibly unknown, date without being played.
_Avoid_: delayed, rescheduled

**Cancelled**:
A Match that will not be played at all.
_Avoid_: called off

**Abandoned**:
A Match that kicked off but was stopped and not completed; a Match stopped briefly and resumed the same day stays Live.
_Avoid_: suspended, unfinished

**Penalty Shootout**:
The tiebreak after a drawn Cup Match, whose result is kept apart from the Match score.
_Avoid_: pens (except as a display label), penalties

## Data sources

**Primary Source**:
The data source every Competition is read from by default.
_Avoid_: provider, API

**Backup Source**:
A secondary data source read for a Competition only when the Primary Source fails for it, and never mixed with Primary Source data.
_Avoid_: fallback provider, mirror

## Refreshing

**Refresh setting**:
The user's chosen preset (Battery Saver, Balanced or Aggressive) that sets the Live rate and the Idle rate.
_Avoid_: cadence, update frequency (except as the Settings label), polling mode

**Live rate**:
The short interval of the Refresh setting, used for a Competition while something in it is changing or about to change.
_Avoid_: fast poll, live cadence, fast mode

**Idle rate**:
The long interval of the Refresh setting, used for a Competition while nothing in it is expected to change.
_Avoid_: slow poll, idle cadence, slow mode
