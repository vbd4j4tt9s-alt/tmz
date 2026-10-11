# R149 fruit models: cocoa-pod / pepper style, baked meshes for the melons and the pumpkin, Ash Tomato variations

Design and owner decisions: `docs/proposals/R149/fruit_models.md` (approved "they all work except Lantern Fern, and Tomato: make growth variations", then "keep Amethyst Grape",
"Ash Tomato also keeps", and after `fruit_models_built.png`: **"keep prickly pear as it is and for the melons and pumpkins bake the meshes in"**).
Pictures: `docs/proposals/R149/fruit_meshes.png` (Watermelon / Snow Melon / Ember Pumpkin: part-built | baked mesh), `docs/proposals/R149/fruit_models_built.png` (the part-built batch;
its Prickly Pear column is superseded). Tests: `docs/proposals/R149/tests/run_fruit_models.sh`.

**Installer:** one new ModuleScript, `ReplicatedStorage/FruitMeshes149` (listed in `src/MANIFEST.tsv`), and three changed scripts besides the art modules: `PlantVisuals` (routes the new
mesh keys), `ServerScriptService/ApprovedPlantsBootstrap` (starts the bake) and the art modules below. `ApprovedPlantMeshes` and its ServerStorage index / data (place-only, not in
`src/`) are **not** touched. No saved-data change. A server picks it up when it starts.

## What changed
Same fruit centres, sockets, radii, Height / Radius, FruitCount, ids, harvest prompts / reach and connectors as before.

| Fruit | Art module | Hotbar picture (parts) | Plant at full detail |
|---|---|---|---|
| Watermelon | `PlantArtForest.SunflowerSeed` + **baked mesh** | 42 -> **5** (1 mesh body + stem, tendril, leaf, gloss) | 152 -> **90** |
| Snow Melon | `PlantArtSnow.SnowdropSeed` + **baked mesh** | 34 -> **5** (the snow cap is baked into the colours) | 152 -> **106** |
| Ember Pumpkin | `PlantArtLava.EmberBloomSeed` + **baked mesh** | 28 -> **5** (1 mesh body + stem, curl, leaf, gloss) | 148 -> **114** |
| Apple | `TreeReworkData2` | 5 -> 8 | 71 -> 83 |
| Elderbloom's elder apple | `TreeReworkData4` | 17 -> 10 | 172 -> 137 |
| Blueberry | `PlantArtForest.BluebellSeed` | 15 -> 18 | 90 -> 94 |
| Iceberry | `PlantArtSnow.IceberrySeed` | 15 -> 18 | 90 -> 94 |
| Prickly Pear | `ApprovedPlantArt6` | **unchanged** (24, its live look) | unchanged (97) |

