# Boots R111: biome materials, walking prints, idle aura

This builds the approved sneaker-boot shape (docs/proposals/art_boots_plants) and adds biome materials, ground effects and an idle effect. Nothing has been run in Roblox Studio. The previews in `renders/` are three.js approximations. Their geometry, colours, materials and effect timings come from the real Luau modules run under a mock.

## Files
- `ReplicatedStorage/RunnerBootArt` (changed): the approved design plus materials and detail parts. Same API. Specs can now carry `Transparency`, `Reflectance` and `Shape='CornerWedge'`.
- `ReplicatedStorage/ShopProductArt` (changed, 3 lines): passes Transparency and Reflectance through and supports CornerWedgePart.
- `ReplicatedStorage/RunnerTrailEffects` (changed): prints that age, shared step bursts, idle aura rigs, arcs, budgets. It connects no events.
- `StarterPlayerScripts/RunnerTrailClient` (changed): picks the detail level for each runner and applies the budget.
- **New** `ReplicatedStorage/RunnerTrailStyles` (ModuleScript): per-biome effect data and budget rules.
- `EconomyService` is not changed. The client now takes the look from `BootBiome` when `BootCount==2`. This means **all 5 boots get effects whatever the treadmill tier is**. The old R47 gate (ground effects only at Lava+ treadmill tiers, and only for Lava/Crystal/Storm boots) is bypassed. `BootGroundTheme` still works as a fallback.

## Per biome (parts per leg: approved to R111)
| Boots | Materials | Walking | Idle |
|---|---|---|---|
| Sand (16 to 19) | Rubber sole, Sandstone midsole, Leather upper, Fabric wrap with a loose tail, Sand-worn toe and heel | sand prints fade over 2.6 s, dust puff and kicked sand | swirling sand ring (spins) and grains |
| Frost (17 to 21) | Glacier upper and sole, Ice overlays, Snow fur cuff, clear Ice toe cap and heel fin, 3 icicles | clear ice prints crystallise into white snow with a small star over 3 s, snow puff | frost crystals creep out on the ground, mist, snowflakes |
| Lava (17 to 21) | Basalt, CrackedLava overlays, Neon seams, crack and heel drip, obsidian Glass shards | glowing prints cool yellow to red to basalt over 2.4 s, sparks, ash | glowing ground cracks, rising embers, heat haze |
| Crystal (17 to 21) | Glass shell (T .28, R .3) over a Neon core, Glass toe and tongue, Metal setting, CornerWedge crown and ankle shards | reflective shard prints whose centre twinkles, sparkles | twinkles, 3 orbiting shards |
| Thunder (19 to 22) | Metal upper, Foil overlays, Neon bolts, wing and ring, ForceField static field | bolt prints that flicker, turn blue and fade over 1.6 s, sparks, arcs | crackling sparks, arcs from the boots to the ground |

The R47 ground ribbons are kept for all five boots. They are slightly more transparent than before so the fresh prints show through.

Textures are built-in only: `rbxasset://textures/particles/sparkles_main.dds` and `smoke_main.dds`, which the place already uses. Prints are small anchored parts.

## Speed and budget
- Stride spacing is `clamp(speed*0.12, 2.2, 60)` studs. Prints come no faster than every 0.11 s for the local player and 0.16 s for others, or 1.5 times that on low. At 500 studs/s this is about 6.7 prints/s, 75 studs apart. Prints stretch up to 1.8x with speed and live 30% shorter above 150 studs/s.
- The idle aura fades in after 0.6 s standing still (below 0.8 studs/s, grounded). It fades out 0.25 s after moving. Treadmill training shows the aura instead of stacking prints.
- Budget tiers come from `ClientFxBudget.Get()`, so the FastMode / Effects quality setting applies. Graphics level 1-3 forces low and 4-6 caps at mid.

| | High | Mid | Low |
|---|---|---|---|
| runners handled | 8 | 6 | 4 |
| local / other print pools (3 parts each) | 24 / 36 | 18 / 18 | 12 / 6 |
| idle rigs (plus 1 always kept for the local player) | 5 | 3 | 1 |
| burst particles per second | 160 | 90 | 40 |
| particle scale | 1 | .75 | .5 |
| arc pool | 6 | 4 | 2 |

- Detail per runner: the local player gets everything. Others within 75 studs (60 on mid, 45 on low) and on screen also get everything. Others within 120 studs (100 on mid) get prints only. Beyond that, up to 160 studs, they get ground ribbons only. On low, far runners update every other tick.
- Reduced Motion halves particles and turns off arcs, flicker, twinkle, the sand spin and the shard orbit.
- `CosmeticBudget` has no boot hook, so its low flag source (`ClientFxBudget`) is used instead.

## Tests run (Luau CLI with a Roblox mock)
- `Create()` on R15, R6 and mid-run rigs returns 2 on every rig, with at most 22 parts per leg. The shop Build creates the glass and CornerWedge parts.
- 282 effect checks pass with the real client and module. The run goes walk, stop, idle, walk, 500 studs/s, 7-player crowd, FastMode, graphics level, Reduced Motion, unequip, respawn, leave, script destroyed.
- What the checks cover: pool caps, particles per second, idle rig cap and reuse, detail levels, no parts left and connections closed after destroy. The peak was 227 live effect parts against a bound of 257.
- luau-compile passes and luau-lsp reports no findings on all 5 files.

## Check in Studio
1. How CrackedLava, Glacier, Foil and ForceField look on small parts, and whether the ForceField shimmer is too busy.
2. Whether Crystal glass reads violet under the real sky. Reflectance may wash it out; lower it to about .2 if so.
3. In the shop ViewportFrame: glass reflectance, ForceField and Neon with no bloom.
4. That `Emit()` on an emitter moved within the same frame spawns at the new spot. That the Disc shape and LockedToPart swirl look right. Idle visibility on the matching biome ground (sand on sand, frost on snow is low contrast).
5. Frame time with 8 booted players nearby on mobile, compared with R47.
6. Whether you want the treadmill-tier gate back (one line in `RunnerTrailStyles.ThemeName`).
