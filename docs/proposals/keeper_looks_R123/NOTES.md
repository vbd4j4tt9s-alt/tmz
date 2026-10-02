# R123 keeper looks: Dragon, Snow Tiger, Snake and Gorilla (preview only)

**Status:** waiting for the owner's approval. Nothing under `src/` has changed.

## What to look at
Start with `renders/overview_before_after.png`. The top row is the current look and the bottom row is the proposed look, shown with the same camera and lighting.

There is also one sheet per keeper: `renders/keeper_<n>_<name>_before_after.png`. Each sheet shows four views:
- front 3/4
- side
- chase stride, using the real `BeastPose` frames
- strike impact, using the real `KeeperStrikeFrames`

### How the renders were made
- **AFTER:** this is the actual output of `BeastModelsRefined.lua`. It was run offline in Luau with exact CFrame math and posed by the live pose modules.
- **BEFORE:** this is a reconstruction. The keepers are imported MeshParts, and their mesh files cannot be downloaded in this environment. Each textured mesh is drawn as the convex hull of the rig's `FloorSamples` points, in an assumed texture colour. Small untextured mesh details are drawn as rounded boxes at their exact size and position.
- Materials are approximate. Particles, KeeperFx and client accents are not drawn.
- Compare the BEFORE row against an in-Studio screenshot before deciding.

## Per keeper
| Keeper | Before (mesh parts) | After (native parts) | What changed |
|---|---|---|---|
| 2 Sand Snake | 17 | 74 | **Body:** smooth tapering body with a sand gradient (cream belly, tan back) and a brown diamond pattern with a cream outline on every segment. **Head:** a flared cobra hood with spectacle markings on the back, desert-viper brow horns, glowing amber eyes, two fangs and a forked red tongue. The client rattle accent still sits at the tail tip. |
| 3 Ice Fang (snow tiger) | 21 | 83 | **Fur and stripes:** white fur with six dark tiger-stripe bands, a striped tail ending in a frost crystal, cheek ruffs, belly and elbow tufts. **Ice:** a frost mane of ice-crystal spikes around the neck and shoulders, and ice-blue claws. **Face:** long sabre fangs, ears with blue inner ears, and glowing ice-blue eyes under heavy brows. |
| 4 Lava Dragon | 27 | 127 | **Head:** swept bone horns, cheek spikes, brows, glowing red eyes, glowing nostrils, teeth, and a lava glow inside the mouth. **Body:** gold belly and throat plates, a row of dark spine plates with a glowing magma seam, and magma cracks on the flanks, legs and tail. **Wings:** bat wings with an arm, three finger ribs, a thumb claw and five membrane panels. The inner panels are darker. **Tail:** side spikes and a spade tip. |
| 6 Jungle King (gorilla) | 23 | 69 | **Head:** heavy brow ridge, crest on the skull, leathery face and muzzle, glowing amber eyes, fangs, and a leaf crown with a glowing orchid. **Body:** silverback saddle, chest muscles, and a vine sash with leaves across the chest. **Arms and legs:** big shoulders, long thick forearms, knuckle-walking fists with knuckles, vine bracers with leaves, moss on the shoulders, and short thick legs. |

The native keepers already in the game use 30 to 63 parts each. The dragon is the heaviest at 127 parts. If that is too many, a lighter version can drop the side spikes, cracks and teeth to get to about 100.

## What stays the same (so animation and hits keep working)
- **Group names:** the same as today, for example `Head`, `Jaw`, `LeftWing` and `Segment1`..`Segment9`.
- **Rig config:** `KeeperRigConfig` (pivots, bounds, floor samples and eye colour) is unchanged. Each part is built inside its group's existing bounds. The check is in `tests/bounds_report.txt`.
  - The worst overshoot is 0.25 to 0.36 studs on the dragon, tiger and gorilla.
  - The snake's joint fillers deliberately overlap into the next segment's space by up to 1.2 studs. That space is already covered by the next segment, so the outline does not change.
- **Hit reach:** `BeastPose`, `KeeperStrikeFrames` and `KeeperContact` are untouched, so the rule for what counts as a hit is the same.
- **Part attributes:** every part gets the same attributes the game reads today (`RestCFrame`, `BeastGroup` and `KeeperEyeGlow`), set the same way as in `KeeperUpgradeArt.Build`.
- **No external assets:** no meshes or decals are used. Rounded shapes are a Part with a `SpecialMesh` set to Sphere.

## What would change on approval
1. Add `BeastModelsRefined` as a ModuleScript under `ServerScriptService/ChestChaseServer`, with a MANIFEST row.
2. In `BeastModels.lua`:
   - `Build` uses `Refined.Build(stage)` for stages 2, 3, 4 and 6.
   - `version()` returns 123 for those stages, so keepers already saved in the place are re-dressed.
3. In `BeastAnimation.client.lua`: `expectedVersion` returns 123 for those stages. This is one line.
4. In `KeeperAccents.lua`: remove the Ice Fang spine-shard accent `[3]`, because the frost crystals are now part of the model. Keep the Snake rattle `[2]`.
5. Optional: drop the four keeper stages from `KeeperTemplatesV100` in the place file.

## Risks
- **Contact geometry:** hit tests on a part with a SpecialMesh use its full box, not the visible ellipsoid. The old MeshParts used their own collision hulls. Reach can therefore differ by a fraction of a stud at rounded edges. Check this with the R112 `keeper_check` and the R113 `side_check` after installing.
- **Cost:** there are more parts to move each frame. The client moves every part with `BulkMoveTo`. With all four keepers on screen, that is about 350 parts instead of about 90. That is cheap, but measure it on low-end devices.
- **Looks:** the BEFORE row is a reconstruction, so the size of the visual change is approximate. Materials such as Slate, Glass, Grass and Neon will look somewhat different in Studio lighting.
- **Eye colour:** eye colour still comes from the config, so the dragon's eyes stay red-orange. Changing the colour means editing the config.

## Files
- `BeastModelsRefined.lua`: the proposed builder module.
- `tests/dump_refined.luau`: dumps the before and after geometry and checks the bounds.
- `tests/render.mjs` and `tests/render.html`: the headless Chromium and three.js renderer.
- `tests/run.sh`: rebuilds the renders.
- `tests/bounds_report.txt`: the bounds check output.
- `renders/`: the output images.
