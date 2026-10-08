# R153: nobody can stand on a track wall

Owner: "there are also some issues with being able to stand on track walls if flung up high enough fix that so u cant stand on track walls".

## What was wrong

The track's side walls (`Obby.BiomeWalls`) are 5 thick and 48 tall, in every biome: inner face at |x| 89, outer face at |x| 94, bottom Y 3, **top Y 51**. The saved invisible barriers that crown them (`InvisibleMapBarriersV071`, raised to 1,024 tall by `MapService`) sit at |x| 90 - 95. So **the inner 1 stud of every side wall top is open sky**: 14 strips, 12,160 square studs along the whole track. A body that is above Y 51 and pushed against the barrier's face (the game's runner sweep, a Blockcast hull 1.8 wide, stops it with its centre at |x| 89.1) comes down onto that strip, and the Humanoid's floor ray finds the wall top: the player stands and runs on the wall. The hub walls, the end wall and the hub wall caps have no such strip (their barriers have the same footprint).

| biome (stage) | side walls: z range after the code (as saved) | inner / outer \|x\| | bottom - top |
|---|---|---|---|
| Forest (1) | -100 .. 80 (-100 .. 125) | 89 / 94 | 3 - 51 |
| Jungle (6) | 80 .. 530 (125 .. 395) | 89 / 94 | 3 - 51 |
| Desert (2) | 530 .. 1180 (395 .. 687.5) | 89 / 94 | 3 - 51 |
| Snow (3) | 1180 .. 2030 (687.5 .. 1002.5) | 89 / 94 | 3 - 51 |
| Lava (4) | 2030 .. 3080 (1002.5 .. 1362.5) | 89 / 94 | 3 - 51 |
| Crystal (5) | 3080 .. 4380 (1362.5 .. 1767.5) | 89 / 94 | 3 - 51 |
| Storm (7) | 4380 .. 5980 (1767.5 .. 2217.5) | 89 / 94 | 3 - 51 |
| end wall | z 5980 .. 5985 (2217.5 .. 2222.5), x ±94 | - | 3 - 51 |

(Both sides are the same. The floor's top is Y 4. The hub's five walls: top Y 51, caps Y 51.5 - 52.5, all under barriers of their own footprint. The hub gate's two round tower shafts, Y 34 / 58, stand at |x| 92 - 106 beyond the barriers.)

## How high a fling goes

`KnockbackConfig` (sideways / up, studs per second; gravity 196.2): Forest 93 / 110, Desert 103 / 134, Snow 108 / 146, Lava 123 / 158, Crystal 106 / 170, Jungle 98 / 122, Storm 118 / 182, **The Darkened 130 / 200**, lightning 135 / 65, bat 88 / 42. The highest peaks, over the launch point: Darkened 101.9, Storm 84.4, Crystal 73.6. A standing body's root is at Y 7, so the highest root reaches **Y 108.9: 57.9 studs over the wall tops**. Every keeper from the second on (Desert, 134 up) clears the wall top. `Ragdoll.KeepOnTrack` clamps the sideways part of a keeper fling so that it lands at |x| 81 at most; the simulation shows that an unsteered, clamped fling never reaches the wall, but a launch the clamp does not apply to flies over it, and a body that gets control back in the air (the runner sets the horizontal speed every frame) can steer onto the strip at any speed.

## The fix

1. **Blockers** (`ChestChaseServer/TrackWalls153`, built at the end of `MapService.new`, after every pass that moves a wall; failure only warns). One invisible slab per wall part (15): its inner face flush with the wall's (0.02 on the track side, so no seam leaves a ledge), 3 studs past the outer face (8.02 thick, so nothing tunnels), from 6 studs inside the wall (hidden) up to **1,000 over its top (Y 1,051: 9.6 times the highest fling)**. Joints overlap by 0.5; a wall over 2,000 studs would be cut into overlapping parts (Roblox's limit is 2,048). They are measured from the walls themselves, so a taller or moved wall is followed. Nothing is on the track side of a wall's face and nothing lies below Y 45, so the track width, keepers, packs, holes, the keyboard (keys under Y 10) and the refresh barrier / gate (opening under Y 41.5) are untouched. A body that comes down on them slides down the flush face onto the track floor; there is no pocket, no ceiling, and no top within reach.
   - Transparency 1, CastShadow off, CanTouch off, anchored: never drawn, no Touched events, nothing in the z-fight sweep. They are one Persistent model (always on every client under StreamingEnabled).
   - **CanQuery stays on**, like the game's other invisible colliders (`FloorSafety86`, `RefreshBarrier`, the garden ramps). The runner's hull sweep (`RunnerSweep`, a Blockcast) and the movement guard only see queryable parts: with CanQuery off the sweep would still push a body into the slab, and the physics would push it back out every frame. The Roblox camera does not zoom in on a fully transparent part and the pack-scenery scan skips Transparency 0.98 and up, so the camera and pack placement treat them like the saved barriers.
2. **Fallback** (`TrackWalls153.Start`, started by the main script; 4 looks a second, nothing per frame): a body that RESTS (vertical speed 2.5 or less) inside a blocker's volume or on a wall top, on two looks in a row, is moved 6 studs in from the wall's face, at the same height, so it falls to the floor; sideways speed and spin stop and `MovementGuard.Reset` is told. A flung body passes through at speed and is never touched; owner test flight / noclip, dead and anchored bodies are left alone. This also takes a player who is somehow up there (a half-updated server) back down.

A smooth sloped cap was rejected: a Humanoid stands on slopes up to `MaxSlopeAngle` (89 by default), so only a vertical face keeps it off. A server check alone was rejected as the main fix: it is late (half a second) and does nothing about the runner sweep or limbs resting on the strip. The tall slab removes the surface; the check catches what nobody foresaw.

## Hub and props

- The hub walls (and their caps and merlons) are covered by barriers of their own footprint: no open strip. Hub players are lifted by the trampolines to Y 34.9 (rules cap: 44.9), under the wall tops (51) and the tower caps (58). A fling on the track cannot reach the hub: the barriers (|x| 90 - 95, to Y 1,028) and the front wall block the way, and the lateral clamp keeps flings inside |x| 81.
- Track-side props: after the start-up builders the only solid parts on the track are the floor, the walls, the barriers and the two gate towers; all scenery (wall banks, rock shoulders, vines, trees, ice spikes, landmarks) is non-colliding, so there is no stairway onto a wall and no prop to stand on.
- The R152 keyboard adds only non-colliding parts (CanCollide, CanQuery, CanTouch off), all under Y 10; the blockers start at Y 45 and are invisible, so the far letters are not blocked or hidden.

## Tests

`docs/proposals/R153/tests/run_track_walls.sh [scratch dir] [place.rbxl] [nomutate]` (registered in `tools/tests/run_all_suites.sh`): static checks (fling, movement and sweep code, BackgroundMusic and `Config.Version` byte-identical to the R152 release; frozen hashes hold), `test_track_walls.luau` (the real start-up on the owner's place in the mock: the blockers as built, the plan on synthetic walls, a rebuild, and the fallback on mock players), `check_track_walls.py` (the walls measured as saved and after the code; every wall top covered exactly, with and without the blockers: 14 of 20 open without, none with; the blockers against the walls; 1,848 simulated flings per world: without the blockers 896 come to rest on a wall top, with them 0 and all end on the floor), and 17 mutations that each must fail it. No frozen file changed, so `frozen.sha256` is untouched.
