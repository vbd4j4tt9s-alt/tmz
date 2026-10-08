# R153 performance patch

Owner: *"do a performance patch after all these as its quite laggy"*, *"the whole game in general is quite laggy"*. Many players are on phones.
Rules for a performance patch: **no look change and no feel change** (what a player sees up close and what they hear stay the same), **no feature
reverted**.

Base: the R153 release branch at `0260e00` (the client and server fix rounds merged). `Config.Version` is unchanged, line 1 of every client script
is still the R152 load guard (Hotbar: its Backpack line, then the guard), BackgroundMusic is untouched. Sources: `lag_audit.md` (the "do now" set
D1-D10, the bigger wins B1-B10) and `architecture_review.md` (dead code, never-run code, the two quality governors).

## In one minute

- **The menus are 5x lighter once their icons have loaded.** Every icon kept ~400 hidden "fallback" pixel strips after its picture loaded. They
  now go when the picture shows: the PlayerGui drops from **37,389 to 6,967 instances** on every tier, at the hub and on the track.
- **The Void giveaway pack costs a quarter of what it did.** Its ~190 pieces were moved one by one every frame. Now the fixed pieces ride on the
  pack's root and each spinning ring on one hidden hub: **289 -> 79 property writes a frame** at the plaza on phones (294 -> 73 on PC). It still
  moves every frame in view on every tier (the jitter fixes stay).
- **73 dead files are gone**: 4.5 MB (44% of ReplicatedStorage) that every player downloaded at join and nothing ever used.
- **Pack outlines fit Roblox's limit of 31 Highlights**, weather glows included (40 -> 30 at once during weather on PC), and phones keep only 8
  far outlines (24 -> 8; every pack within 150 studs keeps its outline).
- Smaller ones: far keepers skip their switched-off effects, the 5-minute pack refresh no longer builds 35 packs in one frame, three
  "anything added anywhere" listeners now listen only where their things live, one frame-rate measurement instead of two, an idle hub display
  stops rewriting itself, the keyboard's far letters stop at 500 studs on phones.
- **Look and sound: identical.** Every fingerprint of the R152 performance suite (hub, keyboard, keepers, seed opening with its sound schedule,
  hotbar, popups, 1,574 packs) and the whole PlayerGui on a PC and a phone match the same game with this patch switched off, in everything that
  is drawn and every sound played. The only differences are never drawn (listed below).
- **Your part (Studio, 3 settings, ~5 minutes): see the checklist below.** The ten "bigger wins" each change something you can see, so they wait
  for your OK.

## What changed, and what it won (measured before -> after)

Measured with `docs/proposals/R153/tests/run_perf153.sh` on the Roblox mock with the real scripts, against the same checkout with this patch
switched off. "Writes" = property writes per frame by the scripts (each is a call into the engine in the game). Lua ms are the mock's (they rank
scripts against each other; the writes are the measure). Tiers: 3 = PC, 2 = phones, 1 = FastMode / slow devices.

