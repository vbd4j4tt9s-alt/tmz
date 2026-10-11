# R149 review, part 1: correctness on live Roblox, and phone performance

Reviewer pass, findings only (no code changed). Scope: `git diff 766ec4d..5815c1a -- src tools`. That covers world weather and snow patches, the tiger gear, the fruit redesigns and the Ash Tomato variations, Verity's voice cut, lip sync and portrait, the yellow Verity pack, the keyboard rework and the installer chunking.
Not in scope: growth-style phase 1, baked melon / pumpkin meshes, the Prickly Pear revert, the z-fighting sweep and lifting the lightning ring / dirt bursts.

How each finding was checked:
- I read every changed file in full.
- These suites all pass on this commit: `run_keyboard` (314 checks), `run_all` (weather 173, snow biome 37, R128-R131, the R147 runner), `run_verity` (151 + 119 + 185 + 240), `run_verity_pack` (673), `run_tiger_gear` (505) and `run_fruit_models`. The fruit suite's file-list stage fails only because later R149 commits touched other files. Its regression diff, the 1411 checks and the floating check all pass.
- I added a small profiling harness: the real `KeyboardTrack.client.lua` on `tools/tests/roblox.luau`, with every property write counted per frame. Its numbers are below.

Labels used for each finding:
- **CONFIRMED**: shown by reading the code, by arithmetic, or by running the mock.
- **PLAUSIBLE**: depends on engine behaviour the mock cannot model. Each one says what to check in Studio.
- **live-only**: the mock passes, but live Roblox behaves differently.

## Ranked list

| # | Finding | Kind | Status | Severity | Live-only |
|---|---|---|---|---|---|
| 1 | Hiding the track floor with LocalTransparencyModifier stops it blocking the camera: looking up on the track, the camera sinks under the keyboard | correctness | PLAUSIBLE (high) | should-fix (blocker if seen in Studio) | yes |
| 2 | Turning the camera round rebuilds the whole key window in about 2 frames: 4,802 writes + 792 moves, then 2,340 + 704. On phones the Follow camera turns on every pack carry | perf | CONFIRMED (mock) | should-fix | no |
| 3 | Snow-biome patches sit 0.0-0.06 studs above an armed shovel hole and hide it (hidden trap) | correctness | CONFIRMED (heights) | should-fix | no |
| 4 | Keycap triangle budget: 1,958 keycap MeshParts on phones (R148: 450 + 1,500 twelve-triangle blocks). The mesh's triangle count and RenderFidelity are unknown | perf | PLAUSIBLE | measure before release | yes |
| 5 | Rain on phones: 1,268 live particles (R148: about 95), blizzard about 5x R148 | perf | CONFIRMED (suite numbers) | nice / should after measuring | no |
| 6 | Every snow patch is permanently translucent (0.04 / 0.06), so up to 290 discs are sorted and drawn one by one | perf | PLAUSIBLE | nice (free) | yes |
| 7 | Letter strips cause about 60% of the keyboard's writes while sprinting, many of them unchanged values; parked strips still draw | perf | CONFIRMED (mock) | nice | partly |
| 8 | Recycling a key writes Transparency twice (hide on release, show on bind) | perf | CONFIRMED (mock) | nice | no |
| 9 | `start()` hides the floor before the rest of the keyboard is built. An error later in `start()` leaves an invisible floor and no keys | correctness | CONFIRMED (order) / PLAUSIBLE (trigger) | nice (defensive) | no |
| 10 | Blueberry / Iceberry: 24 new translucent parts per plant (bloom 0.5, glint 0.25) | perf | PLAUSIBLE | nice | yes |
| 11 | `swapPass` creates and destroys a Part every frame forever if the keycap template stops cloning | correctness / perf | CONFIRMED (code path) | nice | no |
| 12 | Every key clone copies the template's own children, then destroys them | perf (join) | CONFIRMED | nice | no |
| 13 | Track overlays that are not `BiomeGround_n` now float in the 0.5-stud key gaps, 1.6 studs above the sunken bed | correctness (visual) | PLAUSIBLE | verify in Studio | yes |
| 14 | Feet vanish under the Snow edge / border patches (patch top 4.71, feet at 4.0) | visual | CONFIRMED | nice | no |
| 15 | Small items: `conns` growth, `Art.Key` loads art modules, `Config.Version`, GreetingEnd is a guess, fade cut on a tier change, stale avoid list, portrait redraws every frame, weather raycast while Clear | mixed | CONFIRMED | nice | no |

