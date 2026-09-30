# R113: keeper animation, model and effects polish

Nothing here was run in Studio. The real modules were run offline with the Luau CLI, using the tools/tests mock and exact CFrame math. The renders are approximations: mesh keepers are drawn as boxes, and materials and particles are not drawn.

## Hit rule (unchanged)
The server's contact test is `KeeperContact` -> `KeeperStrikeFrames` -> `BeastPose` / `KeeperAttackPose`. None of those files changed. `ChaseService`, `ConcurrentKeeperService`, `KeeperCombat` and `KeeperMotion` are also untouched. All new motion is in the client-only `KeeperPolish`. It adds nothing between W and W+HitHold (3,479 checks, exact equality). The strike fade-in is at most 0.08 s and always ends before impact. The R112 `keeper_check` still reports IDENTICAL on all 7 stages. Accent parts are created only on the client, so the server never sees them. The finish pass changes only material, colour and reflectance, plus transparency 0.12 on the Knight's crystals. The server contact part set is identical for stages 1, 5 and 7.

## Animation (KeeperPolish, per keeper, client)
| layer | what |
|---|---|
| look-at | Head (and jaw) turn toward `TargetUserId`'s root within 90 studs, using a damped spring. Yaw is limited per stage (Golem 0.30 to Snake 0.70 rad). It fades out when the target is behind the keeper. |
| wake roar | Sleeping -> ALERTED: a 0.22 s crouch and head dip, then the keeper rears up (quadrupeds pivot on their hind feet), the head lifts, the jaw gapes with a tremble and arms flare (bipeds and gorilla). It settles by 1.35 s. |
| weight | Leans forward on acceleration and back on braking, with a slight overshoot (spring damping 0.42). |
| follow-through | The tail (Ice Fang, Dragon) lags on turns and lifts on braking. The Snake's turn lag rolls down its 8 body joints. |
| sleep | The torso breathes (not the Golem, which is a tree). A sleeper stirs and lifts its head when you come within 24 studs. |
| taunt | 1.6 s after a landed catch, while the keeper is not moving. Roar for most; chest-beat for Jungle King; swaying hiss and rise for Snake. |
| blends | Crossfade into the strike window (at most 0.08 s, before impact) and out of it (0.16 s). This removes the gait-to-strike pop. The largest per-frame joint jump at strike entry fell from 4.5 to 2.1 studs on Snake, 5.6 to 3.5 on Dragon, and 10.3 to 6.3 on Colossus. |

The gait cadence is still set by `KeeperMotion` stride lengths. At chase speeds of 100 to 400 studs/s, cadence hits its 3.6 cycles/s cap, so feet cannot match the ground there; that is unchanged.

## Models
- **Golem:** bark and limbs are Wood, moss is Grass, and the leaf crown is LeafyGrass. Client accents: a glowing heartwood rune and 2 shelf mushrooms, hidden while it is a tree.
- **Knight:** crystals are Glass (transparency 0.12), the chest inset is Neon, and the blade and armour have reflectance. Accent: 3 neon shards orbit the helm.
- **Colossus:** prongs are Metal, and the fists and feet are Basalt. Accent: a 3-puff storm-cloud crown.
- **Snake:** Sandstone tail rattle (3 parts) that buzzes while it hunts.
- **Ice Fang:** 3 ice shards along the spine.
- **Dragon and Jungle King:** no geometry added, because their meshes cannot be seen offline. They get effects only.
- Keepers already saved in the place are refinished in place by `BeastModels.Dress` (`KeeperUpgradeArt.Refinish`, idempotent, geometry untouched).
- Uploaded meshes are unchanged.

## Effects (KeeperFx, KeeperSleep, KeeperHitEffects)
Textures are only `rbxasset://textures/particles/smoke_main.dds` and `sparkles_main.dds`.
- **Footfall dust:** biome colour, 2 or 4 contacts per gait cycle, at the lowest foot. The Snake leaves a slither trail. Heavy keepers (Golem, Dragon, Knight, Jungle King, Colossus) add a tiny camera shake within 60 studs.
- **Breath puffs:** frost (Ice Fang), smoke (Dragon), hot mist (Jungle King), sand hiss (Snake).
- **Body motes:** spores (Golem), snow (Ice Fang), embers (Dragon), glints (Knight), fireflies (Jungle King), sparks (Colossus).
- **Wake:** ground ring, dust burst, breath burst and a short shake.
- **Strike:** slam dust at the visual impact, plus a ring and shake for heavy keepers.
- **Eyes:** the eye PointLight is on while hunting.
- **Hit:** biome ring and dust at the caught player.
- **Sleep:** 3 small drifting "z" letters (text only; the old sleep clouds stay removed). There are none on the Golem. Turn them off with `KeeperSleep.ShowZzz=false`.

**Budgets:**
- Dust and wake effects within 120 studs; breath and motes within 90; Zzz within 55; eye lights within 120.
- A shared particle token bucket caps output at 90/s, or 35/s in low graphics.
- At most 3 eye lights at once.
- At most 6 rings, pooled.
- Low graphics (FastMode or tier 1): no breath, motes, lights or Zzz; dust at half.
- ReducedMotion turns off every added shake.
- Measured over a full run: up to 58 particles/s per chasing keeper (Ice Fang), 8 to 24/s in low graphics. The wake burst is 14 to 25 particles.

Per-frame cost: one spring pass (about 30 CFrame operations) only on pose frames, a few scalar checks per keeper every frame, and 3 extra `BulkMoveTo` entries for keepers with accents. Mock timing for 7 chasing keepers is within about 15% of R112, and mock CFrame math dominates that figure.

## New instances
| name | class | parent |
|---|---|---|
| `KeeperPolish`, `KeeperFx`, `KeeperAccents` | ModuleScript | ReplicatedStorage (MANIFEST rows added) |

At runtime, on the client only:
- `KeeperFxFoot`, `KeeperFxMouth`, `KeeperFxBody`, `KeeperFxEyes` (Attachments under the keeper root)
- `KeeperAccentsLocal` (Folder in the keeper model)
- `KeeperZzzLocal` (BillboardGui)
- `Workspace.KeeperFxLocal` (rings and burst)
- render steps `KeeperFxShakeReset` / `KeeperFxShake` (Camera -3 / +3; they nest with KeeperHitEffects' -2 / +2)

## Tests (`tests/`; bundles are built by `mk.sh`)
- `states_test.luau`: the real BeastAnimation on all 7 stages through sleep, stir, wake, chase with turns, strike and catch, taunt, return, sleep, low graphics and removal. 70 checks: no NaN, every part posed, Zzz rules, at most one light per keeper, dust and wake emitted, and everything cleaned up.
- `polish_check.luau` (hit window), `side_check.luau` (contact set, refinish, hit ring and dust pools, shake reset), and the R112 `beast_test` and `keeper_check`. All pass.
- `luau-compile` is clean. `luau-lsp` shows no new findings.

## Renders
`keeper_1..7_*.png` show 8 key poses per stage, R112 above R113. `motion_curves.png` shows the added layers over time.

## Check in Studio
- Wake roar and look-at on the mesh keepers (Snake, Ice Fang, Dragon, Jungle King); head and jaw pivots are from config.
- Accent placement on the Ice Fang spine and Snake tail tip (placed from bounding boxes).
- Particle look and density, Zzz size, and the eye-light range at night.
- Glass on the Knight crystals.
- Shake feel on the victim together with the existing hit kick.
