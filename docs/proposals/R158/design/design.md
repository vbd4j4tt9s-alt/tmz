# R158: track walls, outer track, base wall tops (preview, not built)

You asked: "look into designing each of the track walls and also the outer track designs can be added and so on and also polish up the base walls especially the top."

These are **pictures only**. Nothing in the game has changed yet. Tell me what you like and I will build it.

The pictures are made from **your real place** and the real game code, with the new parts added. They are close, but not exact: they are not Roblox lighting.

## 1. Track walls: a wall for each biome

Picture: `track_walls.png` (left is now, right is new).

Your walls stay the same size and the same height. Nobody can stand on them, just like now. The new parts sit on the inside of the wall and on its top. You can walk through them (they do not block you, the keepers, the packs or the camera).

| Biome | New look | Parts (both walls) | Lite (phones) |
|---|---|---|---|
| Forest | A log fort: round logs with sharp tips all along the wall, two log rails, moss at the bottom, ivy. | 306 | 282 |
| Jungle | Temple ruins: mossy stone, stepped temple tops, carved stone faces, leafy pillars, vines, bushes on top. | 250 | 120 |
| Desert | Sandstone temple: a big top lip, painted bands, small gold-tipped obelisks, golden winged suns, carved doors. | 197 | 99 |
| Snow | Ice bricks: ice pillars, a soft lumpy snow cap, icicles, snow drifts at the bottom. | 236 | 134 |
| Lava | Volcano rock: a jagged rocky top, glowing cracks, a glowing line at the bottom, lava drips. | 228 | 144 |
| Crystal | Purple crystal stone: big crystals growing on top, glowing stripes, crystals in the wall. | 238 | 186 |
| Storm Peaks | Dark slate fort: broken stone teeth on top, copper lightning rods with glowing tips, big lightning bolts. Also on the end wall. | 256 | 205 |
| Where two biomes meet | A stone tower with a glowing band in the next biome's colour (6 places, both sides). | 36 | 36 |
| **All** | | **1,747** | **1,206** |

The wall itself also gets a new colour and material in each biome (wood, stone, sandstone, ice brick, basalt, slate). That costs no parts.

**Your choice:** Track walls: **yes** / **yes, but change ___** / **no**.

## 2. Outer track: what you see over the walls

Picture: `outer_track.png`.

Right now there is **nothing** outside the walls: no ground, just sky. The new outer track adds a ground outside the walls (grass, sand, snow, dark rock, purple stone, slate) and big simple shapes that rise over the walls:

| Biome | Outside the walls | Parts |
|---|---|---|
| Forest | Tall round oaks (you also see them over the gate from your hub). | 38 |
| Jungle | Giant flat-top jungle trees, a stepped temple, a cliff with a waterfall. | 31 |
| Desert | Big dunes, two obelisks, a great pyramid far away. | 27 |
| Snow | Snowy fir trees and big snow mountains. | 34 |
| Lava | A volcano with a glowing top and lava streams, more lava peaks. | 15 |
| Crystal | Giant crystal spires, purple mountains. | 32 |
| Storm Peaks | Dark peaks, two lightning towers, a big storm mountain behind the end wall. | 30 |
| **All** | | **207** |

All of it stays far outside the walls (100+ studs from the middle of the track) and away from your hub. Nothing can touch it, it casts no shadow, and it has no collision.

**Your choice:** Outer track: **yes** / **yes, but change ___** / **no**.

## 3. Base walls: the top of your castle walls

Picture: `base_walls.png` (now, then A, B and C: the gate, a stretch of wall, a corner, and C at night).

The gate is drawn **without** the "THE TRACK" sign (the hotfix takes it off). All three options also put caps on the gatehouse and on the two rook towers.

* **A. Stone caps** (261 parts). A dark stone cap on every merlon, and a stone edge along the whole top of the wall. Calm and clean. The closest to what you have.
* **B. Rook crown** (702 parts, but 218 of them replace the merlons you have, so 484 more). The top of the wall flares out like the rook towers at the gate: a stone ring, a dark step and a wide crown band on little stone brackets. The merlons stand on the crown, with caps. This one looks the most like a castle. The merlons stand 0.6 studs higher and reach 2.2 studs further into the hub than now.
* **C. Lantern walk** (530 parts). Stone caps, a stone walkway ledge on brackets along the inside, and small lanterns on it. The lanterns glow by themselves, so you see them at the track-refresh night and in cloudy weather.

(Flags and banners are not in these options, because you took them off in R152. Tell me if you want them back.)

**Your choice:** Base walls: **A**, **B** or **C**.

## How much it costs (speed)

* Every new part is anchored, has **no collision**, no touch and no query. No scripts, nothing runs every frame. The glow is Neon.
* Only big parts (20+ studs long: the long bands, the pillars, the logs) cast shadows: 494 of the wall parts. The small ones, the outer track and all the base wall parts cast none.
* Phones on low can use the **lite** walls (1,206 parts): the same walls without the small extras (vines, faces, suns, doors, icicles, cracks, bolts).
* For size: your map has about 10,000 to 12,700 parts with the keyboard. The full walls add 1,747, the outer track 207, a base option 261 to 484.

## What else would change

* Nothing changes on the track floor, the keys, the keepers' paths, the pack spots, the R153 wall blockers or the R157 Desert pyramid.
* The Desert's 4.5-stud walkway next to the pyramid stays clear: no pillar or door on that part of the left wall (near the ground only a flat band, 0.6 studs).
* Near the ground, pieces stick out at most 3 studs from the wall face (the Forest moss). Higher up, at most 4.5 (the Forest log rails 3.7), and crystals on the wall top up to 6.
* The track-refresh cover is a black box up to Y 55. Wall pieces higher than that (log tips, obelisks, lightning rods, crystals, border towers) stand over it, so at refresh time you see the fort's outline. That is fine, but tell me if you want it hidden.

## Checks

* **Z-fighting** (flickering): the same detector as the R152 sweep, on your whole map with every new part and with the new wall colours. **0** flickers (`zfight.txt`). While designing it found 16, and I fixed them (the glowing bands on the border towers, the ivy tops).
* **Placement rules** (`make158.py check`): every part passes (how far it sticks out, nothing in the keys, the gatehouse or the Desert walkway, the outer track outside the walls and off the hub).
* No game code changed, so the R152 sweep (`run_zfight_sweep.sh`) is the same as before.

## Things I am not sure about

* The pictures are not Roblox lighting. Materials (wood, brick, slate...) will look richer in Roblox, and Neon glows more.
* The biome keys on the gate are drawn without their writing.
* The lantern night picture is made brighter so you can see it.

## Files

* `walls158.lua`: every new part as data (what a later build would make), `D.Restyle` (the new wall colours), what option B replaces.
* `dump158.luau`, `make158.py`, `render.sh`: `sh render.sh <scratch folder>` redraws the three pictures and runs both checks.
