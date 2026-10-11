# R149 proposal: cocoa-pod / pepper style for the other fruits

> **Status: Phase 1 built in R149** (owner: "they all work except for Lantern Fern ... and Tomato: make growth variations", then "keep Amethyst Grape" and "Ash Tomato also keeps").
> Built: Watermelon, Snow Melon, Apple, Elderbloom's apple, Ember Pumpkin, Blueberry, Iceberry; Ash Tomato gets 3 variations of its current look; Lantern Fern and
> Amethyst Grape are untouched. See `docs/releases/R149_fruit_models.md`, `fruit_models_built.png` (the real modules, before | after), `tests/run_fruit_models.sh` and `tools/`.
>
> **Then, after `fruit_models_built.png`** (owner: "keep prickly pear as it is and for the melons and pumpkins bake the meshes in"):
> - the **Prickly Pear is back to its current look** (`ApprovedPlantArt6` byte for byte the live one; its column in `fruit_models_built.png` is superseded);
> - **Phase 2 for the Watermelon, Snow Melon and Ember Pumpkin is built in R149**: one baked mesh body per fruit (+ stem, tendril / curl, leaf, gloss), generated in Luau
>   by the new `ReplicatedStorage/FruitMeshes149` (parametric lathes, no shipped vertex data), baked at server start through the same EditableMesh -> MeshPart route, with
>   its own template folder; `ApprovedPlantMeshes` and its place-only index / data are not touched (the "5-line index merge" below was not needed). A failed bake keeps
>   the part-built fruit. Picture: `fruit_meshes.png`; preview `preview/run_mesh_preview.sh`.
>
> The text below is the original proposal.

