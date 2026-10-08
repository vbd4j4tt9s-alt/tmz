# R153: the SPEED NEEDED sign over the keepers

Owner, after R152: "make it so that speed needed thing is dislocated from the keeper and is way above the keepers head" (screenshot: the sign sits
on the Timber Golem's canopy, touching it). Then: "for the secret keeper just put the inf speed like above him really high up but stays at his
spawn point so when he chases the player it doesnt follow the keeper, for other keepers adopt this same thing".

Changed: `KeeperSpeedLabels.client.lua` (line 1 is still the R152 load guard), one stamp line each in `ChaseService.lua` and `VeiledEvent81.lua`.
Not changed: `Config.Version`, `BackgroundMusic.client.lua`, the number rules (R148), the sign's size (104x36 px).

## Cause (from the code; I did not run it in Studio)

R152's `place()` measured the keeper's bounding box **once**, when the client first saw the `BiomeKeeper` tag, and hung the sign
`clamp(top, 2, 80) + 2.5` studs above the root. Nothing guarantees the model is final at that moment:

* `KeeperMeshes152.Start()` bakes the 8 models in the background (4 ms slices) while `BeastModels.Dress` has already built every keeper from
  today's smaller model and `ChaseService` has tagged it. `BeastModels.Keep()` (every 2 s) swaps an idle keeper to the baked one later:
  `body:Destroy(); rig.Parent = model`. A client that measured before the swap hangs the sign on the old, shorter body.
* A model that streams in late (or is re-dressed) is measured with whatever parts have arrived; `GetBoundingBox` also follows the pose
  (`BeastAnimation` moves and resizes the parts every frame: sleep, chase, the golem's tree form), and includes the root / hitbox and the parts
  the effects add (`KeeperSurge`'s "Electrical surge" arcs on the colossus).
* 2.5 studs is smaller than the sign: the pill is a fixed 36 px, which is about 4.5 studs tall at 40 studs from the camera, so even a perfect
  measurement left its lower edge on the head.

## Now

* **Pinned to the spawn point.** The server stamps `KeeperHome` (Vector3): `ChaseService._preparePersistentGuardian` from the camp it keeps for
  the stage (`GuardianHomeCFrames`), `VeiledEvent81.EnsureGuardian` from the appearance's `Home`. The client puts one invisible, anchored,
  non-colliding / non-touch / non-query part there (`workspace.KeeperSignAnchors`, one per keeper, an ObjectValue `Keeper` says whose) and
  the sign hangs on it: it never follows the keeper. If a server has not stamped `KeeperHome` yet, the sign waits at the spot where the keeper
  was first seen and moves once when the stamp arrives.
* **18 studs over the body at rest** (`LIFT`; the owner's "really high up", 15 to 20 asked for), `MaxDistance` 250 (was 160: the sign is higher
  and is wanted from the run-up; a fixed pixel size does not grow with the range).
* **Body top at rest, not the current pose.** Rig parts carry their rest frames (`RestCFrame`, the golem's `TreeRestCFrame` / `TreeRestSize`,
  `IdleRestCFrame`), so the animation does not matter. Only rig parts count once there are any; the root / hitbox, `ColossusSurges`,
  `KeeperFx*` / `KeeperHit*` parts, `KeeperFxKind` parts and invisible parts never do (for a model without rig attributes they are filtered
  by name). KeeperFx152's flames, wisps, leaves, rain, bolts and trails are emitters, beams and attachments, not parts. The Storm Colossus's
  cloud crown (`Head_Cloud`) is a real mesh sitting on its head, so the sign clears it. The Darkened's pieces follow group frames
  (asleep it lies 4 studs high, awake 13.06), so its top is never below `DARKENED_TOP = 13.5`.
* **Measured again only when the body changes:** `DescendantAdded` / `DescendantRemoving` of a BasePart, debounced 0.5 s (at most twice a second),
  and not at all after 5 s without a change; a `KeeperMeshVariant` change (the swap) listens again. Written only when the height moved by more
  than 0.25 stud. No per-frame connection, no polling.

| keeper | body top over its root | sign centre over its root |
|---|---|---|
| Timber Golem / Jungle King / Sand Snake | 25.1 / 13.3 / 3.9 | 43.1 / 31.3 / 21.9 |
| Ice Fang / Lava Dragon / Crystal Knight | 9.2 / 14.5 / 31.0 | 27.2 / 32.5 / 49.0 |
| Storm Colossus / The Darkened (standing) | 38.8 / 13.1 | 56.8 / 31.5 |

## Checked

`tests/run_keeper_label.sh` (registered in `tools/tests/run_all_suites.sh`), on the Roblox mock with the real script and the real rev 6 data: every
biome keeper first small, then swapped to the baked model (and the colossus's cloud streaming in late) ends >= 15 studs over the real mesh top;
effects and an oversized root change nothing; a keeper chased 900 studs away leaves the sign where it was; The Darkened's sign is at its spawn (also
when it spawns asleep), unmoved while it wakes and chases, gone when it despawns, and new at the next spawn point; debounce, stop-listening,
write-on-change, no frame signal, no leaked anchor; line 1 of the script. `check_label_clear.py`: nothing saved in the owner's place (hub, track
props, biome walls) is within 12 studs of any of the 7 signs (nearest 19 studs, a side wall) and the track gate is 67 studs from the Forest one.
The Darkened's spawn is computed at run time (not in the saved place), so it is not in that scan.

Older tests updated to the new behaviour: `R147/tests/test_r147_client.luau` (where the sign hangs, its height, MaxDistance 250, signs wait for a
body) and `R147/tests/test_mystery.luau` (+ the `KeeperHome` stamps); `R152/tests/run_keepers.sh` (KeeperSpeedLabels is on its list of changed
keeper files) and `tools/tests/r152_real_diff.sh` / `R149/tests/run_tiger_gear.sh` (ignore the one marked `KeeperHome` line in ChaseService, which
stays byte-identical otherwise).

The R153 jitter sweep (merged) had hung the sign on `KeeperFollow153`'s smoothed-body anchor so it glided with the keeper. The owner's spec
replaces that for the signs: a pinned sign never moves, so there is nothing to smooth and the label script does not use `KeeperFollow153`
(the client bug review's finding 5 then removed the module and the per-frame anchors `BeastAnimation` and `VeiledEventClient81` still moved for it:
nothing read them; the keeper bodies' own smoothing, `KeeperMotion`, is untouched). `run_jitter.sh`'s expectations about the signs changed to match
(`test_jitter_keepers`: the sign does not move at all while the keeper runs in packet steps, at 30 / 60 / 144 fps; `test_jitter_misc`: the static check).

## Not covered

Only the mock was run, not Studio. A sign is occluded by solid geometry like any BillboardGui (not AlwaysOnTop); nothing is over any keeper's
spawn in the saved map. A keeper that streams out takes its sign with it, as before. `LIFT` and `DARKENED_TOP` are the two numbers to change if the
owner wants it higher or lower; the test fails if The Darkened ever stands taller than `DARKENED_TOP` allows.
