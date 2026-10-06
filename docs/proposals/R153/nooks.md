# R153 garden nooks: the trampolines and their look

Owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit", then "trampoline can just use this asset 12088629887".

## Gameplay (unchanged by the look)

Two trampolines, one in the middle of each garden nook (x = +-312, z = -269). One invisible collider (6.05 studs round, its top 0.9 over the floor, under the
runner's 1.1-stud step) is the only part that collides. The client sets the vertical speed of the local character's root to the launch speed of
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

- `Model:ScaleTo` so the bigger of its footprint's two sides is the collider's diameter, 12.1 studs;
- centred on the nook; its mat (the largest roughly flat part in the top half, preferring a name like Mat / Bouncy / Jump; frames, legs, springs, poles and nets are never the mat)
  with its top at the collider's walking top, 4.9. A model with no mat that can be told (one part, or two like candidates) has its top surface there instead;
- a flat part whose top would lie on a plane of the paving (4.14 / 4.20 / 4.26 / 4.32) lifts the look by a tenth (at most three) so nothing z-fights with the plaza;
- the built feet, frame, springs, gap, mat and badge are removed: one look only; the collider stays;
- both nooks are dressed together or not at all (a model that cannot be scaled leaves the built trampolines untouched).

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
