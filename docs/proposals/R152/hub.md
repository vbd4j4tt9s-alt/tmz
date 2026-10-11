# R152 hub decor: what changed in the Seed Festival Square

Owner feedback on R151's hub (the walls, gate, streets and props round the six bases), answered in `src/` and tested on the owner's place in the
Roblox mock. Nothing outside the hub decor was touched (`Config.Version` is unchanged: the release step does that).

> "removing the fountain. reduce the amount of trees ... entrance is not placed properly to remove the front gates for the garden that was recently added"
> "remove these painting and flatten out the top of the wall the corners of the wall and the gate of the track has to be a castle like gate like u know a rook in chess that shape. remove these front guarded gates and fix any signs of z fighting"
> "remove these base 6 banners"
> "remove the signs, the banners and that red track thingy, make all the walls in the base area for the top design be like a rook in chess design"

The wall-top request changed twice: first "flatten", then "like a rook in chess" (a continuous castle battlement). The battlement is what ships.

## What changed

| # | Owner's words | Now |
|---|---|---|
| 1 | removing the fountain | `A.Fountain`, its call, `ctx.Fountain`, its sparkles / jet / ripples / giant seed pack, the four benches that faced it, the "SEED FOUNTAIN" sign board and the per-frame fountain code in `HubLife151.client` are gone. The plaza (`South plaza`, a brick disc of radius 21 at x = 0, z = -392) stays as plain paving. **The 18-stud circle round (0, -392) is kept clear** (`HubDecorKit151.Open`, refused by `HubLifeArt151.Clear`; a test checks the layout and the built parts) for the free Void Pack pedestal another change is adding there: no trees, benches, lamps, signs or beds. The two butterflies that flew round the fountain moved to the south lawn. |
| 2 | reduce the amount of trees | `A.Layout.trees` 62 -> **24** (38.7 %): the front corners by the gate, the lawns' outer edges, the market's sides, the garden mouths, the south corners, the two desert / lava garden alleys and the snow lane's far end. Gone: everything in the middle of the lawns, along the avenue, the streets and the lanes in front of the bases (no tree at \|x\| < 70 except the snow lane's far pines). The tree template / `TreeSlots` / `HubStudTrees151` / `HubTreeLoader151` logic is untouched and works with 12 leafy slots (8 oaks, 2 blossoms, 2 leafy trees; was 30). Still no collision. |
| 3 | remove the front gates for the garden / the front guarded gates | `buildArches` and **every** entrance piece at a base are gone: the footings, the white posts with base-coloured bands and ball tops, the pennant poles and pennants, the name beam ("NAME'S BASE" / "FREE BASE"), its trim, the number medallion with its rim, and `UpdateOwnerNames` with the attribute listeners. The potted topiary that stood guard either side of each spur's street end is gone too. Kept: the streets, spurs, base-coloured curbs, the welcome-mat disc on the street, the flower verge, and everything that existed before R151 (the base's own pad, spawn circle, fence posts, the grey aisle pavers inside the garden: `GardenBaseLayout` made those). |
| 4 | remove these painting(s) | `buildMurals`, its painter and the seven biome scenes, plates, frames, plaques, crests and number keys; `K.Murals`, `K.MuralW/H/Y0` are gone from the kit. The 14 wall lanterns stay (the cloudy-sky tests need them) on the same pilasters, now listed in `K.WallLanterns`. |
| 5 | flatten the top of the wall ... the corners ... **then** a rook's crown | The corner towers (cylinder, plinth, band, three roofs, finial), the hedge and the topiary balls are gone. The wall top is a **chess-rook battlement**: 218 square merlons (5 x 6 x 5 studs, the walls' own thickness, flush with both faces), a merlon on each of the four outer corners, one size and one rhythm all round (front 24 + 24 merlons 10.0 apart, sides 53 + 53 at 9.98, back 68 at 10.07, corners shared; each run's end merlons are fixed: the corners, and x = +-107.5 next to the gate towers). `K.Battlement` / `K.MerlonSpots` in the kit; one part per merlon, `CastShadow` off. Nothing else stands over the wall top (51): the plinth, gold string course and pilasters end under it, the pilaster caps are stone (the gold ones poked up) and end 0.1 under the top. The saved 1-stud wood caps (51 - 52) are hidden like the timber strips. Merlon tops are at 57, the gate towers at 73.8: none at tower height. |
| 6 | the gate of the track ... a rook in chess | `buildGate` is two **rook towers** at x = +-99 and a **crenellated gatehouse** between them. Tower: three round steps (diameters 17.4 / 16.2 / 15.2), a shaft that tapers (14.4 then 13.0, the only parts that collide: 2 stacked cylinders each), a gold ring at the walls' string-course height, a collar (15.4), a flare (16.4), a crown (17.4) and **8 square merlons** (3.4 x 5.4 x 3.4) on its rim, 45 degrees apart, plus two arrow slits on the hub side. Gatehouse: a plaster wall (y 44 - 58) whose ends sit inside the shafts, a gold course under it, a stone cornice over it, 12 merlons of the wall's size on the same 10-stud rhythm, and a raised keep in the middle with 5 more merlons and the "THE TRACK" sign. The seven biome keys (`Biome key i`, `M.SpeedNeed`, the green ticks) hang in front of the wall as before. No red crest, no flags, no roofs. Footprint: the stepped base reaches \|x\| = 90.3 as the R151 plinth did, the colliding shaft 91.8 (was 91): the 180-wide track is not narrowed. Stone and plaster colours from the kit palette (gold only for the rings and the course). |
| 7 | fix any signs of z fighting | see below |
| + | the signs, the banners | The wooden signposts (arm boards "Base 1 - Base 3", "THE TRACK", "MARKET", the south post), `A.Signpost`, `ctx.Signs`, the client's `applySigns` and its half-second refresh are gone; `A.Build` lost its `owners` argument. The six base banners (`buildBanners`, rods, cloth, stripes, tails) and `K.Banners` are gone. |

## Numbers

| | R151 as handed over | R152 |
|---|---|---|
| Server decor parts (`HubDecor151`) | 725 (walls 203, murals 256, banners 42, base entrances 96, gate 52, paths 76) | **487** (walls 341 of them 218 merlons, gate 70, paths 76) |
| Client parts, desktop (all levels) | 1101 (core 435 / detail 615 / fine 51) | **769** (309 / 418 / 42) |
| Client parts, phone tier 2 / low tier 1 | 1050 / 435 | **727 / 309** |
| Parts drawn on a phone at the front street | 680 | **528** |
| Parts in the mock's whole map | 10 242 | **9 674** |

## Z-fighting

The R149 detector (`docs/proposals/R149/tools/zfight.py`, all tiers) on the finished hub (`preview/run_hub_scenes.sh`: the real `HubDecor151` and `HubLife151.client` on the owner's place file), checked by `tests/check_hub_zfight.py`:

* **R151 as handed over**: 0 counted findings (coplanar / near / far) with a decor part, but 401 strict-tier pairs (offset up to 0.6) with one, 141 of them within 0.1 stud. 98 of those were between decor pieces: 80 mural layers (0.05 apart), 6 banner layers, 12 paving steps. 243 of the 401 belonged to murals, arches, the fountain, the corner towers and banners and went with them.
* **Found and fixed while rebuilding**: 82 coplanar pairs: 36 pilaster-cap tops sharing the plane y = 51 with the saved wall top (the old hedge had been hiding them; the caps now end 0.1 under it), and 46 faces of the saved wood caps sharing the planes of the new merlons (the five saved caps are hidden). Every ring, step, merlon and gatehouse piece of the new gate and battlement has its own plane (checked by the detector: no merlon z-fights the map's wall top: their bottoms rest on it, opposite faces never fight).
* **R152**: 0 counted findings with a decor part, 0 on a saved wall part, 0 new against the old hub (`run_base_area.sh`, and R149's whole-map `run_zfight.sh`: 0 left that are ours). 12 tight pairs remain, all by design: the paving's flat layers 0.05 - 0.06 stud apart (4.07 / 4.12 grass patches, stage circle 4.14 under the market square 4.20, streets 4.20 under plazas / nooks 4.26, circles 4.26 under curbs 4.32). That is over the depth-buffer rule (0.043 at 300 studs); lifting them further would also move `HubSnow151.Keep`.

## Tests (all pass)

The full runner (`tools/tests/run_all_suites.sh`, 64 suites) passes: 64 of 64 PASS.

* `docs/proposals/R151/tests/test_base_area.luau` (104 checks, via `run_base_area.sh`): the old fountain / arch / mural / banner / tower checks now assert the removal; new section 16 checks no fountain, base entrance piece, mural, banner, signpost, corner tower, hedge, topiary, crest or flag; 22 - 25 trees, none in the middle; the plaza circle clear; 218 merlons of one size standing on the wall top, one on each corner, evenly spaced per run, nothing but merlons over 51, none near tower height; both rooks (3 base steps, tapering shaft, ring, collar, flare, crown wider than the shaft, 8 square merlons 45 degrees apart on the rim); the gatehouse (wall between the rooks, 12 + 5 merlons on the 10-stud rhythm, rooks tallest, sign on the keep, 7 keys). Mutation-checked: a pilaster over the wall top, a gap in the rhythm, an arch post, a tree on the plaza, a crest, a seventh tower merlon, a hedge and a fountain bench each fail it.
* `run_hub_trees.sh` (57 checks): counts updated for 12 leafy tree slots; no signposts means no SurfaceGui in the square. `run_cloudy.sh`, `run_perf.sh` and `run_hub_displays.sh` pass unchanged.
* `docs/proposals/R152/tests/run_hub_zfight.sh <scratch dir>` (builds the hub with `preview/run_hub_scenes.sh`, then `check_hub_zfight.py`): the before / after z-fight report above; it fails on any counted finding with a decor part or any tight pair other than the six designed paving steps.

## Previews

`docs/proposals/R152/preview/run_hub_preview.sh <scratch dir>` builds the hub before / after and renders `hub_views.json` with R151's three.js preview (an approximation: no Roblox lighting, PBR materials or bloom):

* `hub_aerial.png`: the whole base area.
* `hub_rook_gate.png`: the gate from the hub, and the east rook up close.
* `hub_wall_corner.png`: a corner and a straight run of battlement.
* `hub_old_fountain_spot.png`: the empty plaza.
* `hub_entrance.png`: a base entrance and the view leaving a base, with no arch.

## Judgment calls

* "The signs" were read as the wooden signposts. The gate's own "THE TRACK" board stays on the gatehouse keep (the design brief keeps it readable on the gatehouse); only the red crest behind it went.
* The potted topiary at the spur ends were removed with the arches (they flanked the entrance like guards); the flower verge was kept.
* The grey stepping-stone path from an entrance into the garden is the pre-R151 `Aisle paver` row of `GardenBaseLayout`, not R151's: it stays.
* `WeatherWorld149.client` still looks for a `BaseEntrances` folder (it finds none) and `HubSnow151` mentions the arches in a comment: both harmless, left alone as outside the hub decor.
