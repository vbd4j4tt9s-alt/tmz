# R153 lag audit: why the whole game feels laggy (audit only, no code changed)

Owner, after installing R152: *"the whole game in general is quite laggy"*. Many players are on phones.

Base: the R152 release commit `e36b71b`. Nothing in `src/` was changed.

## In one minute

R152's performance patch was real, but it only removed **repeated writes of the same value** (PropCache152) and froze two display items while they are
**off screen** (ViewCull152). It did not touch what a phone actually struggles with here, which is **how much there is**:

1. **The hub is very heavy, and it is the same on every quality tier.** Standing at the plaza a client holds **about 7,200 drawn parts within 400 studs**
   (3,300 of them cast shadows, about 900 of those are tiny props). The market area alone is **2,485 parts** (its fruit / plant / pack showcase is 2,186).
   R151 and R152 added about **1,600** of these (HubLife, HubDecor, displays, the Void giveaway, treadmill dressing). The FastMode / phone tiers shrink effects,
   but they cannot shrink any of this geometry, because the server builds it.
2. **The UI holds 38,000 instances, and 82% of them are hidden icon "fallback" strips.** Each icon (77 of them: shop, index, daily rewards, HUD) carries
   about 400 hidden Frames + UIGradients that stay forever after the real image has loaded. That is more instances than the whole 3D world (15,000). It costs
   phone memory and join time and does nothing on screen.
3. **The keyboard keycap mesh is set to `RenderFidelity = Precise`** in the place file (`ReplicatedStorage.R142Keycap`). So all **2,288 keycaps on a phone
   (3,605 on PC)** are drawn at full mesh detail, out to about 600 studs, with no level of detail. Its triangle count is unknown offline. This was an
   open question in R149 (B1). The place file now answers it, and the answer is the worst case.
4. **The new R152 Void giveaway pack is the biggest per-frame script cost in the hub.** About 200 pieces are moved and 90 recoloured on every step
   (290 writes), on every tier, whenever it is in view within 190 studs. It stands in the middle of the spawn plaza. On the mock it costs 7x the next
   script (5.2 ms against 0.7 ms per frame).
5. **The keyboard letters are 92 SurfaceGuis on a phone (124 on PC), with about 8 million canvas pixels.** Each one is its own texture, and it is redrawn
   whenever any of its labels changes.
6. **Streaming can freeze fast runners.** The place has `StreamingIntegrityMode = PauseOutsideLoadedArea`, `StreamingMinRadius = 64`, and runners reach
   about 500 studs/s. On a phone with a slow connection, outrunning the loaded area shows Roblox's "gameplay paused" freeze. That is exactly the kind of
   "lag" players report. It cannot be shown offline.

The things the brief suspected that turned out **not** to be the problem:
- **Shadow-casting lights: none.** All 46–47 lights have Shadows off, and the place uses `ShadowMap`, where local lights cannot cast shadows anyway.
- **Server-side per-frame replication: none of note.** Only active keepers' root parts move on the server. Every spinning or animated prop is
  client-side.
- **Network rates are low.** The busiest broadcast is the treadmill popup: 5 per second per training player.
- **Unanchored physics: nothing that keeps simulating.**

The recommended R153 "do now" set (section 3) removes the hidden UI strips, fixes the keycap level of detail, makes the giveaway pack cheap, trims
invisible or far-only work, and makes fast runs safe from streaming freezes. None of it changes anything a player sees up close.

---

## How this was measured

Everything below was run offline. Nothing was run in Roblox Studio or on a phone.

- **`docs/proposals/R153/tools/place_census.py`** reads the owner's place file (`sapkeyver.rbxl`). It reports Workspace by area (parts, MeshParts,
  shadow casters, small / tiny casters, transparent / Glass / Neon parts, unanchored parts, lights and their Shadows flag, emitters, beams, SurfaceGuis
  with canvas sizes, Highlights), the Lighting service and its effects, the Workspace streaming / physics settings and the template stores.
- **`docs/proposals/R153/tests/lag153_census.luau`** runs on the Roblox mock (`/opt/luau/luau`). It is built by `lag153_world.py` on top of the R152 perf
  world (`perf152_world.py`).
  - The world is the owner's place with **every real start-up builder**: MapService and its passes, MarketLayout, treadmills, fences, mystery
    pedestals, Verity, leaderboards, HubDecor151, both hub displays and the Void giveaway pedestal.
  - It runs the real **KeyboardTrack, SnowBiome149, HubLife151, HubDisplayClient and VoidGiveawayClient152** clients.
  - With `ALLCLIENT` it also starts **65 of the 67 StarterPlayerScripts clients**. DistantGardens and StudioTestClient wait for objects the mock does
    not have.
  - It runs for tiers 3 / 2 / 1, standing at the hub plaza and on the track (z 1300).
  - It prints:
    - counts per area, and within 1024 / 400 / 150 studs;
    - the PlayerGui, broken down by ScreenGui;
    - every RunService connection and bound render step, by the script that made it;
    - property writes per frame by area;
    - Lua ms per frame per script.
  - Run it with `sh docs/proposals/R153/tests/run_lag153.sh [scratch dir]`. It takes about 4 minutes.
- **R152's own numbers** (`docs/proposals/R152/perf.md`) are reused for the keyboard while running and for the keepers. **R151's**
  (`docs/proposals/R151/perf.md`) are reused for weather particles.
