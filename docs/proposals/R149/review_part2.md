# R149 review, part 2: growth style, baked fruit meshes, z-fighting, fix round A

Reviewer pass, findings only (no code changed). Scope: `git diff 5815c1a..HEAD -- src tools` (HEAD = `bc29fbb`). That covers:
- the z-fighting sweep (MarketLayout, BiomeVisuals treadmills, GardenFenceArt, TrackHoleService, VerityService, the new ZFightFix149 and its MapService hook);
- the lightning ring / dirt burst lift (KeyboardSurface149, StormWeather.client, TrackHoleClient);
- growth style phase 1 (PlantGrowth rewrite, PlantGrowthFx, HarvestArrival, PlantAnimationBatch, PlantingEffects, GardenVisuals, Hotbar, EconomyClient);
- fix round A (`b4f851d`: KeyboardTrack*, SnowBiome149, SnowPatches149, WeatherWorld149*);
- the baked fruit meshes (FruitMeshes149, the PlantVisuals and ApprovedPlantsBootstrap hooks) and the Prickly Pear revert.

Part 1 (`review_part1.md`) covered `766ec4d..5815c1a`. `tools/` has no change in this range.

How each finding was checked:
- I read every changed file in full, plus the callers they touch: GardenPlantRuntime, DistantPlantView, ApprovedPlantMeshes, ApprovedFruitEffects, GardenInventoryState, HarvestToolService, PlayerDataService.HarvestPlant, BiomeVisuals V134 / V136, TrackExpansion83 and the z-fight detector.
- These suites pass on `bc29fbb`:
  - `run_growth` (35 + 136 + 1,730 + 114 + 44 + 24 checks, 0 new floating parts in 168 scenes, write benchmark x4.2 - x1,265 fewer);
  - `run_keyboard` (381; a camera turn now costs at most 551 writes + 198 moves in one frame, was 4,802 + 792);
  - `run_weather` (192 + 63 + 41);
  - `run_zfight` on the owner's place (273 fixer checks, 25 of 25 parts moved, 0 findings left that are ours).
- `run_fruit_models` passes every stage (regression diff, fallback, 1,442 checks) except one case of `test_fruit_mesh_fallback` (the garden case). That failure comes from the test harness, not the game: see finding 9.
- I added three scratch probes on the mock. They are not committed and are described where they are used:
  - the real Hotbar with a harvested fruit of the same plant and fruit slot;
  - the cost of `PlantGrowth.Capture` per plant (near detail and server silhouette);
  - the remaining z-fight findings, listed with `tools/zfight.py`.

Labels used for each finding:
- **CONFIRMED**: shown by reading the code, by arithmetic, or by running the mock.
- **PLAUSIBLE**: depends on engine behaviour the mock cannot model. Each one says what to check in Studio.
- **Live gap**: yes when the mock passes but live Roblox can behave differently.

## Ranked list

