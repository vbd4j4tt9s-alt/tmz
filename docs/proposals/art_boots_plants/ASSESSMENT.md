# Chest Chase art assessment: boots and plants (2026-09-29)

Scope: read-only look at the live scripts (`/home/user/tmz/src`, R107) and the place file, a boot redesign prototype, and a
feasibility plan for plant polish. Nothing here was run in Roblox Studio. Nothing under `src/` was edited.

All images are in `renders/`. They come from the **real Luau modules** run in the Luau CLI with a small Roblox shim
(`shim.luau`), so the geometry is what the code builds. Lighting and Neon bloom are a three.js approximation of Roblox.
The R15 leg sizes are approximate block-rig values (Foot 1x0.3x1, LowerLeg 1x1.1x1, UpperLeg 1x1.2x1).

| File | What it shows |
|---|---|
| `renders/current_r15_sheet.png` | Current boots, all 5 tiers: side, 3/4 front, 3/4 back |
| `renders/proposed_r15_sheet.png` | Proposed boots, same views |
| `renders/compare_now_vs_new.png` | Current vs proposed side by side (3/4 front) |
| `renders/action_now_vs_new.png` | Mid-run pose from the usual behind/above camera |
| `renders/current_shop.png`, `renders/proposed_shop.png` | Shop ViewportFrame preview via the real `ShopProductArt.Build` |
| `renders/current_r6.png`, `renders/proposed_r6.png` | R6 rig |
| `renders/current_plants.png` | 12 current plants from the real `PlantVisuals.Build` (includes EditableMesh plants) |

---

## 1. Boots today

**How they are built.** All code-built Parts, no meshes, no images.

- `ReplicatedStorage/RunnerBootArt` returns spec tables (`Name, Size, Frame, Color, Material, Shape='Wedge'|nil`):
  `Specs` (foot), `ShinSpecs` (lower leg), `KneeSpecs` (upper leg). `Create(character, parent, biome, accent)` makes
  `Part`/`WedgePart`s, welds them (`WeldConstraint`, Massless, no collision/touch/query, no shadow) to
  `LeftFoot/RightFoot` + `LowerLeg` + `UpperLeg` (R15) or to `Left Leg/Right Leg` (R6). Returns the number of legs dressed.
- Server: `EconomyService:ApplyCosmetics` calls `Create(character, folder, accessory.Biome, accessory.Color)` into
  `character.ChestChaseCosmetics`; `BootCount == 2` also enables `BootGroundTheme` (ground ribbons and footprints in
  `RunnerTrailEffects`, which raycast from the foot part, not from boot parts).
- Shop: `ShopMenu` -> `ShopViewport.Attach` -> `ShopProductArt.Build`, which calls the same `Specs/ShinSpecs/KneeSpecs`
  with fixed sizes (foot `1x0.7x1.8`, shin `1.05x1.45x1.05`, knee `1.1x1.4x1.1`), so the shop shows the wearable geometry.
  `ShopProductArt.Build` only knows `Shape=='Wedge'`; anything else becomes a block.

**Tiers** (`Config.ShopCatalog.Accessories`; the look is chosen by `Biome`, not by id):

| # | Id | Name | Biome | Color | Luck |
|---|---|---|---|---|---|
| 1 | RunnerHalo | Sand Boots | Desert | 233,192,113 | x1.5 |
| 2 | StormCrown | Frost Boots | Snow | 190,233,251 | x2 |
| 3 | LavaBoots | Lava Boots | Lava | 255,140,53 | x2.5 |
| 4 | CrystalBoots | Crystal Boots | Crystal | 193,152,250 | x3 |
| 5 | MythicOrbit | Electric Boots | Storm | 177,232,255 | x3.5 |

(Forest/Jungle palettes exist in the module but no product uses them.)

**What is wrong with the current look** (see `current_r15_sheet.png`):
- Knee-high armoured blocks: a full-length shaft over the whole lower leg plus a metal knee guard. Reads as "armour", not "sneaker/boot".
- 1.10-1.30x leg width, so on R15/R6 (legs touch) the two boots merge into one wide block.
- Foot is barely longer than the leg (1.2x on a 1x1 R15 foot), so the side profile is a square.
- Dark soles with no accent; the sole is what the behind camera sees most while running (`action_now_vs_new.png`).
- 19-21 parts per leg (38-42 per player).

## 2. Boot redesign (prototype)

**File:** `RunnerBootArt.proposed.lua` (drop-in replacement for `ReplicatedStorage/RunnerBootArt`).
`luau-analyze` is clean in nonstrict mode once the Roblox globals are stubbed (plain `luau-analyze` only reports
"Unknown global" for Vector3/CFrame/Color3/Enum/Instance, same as the current file). `luau-compile` passes.
It ran through `Create()` on mock R15, R6 and mid-run rigs (returns 2), and through the real `ShopProductArt.Build`.