- **What the mock cannot do:**
  - It has no GPU, so triangles, overdraw, shadows, post effects and SurfaceGui textures are counted and then reasoned about from Roblox's documented
    behaviour.
  - Its "Lua ms" runs CFrame maths and every property write in Lua. It also ran on a shared machine under heavy load (load average 23–31 on 4 cores).
  - So the ms **rank scripts against each other; they are not phone milliseconds.** The tier-2 numbers quoted come from runs made one at a time.
    Parallel runs give the same ranking with 2–4x the values.
- **The place file is the R140-era file the R147–R152 installers were built on.** The installers change scripts and move a few objects; they do not change
  Studio-only properties such as `RenderFidelity` or the Lighting and Workspace settings. One known difference: the R140 toolbox keyboard
  (`Workspace."Keycap/Keyboard"`: 288 keycaps, 36 of them loose, and 8 server scripts that tween keys on touch) is in the file, but R147 retired it.
  Check it is really gone from the live place.

## What a phone has to carry (tier 2, from `lag153_census.luau`)

| | hub plaza (0, -330) | track, z 1300 |
|---|---|---|
| Workspace instances (server-built + client-built) | 14,734 | 16,609 |
| drawn parts within 150 / 400 / 1024 studs | 3,593 / 7,197 / 7,664 | 911 / 2,050 / 3,160 |
| shadow casters within 400 studs (tiny, under 1.5 studs) | 3,296 (908) | 92 (11) |
| semi-transparent / Glass parts within 1024 | 476 / 185 | 471 / 457 |
| keycap MeshParts (all at Precise fidelity) | 673 | 2,288 |
| SurfaceGuis drawn, canvas pixels, letters | 68, 8.0 M, 598 | 128, 13.7 M, 1,590 (keyboard: 92, 8.2 M, 1,479) |
| PlayerGui instances (of which icon fallback strips) | 37,905 (31,218) | 38,071 (31,384) |
| frame handlers alive (RenderStepped / Heartbeat / Pre/PostSimulation / PreAnimation / bound) | 67 (16 / 36 / 3+2 / 3 / 7) | 67 |
| property writes per frame, standing still | 319 (giveaway pack 289) | 39 (keepers 28); running: keyboard +112 (R152) |
| Lua per frame on the mock (solo run) | 7.3 ms: giveaway 5.2, keepers 0.74, keyboard 0.54, every other script under 0.15 | 3.8 ms: keepers 3.1, every other script under 0.1 |

The same at tier 1 (FastMode, a phone that runs slow) and tier 3 (PC):
- hub: 6,954 / 7,267 drawn parts within 400 studs; giveaway writes 286 / 294 per step;
- track keycaps: 1,496 / 3,605;
- keyboard SurfaceGuis: 68 / 124, with 5.7 M / 11.0 M canvas pixels.

**Auto quality cannot get a slow phone out of this.** `SettingsClient` switches on FastMode after about 6 s under 38 fps (`SettingsClient.client.lua:118`),
and `ClientFxBudget` drops a tier under 42 fps (`ClientFxBudget.lua:3`). Neither one shrinks the hub geometry, the UI or the giveaway pack.

---

## 1. The top costs, ranked

Impact is for a mid-range phone. **HIGH** means likely several ms per frame, tens of MB of memory, or visible freezes. **MED** means about 1–3 ms or
noticeable spikes. **LOW** means under about 1 ms. GPU items cannot be timed offline; their rating is reasoned from the counts.

