# R154: z-fighting in the hub

Owner: "remove the cases of z fighting in the hub area too".

## How the hub was searched

- **Place.** The owner's current place file, with R153 installed (`5ea4542b-sapkeee.rbxl`).
- **Builders.** Every real start-up builder runs on the place in the R149 Roblox mock, through MapService:
  - ZFightFix149, MarketLayout, GardenBaseLayout and HubDecor151, with the trampolines;
  - the six treadmills, the garden fences, the mystery pedestals, Verity's dais and the leaderboards;
  - the keyboard at the gate;
  - the HubLife151 client, with every detail level shown (trees, lawns, lamps, bunting, verges);
  - the two hub displays, with both champions;
  - the Void giveaway pedestal.
- **Scenes.**
  - One scene of the whole hub (`tests/build_hub154.sh`).
  - The same hub in a blizzard: HubSnow151's drifts over the whole hub, at tier 3, with the player at six spots (0,-300; ±90,-200; ±250,-270; 230,-560). Every lawn lies within a spot's near band, and the back corner is covered.
- **Detector.** R149's detector looks at every pair of faces whose overlap lies inside the hub walls (x -340..340, z -623..-99), at every tier. That covers the plaza, the streets, the market, the bases' fronts, the gate run-up, the corners and the nooks.
- **What counts.** Unlike the R152 sweep, every pair counts here:
  - pairs between two of the saved place's parts;
  - pairs between server-built and client-built parts;
  - look-alike faces on a textured material (Grass, Slate, Metal, Brick, Plastic and so on). Roblox lays a material's texture out from each part's own position, so two overlapping parts in one plane show their two textures flickering through each other, even in one colour.
- **Rule for a visible pair.** A pair is visible when its two planes are closer than the depth rule allows: R149's coplanar, near and far tiers. That limit is 4 steps of a 24-bit depth buffer at the distance from which the overlap still covers about 8 pixels: 0.02 stud for a small overlap, up to 0.043 at 300 studs. An overlap wide enough to be seen from that 300-stud cap needs R152's 0.049.
- **Tight pairs.** Pairs that pass the rule but are still under 0.1 stud apart are listed as "tight".
- **Ranking.** Pairs are ranked by `score` = overlap area × facing × height × contrast:
  - facing: 1 for faces pointing up (flat ground seen across the square), 0.6 for sideways faces, 0.3 for faces pointing down;
  - height: 1 up to 10 studs over the ground, falling off above heads;
  - contrast: the colour difference, or 1 for another material or a decal; 0.5 for a textured look-alike.
- **The full list.** [`hub_pairs.tsv`](hub_pairs.tsv) has every pair, R153 against R154, worst first: rank, kind, tier, gap, the gap the rule needs, area, score, place in the hub, x / y / z, both parts and faces, which builder made them, and what became of each pair.

## What was found (R153)

The hub has 1,584 different pairs across the seven scenes. **98 were visible.** All of them came from our own builders:

| # | What | Pairs | Worst | Where |
|---|---|---|---|---|
| 1 | **Lawn patches** (HubLifeArt151 `A.Patch`). Each patch is a disc plus two smaller discs of the same colour, **in one plane**. The code comment said "look-alike overlaps cannot flicker", but Grass is textured. | 38 coplanar | 301 stud² (score 2,247 of the 2,358 total) | All 14 lawns: both sides of the avenue (±62, -205), by the market (±88, -282), by Verity (±82, -368), the gate corners (±124, -134), the deep patches over them (±78), and the desert and lava gardens (±232, -286 / ±276, -252) |
| 2 | **Fence foundations** (GardenFenceArt). The side sills ran under the front and back sills. Slate, one colour. | 48 coplanar: 24 tops of 2.7 stud², 24 outer ends of 2.4 stud² | 2.7 stud² | The 4 corners of every base's fence, e.g. (-148.1, 5.08, -297.0) |
| 3 | **Blizzard drifts** (HubSnow151). Two overlapping drifts in two different whites (11 / 255 apart), only 0.004 to 0.032 stud apart. | 4 near / far | 125 stud² | The back wall (303, -613), (190, -471), the lava garden walk (-176, -288), behind Base 5 (-174, -451) |
| 4 | **Double lamps** (HubLifeArt151 `A.Lamp`). The arm's bottom was flush with both lantern caps' bottoms. Metal. | 8 coplanar | 0.11 stud², 12 studs up | The four double lamps by the market (±53 / ±57, -236 / -308) |

Five more groups are not ours, and they are printed apart:

- **Allowed: the market showcase's crystal fruit.** 27 coplanar tops in the approved plant art (PlantArtCrystal "Harvest form"), colours 8 to 9 / 255 apart, 0.11 stud² each. Left on purpose since R152.
- **Allowed: the hub avatar.** 60 pairs on the R15 rig and 120 on the accessory handles. These are stand-ins on the mock. In the game they are Roblox's own avatar.

