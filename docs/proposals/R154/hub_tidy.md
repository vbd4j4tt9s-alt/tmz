# R154 hub tidy: fewer props, brighter warmer lamps

Owner: "reduce the amount of props in the base area like reduce the amount of lamps and to remove the soil beds and benches beside it just leave those parts empty. basically just tidy up
the base area"; then "the bushes and flags can stay"; and "make each lamp brighter in its warmth during cloudy season too".

Preview: `docs/proposals/R154/hub_tidy.png` (before = the R153 release as installed, after = this branch; from above, from the plaza, the east lawn, and the plaza and a side street under a Cloudy
sky). Made by `preview/run_hub_tidy_preview.sh` (the real builders and the real client in the mock, drawn by three.js: approximate, no Roblox lighting).

## What is kept: ONE table, `HubLifeArt151.Tidy`

`HubLifeArt151.Full` is everything the square had; `HubLifeArt151.Layout` is `Full` through `Tidy`, and the whole build, the clearance tests and the lights follow `Layout`. To bring a kind
back, flip its value (or add lamps to the list) and republish; `HubLifeArt151.SetTidy(table)` does it at run time (tests).

| kind | before | after | table value | note |
|---|---|---|---|---|
| round flower beds (white rim, black soil, flowers) | 10 (11 in the R153 release) | 0 | `Beds=false` | on the lawns, round the market, in the corner circles; the three nook beds went with the trampolines |
| benches | 4 (5 in the R153 release) | 0 | `Benches=false` | the market's two garden benches and the two wooden ones on the front lawns |
| pebbles | 40 balls | 0 | `Pebbles=false` | along the side streets and the garden walks (clutter without a purpose; the owner left the call to us) |
| lamp posts | 26 (30 lamp heads) | 12 (16 heads) | `Lamps={x,z ...}` | see below |
| bunting strings | 6 | 5 | `BuntingExtra` | the owner keeps the flags; the avenue's two crossing strings hung from the two lower avenue posts that went: one string now joins the two posts that stay |
| trees, bushes, topiary pots, grass patches, verges, wall lanterns | as before | as before | (not in the table) | the owner: "the bushes and flags can stay"; the trees, the market, Verity, the giveaway pedestal, the hub displays, the Fruit of the Hour pedestal and the treadmills are untouched |
| butterflies | 12 | 6 | `Beds=false` | review: 6 of the 12 were homed on the removed beds (60,-196) (-60,-198) (36,-252) (-36,-300) (118,-161) (-118,-409) and would circle bare lawn: they go with the beds (`HubLifeArt151.Filter`) and return with `Beds=true`; the other 6 (lawns, nooks, lane, market) stay with their wing colours |

The three trampoline nooks keep their trampolines (no beds or benches there any more). The players' own garden beds are gameplay and are not touched.

### The 12 lamps that stay (of 26)

Evenly spaced along the streets and round the market; every one that carries a real light stays (8: the real lights, their tier caps 8 / 4 / 0 and their mirror pairs are unchanged) and so does
every one that holds a string of bunting up:

- the west and east side streets: (+-106, -240) and (+-106, -340) (lit; they were five a side, 50 studs apart, now two, 100 apart);
- the avenue's mouth: (+-15.4, -200) (lit); the two lower posts (+-15.4, -228) are gone;
- the market's four corner doubles: (+-55, -236) (lit) and (+-55, -308), the candy bunting's four anchors;
- the garden walks' first posts: (+-140, -257).

Gone: the side streets' other three posts a side (z = -190, -290, -390), the avenue's lower pair, the south street's pair (+-30, -400), the four garden-walk bollards.

### The lamps' light (owner, with the tidy: "make each lamp brighter in its warmth during cloudy season too")

Each real light is brighter and reaches further, and warms toward amber at full glow, in the dark too:

| | R153 release | R154 |
|---|---|---|
| base light (`HubLifeArt151.LampLight`) | Brightness 1.4, Range 22 | 1.8, 28 |
| at full Cloudy (and The Darkened / Rain / Thunderstorm / Blizzard) | 1.4 x1, 22 | x1.5 brighter = 2.7, x1.3 wider = 36.4 |
| colour | (255,214,150) | toward amber (255,150,60) by 0.85 at full glow |
| lamp heads (neon, free) | warm only under Cloudy (80% toward (255,168,76)) | the same, and in the dark too |
| real lights | 8 (desktop) / 4 (phone) / 0 (FastMode) | the same 8 / 4 / 0 |

`WeatherCycle151.Lamps.Boost` / `LightWarm` / `LightWarmShare` hold the numbers. Timing and rules are unchanged: the lights and heads change only on the half-second tick's steps (24 steps over a
fade for the lights, 4 - 8 for the heads), nothing per frame, nothing once settled. `ClientFxBudget` has no light limit (its budget is for Highlights); the only light cap is the tier's real-light
count above, which did not change, so a phone still runs 4 point lights and FastMode none.