| # | What | Where | Phone impact (estimated) | Kind |
|---|---|---|---|---|
| 1 | **Hub geometry, the same on every tier**: about 7,200 drawn parts within 400 studs of the plaza. Market area 2,485 (showcase 2,186, with 681 tiny shadow casters). Treadmills 1,338 (6 bases). Fences 978. HubLife 549–626. HubDecor 487. R151 + R152 added about 1,600 | `MarketLayout.lua:425-460`, `BiomeVisuals.lua:1266` (BuildTreadmillV131), `GardenFenceArt.lua:76`, `HubLife151.client.lua` / `HubLifeArt151.lua`, `HubDecor151.lua` | **HIGH**: draw calls and scene upkeep for about 7k objects, every frame at the hub | client GPU + render CPU |
| 2 | **Keycaps with no level of detail**: `R142Keycap.RenderFidelity = Precise` (1) in the place, and every key is a clone of it. 2,288 on phones, 3,605 on PC, out to about 600 studs | place: `ReplicatedStorage.R142Keycap`; cloned at `KeyboardTrack.client.lua:873`; rows per tier at `ReplicatedStorage/KeyboardTrack.lua:158-160` | **HIGH if the mesh is detailed**: N triangles × 2,288 on a phone (N = 300 gives about 0.7 M triangles, N = 1,000 about 2.3 M) | client GPU |
| 3 | **38k UI instances, 31k of them hidden icon fallback strips**. 77 icons × about 405 instances (one Frame + UIGradient per pixel strip) are cloned into every icon holder and kept after the image loads. GardenPasses alone has 18,278 | `ArtworkRuntime87.lua:38-49` (draw), `:82` (clone into every holder), `:19` (only hidden); built at join by `GamePassClient.client.lua:30`, `ChestIndex.client.lua:14`, `DailyRewardsClient.client.lua:14`, `WorldStatusHud.lua:48` | **HIGH on memory and join**: more instances than the 3D world (15k), created at join; held in memory for the whole session | client memory / CPU at join |
| 4 | **Void giveaway pack (R152)**: about 200 pieces posed + 90 recoloured per step (289 writes per frame at tier 2, 286 at tier 1, 294 at tier 3). Runs whenever it is within 190 studs and in view, at the spawn plaza (also reached from bases 5 and 6). It is 70% of all client Lua at the hub | `VoidGiveawayClient152.client.lua:145-181` (stepPack), `:29` (190-stud range), `:185` (30 Hz on phones); `VoidPackFx.lua:53-67` (Pose / Pulse) | **MED-HIGH** at the hub: largest per-frame script; on the mock 5.2 ms per frame against under 0.8 for any other script | client CPU (+ ~200 moving parts to the renderer) |
| 5 | **Keyboard letters**: 92 SurfaceGuis on a phone (124 on PC), 1,479 labels, about 8.2 M canvas pixels (≈33 MB if Roblox kept them at full size as RGBA). Near rows at 16 px/stud, far rows at 4 px/stud. A label change redraws its whole SurfaceGui | `KeyboardTrack.client.lua:358` (near), `:482` (far), `:791` (spacebar); `ReplicatedStorage/KeyboardTrack.lua:103-104` | **MED-HIGH**: render-to-texture work and texture memory on the track | client GPU + memory |
| 6 | **Streaming freezes for fast runners**. Settings: `StreamingIntegrityMode = PauseOutsideLoadedArea`, `StreamingMinRadius = 64`, `StreamingTargetRadius = 1024`, `StreamOutBehavior = Opportunistic`. Runners go up to about 500 studs/s, and prefetch starts only at 250 studs/s | place: Workspace; `MovementGuard.lua:112-127` (prefetch, `:120`) | **MED-HIGH as felt** (a freeze, not a low frame rate). Not measurable offline | streaming / network |
| 7 | **Keepers**. Every keeper's motion and effects are stepped every frame at any distance (only the pose is distance-LOD'd). R152 models: 359 instances, 102 MeshParts (about 47k triangles over 8 models, Precise, no LOD), 36 emitters, 28 beams. 75–99 writes per frame for all 7 (R152) | `BeastAnimation.client.lua:121-233` (`:178` KFx.Step every frame, `:185` pose LOD); `KeeperMeshes152.lua:249` (Precise) | **MED**: mock 0.74 ms at the hub (all far), 3.1 ms next to one (the mock world has the place's saved keeper models; R152's own harness measured 2–4 ms on its mock for all 7) | client CPU + GPU |
| 8 | **Highlights**. Up to 24 pack Highlights on tiers 2–3 (12 on tier 1), up to 16 AlwaysOnTop weather glows (server), a rarity aura on every rare plant in detail (tier 2 too), owner mutation outlines, the giveaway (tier 3). Roblox draws at most 31 | `SeedPackRender.client.lua:337`, `WeatherService.lua:31-41` + `MutationGlow127.lua:4`, `PlantEffects.lua:67`, `MutationHighlights.client.lua:60` | **MED**: each Highlight is an extra pass over its object; past 31 they also stop showing (a visual bug) | client GPU |
| 9 | **Sun shadows** (`Technology = ShadowMap`, GlobalShadows on, softness .45 at run time). About 3,300 casters within 400 studs at the hub; 908 are tiny (under 1.5 studs), 681 of those in the market showcase | place: Lighting; `EnvironmentLighting.lua:34` | **MED** on phones that render shadows; Roblox drops shadows on low graphics levels | client GPU |
| 10 | **Post effects on phones**. Bloom (size 14, threshold 1.8) and SunRays run unless FastMode is on (the automatic tier drop does not turn them off), but SunRays' intensity is **0.008** (invisible). `PrioritizeLightingQuality = true` | `BiomeMood.lua:74` (Sun = .008), `:92` (only FastMode turns them off: `low` is the FastMode flag from `BiomePresentation.client.lua:28`); `EnvironmentLighting.lua:77-82` | **MED-LOW**: full-screen passes; the SunRays one draws nothing you can see | client GPU |
| 11 | **Transparency, Glass and Neon**. 983 semi-transparent drawn parts in the world (476 near the hub); 654 Glass (Frostland ice 324, treadmills 172, EnvironmentPolish 131); 1,200 Neon (the Void pack: 177 Neon, 71 transparent) | place `Obby/Biomes/Biome_3_FROSTLAND/CustomScenery`, `EnvironmentPolishV127`; treadmill art | **MED-LOW**: overdraw and sorting; Glass is heavier on high graphics levels | client GPU |
| 12 | **Garden detail budget is not lowered for phones**. 1,400 parts / 24 detailed plant models on tiers 2 and 3; only tier 1 gets 850 / 12. Rare plants also get a Highlight aura | `PlantDetailPlanner.lua:2`, `:17` | **MED-LOW** at full gardens | client GPU / CPU |
| 13 | **Periodic spike: pack refresh**. Every 300 s all 35 world packs are re-skinned in one server frame. The burst replicates to every client, and four workspace-wide DescendantAdded listeners plus the pack renderers react to each new instance | `ChestService.lua:626-632`, `SeedPackRules.lua:8`; listeners `BeastAnimation.client.lua:118`, `LavaFlow.client.lua:82`, `AudioMixer.lua:55`, `EconomyClient.client.lua:726` | **LOW-MED**: a hitch every 5 minutes (also when the keyboard window refills) | network + client CPU spike |
| 14 | **Hotbar / inventory 3D pictures**. Every visible icon is a ViewportFrame with the real 3D model (R137 removed the caps and the low-graphics swap), up to 10 in the hotbar | `ItemPictures.lua:13`, `:210` | **LOW-MED**: a small 3D scene per slot | client GPU |
| 15 | **Small server and network items**: treadmill popups `FireAllClients` 5 per second per training player (6 AFK trainers = 30 events/s to every client, plus a `PhysicalWalkSpeed` attribute and a leaderstat change each tick). The garden loop renders all 10 beds of a base every server frame (the `slot` argument is ignored, so it does 10x the work it means to) | `BaseService.lua:496`, `Config.lua:115`; `ChestService.lua:945` vs `:853` | **LOW** | network / server CPU |