Checked and fine (details at the end):
- Save data is untouched: no ProfileVersion bump needed (it stays 22).
- `verityvoice` is owner / admin gated.
- PlaybackRegion / TimePosition usage is correct.
- The ViewportFrame has its CurrentCamera.
- No Studio-only property is written.
- Attribute types are valid.
- Key changes do not break the hotbar / Index caches.
- Installer chunking is correct.
- Pools are bounded.

---

## A. Correctness

### 1. The hidden floor no longer blocks the camera, so the camera can drop under the keyboard: live-only, PLAUSIBLE (high), should-fix

**Where:**
- `KeyboardTrack.client.lua:157` sets `part.LocalTransparencyModifier=1` on every `BiomeGround_n`.
- The keys, bed and rim are all `CanCollide=false` / `CanQuery=false`, via `flat()` at :76-79.
- The arena copy (`makePatch`, :133) is `CanCollide=false` too.

**Why:**
- Roblox's default camera occlusion (DevCameraOcclusionMode Zoom = Poppercam, PlayerModule `Popper.lua`) only treats a part as an occluder when three things hold:
  - its total transparency `1-(1-Transparency)*(1-LocalTransparencyModifier)` is under 0.25 (0.95 with the newer flag);
  - `CanCollide` is true;
  - a raycast can hit it.
- With LTM = 1 the floor's total transparency is 1, so it no longer occludes. Nothing else under the runner does either.
- In R148 the floor was visible, so the camera stopped at it.

**What the player sees:**
- Pitching the camera up on the track: at the default zoom of ~12.5 and a focus about 5 studs above the floor, that is any pitch above about 24°. The camera drops below y = 4.
- Between y 1.4 and 4 it sits inside the keys' bodies.
- Below 1.4 it looks up at the underside of the 180-wide bed, which covers the runner completely.
- The same happens in The Darkened's arena: the local copy does not collide and the real floor is hidden.

**Mock gap:** the mock has no camera module, so all 314 keyboard checks pass.

**Fix (minimal, keeps the look):**
- In `start()`, after the geometry is known, bind a render step right after the camera: `Run:BindToRenderStep('KeyboardCameraFloor', Enum.RenderPriority.Camera.Value+1, fn)`.
- In it:
  - read `cam.CFrame` once;
  - skip unless `cam.CameraType ~= Scriptable` (the pack opening uses Scriptable);
  - skip unless `|x-CX| <= HALF+2` and `geo.Z0-2 <= z <= KeyEndZ+150` (the end bound includes the arena);
  - if `y < K.KeyTop(0)+0.6`, set `cam.CFrame = cf + Vector3.new(0, minY-y, 0)`.
- Unbind it in `cleanup()`.
- Translating the camera keeps its LookVector, which is what the camera module reads next frame, so it is stable.
- Cost: one CFrame read and a compare per frame.
- The alternative, making the bed `CanCollide`/`CanQuery`, stops the camera at y 2.4, which is still inside the key bodies.

**Studio check:** stand on the track, pitch the camera fully up at the default zoom, then on a phone in the device emulator.

### 2. Snow-biome patches cover armed shovel holes: CONFIRMED, should-fix (gameplay)

