# R151 fruit fixes: no shine dots, one Verity face, every picked fruit flies into the player

Owner, live: "verity fruit also has 2 faces and some plants and fruits dont float into the players inventory. looking at watermelon remove those white dots ik its for shine but its
just really ugly do so for all similar fruits". Picture: `docs/proposals/R151/fruit_fixes.png` (before | after; approximate three.js renders, see the note on the picture).
Tests: `docs/proposals/R151/tests/run_fruit_fixes.sh` (`all` also runs the older fruit / growth / Verity / SFX suites), mutation check `mutation_fruit_fixes.sh`.

**Installer:** no new ModuleScript, nothing in `src/MANIFEST.tsv` changes. Changed scripts: the art modules (`PlantArtForest / Snow / Lava / Desert / Jungle / Crystal`, `TreeReworkData2 / 4`,
`MoonflowerSeedArt45`, `AncientWorldrootSeedArt45`, `ElderbloomSeedArt45`), `PlantVisuals`, `PlantSurfaceStyle`, `FruitMeshes149`, `VerityPlantArt`, `VerityCatalog`, `VerityGrowth`,
`SeedPackVisuals`, `PlantGrowthFx`, `HarvestArrival`, `GardenVisuals.client`, `GardenPlantRuntime` and `PlayerDataService`. Installers (`docs/releases/*install*`) are NOT rebuilt here.
No saved-data change. A server picks it up when it starts.

## 1. No white shine parts
The gloss / glint parts are removed (the parts themselves, not made transparent): Watermelon, Snow Melon, Ember Pumpkin ('Fruit gloss' x2 each), Apple (x4), Elderbloom's apples (x5),
Blueberry and Iceberry ('Berry glint' x12 each), Moon Melon ('Moon glint' x2), Verity ('Verity gloss' / 'Verity glint', x4), and the same kind of part in lists no live plant reads any more
(the Fire Pepper's 'Pepper sheen', the Ember Emperor's 'Fruit shine', and the Desert / Jungle / Crystal / Moonflower / Ancient Worldroot / Elderbloom art lists). Colours, stripes, sizes, pivots
and bounding boxes are unchanged: a plant list may carry `Skipped` (the positions of removed parts), and `PlantVisuals.Specs` / `PlantSurfaceStyle` keep the `_ArtIndex` of every later part, so
the position-based tints and growth staggering do not move. The `decor` spec flag and `GlossOut` are gone. The ripe-moment glints (R149) stay a short particle burst; no part is left behind.
The Verity PACK art (`VerityPackArt`) and all UI are untouched.

## 2. The Verity fruit has one face
`VerityPlantArt.AddFace` makes ONE Decal. Front (-Z) for everything detached from a plant: the harvest item, the hotbar, Bag and Sell pictures, the held fruit, the Index card and the harvest
flight's copy (their cameras look from -Z, the grip is on +Z). Back (+Z) for a planted crop (the plant, its regrowing fruit and its far proxy): the side of the plot the player stands on.
The Verity seed has no face of its own beyond the front. The pack keeps front and back.

## 3. Every picked fruit flies into the player
Root causes (R149's flight, every seed and every path; the harvested item was always granted, what was missing was the flight into the player):
(a) 14 seeds were refused outright (`PlantGrowthFx.Eligible`): the plants that move their own parts (Amethyst Grape, Lantern Fern, Crowncore Tree, Holo Apple Tree, Holo Melon, Nebula Vine,
Plasma Pepper, Prism Lotus, Verity) and the ones in its Skip list (Obsidian Maw, Silent Frostbell, Orbit Lotus, Supernova Bloom, Dune Starfruit);
(b) a fruit of more than 48 parts was refused (`FlightMaxParts`): Crystal Lily, Dragonfruit, Hollow Geode, Moon Melon, Pineapple, Tempest Lotus, Frost Fern (~220 parts) and the other big ones;
(c) the lowest quality tier had a budget of 0 flights, and a harvest of several fruit at once (more than 5 / 8 flights or 120 / 200 parts) refused the rest;
(d) a harvest that REMOVES the plant (10 seeds: Aloe, Date Palm, Frost Fern, Lava Lotus, Monstera, Mooncap, Obsidian Maw, Sunflower Bloom, Venom Vine, Winter Pine; the plant is the fruit, or
it is the last fruit of a plant that does not regrow) deleted the plant's model in the same refresh, so the client never saw a picked fruit; and a fruit whose model was not built here (the detail
planner left it out) had nothing to fly from;
(e) once a flight did run, `HarvestArrival.LandCrop` (the plant going away) released the inventory hold while the fruit was still in the air, and the plant's own rig kept re-posing a part a
flight had lifted.
Fix: the server marks the harvest that removes a plant (`HarvestedBy` / `HarvestedIndex`, set before the model goes; the model stays a beat, `Runtime.HarvestLinger`), the client launches a flight
from every path (the fruit's own parts, a detached copy of it, or one ball in its colour at the fruit's position; a copy is rate limited), the cap is 300 parts and the lowest tier flies two at
a time, `HarvestArrival` holds the item until the flight ends, the rigs let go first, the Hotbar flashes the slot, and observers see it too. Reduced motion and the Studio effects switch off
still skip the flight (the item is granted at once), as before.

## Checks
`run_fruit_fixes.sh` (all on the Roblox mock with the real modules; nothing here ran in Studio): static wiring; every plant of the catalog against the base commit (56 identical in every mode, the nine
with shine parts differ only by them, 334 lines); the Verity face on every side in every place (57 checks); the real `PlayerDataService` marks (201); every seed (65) through every path with the
real runtime + client + `HarvestArrival` + Hotbar (3362 checks: 137 own-parts flights, 164 copies, no balls). `mutation_fruit_fixes.sh`: 14 deliberate breaks, all caught. The R149 / R147 / R148 / R150
suites keep passing; `R147/tests/run_verity_ui.sh` was already failing before this change (the same 10 checks) and is unchanged. Tests that pinned the old look or behaviour were updated:
R147 `test_verity_art`, R148 `test_roster_art` (the Clover stands in for the Watermelon in the old-pipeline comparison), R149 `test_fruit_models`, `test_fruit_mesh_fallback`, `test_growth_fx`,
`test_growth_client`, `dump_plants` (the "~ng" twins) and their runners.

## Studio checklist
- Plant a Verity: the face looks to the path; pick it up: the fruit in the hotbar / Bag / Index has its face to the front; the held fruit shows it on the outside.
- Harvest a Watermelon, an Apple, a Blueberry: no white dots on the plant, the hotbar, the Bag, the Index.
- Harvest a single-harvest plant, a regrowing plant, the last fruit of a non-regrowing plant, a big fruit (Frost Fern), many fruit at once, and with a full bag: every fruit flies to the character,
  the slot flashes when it lands, another player in the server sees the flight.
- Lowest graphics quality and reduced motion: the item still arrives (reduced motion has no flight by design).