Also checked and not a problem: see the appendix (lights, server replication, unanchored parts, EditableImages / EditableMeshes, emitters, data
stores, leaks).

---

## 2. Fixes, one per cost

Labels: **[same]** = nothing visible changes. **[far]** = only far or out-of-view things change. **[near]** = something visible up close changes.
Effort: **S** = under half a day, **M** = 1–2 days, **L** = 3 days or more.

### 1. Hub geometry (about 7,200 drawn parts near the plaza)
- **[far, M] Client-side distance LOD for the market showcase.** Build the 70 showcase models on each client, the same way HubLife151 already does,
  and skip them beyond about 200 studs on tier 3, 160 on tier 2 and 120 on tier 1. Today the server builds them, so every client always holds all
  2,186 parts. Same look at the market.
- **[far, S] Treadmill details by distance.** A base's treadmill dressing (`TreadmillDress151`, belt glass, neon trims) can be hidden beyond about 250
  studs on tiers 1–2 by the client (`TreadmillFx` already finds them). From your own base the others are 180+ studs away.
- **[near, S] CastShadow off on tiny parts** (largest side under 1.5 studs): about 900 near the hub, 681 in the showcase alone. Their shadows are a few
  pixels. See "bigger wins".
- **[near, L] Fewer parts per showcase model.** The market fruit uses part-built art; FruitMeshes149 bakes only 3 fruit as meshes. Baking the
  showcase fruit into meshes would cut it from 2,186 parts to a few hundred, but meshes shade slightly differently.
- **Studio:** no setting shrinks this. `StreamingTargetRadius` does not help at the hub (7,197 drawn within 400 studs against 7,664 within 1024).

### 2. Keycaps at Precise
- **[far, S] Studio (owner, 1 minute):** select `ReplicatedStorage.R142Keycap` and set **RenderFidelity = Automatic**. Every key is a clone, so the next
  Play uses it. Near keys look identical (full detail); far keys use Roblox's lower-detail versions.
  - First read the triangle count in the Command Bar:
    `print(#game:GetService('AssetService'):CreateEditableMeshAsync(Content.fromUri(game.ReplicatedStorage.R142Keycap.MeshId)):GetFaces())`
  - If it prints more than about 300, also upload a decimated copy with the same silhouette ("bigger wins").
  - Scripts cannot set RenderFidelity (Roblox refuses it), so this is a Studio-only change.
- **[far, S] Optional:** on tier 2, 74 → 56 rows ahead (keys end about 450 studs ahead instead of 600; the haze hides that range).

### 3. Hidden icon fallback strips (31k UI instances)
- **[same, S-M] `ArtworkRuntime87`:**
  - keep the one fallback template per icon kind (it is already built once, `e.Template`);
  - clone it into a holder only while that holder has no loaded image (`Artwork` or `UploadedArtwork` with `IsLoaded`);
  - destroy a holder's `SmoothFallback` once its image shows.

  When EditableImage is unavailable the fallback still appears exactly as today. Expected result: **PlayerGui about 38k → about 7k instances**.
  The join gets faster too: about 31k fewer instances are created.
- **[same, M] Build the big menus on first open** (premium shop 18k, index 7k, daily rewards 2k), or build them in time slices after load. The first
  open then costs a short build; with fix 3 they are small anyway.

### 4. Void giveaway pack
- **[same, M] Weld the pack's non-spinning pieces to its root and move only the root and the spinners.**
  - `VoidPackFx.Pose` places every piece at `hover × piece.Frame`, and that offset is fixed for all pieces except the galaxy / halo spinners.
  - So: weld those pieces to the root (Massless, no collision / touch / query), keep the root anchored, and move only the root plus the spinners each
    step.
  - The poses are the same numbers. About 200 CFrame writes per step become 1 plus the spinner count.
  - R152 declined welding the whole pack; this welds only the parts that never move relative to the bag. Prove it with the R152 fingerprint run
    (`ONLY=hub`).
- **[far, S] Step rate by distance:** 30 Hz within 40 studs, 15 Hz beyond (tier 3: 60 / 30). Also write the 90-part colour pulse at no more than 15 Hz
  beyond 40 studs. The 190-stud range stays.
- **[near, S] Phones:** on tiers 1–2, show the track's lighter Void pack (`VoidPackFx.Budget` already gives fewer debris and comets per tier) instead of
  all 190 pieces. See "bigger wins".

### 5. Keyboard letters
- **[far, S]** Far letters (4 px/stud) currently draw out to 800 studs (`FarMaxDistance`); 500 on tier 2 cuts far SurfaceGuis that are smaller than a
  pixel row anyway.
