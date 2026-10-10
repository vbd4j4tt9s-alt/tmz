# R158: track walls, outer track, base wall tops (built: see "Built" at the end)

You asked: "look into designing each of the track walls and also the outer track designs can be added and so on and also polish up the base walls especially the top."

The first part of this file is the preview you looked at (kept as it was written: pictures only). **Everything you approved is now built. What is in the game, what changed on the way (your later notes) and what to check in Studio is in "Built" at the end of this file.** The models for the outer track are in `outer_track_assets.md`.

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


---

# Built (R158)

You approved: the track walls for every biome, the outer track, and base walls **A** (stone caps). On the way you added: no repeated look on the walls, your own models for the outer track (pyramid, volcano, snow hills, dark mountain), "use our own crystal models", and "remove the lava flow and pond / the streams / the lava pool". All of it is built.

## What is in the game now

| What | Where it is built | Parts |
|---|---|---|
| **Track walls**: a different dressing in each of the 7 biomes, plus the 6 border towers | `TrackWalls158` (data in `TrackWallSpecs158`) | **1,310** (the design said 1,747 at most) |
| **Base walls A**: stone caps on every merlon of the hub wall (gatehouse and rook towers too) and a stone edge along the whole top | `TrackWalls158` | **261** |
| **Ground outside the walls**: grass, sand, snow, dark rock, purple stone, slate | `TrackWalls158` | **15** slabs |
| **Models outside the walls**: your pyramid, dark mountain, volcano, snow hills, and the game's own oaks, jungle trees, ice trees, crystals | `OuterTrackLoader158` (spots and ids in `OuterTrackAssets158`, the pyramid and dark mountain as data in `OuterTrackModels158`) | **1,977** parts with nothing dragged in, plus your volcano and hills when their meshes load |
| **Lava**: no streams, no pools; your volcano in place of the old cone | `LavaVolcano158` | 762 parts removed |

They are called from `MapService.new`, in this order: the hub dressing (`HubDecor151`), then the walls (`TrackWalls158.Apply`, which starts the model loader in the background), then the volcano (`LavaVolcano158.Apply`), all **before** the keyboard decides which keys to leave out (so the keys fill the floor where the lava was). Each call is inside a `pcall`: if one fails, the map is as it was and the Output says why. `HubDecor151`, `BiomeVisuals`, `Config.lua` and the bat files are not touched. One client script changed: `LavaFlow.client.lua` (see Lava).

## Track walls (full version everywhere)

| Biome | Built | Design | What the wall looks like |
|---|---|---|---|
| Forest | 238 | 306 | log fort: logs of every thickness in an uneven row (a few gaps, a few short broken ones, tops rolling up and down, each leaning a little), most with a sharp tip, some cut flat, two log rails in pieces, moss banks in patches, ivy strands in a few places |
| Jungle | 159 | 250 | temple ruins: bands in close shades, crenels that differ (stepped, plain, missing), unevenly spaced pillars (some broken), carved faces (whole, weathered), hanging vines |
| Desert | 140 | 197 | sandstone temple: painted bands in warm shades, pilasters where only some carry an obelisk (each its own height, gold or turquoise tip), suns, plain panels and doors in some bays only |
| Snow | 142 | 236 | ice bricks: a snow cap, ice pillars (some broken), icicles in bunches of 1 - 3 of different lengths, drifts at the foot |
| Lava | 190 | 228 | volcano rock: a jagged crest of every height, columns (some broken), glowing seams in pieces, cracks of different length and bend (no drips: the owner had them removed) |
| Crystal | 180 | 238 | crystal stone: clusters of 1 - 3 crystals of every height and lean, glow line in pieces, glow stripes on some pillars, small crystals in the wall in some places |
| Storm Peaks | 225 | 256 | slate fort: buttresses of different height, lightning rods on some (each its own length and lean), broken teeth, bolts in some bays (also on the end wall) |
| Border towers (6 places, both sides) | 36 | 36 | a stone tower with a glowing band in the next biome's colour, each a little different |
| **All** | **1,310** | **1,747** | |

Picture: `track_walls.png` (left: before, middle: built, right: built, along the wall) and `base_walls.png` (before and A), both drawn from the real map the game builds.