**Where:**
- `SnowBiome149.client.lua:41`: `patchY = K.KeyTop(0)+Rise(.1)+thickness/2` puts the disc between 4.65 and 4.71.
- `TrackHoleService.lua:159-160`: Pit top = floor + 0.08, lifted 0.57 by the keyboard (`KeyboardTrack.client.lua:674`), so 4.65. The Rim top is 4.63.
- So every Snow-biome patch is drawn on top of a hole, nearly opaque (0.06) and white.

**Who it hits:**
- The border patches (whole width, the first and last four 15-stud rows past the spacebar, 45% per cell), the edge drifts (the outer 15 studs, 85%) and the dust (20%) hide pits there.
- An armed hole ragdolls a carrier and drops his pack (TrackHoleService header), so the trap becomes invisible.
- `readAvoid()` (:62-74) only avoids packs and keeper camps.

**Fix:**
- In the 1 Hz slow path (:125-137), also collect the `Pit` positions from `map._GameplayRuntime.TrackHoles` (same lookup as `KeyboardTrack.client.lua:657-664`), limited to z0-20 .. z1+20.
- Keep a signature; when it changes, drop bound patches whose `nearAvoid(x, z, Extent)` hits a pit (radius about 1.7 + 0.3 + 2).
- In `bind()` reject such cells without adding them to `skip`, so they come back once the hole is gone.
- Cost: a few distance checks per bind. Holes stay visible.

### 3. `start()` hides the floor before anything else is built: CONFIRMED order, PLAUSIBLE trigger, nice (defensive)

**Where:**
- `KeyboardTrack.client.lua:186` calls `scanGround()`, which hides every floor, right after the bed is built.
- The rest of `start()` follows: strips, keys, spacebars, sounds (:239-823).
- The RenderStepped connection is made at :821.

**Risk:**
- Any error in between leaves the client with an invisible floor and no keys for the session. `cleanup()` only runs on `script.Destroying`.
- Examples: a bad `Enum.Font` name in config, or a future edit.

**Fix:** move `scanGround()` to just before `table.insert(conns, Run.RenderStepped:Connect(step))`. Alternatively, run the body in `pcall` and call `restoreGround()` on failure. No visual change: keys appear the same frame.

### 4. `swapPass` churns a Part every frame forever if template clones start failing: CONFIRMED code path, nice

**Where:**
- `KeyboardTrack.client.lua:482-487` and `:393-401`.
- `template` is accepted once (:476-477). If it later returns nil from `Clone`, for example after `Archivable` is turned off, `swapSlot` builds a plain Part via `newKeyPart` (parented to `keyFolder`, :359), destroys it and returns.
- `plainSlot` never empties, so this repeats every frame.

**Fix:** on the first failed swap set `template=nil` (or a `swapFailed` flag) and stop calling `swapPass`.

### 5. Track overlays that are not `BiomeGround_n` float in the key gaps: PLAUSIBLE, verify in Studio

**What changed:**
- R148's bed sat 0.1 above the floor, so any thin part lying on the floor (y 4.0-4.5) was under the bed.
- R149 sinks the bed to y 2.4 and hides only `BiomeGround_n` (`:147`).
- Any other flat part on the track inside x ±90 (biome decals or overlay parts, puddles, scorch marks, trail ground marks placed by `RunnerTrailClient` on its floor raycast) now shows in the 0.5-stud gaps between keys as a layer floating 1.6 studs above the bed.

**Studio check:** fly low over each biome's track and look between the keys. If something shows, hide it the same way (by name / tag), or leave it for the z-fighting sweep.

### 6. Feet hidden in the Snow border / edge patches: CONFIRMED, cosmetic

**Where:** `SnowBiome149.client.lua:41`.
- The patch top is 4.71 while a runner's feet stand at 4.0. The keys sink under him, but the patch does not.
- Dust is hidden near the runner (`DustClear`), but border / edge blobs are not, so runners and keepers wade through them with their feet hidden.

**Possible fix:** hide (`Patches.Alpha(rec,1)`) any non-dust patch whose blob is within about 3 studs of a runner. The keyboard already samples runners: one shared helper, or leave it if the owner likes the "wading" look.

