# ESPN as the Primary Source, OpenLigaDB as a German-only Backup Source

The app reads every Competition from ESPN's undocumented scoreboard endpoint (`site.api.espn.com`), because no free, keyless source gives live scores for the Cups users asked for (FA Cup, Carabao Cup, DFB-Pokal and others); a client-only app also cannot keep an API key secret. We accept that Disney's Terms of Use prohibit automated access without written permission, that the endpoint has no documentation or SLA, and that the app is publicly distributed. OpenLigaDB is the Backup Source for the Bundesliga and DFB-Pokal only, read for a Competition only when ESPN fails for it, never mixed with ESPN data, and shown with "via OpenLigaDB" attribution as its ODbL licence requires.

## Considered Options

- **ESPN only.** Simplest, but a German Competition would show stale results whenever ESPN fails for it.
- **A licensed paid source** (e.g. football-data.org Standard, €49/month). Removes the terms risk, but has no free Cup coverage and needs a backend to hold the key.
- **Keyed free tiers** (football-data.org, API-Football, TheSportsDB). Rejected: delayed scores, no domestic Cups, or result caps too small to list a day's Matches.

## Consequences

- Backup Source Matches use OpenLigaDB IDs and names, so they cannot be pinned, ignore abbreviation overrides and never trigger notifications.
- Revisit this decision before the app becomes commercial or gains a large user base; the move would be to a licensed source behind a small backend.
- Evidence and probe results: `docs/research/football-data-sources.md`.