**Removed at your request (10 Oct: "remove those leaf balls, don't have plain balls or anything that might reduce the look of the walls", and the Lava drips "gone")**: every round piece and the drips, 171 parts in all, nothing added in their place and every other piece exactly where and what it was (the walls draw from fixed seeds, and the removed pieces' draws are still made). Forest: ivy leaf balls 8, moss tufts 4. Jungle: leaf crowns 8, overgrowth blobs 15, rubble blobs 10, vine leaf balls 10. Snow: snow pillows 55, snow mounds 26. Lava: drips 20. Storm Peaks: charged tips (glow balls on the rods) 15. Desert and Crystal had none. The base walls (stone caps) had none. The tests check it (no Ball, no sphere mesh, nothing named like a ball / blob / leaf / crown / drip on any wall).

**Full version everywhere.** The lite set (`TrackWalls158.Lite = true`: 1,020 parts, the same walls without the small extras) is in the code as a one-word switch, but I did not use it for any biome: the walls have no script and nothing runs per frame, they are small anchored parts that nobody can touch, and only **352** of them cast a shadow (the design said 494: thin flat bands cast none). The performance tests only look at looks, sounds and lag in scripts: none of them showed a reason to cut. The phone check is yours (below).

**No repeated look** (your note about "green balls on each wooden stick"). Every wall (biome and side) takes its details from **its own fixed seed**, so the same server always builds the same wall, but along it nothing is stamped: posts, pillars and teeth are spaced unevenly, details skip some posts and bunch up on others, sizes run 0.7 - 1.3 times, heights and leans differ, long bands are cut into runs in close shades, and now and then something is broken (a short log, a missing crenel, a cracked face, a patch of moss bank). The Forest has no ivy ball on every log any more (and no ball at all, see below): a few ivy strands, each its own length and width. The tests check it (no run of 5 equal posts, uneven spacing, a spread of log tops and thicknesses). The base caps come in **five close stone shades** and a hair of thickness difference.

All the old rules hold: every part is anchored, no collision, no touch, no query; nothing under Y 5.25 where the keys are; nothing in the gatehouse; only flat bands (under 0.7 studs) on the Desert walkway and nothing near the R157 pyramid; at most 3.2 studs into the track near the ground, 4.5 over heads, 6 on the wall top.

## Outside the walls

* **Only the flat ground is built from parts.** Everything else is a model (owner: "just place the stuff"). The table of keys, spots, sizes, how many and what is done / waiting is in **`outer_track_assets.md`**. Two ways to give a model: send the asset id (it goes in `OuterTrackAssets158.Ids`), or drag the model into `ServerStorage.OuterTrackAssets158` named by the key.
* **Done from your files:** the Desert pyramid (asset 9981304: its 82 blocks built in as data, no loading), the Storm Peaks dark mountain (1,532 blocks cut down to **280** per copy, no lights: `dark_mount_cut.png` shows before and after, the silhouettes overlap 97.7 % / 96.8 % / 99.8 %; two copies each side with their own size, turn and mirror), the volcano (mesh 5138886694 with its texture, loaded by id, or the model you drag in; four outside spots, each a different size, turn, lean and tint, two with a small glow, **no lava streams**), and the snow hills (16 hills, 4 meshes loaded by id; the trees are **re-placed unevenly** and 4 in 10 are the game's own snowy trees).
* **Forest and Jungle: only large trees** (owner: "forest and jungle can just have large trees on the outside with our current game assets"), made from the game's own trees: the map has ONE oak design (the Forest's three Oaks and the Jungle's two are the same tree in different sizes and greens), so the other looks are **the hub's own trees** (its round oak, poplar and palm). **Forest: 14 trees (7 + 7), 131 parts (was 12 oaks, 204 parts), 7 looks**: the Forest's Oak, four hub-oak crowns, two hub poplars. **Jungle: 29 trees (14 + 15), 348 parts (was 6 trees, 198 parts), 8 looks**: the Tall jungle tree with its vines, the Jungle oak, three hub palms, two hub-oak crowns, a hub poplar. Together **479 parts** (the limit you set: about 900). Three bands per side (a front row at 105 - 118 studs, a middle row, a denser and taller back row), 95 - 169 studs tall, every tree its own height and turn and a few close shades, along the whole biome on both sides, never inside |x| 100, never over the hub, never past the biome's ends. The Jungle temple and cliff keys are gone. Picture: `outer_track_built.png` (Forest and Jungle, from over the wall and from the track).
* **Also the game's own models:** the Snow trees (8, the ice trees), the Crystal spires (6, the crystal clusters scaled up and tinted).
* **Still waiting for a model** (nothing is built in their place): the Desert dunes and obelisks, the Crystal mountains, the Storm tower, lightning and end mountain.
* Picture: `outer_track_built.png` (what stands there now, offline: the volcano and the snow hills are meshes, so they only appear in Studio).
* Rules kept: all of it at 100+ studs from the middle of the track (or behind the end wall), never over the hub, no collision / touch / query, no shadow, scripts and sounds stripped from any model, the R157 pyramid on the track untouched. A model that is not there is one plain line in the Output, never a warning.

## Lava: no streams, no pools, your volcano

What was there (all of it scenery: no script hurts, slows or respawns anyone on it; only the builders, the client's `LavaFlow` animation and the keyboard's skip list touched it): the **lava river** (413 parts, with the pond at its end), the **two side pools** (106), the volcano's **three magma channels** (195), its **molten crater** (48) and the three rocks of the pond's **"Pool shore"**. **All of it is removed** (762 parts) at server start, whether or not your volcano model is there. The ground under them is the plain floor.
* **Your volcano replaces the old cone** at the same spot, scaled evenly until it fits the old cone's footprint (so nothing on the track moves; it stands taller than the old 28.5 studs, as your model is). It is walk-through like the old one (no collision, no touch). The old embers, smoke and light move to its mouth. The swap happens **in the background** (the mesh request may take long or hang: the server never waits for it, players are set up at once); the old cone stands until the model is there and stays for good if it never comes (one plain line says so). The volcano's mesh is asked for **once**: the swap and the loader of the four outside volcanoes share the request. The keyboard's skip scan (which runs at once, on the old cone) is unchanged; if it ever ran on the mesh, the mesh's square box would leave out keys under its corners, so the mesh carries `KeyboardDisc`, the radius of the circle the old cone's own parts cover (measured before they are destroyed) and the scan reads that instead.
* The keyboard now has keys where the lava was (the lava area only; the rest of the keyboard is identical, checked part by part).
* `LavaFlow.client.lua` only served the streams. It now does **nothing per frame** until a stream or pool exists (and lets go again when the last one is gone). Its first line (the load guard) is untouched.

## The track refresh (the black cover)

The cover is a black box up to Y 55. **463** wall parts stand over it (444 above Y 55: log tips, obelisks, rods, crystals, border towers; and 19 at or below Y 55 that stick out of its sides, up to a stud past |x| 94: the top bands and the temple tops): they would show as a dark outline against the box. **Chosen:** they are hidden while the track refreshes. The server listens to the map's `BiomesRefreshing` attribute (which the refresh already sets) and turns those parts invisible and back: a few hundred property writes per refresh, no script on the client. Your outer models are not hidden (they are far outside the box).

## Streaming

All new parts are plain parts in plain Folders (each backdrop model is an **Atomic** Model: a tree or a mountain streams in whole, never half-built at the streaming edge; the walls, ground and caps are plain Folders, each part streams in and out on its own like the rest of the map). No client script looks for them (checked: none mentions them). The base caps are not Persistent. LavaFlow copes with streams streaming in and out.

## Speed

* New parts: walls 1,310 + caps 261 + ground 15 + models 1,977 = **3,563**, on a map of about 10,000 - 12,700 parts. Far parts stream out. The build takes about a second on the test machine.
* Every part is anchored with no collision, touch or query: they cost the physics nothing. No script, nothing per frame (LavaFlow got *lighter*). The glow is Neon.
* Shadows: **352** of the wall parts, 10 caps, **no** outer model (the design: none). `OuterTrackAssets158.Shadows = true` would let parts 20+ studs long cast one.
* The R152 z-fighting sweep and the new "camera anywhere" check find **0** flickers.
* Size of the change: six new scripts, about 109 KB of Lua (the installer's paste limit is about 300 KB). The biggest, `TrackWallSpecs158`, is 42 KB; `OuterTrackModels158` (the pyramid, the dark mountain, the hills' layout as packed numbers) is 17 KB.

## To check in Studio (the offline tests cannot)

1. **Phone frame rate**, walking each biome: the Forest (the log fort) and the Storm Peaks (four dark mountains, 1,120 parts) are the heaviest places. If a phone suffers, tell me which: switching `TrackWalls158.Lite` on cuts 290 small parts, and `OuterTrackAssets158.Slots` can lose spots.
2. **Night and cloudy weather** (the refresh night, rain / clouds): the Neon parts should glow by themselves (lava seams, crystal lines, border bands, rods' tips).
3. **Your volcano:** a moment after the server starts the Output should say `[R158 volcano] removed 762 ...; the volcano is the owner's volcano ...`. Is it the right size on the track, the right way up, with its texture? Do the embers and smoke sit on its mouth? On the outside volcanoes, is the small glow ball on the mouth? If the mesh does not load ("not authorized" or a timeout), drag the model into `ServerStorage.OuterTrackAssets158` named `LavaVolcano`.
4. **The snow hills** (outside the Snow track): do the meshes load, do the trees look uneven?
5. **The pyramid** far right of the Desert, the **dark mountains** (Storm Peaks), the **Forest and Jungle trees** (are they big enough from the track, do they read as a forest / jungle, are the hub's oaks / poplars / palms in the right greens?), the **ice trees and crystal spires**: sizes and spacing.
6. **The refresh:** the wall decoration over the black box vanishes while the track refreshes and comes back after.
7. **The keyboard** in the Lava biome: keys where the lava was, none left floating.

## Checks and results

`docs/proposals/R158/tests/run_walls158.sh` (on line 6 of `tools/tests/run_all_suites.sh`, before the R156 pyramid suite) runs, on the owner's place:
1. static: the six new scripts compile and are in `MANIFEST.tsv`, `MapService` calls them inside pcalls in the right order, `Config.lua`, the bat files, the frozen hashes and every client script's line 1 are untouched;
2. the data: parts per biome never above the design's numbers (and locked), every placement rule, shadows only on parts 20+ studs long, no repeated design, **no two base wall faces in one plane**, fixed seeds;
3. the outer data (60 checks): keys, spots, the owner's pyramid and dark mountain as data, and the Forest and Jungle trees (large, uneven heights, 6+ looks, both sides, the whole length, a denser and taller back row, no grid);
4. the map built with and without the R158 passes: everything else identical (the R157 pyramid, the keyboard outside the lava area, the keepers, the pack spots, the hub, the bases, the floor);
5. z-fighting with the camera anywhere (8 scenes: 0), and the R154 hub z-fighting in strict mode (0);
6. the real start-up in the mock (114 checks, the loader on fake models and the code review's fixes included), the boot test (`test_boot158.luau`, 11 + 10 checks: MapService.new never waits for an asset request), LavaFlow (12, and the old script must fail it);
7. 27 mutations (each break of the code must make a step fail: 27 of 27 are caught).

## Review fixes (10 Oct, after a code review of the build)

* **The volcano swap no longer runs on the boot thread.** `LavaVolcano158.Apply` used to ask for the mesh (8 s), then the asset by `LoadAssetAsync` (8 s) and `LoadAsset` (8 s) before `MapService.new` went on: about 24 s with Roblox's asset requests hanging, before anyone was set up. Now only the lava removal runs at once; the swap runs in `task.spawn`, the old cone stands until the mesh is there. The loader keeps one request per key in flight (`Loader.Pending`): the swap and the background loader of the four outside volcanoes share it. Test: `test_boot158.luau` (every request hangs: `MapService.new` returns at once and each request is made once; the mesh arrives 3 s late: the swap and the outside volcanoes happen then).
* A copy of a game model keeps **no tag and no attribute** (HideBushes124 tags the Tall jungle tree's bushes `HideBush` / `HideBushId`; Clone copies both, which would turn the giant copies' bushes see-through for a player hiding in a real bush); a source that is **not a Model** (a Folder from a loaded asset) is wrapped in one.
* The **keyboard** never leaves out keys under the mesh volcano's square corners: the mesh carries `KeyboardDisc` (the radius of the circle the old cone's own parts cover, measured before they are destroyed) and `KeyboardSkip152.Footprint` reads it; the scan with the mesh leaves out no key that the old cone's scan kept.
* The refresh cover hides the pieces at or below Y 55 that stick out of its sides (19 after the removals below; 463 pieces in all).
* **Nothing floats**: the Snow icicles' wall side stands under the cap's inner face, so they touch the cap.
* The mesh is asked for with `CollisionFidelity.Box` / `RenderFidelity.Automatic` (asked again without them only when the engine does not know the options); every backdrop Model is `Atomic`.

What the run found on the way and what was done: the base walls first had two places where look-alike faces on a textured material shared one plane, which the R154 hub check counts as flicker (the front / side copings met with a 0.4 overlap at the four corners, and the neighbouring caps on a rook tower shared a top and a bottom plane). The side bands now meet the front / back bands exactly, and every second cap on a rook tower sits 0.04 lower. The new plane check and the R154 step in `run_walls158.sh` keep it so (two of the mutations put each back).

Other suites on the final code: R152 z-fighting sweep, R149 z-fight, R154 hub z-fight, R151 base area, R153 track walls, R156 pyramid, R152 / R153 performance, the R149 keyboard and the keepers all pass; `check_compile_O0.sh` is ok. `R158/tests/run_hud158.sh` (not part of this build) fails its first static line ("Config.lua changed since c0af9d6": the R157b version bump) with or without these changes.

Tests that changed on purpose: `R149/tests/keyboard_place.luau` (the Lava biome leaves out no key for a lava stream or pool any more: it was 15 or more), `R156/tests/pyramid_map156.luau` (the Desert wall's own dressing may stand in the pyramid's Hold E zone: only flat bands there).
