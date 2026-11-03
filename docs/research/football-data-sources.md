# Football data sources: can we show more competitions?

Researched 2026-11-01 for the FootballMenuBar app (Swift 6, SwiftUI, SPM, no third-party deps, no backend).

**Evidence labels.** "Live probe" means a request made on 2026-11-01 and read directly. "Code" gives a path in this repo. Web sources are numbered and listed in [Sources](#sources). Anything I could not confirm is in [What could not be verified](#what-could-not-be-verified).

## Bottom line

1. **Keep ESPN and add slugs.** The competitions asked for are already on the source the app uses. Carabao Cup, FA Cup, Bundesliga, LaLiga, Serie A and their domestic cups all return real data from the same endpoint, with no key and no new provider.
2. **No free alternative matches it.** Nothing I tested gives live scores for the FA Cup and Carabao Cup together for free from a client-only app.
3. **The change is mostly hardening, not integration.** One failing league currently fails the whole refresh, and that gets more likely with every league added. Fixing it has one trap: the obvious fix would clear the pinned match (see [Code implications](#code-implications)).
4. **ESPN is not a licensed source.** The endpoint is undocumented with no SLA, and Disney's terms on their face prohibit automated access. That is already true today, and adding leagues does not change the type of risk, only the amount of traffic. The owner should accept this knowingly.

Three findings are not obvious from the outside:

- **Shootouts look like draws.** ESPN keeps penalties in a separate field the app ignores, so the 2026 Champions League final shows as `PSG 1 – 1 ARS` with no winner. This affects the app today, including its World Cup coverage.
- **Postponed and cancelled matches look finished.** ESPN gives them `state: "post"`, so the app shows `0 – 0` with a highlights button.
- **The planned 2-day date range does not work.** ESPN rejected every `YYYYMMDD-YYYYMMDD` range with HTTP 400, on every slug tried. The fix sketched in `ESPNProvider.swift:17-19` and design D5 cannot be built that way.

## Current state of the app

| Fact | Evidence |
| --- | --- |
| Exactly 3 competitions: `fifa.world`, `eng.1`, `uefa.champions`. The FA Cup is not included. | `Sources/FootballMenuBar/Models/League.swift:17-21` |
| The spec requires exactly those 3, so adding leagues needs an openspec change. | `openspec/specs/match-data/spec.md:67-71` |
| No league picker exists. `AppSettings` has no league key and `SettingsView.swift` never mentions leagues. A code comment calls the picker "a follow-up change". | `Sources/FootballMenuBar/Settings/AppSettings.swift:14-23`, `League.swift:16` |
| `MatchStore.leagues` is an immutable `let`, set once at launch. | `Sources/FootballMenuBar/Store/MatchStore.swift:52,72` |
| One request per league per refresh, inside `withThrowingTaskGroup`. One failure rethrows and fails the whole fetch. | `Sources/FootballMenuBar/Services/ESPNProvider.swift:37-46` |
| On failure the store keeps the old `matches` and sets `errorMessage`, so all leagues go stale together. | `MatchStore.swift:266-275` |
| Every league is polled on the same cadence, even if only one has a live match. | `MatchStore.swift:196-203`, `Settings/RefreshCadence.swift` |
| `MatchDataProvider` is a protocol, so a second provider is structurally possible. | `Sources/FootballMenuBar/Services/MatchDataProvider.swift` |
| The app is distributed publicly as a tagged release build. | `.github/workflows/release.yml`, `README.md:141-142` |

## ESPN coverage

### Finding slugs

**`https://site.api.espn.com/apis/site/v2/leagues/dropdown?sport=soccer&limit=400` is the best listing.** One request returned all 220 leagues, each with `slug`, `name`, `id` and `abbreviation` (live probe). `https://sports.core.api.espn.com/v2/sports/soccer/leagues?limit=400` also reports 220, but only as `$ref` links, so names would need 220 more requests.

Both are undocumented. I would hardcode a curated list in `League.swift` and use the dropdown only as a tool for finding slugs. A live 220-item picker would offer NCAA, friendlies and qualifying tiers, most of which are empty on any given day.

### Recommended starter set

Each slug below returned HTTP 200 with the correct league name (live probe). Display names are suggestions.

| Group | Slug | Display name |
| --- | --- | --- |
| England | `eng.1` | Premier League |
| England | `eng.2` | Championship |
| England | `eng.fa` | FA Cup |
| England | `eng.league_cup` | Carabao Cup |
| Spain | `esp.1` | LaLiga |
| Spain | `esp.copa_del_rey` | Copa del Rey |
| Germany | `ger.1` | Bundesliga |
| Germany | `ger.dfb_pokal` | DFB-Pokal (ESPN calls it "German Cup") |
| Italy | `ita.1` | Serie A |
| Italy | `ita.coppa_italia` | Coppa Italia |
| France | `fra.1` | Ligue 1 |
| France | `fra.coupe_de_france` | Coupe de France |
| Europe | `uefa.champions` | Champions League |
| Europe | `uefa.europa` | Europa League |
| Europe | `uefa.europa.conf` | Conference League |
| World | `fifa.world` | World Cup |

### Further verified slugs, for the picker

- **England:** `eng.3`, `eng.4`, `eng.5`, `eng.charity` (Community Shield), `eng.trophy`, `eng.w.1` (Women's Super League)
- **Europe:** `por.1`, `ned.1`, `sco.1`, `tur.1`, `bel.1`, `uefa.nations`, `uefa.super_cup`, `uefa.euro`
- **Americas:** `conmebol.libertadores`, `conmebol.sudamericana`, `conmebol.america`, `usa.1` (MLS), `mex.1`, `bra.1`, `arg.1`
- **Other:** `ksa.1` (Saudi Pro League), `fifa.cwc`

**Qualifying rounds are separate slugs.** `eng.fa` starts at the First Round, while `eng.fa_qual` held 747 events in 2026. Likewise `uefa.champions_qual` held 90. Picking `uefa.champions` alone misses summer qualifiers, which is probably what most people want.

### One request for every league

`.../soccer/all/scoreboard?dates=YYYYMMDD&limit=1000` returns all leagues in one response (live probe). I did not find this documented anywhere.

| Date | Events | Leagues | On the wire | Decoded JSON |
| --- | --- | --- | --- | --- |
| Wed 2026-10-28 | 156 | 27 | 112 KB | 1.4 MB |
| Sat 2026-10-31 | 315 | 61 | 206 KB | 2.6 MB |
| Sun 2026-11-01 | 292 | 63 | 167 KB | 2.4 MB |

- **`limit` is required.** Without it the response stops at 100 events (100 of 292 on 2026-11-01).
- **Events can be filtered.** Each event's `uid` looks like `s:600~l:700~e:401879246`, where `l:` matches the dropdown's `id`. Every league ID in all three days mapped to a known slug.
- **Cups were included on the one night tested.** All 8 DFB-Pokal and all 5 Carabao Cup events from 2026-10-28 appeared. That is one night, not proof of completeness.
- **The cost is size.** A per-league response is about 4-10 KB on the wire, so 16 leagues cost about 100 KB at most. The all-league call costs 2-3 MB of JSON parsing each tick, mostly NCAA and lower-division matches the user never sees. Only choose it if users commonly select more than about 20 leagues.

## ESPN data compatibility

I compiled the app's exact DTOs from `ESPNProvider.swift` into a test program and ran them over 13 real payloads. **All 1,896 events decoded and none were dropped by `toMatch`**, covering FA Cup, Carabao Cup, Copa del Rey, DFB-Pokal, Champions League, Liga MX, MLS and the all-league call. Team IDs, names and `homeAway` were present on every event, and no score was non-numeric.

So adding these slugs will not break decoding. These are the display problems:

| Case | What ESPN sends | What the app does | Applies today? |
| --- | --- | --- | --- |
| **Penalty shootout** | `score` stays level; `shootoutScore` is a separate Int on each competitor; `shortDetail` is `FT-Pens`; `notes[0].headline` reads "Paris Saint-Germain win 4-3 on penalties" | Row shows 1, 1 and `FT-Pens`. Menu bar shows `PSG 1 – 1 ARS` with no winner | Yes. 94 shootouts seen, including the 2026 Champions League final and World Cup knockouts |
| **Postponed or cancelled** | `STATUS_POSTPONED` and `STATUS_CANCELED` both have `state: "post"` and `completed: false` | `.finished`, `0 – 0`, a `Postponed` badge and a highlights button | Yes, but rare. 3 seen. Cups add more lower-tier matches |
| **Placeholder teams** | Coppa Italia 2027: 9 of 12 events are `TBD Home` vs `TBD Away` (IDs 131556, 131554), with `timeValid: false` and score `"0"` | Decodes fine. Shows `TBD Home` as a team, plus an invented kickoff time | New with bracket cups |
| **Provisional kickoff** | 4 Carabao quarter-finals have real teams, but `shortDetail: "TBD"` and `timeValid: false` at a nominal 20:00Z | Shows a precise time, because `MatchListView.swift:343-344` replaces the status with the kickoff for upcoming matches | New with cups |
| **Two-legged ties** | `leg.displayValue` ("2nd Leg"), `series`, and `aggregateScore` on each competitor in the second leg only; first legs carry only the note "1st Leg" | Shows that leg's score only, so a tie's state is hidden | Yes, for Champions League knockouts |
| **Extra time** | `STATUS_FINAL_AET`, `shortDetail: "AET"`, `score` is the final result | Correct | No problem |

**Future rounds usually don't exist yet.** `dates=2027` returned no events for `eng.fa` or `eng.league_cup`, and only the 36 league-phase matches for `uefa.champions`, so placeholders are specific to some competitions. Coppa Italia was the only one found.

**Live extra time and live shootouts were not observed.** No such match was in play during this research. The app only reads `state` and `shortDetail`, so a live match should display, but the exact strings are unconfirmed.

**Single-day queries work on all five cups.** `eng.fa` on 20260516 returned 1 event, `ger.dfb_pokal` on 20261028 returned 8, `eng.league_cup` on 20261028 returned 5, `esp.copa_del_rey` on 20261104 returned 7, and `uefa.champions` on 20261021 returned 9. An empty day returns 200 with `events: []`, which decodes correctly (`esp.copa_del_rey` on 20261028).

**No event appears under two slugs.** Across seven sets totalling 1,282 events (FA Cup, Carabao, Copa del Rey, DFB-Pokal, Champions League, and both qualifying slugs), there were no shared IDs, and no duplicates inside the all-league responses. The Champions League set was capped at 100 by the default limit. Only those pairs were tested.

**Crests are not guaranteed.** `logo` was missing on 1,550 of 2,200 competitor entries in a lower-tier-heavy sample (mostly FA Cup qualifying). `logo` is optional in the DTO and `TeamLogoView` exists for this, so it should only look plainer.

## ESPN date handling

- **Accepted:** `dates=YYYYMMDD`, `dates=YYYYMM`, `dates=YYYY`, or no parameter.
- **Rejected:** `dates=YYYYMMDD-YYYYMMDD` returned HTTP 400 `{"code":400,"message":"Failed to get events endpoint."}`. That held for 2-day, 1-month and 5-month ranges, and even a same-day range, across `eng.fa`, `eng.1`, `uefa.champions` and NBA basketball. **`limit` was never the cause.** The earlier failed probe was a range problem. A retest about 25 minutes later gave the same 400, so this was not a momentary fault, though one session cannot show how long it has been this way. `dates=2026` with `limit=1000` covers the same need.
- **The day boundary is not UTC.** `mex.1?dates=20261016` returned kickoffs at 01:00Z, 03:00Z and 03:05Z on Oct 17, and an all-league day ran from 04:00Z to about 03:10Z the next day. That fits a US Eastern day. Design D5 says UTC (`openspec/changes/archive/2026-07-02-add-date-navigation/design.md:68-70`), and the code actually sends the user's local date (`ESPNProvider.swift:26-33`).
- **Who this affects:** European evening kickoffs (19:45-20:00Z) are safe for users in Europe and the Americas. Late kickoffs from the Americas appear one day early for European users: that 03:05Z Oct 17 match is 05:05 on Oct 17 in Madrid but is listed under Oct 16. Users in Asia and Australia would see it the other way round for European evening games.
- **If this gets fixed:** use two single-day requests and filter, or one `YYYYMM` request. Either way the comment at `ESPNProvider.swift:17-19` needs correcting.

## ESPN terms, stability and rate limits

**Status: undocumented, unofficial, no SLA.** I found no public documentation for these endpoints. `www.espn.com/apis/devcenter/` returns 404 and `developer.espn.com` returns a 127-byte stub (live probe).

**Terms.** `www.espn.com/terms-of-use` is a 404, but Disney's Terms of Use name ESPN as a covered brand. The US edition was last updated May 24, 2024 [1]. Section 2.B opens: "You agree that you will not nor permit another person to do any of the following without our express written permission". Its list includes:

> x. access, monitor, copy or extract the Disney Products using a robot, spider, script, or other automated means, including, for the avoidance of doubt, for the purposes of creating or developing any AI Tool, data mining or web scraping or otherwise compiling, building, creating or contributing to any collection of data, data set or database (other than for a public search engine's use of spiders for creating search indices to the extent not disallowed by Disney, including through the applicable robots.txt files or NOINDEX or NOFOLLOW meta-tags)

> viii. use the Disney Products for any commercial or business-related use or build a business utilizing the Disney Products, or engage in any activity to enable third parties to engage in any of the foregoing activities, in each case whether or not for profit

Section 2.A limits the licence to "personal, noncommercial use only" [1]. The terms do not mention APIs specifically.

**Plain reading (not legal advice):** an app polling this endpoint on a timer is automated access without written permission, and shipping that app to others may fall under "enable third parties". The wording makes no exception for free or hobby projects. I found no sign that ESPN enforces this against small clients, but no sign of enforcement is not permission. Other regions have their own editions: the homepage footer linked the Latin American Spanish one for this machine. I read only the US edition.

**Rate-limit signals.** None seen in 74 requests (spaced about 1 second apart, or 5 minutes apart for the live sampler): no 429s and no `X-RateLimit-*` or `Retry-After` headers. Scoreboard responses carry `cache-control: max-age=1` to `max-age=10`. This shows only that light use was fine. It is not a measured limit, and I deliberately did not look for one.

**Stability.** The rejected date ranges are themselves a reminder that behaviour can differ from what the repo assumed: design D5 from July 2026 planned on a range form that returns 400 today. The cause and date of any change are unknown.

## Alternatives

"Fit" means fit for a client-only app. A shipped app cannot hide a key, so any keyed source really means each user brings their own key, or one shared key has its quota exhausted by all users together.

| Source | Key | Live? | FA Cup / Carabao | Bundesliga, LaLiga, Serie A | Limit | Licence / terms | Fit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **ESPN** (current) | None | Yes | Yes / Yes | Yes | Unknown | Unofficial; terms prohibit automated access [1] | Best coverage, weakest legal footing |
| **football-data.org** free | Required | No, "Scores delayed" [2] | No / No [3] | Yes | 10/min [2] | Terms page not found | Poor: per-user keys, delayed, no cups |
| **API-Football** free | Required | Unverified | Unverified | Unverified | 100/day [4] | Not read | Poor: 100 calls run out in about 75 min at the 45 s cadence, for one league |
| **TheSportsDB** free | Public `123` | No; livescores are Premium [5] | Listed, but 3 events per call | Listed, same cap | 30/min [5] | Not read | Unusable: results truncated |
| **OpenLigaDB** | None | Yes, community-entered | No / No | Bundesliga yes; LaLiga weak; Serie A none | 60/min per IP [6] | ODbL 1.0 [6] | Good for Germany only |
| **openfootball** | None | No, static files | No / No | League files only | GitHub raw | Public domain [7] | Unusable: 6 weeks behind |
| **Sportmonks** free | Required | Not stated | No | No | Not stated | Not read | Unusable: two fixed leagues [8] |
| **BALLDONTLIE** free | Required | Unverified | Not listed | Listed | 5/min [9] | Not read | Poor: 5/min, unverified |
| **SportScore** | None | Yes (60 s cache) [10] | Unverified | Unverified | ~10,000/day per IP [10] | Attribution link required [10] | Not recommended; see below |

### football-data.org

- **Coverage:** the free plan's 12 competitions exclude the FA Cup, League Cup, Copa del Rey, DFB-Pokal and Coppa Italia [3]. Those cups are the main thing the owner asked for.
- **Delay:** the pricing page says "Scores delayed" and gives no figure [2]. I searched the docs and quickstart and found no number anywhere.
- **IN_PLAY on the free tier:** I could not test this without a key. `IN_PLAY` is a documented status [11], but the docs do not say which plans receive it.
- **No key:** `/v4/matches` returns 200 with an empty list, and `/v4/competitions/PL/matches` and `/v4/competitions/FAC` return 403 (live probe). The docs state 100 requests per 24 hours without a key [12], but the response header showed 48-49 remaining with a reset about 24 hours away.
- **Live scores cost:** "Free w/ Livescores" is €12/month [2], which makes it a poor fit for a free app with many users.
- **Worth noting:** it documents shootouts cleanly, with `score.duration` and a separate `penalties` node [13].

### API-Football

`www.api-football.com`, `api-sports.io` and `dashboard.api-football.com` all served a Cloudflare "Just a moment" challenge, so I could not read the pricing or docs. I did not try to get past it. `v3.football.api-sports.io` responds normally and asks for a key (`Missing application key`), so the API itself is up. The 100 requests per day and "limited in terms of available seasons" come only from search snippets of the official pricing page [4], so check them directly before relying on them. If the season restriction blocks the current season, this option is out entirely.

### TheSportsDB

Key `123` works, which explains the earlier 403 on key `3`. The free tier is capped per endpoint [5], and live probes confirm it:

- `eventsday.php?d=2026-11-01&s=Soccer` returned **3 events for the entire sport** on a day when ESPN had 292.
- The Premier League on 2026-10-31 returned 3 of 8 matches.
- `eventsnextleague` and `eventspastleague` each returned 1 event.
- Responses carry `cache-control: public, max-age=14400`, which is four hours.

The FA Cup (4482) and EFL Cup (4570) exist there, and the final's result (Chelsea 0-1 Man City) matched ESPN, but the cap makes it unusable for a score list.

### OpenLigaDB

Its Swagger states: no sign-up, no key, 60 requests per minute per IP, please fetch sparingly, and use `/getlastchangedate/...` as a cheap poll. It also says the server costs about €50 a month and is privately funded [6]. Anyone registered can enter results [14], and the league list shows that: 841 entries, including test leagues.

Upkeep varies widely by league. For matches that kicked off at least 3 hours before the check:

| Shortcut | Competition | Past matches | Finished | With results | Median hours, kickoff to last update |
| --- | --- | --- | --- | --- | --- |
| `bl1` | Bundesliga | 70 | 70 | 70 | 1.9 |
| `dfb` | DFB-Pokal | 48 | 48 | 48 | 1.9 |
| `ucl` | Champions League | 54 | 54 | 54 | 1.9 |
| `uel2026` | Europa League | 54 | 54 | 54 | 28.1 |
| `la1` | LaLiga | 104 | 99 | 99 | 38.1 |
| `pl` | Premier League | 88 | 61 | 66 | 50.7 |
| `uecl2026` | Conference League | 36 | 19 | 19 | 121.1 |
| `ucl2026` | Duplicate Champions League entry | 32 | 0 | 0 | none |

The German competitions and `ucl` are well kept. The rest are not reliable. I found no Serie A, FA Cup or Carabao Cup entry for 2026. The ODbL licence requires attribution and has share-alike terms for derived databases [6]. The site's terms and licence pages are client-rendered and came back empty, so I have not read the operative terms.

**Live freshness.** At 14:14Z on 2026-11-01, three 2. Bundesliga matches were at about minute 85. Seconds apart, `getmatchdata/bl2/2026` matched ESPN on all three scores (2-1, 0-0 and 1-2 in OpenLigaDB's home-team order), with goal minutes included, so the community feed was current at that moment. At the 14:30Z Bundesliga kickoff, `getmatchdata/bl1/2026` had the match open with a `lastUpdateDateTime` of 15:30:14 Berlin time, 14 seconds after kickoff. Goal-to-feed lag was not measured: I stopped sampling at minute 5, with the match still 0-0, because waiting for a goal could have taken two hours for one data point.

**The endpoint matters.** In both cases the current-matchday form (`getmatchdata/bl2`, `getmatchdata/bl1`) returned no results for matches in progress, while the season form had them. Use the season form, or test `{season}/{matchday}` first, which I did not sample live. Shootouts come through as a cumulative `Elfmeterschießen` result (5-4 for a 1-1 draw won 4-3 on penalties).

### openfootball/football.json

Public domain (CC0) [7], but the data is not fresh. The last push was 2026-09-22, 40 days ago [15]. The 2026-27 Premier League file has 50 of 380 matches scored, the latest from 2026-09-20 (live probe). The README explains why: the JSON auto-updates daily, but the upstream sources have "no automatic (daily) update" [7]. There are 8 league files and no cups for 2026-27 [15]. It is useful for historical fixtures, not this app.

### SportScore

This was the one new keyless candidate worth a look. `sportscore.com/api/widget/matches/` works without a key (live probe). Its terms, last updated 23 April 2026, allow about 10,000 requests per 24 hours per IP with a 60-second edge cache [10]. Three problems:

- **Attribution:** the free tier requires a real HTML `<a>` "Powered by SportScore" link, `dofollow` and "discoverable by crawlers", on every surface showing its data [10]. That doesn't map onto a native menu bar popover.
- **Rights:** the terms say data is pulled "from a range of upstream providers" [10] and crest URLs point to `img.thesports.com`, so the chain of rights is unclear.
- **Coverage:** `limit=500` still returned only 50 matches, so I could not confirm FA Cup or Carabao coverage.

### Others

- **Unofficial first-party JSON:** `fantasy.premierleague.com/api/`, `match.uefa.com/v5/matches` and `api.fifa.com/api/v3/` all returned 200 without a key (live probe). Each covers only its own competitions, none is documented as a public API, and I did not review their terms. Not recommended.
- **FotMob and SofaScore:** `www.fotmob.com/api/matches` returned 404 and `api.sofascore.com` returned 403 to a plain request. Neither was verified as working and I did not attempt to bypass anything, so neither is assessed further.
- **Excluded:** vendor comparison blogs, and small self-reported APIs surfaced by search (such as worldcup26.ir and 5DollarFootballAPI), whose claims I did not verify.

## Recommendation

**Use ESPN as the only provider and expand through slugs.** Start with the 16 leagues above and add a picker.

**Do not build a fallback provider now.** Its value is low and its cost is real:

- No free source covers the cups, so a fallback would show fewer competitions and, for most of them, no live scores. OpenLigaDB could cover German football and `ucl`, and that is all.
- It would not be a drop-in swap. Pins and abbreviation overrides are keyed by ESPN IDs (`MatchStore.swift:76`, `AppSettings.swift:50`), and other sources use different match and team IDs. A fallback would need an ID mapping for little gain.
- The realistic contingency if ESPN goes away is a planned migration, likely to a paid source. The `MatchDataProvider` seam already makes that possible, so that part needs no new work.

**Accept the terms risk deliberately.** If the app ever becomes commercial or gains a large user base, move to a licensed source first. football-data.org Standard (€49/month, 30 competitions, 60 calls/min [2]) is one starting point, though its 30-competition list and client-key handling would need checking, and it would likely need a small backend to keep the key out of the app.

### Code implications

Listed in suggested order. None of this has been implemented.

1. **Make one league's failure non-fatal, with care.** Catch per league in `ESPNProvider.swift:37-46` and return which leagues failed. Treating partial results as success would introduce two bugs:
   - `MatchStore.swift:296` and `:308` treat a missing pinned ID as "match gone". If the pinned match's league failed, the pin would blank out on a transient error.
   - `MatchStore.swift:269` replaces all matches, so a failed league's rows would disappear. Keep its previous rows instead.
2. **Add the league picker.** Persist selected slugs in `AppSettings`, make `MatchStore.leagues` mutable, and only poll selected leagues. Keep polling the pinned match's league even if it is deselected, or the same "match gone" path clears the pin.
3. **Reduce polling.** See the table below. After a day's first sweep, fast-poll only leagues with an unfinished match that day, and let the rest fall to the idle cadence.
4. **Stop showing postponed and cancelled matches as finished.** Require `status.type.completed == true`, and hide the highlights button for them.
5. **Show shootouts.** Add `shootoutScore: Int?` to the DTO and an optional pair to `Score`, or use `notes[0].headline`. Match the menu bar title to it.
6. **Handle unconfirmed fixtures.** Decode `timeValid` and show "TBD" rather than a time when it is false. Consider hiding `TBD Home` fixtures.
7. **Update the docs.** Correct the comment at `ESPNProvider.swift:17-19`, and write an openspec change for `match-data` (the spec says exactly 3 leagues) and for the picker.

Optional later: show the aggregate on second legs using `aggregateScore`.

**Requests per minute while something is live** (leagues × polls per minute):

| Leagues | Battery Saver (90 s) | Balanced (45 s) | Aggressive (20 s) |
| --- | --- | --- | --- |
| 3 (today) | 2 | 4 | 9 |
| 16 (starter set) | 11 | 21 | 48 |
| 25 | 17 | 33 | 75 |

This doubles when the pinned match is on a different day from the one being browsed, because the ticker and browse feeds fetch separately (`MatchStore.swift:232-240`). There is no known limit to compare against. Item 3 above would cut this a lot on most days, since few leagues play at the same time.

## What could not be verified

| Item | Why |
| --- | --- |
| ESPN's real rate limit | Deliberately not tested. |
| Live extra-time and shootout status strings | No such match was in play. |
| OpenLigaDB goal-to-feed lag | Sampling stopped at minute 5 of a 0-0 match, before any goal. Point-in-time agreement with ESPN was verified instead. |
| Whether the all-league scoreboard is always complete | Compared on one cup night only. |
| football-data.org delay length, and IN_PLAY on the free tier | No figure in its docs, and no key available to test. |
| football-data.org terms | `/terms` returned 404, and no terms link appears on the coverage page. |
| API-Football pricing, docs, live cadence and current-season access | Cloudflare challenge on its sites; only search snippets were available, and the Wayback Machine could not be fetched. |
| TheSportsDB terms | `/terms_of_use` returned 502, then 404 on retry. |
| OpenLigaDB terms and licence text | Pages are client-rendered and came back empty; ODbL is taken from its Swagger and homepage. |
| BALLDONTLIE free tier details | Homepage only; `/pricing` returned 404. |
| Sportmonks free-tier limits and live data | Not stated on its free-plan page. |
| SportScore cup coverage | Widget capped at 50 matches. |
| Non-US Disney terms | Only the US edition was read. |
| App behaviour | Findings about display come from reading code and running the DTOs, not from running the app. |

## Research notes

- **www.espn.com:** its `robots.txt` disallows several AI agents, including `anthropic-ai`. I read that only after one homepage fetch (with a generic browser user agent) to find the terms link. After that I fetched nothing further from that host except `robots.txt` itself, and read the terms on disneytermsofuse.com instead. `site.api.espn.com/robots.txt` returned 403, so no stated rule for the API host is known.
- **Volume:** 74 requests to ESPN's API in total: 69 probes and 5 live samples. The sampler was stopped at minute 5 of the match.

## Sources

1. Disney Terms of Use, United States, last updated May 24, 2024: <https://disneytermsofuse.com/english/>
2. football-data.org pricing: <https://www.football-data.org/pricing>
3. football-data.org coverage: <https://www.football-data.org/coverage>
4. API-Football pricing (search snippet only; the page could not be opened): <https://www.api-football.com/pricing>
5. TheSportsDB documentation: <https://www.thesportsdb.com/documentation>
6. OpenLigaDB Swagger (`info` block): <https://api.openligadb.de/swagger/v1/swagger.json>. ODbL 1.0 text: <https://opendatacommons.org/licenses/odbl/1-0/>
7. openfootball/football.json README and licence: <https://github.com/openfootball/football.json>
8. Sportmonks free plan: <https://www.sportmonks.com/football-api/free-plan/>. Pricing: <https://www.sportmonks.com/football-api/plans-pricing/>
9. BALLDONTLIE homepage plan table: <https://www.balldontlie.io/>
10. SportScore API terms: <https://sportscore.com/developers/terms/>. Portal: <https://sportscore.com/developers/>
11. football-data.org match resource: <https://docs.football-data.org/general/v4/match.html>
12. football-data.org rate-limit policy: <https://docs.football-data.org/general/v4/policies.html>
13. football-data.org score handling: <https://docs.football-data.org/general/v4/overtime.html>
14. OpenLigaDB homepage: <https://www.openligadb.de/>
15. openfootball commit history and 2026-27 folder: <https://github.com/openfootball/football.json/commits/master> and <https://github.com/openfootball/football.json/tree/master/2026-27>
