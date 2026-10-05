# R151 weather + keyboard performance patch (and snow across the whole hub)

Owner, R151:
- *"for the snow make sure the snow piles are visible throughout and not just when players walk into an area that it appears, also do a performance patch on the weather and keyboards, see what we can improve in performance while retaining quality and feel"*
- *"snow piles can be bigger and more combined so we don't have to deal with that much performance demand too"*
- *"same for rain, some of the droplets can have impact with the ground, not all"*
- Keyboard screenshots (Snow biome on PC, Lava biome on a phone): a big area near the player had no keys, only flat floor.

The picture is `docs/proposals/R151/snow_hub.png`. It shows a blizzard before and after, seen from a base, from the market and from above.

**How these numbers were measured.** Every number below comes from the real scripts of this checkout running on the Roblox mock (`/opt/luau/luau`). For the hub numbers, `docs/proposals/R151/tests/hub_snow_scene.luau` loads the owner's place (`sapkeyver.rbxl`) and runs the real start-up builders, the R151 festival square and the real weather client. It runs 40 s of weather with the player at a spot, and then counts:
- the parts drawn
- the property writes in the last 10 s
- the raycasts
- the live particles (rate x lifetime)
- how much of the hub floor is under snow (on a 4-stud grid)

"Before" means the same hub with the R150 weather scripts (`ad40efc`). "After" means this checkout. The mock can't measure milliseconds, so the cost is counted in parts, particles, writes and rays. Frame times in Studio are listed at the end under the checks still to do.

## 1. Snow across the whole hub (blizzard)

Before, the R150 snow patches only appeared within 130 / 100 / 70 studs of the player (tier 3 / 2 / 1). They were small, so most of the hub showed no snow. Now one fixed layout of big drifts covers the whole hub, from the walls (x -335 .. 335) to the safe line at the track (z -104 .. -618):
- banks along the walls and fences
- drifts in the corners
- drifts on the open lawns
- a light sprinkle inside the bases (tier 3 only)

Every player sees the same layout, because it is placed by hash and not at random. Banks are thicker along the walls, fences and corners and thinner on open grass.

Player at Base 1 (-118, -186). Tiers 3 / 2 / 1 are PC / phone / FastMode.

| | tier 3 before | tier 3 after | tier 2 before | tier 2 after | tier 1 before | tier 1 after |
|---|---|---|---|---|---|---|
| snow parts drawn | 84 | 189 | 57 | 152 | 30 | 132 |
| hub floor under snow | 0.9 % | 13.1 % | 0.6 % | 13.1 % | 0.3 % | 13.3 % |
| hub zones with snow (3 x 3 grid) | 4 / 9 | **9 / 9** | 4 / 9 | **9 / 9** | 2 / 9 | **9 / 9** |
| parts per 1 % of floor covered | 95 | **14** | 97 | **12** | 94 | **10** |
| snow on things it must avoid | 44 overlaps (pedestal, garden beds) | **0** | 2 | **0** | 2 | **0** |
| weather writes in 10 s, standing still | 639 | **344** | 249 | **163** | 249 | **146** |
| ground raycasts in 10 s | 85 | 85 | 85 | 85 | 47 | 47 |

- **Bigger, merged drifts.** One drift is a stack of 2–4 overlapping flat lobes. Each part now covers about 7x more ground than before, so 13 % of the hub is covered with 130–190 parts. With the old small patches the same cover would take about 1,250 parts.
- **Part budgets per tier.** The caps are 340 / 230 / 170 parts. The worst case over the whole hub in the test is 310 / 193 / 156. The owner's place was measured at three spots on each of the three tiers (`run_perf.sh`). Every run covered all 9 zones, put no snow on an avoided part, and stayed inside the budget.
- **Level of detail.** Near the player a drift has all its lobes. At mid distance it has fewer, and far away it is a single part. Lower tiers use shorter bands. There is an 8–12 stud buffer at each band edge, so a drift doesn't flicker as you walk past it. 24 drifts are re-checked per step, with a cap on how many may change shape. Only the parts that change are rewritten.
- **Standing still costs nothing.** Once placed, the drifts are static. While walking, the test measures 4.1 snow writes and 8.8 weather writes per frame in total.
- **Things the snow avoids.** It never covers:
  - garden beds and aisles, plots, pack pads and pedestals
  - treadmills, the market and Verity, the displays and leaderboards
  - the R151 festival square's streets, plazas, fountain, arches and gate feet
  - anything tagged `SnowAvoid`, and shovel holes
  - anything that streams in later (a drift over a bed that loads later is dropped at once)