(Plant counts are for one crop id; leaf counts vary a little per crop. If the fruit-mesh bake fails, the three get the part-built R149 fruit: 12 / 13 / 25 parts, plants 104 / 122 / 154.)
- Apple, elder apple, berries: smooth ellipsoid bodies, a Neon gloss patch (and the berries' glints) as `decor`: hidden on Gold / Diamond, as Verity's gloss. Every new Ball / Block
  carries `tx="smooth"` (no surface marks). The old connector specs that reach the vine stay as they were (`Fruit stem`, `Apple hanging stem`); the Blueberry / Iceberry cluster keeps
  its `canopy` / `cd` link to each crop's shrub crown. New stems are not in `PlantVisuals`' connector list, so they show in the hotbar / Bag / Index picture.
- **Unchanged (owner):** the Prickly Pear (`ApprovedPlantArt6` is byte for byte the live one again), Lantern Fern (`ApprovedPlantArt2`), Amethyst Grape (`PlantArtCrystal`), the Ash
  Tomato's look, the R148 seeds, Verity, every other plant.

### Baked meshes: Watermelon, Snow Melon, Ember Pumpkin
Like the cocoa pod and the Fire Pepper: one smooth, vertex-coloured mesh per fruit body.
- **Generated, not shipped.** `ReplicatedStorage/FruitMeshes149` (15 KB of source; PlantVisuals and the bootstrap add about 2 KB) builds each mesh in Luau as a lathe:
  - Watermelon: a slightly blunt oblong along its length, 8 dark stripes standing 2 % proud, a pale ground spot underneath, darker ends. 258 vertices, **512 triangles**.
  - Snow Melon: the same shape in frost colours, with the snow cap baked in as a frosted top. 258 vertices, **512 triangles**.
  - Ember Pumpkin: squat, 10 lobes (crests 18 % out from the grooves), sunken top and bottom, ember-lit grooves, a dark heart round the stem, a lighter underside.
    242 vertices, **480 triangles**.
  - The data is exactly the `ApprovedPlantMeshData` format (unit box, outward faces, area-weighted unit normals, colours 0..1), so the bake code is the same as ApprovedPlantMeshes'.
- **Baked at server start.** `ApprovedPlantsBootstrap` spawns `FruitMeshes149.Prepare()` before the approved meshes. Per key it generates the data (about 1 ms), then
  `AssetService:CreateEditableMesh` -> vertices / normals / colours / triangles (yielding every 192 vertices / 256 triangles) -> `CreateDataModelContentAsync` ->
  `CreateMeshPartAsync` (Hull, Precise, no shadow), twice: the normal template and a **`_Neutral`** twin with white vertex colours (Gold / Diamond coats colour it). The two are parented
  together into `ReplicatedStorage.FruitMeshTemplates149`; the EditableMesh is destroyed after each bake. 6 small bakes: a fraction of a second next to ApprovedPlantMeshes' 100.
- **Clients only clone.** `PlantVisuals` sends the three keys' `Get` / `Status` to FruitMeshes149 (every other key still goes to ApprovedPlantMeshes), so the cocoa-pod behaviour
  holds: while a template is still arriving `DetailReady` is false (GardenVisuals keeps the server silhouette) and a picture build errors "still loading" (ItemPictures retries in 2 s).
- **The specs.** `FruitMeshes149.Art` folds each fruit's body pieces (rind + 7 stripe bands; rind + 7 bands + snow cap; heart + 10 ribs + 10 Neon grooves) into one
  `s='ApprovedMesh'` spec where the first of them stood, after PlantSurfaceStyle (so every other spec, its `_ArtIndex` and leaf tints are exactly the part-built list's). The melon
  body takes the rind's frame and size; the pumpkin body fills the ribs' envelope around the heart (same bottom on the soil). The pumpkin's gloss patch moves out 10 % from the body
  centre (its fuller lobes would cover it). Growth, coats, mutations, weather, far proxies, harvest prompts, the hotbar / Bag / Index pictures (a MeshPart in the viewport, like the
  cocoa) all go through the usual paths.
- **Fail safe.** If a bake fails (no EditableMesh memory, EditableMesh not allowed, a content error), that key is marked Failed (both templates dropped, a `Failures` value per
  name) and its seed keeps **exactly the R149 part-built fruit** everywhere (the spec cache key carries the choice); one `warn` per server, no error spam. A server that never
  baked (no `FruitMeshTemplates149` folder) also shows the part-built fruit. If a bake fails in the middle of a server build (e.g. the market at server start), that one build draws
  a plain ellipsoid in the fruit's colour and never errors.
- **Phones.** At most 512 triangles per fruit, 1024 per plant, 6 templates of 242 - 258 vertices; a fruit clone shares its template's mesh. The plants lose 14 - 40 parts each
  (Watermelon 104 -> 90, Snow Melon 122 -> 106, Ember Pumpkin 154 -> 114 against the part-built version), so more fit the detail budgets.

### Ash Tomato: four designs
`ApprovedPlantArt5` keeps its design 1 exactly and gains three variations of it (mirror / size <= the original / lean, leaves swung about their stems and a few fewer, each tomato scaled and twisted
about its socket, a shade of red and green). Same 4 fruit, 11 specs per tomato. `ApprovedPlantArt.Get` already picks `hash(crop.Id) % #designs`; **`ApprovedPlantArt.Key` gained a design suffix**
(only when 10 is not a multiple of the design count): the old key was `hash % 10`, which cannot name 1 of 4 designs, so a cache entry (plant spec cache, hotbar picture template) would have served two
designs. Keys of every other plant are unchanged.

### Known, harmless
- The art-list index (`ArtSpecIndex` attribute) of body parts listed after a redesigned fruit moves in the Watermelon, Snow Melon and Ember Pumpkin against the live game (the part-built
  redesign changed the list; the mesh fold keeps the part-built indices). It only staggers when a leaf appears during growth.
- Apple tree: two of the four hanging stems end about 0.3 - 0.5 studs under the canopy ellipsoid (as in the base; the R134 box check passes). Elderbloom's two trunk "living runes" are flagged by the same checker in the base too.
- `PlantVisuals.AssetRevision` is not bumped (it only matters inside a running client).

## Tests
`sh docs/proposals/R149/tests/run_fruit_models.sh`:
- files: under `src/` only the 7 art / key modules, PlantVisuals, the bootstrap, the new FruitMeshes149 and the manifest differ from the base (the Prickly Pear, ApprovedPlantMeshes,
  PlantGrowth, GardenVisuals ... byte for byte);
- a regression diff of EVERY catalog plant against the commit before the redesigns (`0b08836`), with the fruit-mesh bake run on the mock: 57 plants identical (the Prickly Pear: 8 crops,
  every mode), the 7 redesigned fruit and the Ash Tomato's variations the only differences;
- **fallback**: the same dump with no bake and with every bake failing, against the R149 part-built commit (`3484f31`): every plant identical (Watermelon / Snow Melon / Ember Pumpkin
  included), only the reverted Prickly Pear differs; 0 / exactly 1 warning;
- `test_fruit_models.luau` (1442 checks): before the bake (part-built, then Loading), the generator (deterministic, counts, unit box, closed and outward, normals, colours, relief, a
  pinned digest of the reviewed design), the bake (exactly the generated data, white neutral twin, editables destroyed, yields, MeshPart settings, idempotent), the mesh specs, every
  build (hotbar / Gold / Diamond, plant, far proxy, growth), the stem / leaf / gloss on the real mesh surface, ItemPictures holding the MeshPart, PlantVisuals' routing (the cocoa's keys
  untouched), a template that has not replicated yet; plus every part-built redesign, the Ash Tomato, the unchanged plants;
- `test_fruit_mesh_fallback.luau`: one key's neutral twin failing, every key failing, a content failure, a failure in the middle of a server build, a server baking on demand, and the
  real GardenVisuals on a garden of the three (no detail and no warning while the templates load, then the plants with their mesh bodies);
- the R134 floating check (31 plants, 62 fruit scenes: 0 new floating parts).

`mutation_check.sh` breaks eleven things in a copy (the Ash key suffix, a gloss's decor, Lantern Fern, a berry connector, the design pick, the neutral twin's colours, the mesh routing,
the Prickly Pear, the fallback, the pumpkin's gloss, the cache-key suffix) and shows each is caught. Older suites that build plants / pictures (R132, R135, R137, R139, R123 borders and
treadmill, R122 veiled, R124, R147 Verity, R148 roster and Index, inventory R113) pass as before: their mock worlds have no bake, so they see the part-built fruit.
The preview: `sh docs/proposals/R149/preview/run_mesh_preview.sh <scratch>` (renders the meshes from the vertex data FruitMeshes149 generates). The part-built art is regenerated
from `docs/proposals/R149/tools/` (`port_fruit_models.sh`; it no longer touches the Prickly Pear).

## Check in Studio
- Start a server: `ReplicatedStorage.FruitMeshTemplates149` holds 6 MeshParts, `Ready = true`, `FailureCount = 0`, `BakeSeconds` small; no `[R149 fruit meshes]` warning in the output.
- Watermelon, Snow Melon, Ember Pumpkin: on the plant, growing from the seed, regrowing after a pick, far away; hotbar / Bag / Index / sell pictures plain, Gold and Diamond; held in the
  hand; the market stands at server start; weather effects around them. Look at the stripes, the frosted top, the lobes / ember grooves and the gloss patch under real lighting.
- A phone: frame time in a garden of melons / pumpkins.
- Prickly Pear: as live, on both cactus designs. Ash Tomato: the four shapes and their hotbar pictures. Blueberries / Iceberries on their crowns; Apple trees.