Design only. No gameplay `src/` changes. Base: `ca381f2` (R148 head, with the owner's R148 art feedback).

Owner: *"look at the cocoa pod and pepper models, see if we could incorporate the same type of models and renders to other fruits to
improve looks; propose the models and new changes we could do"*.

| Picture | What it shows |
|---|---|
| `fruit_models_today.png` | All 54 active fruits as the hotbar / sell viewport builds them, grouped by biome, framed by priority (P1 / P2 / OK / REF). |
| `fruit_models_proposed.png` | The cocoa / pepper references; 10 part-based prototypes next to today's fruit; 2 Phase-2 baked meshes; 4 plants before and after. |

How the pictures were made:
- Everything is built by the **real modules of this checkout** on the Roblox mock: `HarvestPresentation.Build`, `PlantVisuals.Build` and `PlantVisuals.Part`.
- They are drawn with three.js. Tooling and rerun steps are in `preview/run_preview.sh`.
- The baked meshes are **not in the repo**. They live in ServerStorage. The preview draws them from their real vertex data, read out of the
  place file `b4f113d1-sapkeyver.rbxl` (2026-10-04 upload) by `preview/extract_meshes.py`. Every scene used real mesh data, with **0 stand-ins**.
- Without a place file, the tooling draws each baked mesh as a stand-in ellipsoid of its bounding box (as R148's preview did).
- Not drawn: Roblox textures, decals (Verity's face), Future lighting, bloom and the Mech hologram effect.

## 0. Recommendation in one screen

- **The look comes from three things, not from highlights or textures:**
  - one smooth, sculpted body per fruit (a baked mesh, or a few overlapping ellipsoids);
  - built-in segmentation (the cocoa's 10 flutes, the Plasma Pepper's shell rings);
  - a colour gradient, plus small attached detail (sepals, a curled stalk).

  All three can be done today. Part-based sculpts can ship in one release. New baked meshes can also be **generated from this repo**:
  `preview/gen_meshes.py` writes the exact `ApprovedPlantMeshData` format, and the preview shows two of them. Shipping those needs one small
  loader change and a Studio bake check, so they are a later batch.
- **First batch (one release, data-only, part-based):** Watermelon, Snow Melon, Apple (+ the Elderbloom elder apple), Amethyst Grape,
  Lantern Fern, Prickly Pear and Ash Tomato.
  - These are the seven fruits whose body is a **Block**, plus the 162-part Amethyst bunch.
  - Parts drop where it matters: Watermelon plant 152 -> 104; Amethyst Grape plant **726 -> 150**.
- **Second batch:** Ember Pumpkin, Blueberry / Iceberry and Pineapple (plain round fruit), then **Phase 2 meshes**: Watermelon, Pumpkin, Apple
  and Tomato as baked lathes, 1 part each.
- **Leave alone:**
  - the references: Cocoa, Fire / Prism Pepper and the Worldroot heart;
  - the stylised Legendary+ flowers, crowns and lotuses;
  - the Mech holograms and Verity;
  - the just-approved R148 Aloe, cactus Sand Fruit and x2 Fire Pepper. Their growth variations are being done separately.

## 1. How the cocoa pod and the peppers are built

**Art lookup** (`ApprovedPlantArt.Get`, first match wins):

1. `VerityPlantArt`
2. `DesertPlantArt149`
3. `MechArt` -> `HologramForms`
4. `RarityPlantArt` (`*SeedArt45`)
5. `TreeReworkArt` (`TreeReworkData1..12`)
6. `ApprovedPlantIndex` (`ApprovedPlantArt1..21`)
7. `PlantArt<Biome>`, scaled by `BaseScale` and passed through `PlantSurfaceStyle`

Every source is a list of **specs**:
- `s` shape, `f` feature name, `r` role, `m` material, `k` RGB, `z` size, `c` CFrame, `g` fruit group;
- optional `tx` surface detail, `decor` (gloss hidden on Gold / Diamond), `rf` reflectance and `mesh`.

`PlantVisuals.Part` turns each spec into Parts. `Ball` is a SpecialMesh ellipsoid. `LeafBlade` becomes 4 wedges + 3 veins. `Crystal` becomes a prism + 8 corner wedges.

| Fruit | Art source | Fruit build (hotbar picture) | Colour |
|---|---|---|---|
| **Cocoa** (Jungle Common) | `TreeReworkData3`. It wins over `ApprovedPlantArt9`, which holds the same pod. | `ApprovedMesh` **FlutedCocoa** (1.71 x 3.50 x 1.48) + a CylinderX pedicel (hidden in the hotbar): **1 part** | Part colour 242,242,243 (white), so the mesh's **vertex colours** show. |
| **Fire Pepper** (Lava Mythic) | `ApprovedPlantArt16`. `Roster149.FirePepperArtScale` x2 is applied in `ApprovedPlantArt.Get`. | `ApprovedMesh` **SmoothFirePepper** (3.54 x 4.19 x 1.69) + a `FruitStalk` mesh + 3 `Ball` "pointed sepals" (0.22 x 0.79 x 0.21): **5 parts**. The plant: stems and leaves are meshes too (34 parts). | Pepper part colour 255 (vertex colours show). Stalk part colour green x near-white vertex shading (baked AO). |
| **Prism Pepper** (Crystal Rare, `PrismOrchidSeed`) | `ApprovedPlantArt17` | **SmoothPrismPepper**: the same geometry as the Fire Pepper, violet vertex colours; 5 parts | Same as Fire Pepper. |
| **Plasma Pepper** (Mech Legendary) | `MechArt` / `MechPlantData` | **Parts only** (24): 3 stacked CylinderX shell rings (tapering, each a step redder to oranger), 3 Neon energy seams, 8 corner-wedge exhaust tips, 6 metal ribs, a dark cap with Neon slits, a gauge | Metal + Neon. |

**Baked-mesh pipeline:**
- **Data.** `ServerStorage/ApprovedPlantMeshIndex` maps 50 keys to `ApprovedPlantMeshData1..50`. Each holds `{Vertices, Normals, Colors (0..1), Faces}`,
  normalised to a unit box, so the spec's `z` sizes it.
- **Bake.** At server start, `ApprovedPlantsBootstrap` calls `ApprovedPlantMeshes.Prepare()`. For every key it runs
  `AssetService:CreateEditableMesh` -> `CreateDataModelContentAsync` -> `CreateMeshPartAsync` (Hull, Precise, no shadow).
- **Templates.** It stores a normal template and a `_Neutral` one (white vertex colours, so a Gold / Diamond coat shows) in
  `ReplicatedStorage.ApprovedPlantMeshTemplates`.
- **Clients** clone the templates. `PlantVisuals.DetailReady` makes `GardenVisuals` keep the silhouette until a template is ready.
- No uploads, no asset ids.
- **Users:** Cocoa, Fire Pepper, Prism Pepper and the Ancient Worldroot heart and sepals.

**The meshes themselves** (read from the place file):

| Key | Vertices / triangles | Form | Vertex colour |
|---|---|---|---|
| FlutedCocoa | 662 / 1320 | Lathe, 22 rings x 30 segments. **10 flutes** (radius alternates 0.38-0.56), rounded shoulder, pointed tip. | Mottled 135,47,11 -> 219,106,22, darker tip. |
| SmoothFirePepper | 522 / 1040 | Swept curved tube with a hooked tip | **Gradient** red shoulder 231,57,10 -> orange tip 255,115,13 |
| SmoothPrismPepper | 522 / 1040 | Same tube | 91,60,193 -> 155,134,225 |
| Stems / stalks | 162 / 320 | Tapered tubes | Near-white AO shading (233-255) under a green part colour |
| Leaves / sepals | 54 / 104 | Curved pointed blades | Green gradient baked in |

**What makes them look better than the other fruit** (see `fruit_models_today.png`):
1. **Shape fidelity.** One sculpted silhouette (pod, hooked pepper) instead of a Block or a stack of boxes. 7 fruits still have a **Block body**:
   Watermelon, Snow Melon, Apple, Elder apple, Ash Tomato, Prickly Pear and the Lantern box.
2. **Smooth shading.** Per-vertex normals: no hard box edges.
3. **Segmentation.**
   - The cocoa's flutes and the Plasma Pepper's rings read as "made", not "placeholder".
   - Today's melons fake stripes with 18 flat slabs on a cube.
4. **Colour gradient.**
   - The meshes: shoulder to tip, plus mottling.
   - The Plasma Pepper: a colour step per ring.
   - Part fruit are one flat colour per part.
5. **Small attached detail.** Three pointed sepals, a curled stalk, a pedicel. Most other fruit have a Block "calyx" or nothing.
6. **Cheap.** A mesh fruit costs **1** part (`PartCost` of an ApprovedMesh is 1), so detail costs nothing at render time.

**What does NOT make the difference:**
- **Highlights.** The `PlantEffects` rarity aura (a Highlight) is Legendary+ only, and Cocoa is Common. Roblox draws at most 31 Highlights
  (R148 slot fix), so do not add more.
- **Effects.** `ApprovedFruitEffects` only runs for Mirage Fig and Ember Emperor.
- **Pictures.** `ItemPictures`, `HarvestPresentation` and `HarvestViewport` have had no 2D icons since R137. The hotbar, inventory, sell
  menu and Index **build the same 3D fruit**, so every model change below shows up there for free.

## 2. Audit: all 54 active fruits, ranked

Parts = parts in the hotbar picture (`HarvestPresentation.Build`, stems hidden). Plant = full-detail parts of the grown plant.
Measured on the mock (`AUDIT` rows of the dump).

**P1: Block body. Redo first.**

| # | Fruit (biome, rarity, fruits/plant) | Today | Proposed |
|---|---|---|---|
| 1 | Watermelon (Forest Common, 2) | Block rind + 18 Block stripes. 42 parts; plant 152. | Ellipsoid rind, 7 stripe bands meeting at the ends, stem + tendril, leaf, gloss: **12**; plant 104. Phase 2: 1 mesh, **5**; plant 90. |
| 2 | Apple (Forest Rare, 4) | A red **cube** + 3 dots, 5 parts | Body + 2 shoulder lobes + lighter base tone, dimple, stem, leaf, gloss: **8** |
| 3 | Snow Melon (Snow Uncommon, 2) | The Watermelon cube in frost colours, 34 parts | Watermelon build, frost palette + translucent snow cap: **13** |
| 4 | Ash Tomato (Lava Rare, 4) | "Squared ash tomato" Block + flat ash plates, 13 parts | Round body + 5 lobes, Neon ember seams in the grooves, 5-sepal star calyx, ash bloom, gloss: **19** |
| 5 | Prickly Pear (Desert Uncommon, 3) | Block + Ball shoulder + 12-wedge crown, 24 parts | Barrel ellipsoid with a dark top / magenta / coral base gradient, sunken navel + 5 crown scales, 6 areoles, gloss: **16** |
| 6 | Lantern Fern (Jungle Rare, 4) | Neon **box** + 4 rib sticks + 12 corner wedges, 24 parts | Physalis husk: 5 fluted ribs over a Neon core glowing through the gaps, calyx, tip: **8** |
| 7 | Elderbloom (Forest Mythic, 5) | Elder apple: Block body + Block base + 2 balls + Neon rune, 17 parts | The Apple build in jade / gold, keeping the Neon rune: about **10** |

**P2: plain round or very heavy. Improve.**

| # | Fruit | Today | Proposed |
|---|---|---|---|
| 8 | Amethyst Grape (Crystal Rare, 4) | 9 `Crystal` grapes + 9 `Crystal` facets: **162 parts a bunch, 726 a plant** (the heaviest plant in the game) | 3/3/2/1 bunch of glossy grapes, dark-to-light row gradient, 4 facet glints, crystal shard: **18**; plant **150** |
| 9 | Ember Pumpkin (Lava Rare, 2) | 6 tall ball lobes, stick stem, leaf blade, 28 parts | 10 flatter ribs around a dark heart, Neon ember light in the 10 grooves, curled stem, leaf, gloss: **25**. Phase 2: 1 mesh, **5**. |
| 10 | Blueberry (Forest Uncommon, 4) | 3 balls + Block calyx caps, 15 parts | Frosty bloom shell per berry, dark crown, stalk + pedicels, 2 leaves, glints: **18** |
| 11 | Iceberry (Snow Rare, 4) | The Blueberry in ice blue, 15 parts | The Blueberry build, ice palette: **18** |
| 12 | Pineapple (Jungle Uncommon, 1) | Ball + 8 Block scales + 5 leaf blades, 60 parts | Later: ellipsoid + rows of diamond pads + 5-blade crown (about 30), or a Phase-2 lathe with a baked diamond pattern (1 part + crown) |

**REF: baked mesh. Keep.**
- Cocoa: 1 part.
- Fire Pepper: 5 parts (R148 x2 approved; growth variations in progress separately).
- Prism Pepper: 5 parts.
- Ancient Worldroot amber heart: AmberHeart + 2 HeartSepal meshes, 7 parts.

**OK: stylised by design or already good. Keep, optional touches only.**

| Biome | Fruit (parts) and note |
|---|---|
| Forest | Mooncap (51): glowing mushroom cluster, good. Sunflower (96): sculpted, good. |
| Jungle | Venom Pitcher (112): sculpted but heavy, candidate for a later mesh. Tiger Orchid (35): good. |
| Desert | Aloe (26) and Sand Fruit (3): **R148, owner-approved today**, variations in progress; at most add a gloss later. Dune Lotus (104), Dune Starfruit (40), Mirage Fig (10: two ellipsoids + Neon window, already in this style), Solar Starfruit (30). |
| Snow | Aurora Lily (53), Glacier Lotus (80), Silent Frostbell (50), Polar Starbloom (39), Winter Crownwood (16): stylised. |
| Lava | Lava Lotus (92), Obsidian Maw (29), Boom Bloom (72), Ember Emperor (18): stylised. |
| Crystal | Moon Melon (68): a crescent by design. Diamond Vine (16), Hollow Geode (174), Orbit Lotus (34), Prism Monarch (9): stylised gems. |
| Storm | Spark Reed (7), Thunder Tulip (19), Volt Orchid (45), Tempest Lotus (73), Blackout Bloom (22), Storm Sovereign (7), Pulsar Starfruit (22): stylised. |
| Mech | Plasma Pepper (24): the segmentation reference. Holo Melon (36): a square hologram by design. Prism Lotus (10), Holo Apple Tree (22), Nebula Vine (31), Crowncore (12): holograms, keep. |
| Verity | Verity (5): the owner-specified ball with a face. Keep. |

## 3. Proposed models

All prototypes are in **`preview/FruitModels149.luau`**:
- a scratch module, **not** in `src/` and not required by anything;
- written in the spec format above and built by the **real `PlantVisuals.Part`**;
- authored around each fruit's centre, front = -Z, at today's fruit size.

Each one carries the cocoa / pepper style into parts:

| Cocoa / pepper trait | Part-based equivalent used |
|---|---|
| Sculpted body | 1-3 overlapping `Ball` ellipsoids (apple shoulders, barrel pear), never a Block |
| Flutes / ribs | Radial ellipsoids around the axis (pumpkin 10, tomato 5, lantern 5), or **meridian bands**: a thin ellipsoid 4.5% proud of the rind, so 2 stripes per part that meet at both ends (melon) |
| Vertex-colour gradient | Stacked shells of shifted tone: dark shoulder -> body -> light base; translucent bloom / snow / ash caps |
| Sepals, curled stalk | `Ball` sepals like the pepper's, 2-segment `Cylinder` stems with a curl |
| Glossy finish | One Neon gloss patch, `decor=true`, so it is hidden on Gold / Diamond (Verity's R147 gloss). Grapes also use `rf` reflectance. |
| Plasma Pepper energy seams | Neon slivers in the grooves (Ember Pumpkin, Ash Tomato): the Lava identity |

**Per-fruit result.** Parts are counted by the dump. "Plant" is full detail with the prototype dropped onto today's fruit centres (`PLANT` rows).
Rows marked ≈ are FruitCount x the per-fruit change.

| Fruit | Hotbar parts today -> new | Plant parts today -> new | Budget per fruit | Where it goes |
|---|---|---|---|---|
| Watermelon | 42 -> 12 | 152 -> 104 | 12 | `PlantArtForest.SunflowerSeed`, group 1/2 specs |
| Snow Melon | 34 -> 13 | ≈152 -> 110 | 13 | `PlantArtSnow.SnowdropSeed` |
| Apple | 5 -> 8 | 71 -> 83 | 8 | `TreeReworkData2` (Apple). Elder apple: `ElderAppleArt` / `TreeReworkData4` |
| Ash Tomato | 13 -> 19 | ≈107 -> 131 | 19 | `ApprovedPlantArt5` |
| Prickly Pear | 24 -> 16 | ≈97 -> 73 | 16 | `ApprovedPlantArt6` (author at 1/2 size: `ApprovedPlantArt.Get` grows the fruit x2 around its shoulder socket) |
| Lantern Fern | 24 -> 8 | ≈206 -> 142 | 8 | `ApprovedPlantArt2` |
| Amethyst Grape | 162 -> 18 | **726 -> 150** | 19 | `PlantArtCrystal.AmethystSeed` |
| Ember Pumpkin | 28 -> 25 (mesh: 5) | 148 -> 154 (mesh: ≈114) | 25 / 5 | `PlantArtLava.EmberBloomSeed` |
| Blueberry / Iceberry | 15 -> 18 | ≈90 -> 102 | 18 | `PlantArtForest.BluebellSeed` / `PlantArtSnow.IceberrySeed` |

**Rules for the real port:**
- Keep ids, `FruitCount`, `Sockets`, `FruitCenters` and `FruitRadii`. A saved crop's `FruitStates` are validated against FruitCount (see R148 D2).
  Harvest reach and the fruit picker therefore stay as they are.
- Keep today's **connector** specs (`Fruit stem`, `Berry pedicel`, `Apple hanging stem`, `Lantern pedicel`, ...): they reach the vine or branch
  and are already hidden in the hotbar.
- Give new stems names that are **not** in `PlantVisuals`' connector list, so they do show in the hotbar.
- Run the R134 floating check on every changed plant, as for R148's Sand Fruit.
- **Variety.**
  - `ApprovedPlantArt` modules already return a *list* of designs. `ApprovedPlantArt.Get` picks one per crop (`hash % #designs`) and adds ±2% size
    and a small turn. Cactus and Agave carry 2 designs today, and the R148 Aloe / Sand Fruit / Fire Pepper growth variations use the same mechanism.
  - Fruit can use it too: 2-3 designs per seed (stripe phase, blush side, a lighter or darker tone) at no extra parts.
  - `PlantArt<Biome>` and `TreeRework` fruit would need the same small list wrapper. TreeRework already varies by 16 hashed turns.

### Baked meshes: can the pipeline make NEW meshes from here?

**Yes.** Nothing in the pipeline needs an upload:
- `preview/gen_meshes.py` generates `RibbedMelon149` (1202 vertices, wavy vertex-colour stripes, a pale ground spot, slight stripe relief) and
  `LobedPumpkin149` (1382 vertices, 10 lobes, dimples, ember-lit grooves, a dark shoulder).
- It writes them in the exact `ApprovedPlantMeshData` format.
- The prototypes reference them with `s='ApprovedMesh', mesh=<key>`, through the same `PlantVisuals.Part` path as the cocoa, and the preview draws
  them from the generated vertices.

What shipping them needs:
1. **A home for the data.**
   - Today's index and data live in ServerStorage, which `tools/export.py` skips, so the installer cannot patch `ApprovedPlantMeshIndex`.
   - Proposal: add `ServerScriptService/FruitMeshes149/Index` + data modules (exported and installable), and merge that index in
     `ApprovedPlantMeshes.build` / `Prepare`. That is about 5 lines.
2. **Size.** About 120-140 KB of module source per mesh at 4 significant digits, so 10 meshes come to about 1.3 MB of installer paste.
   Split the installers, or lower the resolution (the cocoa is 662 vertices).
3. **Bake time.** Each key is baked twice (normal + `_Neutral`), yielding every 192 vertices / 256 triangles. That is about 15 frames per bake,
   so 10 new meshes add about 5 s to server-start preparation. Until a template is Ready, clients keep the silhouette (`DetailReady`).
4. **Limits.**
   - Vertex colours only: no textures.
   - No per-vertex Neon. A glow needs a Neon part next to the mesh.
   - One shape per key. The spec's `z` stretches it.
   - If baking fails, the plant stays on its silhouette. The cocoa and peppers carry this risk already.
   - Keep the Phase-1 part version as the fallback spec.

## 4. Performance

- **Planner budgets.**
  - Full detail: `PlantDetailPlanner`, 1400 parts / 24 models (850 / 12 low; 1050 / 650 when more than 6 are on screen).
  - Distant: `DistantPlantView`, 5000 parts / 64 models.
  - Fruit proxies use the same specs (minus `tx`), so fruit savings count twice.
- **Per garden (10 plots).**
  - Amethyst: 10 plants go from 7260 to 1500 parts. Today one Amethyst plant (726) uses half the full-detail budget; after, about 9 fit.
  - Watermelon: from 1520 to 1040 (Phase 2: 900).
  - Apple: from 710 to 830.
  - Ember Pumpkin: from 1480 to 1540 (Phase 2: about 1140).
  - The first batch is **net negative** in parts for any realistic mix.
- **Hotbar / inventory / sell viewports** (`ItemPictures`).
  - On-screen pictures have no cap. The off-screen pools are capped (`MaxParts` 9000, warm / spare 4000 parts).
  - Watermelon goes 42 -> 12, Amethyst 162 -> 18, Lantern 24 -> 8, so more pictures stay warm.
- **LOD.**
  - The prototypes use only `Ball` / `Cylinder` / `Gem`, so the distant proxy is the same build.
  - Optional one-line change: skip `decor` specs (gloss, glints) in `Visuals.Metadata` proxies, which saves 1-4 parts per distant fruit.
- **No new Highlights, lights or Heartbeat work.** Everything is static parts.

## 5. Plan

| When | Scope | Risk |
|---|---|---|
| **R149 (one release)** | Part-based: Watermelon, Snow Melon, Apple + Elder apple, Amethyst Grape, Lantern Fern, Prickly Pear, Ash Tomato. Data edits in the art modules listed in §3 only (no new code paths; optionally `PlantVisuals.AssetRevision` 46 -> 47). | Low. Checks: floating check, mutation coats, hotbar pictures, harvest reach unchanged. |
| R150 | Ember Pumpkin, Blueberry / Iceberry, Pineapple; 2-3 designs per fruit through the art-variant lists. | Low |
| Later (Phase 2) | The 5-line `ApprovedPlantMeshes` index merge plus generated lathe meshes: Watermelon, Pumpkin, Apple, Tomato, then Pineapple and Venom Pitcher. Verify `ApprovedPlantMeshTemplates.Ready` / `FailureCount=0` in a live server first. | Medium (bake time, installer size, Studio check) |

## 6. Files

- `fruit_models_today.png`, `fruit_models_proposed.png`: the pictures.
- `preview/run_preview.sh <scratch> [place.rbxl]`: reruns everything. It needs `/opt/luau`, python3 + Pillow, node + playwright and three@0.169.0.
- `preview/FruitModels149.luau`: the prototypes (scratch).
- `preview/dump_fruit_models.luau`: the mock dump (scenes + AUDIT / INFO / PLANT rows).
- `preview/extract_meshes.py`: reads the baked meshes from a place file (read-only).
- `preview/gen_meshes.py`: the Phase-2 meshes.
- `preview/fruit_models.html`, `preview/render_fruit_models.mjs`, `preview/make_sheets.py`: the renderer and the sheet composer.