| | Change | Win |
|---|---|---|
| D2 | `ArtworkRuntime87`: an icon holder keeps its fallback strips only while no picture of it is shown; they come back if the picture is ever unloaded | PlayerGui with the icons loaded **37,389 -> 6,967** instances (hub and track, every tier); 30,422 hidden strips -> 0 |
| D3 | Void giveaway: the pieces that never move against the bag are welded to its anchored root, each spinning ring to one invisible hub that turns; `VoidPackFx.Pulse` skips a colour write that stays in the same 8-bit level (the engine keeps part colours in 8 bits) | Plaza writes / frame (tier 3 / 2 / 1): giveaway **294 / 289 / 286 -> 73 / 79 / 76**; all scripts at the plaza 326 / 324 / 322 -> 105 / 111 / 108. Mock Lua for the giveaway client 1.75 / 1.64 / 1.22 ms -> 0.86 / 0.84 / 0.77 ms. +195 never-drawn instances (the welds and 3 hubs) |
| D6 | Keepers past 200 studs (every keeper effect is off there): once a step has switched their effects off, `KeeperFx` / `KeeperFx152` are not stepped again until the keeper comes within 200 studs; the body's smoothing and pose rules are unchanged (on screen within 350 studs it is still posed every frame) | At the hub all 7 keepers are past 200 studs: 14 effect steps a frame -> 0. Keeper writes unchanged (identical fingerprints) |
| D7 | `ClientFxBudget.HighlightRoom`: the track packs' outlines take what is left of Roblox's 31 after the weather glows, mutation outlines, plant auras and Void packs; on tier 2 a pack past 150 studs keeps its outline only among the nearest 8 (its far aura stays) | Pack outlines on phones **24 -> 8**; with 16 weather glows: PC 40 -> 30 Highlights at once (never over 31: none silently dropped), phones 40 -> 24. Within 150 studs: the same outlines on every tier |
| D8 | Keyboard far letters render to 500 studs on tier 2 (800 elsewhere) | On phones the letter window ends ~360 studs ahead of the runner, so at a normal camera nothing changes; a far / zoomed-out camera no longer draws letters past 500 studs |
| D9 | The 5-minute pack refresh: the 35 new packs are built 2 a server frame during the closed window's last 2 s (hidden, unavailable, prompts off); the reopening makes each available, rolls its weather and sends its rare-pack alert in the same frame and order as before | The reopening frame builds **0 packs instead of 35** (the burst every client had to take in at once); same packs, rolls, weather, alerts (`test_skin_spread153`) |
| D10 | `BeastAnimation` finds keepers by their tag and follows each keeper alone; `EconomyClient`'s garden prompts and plant colliders listen to the map's Bases; `LavaFlow` listens to the map | Four "every instance added anywhere in the workspace" handlers -> one (`AudioMixer`, see below). Pack openings, effects and the keyboard no longer call them |
| A1 | 73 dead files retired (below) | **4.5 MB** less ReplicatedStorage sent to every player at join (10.3 -> 5.8 MB) |
| A2 | `ChestService`: the never-run `BuildPlantAt` / `BuildGrowthModel` / `BuildArtLibrary` / `RenderGarden` (131 lines) replaced by a pointer to `GardenPlantRuntime` | `test_live_methods153` proves which functions are live |
| A8 | One quality signal: the frame rate is measured once, in `ClientFxBudget`; `SettingsClient`'s Auto quality reads its 3 s windows instead of counting frames on its own Heartbeat. Thresholds unchanged (tier 42 / 55 fps, FastMode 38 / 53 fps) | Per-frame connections 71 -> 70 (PC hub), 70 -> 69 (phone hub), 69 -> 68 (track). Same FastMode decisions at the same frames (`test_quality153`) |
| R153 | Hub displays: an inactive display (far, FastMode, tier 1) no longer writes its item home and resets its avatar every half second | 2.7-4.5 same-value CFrame writes a frame -> 0.2 (on the track too: tier 2 43.5 -> 40.8, tier 1 33.4 -> 29.6 writes / frame) |

Unchanged by design (they need geometry or settings changes, so they are in the checklist or the bigger wins): drawn parts within 400 studs
(hub 7,314 / 7,244 / 7,001; track 2,355 / 2,053 / 1,800), keycap detail, shadows, streaming.

### Kept as they are, on purpose

- **Smoothness first (the jitter rounds).** The audit proposed 15 Hz steps for the giveaway pack beyond 40 studs and 10 Hz motion for keepers
  beyond 200 studs. Both would bring back visible stepping on screen, which R153's jitter fixes removed. The wins above come from far, off-screen,
  hidden and duplicate work instead: the giveaway moves 4 parts instead of 190 every frame, the far keepers skip effects that are off.
- **Treadmill popups batched into one event per 0.2 s (D9, third part): not done.** Batching means holding each player's popup until a shared
  tick, up to 0.2 s late: a feel change. The payload is also pinned by the R151 popup suites. Roblox already packs remote events into one network
  packet per frame.