### 7. Small correctness items (all CONFIRMED, nice)

- **`conns` grows:** `KeyboardTrack.client.lua:160` adds a new `ChildAdded` connection each time a floor part streams back in. The disconnected one stays in `conns` (:171). It is small, but grows with every stream cycle of a 2,000-stud floor part. Remove it from `conns` on disconnect, or keep per-part connections in `rec` only.
- **Fade cut on a tier change:** `WeatherWorld149.client.lua:332` calls `setKind(kind,now)` on a tier change even when `kind=='Clear'` while the drops are still fading out. That sets `profile=nil` and cuts the fade. Guard it with `if profile and kind~='Clear'`.
- **Stale avoid list:** `SnowBiome149.client.lua:135-136` refreshes the avoid list only when the Seeds child count changes, and bound patches are never re-checked. It is harmless if Seeds are fixed spawn points; re-read on a 5 s timer if they can move.
- **`Config.Version`** is still `'V150 R148'` (`Config.lua:747`). That is release hygiene for whoever builds the installer.
- **Greeting cut is a guess:** `VerityConfig.GreetingEnd=1.9` is marked as a guess. If the clip says "Verity" later than 1.9 s, every greeting is cut mid-word until the owner runs `/test verityvoice`. Put this on the release checklist.

---

## B. Phone performance

### Measured cost of the keyboard (mock harness, tier 2 = phones, real client script)

| Situation | Property writes / frame | BulkMoveTo parts / frame | Notes |
|---|---|---|---|
| Standing on keys | 0 | 0 | nothing runs per key at rest |
| 60 studs/s | 34 avg (272 worst) | 4.4 | worst = a row change |
| 300 studs/s | 170 avg (290 worst) | 18 | 13 Color + 26 Transparency on keys; ~95 on letter labels |
| 1000 studs/s (the speed cap, `BalanceValues81.PointCurve`) | 490 avg (707 worst) | 51 | 44 Color, 88 Transparency; ~290 on letter labels (60%) |
| **Camera turns round** | **4,802, then 2,340** | **792, then 704** | 2,288 Transparency + 792 Color + 880 label writes in one frame |
| Turn, with fix B2 below | 1,722 / 1,020 / 792 ... | 198 per frame | ~8 frames; nearest rows still first |

Other per-frame Lua work on the keyboard is small:
- local press, ≤512 other footprints, the platform cell list;
- timers: clearances at 4 Hz (one `GetDescendants` per hole), others at 30 Hz, keepers and floor scan every 2 s.

On a mid phone I expect property writes to cost about 1-3 µs each plus the engine-side update. That means:
- a sprint at 300-1000 studs/s costs about 0.3-1.5 ms per frame;
- a camera turn costs one hitch of about 10-30 ms.

### 1 (B2). Camera turn = full window rebuild in 2 frames: CONFIRMED, should-fix

**Where:**
- `KeyboardTrack.client.lua:779` sets `turnBurst=true` on a flip.
- `:408-410` turns that into `budget=Bind*4` (792 keys on tier 2) and `relBudget=budget*4` (3,168), so all ~1,500 released keys are hidden in one frame.
- The window is Back 8 / Ahead 76, so a flip swaps about 68 rows.

**Why phones hit it:**
- On touch devices the default camera movement mode is Follow (PlayerModule `ConvertCameraModeEnumToStandard`: `TouchCameraMovementMode.Default` → Follow).
- So the camera swings round by itself whenever a runner turns to carry a pack back (-Z) and again on the way out. That is two hitches per round trip.

**Fix (measured on the mock):**
- Do not set `turnBurst` on a flip. Keep the 4x burst only for "rows within ±2 of the runner are missing" (teleports, :409).
- Set `relBudget=budget`.
- Optionally drop `Legend.RowsPerFrame` 8 → 4 (`KeyboardTrack.lua:55`).
- Measured: the worst frame goes from 4,802 writes + 792 moves to 1,722 + 198 (about 1,280 with RowsPerFrame 4), then about 800 per frame for ~8 frames.

