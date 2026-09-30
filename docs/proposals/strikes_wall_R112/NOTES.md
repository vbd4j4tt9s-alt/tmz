# R112: bat / keeper strikes, refresh night wall, rare-pack notices

Nothing here was run in Studio. Everything was run offline with the Luau CLI, using the real module sources and an exact CFrame library. All renders are approximations.

## A. Swings (wind back, then slap forward)
**Bug found:** the old `BatSwingPose` keys moved the arm, but the bat hangs off the hand's front axis. So during the "wind-up" hold the bat pointed forward and down, about 5 studs in front of the player. At contact and in the follow-through it pointed backward over the shoulder. The swing read in reverse on both R15 and R6 (see `bat_swing_side.png` and `motion_curves.png`).

**New bat swing** (`BatSwingPose`, `BatClient`). Server timing is unchanged: the hit resolves at request time + `Windup` 0.30 s.

| phase | time (s) | pose |
|---|---|---|
| wind back | 0 to 0.135 | torso coils right, hand behind the head, bat tip about 6.7 studs behind |
| hold | 0.135 to 0.165 | cocked |
| whip | 0.165 to 0.30 | over the top, ease-in, fastest at contact |
| **contact** | **0.30** | bat tip about 7 studs in front, same instant as the server hit |
| follow-through | 0.30 to 0.43 | continues forward and down, to the left |
| settle | 0.43 to 0.74 | blends back to the tool hold |

R6 uses the composed R15 hand orientation, so the bat points the same way on both rigs. `Lead` makes a late-arriving swing play its whole wind-back instead of popping in part-way.

**Keepers** (`KeeperAttackPose`, `KeeperStrikeFrames`, `BeastAnimation`). The limb pulls about 1.5x further back and is cocked at 0.6 W and held to 0.7 W. The strike eases in, the hit pose holds for `HitHold`, then comes a follow-through (peak at about W + 0.15 s) and a settle by W + `Recovery`, which is where the R110 window ends.

| stage | W (s) | cocked | impact | follow peak | settled |
|---|---|---|---|---|---|
| 1 Golem | .30 | .18 | .30 | .45 | .60 |
| 2 Snake | .22 | .13 | .22 | .37 | .52 |
| 3 Ice Fang | .24 | .14 | .24 | .39 | .54 |
| 4 Dragon | .32 | .19 | .32 | .47 | .62 |
| 5 Knight | .32 | .19 | .32 | .47 | .62 |
| 6 Jungle King | .28 | .17 | .28 | .43 | .58 |
| 7 Colossus | .34 | .20 | .34 | .49 | .64 |

The server's contact test (`KeeperContact`, via `KeeperStrikeFrames`) sees frames that are **identical to before** from W to W + `HitHold` on all 7 stages (max difference 0). Hit timing, reach, damage and `KeeperCombat` are untouched. `VeiledKeeper81` still uses `KeeperCombat.Pose` and is unchanged. The wind-back pose differs, and during the windup it only affects when the server stops moving a keeper toward the player. No timing mismatch was found.

## B. Refresh night wall (`RefreshBarrier`)
- Flat unlit white face (240) on both faces. A crescent moon plus cloud icon in dark grey (70,72,79) with thick black outlines, drawn from rounded Frames. The crescent is clipped at the circles' radical line so no stray ring shows.
- Huge "Ns" countdown in FredokaOne: `TextSize` 100 with `UIScale` 2.6 (about 52 studs), black `UIStroke`.
- The sign is centred at 40% of the wall height (`B.SignHeight`, tunable).
- The part, its size, position, collision flags and attribute are unchanged. The old trims, posts and seams are gone.
- MapService's label writes are routed through `B.Format` so server and client both show "Ns" (no flicker). MapService is unchanged.

## C. Rare-pack notices (`RarePackRules`)
`Message` returns nil unless the tier is Legendary or Mythic (`R.NoticeTiers`). Every such spawn is announced; the old below-1% odds gate no longer applies to them. Checked over every tier x size x mutation. The size line is marked `-- R112: size text -> ItemWeight`.

## Tests (scratch: strikes/)
- `keeper_check.luau`: impact identical on all 7 stages, no pop at the window end, late start begins from idle.
- `bat_client_test.luau`: real BatClient on R15 and R6.
- `beast_test.luau`: real BeastAnimation on stages 1, 5 and 7.
- `wall_test.luau`: 135 checks, including the real TrackRefreshSky countdown from 10s to 0s.
- `notice_check.luau`.
- `luau-compile` and `luau-lsp`: no new findings.

## Check in Studio
- Swing look on your own avatar, including R15 animation-constraint rigs and scaled or Rthro bodies.
- SurfaceGui text sharpness with `UIScale`, the clip edge on the crescent, and the sign height from the refresh spawn spots.
- Mesh keepers (stages 2, 3, 4, 6): the renders show them only as boxes.