**Design language:** chunky sneaker-boot. Dark outsole with toe spring, a light midsole with a stripe that wraps
all four sides (one part), a colored tread plate under the sole (seen when the foot kicks back), a tapered toe box and
sloped vamp that extend about 0.4 studs past the foot, a heel counter wedge, a shorter shaft (50-66% of the lower leg, taller for higher tiers),
a cuff band, a tongue that pokes above the cuff, and a pull tab. No knee pieces. Block and Wedge parts only.

| Tier | Look | Glow (Neon) | Parts/leg (now -> new) |
|---|---|---|---|
| Sand | tan upper, brown toe/heel overlays, cream midsole, gold stripe, laces | none | 19 -> 16 |
| Frost | icy white upper, steel-blue overlays, big white fur cuff, glass ice toe cap, laces | none (glass) | 19 -> 17 |
| Lava | black upper, orange heel/tongue/strap | midsole stripe, tread, pull tab, toe vent, 2 magma seams | 21 -> 17 |
| Crystal | purple upper, silver metal toe/heel/strap | stripe, tread, pull tab, cuff ring, crystal cluster on the outer ankle | 20 -> 17 |
| Electric | deep blue upper, white toe/heel/tongue/strap | stripe, tread, pull tab, toe bolt, cuff ring, 3-feather wing on the outer ankle | 21 -> 19 |

Per player: 32-38 parts instead of 38-42.

**API compatibility:**
- Same four functions, same arguments, same return values; `Create` code path is the old one plus a side filter.
- New optional spec field `Side = 1 | -1`. `Create` keeps only the outer-side ornament on each leg (Right leg: +X, Left: -X),
  so ankle wings/crystals never poke into the other leg. `ShopProductArt` ignores the field, so the shop shows ornaments
  on both sides of each boot (visible in `proposed_shop.png`, looks fine).
- `KneeSpecs` now returns `{}` (both callers iterate, so this is safe; knee guards disappear on purpose).
- `accent` (the product Color) still tints the non-glowing trims. Neon parts use a saturated per-look `Glow` color
  instead, because the pale product colors turn almost white as Neon.
- The module no longer has the local `palettes`/`trims` tables; nothing outside read them.

**Risks / unverified:**
- Not run in Studio. Real avatars vary (Rthro, scaled bodies); geometry scales with the part sizes like the old module,
  but only block-rig proportions were checked visually.
- The sole and tread sit 0.04-0.06 studs below the foot bottom (old sole: 0.04). Hidden by the floor when standing;
  on glass floors the Lava/Crystal/Electric tread glows from below.
