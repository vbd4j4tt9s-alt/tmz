# R112 planting VFX/SFX: notes

**Files**
- NEW `ReplicatedStorage/PlantingEffects` (ModuleScript): `src/ReplicatedStorage/PlantingEffects.lua`
- CHANGED `StarterPlayer/StarterPlayerScripts/GardenVisuals` (LocalScript): 3 small hooks (create, `Add` on track with an `initial` flag, `Remove` on removal). It is wrapped in pcall, so plant visuals keep working if the effect fails.
- No server changes.

**Trigger:** a crop model (`GardenPlantV141`) appears after the client's initial scan and 3 s startup grace, and its `PlantedAt` is 6 s old or less by `workspace:GetServerTimeNow()`. Everything is keyed by `CropId`, so a growth-stage rebuild (same id) does not replay the effect and keeps its mark. Joins, garden loads, stream-ins and old crops never trigger it.

**VFX:** a spiral of voxel cubes around a seed hole. It has a crater-rim height profile, 4 brown tones taken from the soil colour, and random size and tilt. The cubes rise from inside the soil with a back-out bounce and a wave from the centre outward. There is a smoke-texture dust puff and dark clod particles, and 3 to 6 cubes are tossed out of the hole onto the rim. After about 2.4 s the cubes sink back (back-in ease). A two-disc mark (dug soil plus a darker hole) fades in and stays until the crop is gone (0.5 s grace for reordered replication). The layout is deterministic per crop id, so every client sees the same pile.
Size: pile radius = clamp(0.55 + 0.42·sqrt(catalog Radius × PlantScale), 1, 4.5), height 0.4·R, cube count 8 + 9·R (plus support cubes). Herb: about 23 cubes, R 1.1. Apple: about 36, R 1.9. King tree ×2: about 82, R 4.2. The mark radius is 0.45 to 1.35, below half of the 3-stud plant spacing.
Budgets (tier from ClientFxBudget; graphics level 1–3 forces low): high 6 piles / 260 cubes / 96 per pile, mid 4 / 130 / 44, low 2 / 50 / 22 with no flyers. Past 95 studs you get half a pile. Past 170 studs, or off-screen past 30 studs, there is no pile. Marks show within 220 studs, nearest 160/110/60. Reduced Motion gives no overshoot, no flyers, no clods and fewer puffs. `StudioPlantEffects='off'` turns everything off. All parts have CanQuery, CanCollide and CanTouch set to false, so planting raycasts are unaffected. Movement uses BulkMoveTo, and parts are pooled.

**SFX** (positional, Effects sound group; edit `M.Sounds` or set `<Key>SoundId` attributes on the module):
| Layer | Id | Source | Play |
|---|---|---|---|
| Thud | `rbxasset://sounds/action_jump_land.mp3` | built-in default landing sound | pitch .70–.80, lower and louder for big piles |
| Crunch | `rbxassetid://9125725227` | SeedPackRules.TearSoundId (paper tear) | pitch .50–.60, 0.28 s from 0.10 s, faded |
| Pop | `rbxassetid://131731955363530` | InteractionAudio Bubble06 (harvest pop) | pitch 1.12–1.26, +80 ms |
| Sparkle | (empty) | planter only | set `SparkleSoundId` to enable |
Other players' plantings play at 0.75× volume. At most one set plays per 0.09 s. Unloaded sounds are skipped, never played late.
Better free Creator Store replacements: a short "dirt/soil impact" or "shovel dig" thud, a "gravel/dirt crumble" one-shot under 0.4 s, and a soft "pop"/"plop" or "cute sparkle chime".

**Verified offline** (Luau CLI + mock, real PlantCatalog): `tests/test_planting.luau` gives 69/69; `tests/test_gv.luau` (real GardenVisuals) gives 6/6. luau-compile is OK. luau-lsp reports no findings in PlantingEffects and no new ones in GardenVisuals. PNGs here are three.js **approximations** built from the real layouts (`tests/dump.luau`).

**Needs Studio:** how the sounds actually sound (and whether the built-in landing file resolves), the particle look with the sparkle texture, mark z-fighting at a distance, and feel on mobile.

**Refinements**
Done:
1. Heavier sound for bigger piles.
2. The pile is the same on every client.
3. Quieter plantings from other players.
4. Self-disable after 3 errors.
5. Debug attributes `PlantingPiles/Chunks/Marks` (Studio/admins).

Proposed:
- a) Local prediction on the planter's click (0 latency), which needs EconomyClient.
- b) The seed "drop" into the hole (seed ball falls in at t=0).
- c) Soil-tinted chunks per biome and fence tier.
- d) A tiny squash on landing cubes, via Size, only on high tier.
- e) Real dirt SFX from the Creator Store.