## Part counts (client square, HubLife151)

Counted from the four scene dumps of the preview (desktop tier, every detail level shown; before = the R153 release):

| | before | after |
|---|---|---|
| flower beds (rim, soil, flowers, stems) | 91 | 0 |
| benches (seat, back, legs, knobs, slab, blocks) | 23 | 0 |
| lamps (base, collar, pole, arm, lantern, cap, bollard) | 134 | 72 |
| pebbles | 50 | 0 |
| bunting (lines and pennants) | 44 | 34 |
| bushes, trees, topiary pots, grass patches, verges, wall lanterns | 360 | 360 |
| butterflies (2 wings each) | 24 | 12 (review: the 6 that circled the removed beds went) |
| **all parts of the client square** | **728** | **480** (248 fewer, 34%) |

The whole map's visible parts, trampolines included (they now fill their circles: fewer, bigger frames): 10307 -> 10112. The build budgets (`run_base_area.sh`, the `BUDGET tidy` lines), with the table
flipped back to everything and then as shipped: tier 1 272 -> 184, tier 2 638 -> 426, tier 3 678 -> 440 parts (what the tidy alone removes: 88 / 212 / 238; the butterflies are the tier 3 "fine" level).

## Nothing left behind

`test_base_area.luau` section 18: no bed, flower, bench, pebble or bollard part anywhere on the square; 12 lamp bases each with its collar and pole at the same spot and at a layout lamp, 16 heads each
with a cap, 4 arms, no head more than 3 studs from a lamp; the 8 real lights each on a head at a kept lit lamp; 5 strings of bunting, none hung from a lamp that went; and flipping the table back
restores 26 lamps, 4 benches, 10 beds and the pebbles.

## Review fixes

- **Trampoline looks fill the circle** (`HubTrampoline153`). The owner's model (asset 12088629887, or a template) was fitted by the 8 box corners of each part, so a round part (Cylinder, Ball, round
  MeshPart / union) counted D/sqrt2 instead of D/2 and a round look ended at 71% of the collider's circle: radius 8.91 of 12.60 in the garden nooks, 6.79 of 9.60 in the lane's. A round part is now measured
  by its circle (upright Cylinder: centre distance + D/2; Ball: + widest side/2; MeshPart / union with an axis standing: + the wider flat side/2), never past its own box corners, so a look that is not round
  (a square frame) is still fitted inside by its corners. A cylinder look now ends at 12.60 / 9.60 exactly. `ScaleTo(k)` is absolute, so a model saved at scale 2 came out half size: it is
  `ScaleTo(GetScale() * k)` now. `/test trampoline` says "round, so its rim lies on the collider's circle" or "not round ... fitted INSIDE the circle by its corners".
- **Butterflies**: 6 of the 12 were homed on the removed beds and circled bare lawn; they go with the beds (see the table), the other 6 stay.
- **Garden soil strip** (`GardenBaseLayout`). The 46 x 3 stud strip of soil in front of DirtPlot_5 (all 6 gardens, up to DirtPlot_9's front edge) was drawn but not solid, so walking in over the front border the
  feet were 0.4 - 0.8 below the soil you see. DirtPlot_5's ramps now stand at the strip's real front edge and sides, and one invisible flat block per base (`GardenBedRamps153` / `Soil edge top`, the soil's own
  thickness, its top exactly the soil plane 5.8, never above it) is the floor; planting, shovel and inspection rays are unchanged (6828 rays, none crosses a ramp).
- **Lamps in a Blizzard**. The Blizzard's palette dims the world like the other event weather (`BiomeMood.Palette`: Lighting.Brightness 2.55 -> 1.9, exposure +0.015 -> -0.05, no sun rays, haze 0.40 -> 1.30, air
  density 0.14 -> 0.30; Cloudy at full is 1.73, Rain 1.45, Thunderstorm 1.15), so `HubLife151.isDark` includes it: all 8 real lights at full glow and the heads warm, on every tier, as in rain.

## Tests

`docs/proposals/R151/tests/run_base_area.sh` (section 18 above; its lamp / bench counts), `run_cloudy.sh` (`test_cloudy_hub`: 16 heads, the boost, range and colour at full glow, the dark's warm
heads, the fade's steps and write counts; `test_cloudy_cycle`: the boost's bounds; `test_cloudy_place`: the owner's place), `docs/proposals/R153/tests/run_nooks.sh` (the layout now has no bench or bed; R154 review: round / ball / mesh / union / scaled trampoline looks, the soil strip walked at 5.8).