- **`AudioMixer` keeps its workspace listener (D10).** It puts every new sound in its volume group (Effects, Music ...); narrowing it could leave a
  sound outside the sliders. It is also a frozen file (R153 fling suite).
- **The code half of D5** (track models Persistent, an earlier MovementGuard prefetch) is not in this patch: `MovementGuard` is frozen by the
  track-walls suite and a prefetch change touches movement. The Studio half is in the checklist.
- **`ChaseService`'s never-run copies (563 lines)** stay: the file is frozen byte for byte by three keeper suites. `test_live_methods153` lists
  them by name (Begin, Finish, Start, `_updateActiveRun`, `_maintainGuardians`, the three drop-chest methods, CleanupPlayer, ...) and proves the
  live ones are `ConcurrentKeeperService`'s, so nobody edits the dead copy.

### R153 leftovers checked

- `KeeperFollow153` is gone: no file, no manifest row, nothing in src names it (only a comment says it is gone); the speed signs are pinned.
- Per-frame work when far or off screen in what R153 added: the trampolines do two squared distances a frame (the bounce only within 60 studs,
  the squash only while a mat moves); belts and arrows run every frame only near and in view; the Mech pack's hum and parts move only for a
  detailed or carried pack; holes and the garden bonus sign poll at 4 Hz / 2 Hz; the keeper speed signs are pinned (no loop). The one waste found
  was the hub displays' idle rewrite (fixed above). The hub avatar's cheer is written every frame in view and at 30 Hz out of view (as R153's
  jitter round set it).

## Retired dead code (73 files)

Nothing requires them by any path: static `require`, `WaitForChild` / `FindFirstChild` names, string-built names (`'PlantArt'..biome`,
`Index[id]` tables), `script.Parent[...]`, name tables, owner commands, the installer. Checked with a require graph over src (comments stripped,
every name used as a word counted as a use, every `'Prefix'..x` reaching every module that starts with it) and by hand. Removed from `src/` and
`src/MANIFEST.tsv`; the installer builder retires deleted scripts with undo.

- **65 pack-art data modules** of the V120-V122 packs: `SeedPackArt<Biome>` and `SeedPackArt<Biome><NN>` (51, Snow_06 in two chunks),
  `SeedPackLOD<Biome>` (7), `SeedPackShapes<Biome>` (7). The V123 renderer clones the uploaded `SeedPackMeshAssets` instead. The R153 pack-parts
  suite measures the pouches against this data, so it now takes those files from git (`0260e00`).
