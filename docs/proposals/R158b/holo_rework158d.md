# R158d: Holo Melon and Holo Apple Tree rework

Owner: "do a mini rework on the holo melon and holo tree: make sure they use the updated melon and pumpkin meshes for the holo melon, and for the tree it uses the updated apples".
Picture (approximate, offline, before | after): `docs/proposals/R158b/holo_rework158d.png`. Tools: `docs/proposals/R158b/preview/run_holo_preview158d.sh`.

## What changed
Two scripts, no new script, no saved-data change, nothing in `src/MANIFEST.tsv`, nothing per frame:
`ReplicatedStorage/FruitMeshes149` (two more mesh keys) and `ReplicatedStorage/HologramForms` (builds the fruit). The plant bases, sockets, fruit centres, radii, harvest reach, names
(Holo Melon / Cantaloupe / Pumpkin, Holo Apple / Pear / Orange) and the per-harvest form cycle are exactly as before.

### Holo Melon (3 forms, one per harvest)
- **Melon**: the Watermelon's baked mesh (`Watermelon149`), at the real fruit's size, with the real Watermelon's stem, tendril and leaf where they sit on the real fruit.
- **Pumpkin**: the Ember Pumpkin's baked mesh (`EmberPumpkin149`) at 0.9 of its real size, with the real pumpkin stem, curl and leaf.
- **Cantaloupe**: there is no cantaloupe mesh, so it is the melon mesh drawn rounder (3.3 x 3.15 x 3.15 against 3.76 x 3.0 x 3.0), teal, with the same stem and leaf and two extra scan rings across (its netting).
- **Still holograms**: Neon, translucent (0.38), the cyan / teal / violet palette as before, the slow spin (`HologramProjection.Turn`, every fruit part keeps its `HologramFrame`), the growth reveal (`MechGrowth`), three thin scan rings a fruit. The square wire boxes and stripes are gone.
- **How the mesh reads as a hologram**: Neon is unlit, so the real stripes / grooves come from the vertex colours. Two new keys in `FruitMeshes149`, `HoloMelon158` and `HoloPumpkin158`, are the **same mesh data** as `Watermelon149` / `EmberPumpkin149` (every vertex, normal and triangle, pinned by a test) with each vertex colour turned into brightness (grey 0.3 .. 1). The part colour tints it, so the melon's stripes and the pumpkin's grooves show as brighter and dimmer bands of the form's colour. They are baked at server start like the other keys, with a `_Neutral` twin: a Gold / Diamond Holo Melon is now a solid Metal / Glass melon or pumpkin (it was gold wire boxes).
- **Fallback**: if either mesh fails to bake, or the server never baked, the Holo Melon keeps its R57 wire forms byte for byte (the spec cache key carries `|parts`, like the real fruit); the Holo Apple Tree needs no mesh.

### Holo Apple Tree (4 fruit, each cycles apple / pear / orange)
- Each fruit is the **real Apple's parts**, read from `TreeReworkArt` ('AppleSeed': body, two shoulders, base tone, dimple, stem, leaf), so a later change to the real apple carries over. Neon, translucent, the form's palette, two scan rings. The stem that joins it to the crown stays as authored.
- The game has no pear or orange art: the pear and the orange are the apple stretched (tall and narrow / wide and low) and tinted, exactly as before.

## Parts (visible, per fruit; Holo Melon plant in all; Holo Apple Tree in all)
| | before | after |
|---|---|---|
| Holo Melon fruit | 36 | **7** (1 mesh, stem, tendril, leaf, 3 rings) |
| Holo Cantaloupe fruit | 42 | **9** |
| Holo Pumpkin fruit | 36 | **7** |
| Holo Apple / Pear / Orange fruit | 22 | **10** |
| Holo Melon plant | 61 / 67 / 61 | **32 / 34 / 32** |
| Holo Apple Tree (4 fruit) | 427 | **379** |

Mesh cost: the Holo Melon draws one 512-triangle (melon, cantaloupe) or 480-triangle (pumpkin) MeshPart. Four more small bakes at server start (10 in all, 242 - 258 vertices each, a few milliseconds). No new per-frame work: fewer parts to spin, no new loops.

## Everything that shows them
The plant in the garden, the harvested fruit (hotbar / Bag / held: `HarvestPresentation`, `HeldHarvestRig`), the Index / collection picture (`CollectionViewport`), `ItemPictures`, the market and the hub displays (`MarketLayout`, `HubDisplayArt`) all build through `PlantVisuals.Specs` -> `ApprovedPlantArt` -> `HologramForms`, so they all get the same forms. While the mesh is still replicating, `DetailReady` keeps the silhouette and `ItemPictures` retries, as for the real melons.

## Not checked in Studio
The picture is a three.js approximation (Neon drawn unlit, no bloom). One assumption to look at in Studio: that the mesh's vertex colours multiply the Neon part colour (they do for every other material). If they were ignored the melon would be a plain translucent cyan body with its rings, stem and leaf (still readable, without the stripes).

## Tests
- `docs/proposals/R158b/tests/run_holo158d.sh` (wiring + the frozen files + `check_compile_O0.sh`, then four scenarios: bake ok, no bake, one key failing, templates still loading): the mesh data is the real mesh, the forms, sizes, the real stem / leaf positions, rings, palettes, plant base untouched, builds (plant, item, coats, growth, spin), parts budget, the apple tree, the fallback.
- Updated on purpose (they pinned 3 keys / 6 templates): `docs/proposals/R149/tests/test_fruit_models.luau`, `test_fruit_mesh_fallback.luau` (10 templates, the failing-bake call numbers), `check_plants_diff.py` and `run_fruit_models.sh` (the two Mech plants may differ from the R149 base; their catalog / key / prompt / reach / socket lines must not).