- **No z-fighting.**
  - Drifts sit on separate height levels, 0.004 studs apart. No two overlapping drifts share a top, and no top lands on a street or curb plane.
  - The R149 z-fight check on the owner's place finds 0 snow problems. It found 4 at `3484f31` and 4 at `a669234`.
  - That check also counts 128 / 461 keyboard findings (normal / snow scene). These are the same before and after this patch. They are all keycap-mesh pairs from `e226df0` and are left for whoever owns the keycaps.
- **Fade.** Everything fades in and out with the one snow level (`WeatherWorld149.Level`). Reduced Motion is not affected.
- **Bug fixed.** In R149/R150, the second blizzard of a session showed no snow at all. `Level` was reading a time that the pruned history had already dropped.

### Snow biome (on the keyboard track)

The Snow biome's own banks are now fewer and bigger. Edge banks go every other row and are stretched along the track. Border patches use a checkerboard and are 1.35x larger. The total snow area stays the same: 17,004 sq studs before, 17,202 after.

| | before | after |
|---|---|---|
| edge / border bank patches in the biome | 87 / 25 | **48 / 19** |
| parts around a runner, tier 3 (z 1250 / 1500 / 1950) | 77 / 103 / 110 | **43 / 84 / 90** |
| tier 2 | 52 / 62 / 82 | **30 / 54 / 69** |
| tier 1 | 10 / 0 / 18 | **4 / 0 / 13** |

## 2. Rain and thunderstorms: only some drops splash

Rain falls just as densely as before; only the number of drops that splash on the ground went down:
- Near the player on tier 3, 20 % of drops spray and 14 % leave a ripple. In R149/R150 it was 40 % and 30 %.
- Far tiles splash down to 0.45x of that.
- Phones get 0.75x and FastMode gets 0.6x.

| live particles (Base 1, 40 s) | tier 3 before | after | tier 2 before | after | tier 1 before | after |
|---|---|---|---|---|---|---|
| rain drops | 2,274 | 2,274 | 640 | 640 | 430 | 430 |
| splash particles, rain | 721 | **299** (-59 %) | 197 | **61** (-69 %) | 30 | **8** (-73 %) |
| splash particles, thunderstorm | 719 | **299** | 197 | **61** | 30 | **8** |
| weather writes in 10 s, rain | 709 | **606** | 282 | **259** | 282 | **253** |
| weather writes in 10 s, thunderstorm | 790 | **720** | 309 | **296** | 309 | **290** |

The weather client also got cheaper in other ways (same look):
- The pass that sets emitter rates is skipped while nothing it depends on has moved.
- Gusts on far tiles are written less often. A tile's wind is only rewritten when the gust has moved by `3 - 2 x weight` studs/s².
- The "am I in a base" check reads the track rectangle. It used to build 14 attribute-name strings ten times a second.
- Snow ground rays respect CanCollide.

## 3. Keyboard: no missing keys near the player (top priority), at the same cost

**Cause, reproduced on the mock with the owner's view.** The keys are drawn in a window of rows. The window's long side followed only the camera's `LookVector.Z`, with a dead zone of ±0.25 that kept the old direction. Picture a player who carries a pack back to base (camera toward -Z) and then looks across the track, or straight down on a portrait phone. The long side stayed behind him, so where he looked he got only the short "Back" rows: 98 / 65 / 41 studs on tier 3 / 2 / 1, then bare floor. It was not a speed or budget problem: sprints up to 1,000 studs/s never missed a key along the track.

**Fix.**
- **Window direction.** The window now follows the camera's *heading* and has three states:
  - along +Z
  - along -Z
  - across the track (sideways, or looking straight down), with the same number of rows on each side
  - Between these bands it keeps its current state, and a change must hold for 0.2 s, so it never flickers.
- **Near zone.** It covers 114 / 90 / 65 studs on each side, across the full width. It is drawn in the same frame, whatever the budget (teleport, respawn, tier change). If the part cap is reached, the rows farthest away make room.
- **Adaptive budget.** The budget grows with the rows the runner crossed since the last frame (up to 16 extra rows), so a sprint at any speed keeps up.
- **Stand-ins.** Far rows that are still waiting for keys (a turn is spread over a few frames, as before) show a flat slab in the biome's mean key colour instead of bare bed:
  - at most 8 slabs
  - each slab's top sits 0.08 under the key tops, so it is never coplanar with a key
  - the slabs are put away once the keys arrive