- **[near, S]** Near letters at 12 px/stud on tier 2 (16 today) cut the near canvas by 44%. The letters are a bit softer up close. See "bigger wins".
- **[near, L]** Letters baked into one texture atlas per biome, as Decals on the strips, instead of SurfaceGuis: no render-to-texture at all. R152
  ruled out merging rows of SurfaceGuis for the look.

### 6. Streaming freezes
- **Studio (owner):**
  - **`StreamingMinRadius` 64 → 192.** The ground ahead of a fast runner is always loaded. Trade-off: a little more memory; the radius only covers the
    track's width around the player.
  - Keep `StreamingIntegrityMode = PauseOutsideLoadedArea`. With a bigger minimum radius it should almost never trigger. `Disabled` would remove freezes
    but could let a runner reach unloaded ground, so it is not recommended.
- **[same, S]** Mark the track's ground and wall models Persistent (`ModelStreamingMode`, as `MysteryPackService` / `HubDisplayArt` already do for
  their models). Start the MovementGuard prefetch at 150 studs/s instead of 250 (`MovementGuard.lua:120`).
- **Studio, optional [far]:**
  - `StreamingTargetRadius` 1024 → 640 lowers phone memory on the track (2,050 drawn within 400 against 3,160 within 1024 at tier 2).
  - Set the big landmark Models' `LevelOfDetail = StreamingMesh`, so they show as low-detail stand-ins instead of vanishing. Lava landmark 629 parts,
    Crystal 187.
  - Trade-off: far scenery is simpler or loads later.
- **To confirm on a phone:** sprint the track; a "gameplay paused" spinner or a freeze followed by a jump means this item.

### 7. Keepers
- **[same, S]** Beyond 200 studs, where KeeperFx152 already turns every effect off (`KeeperFx152.lua:15` Range = 200), step `Motion.Update`, `KFx.Step` and
  `Fx152.Step` at 10 Hz instead of every frame. The pose LOD (`CosmeticBudget.KeeperDue`) stays. On screen nothing changes; at the hub all 7 keepers
  are past 200.
- **[far, M]** A decimated LOD model for each baked keeper (bake a second, coarser mesh; swap beyond about 150 studs). Meshes baked at run time get no
  Roblox LOD even with Automatic.

### 8. Highlights
- **[far, S]** Tier 2: `MAX_HIGHLIGHTS` 24 → 8 (nearest packs). The farther packs keep their BillboardGui aura (`DistantRarityAura`), so only a faint
  outline on far packs goes.
- **[same, S]** Count the server's weather glows (up to 16) and the plant auras in the same budget, so the total stays under Roblox's 31. Today it can
  exceed 31 during weather, and the extra ones silently do not draw.
- **[far, S]** Plant rarity auras only on the nearest 6 detailed plants on tier 2.

### 9. Sun shadows
- **[near, S]** CastShadow off for parts under 1.5 studs that scripts build: showcase fruit, HubLife pebbles and petals, fence caps, Crystal Wilds
  shards (233). See "bigger wins".
- **Studio:** nothing to change safely. ShadowSoftness is rewritten by `EnvironmentLighting` at run time (.45), and turning GlobalShadows off would
  change the whole look.

### 10. Post effects
- **[same, S] Studio (owner):** delete `Lighting.SunRays` (intensity .01; the game drives it to .008). `EnvironmentLighting` handles a missing SunRays
  (`EnvironmentLighting.lua:25-26`). This removes a full-screen pass that draws nothing visible.
- **[same, S] Studio:** delete the four post effects parented to **Workspace** (`Bloom` size 56, `SunRays` .25, `ColorCorrection`, `Blur`). Effects only
  render from Lighting or the Camera, so they do nothing today; deleting them is tidy-up, and it stops a heavy Bloom (size 56) from ever being moved
  into Lighting by mistake.
- **[near, S] Studio:** `Lighting.PrioritizeLightingQuality` true → false.
  - Roblox's description: it keeps lighting quality on weak devices instead of letting the engine scale it down.
  - Read its tooltip in Studio and compare on a phone emulator.
  - Trade-off: weak phones may lose shadow detail sooner.
- **[near, S]** Bloom off on tier 2 (today only FastMode turns it off). Phones lose the soft neon glow. See "bigger wins".

### 11. Transparency and Glass
- **[near, M]** Frostland's 324 ice pieces, the treadmills' 172 Glass parts and EnvironmentPolish's 131 to SmoothPlastic with the same transparency.
  They lose the glass sheen on high graphics levels. See "bigger wins".

### 12. Gardens
- **[far, S]** A tier-2 budget in `PlantDetailPlanner.Select`: 1,000 parts / 16 models (today phones get the PC budget of 1,400 / 24). Far plants switch
  to their simpler growth model sooner. See "bigger wins".

### 13. Pack refresh spike
- **[same, S]** Re-skin the 35 packs a few per frame during the 10 s closed window (`ConcurrentKeeperService:_updateBiomeRefresh` →
  `ChestService:SkinWorldSeeds`). The packs are behind the closed entrance then.
- **[same, S]** Narrow the four workspace-wide `DescendantAdded` listeners to the folders they care about. For example, BeastAnimation needs only
  `GuardianEncounters` and the event keeper; LavaFlow needs only the lava biome.