**Look:**
- The released rows are behind the camera after the turn.
- New rows appear nearest first at 9 rows per frame, so the far end (~620 studs) fills within about 0.13 s, right after the 0.2 s `FacingHoldSeconds`.

### 2 (B1). Keycap triangle budget unknown: PLAUSIBLE, measure before release (live-only)

**Counts:**
- Tier 2 (phones) binds up to `KeyCap = (8+76+1+2·2)·22 = 1,958` clones of `R142Keycap` (3,146 on tier 3, 1,232 on tier 1).
- R148 tier 2 drew 450 keycaps + 1,500 twelve-triangle blocks.
- Draw calls stay low because identical MeshParts are GPU-instanced and per-instance Color is fine.
- Triangles scale with the mesh: 1,958·N minus LOD. At N = 500 that is about 1M triangles at full detail, too much for low-end phones. At N = 150 it is about 0.3M, fine.

**Who decides LOD:**
- Clones inherit `RenderFidelity`, which game scripts cannot set (the mock correctly errors).
- So if `ReplicatedStorage.R142Keycap` is `Precise`, the far rows (out to 620 studs) are drawn at full detail.

**Check in Studio:**
- Select `R142Keycap` and confirm `RenderFidelity = Automatic`.
- Read its triangle count: Command Bar `#game:GetService('AssetService'):CreateEditableMeshAsync(Content.fromUri(game.ReplicatedStorage.R142Keycap.MeshId)):GetFaces()`.
- Check the MicroProfiler / Stats render triangles on a phone emulator.

**If N is high, look-preserving options in order:**
1. Upload a decimated copy of the same keycap (same silhouette) and set it on the template in Studio.
2. Trim tier 2 `Ahead` 76 → ~60, which is where Atmosphere haze already hides most keys.
3. Make far rows (beyond ~40 rows) a box of the keycap's exact size and colour. This contradicts the owner's "one look", so ask first.

### 3 (B3). Rain / blizzard particle counts on phones: CONFIRMED numbers, nice / should after measuring

**Numbers:**
- `test_weather` reports the worst-case live particles for tier 2 Rain / Thunder: 1,268 (cap 1,300, splashes included); tier 3: 3,120.
- R148's camera bubble on mobile was `min(rate,90)` × 1.05 s, about 95 rain drops, or about 252 snowflakes.
- So rain on phones is about 13x and blizzard about 5x R148. This is inherent in moving from a camera bubble to world tiles. Ripples are 2.4-stud smoke quads near the ground (overdraw).

**Fix if the MicroProfiler shows particles on a phone:**
- `WeatherWorld149.lua:64`: tier 2 `Cap` 1300 → ~800, and optionally `SplashMin` .6 → .8 (splashes only right around the player).
- About 40% fewer particles. The density near the player goes from 0.055 to about 0.034 per square stud.

### 4 (B4). Snow patches are always translucent: PLAUSIBLE, nice (look unchanged)

**Where:**
- `WeatherWorld149.lua:205` `Patch.FinalTransparency=.04`.
- `:266` `Biome.FinalTransparency=.06`, also used for Snow-biome edge / border patches at bind (`SnowBiome149.client.lua:102`).
- So up to 170 (biome) + 120 (weather) Cylinder discs on tier 2 are drawn translucent forever, every one in the sorted transparent pass instead of instanced.

**Fix:**
- Set both final transparencies to 0. Weather patches stay translucent only while fading (`PatchTransparency(level<1)`).
- 4-6% transparency over white is invisible.
- All lobes of one patch share one colour, so overlaps that touch cannot show a seam.

### 5 (B5). Letter strips: most of the sprint writes, and parked strips still drawn: CONFIRMED (mock) / PLAUSIBLE (render), nice

**Where:**
- `bindStrips` (`KeyboardTrack.client.lua:302-326`) rewrites Position, Text, TextColor3 and Visible on all 11 labels, plus strip CFrame / Size, for every strip it binds.
- `stripAlpha` rewrites 11 TextTransparency values for each strip in the fade band on every row change.

