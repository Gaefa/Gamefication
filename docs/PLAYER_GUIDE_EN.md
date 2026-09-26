# Mandate Cities — Player and Tester Guide

> English edition. The Russian original is [PLAYER_GUIDE.md](PLAYER_GUIDE.md).

Version: "Rust Pit" test build (MVP, September 2026). A run takes 20–40 minutes.

## What this game is

A city builder about **power on loan**. You are not a mayor or an owner — you are an administrator the Restoration League appointed to the Rust Pit, a dry district after the Rift. The League gave you the mandate and money; the residents gave you an advance of trust. Two masters, and you can't please both: the more you give the city, the less the League likes you, and vice versa.

The stressor is climate. In 18 days the Dust season arrives: water drains faster, crops fall, solar panels weaken. On day 20, in the middle of the Dust, a League inspector comes for the audit.

## Goal

- **Win:** reach day 30 with a city that hasn't emptied (resident mood at 40 or higher). The flavor of the ending depends on how you ruled: loyal administrator, city protector, pragmatist, or future autonomist.
- **Lose:** League trust drops to 0 — recall of the mandate; city support drops to 0 — riot; residents leave — exodus.

The ending screen explains why things ended the way they did: the two masters, the Cistern, what broke first, how many people stayed.

## How a day goes

1. **Day.** Build, repair, watch the map. Time runs; you can pause (Space) and change speed (1 / 2 / 3).
2. **Evening — the Administrator's Desk.** The game pauses and the secretary lays out patron letters and resident petitions. **Hover over an answer to see its consequences** (trust, support, resources, pressure). Choose. Urgent items (audit, ultimatum) arrive in the middle of the day.
3. **Morning.** Your decisions take effect. Everything you answered is in the log (N).

## What you see at the top

- **Resources:** money, food, water reserve, wood, stone, tools.
- **Water for N days** — the key number. Yellow below 5 days, red below 2.
- **League ↕ City** — the two masters. A red meter means that master is about to remove you.
- **Voss · you** — comparison with the neighboring district run by Mara Voss (the Directorate). Your patron compares you with her: on day 14 the better district gets the Dust grant, and at the audit the gap affects trust.
- **Pressure: food · water · people · mandate** — four gauges. At 100 a crisis lands on the Desk. The cause builds up over days, so you can see it coming.

## Water — three different values

This is the main thing to understand in the game:

| Value | What it is | Where to see it | How to fix it |
|---|---|---|---|
| **Reserve** | how much water is in the Cistern | "Water for N days" at the top, panel C | more pumps, Cistern upgrade, rationing |
| **Coverage** | whether water reaches a house | ranges (V), panel C, "droplet" pin over a house | a pump closer to the house |
| **Pressure** | whether there is enough head | panel C, "P" pin over a house | house is far from the pump or the pump feeds too many houses — build a second pump |

You can have plenty of reserve and the far block still sits without water. Panel **C** tells you which of the three is failing.

## Icons over buildings

Click a building — at the bottom left the game names **the one main cause** of the problem and what to do. Icons: damage (R — repair), no road, no water, empty storage, no power (E), low pressure (P).

## What to build (right panel)

- **Road** — everything works only next to a road.
- **Well Pump** — water within a 4-tile radius. A second pump before the Dust is a must.
- **Shelter** — housing; only inside the water zone, otherwise it stays empty.
- **Dust Plot** — food; better near water.
- **Warehouse**, **Lumber Yard**, **Stone Quarry**, **Tool Workshop** — materials and tools.
- **Solar Panel / Generator** — power. In the Dust, panels drop to half.

Starting objects: administration post, the Main Cistern, warehouse, pump, shelter, plot, panel. Plus the legacy of the Clear Source Company: the old Source Tower (on day 8 you decide its fate), the Company office, and ruins along the dead pipeline (ruins can be salvaged for stone).

## Panels and keys

| Key | What |
|---|---|
| **H** | in-game help |
| **C** | water: reserve, coverage, pressure |
| **K** | season and forecast, Dust readiness checklist |
| **J** | previous administrator's diary (found during play) |
| **N** | log of your answers to letters and petitions |
| **G** | governance (policies) |
| **O** | options, language |
| **V** | water and power ranges |
| **L** | logistics lens (roads and delivery) |
| WASD | camera · wheel — zoom |
| LMB / RMB / Esc | select or build / cancel |
| Space | pause · 1 / 2 / 3 — speed |
| U / R / B | upgrade / repair / bulldoze selected |

Saving: autosave to a single slot; "Continue" in the main menu.

## Tips for your first run

1. First 5 minutes: road → second pump → shelter inside the water zone. The game walks you through this step by step.
2. Watch "water for N days." By day 18 you need 10+ days of reserve and two pumps.
3. Don't say "yes" to the League on everything — city support will drain away. And vice versa.
4. An icon over a building — click it. The game explains, but it won't fix things for you.
5. Lost? Read "SUMMARY" on the ending screen and try a different style: runs are short.

## For testers: what we need from you

Play without outside hints. After the run, answer (short is fine, voice or text):

1. What did you think the goal of the game was? When did you realize it?
2. What happened at the end and **why** — in your own words, before reading "SUMMARY." Did it match?
3. Was there a moment of "I don't understand what to do"? When exactly?
4. Water: did you get how reserve differs from coverage and pressure? What helped or got in the way?
5. The Desk: was it clear what each answer does?
6. What annoyed you in the controls or interface?
7. Did you want to play again differently? How?

Also: a screenshot of the ending screen and, if the game broke, what you were doing just before.

## Known limitations of the test build

- One region, two patrons (the League and the Directorate), 30 in-game days.
- Art is being replaced: some buildings and all decoration are still placeholder.
- The English localization is new: please report any untranslated or awkward text.
- No mobile versions and no gamepad.