| # | Finding | Kind | Status | Severity | Live gap |
|---|---|---|---|---|---|
| 1 | HarvestArrival hides EVERY tool from the same plant and fruit slot, not just the new one. An older fruit of that slot leaves the hotbar during the flight and loses its slot for good (a bag item takes it). The held fruit vanishes from the hotbar and the selected label | correctness / UX | CONFIRMED (mock, real Hotbar) | should-fix (high; one-line fix) | no |
| 2 | The new leaf-link pass (#5) makes `PlantGrowth.Capture` 10-70x dearer and runs on every Capture: client near detail, client distant gardens and **server** silhouettes. Worst plant about 94 ms on the mock (base 1.6 ms); native estimate 10-20 ms on desktop, 30-80 ms on a phone, in one frame | perf | CONFIRMED (op counts) / PLAUSIBLE (native ms) | should-fix | yes |
| 3 | Hole Rim made thinner (.06 -> .04): the keyboard's letter strips are now only .03 under a lifted hole's rim top (detector: `far`) | z-fight (new) | CONFIRMED (geometry + detector) | nice | no |
| 4 | KeyboardTrack RimEnd top .02 under LobbyFloor (z -100.3) and under the arena GroundPatch (z 5860.3) | z-fight | CONFIRMED | nice | no |
| 5 | Ash Tomato "Flat ash patch" top only .0131 above the "Squared ash tomato" top (.0095 in the market) | z-fight (old, R148 too) | CONFIRMED | nice | no |
| 6 | Amethyst "Harvest form" coplanar shaft tops / bottoms | z-fight | false positive (CONFIRMED by geometry + detector code) | none | no |
| 7 | Ember Pumpkin mesh: the unripe tint multiplies orange vertex colours, so a young pumpkin stays dark orange. There is no pale unripe look, unlike the part-built fruit; the melons are fine | look | CONFIRMED (arithmetic) / PLAUSIBLE (multiply on live) | nice (owner's call) | yes |
| 8 | Arrival flash after fix 1: the released key is consumed by whichever tool of that plant and slot is met first, so the flash can land on the older stack | UX | CONFIRMED (code) | nice | no |
| 9 | `run_fruit_models.sh` pins the base PlantGrowth next to the new GardenVisuals, so the garden case fails on `Growth.StateOf` | test harness | CONFIRMED (passes 7/7 with the real PlantGrowth) | nice | no |
| 10 | MarketLayout `clearTops` walks the whole market (about 2,200 parts) once per showcase model (about 70) at server start | perf (start-up) | CONFIRMED (code) | nice | no |
| 11 | Small items: fig / ember fruit lose their Neon coat mid-flight; `Growth.Batch` stays set for a frame after a failed step; V134 / V136 undo would refuse moved parts; snow-biome patch step .008 (contrast 5) | mixed | CONFIRMED | nice / none | no |

No blocker found. Save data is untouched (ProfileVersion 22). The EditableMesh route is the one ApprovedPlantMeshes already runs live. Section D lists everything checked and found fine. Section E gives the status of the part-1 findings.

---

## A. Correctness

### 1. The inventory hold hides older fruit of the same plant and slot: CONFIRMED, should-fix (high)

**Where:**
- `Hotbar.client.lua:298`: `if tool:IsA('Tool')and not Arrival.Holds(tool)then`.
- `HarvestArrival.lua:15-18`: the hold key is `SourceCropId:FruitIndex`.
- `HarvestArrival.lua:50-54`: `Holds`.

**Why:**
- The server stamps `SourceCropId = crop.Id` and `FruitIndex` on every harvested tool (`PlayerDataService.lua:1566-1571`, `HarvestToolService.lua:35`).
- A regrowing slot therefore produces one tool per harvest with the **same** key. While the new fruit flies (up to 1.5 s), every older tool of that plant and slot is hidden as well.
- `GardenInventoryState:Reconcile` (`GardenInventoryState.lua:6-11`) frees the slot of a key that vanished, then fills free slots with unassigned stacks. When the bag holds more stacks than the hotbar shows, a bag-only item takes that slot.
- When the hold ends, the old stack and the new one have no slot left and stay in the Bag only.

**Mock run (the real Hotbar and HarvestArrival):**

| Moment | Hotbar slots 2-3 | Selected label |
|---|---|---|
| Before (two older apples of plant-A slot 1, the bag fuller than the hotbar) | Apple, Apple | |
| Equip one of the apples | Apple, Apple | `Apple (4kg)` |
| During the flight | Bananas, Pineapple | `""` |
| After landing | Bananas, Pineapple (no apple on the hotbar) | |

**Who it hits:** anyone who keeps fruit and re-harvests the same plant. This is the normal multi-harvest loop, and players arrange their hotbar by dragging.

**Fix (one line, verified):**
```lua
-- Hotbar.client.lua:298 - a tool that was already shown is never held back again
if tool:IsA('Tool')and(seen[tool]or not Arrival.Holds(tool))then
```
- With it, the probe keeps both apples on slots 2-3 during and after the flight, and the selected label stays.
- `test_growth_hotbar` still passes (24 / 24).
- A tool rebuilt on respawn is a new instance and could be held for at most 1.5 s; that is harmless.
- Finding 8 refines the flash.

**Not affected** (checked): data, selling (server list), gifting, planting and the Bag of other players. A hold always ends at its deadline (`watch` / `task.delay`). A failed request releases without a flash.

### 2. Leaf-link pass on every Capture, including the server: CONFIRMED op counts, PLAUSIBLE native cost, should-fix

**Where:**
- `PlantGrowth.lua:286` calls `link()` (`:158-217`) for every non-frozen Capture.
- `link` tests every foliage part against every part within the sum of their half-diagonals. Each candidate pair runs `contact()`: 15 sample points each way, so 30 `boxGap` calls with 1 subtraction and 3 `:Dot` each.
- Capture runs from:
  - GardenVisuals near detail (`BuildGrowing`, inside the build job but not time-sliced);
  - `DistantPlantView.lua:26` (every growing plant of every distant garden);
  - the **server**: `GardenPlantRuntime:BuildGrowthModel` -> `Visuals.Supports` -> `GrowingSupports` -> `BeginGrowth` (`PlantVisuals.lua:596 / 604`), once per growing plant model.

**Measured on the mock** (scratch probe `bench_capture*.luau`, the real modules):

| | Base Capture | New Capture | Link tests |
|---|---|---|---|
| Frost Fern (171 parts, near detail) | 1.6 ms | 95.9 ms | 2,211 |
| Monstera / Desert Aloe / Aloe | 0.7 - 1.7 ms | 69 - 72 ms | 1,800 - 2,300 |
| 58 plants in all | 84 ms | 849 ms | |
| Server silhouettes (`Supports`, stage 2) | | 1,104 ms over 58 plants, incl. build | 11,511 (worst Desert Aloe 1,794) |

**Native estimate:**
- One mock `(a-b):Dot(b)` costs 0.45 µs.
- Natively, a Vector3 subtraction plus a `:Dot` namecall is roughly 0.05-0.1 µs, so `contact()` costs about 8-10 µs.
- That gives about 20 ms on desktop for the Frost Fern, and 3-4x that on a phone, in ONE frame each time a growing plant comes into detail.
- The server pays about 2 ms per growing plant on average and 15 ms for the worst species, each time a player joins with a growing garden.

**Fix, in order of gain:**
1. Server silhouettes and `DistantPlantView` skip `link`. They take the existing `G.PlainLeaves` branch (`:165`: `LeafStart` per foliage, no contacts), with an option flag passed through `Visuals.BeginGrowth(model,id,crop,origin,{Plain=true})`.
   - The leaf grow-out look cannot be seen at those distances.
   - Gain: 100 % of the server cost and of the distant-garden hitches.
2. Near detail: pass the build job's `work` down (`Build` -> `BuildGrowing` -> `BeginGrowth` -> `Capture`) and call `work.BeforePart(1)` every 32 `contact()` calls. The job already yields per part budget, so a 20-80 ms hitch becomes 1-2 ms slices.
3. Optional, about -40 % on top: use 9 samples instead of 15 (centre and corners), and replace the half-diagonal sphere pre-test by a plant-space AABB overlap (leaves and stems are long and thin).

**Studio check:** MicroProfiler label `debug.profilebegin('PlantGrowth.Capture')` around `link`; walk into a garden of Frost Ferns, Aloes and Monsteras on the phone emulator.

### 7. Ember Pumpkin mesh: unripe tint cannot read as unripe: CONFIRMED arithmetic, nice (owner's call)

**Where:** `PlantGrowth.lua:26` and `:256`. A MeshPart fruit's unripe colour is `Part.Color x MeshTint (222,240,176)`, on top of the vertex colours.

**Why:**
- Multiplication can only darken a channel.
- The pumpkin's orange `(240,120,34) x .87/.94/.69 x .95` gives about `(198,107,22)`, a slightly darker orange; the path to ripe is just a small brightening.
- The melons (green vertex colours) do read as pale and unripe.
- The part-built fallback pumpkin goes through `G.Unripe`, which is pale green. A server whose bake fails therefore draws the pumpkin differently while it grows.

**Options:** accept it (it is cosmetic), or keep the pumpkin on the plain blend from its tone. A real "green to orange" path needs the `_Neutral` twin while unripe, which is not worth the cost.

**Live gap:** this assumes the engine multiplies Part.Color with vertex colours. The cocoa pod's Gold / Diamond coats on the white-vertex `_Neutral` twin already depend on that live. If it does not multiply, the tint simply has no effect, which is harmless.

### 8. Arrival flash target: CONFIRMED (code), nice

**Where:** `Hotbar.client.lua:301`: `released[ToolKey]` is consumed by the first tool with that key in `GetChildren()` order.

**Why:** with fix 1, older tools of the plant and slot are listed too, so the flash can go to the old stack's slot.

**Fix:**
- Take `local isNew=not seen[tool]` before `seen[tool]` is assigned.
- Consume the key only `if arrival and isNew`.

### 11. Small items (all CONFIRMED, nice or none)

- **Fig / Ember fruit effects mid-flight:**
  - `ApprovedFruitEffects` coats the Emberfruit core Neon and keeps references to it. The flight takes the core away, and `clearEffects` runs when the rebuild job finishes, restoring the core's Colour and Material mid-flight. That is a colour snap of about 1 frame on 2 species.
  - The wisps and embers follow the flying core, which looks fine.
  - Fix if wanted: `PlantGrowthFx.Eligible` skips `MirageFigSeed` and the Ember style, or `Harvest` restores the coat first.
- **`Growth.Batch`** (`GardenVisuals.client.lua:237 / 281 / 319`): an error inside the animation step leaves it set until the next Heartbeat. Another script's `UpdateGrowth` in that frame would queue into `animationBatch`, flushed 1/20 s later. It is harmless and already reset at the top of Heartbeat.
- **V134 / V136 undo** (`BiomeVisuals.lua:1570`, `:1804`): they compare the recorded "After" CFrames with a tolerance of .001, so after ZFightFix149 an undo would refuse the 25 moved parts. Nothing in `src/` or `installers/` calls undo, so this is only a note for anyone who does.
- **Snow-biome patches:** two patches with `BiomeStep` .004 x 2 apart are flagged `near` (.008) at contrast 5 (white on white). No visible flicker.

---

## B. Phone performance

| Item | Cost | Verdict |
|---|---|---|
| Growth writes (#1) | `run_growth` bench, one growing plant under the real GardenVisuals: Watermelon 17,200 -> 2,098 writes/s still (4,111 with sway); Ash Tomato 14,140 -> 22; Amethyst 99,960 -> 46. A skipped Apply allocates nothing (test_growth_writes) | big win |
| Sway while growing (#2) | the same 6 models / 600 parts wind budget as ripe sway; one batched move per visible part per motion tick | fine |
| Skipped Apply, every near plant at 20 Hz | `Progress` for the body + each fruit, `FruitReady`, the sprout check: about 10 µs a plant, so 40 plants cost about 0.13 ms a frame | fine |
| Capture (#5 link) | finding 2: 20-80 ms phone hitch per growing plant entering detail; server about 2 ms per plant on joins | **should-fix** |
| Harvest flight | at most 8 / 200 parts (5 / 120 on phones); one `StepFrame` per Heartbeat, no-op when idle; Size every other frame + one BulkMoveTo. One closure per frame while flying (`pcall(function()...)`) | fine (the closure could be a named local) |
| Ripe bounce + glints | ≤ 4 fruit / 120 parts, 4 pooled emitters, ≤ 6 cues per 2 s | fine |
| Hotbar flash | a RenderStepped connection only while a flash lasts (0.32 s), disconnected after | fine |
| Keyboard | turn worst frame 551 writes + 198 moves (was 4,802 + 792); sprint at 1,000 studs/s: 294 writes a frame; camera clamp: 1 CFrame read a frame | fixed (part-1 B2) |
| Weather while Clear | early return (no raycast, no area read); area re-read only on `AttributeChanged` | fixed |
| Server bake | 6 meshes (242-258 vertices) in 6.4 ms of Luau on the mock + 2 async calls + about 4 `task.wait` each, so well under 1 s. The market showcase waits for it in its own `task.defer` thread, not in MapService. Memory: 6 tiny templates; the EditableMeshes are destroyed | fine |
| Mesh triangles | ≤ 512 a fruit (Precise), ≤ 1,024 a plant; the plants lose 14-40 parts | fine |
| MarketLayout `clearTops` | finding 10 | nice |

### 10. `clearTops` scans the whole market per model: CONFIRMED (code), nice

**Where:** `MarketLayout.lua:247-272`.

**Cost:**
- For each showcase model (about 70: counter crates, stands, planters, flower boxes, pots, lanterns, packs), `market:GetDescendants()` enumerates about 2,200 parts. The count grows as the showcase fills.
- It builds a box for every part outside the showcase: about 260 market-structure parts.
- In all that is roughly 150k `IsDescendantOf` calls and 18k box allocations, in one deferred thread at server start: an estimated 20-60 ms.

**Fix:** compute the structure boxes once per `Apply`, lazily on the first `clearTops`, excluding the `MarketShowcase` folder. Each model then tests only those 260 boxes.

---

## C. Remaining z-fighting

The data comes from `tools/zfight.py` on `run_zfight`'s `after_start` / `after_snow` scenes, listed with the scratch helper. Detector thresholds:
- `near` ≤ .02;
- `far` < max(.02, 4.77e-7 x D²), with D = 64 x the overlap's short side (≤ 300);
- every proposal below lands at least 2x past those.

### 6 (C1). Amethyst "Harvest form" shaft tops / bottoms: false positive, no change

**Detector finding:** 27 pairs. `Harvest form.Top <-> Harvest form.Top`, coplanar, area .11, contrast 10. Market example: shafts `[.468, .243, .468]` at y 7.3, x 21.745 / 21.485.

**Why it is not visible:**
- `PlantVisuals.lua:274-286` builds a Crystal as a shaft spanning -.305Y .. .215Y plus four CornerWedges per end.
- Each wedge has its tall edge at the crystal's centre (offset `(-w/4, 0, +d/4)`, top vertex at the +X / -Z corner). Together they form a pyramid whose base is exactly the shaft's top (.3575Y - .1425Y = .215Y) and bottom (-.4025Y + .0975Y = -.305Y).
- So every point of a shaft's top or bottom face lies under its own pyramid, including where two crystals of a row overlap. No camera ray reaches it without first hitting a sloped wedge face.
- The detector cannot see this: `zfight.py:200` `contains()` returns `False` for CornerWedge, so wedges never occlude.

**Recommendation:** no change. The Amethyst Grape is owner-frozen, and its tests are byte for byte. Optionally teach the detector that a CornerWedge's bottom face covers its base. The far-proxy `Gem` form (4 Wedges) has only internal mid-plane faces.

### 5 (C2). Ash Tomato "Flat ash patch" vs "Squared ash tomato": CONFIRMED near-coplanar, proposal +.02

**Geometry** (`ApprovedPlantArt5`, design 1, fruit group 1):
- tomato Block centre y 3.44034, height 1.45840, so its top is at 4.16954;
- patch Block centre 4.17141, thickness .02244, so its top is at 4.18263: **.0131** above the tomato top, and .0095 at the market's showcase scale (.724);
- the same offset, times the design scale, holds in designs 2-4 (patches and tomatoes share their tilt) and on all 4 fruit (3 patches each).

**Proposal:** raise only the patch's TOP by .02 and keep its bottom embedded in the tomato.
- thickness `z[2] += .02` (x design scale);
- centre `+= .01` along the patch's own up axis (rotation column 2);
- design 1: `z[2]` .02244 -> .04244, `c[2]` 4.17141 -> 4.18141 (g1), 5.21847 -> 5.22847 (g2), 6.65818 -> 6.66818 (g3), 7.72394 -> 7.73394 (g4).

| | Patch top above the tomato top |
|---|---|
| Plant scale 1 | .0331 |
| Market (.724) | .024 |
| Bottom | stays .0094 inside the tomato |

- The ash flake gets .02 thicker, which cannot be seen.
- Apply it in the generator (`docs/proposals/R149/tools`), then let `check_plants_diff.py` accept these 48 spec lines. The Ash Tomato's "design 1 identical to the base" check would otherwise fail.
- The issue is old: R148 has the same patch.

### 4 (C3). KeyboardTrack RimEnd under LobbyFloor / the arena GroundPatch: CONFIRMED, proposal `RimDrop=.04`

**Geometry:**
- `RimEnd` `[181.2, 2.68, .65]` at y 2.64 has its top at 3.98 (`F - C.RimDrop`, `KeyboardTrack.client.lua:98`).
- `LobbyFloor`'s top is 4.00; it reaches z -99, over the whole start RimEnd (z -100.6 .. -99.95).
- The arena copy `GroundPatch` (top 4.00) covers the end RimEnd at z 5860.3.
- Offset .02 (`near`), area 118 / 108, contrast 255 / 76.

**Proposal:**
- `KeyboardTrack.lua:33` `RimDrop=.02` -> `.04`: the rim top goes to 3.96.
- Offset .04 > `far` .02 (D = 41.6), so both findings clear.
- The rim's visible top edge under the hidden floor drops .02, which cannot be seen.
- `test_keyboard` reads `C.RimDrop` symbolically.

### 3 (C4, new). Letter strips .03 under a lifted hole's Rim: CONFIRMED, proposal `HoleLift=.59`

**Geometry** (snow scene `holes+keyboard 0 -> 1`):
- LegendStrip top 4.58 (key top 4.55 + `Legend.Lift` .03).
- The R149 Rim is now .04 thick at +.02, so its top is 4.0 + .04 + .57 = 4.61, where it was 4.63 with the old .06 rim.
- The letters of keys under the .3-wide rim ring are .03 below it. That is `far`, area 5.8, contrast 255.

**Proposal:**
- `KeyboardTrack.lua:35` `HoleLift=.57` -> `.59` (every hole part +.02): rim top 4.63 (.05 above the letters), pit top 4.67.
- Snow-biome patches already avoid holes.
- Lowering `Legend.Lift` instead would push the letters to .01 over the key tops, which is worse.

---

## D. Checked and fine

**Baked meshes on live:**
- `FruitMeshes149.bake` is the same call sequence as `ApprovedPlantMeshes.build`, which runs live for the cocoa pod and Fire Pepper:
  - `CreateEditableMesh` (asserted non-nil: no memory budget or not allowed fails cleanly);
  - `AddVertex` / `AddNormal` / `AddColor`, `AddTriangle` + `SetFaceNormals` / `SetFaceColors`;
  - `CreateDataModelContentAsync(Content.fromObject(...))`, so the result replicates;
  - `CreateMeshPartAsync` with `{CollisionFidelity=Hull, RenderFidelity=Precise}`.
- Every error path is under `xpcall` / `pcall`:
  - the editable is destroyed;
  - the key is marked Failed for both twins;
  - one `warn` per server;
  - `preparing` cannot stay stuck, since nothing outside the pcall can throw.
- Templates replicate from `ReplicatedStorage`, and clients only clone them: ViewportFrame pictures as the cocoa does, coats through `_Neutral`.
- While a template is Loading, `UsesMesh` is true and `DetailReady` false, so the silhouette stays.
- Once Failed, the `|parts` suffix keeps the part-built fruit; spec and metadata caches are keyed on it.
- On the server, a build during the bake waits for `Prepare`. If the bake fails, that one build gets a plain ellipsoid.

**Prickly Pear:** `ApprovedPlantArt6.lua` is byte for byte `766ec4d` (live). It has 2 designs, so there is no key suffix.

**Growth correctness:**
- The final state equals the base's for every plant, 3 coats and every regrowing fruit (`test_growth`).
- A fruit crossing ripe, a body crossing 1, readiness and coat changes always force a write.
- `EndGrowth` applies at `max(now, ReadyAt, MatureAt)`.
- Timestamps drive it, so offline growth, joins and growth passes all work.
- The frozen plants are identical to the base at every write step.
- Server silhouettes write at their 32 steps (1/32 > 1/600).
- No change to timing, readiness, prompts or collision (`CanCollide=false`, `CanQuery` as before).

**Flight:**
- The fruit parts are the client's own detail model, so there is no server replication and no streaming of them.
- The rig and the bounce are reset before `syncFruit` (`show()`), so nothing poses a flying part.
- A plant that streams out or is removed ends its flights, and `LandCrop` releases the holds.
- A harvester who left or died drops the flight.
- Only the owner can harvest (`GardenPlantRuntime:112`), so aiming at the garden owner is right.
- Flight is off for reduced motion, the lowest tier, the frozen plants, Mech, Verity, Maw, Frostbell, the floating-petal plants and Starfruit.

**HarvestArrival:**
- Every hold ends (deadline via `task.delay`, extended by `Flying`).
- `Cancel` on a failed request means no flash.
- Observers never hold anything.
- No data is touched.

**ZFightFix149:**
- It runs first in `MapService.new`, under pcall.
- A part is moved only when exactly one match lies within .02 stud / .002 rotation / .02 size. It is idempotent (attribute).
- 25 of 25 match on the owner's place, and no other part changes (fixer test).
- The later start-up passes are no-ops on the installed place (`RoutesExpanded*` attributes), or rigid moves.
- No code finds these 25 parts by position (grep: only `'Wall bank slope'` by name, for a Z stretch that keeps X).

**Other z-fight edits:**
- Fence sill .08: its bottom stays at the pad bottom; collision is +.06 high.
- Lintel and roof: tiny size changes, collision unchanged in practice.
- Verity inlay: its bottom sits on the dais top, internal.
- Hole Rim .04 (see C4).
- Treadmill offsets: client-only art.
- MarketLayout sink ≤ .045.

**Lightning / dirt lift:**
- One lift per effect: `groundImpact` gets the already-lifted centre.
- A burst whose origin is already on the lifted pit gets lift 0.
- `KeyboardSurface149.Rect` reads the map attributes per effect, not per frame.

**Fix round A** (part-1 items, verified by suites or code):
- camera clamp: Camera+1 render step, translation only, Scriptable and first person skipped, unbound in cleanup;
- turn without a burst, `RowsPerFrame` 4;
- no double Transparency writes (`shown` / `hideList`; every release goes through `windowPass`);
- strip pools per half row; parked strips have their gui off;
- `SpacebarMaxDistance` 800;
- template stripped once, `swapPass` stops on a failed clone;
- floor hidden only at the end of `start()`, `safeStart` + 3-strike frame guard;
- `conns` pruned;
- snow patches avoid shovel holes (`reachesHole`; avoided cells retried when the signature changes);
- opaque snow with parity height steps;
- rain cap 900 on tier 2;
- weather idle early return;
- `Bases.DescendantAdded` byte filter;
- the fade not cut on a tier change.

**Leaks:**
- the `PlantGrowth` registry entry is cleared on `Destroying` (fired for descendants too) and lazily in `StateOf`;
- `Cued` ≤ 256;
- flights and pulses bounded;
- SnowBiome `holeConns` re-hooked and disconnected on destroy;
- Weather `areaConn` / `basesWatch` disconnected in cleanup.

**Trust:** no new remote and no server trust of client values. The new player attributes are written only in Studio or for command users, and client attributes do not replicate.

**Save data:** no saved field, catalog or value changed in this range. `Config.ProfileVersion` stays 22.

---

## E. Part-1 findings: status at `bc29fbb`

| Part 1 | Status |
|---|---|
| A1 camera under the keys | fixed (`cameraStep`, Studio check still advised: pitch up on the track, phone emulator) |
| A2 snow over holes | fixed (avoid list with the holes' rims) |
| A3 floor hidden before build | fixed (`armGround` last, `safeStart`) |
| A4 `swapPass` churn | fixed |
| A5 overlays floating in key gaps | open: Studio check |
| A6 feet in snow edges | open: owner's call |
| A7 `conns` growth / fade cut / stale avoid | fixed |
| A7 `Config.Version` 'V150 R148', GreetingEnd guess | open (release checklist) |
| B1 keycap triangle budget | open: measure `R142Keycap` in Studio |
| B2 turn rebuild | fixed (551 + 198 worst frame) |
| B3 rain particles | fixed (Cap 900) |
| B4 translucent snow | fixed (opaque + height steps) |
| B5 letter strips | fixed |
| B6 double Transparency | fixed |
| B7 berry translucency | open: owner's call |
| B8 template children cloned | fixed |
| B9 weather while Clear, `DescendantAdded` | fixed |
| B9 `ApprovedPlantArt.Key` requires art modules, Verity portrait every frame | open (nice) |