| keyboard (mock, R149 suite) | before (`a669234`) | after |
|---|---|---|
| rows with no keys and no stand-in, camera across / down, tier 3 | **100 rows (~820 studs)** | **0** |
| same, tier 2 (phone) | **68 rows (~560 studs)** | **0** |
| owner's case (back from a run, then look across), bare rows while it fills | 32 | **0** |
| near zone each side (tier 3 / 2 / 1) | 98 / 65 / 41 studs | **114 / 90 / 65 studs** |
| near-zone keys missing: 7 biome teleports + 4 sprint speeds (141–2,000 studs/s), 6 camera directions, 3 tiers, 60 + 30 fps (252 teleports, 6,480 audited sprint frames) | 0, but only within the smaller zone (the rows above it were bare) | **0** |
| key parts in the pool, tier 3 | 3,058 | 3,102 (+1.4 %) |
| instances under the keyboard folder | 3,725 | 3,771 |
| sprint at 1,000 studs/s, property writes per frame | 295 | 296 |
| camera turn on a phone: worst frame / frames to settle / total writes | 551 / 8 / 3,231 | **559 / 7 / 3,033** |
| teleport +260 / +700 / +1500 / -700 / -1500: frames until the whole window is there | 3 / 7 / 9 / 5 / 9 | **2 / 6 / 9 / 5 / 9** |
| stand-in parts | 0 | ≤ 8 (0 at rest) |

Turns stay smooth: the near zone looks the same in every direction, so only the far side moves, and it is still spread over about 7 frames.

## 4. Tests

| suite | result |
|---|---|
| `docs/proposals/R151/tests/run_perf.sh` | test_hubsnow 75 checks, 0 failures; owner's place 9 / 9 runs ok; `mutate`: 16 / 16 caught |
| `docs/proposals/R149/tests/run_keyboard.sh` | 465 checks, 0 failures (section 5d is new: the near zone); `mutate`: 48 / 48 caught (4 new) |
| `docs/proposals/R149/tests/run_weather.sh` | test_weather 192, test_snowbiome 64, test_keyboard_fx 41 checks, 0 failures; `mutate`: 24 / 24 caught; `run_all.sh` (R128–R131, R147) passed |
| `docs/proposals/R150/tests/run_sfx.sh` | passed |
| `docs/proposals/R149/tests/run_zfight.sh <dir> sapkeyver.rbxl 3484f31` | PASS, 0 snow findings left |
| `docs/proposals/R151/preview/run_snow_hub_preview.sh <dir>` | renders `snow_hub.png` |

## 5. Still to check in Studio (the mock can't show these)

1. **Blizzard on the real place, PC and the phone emulator.**
   - Drifts should read as snow piles from a base and from the market, at the default zoom and zoomed out.
   - Thickness: wall banks up to about 0.4 studs, open drifts about 0.07.
   - Look closely at the edges of the festival square's streets and curbs. There should be no snow on them and no flicker.
2. **MicroProfiler / Stats.**
   - Frame time in a blizzard and in a thunderstorm on a phone (tier 2), before and after.
   - The splash particles should drop by about 60–70 %; the rain itself should look as dense as before.
3. **Streaming.** Walk from Base 1 to Base 6 with StreamingEnabled on. No drift should show over a bed that streams in late; such a drift is dropped as the bed arrives.
4. **Keyboard on a phone.**
   - Carry a pack back to base, then look across the track and straight down. Also teleport into each biome and sprint with a speed boost.
   - There should never be bare floor around the player.
   - The stand-in slab under far rows should be hard to notice (it lasts a few frames), and its colour should match the biome's keys, especially Lava and Snow.
5. **A second blizzard** in the same session shows snow again (the `Level` fix).
6. **Keycap meshes.** The 128 / 461 keyboard findings in the z-fight check are keycap mesh pairs from `e226df0`. They are unchanged here and belong to whoever owns the keycaps. Check them with `RenderFidelity` Automatic and look at the triangle count.
7. **Props.** If a festival-square prop should stay clear of snow and isn't, tag it `SnowAvoid`; no code change is needed.