**Fixes:**
- Skip a write when the value is unchanged:
  - `Position` depends only on the strip slot `k` and row depth, so it is almost always the same;
  - ink is one of two colours per zone;
  - `Visible` is usually true.
  - About 90-130 fewer writes per frame at 1000 studs/s. Every TextLabel change re-renders its whole 1440×131-px SurfaceGui.
- `releaseStrips` (:327-331) parks strips at y −196 with their SurfaceGui still enabled. From the base they are within `MaxDistance` 420. Set `st.Gui.Enabled=false` on park and `true` on bind.
- Optional: `Legend.PixelsPerStud` 16 → 10 halves the strip texture area (TextSize 74 → 46; letters are seen from 5+ studs). This is a small look change.
- Spacebar guis (:458-459) have no `MaxDistance`. Setting about 800 is invisible in play.

### 6 (B6). Every recycled key writes Transparency twice: CONFIRMED (mock), nice

**Where:** `releaseRow` (:386) writes `Transparency=1`, then `bindRow` (:375) writes `Transparency=0` on the same pooled slot, usually in the same frame (LIFO pool).

**Fix:**
- Keep a `shown[s]` flag.
- Do not hide on release.
- At the end of `windowPass`, hide only the free slots that are still shown.
- Write `Transparency=0` in `bindRow` only when the slot was hidden.
- About 26 → 13 key writes per frame at 300 studs/s, 88 → 44 at 1000, and about 1,500 fewer in a camera turn.

### 7 (B7). Blueberry / Iceberry translucency: PLAUSIBLE, nice

**Where:**
- `PlantArtForest.lua:136-200` (`BluebellSeed`) and `PlantArtSnow.lua:142-206` (`IceberrySeed`).
- 12 "Berry bloom" balls at t=0.5 and 12 "Berry glint" Neon at t=0.25 per plant. Before: 0.
- A garden of 20 berry bushes adds about 480 sorted transparent parts. The glints are `decor` and are already hidden on Gold / Diamond.
- Other fruit only add 2-4 translucent gloss parts each. Part totals mostly drop: Watermelon −48, Snow Melon −30, Elder −35, Pear −15, Apple +12, Pumpkin +6, berries +4.

**If a berry garden shows in the MicroProfiler:**
- Make the bloom opaque with the blended colour (about 107,123,196): one opaque part instead of one translucent.
- Or make the glints opaque Neon.
- Either is a small look change, so it needs the owner's approval.

### 8. Join-time: template children cloned 1,958 times: CONFIRMED, nice

