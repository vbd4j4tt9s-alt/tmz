# R153 garden nooks: the trampolines and their look

Owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit", then "trampoline can just use this asset 12088629887".

## Gameplay (unchanged by the look)

Three trampolines, one filling each nook's brick circle: the garden nooks (x = +-312, z = -269, disc radius 13) and the back lane's (0, -596, disc radius 10; its bench and bed are gone too).
Owner: "it should fit the whole circle": each frame's outer edge stands 0.4 stud inside its disc's rim (collider radius 12.6 / 12.6 / 9.6), so the brick shows as a thin ring.
One invisible collider (its top 0.9 over the floor) and a ring of invisible 22 degree wedges (`Trampoline ramp`, 2.25 studs of run: a body WALKS up the kerb from any side; the
Humanoid does not step a 0.9 ledge, as the garden beds' 0.8 showed) are the only parts that collide. The whole circle bounces (`T.OnMat` takes the spot's own radius, set on the
model as the `Radius` attribute; MovementGuard's `LaunchRise` reads the same attribute per spot). The client sets the vertical speed of the local character's root to the launch speed of
`HubTrampolineRules153.BounceHeight` (30 studs; 108.5 studs/s at the default gravity); debounce 0.45 s; a rising body is left alone; the speed is set, never added.

## The look

`HubTrampoline153.Build` (called by `HubDecor151.Apply`) always makes the built trampoline first (red 16-sided frame, gold springs, teal mat, cream badge, six feet). Then,
off the start-up thread, it replaces the visuals with the owner's model, in this order:

1. **A model you drop in by hand**: any Model / part / Folder inside `ReplicatedStorage.HubTrampolineTemplates153`. Preferred: when one is usable the asset is not even asked.
2. **The asset**: `InsertService:LoadAsset(12088629887)`, then `AssetService:LoadAssetAsync(12088629887)`, each with a 15 s timeout.
3. **The built trampoline** stays when both fail. Nothing breaks; `/test trampoline` says why.

### What happens to a model from outside

A store model can carry code, so it is never used as it is. It is cloned (the original in the folder is never put in the world) and then:

- every Script / LocalScript / ModuleScript is destroyed and counted, and so is everything that is not geometry (`HubStudTrees151.Sanitize`, the tree templates' own sanitiser): sounds,
  click detectors, proximity prompts, welds and constraints, humanoids, attachments, lights, particles, guis, remotes, values ...;
- parts with an absurd size (a side over 600 studs, or not a number) and invisible parts (transparency 0.95 or more: hit boxes) are dropped;
- more than 400 parts per trampoline (`T.AssetMaxParts`) and it is not used (the count is reported);
- every part is locked: anchored, CanCollide / CanTouch / CanQuery off, Default collision group, CastShadow only for parts of 2 studs or more.

### Fitting it in

- `Model:ScaleTo(GetScale() * k)` so its FARTHEST point lies on the collider's circle (R154 review: a round part - upright Cylinder, Ball, round MeshPart / union - is measured by its circle, not by its box
  corners, which put a round look at 71% of the circle; a model saved at scale 2 is scaled from there): for a round look that is its whole width, so it fills the circle; a look that is not
  round (a square one) is fitted INSIDE the circle by its corners, and `/test trampoline` says so ("not round ... fitted inside the circle by its corners");
- centred on the nook; its mat (the largest roughly flat part in the top half, preferring a name like Mat / Bouncy / Jump; frames, legs, springs, poles and nets are never the mat)
  with its top at the collider's walking top, 4.9. A model with no mat that can be told (one part, or two like candidates) has its top surface there instead;
- a flat part whose top would lie on a plane of the paving (4.14 / 4.20 / 4.26 / 4.32) lifts the look by a tenth (at most three) so nothing z-fights with the plaza;
- the built feet, frame, springs, gap, mat and badge are removed: one look only; the collider stays;
- all three nooks are dressed together or not at all (a model that cannot be scaled leaves the built trampolines untouched).

The mat squashes (a 0.2-stud dip and rebound) when it is found; the badge is optional. No mat found = no squash, the bounce is the same.

## "User is not authorized to access Asset"

The R152 log showed this for the tree assets: `InsertService` loads only models the game's owner owns. Cure: open the asset's Creator Store page with the **game owner's account**, press
**Get Model**, insert it in Studio from Toolbox -> Inventory -> Models, and drop it into `ReplicatedStorage.HubTrampolineTemplates153` (make the Folder if it is not there). Publish and
restart the server, or run `/test trampoline reload`. "Allow Loading Third Party Assets" (Game Settings -> Security) also lets `AssetService:LoadAssetAsync` load it.

## `/test trampoline [status | reload]` (owner)

Prints which look is in use (the asset, the hand-placed template, or the built fallback), the parts per trampoline, how many scripts and other non-geometry instances were removed,
how many invisible or absurd parts were dropped, the mat found for the squash, the state of `HubTrampolineTemplates153`, the real error of every route that was not used, and the cure above.

## Tests

`docs/proposals/R153/tests/run_nooks.sh`, section 6 of `test_hub_gardens.luau` (mocked `InsertService` / `AssetService`): a store model with scripts and junk inside (stripped), scale /
centring / mat height / one collider, the squash on its mat, the same bounce and debounce, "not authorized" -> template -> built, a template with only a script, a timeout, too many parts, a
single part, no findable mat, a model that cannot be scaled, the paving-plane nudge, the owner command. The real asset cannot be fetched here (no Roblox access): its type, size and part
count are reported by `/test trampoline` once it loads, and the cap (400 parts per trampoline) keeps a heavy model out.

## Second round (R153, after the owner installed it)

- **The `HubTrampolineRules153:44: Expected identifier ... got '//'` error was not in our code**: the owner's copy had the asset link pasted into line 44. The loader never writes into
  ReplicatedStorage (it only reads `HubTrampolineTemplates153` and clones what it finds; nothing it loads is parented there), and the owner's place now holds the files byte for byte.
- **Why the beds' sides were still blocked**: the first ramps skipped the pad's 1.0-stud aprons beside the fence and were measured against the runner sweep's
  1.1-stud clearance, but the Humanoid does not walk up a 0.8 step. Every raised block (each soil bed and the pad) now has a continuous 22 degree skirt: a wedge along each face and a fan
  of wedges at each convex corner (`GardenBaseLayout.RampSpecs`); tested by walking every side, corner, rim and fence pillar of all 6 bases and a flood fill from the lawn.
  R154 review: the 46 x 3 stud strip of soil drawn in front of DirtPlot_5 (up to DirtPlot_9's front edge) had no floor (feet 0.4 - 0.8 below the soil you see); its skirt now stands at its real
  edge and an invisible flat block `Soil edge top` (soil plane 5.8) in `GardenBedRamps153` is its floor.
- The measurements use the owner's current place (`5ea4542b-sapkeee.rbxl`); against the older snapshot (`b4f113d1-sapkeyver.rbxl`) the pads, plots and nooks are identical (it
  differs only by the installed R151 - R153 scripts and the ServerStorage backups).
- The lane nook trampoline stands 5.4 studs from the pads of Bases 5 and 6; its ring and the neighbouring beds' skirts join in a valley 0.28 over the floor (tested).
