# R121: final performance pass (quality-neutral)

Nothing was run in Roblox Studio; real frame time was not measured. Every fix was checked offline (luau-compile, luau-lsp
with no new findings, existing mock test suites) plus micro-checks comparing the old file (commit 352e079) with the new
one: `sh docs/proposals/perf_R121/tests/run.sh`.

Rule: same visible result at normal quality/distance, same gameplay and UX. Fixes skip work whose result is already in
place, cache values instead of re-reading them, or reuse buffers.

## Fixes (ranked by expected saving)

1. **ChaseService `_setGuardianNoticeVisual` (server):** scanned every chasing keeper with GetDescendants every
   Heartbeat. Now one scan per keeper, again only after a BillboardGui/SurfaceGui is added. 600 heartbeats: 600 -> 0 scans.
2. **GardenVisuals growth refresh (client):** 20 Hz within 75 studs (unchanged); beyond that 10 Hz on screen, 2 Hz off
   screen. Growth takes >= 72 s, so the step is at most 0.14% (sub-pixel at that distance).
3. **ShopViewport / CollectionViewport / GuiShine:** hidden menus' rows and shined buttons no longer walk their whole GUI
   ancestry 20-30 times a second; a cached "what hid me" check (0 mismatches in 20,000 random steps).
4. **BeastAnimation keeper voice:** resolved on change / every 0.5 s; Sound properties written only when different;
   Stop() only when playing; one reused context table. 600 frames: Stop 4200 -> 0, Sound writes 8400 -> 0, same plays.
5. **ConcurrentKeeperService drop countdown:** label written once per second instead of every frame (322 -> 6 writes).
6. **LavaFlow:** cached route flag, glow moves joined into the existing BulkMoveTo, buffers reused; identical positions.
7. **KeeperHitEffects:** idle overlay writes skipped (3000 -> 5 over 600 frames); same victim flash.
8. **SpeedGainPopup track arrows:** move buffers reused (no allocations per tick).

## Not verified
- No Studio run; savings are call/allocation counts. Fix 2 checked by review (plant art can't be built in the mock).
- Engine assumptions: Sound.Playing follows Play/Stop; DescendantAdded fires per descendant of an added subtree;
  BulkMoveTo equals setting CFrame.

## Recommendations (not done, riskier)
1. Idle keeper upkeep (server) re-runs full keeper setup at 4 Hz (~10k+ calls/s): run the full re-prepare at 1 Hz or on change.
2. GardenLiftPrompts loops over every plant prompt in the map every 0.15 s: keep a set of owned prompts.
3. Workspace-wide DescendantAdded listeners (LavaFlow, BeastAnimation, AudioMixer, EconomyClient): scope to the map or tags.
4. PlantShovelPicker: one connection per non-plant model; track plants by tag.
5. Client polling (tutorial every 1 s, pending sales every 5 s): push revision attributes instead.
6. Small per-frame allocations (GardenVisuals build signature, ItemCosmetics.visible, TreadmillFx spin buffers,
   MovementGuard RaycastParams, CarryNameplate84 GetChildren, SeedPackRender closure).
