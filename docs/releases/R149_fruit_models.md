# R149 fruit models: cocoa-pod / pepper style for eight fruit, and Ash Tomato variations

Design and owner decisions: `docs/proposals/R149/fruit_models.md` (approved "they all work except Lantern Fern, and Tomato: make growth variations", then "keep Amethyst Grape" and
"Ash Tomato also keeps"). Before / after picture: `docs/proposals/R149/fruit_models_built.png`. Tests: `docs/proposals/R149/tests/run_fruit_models.sh`.
**Data only.** No new ModuleScript (nothing for `src/MANIFEST.tsv` or the installer), no saved-data change, no server shutdown needed. `PlantGrowth`, `PlantVisuals` and `GardenVisuals` are untouched.

## What changed
Phase 1 of the proposal: part-based (no baked meshes), same fruit centres, sockets, radii, Height / Radius, FruitCount, ids and connectors.

| Fruit | Art module | Hotbar picture (parts) | Plant at full detail |
|---|---|---|---|
| Watermelon | `PlantArtForest.SunflowerSeed` | 42 -> 12 | 152 -> 104 |
| Snow Melon | `PlantArtSnow.SnowdropSeed` | 34 -> 13 | 152 -> 122 |
| Apple | `TreeReworkData2` | 5 -> 8 | 71 -> 83 |
| Elderbloom's elder apple | `TreeReworkData4` | 17 -> 10 | 172 -> 137 |
| Ember Pumpkin | `PlantArtLava.EmberBloomSeed` | 28 -> 25 (the small one 16 -> 25) | 148 -> 154 |
| Prickly Pear | `ApprovedPlantArt6` (both designs) | 24 -> 17 | 97 -> 82 |
| Blueberry | `PlantArtForest.BluebellSeed` | 15 -> 18 | 90 -> 94 |
| Iceberry | `PlantArtSnow.IceberrySeed` | 15 -> 18 | 90 -> 94 |

(Plant counts are for one crop id; leaf counts vary a little per crop.)
- Smooth ellipsoid bodies instead of Blocks, meridian stripe bands on the melons, 10 ribs with Neon ember grooves on the pumpkin, a three-tone barrel with a navel on the pear, bloomed berries on a stalk,
  jade / gold apple with its Neon rune. A Neon gloss patch (and the berries' glints) is `decor`: hidden on Gold / Diamond, as Verity's gloss.
- The old connector specs that reach the vine stay as they were (`Fruit stem`, `Apple hanging stem`, `Upper surface fruit attachment`). The Blueberry / Iceberry cluster keeps its `canopy` / `cd`
  link so it still rides on each crop's shrub crown. New stems are not in `PlantVisuals`' connector list, so they show in the hotbar / Bag / Index picture.
- Every new Ball / Block carries `tx="smooth"`: it draws no surface marks and `PlantSurfaceStyle`'s "first four grain / first six speckle" rules skip it, so a fruit is exactly the listed parts.
  Part names avoid "crown" / "leaf" where the part is not a leaf (the style tints those green).
- **Unchanged (owner):** Lantern Fern (`ApprovedPlantArt2`), Amethyst Grape (`PlantArtCrystal`) and the Ash Tomato's look, the R148 seeds, Verity, every other plant: byte for byte.

### Ash Tomato: four designs
`ApprovedPlantArt5` keeps its design 1 exactly and gains three variations of it (mirror / size <= the original / lean, leaves swung about their stems and a few fewer, each tomato scaled and twisted
about its socket, a shade of red and green). Same 4 fruit, 11 specs per tomato. `ApprovedPlantArt.Get` already picks `hash(crop.Id) % #designs`; **`ApprovedPlantArt.Key` gained a design suffix**
(only when 10 is not a multiple of the design count): the old key was `hash % 10`, which cannot name 1 of 4 designs, so a cache entry (plant spec cache, hotbar picture template) would have served two
designs. Keys of every other plant are unchanged.

### Known, harmless
- The art-list index (`ArtSpecIndex` attribute) of body parts listed after a redesigned fruit moves in the Watermelon, Snow Melon and Ember Pumpkin (the index is their position in the list).
  It only staggers when a leaf appears during growth.
- Apple tree: two of the four hanging stems end about 0.3 - 0.5 studs under the canopy ellipsoid (as in the base; the R134 box check passes). Elderbloom's two trunk "living runes" are flagged by the same checker in the base too.
- `PlantVisuals.AssetRevision` is not bumped (it only matters inside a running client).

## Tests
`sh docs/proposals/R149/tests/run_fruit_models.sh`: files against the base (only the 8 art / key modules differ under `src/`), a regression diff of EVERY catalog plant against the base commit
(2718 lines identical, the 8 fruit and the Ash Tomato the only differences, a design-1 Ash Tomato crop identical in every mode), `test_fruit_models.luau` (1411 checks) and the R134 floating check
(34 plants, 68 fruit scenes: 0 new floating parts). `mutation_check.sh` breaks five things in a copy and shows each is caught. The art is regenerated from `docs/proposals/R149/tools/` (`port_fruit_models.sh`).

## Check in Studio
- Hotbar / Bag / Index pictures of the eight fruit, plain, Gold and Diamond: the gloss patch on the plain coat, translucent bloom / snow cap ordering, Neon ember grooves and runes.
- A garden of Blueberries / Iceberries: clusters on the crowns, still attached when the crown varies; Prickly Pear on both cactus designs; Apple trees with the 16 turns; Ember Pumpkin on the ground.
- Ash Tomato: plant several, check the four shapes, the leaves, harvest prompts on the fruit, and the hotbar pictures (four shades of red).
- Growth from seed to ripe and regrowth of a picked fruit; far (distant) plants; weather effects around the new shapes.
