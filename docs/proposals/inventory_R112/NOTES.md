# R112 visual inventory + kg sizes (notes)

`inventory_mockup.png` is a **mock-up**: an offline three.js render of the geometry that the real art modules built under the Luau mock. Pack bodies are placeholder boxes because the approved pack meshes are not in the repo. Nothing here was run in Studio.

## Files
- NEW `ReplicatedStorage/ItemWeight` (ModuleScript). This is the only kg formatter. It is display-only.
- NEW `ReplicatedStorage/ItemPictures` (ModuleScript). Makes item pictures for cards and slots.
- `StarterPlayerScripts/Hotbar.client.lua`: picture cards, stacks, kg, green sheet, left category column.
- `ReplicatedStorage/HarvestSellMenu`: "1.5× size" is now shown as kg.
- `MANIFEST.tsv`: two new rows.

## Weight
`kg = base × saved size multiplier`. It shows one decimal under 10 kg, drops a trailing ".0", and shows whole numbers from 10 kg up with thousands separators (e.g. "1,250kg").
- Fruit base: 0.8 × (average `PlantCatalog.FruitRadii`)². This gives 0.75 kg to 311 kg across all species.
- Seed base: 0.1 × √(fruit base), clamped to 0.1–1 kg.
- Pack base by tier: 1 / 1.25 / 1.5 / 2 / 2.5 / 3 kg, Limited 3 kg, Void 4 kg.

For RarePackRules, use `require(script.Parent.ItemWeight).Text('Pack', variant, size)`.

## Pictures and performance
- **Templates.** There is one template per look, cached with LRU (48 max). Templates are built by the game's own code:
  - packs: `SeedPackVisuals.Bag`
  - seeds: `SeedPackVisuals.Seed` (falls back to the `SeedArt` library)
  - fruit: `HarvestPresentation.Build`
  - bat, loot and other gear: the tool's own visible parts
  - shovel: `ShovelModel.Build`
- **Static copies.** Effects, lights, joints and CollectionService tags are stripped, parts are anchored, and nothing is animated.
- **Viewports.** Only visible holders get a ViewportFrame, which holds a clone of the template.
  - Hotbar slots come first, then grid cards from top-left.
  - Limits: 34 viewports, 6000 parts, 3 clones per frame.
  - Builds are time-sliced to 2 ms per frame.
  - A picture that goes off-screen is released after 3 s.
- **Flat icons.** Low graphics (FastMode, ClientFxBudget tier 1, or StudioPlantEffects set to low/off), an item over budget, or a failed build (retried after 15 s) all show a flat icon instead. The icon is a few Frames coloured from the seed/biome art data.

## Behaviour
- **Stacks.** Identical packs, seeds and fruit share one card or slot with an `xN` badge. The equipped copy represents the stack. Tools are never stacked.
- **Slot names.** Each slot's `ItemName` still shows exactly `GardenDisplayNames.Tool(...)` for the tutorial. It is not text-fitted. It shrinks or wraps only visually.

## Tests (`tests/`, run from a folder with `roblox.luau` and a bundle built by `mkbundle.py`)
- `test_weight.luau`: 164 checks, 0 failures.
- `test_inventory.luau`: 56 checks, 0 failures. It runs the real Hotbar with real ReplicatedStorage modules and covers:
  - every item kind, including bat, loot and shovel
  - stacks
  - open, filters, search, rarity, scrolling and budgets
  - equipping by card, slot and number keys
  - drag onto the hotbar
  - the tutorial name match
  - low graphics
  - leak and tag checks
  - teardown

## Check in Studio
- How the ViewportFrames look: framing, lighting, how Diamond glass reads.
- Frame time with the panel open on a phone.
- Two-line slot names at 44 px.
- That meshes still loading show a flat icon, then the picture on retry.
- That stacking feels right.