- Legs touch on block rigs, so the shafts (1.04x) still meet in the middle from the front; the tongues and toes separate them visually.
- Hand-off: needs one script replacement (the owner's hash-guarded installer format works; only `RunnerBootArt` changes).
  New servers pick it up; boots rebuild on respawn/equip.

**Further option (not built):** a smooth, truly "mesh-like" boot is possible without uploads by baking one
vertex-colored mesh per tier through the same EditableMesh path the plants use (section 3). That would need
`ShopProductArt.Build` to learn a MeshPart path, so it is not a drop-in.

## 3. Plants today

**Pipelines** (`ApprovedPlantArt.Get` precedence: Mech > Rarity45 > TreeRework > Approved index > PlantArt<Biome>):

| Source | Species | Typical parts |
|---|---|---|
| `MechArt` + `MechPlantData` (+ `HologramForms`/`HologramProjection`) | 6 mech/holo plants (MechCatalog) | 21-427 |
| `RarityPlantArt` -> `*SeedArt45` | 12 (flowers, agave, lotus, geode...) | 67-194 |
| `TreeReworkArt` -> `TreeReworkData1..12` | 12 trees | 40-193 |
| `ApprovedPlantIndex` -> `ApprovedPlantArt1..21` | 21 entries (some overridden by the rows above) | 32-220 |
| `PlantArtForest/Jungle/Desert/Snow/Lava/Crystal/Storm` | fallback for the rest of the 56 | 13-145 |

- Everything is **data tables of primitives** (`s` shape, `z` size, `c` CFrame, `k` color, `m` material, `g` fruit group,
  `tx` surface detail). `PlantVisuals.Part` turns them into Parts; a few shapes expand into several parts (LeafBlade = 4
  wedges + veins, Crystal = prism + 8 corner wedges, Crown, Shrub...). Ellipsoids use a built-in Sphere `SpecialMesh`
  (no asset). `PlantSurfaceStyle` adds small detail parts (grain, bark, frost...). Shape counts across all data:
  Wedge 1912, Cylinder 1496, Block 1280, CornerWedge 1222, Ball 1074, CylinderX 603, LeafBlade 434, Petal 248, Crystal 202.
- **EditableMesh is already in production.** `ApprovedPlantMeshes` bakes vertex-colored triangle meshes on the server
  (`AssetService:CreateEditableMesh` -> `CreateDataModelContentAsync` -> `CreateMeshPartAsync`) from 50 data modules in
  `ServerStorage/ApprovedPlantMeshData1..50` (index: `ServerStorage/ApprovedPlantMeshIndex`), stores templates in
  `ReplicatedStorage/ApprovedPlantMeshTemplates`, and clients clone them. Used by Fire Pepper, Prism Pepper
  (PrismOrchidSeed), Ancient Worldroot (AmberHeart + sepals) and Cocoa (FlutedCocoa). No uploads involved.
- Client builds plants (`GardenVisuals`, `DistantGardens`) under `PlantDetailPlanner` (1400 parts / 24 full-detail models;
  850 / 12 on low) with distant proxies (`DistantPlantView`).
- The place does contain 699 uploaded MeshParts (keepers, seed packs), so the owner has uploaded meshes before.

**How they look** (`current_plants.png`): the two EditableMesh peppers are clearly the most polished (smooth, curved,
shaded). Part plants range from decent (Tiger Orchid, Glacier Lotus, Obsidian Maw) to crude: the common Watermelon is
two striped cubes, Strawberry is a green slab, Apple fruit are red cubes. Compared with the reference style (big, chunky,
high-contrast, glowing accents): stems are thin, values are mid-range greens, and Neon is rare (mostly Mooncap, Storm plants).

## 4. What is feasible for plants from code, and a suggested plan

We cannot upload assets from here. Three levers remain, in order of cost:

**Phase 1 - data/style pass on existing parts (code only, low risk).**
Per-rarity palette and contrast (darker bases, brighter tips, saturated fruit), chunkier proportions (thicker stems,
bigger fruit, via `BaseScale` and spec sizes), rounded fruit where cubes look wrong (Block -> ellipsoid is a one-field
data change), rarity glow accents (Neon veins/cores for Legendary and up), a consistent soil mound. All reviewable
offline: `plant_harness.py` now runs the real `PlantVisuals.Build` and renders it, so every change can be checked as PNGs
before it goes to the owner. Part counts must stay inside the planner budget.

**Phase 2 - generated smooth meshes through the existing EditableMesh path (code + generated data, medium risk).**
Generate lathe fruit, lofted leaves/petals, tapered stems with vertex-color gradients offline (Python), emit
`ApprovedPlantMeshData` modules and index entries, and reference them with `s='ApprovedMesh'` specs. This is how the
peppers were done, and it can also cut part counts (one mesh instead of dozens of parts; keep animated and harvestable
groups separate). Start with the weakest common/uncommon species. Check first in a live server that
`ReplicatedStorage.ApprovedPlantMeshTemplates` has `Ready=true` and `FailureCount=0`; if EditableMesh is not
available to the published game, the four mesh plants are already broken and this phase is blocked. Limits: vertex
colors only (no textures), per-server bake time and mesh memory.

**Phase 3 - hero/creature plants like the reference screenshot (needs a 3D artist).**
Faces, teeth, bulbous organic forms and painted textures need hand-made models (Blender) with textures, uploaded by the
owner through Studio (MeshPart + SurfaceAppearance or TextureID). Code can then swap them in by asset id, keep fruit
sockets and harvest groups, and add glow and motion. This is the only route to match the reference quality; procedural
code will get "clean stylized", not "hand-crafted creature".

Suggested order: Phase 1 on the 8-10 most-seen (common/uncommon) species first, review renders with the owner, then
Phase 2 for the ones that still look primitive, and Phase 3 only for a few top-rarity showcase plants.

## 5. Reproducing the renders

```
cd <scratchpad>/art
python3 gen_harness.py current proposed      # runs RunnerBootArt (+ ShopProductArt) in Luau, writes scene_*.json
python3 plant_harness.py [SeedIds...]       # runs the real PlantVisuals.Build (default: the 12 in the PNG), writes scene_plants.json
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node render.mjs current proposed plants
```
Plant mesh vertex data was pulled from the .rbxl with `dump.py` + `q2.py ServerStorage/ApprovedPlantMeshIndex ServerStorage/ApprovedPlantMeshData<N>...` (saved as `extract_*.lua`).
`render.mjs` uses the preinstalled Chromium at `/opt/pw-browsers/chromium-1194` (the npm Playwright build expects a
newer one, so the path is set explicitly).