**The saved place's own parts are clean.** There are 227 saved-only pairs in the hub, and none needs a nudge:

- 112 are untextured look-alikes: the treadmills' SmoothPlastic chassis and console corners, which have one colour and no texture, so there is nothing to see.
- 96 are tight but inside the depth rule: the treadmill chevrons, 0.044 and 0.058 apart, on 1.6 stud² slivers, where the rule asks 0.02. These sit on the treadmill belts, which are not touched.
- 19 are 0.12 stud apart or more.

So the hub needs no runtime nudge module (no HubZFix154). Every fix is in a builder.

### The suspects, one by one

| Suspect | Verdict |
|---|---|
| SAFE ZONE run-up lanes and the "SAFE ZONE" ground title | Safe. Lanes are 0.06 over the floor (1,263 stud² each), and the title's GUI is 0.14 over the lanes. Both are over the rule's 0.049. |
| Path slabs against the saved floor | Safe. Streets are 0.20 up, plazas 0.14 / 0.26, run-up edge 0.14. |
| Curbs | Safe. 0.12 over the streets, 0.32 over the floor. |
| Market and pedestal bases | Safe. Doorsteps 0.14 over the market square, fruit-of-the-hour capital and glow 0.085, pots and barrels 0.06 to 0.08, mystery pedestal rim 0.09, giveaway pedestal 0.12+, hub display inlays 0.19. |
| Lawn patches | **Flickered** (row 1 above). |
| Garden-front spurs against the base pads | No overlap: each spur starts 0.1 outside its pad. |
| Gate area | Safe. Gate bases are 0.10 off the wall plinth caps. The keyboard's rim end is 0.04 under the floor and the spacebar 0.025 behind the safe line. Both of those are thin strips (0.24 to 0.4 stud), where the rule asks 0.02. Being the keyboard, they are not touched. |
| Decals and textures on coplanar faces | No two images share a ZIndex on any hub face. The floor's and pads' grid textures have nothing within 0.05. |
| Treadmill pads | Safe. Aprons are 0.14 to 0.19 over the pad, the inlay 0.05 over the apron, the underlay 0.12 under the belt. |
| Shadows of thin slabs | Not z-fighting. All hub paving and lawns are already built with CastShadow off (R151 / R152). |
| Bases' fence corners | **Flickered** (row 2 above). |
| Blizzard snow | **Flickered** (row 3 above). Snow over the lawns came within 0.012 to 0.046 of a raised lawn disc once the lawns had their own planes, so R154 keeps the drifts off them too (below). |

## Fixes (code only; nothing visible changes but the flicker)

- **`HubLifeArt151.lua` `A.PatchTop` / `A.PatchShape` / `A.Patch` / `A.PatchDiscs`.**
  - Each grass disc takes the lowest of `A.PatchPlanes` = 4.07 / 4.12 / 4.17 / 4.22 / 4.27 that is at least 0.049 from every grass disc it overlaps.
  - A disc stays above every disc of a lower layer it overlaps, and under every disc of a higher one. A deep-green layer-2 patch still lies over the light patch it meets.
  - Discs are laid in the fixed layout order, so every client builds the same planes.
  - Result: 10 discs at 4.07, 18 at 4.12, 10 at 4.17, 4 at 4.22. Each sub-disc stands 0.05 or 0.10 over its main disc.
  - Lawns have no collision, so walking does not change.
  - `A.PatchDiscs()` returns the same discs as data, for the snow.
- **`HubLifeArt151.lua` `A.Lamp`.** The double lamps' arm is 0.05 lower, at FLOOR + 12.15. Its bottom is now 0.05 under the caps' bottoms, and the pole top still lies inside the arm, so no gap opens.
- **`GardenFenceArt.lua`.** The side sills stop where the front and back sills start (`front-back-3.8` long, 0.3 back). This is the same outline and the same collision, just with no overlap. The fence rebuilds on every tier, so the fix belongs in the builder, not a start-up nudge.
- **`HubSnow151.lua`.**
  - **Lawns.** In `clashes`, a drift on the hub floor whose reach meets a lawn disc (`H.Lawns()` = `HubLifeArt151.PatchDiscs()`) keeps every top plane at least `H.LawnGap` = 0.049 from that disc's top.
    - It is lifted by more slots where it must: `H.Slots` is now 80 (0.32 stud); the other drifts never needed more than the old 40.
    - Drifts over the lawns lie up to about 0.1 thicker. Nothing else moves: snow coverage is still 13.7 to 14.2 % at every tier.
  - **Shades.** In `Assign`, drifts that overlap, in a chain, share one white: the shade of the first drift of the chain. All three whites are still used, at about 57 / 35 / 8 % of the drawn discs, where they were 44 / 21 / 35 %.
  - `H.Keep`, the drifts' heights elsewhere, and their slots are unchanged.
  - The first try put the new grass planes into `H.Keep` instead. That left the drifts too few height slots, and R151's `test_hubsnow` caught 116 shared planes, so it was dropped.