- `NavigationArtwork`, `TopNavigationLayout`, `VectorIcons91` (two suites bundled it for TravelButtons, which never required it: removed from
  their bundles), `AncientWorldrootSeedArt45`, `ElderbloomSeedArt45` (not in `RarityPlantArt`'s index).
- The stub `ServerScriptService/ChestChaseServer/ActiveTraining81` (`function M.Step(...)end`; `BaseService`'s `self.ActiveTraining81` is a field,
  not this module).
- The two client scripts that waited for the game to load and did nothing: `SpeedMilestones87`, `ColourfulText81`.

**Kept, in doubt (listed for you):** `DigSoundAnalyzer` and `BatAssetImport` (owner tools run from the Command Bar), `PassGiftDialog` (the
R150 input-sound suite still exercises it), `WorldDesign` (the R147 mystery suite reads it as the layout reference for the base tool box). All
four are never required by the game; `PackTierEmblem` and `RouteDress84` are still called, so they stay.

## How the look and the sound were proven identical

`run_perf153.sh` (in `tools/tests/run_all_suites.sh`) builds both sides with the real scripts: this checkout, and the same checkout with the
patch switched off (`perf153_off.py` applies `perf153.patch` in reverse; `PERF153_BASE=<commit>` compares against a commit instead).

1. **The R152 fingerprints** (`run_perf152.sh` with that base): the hub on the owner's place per tier with the displays empty and with champions
   (the whole world, then the moving parts every 4 frames from 7 camera poses), the keyboard per tier (7 rows in every biome, 4 looks, a run),
   the 7 keepers per tier (asleep / waking / chasing / striking / off screen), the seed opening for every rarity on desktop / phone / low at 60 and
   30 fps and an onlooker's Secret / King **with the sound schedule** (which sound, when, file position, speed, volume, heard level), the hotbar,
   the speed popups, 1,574 packs. Compared on what the engine draws: part colours at the 8 bits the engine keeps, Anchored / Massless (physics,
   never drawn) left out, a gui's MaxDistance as "in range or not".
   Result: each of the 6 hub runs has 73 shots, all the same in everything drawn (54 of them with a display item or the giveaway pack provably
   off screen, compared without it as in R152); keyboard identical (tier 2: 17 shots differ only in parked, switched-off strips); keepers, seed
   opening, hotbar, popups, packs **identical**; every sound schedule identical.
2. **The whole UI on a PC (1280 x 720, tier 3) and a phone (844 x 390, touch, tier 2)**: every client script started, the PlayerGui
   fingerprinted before and after the icons' pictures load, every sound played: before the pictures load identical; after, the same in
   everything drawn (the only differences: the 30,422 hidden fallback strips that are gone); the sounds identical.
3. **The track packs' outlines** per tier, with and without 16 weather glows: within 150 studs the same packs wear the same outline.
4. Unit checks: the pack refresh spread gives the same packs, rolls, weather and alerts as the one-frame refresh; the quality windows and
   FastMode decisions are the old ones; the live methods are the installed ones.

Allowed differences, all never drawn: the giveaway's welds (`PackWeld153`) and its 3 invisible spin hubs (`PackSpinHub153`), the removed hidden
fallback strips, a parked (switched-off) far keyboard strip's MaxDistance.

## Tests

`run_perf153.sh` (registered in `tools/tests/run_all_suites.sh`), plus the suites this patch touches, each in its own scratch dir, all passing:
R152 perf152 (its own base, the R152 patch switched off: hub, keyboard, keepers, seed, hotbar, popups, packs identical or same-visible),
load_guard, keepers, void_giveaway, seed_opening, zfight_sweep, R152 `run.sh`; R153 jitter, pack_parts, fixes, fixes_client, fixes_server,
clover, seed_rarity, nooks, fling_swoosh, track_walls, mech_pack, hotbar, treadmills; R151 hub_displays, badges, pack_shapes, packs, perf,
rare_pull, announce, treadmills, speed_popups, static checks; R150 sfx; R149 keyboard, growth, weather, tiger_gear; R148 index_limited; R147;
R137; R130; veiled / holes R122; perf R121. `run_perf152.sh` now compares part colours at 8 bits by default (`perf153_opts.luau`), because the
giveaway pulse skips a write inside the same 8-bit level. Suites updated narrowly: R148 `test_index_limited` (the fallback may be gone once the picture shows; new: it is drawn again after
an unload), R149 `test_keyboard` (tier 2's far letters render to 500 studs), R152 `test_giveaway_client` (a piece is anchored or welded to an
anchored part of the pack), R150 `run_sfx` / `test_fast_travel` and R152 `run.sh` (retired modules out of their lists), R153 `run_pack_parts`
(the retired pouch data from git). `tools/tests/roblox.luau`: a Weld whose Part0 is anchored moves its Part1 when Part0 moves, as the engine does.
If the patched code is edited later, `perf153_off.py` stops and says so: regenerate the patch with
`git diff 0260e00 <last perf commit> --diff-filter=M -- src ':!src/MANIFEST.tsv' > docs/proposals/R153/tests/perf153.patch`.

---

## Studio checklist for the owner (not code: Roblox only lets these be set in Studio)

Do these in Studio on the live place, then one Play test (ideally on a phone, or Studio's device emulator). Each takes a minute.

1. **Keycap detail by distance (lag audit D1).**
   - In the Explorer select `ReplicatedStorage > R142Keycap`. In Properties set **RenderFidelity = Automatic** (it is `Precise`).
   - Every keyboard key is a copy of it, so the next Play uses it. Keys near you look exactly the same; far keys use Roblox's lighter versions
     instead of full detail out to 600 studs (2,288 keys on a phone, 3,605 on PC).
   - Optional first: paste this in the Command Bar and note the number it prints (the keycap's triangles; if it is over about 300, see B4):
     `print(#game:GetService('AssetService'):CreateEditableMeshAsync(Content.fromUri(game.ReplicatedStorage.R142Keycap.MeshId)):GetFaces())`
   - Scripts are not allowed to set RenderFidelity, which is why this one is yours.

2. **Delete the sun-rays pass and the dead effects (D4).**
   - Delete `Lighting > SunRays`. Its strength is 0.01 (the game turns it to 0.008): it draws nothing you can see but still costs a full-screen
     pass on every device. The lighting script copes with it being gone.
   - In `Workspace`, delete the four effects that sit directly in it: `Bloom` (size 56), `SunRays`, `ColorCorrection`, `Blur`. Effects only work
     inside Lighting or the Camera, so these do nothing today; deleting them is tidy-up and stops the heavy Bloom being moved into Lighting by
     mistake. Do **not** delete `Lighting.Bloom` or `ChestChaseColor`.

3. **Streaming, so fast runners never hit "gameplay paused" (D5).**
   - Select `Workspace` and set **StreamingMinRadius = 192** (it is 64). The ground ahead of a fast runner is then always loaded; it costs a
     little memory.
   - Leave `StreamingIntegrityMode` on `PauseOutsideLoadedArea` and `StreamingTargetRadius` on 1024.
   - Test: sprint down the track in the device emulator (phone, slow network). A "gameplay paused" spinner or a freeze followed by a jump is
     what this fixes.

## Bigger wins (B1-B10): each changes something you can see, so **each needs the owner's OK**. None of them is in this patch.

| | Change | What you would see | Effect |
|---|---|---|---|
| B1 | No shadows from script-built parts under 1.5 studs | Tiny shadow specks under small props (fruit, pebbles, petals, shards) go | ~900 fewer shadow casters at the hub (~27%) - **needs the owner's OK** |
| B2 | Market showcase built by each player's device, hidden past ~200 studs (or its fruit baked into meshes) | The showcase appears from ~200 studs; baked fruit shade slightly differently | Up to 2,186 fewer parts away from the market - **needs the owner's OK** |
| B3 | Phones: keyboard letters at 12 px/stud, 56 key rows ahead instead of 74 | Letters a bit softer; the far end of the keyboard ~150 studs nearer | Letter textures -44%; ~400 fewer keys on phones - **needs the owner's OK** |
| B4 | A lighter keycap mesh, same silhouette (upload, set on `R142Keycap`) | Rounded key edges slightly less smooth up close | Fewer triangles for every key, near and far - **needs the owner's OK** |
| B5 | Phones: Bloom off on tier 2 | Neon glows less soft on phones | One full-screen pass less - **needs the owner's OK** |
| B6 | Glass -> SmoothPlastic (same transparency) for Frostland ice, treadmill glass, EnvironmentPolish | No glass sheen on high graphics levels | A lighter transparent pass - **needs the owner's OK** |
| B7 | Gardens on phones: 1,000 parts / 16 detailed plants (today the PC's 1,400 / 24) | Far plants switch to their simpler model sooner | Up to 400 fewer plant parts on phones - **needs the owner's OK** |
| B8 | Phones: the Void giveaway pack with the track's lighter effect budget | Less sparkle on the giveaway pack | The plaza's per-frame cost drops further - **needs the owner's OK** |
| B9 | `StreamingTargetRadius` 640 + low-detail stand-ins (`LevelOfDetail = StreamingMesh`) for the big landmarks | Far track scenery simpler / loads later | Lower phone memory on the track - **needs the owner's OK** |
| B10 | Keyboard letters as texture atlases (Decals) instead of SurfaceGuis | Letter rendering changes (can be made very close) | No SurfaceGui textures on the keyboard at all - **needs the owner's OK** |
