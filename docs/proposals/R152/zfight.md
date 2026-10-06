# R152: z-fighting sweep

Owner: "after finishing implementation and fixes look for z fighting cases fix them".

Z-fighting is two visible faces that point the same way, lie in (nearly) the same plane and overlap: they flicker. The test is R149's detector (`docs/proposals/R149/tools/zfight.py`): coplanar (up to 0.002 stud), near (up to 0.02) and far (under 4 steps of a 24-bit depth buffer at the distance the overlap is seen from, 0.02 to 0.043 stud) pairs of faces that look different. Every fix keeps that gap or more (0.03 to 0.05 stud, a shift nobody can see).

## What was looked at, found and fixed

| Area | How it was looked at | Found | Fixed |
|---|---|---|---|
| Whole map and hub: rook merlons and gate, giveaway pedestal on the plaza, hub display pedestals, fruit-of-the-hour pedestal, market, treadmills (belts, trims, studs, lamps) | the owner's place after every start-up builder, hub decor + displays + giveaway, all tiers, plus the hub decor's own tight rule (under 0.1 stud) | nothing of ours | - |
| Keyboard: keys, letter strips, far strips, spacebars, floor copies where cells are skipped (oasis, lava river, arena), hole lift | the keyboard client at 8 places (the start and every biome), meshes counted as their boxes | 1 cause: every letter strip lay 0.04 over its keycap (about 14,500 key / strip pairs in the 8 scenes) | strips now 0.05 over the keys (`Legend.Margin`) |
| Baked keepers (8 models, rest and asleep pose) | `check_keeper_zfight.py`: every triangle pair of the drawn parts, face / eye plates and glow slits against the heads | 15 pieces in 6 keepers: golem (leaf cube on the hood step, torso piece against the stump), Sand Snake belly plate, Ice Fang face plate flush with the head, Lava Dragon (glow slits on body and legs, jaw), Crystal Knight (back plate against both legs, bright edge strips of the blade and point, 22 coplanar pairs), Storm Colossus cloud puff | each piece slid 0.01 to 0.06 stud (`blender/fix_zfight.py`) |
| Verity pack (flat pouch, seal, 8 strips, two face Decals) | 24 scenes: ground, held R15 / R6, picture, sizes 0.5 / 1 / 25, plain / Gold / Diamond, and the sachet fallback (all parts one yellow) | nothing | - |
| Pack-opening scenes: void vault, space stage, throne room (with and without drawn images, lite), sky beam landing on the ground (3 tiers), Legendary / Mythic flourish (3 scales); the seed card is a ScreenGui | 1,023 frames through each impact | 4: sky beam cracks under the tier-colour ring (0.015), debris on the ring (0.015), the two Mythic flourish rings crossing in one plane (coplanar), the void vault's rim glow 0.04 over its rune circle | rings and cracks in layers 0.05 apart (`RarePullFx`, `RevealFlourish`), rim glow 0.06 up (`RarePullScenes`) |

## Fixes

- `KeyboardTrack.lua`: `Legend.Margin` .04 to .05. Rim and pit lift tests follow.
- `RarePullFx.lua`: ground layers: cracks top .05, white ring top .10, tier-colour ring top .15 (were .05 / .085 / .095 and, without the halo image, .065 / .10).
- `RevealFlourish.lua`: ring 2 stands `max(.05, .06 x scale)` over ring 1.
- `RarePullScenes.lua`: void vault rim glow at .06 (was .04).
- Keepers: `docs/proposals/R152/blender/fix_zfight.py` slides one piece (one bevelled block) of each coplanar pair out along the face normal, by rule (overlays first, then the smaller box), until the gap is 0.03 to 0.05 stud. Data, `KeeperRigConfig152` (boxes, Bounds, Mouth) follow; `keeper_zfight_moves.json` lists the 15 slides; `blender/run.sh` runs the pass after `encode_meshes.py`, so a Blender regenerate gives the same files. The pass is idempotent.

## Regression checks

- `docs/proposals/R152/tests/run_zfight_sweep.sh` (in `tools/tests/run_all_suites.sh`): maps, Verity pack, opening scenes through `check_zfight_sweep.py`. Fails on any counted pair that is not on its short list (below), on two Decals / Textures with one ZIndex on a face, on a letter strip under 0.049 over its keys, on any opening layer under 0.049 apart. `mutate` puts the old heights back and expects failures.
- `run_keepers.sh` step 4: no counted pair in rest / asleep pose; the fix pass is a no-op and reproduces the committed files; each of the 15 slides, undone alone, is noticed again. Round-trip tolerance widened to 0.07 stud for the 5 parts whose box moved.
- `test_keyboard.luau`: `Legend.Margin` between .05 and .06.
- `zfight_world.luau` now writes each image's `ZIndex` / `ZOffset`.

## Left on purpose

- 27 coplanar tops in the market showcase's Crystal fruit (`PlantArtCrystal`, "Harvest form"): same-size cubes whose colours differ by 8 to 9 of 255, 0.11 stud² each. It is the approved plant art; the flicker cannot be seen.
- 8 pairs between the place file's saved keeper placeholders (`GuardianNPCPlaceholder_*`, uploaded meshes): the server dresses a real keeper over each. Not game code.
- 24 pairs between limbs of the hub displays' avatar: Roblox's R15 rig (stand-ins with different colours on the mock; limbs share a skin in the game).
- The "strict" tier (offset 0.043 and over but under 0.002 x viewing distance): not counted by the R149 rule, which asks no depth buffer for it. The hub paving keeps its designed 0.05 to 0.06 steps.
- Keepers in other poses (stride, strike): the pieces slide as one group, so a pair that is not coplanar in the rest or asleep pose is not coplanar for more than a moment. Faces hidden by the floor or by the keeper itself (the Sand Snake's belly plates 0.15 over the ground) are not counted: no camera sees them.
- The far letters (strips up to 800 studs out) keep the same 0.05: the R149 rule caps the viewing distance at 300 studs, where 0.043 is four depth steps.

## Pack-opening files

The rule not to touch them was lifted when the rework merged; the three files above are the only changes. `test_seed_*` and R151 `run_rare_pull.sh` stay green. `run_seed_opening.sh`'s "no model names" grep no longer trips on the upload folder in the place file's path.