`newKeyPart` (:352-361) clones the template with all its children (the toolbox keycap's SurfaceGui / TextLabel / Script, if any), then `stripPart` destroys them, for every pooled key.

**Fix:** clone once, strip that copy, and use it as `template`. This cuts join and teleport-burst CPU. Keys are created only once per session.

### 9. Other cheap items (CONFIRMED, nice)

- **Weather while Clear:**
  - `WeatherWorld149.client.lua:356-359` raycasts every 0.1 s even when Clear.
  - `W.Area` reads 15 map attributes every step (:353).
  - Skip both when `profile==nil and boundN==0 and not W.Active(events,now)`. That is about 10 raycasts and 150 attribute reads a second.
- **`Bases.DescendantAdded`** (`WeatherWorld149.client.lua:210`) runs a string match for every garden part that streams in. Use `ChildAdded` on each base, or rescan on a timer only while snowing.
- **`ApprovedPlantArt.Key`** (`ApprovedPlantArt.lua:33`) now `require`s the full art module (up to 100 KB) of any approved plant the first time its key is asked for, only to count designs. Use a small static table, `{AshRoseSeed=4}`, defaulting to the old key.
- **Verity portrait:** `portraitFrame` (`VerityClient.client.lua:375-392`) writes the ball's CFrame every frame while the window is open, so the ViewportFrame re-renders every frame on phones that show the portrait (window ≥ 560×330 px). Bob at 30 Hz, or only while she talks.
- **Desktop pool:** a tier drop 3 → 1 leaves up to 1,914 hidden key parts in the pool (`made` never shrinks). Memory only; phones start on tier 2 and cannot go up.

---

## C. Checked and fine

- **Save data:** R149 changes no saved field and no catalog, odds or value. Crop ids are unchanged and the Ash Tomato design comes from `hash(crop.Id)`. **ProfileVersion 22 needs no bump**, and R148 / R149 servers can coexist.
- **`verityvoice`:**
  - Gated by `Access.Publish` / `Access.IsAllowed`: owner, group owner or server-authored `AdminUserIds`; anyone in Studio.
  - Rate-limited to 0.35 s per caller.
  - Global (an `@target` is refused).
  - It only writes `VerityVoiceStart` / `End` (numbers, clamped by `VerityVoice.Region`) on her Persistent model and fires `'Greet'` to the caller.
  - The server's `OnServerEvent` still accepts only `'Give'`.
- **Sound:**
  - `PlaybackRegionsEnabled` + `PlaybackRegion`, then `TimePosition=start` before `Play()`, is correct: Play starts from the last scripted TimePosition.
  - The end is caught three ways: `Ended`, `TimePosition ≥ Stop`, and the `Until` timer.
  - `PlaybackLoudness` is read on the client only.
  - The fallback rhythm covers a sound the engine will not measure.
- **ViewportFrame:** the portrait Camera is parented into the frame and set as `CurrentCamera`. Decals and SpecialMesh render in viewports.
- **No Studio-only writes:** no `CollisionFidelity`, `RenderFidelity`, `MeshId` or `TextureID` write anywhere in the diff. `SurfaceGui.MaxDistance` is written in a `pcall`.
- **Attributes:** all bool / number / CFrame.
- **Keys:** `ApprovedPlantArt.Key` gains `d<n>` only where `10 % n ~= 0` (only the Ash Tomato). Every consumer (`ItemPictures`, `PlantVisuals.styleKey`, `HologramForms`) treats keys as opaque strings, and the Key and Get design choices agree.
- **Bounded pools:**
  - keyboard slots ≤ KeyCap per tier, strips, key-letter guis (≤ KeyLegends), 12 voices;
  - weather tiles ≤ 25; patch discs ≤ the tier budget;
  - `rejected` / `skip` ≤ 4,000;
  - the events list ≤ 8;
  - `gates`, `liftBase` / `liftSet` and `hooked` are weak tables.
- **Streaming:**
  - Floors that stream in are hidden at once (ChildAdded on the map / biomes / each biome model, plus a 2 s rescan), and their late Decals / Textures too (per-part ChildAdded).
  - Floors that stream out drop their arena copy.
  - Hole parts that stream in are lifted (DescendantAdded).
  - Verity's model is Persistent.
  - The keeper rig waits for a complete stream before the gear is fitted.
- **Installer:**
  - `storeText` / `loadText` cut at 99,999 bytes on UTF-8 boundaries and refuse missing / duplicate / short pieces.
  - Old single-value backups still load.
  - `PlantArtForest.lua` (101,911 bytes) will take the chunked path.
- **Tiger gear:**
  - 38 client-only anchored parts, moved inside the existing pose LOD (`KeeperDue`).
  - The 16 studs / facets hide beyond 140 studs and in low graphics.
  - About 80 CFrame products per pose frame, which is negligible.
  - Glass falls back to plain translucent at phone quality levels.
- **Verity pack:** 9 opaque parts plus the ordinary seal / strips; no effects any more (VoidPackFx / VeiledEventClient81 / SeedPackRender all skip it).
- **Lip sync:** runs only while she talks or is closing her mouth, within `AnimateDistance` 300 or while the portrait is open, and not under ReducedMotion. That is 4-6 guarded writes per frame for about 2 s.