Not touched:

- the keyboard, the treadmill belts, the saved place's parts, client scripts, BackgroundMusic, and Config.Version;
- HubDecor151, the benches, the flower beds and the lamps' layout.

The tidy agent's lists in HubLifeArt151's `A.Layout` are not edited. Only the patch functions and one line of `A.Lamp` change.

## Before / after

| | R153 | R154 |
|---|---|---|
| Visible pairs in the hub | **98**: lawns 38, fence corners 48, drift whites 4, lamp arms 8 | **0** |
| Allowed (not ours: approved plant art, the mock's avatar) | 207 | 207 |
| Tight (rule met, under 0.1) | 265 | 264 (incl. the lawns' new 0.05 steps) |
| Saved-only pairs | 227, none visible | 227, none visible |
| Pairs in the hub, all kinds | 1,584 | 1,537 |

The worst ones before, and what they are now (all 98 are in [`hub_pairs.tsv`](hub_pairs.tsv)):

1. Lawn west of the avenue (-68, 4.07, -213): two Grass discs coplanar over 301 stud². Now 0.05 apart.
2. Lawn by Verity (75, 4.07, -374): 294 stud². Now 0.05 apart.
3. Lawn west of the avenue (-55, 4.07, -213): 285 stud². Now 0.10 apart.
4. Lawn by Verity, west (-84, 4.07, -360): 277 stud². Now 0.05 apart.
5. Lawn east of the avenue (54, 4.07, -212): 273 stud². Now 0.10 apart.
6. Blizzard drift by the back wall (303, 4.39, -613): two whites 0.020 apart over 125 stud². Now one white.
7. Base fence corners, e.g. Base 3 (-148.1, 5.08, -297.0): Slate tops coplanar over 2.7 stud². Now gone: the sills butt.
8. Double lamp arms (53, 16, -236): Metal bottoms coplanar over 0.11 stud². Now 0.05 apart.

What became of the 98:

| Outcome | Pairs |
|---|---|
| Gone (fence corners, lamp arms) | 56 |
| Now 0.05 apart | 28 |
| Now 0.10 apart | 10 |
| Drifts now in one white | 4 |

[`hub_zfight.png`](hub_zfight.png) shows close-ups before (R153) and after (R154): the two lawns, the desert garden lawn, a fence corner, and a double lamp seen from below. It was made with `tools/render_zfight_crops.py`, a diagnostic ray caster, not a Roblox render:

- each part is flat-shaded in its colour;
- a textured material carries a pattern laid out from the part's own position;
- where the two nearest surfaces under a pixel lie closer than a 24-bit depth buffer can tell apart, the pixel shows either one at random, outlined in magenta.

Flicker pixels per view before and after:

| View | R153 | R154 |
|---|---|---|
| Lawn west of the avenue | 3,469 | 0 |
| Lawn by Verity | 3,752 | 0 |
| Desert lawn | 1,053 | 0 |
| Fence corner | 1,639 | 0 |
| Double lamp | 82 | 0 |

## Regression check: the sweep's strict hub mode

`tests/run_hub_zfight154.sh` is in `tools/tests/run_all_suites.sh`, run there with "mutate".

- It builds the hub and the six blizzard scenes on the owner's place file, then runs `tests/check_hub_zfight154.py`.
- The check fails on any visible hub pair, or on stacked images on a hub face, unless the pair is on its short allowed list: the approved crystal plant art and the hub avatar's rig and accessories. It is R152's list without its weather line, because the hub's drifts are checked here.
- It reuses R152's `allowed()`, `stacked_faces()` and `MIN_GAP`.
- `mutate` puts the old lines back on copies of src, and each one is caught:
  - copy A: the grass discs of a patch in one plane (9 groups of pairs), the side sills under the front and back sills (18), the lamp arm flush with the caps (4), one white per drift (1);
  - copy B, alone: the drifts no longer kept off the lawns' raised discs (5 groups: 0.012 to 0.046 stud).
- `before=<src dir>` prints the same list for another tree. The R153 numbers above come from it.
- Without the place file the suite says SKIPPED.

## Left on purpose

- The crystal fruit in the market showcase, as in R152: approved plant art, and invisible at 8 / 255 and 0.11 stud².
- The tight pairs. The rule accepts them, and they keep their designed steps:
  - the R151 paving's 0.05 to 0.06 steps and the run-up lanes' 0.06;
  - Verity's glow ring, 0.08 over its inlay;
  - the lawns, 0.07 over the floor, and their own 0.05 steps;
  - the keyboard's rim end and spacebar at the gate, and the treadmill chevrons. These are thin strips the rule asks 0.02 of, and they are not touched.
- `WeatherWorld149.client.lua` still says, in a comment, that the lawns lie at 4.07 / 4.12. The rule is to leave client scripts alone, so it was not edited.
