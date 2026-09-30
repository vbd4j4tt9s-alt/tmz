# R113 inventory: fast-scroll pictures, category cards outside the sheet (notes)

The PNGs here are **mock-ups**, not in-game shots. They are offline renders (three.js, and HTML for the flat icons) of the geometry and layout that the real modules produce under the Luau mock. Pack bodies are placeholder boxes, and the apple on the Fruit card is a box, because the approved meshes are not in the repo. Nothing here was run in Studio.

- `inventory_mockup_pc.png`: 1280×720.
- `inventory_mockup_phones.png`: 844×390 and 390×844. HUD boxes are drawn dashed.
- `flat_icons_mockup.png`: R112 flat icons compared with R113 flat icons.

## Files (no new instances)
- `StarterPlayerScripts/Hotbar.client.lua`: card recycling, prefetch, scroll hurry, and tab placement and pictures.
- `ReplicatedStorage/ItemPictures.lua`: parked views, a warm tier, prefetch, time-budgeted clones, `SampleKey`/`ShowSample`, and better flat icons.
- `ItemWeight.lua` is unchanged.

## 1. Fast scrolling
**Cause (R112):**
- Every card that scrolled out of the window was destroyed, which also destroyed its ViewportFrame. Each card that scrolled in was new and started as a flat icon.
- Pictures were cloned at most 3 per frame, and only after a 0.2 s sweep.
- Templates were built only for visible cards. The template LRU held 48, so bags with more looks rebuilt them.
- The view cap was 34, which the grid plus 10 slots already fill.

**Fix:**
- Cards are recycled from a pool of up to 32.
- A released view is parked unparented under its look and reattached for free. Up to 48 are parked, and looks that are not in the list are dropped first.
- A card that gets a ready look attaches it in `Show` in the same frame.
- Two rows above and below the view are kept. Holders within 240 px of the scroll clip keep warm views (36 extra).
- Every look in the bag is prefetched in inventory order, time-sliced at 2 ms per frame. The template cap is 160, and templates on screen are never evicted.
- While scrolling, the module sweeps every frame, the clone budget rises from 1.5 to 4 ms, and the build budget rises from 2 to 4 ms.
- A mesh that is still loading is retried after 2 s (was 15 s). The Studio warning is printed once per look.

**Measured in the mock** (`tests/scroll_measure.luau`, 1280×720, fling down and back). Figures are the average number of visible fallback cards per frame at 40 / 80 / 160 px per frame:

| Bag | Before | After |
|---|---|---|
| typical (128 tools, 16 looks) | 5.0 / 10.8 / 15.2 | **0 / 0 / 0** |
| heavy (120 tools, 112 looks) | 18.5 / 14.3 / 18.9 | **0 / 0 / 0** |
| heavy, bag opened at once | 18.5 / 14.0 / 18.8 | 11.9 on the first fling while it prefetches, then 0 / 0 |
| worst (232 tools, 224 looks, more than the cap) | 21.3 / 20.4 / 21.4 | 7.4 / 9.1 / 8.6 |

- The mock charges 8 µs per instance so the time budgets are exercised.
- Worst simulated work per frame is 1.3–1.9 ms after the change, compared with 1.0–2.7 ms before.
- Flat icons now use a gradient body, rim, highlight and shadow. The bat and shovel have their own shapes.

## 2. Category cards outside the sheet
`placeTabs` works from HudLayout metrics. It uses `HudLayout.HudBoxes` plus the BASE/TRACK pair when those exist, and otherwise its own copy of the boxes.

1. It tries a column of 4 square cards, or a 2×2 block, to the left of the sheet.
   - The sheet narrows so that the pair stays centred.
   - Card sizes tried are 72, 64, 56, 48 and 44 px.
   - The cards may slide down the sheet edge, or up to 48 px above it.
   - The cards must stay 4 px clear of the hub, wallet, status, travel pair, owner tile, hotbar and thumb zones.
2. The winner is chosen by grid area × card size, with the single column preferred.
3. If nothing on the left fits, the cards go in a row above the sheet, and the sheet moves down.

On short sheets (under 300 px), search and rarity move into the header.

The hotbar reserve now includes a raised phone hotbar, so sheets end above it in portrait.

`tests/test_tabs.luau` covers 26 screens and 44 layouts, with and without touch controls. Every layout places the cards outside the sheet, on screen, at 44 px or more, and clear of every HUD box. The same holds with the committed HudLayout (R110 base).

## 3. Card pictures
The cards use the same ItemPictures templates as the items:
- All: Forest seed pack
- Seeds: Watermelon seed
- Fruit: apple
- Tools: shovel

The selected card is green with a white outline. On low graphics, the new flat icons are shown instead.

## Tests (`tests/`, run with `roblox.luau` and a bundle from `mkbundle.py`)
- `test_inventory.luau`: 67/67. This is R112 plus checks that the cards sit outside the sheet with 3D pictures, a 120 px/frame scroll with 0 flat cards, and bounded parked views.
- `test_tabs.luau`: 44/44.
- R112 `test_weight`: 164/164.
- `luau-compile` passes. luau-lsp shows only the two unused locals that were already there before this change.

## Check in Studio
- Frame time on a phone while flinging. Up to about 60 ViewportFrames exist, but only on-screen ones should render; clipped warm ones should cost little.
- Memory with a big bag (160 templates plus 48 parked views).
- Whether the tab cards read well at 44 px, and the apple and seed framing.
- That cards lifted above the sheet on landscape phones look fine.
- That portrait sheets now end above the hotbar, including in the other menus that use `ChestHotbarReserve`.
