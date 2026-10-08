# R153: parts dislocated on packs

Owner, on R152: "parts are dislocated on packs". Screenshot: the yellow Verity pouch held edge-on; the seal at the bottom and the tear strips at the top sit off to one side of the pouch, and the top looks doubled.
Picture: `pack_parts_fix.png` (before = R152, after = this fix; Cycles renders of the real geometry, not Studio).

## Root cause

Every pack's pouch closes on one plane: the pack's z = 0. The `BottomSeal` and the 8 `TearStrip`s (`SeedPackVisuals.Bag`) are built on that plane. The pouch mesh of all 42 designs closes there too (its crimp rows are at z = 0, y = 1.02 / -1.04, x = ±0.95).

A template's `PackLocalFrame` is a different thing. It is the centre of the pouch mesh's **bounding box**, and that box is lopsided because the print stands out of the front. For Storm_02 the coil relief reaches z = -0.549 and the back only reaches 0.455, so the box centre is at z = -0.047.

1. **Verity (the screenshot).** R152 swapped the copied Storm_02 mesh for a generated flat pouch (`VerityPouch151.Generate`). The new pouch is symmetric about its own centre, but it still took the old mesh's `PackLocalFrame`. So the whole pouch sat 0.047 pack units in front of its seal and strips. That is more than the crimp's own thickness (0.04), so the strips stood beside the crimp instead of on it: the step the owner saw. It showed in every view, because every view builds the same pack.
2. **Shapes on 16 tall designs (also R151/R152, shared code).** `PackShapes151.Deform` keeps the field still for |v| ≥ 0.94 of the design's box, and for most designs that box is the pouch. For 16 designs the box also holds something beyond the pouch: a crown, wings or a glass shell (Crystal_05/06, Desert_05/06, Forest_05/06, Jungle_05/06, Lava_03 to 06, Snow_05/06, Storm_05/06). In those designs the pouch's top crimp sat inside the moving part of the field:
   * Pillow, Hourglass, Pear and Shoulders pulled the crimp in under the tear strips. The strip ends stuck out by up to 0.037 on each side, and by 0.072 on Lava_03 with Shoulders.
   * Flat slid the crimp up to 0.016 off the strips' plane.
   * A shape is kept everywhere except the Index, catalogue and shop pictures, so this showed in hand, on the track, in the base and in the hotbar.
3. **Void corner details (pre-existing since R122).** The print sits on two flat sheets at the box faces. On the front, the box face is the tip of the Forest_01 pouch's raised leaf, while the pouch itself curves back to between -0.08 and -0.31 under the corners. The middle of each sheet rests on the leaf. The corner details touched nothing and hung 0.16 to 0.46 off the pouch: the 4 rune sigils, 2 of the 3 stars and 3 of the 4 specks on each face. The R151 audit missed this because it treated each mesh as its box.

The real pouch is known offline. Each uploaded pouch mesh was made from the design's native render data (`src/ReplicatedStorage/SeedPackArt<Biome><NN>.lua`), and for all 42 designs the union of that data has exactly the template's box (to 1e-15). The checks use that data.

## What changed

| File | Change |
|---|---|
| `VerityPouch151.lua` | The baked flat pouch takes the template's x / y and 180° turn but is centred on the seam plane: `M.SeamZ = 0`, `M.SeamFrame`. Its knife edges now run into the seal and the strips, centred. Size, depth (0.56), faces, colours, Decals and the sachet fallback are unchanged. |
| `PackShapes151.lua` | `Deform` holds the pouch's own crimps still (`M.Pouch`, `M.Keep`): it keeps whichever hold is stronger, the box's or the pouch's. A design whose box is the pouch (26 of 42) skips this path entirely, so it is bit for bit what it was. `Field` (the Blender design) is unchanged. On the 16 tall designs, the crown or shell above the crimp now keeps the default shape. |
| `EclipsePackArt.lua` | The floating Void corner details are seated on the pouch (`A.Seats`, 18 groups, baked from Forest_01's real surface by `tools/void_seats.py`). Each keeps its x / y, size, turn and colour, so the front looks the same. The sheet itself is unchanged. |
| `VerityPackArt.lua` | A comment only. |

Nothing changes on the Mech pack, the 26 standard-box designs, the sachet, the seal or the strips. Config.Version, client scripts and the perf patch are untouched.

## Packs and views

Checked on the mock, in every context:
* ground (0.5x, 1x, 2.5x and 25x, in None, Gold and Diamond)
* held (R15 and R6) and CarryBag
* the opening copy
* pictures, including the real `ItemPictures` viewport behind the hotbar, Bag, Index and the Verity dialog card
* market, mystery pedestal and viewport
* the 6 shapes and the default

| Pack | Before | After |
|---|---|---|
| Verity flat pouch | Seal and strips 0.047 off the pouch's middle, in every view. | Centred (0.0000). |
| Verity sachet (fallback) | Fine. | Fine. |
| 26 ordinary designs | Fine in all 7 shapes. | Fine (unchanged). |
| 16 tall designs | Shaped crimps pulled in or slid. 367 failed checks. | Flush. |
| Legacy Small / Standard / Grand, giveaway (= Void) | Fine. | Fine. |
| Void | Corner details floating, 38 per pack. | Seated. |
| Mech | 18 parts float 0.08 to 0.20 off the pouch: pistons, cuffs, cuff lights, caps, power conduits, LEDs, core accents. **Not changed** (redesign in progress); listed by the check for that work. | Unchanged here. Look B (MechPackArt153, merged after): its own flat pouch / sachet, every part on it; COUNTED by the check (ground, held R15 / R6, 25x, both bodies): 0 float. |

Also noted, not changed:
* The Void's galaxy sheet rests on the leaf at the middle and its rim stands about 0.3 off the pouch. A flat print cannot lie on a curved pouch without bending it; that is the approved look.
* The R122 halo floats on purpose.

## Tests

`docs/proposals/R153/tests/run_pack_parts.sh` is registered in `tools/tests/run_all_suites.sh`.
* `test_pack_parts.luau` measures the seal and strips against the real crimps (centred, touching, not sticking out) on 1,448 built packs, 10,417 checks. Shaped pouches are baked by the real `Deform` from the real crimp vertices.
* `check_pack_parts.py` checks that the data is the place's pouch, and that no part hangs off it (the real surface, or a chain of touching static parts).
* The same run on R152 (8208603) must fail on exactly the reported kinds: seam = 56, crimp = 367, and 38 floating Void parts per pack. The Void seat table must equal the pouch depths there.

Older suites narrowed for the intended changes:
* `R151/tests/test_verity_pouch.luau`: the pouch's frame is now the seam frame.
* `R151/tests/run_packs.sh`: the fingerprint diff allows the seated Void details.
* `R151/tests/mutate_packs.py`: the Void star mutant's pattern.
* `R151/tests/test_pack_shapes.luau`: on a tall design, at least 5% of the mock lattice must move (was 10%), because the pouch hold keeps more of its box still. Shoulders moves 6 to 9%.

## Not checkable without Studio

* That the uploaded pouch meshes really are their native render data. The boxes match exactly, but the vertices cannot be downloaded.
* How a seated Void rune reads where the pouch curves under it: it touches at its highest point, and its far edge stands off by up to 0.1.
* That the Verity pouch looks right in hand at the owner's angle. **Please check:** hold the Verity pack and look edge-on; on a tall pack (Lava_03 to 06, Crystal_05/06) with a shape, look at the top corners.