### 14. Hotbar 3D pictures
- **[near, M]** On tier 1, use a cached still image of each look. R137 removed this deliberately (the owner did not like the low versions), so it is
  listed only for completeness.

### 15. Server and network
- **[same, S]** Pass `slot` through to `RenderGarden` (or drop the per-slot loop): 10x less garden work on the server.
- **[same, S]** Batch treadmill popups: one `FireAllClients` per 0.2 s tick carrying every training player, instead of one per player.

---

## 3. Recommended R153 "do now" set: the look up close stays identical

| | Fix | Label | Effort | Expected effect |
|---|---|---|---|---|
| D1 | Studio: `R142Keycap.RenderFidelity = Automatic`, after reading its triangle count (Command Bar line in fix 2) | [far] | 1 min | Keycap triangles drop with distance; 2,288 / 3,605 keys stop drawing at full detail out to 600 studs |
| D2 | `ArtworkRuntime87`: no hidden fallback strips once an icon's image has loaded | [same] | S-M | PlayerGui about 38k → about 7k instances; less memory, faster join |
| D3 | Void giveaway pack: weld the fixed pieces, move the root + spinners; colour pulse and step at 15 Hz beyond 40 studs | [same] + [far] | M | About 290 → about 100 writes per step (the 90 colours stay near); the plaza's biggest script cost mostly goes |
| D4 | Studio: delete `Lighting.SunRays` and the four stray effects in Workspace | [same] | 5 min | One full-screen pass less on phones and PCs |
| D5 | Studio: `StreamingMinRadius` 192; code: track ground / walls Persistent, prefetch from 150 studs/s | [same] | S | Fast runs stop outrunning streaming (the "gameplay paused" freeze) |
| D6 | Keepers beyond 200 studs: motion / effects stepped at 10 Hz | [same] | S | Keeper script cost at the hub mostly gone (0.74 ms mock); on the track it costs only for the keeper you are near |
| D7 | Highlights: tier-2 cap 8 for packs, one shared budget under 31 | [far] | S | Up to 16 fewer Highlight passes on phones; no silent drop-outs during weather |
| D8 | Keyboard: far letters `FarMaxDistance` 800 → 500 on tier 2 | [far] | S | Fewer far SurfaceGuis drawn on phones |
| D9 | Server: pack re-skin spread over the closed window; garden loop renders one bed per call; treadmill popups batched | [same] | S | No 5-minute spike; 10x less garden work; 6x fewer popup events with 6 trainers |
| D10 | Workspace `DescendantAdded` listeners narrowed to their folders | [same] | S | Smaller spikes when the keyboard window refills or packs stream in |

**Correction (architecture review, R153 perf patch):** the garden half of D9 and cost #15's "renders a whole base each call" describe
`ChestService.lua`'s old `RenderGarden`, which never ran: `GardenPlantRuntime.Install` replaces it at load, and the live
`GardenPlantRuntime:RenderGarden` renders only the slot it is asked for. The never-run copy is gone (`perf153.md`). What was done of this list,
and how it was measured, is in `perf153.md`.

How to check the patch the R152 way: `run_perf152.sh` style fingerprints (identical near-field shots) for the hub (D3), keepers (D6) and keyboard (D8).
Also rerun `lag153_census.luau` (PlayerGui count for D2, writes per frame for D3 / D6). D1, D4 and D5 are Studio settings and need one Play test on a
phone or the device emulator.

## 4. Optional "bigger wins": these need the owner's OK (something visible changes)

| | Fix | What changes on screen | Effort | Expected effect |
|---|---|---|---|---|
| B1 | CastShadow off for script-built parts under 1.5 studs | Tiny shadow specks under small props (fruit, pebbles, petals, shards) go | S | About 900 fewer shadow casters at the hub (about 27% of them) |
| B2 | Market showcase built per client with distance LOD (fix 1), or its fruit baked into meshes | Showcase appears from about 200 studs; baked fruit shade slightly differently | M-L | Up to 2,186 fewer parts away from the market |
| B3 | Phones: keyboard near letters 12 px/stud; 56 rows ahead instead of 74 | Letters slightly softer; the far end of the keyboard starts about 150 studs nearer | S | Near canvas -44%; about 400 fewer keycaps on phones |
| B4 | A decimated keycap mesh (same silhouette), uploaded and set on `R142Keycap` | Rounded edges a bit less smooth up close | S (Studio) | Triangles scale down for every key, near and far |
| B5 | Phones: Bloom off on tier 2 | Neon glows less soft | S | One full-screen pass less |
| B6 | Glass → SmoothPlastic (same transparency) for Frostland ice, treadmill glass, EnvironmentPolish | Glass sheen / refraction gone on high graphics levels | M | Lighter transparent pass |
| B7 | Gardens: tier-2 budget 1,000 parts / 16 models | Far plants simpler sooner | S | Up to 400 fewer plant parts on phones |
| B8 | Phones: the Void giveaway pack at the track's tier budget (fewer debris / comets / pieces) | Less sparkle on the giveaway pack | S | Further cut of the plaza's per-frame cost |
| B9 | `StreamingTargetRadius` 640 + StreamingMesh LOD for the landmarks | Far track scenery simpler / later | S (Studio) | Lower phone memory on the track |
| B10 | Keyboard letters as texture atlases (Decals) instead of SurfaceGuis | Letter rendering changes (it can be made very close) | L | No SurfaceGui textures on the keyboard at all |

---

## Appendix A. Client frame handlers (tier 2, hub; from `LOOPS` / `LUAMS`, plus the code)

The 67 handlers connected at the hub, plus the ones that connect only on demand, grouped. "Mock ms" is per frame, from a solo tier-2 run. Every
handler not listed is under 0.05 ms.

| Script | Hook | Gating | Mock ms (hub / track) | Notes |
|---|---|---|---|---|
| VoidGiveawayClient152 | RenderStepped (on demand) + Heartbeat 2 Hz | within 190 studs; ViewCull when out of view; 30 Hz on tiers 1–2 | **5.2** / 0 | cost #4 |
| BeastAnimation | RenderStepped, every frame | pose LOD beyond 160 studs; motion and effects for every keeper every frame | **0.74** / **3.1** | cost #7 |
| KeyboardTrack | RenderStepped + bound camera step | writes only on change; running about 112 writes per frame (R152) | 0.54 / 0.05 | costs #2 and #5 are GPU, not Lua |
| GuiShine (module) | Heartbeat 20 Hz | up to 16 visible buttons | 0.15 / 0.09 | |
| RunnerController | bound input + PreSimulation + 2× PostSimulation + PreAnimation | always (own character) | 0.08 / 0.07 | |
| FruitOfHourDisplay | RenderStepped | spin only near; 2 Hz text | 0.09 / 0.01 | 11 writes per frame near |
| HubLife151 | Heartbeat 2 Hz + RenderStepped ambience (tier ≥ 2, within 150 studs) | cells by distance and tier | 0.04 | 12 writes per frame on tier 3 |
| WeatherWorld149, BiomeWeather, StormWeather, SnowBiome149, LavaFlow | Heartbeat / RenderStepped, 5–20 Hz | tier and distance budgets (R151) | ≤ 0.04 each | rain: 640 live particles on phones (R151) |
| SeedPackRender, SeedPackClient | RenderStepped (+ PreSimulation, PreAnimation) | selection at 4 Hz, polish 20–30 Hz, on screen and by distance | ≤ 0.01 here | the costs are its Highlights (cost #8) |
| GardenVisuals, DistantGardens, GardenLiftPrompts, PlantInspection, HeldHarvests | Heartbeat (some every frame) | plant planner budgets | ≤ 0.01 here (empty gardens in the mock) | real gardens: cost #12 |
| SpeedGainPopup, ChestRunAlert, KeeperHitEffects, PackOpeningFeedback (2 bound), BeginnerTutorial, MysteryPackClient, HubDisplayClient, TreadmillBonusClient, Hotbar, PurchaseCelebration, TravelButtons, MutationHighlights, OfflineGrowthNotice, VerityClient, VeiledEventClient81 | RenderStepped, mostly on demand (connected only while something is alive or near) | yes | ≤ 0.04 each | pooled (SpeedGainPopup within 100 studs) |
| about 25 more (HudNotices, HomeMarker, CarryNameplate84, BiomeAmbience, BiomePresentation, BiomeEffectGovernor, HideBushClient, GiantVisualSafety, ItemCosmetics, RunnerTrail*, TreadmillAnimation, WorldEvents, SettingsClient, ChaseMusicTrim152, InteractionFeedback, TrackHoleClient, GardenShovel, GardenBonusSign84, TreadmillFx, WorldStatusHud, ItemPictures, CollectionViewport, PackViewport89, NoticeFeed83, PlantingEffects, ClientFxBudget, DefaultCharacterAnimations) | Heartbeat or RenderStepped, nearly all with a 0.1–1 s accumulator | throttled | ≤ 0.04 each; about 0.4 ms together | each handler still costs a call per frame |

Two more client-side observations:
- **Startup map scans.** About ten client scripts walk `workspace` or the map with `GetDescendants()` once at start (BeastAnimation, LavaFlow,
  EconomyClient, GardenVisuals, BiomeEffectGovernor, GardenLiftPrompts, DistantGardens, PlantShovelPicker, WalkthroughProps90). That is about 150k
  visits at join, a one-off.
- **Leaks.** No per-event leak was found in the hot paths reviewed. Speed popups, notices, hit effects and the pull announcer pool or destroy what they
  make. Pack Highlights are destroyed with their records, and MutationHighlights cleans up its outlines and labels. This is a code reading, not a
  soak test. Watch Developer Console > Memory over a 30-minute session to confirm.

## Appendix B. Server loops and network

| Loop | Rate | Cost |
|---|---|---|
| ConcurrentKeeperService `_heartbeat` (replaces ChaseService's) | every frame | Per carrier: escape / death checks, keeper move (**only the root's CFrame replicates**), attack windows. Idle-keeper upkeep at 4 Hz with cheap checks (R130). Proximity to the chased player at 10 Hz (`FireClient`) |
| BaseService training | every frame | Per player: training / stabiliser. At 5 Hz per trainer: `SpeedGainPopup:FireAllClients`, a `PhysicalWalkSpeed` attribute and a leaderstat change |
| TrackHoleService | every frame | Swept segment check per carrier against the holes; cheap |
| Garden render loop (`ChestService.lua:937`) | every server frame | Renders a whole base each call because `slot` is ignored: 10x the intended work |
| MovementGuard | 10 Hz | Per player; streaming prefetch at 250+ studs/s |
| MysteryPackService, TreadmillBonusService, FruitOfHourService, StormService, WeatherService, BatService | 1 Hz / per frame (cheap) / 0.5 Hz / per frame (cheap) / 0.2 + 2 Hz / per frame (cheap) | Attributes written on change only |
| VoidGiveaway152, HubDisplayService, SocialService, SpeedBoardService, PlayerData autosave, PassGift / FruitGift | 2 s loop + MemoryStore poll 45–60 s / 5 s / 5 s / 60 s / 30 s / 15–60 s | Data-store work; does not touch frame time |
| Pack refresh | every 300 s | 35 packs re-skinned in one frame (cost #13) |

Server-side moving parts that replicate every frame: only active keepers' root parts (plus their `KeeperTravelSpeed` attribute in half-stud steps). Not
on the server: the mystery pedestal spin, the Fruit of the Hour, the giveaway pack, the displays' items, keeper limbs, the keyboard. All of those are
client-side.

`ServerStorage` holds about 115,000 instances of old backups (`SeedHeistScriptBackups` 85,832, map backups 8,148, …). They never reach clients, but
they cost server memory and load / publish time. Moving them to an archive place would help the server only.

## Appendix C. Lighting and streaming as found

Lighting in the place, with values the game changes at run time noted:
- Technology **ShadowMap** (3); LightingStyle 1; **PrioritizeLightingQuality true**; GlobalShadows true.
- ShadowSoftness .35 in the place, .45 at run time.
- EnvironmentDiffuse .70; EnvironmentSpecular .55 in the place, .35 at run time.
- Brightness 3; ClockTime 14.2 at run time.
- Fog 350–1200: ignored, because an Atmosphere is present.

Effects:
- **Two Atmospheres.** `ChestChaseAtmosphere` (density .18) is kept; the other is detached at run time.
- **Lighting.Bloom**: .18 / size 24 / threshold 1.5 in the place; size 14, threshold 1.8 at run time; off only in FastMode.
- **Lighting.SunRays**: .01, driven to .008 at run time.
- **ChestChaseColor**: contrast .1, saturation .08.
- DepthOfField is off.
- **In Workspace, inert:** Bloom 1 / size 56, SunRays .25, ColorCorrection, Blur (off).

Lights:
- **46–47 lights at run time** (35 pack glows, market lanterns, landmarks, displays, giveaway); **0 with Shadows on**.
- Under ShadowMap only the sun casts shadows, so the lamps, lanterns, Cloudy warm lamps and reveal lights cost a light each, never a shadow pass.

Streaming:
- **StreamingEnabled true**; TargetRadius **1024**; MinRadius **64**; StreamingAdaptiveRadius false.
- StreamOutBehavior **Opportunistic** (2): parts beyond the target radius stream out even with free memory.
- StreamingIntegrityMode **PauseOutsideLoadedArea** (3); ModelStreamingMode Default.
- `MysteryPackService` and `HubDisplayArt` already make their models Persistent. The client load guard waits for `game.Loaded`. Scripts look parts up by
  tag or name and wait, so the R152 code already copes with streaming.

What turning streaming off would mean: every client would hold the whole map at once, all 7 biomes included. That is about 2,900 more drawn parts
from the hub (those beyond 1024 studs), and every client would get the whole map before it could start. **Keep it on.** The fixes above tune it instead
(D5, B9).

## Appendix D. Checked and found fine

- **Unanchored parts:**
  - 105 pack lid parts (Transparency 1, no collision) are welded to anchored bodies.
  - 10 `LidLeftBand` parts have no valid weld; they fall once to `FallenPartsDestroyHeight` and are gone.
  - Nothing keeps simulating.
- **EditableImages:** icon art (one per kind), rare-pull scene art (≤ 256×256) and treadmill belt art (≤ 256×256). About 1–2 MB in all, made once
  per client.
- **EditableMeshes:** destroyed straight after baking (`FruitMeshes149`, `ApprovedPlantMeshes`, `PackShapes151`, `KeeperMeshes152`). The baked
  MeshParts stay, as intended.
- **Always-on emitters in the static world:** 8–11, rate sum 40–52 (landmarks). Weather, keeper and boot effects are budgeted by tier and distance.
- **Decals / Textures:** 127 (walls).
- **SurfaceGuis outside the keyboard:** 36, mostly signs at 50 px/stud, about 5.5 M canvas pixels in all (treadmill consoles, leaderboards, Storm
  Peaks signs). 20 of them have no MaxDistance; giving them one is a small, invisible win.
- **Client polling:** the tutorial at 1 Hz (only during the tutorial) and pending sale cash every 5 s.
- **Remote events:** KeeperHit, Bat, TrackHole, Storm, Veiled fire on events only.
- **R152's PropCache152 / ViewCull152** work as designed. What is left is counts and in-view work, which they were never meant to address.

## Appendix E. What still has to be measured on a device

Use Studio's device emulator, or better a real phone, with the MicroProfiler (Ctrl+F6) and Developer Console > Memory / Stats:

1. The `R142Keycap` triangle count (Command Bar line in fix 2), and the render triangle count on the track.
2. Frame time at the plaza looking at the giveaway pack, against looking away. The difference is cost #4.
3. Memory: the `Instances` and `Gui` categories before and after D2.
4. A fast sprint down the track on a phone: does "gameplay paused" appear? (cost #6)
5. GPU time at the hub on graphics levels 3 / 6 / 10, with shadows on and off (cost #9 against #1).
