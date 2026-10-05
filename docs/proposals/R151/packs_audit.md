# R151 pack models audit: dislocated parts, connection, "the same mesh and shape"

Owner (verbatim): *"look into refining and loosing the packs that we currently have; ensure there aren't any dislocated parts; the packs are all using the same mesh and shape and so on; make sure everything is connected for the packs"*.

Picture: `packs_audit.png` (every one of the 42 ordinary designs front and side, the Void / Mech / Verity packs, the fixed defects before -> after, defects circled). It is a **three.js preview, not a Studio screenshot**: the 115 pouch MeshParts of the templates are uploaded assets (MeshId only) whose vertices and printed vertex colours are **not in the place file and cannot be downloaded here**, so each is drawn as a stand-in rounded pouch of its Size box. Everything else (seal, tear strips, Void, Mech, Verity, pads) is drawn exactly as the real modules build it. The fixes change only the giant packs, the Void and the pads, so the other designs look the same before and after (the picture shows the fixed ones before -> after).

Everything below was run on the Roblox mock with the **real** modules / client scripts of this checkout and the **real** pack templates read out of the owner's place (`sapkeyver.rbxl`: 42 designs, 115 MeshParts, MeshIds, Sizes, PackLocalFrames). Nothing was run in Studio.

## 1. The short version

| Question | Answer |
|---|---|
| Dislocated / floating parts? | **Two found and fixed** (giant packs' seal / strips, the Void's front print; below), plus one z-fighting defect on the pads. Nothing else floats: every part of every one of the 42 designs, the Void, Mech and Verity packs and the 7 pads touches its body through touching parts (0 floating, bounding-box reading: see section 6 for what the box reading cannot see). |
| Is everything connected? | **Yes, nothing to fix.** In 2,190 built packs (78 stage x variant combinations x 5 sizes x 3 coats; on the ground, held by an R15 and an R6 carrier) every part is anchored together (world) or reaches the carrier through WeldConstraints / Motor6Ds (held); nothing unwelded, nothing anchored in a held pack, no foreign joint, every Mech servo's C0 is its rest frame; after 120 simulated frames of a running / turning / jumping carrier no part is left behind (worst 1e-15 stud); the real `SeedPackRender` hovering the anchored packs for 120 frames keeps every part on its root. |
| Same mesh and shape? | The ordinary packs are all built by **one code path from one kind of template**, and every context builds the **identical parts at the identical size and pivot** (checked part by part, 172 comparisons). But they do **not** share one pouch mesh: the 42 designs have 42 distinct uploaded pouch meshes (the print is in each mesh's vertex colours), 30 of them on the standard 1.97 x 2.06 footprint, 5 wider and 11 taller (tier-5/6 "crowned" designs). Not changed: unifying them would be a different look. Section 4 lists every difference and why; section 5 has the options for the Void / Mech / Verity packs. |
| Verity as the standard pouch, neutral? | **Not feasible from the place file**: it holds the MeshId (`rbxassetid://75504658868908` for Storm_02) and the Size, not the vertices. The routes that could work (section 5, 2 - 4) all need Studio or an asset permission I cannot test. |

## 2. Findings and fixes

| # | Pack | Context | Defect | Fix |
|---|---|---|---|---|
| 1 | **every giant pack (> 10x: 15x / 20x / 25x)**, all 78 stage x variant combinations incl. Void, Verity, legacy Small / Standard / Grand | on the ground, dropped, held, the opening copy | `GiantVisualSafety` fades every `GiantVisualPart` near the camera and `SeedPackRenderer` / `VerityPackArt` / `EclipsePackArt` / `SpecialPackArt89` tag the pouch's parts, but **the seal and the 8 tear strips (built in `SeedPackVisuals.Bag`) were never tagged**: close to a giant the pouch faded away and nine solid bars stayed behind in the air. 9 of the pack's parts, 156 of 156 giant packs in the matrix. | `SeedPackVisuals.Bag` tags the seal and strips when `packSize > 10` (the same rule the pouch parts use). |
| 2 | **Void pack** | every context | The front / back print's **stars (6 blocks a side), specks (4) and rune strokes (12) sat .031 in front of the pouch's front face**: thin blocks .01 deep, .016 out, away from the nebula discs which reach to .016. 40 of the 44 parts of a Void pack were past the .03 touch tolerance (the largest gap of the print; the real, curved pouch surface is further back at the corners than its box, so there it is more). | `EclipsePackArt.Specs`: the same front face (.021 out), **backed to .026 deep**, so they reach .015 from the pouch like the discs do. Nothing changes on the front. |
| 3 | **the pad under a world pack** (`SeedPackVisuals.Platform`, "track pad"): Forest, Jungle, Snow | on the ground | Moss patches (6) and the ice glaze (1) stood .018 / .019 over the pad's top face: the **z-fighting band of `tools/zfight.py`** (same-way faces .02 or less apart). 7 pairs. | Patches .028 thick (was .022), glaze .030 (was .024): their tops are .021 / .022 over the pad. A 6 thousandths of a stud change. |

Counts by kind (before -> after, this audit's matrix): giant parts not fading **1,404 -> 0** (156 packs); floating parts **40 -> 0** (1 pack, the Void); z-fighting pairs **7 -> 0** (3 pads); unwelded / unanchored / left-behind parts **0 -> 0**; parts not matching across contexts **0 -> 0**; Bounds overshoots **0 -> 0**.

`compare_fingerprints.py` runs the same 1,574 packs (every part, every property, joints, tags, attributes) on the base commit (`c1e8829`) and on this checkout: 1,147 are identical; the 427 that differ differ **only** in these three things (tags on the seal / strips of the 25x packs, the Void's backed stars / specks / runes (44 parts of each of its packs), the pads' moss / ice).

## 3. Not defects, but you should know

* **Tear strips and the tall designs (needs a look in Studio).** The plain seal sits at -1.12 and the 8 tear strips at 1.11 (pack units), flush with a standard pouch that spans -1.04 .. 1.02. **11 designs' pouch rises above 1.07** (Forest_05, Desert_05, Desert_06, Lava_03..06, Crystal_05, Crystal_06, Jungle_05, Jungle_06; top 1.11 .. 1.81), so their strips lie **inside the pouch's box**, not on its top edge (and 2 of them, Forest_05 / Desert_06, reach .06 .. .07 below the seal's top). If the pouch is solid there, the strips are simply hidden; they would show only through a Diamond coat's .10 transparency (a bar floating inside the glass pouch), and the opening animation tears from `TearLipY` = 1.11 for every design, i.e. inside the body of these 11. The box cannot tell which. Not moved (it would add a visible strip to 11 designs and move the opening's tear line); see section 6.
* **The Void's halo and debris float on purpose.** 23 halo segments (`EventHorizon*`) and 3 debris blocks are welded to the pack (they pass the connection checks) but hang .1 - .3 unit off the pouch and spin: the R122 "event horizon". Blue in the picture. Option: leave; or hang the ring on four spokes.
* **Layered print stacks (z-fighting by the R149 rule, not changed).** `tools/zfight.py` counts same-way faces up to .02 apart. The Void's nebula / singularity discs (.004 - .018 apart, 20 pairs) and the Mech's stepped reactor / piston print (.010 - .016 per step, 12 pairs) are in that band. They are shallow printed layers of owner-approved designs; flicker needs less than about .0003 stud at 50 studs on a 24-bit depth buffer (`D^2 / (near x 2^24)`), and a >= .02 spacing would thicken the print by about .04 stud and move every detail on top. Listed by `check_packs.py` (32 pairs), not counted, any coplanar pair or any pair outside those named layers still fails.
* **Mesh layers.** 54 pairs of MeshPart boxes in the Snow / Desert_06 / Lava_02 / Storm_04 / Storm_05 templates have coplanar or near-coplanar box faces (Storm_05 `ApprovedMesh02` / `ApprovedMesh03`: 0.0000 - .0008). They are the layered shells of one design (glass over pouch, neon over metal); two boxes' faces say nothing about two meshes' surfaces, so they are listed, not counted.
* **The pack hovers over its pad** by design: more than 0 and at most .6 unit between the pack's lowest point and the pad's top (`SeedPackVisuals.Platform`, checked for all 84 pads).
* **Weather traits add no part.** All 8 trait combinations leave the pack's parts untouched (48 packs compared); the trait is an attribute and a `GardenItemFX` tag on the root. The weather effect's size follows the pack's **size** (`ChaseService` / `ChestService` pass `PackSize`), not its biome / tier scale (.86 - 1.19) nor the tall / wide designs, so its rings are up to 19% smaller than a Storm Pack04 (pack scale 1.19) and well inside Lava_06 (3.07 studs wide). Option: pass `VisualScale`. Not changed (it changes how the effect looks).
* **The Mech pack's body shows Forest_01's print.** Its pouch is Forest_01 painted (231,237,239); a part's Color only multiplies the mesh's vertex colours (the R149 finding), so where the armour panels do not cover it the Forest_01 print shows through, lightly tinted. (The Void's (9,5,20) swallows it.) Not verifiable offline.
* **No "King" / "Crowncore" pack exists.** King is a seed rarity (the Crowncore Tree); the Void pack gives it. There is no pack model of that name to audit.

## 4. Consistency: which packs are the standard pouch

All 42 designs go through **one** builder (`SeedPackVisuals.Bag` -> `SeedPackRenderer.BuildStandard`): a hidden `VisualRoot`, the `BottomSeal`, 8 `TearStrip`s, then the template's MeshParts in a `PackGeometry` folder at their `PackLocalFrame`, all at `VisualScale = tier BagScale x biome scale x size`. Ground, dropped, held (R15 and R6), hotbar / Bag / Index / shop picture, the opening copy, the market shelf, the mystery pedestal (x1.7), the title-screen and Mech viewports all call it, and build **the same parts at the same size and pivot** (`test_packs.luau` section 5: every part's size, position and rotation in the root's frame / scale equal to 1e-5; the pivot is the standard pouch's centre for every design, so every pack stands on the same bottom line, within .07 unit for the two designs that reach lower).

What differs between ordinary designs (none of it a defect):

| Class | Designs | Count | What |
|---|---|---|---|
| standard footprint | Forest_01-04,06, Desert_01-04, Snow_01-06, Lava_01-02, Crystal_01-04, Jungle_01,02,04, Storm_01-06 | 30 | pouch 1.97 (2.025 at most) x 2.06, top 1.02, bottom -1.04: the seal / strips are flush; 1 - 16 meshes (the Snow glass layers) |
| wider | Jungle_03 (2.09), Lava_03 (2.10), Lava_04 (2.30), Lava_05 (2.60), Lava_06 (2.96) | 5 | the crowned / winged tier-5 and tier-6 pouches |
| taller | Forest_05, Desert_05, Desert_06, Lava_03-06, Crystal_05, Crystal_06, Jungle_05, Jungle_06 | 11 | top 1.11 - 1.81 (see section 3) |

Final size at 1x ranges **1.69 x 1.77 studs** (Forest Pack01) to **3.07 x 2.96** (Lava Pack06): tier scale `BagScale` = .86 / .92 / 1.00 / 1.06 / .896 / .96 for Pack01 .. Pack06 (Pack05's meshes are the tall ones; the code gives no reason for its lower scale) and biome scale 1.00 Forest, 1.02 Jungle, 1.04 Desert, 1.06 Snow, 1.08 Lava, 1.10 Crystal, 1.12 Storm. Legacy `Small` / `Standard` / `Grand` use designs 1 / 2 / 3 at .78 / 1.00 / 1.25. The mystery pedestal's locked silhouette is that biome's Pack01 painted (8,8,12), same parts. The per-design table:

| Design | pouch W x H x D (pack units: the template at scale 1) | top / bottom | meshes | size at 1x (studs) | class |
|---|---|---|---|---|---|
| Forest_01 | 1.970 x 2.060 x 1.029 | +1.020 / -1.040 | 1 | 1.69 x 1.77 | standard |
| Forest_02 | 2.015 x 2.060 x 1.051 | +1.020 / -1.040 | 1 | 1.85 x 1.90 | standard |
| Forest_03 | 1.970 x 2.060 x 1.159 | +1.020 / -1.040 | 1 | 1.97 x 2.06 | standard |
| Forest_04 | 1.970 x 2.060 x 1.112 | +1.020 / -1.040 | 1 | 2.09 x 2.18 | standard |
| Forest_05 | 1.970 x 2.215 x 1.061 | +1.111 / -1.104 | 2 | 1.77 x 1.98 | TALL LOW |
| Forest_06 | 1.970 x 2.060 x 1.066 | +1.020 / -1.040 | 2 | 1.89 x 1.98 | standard |
| Desert_01 | 1.970 x 2.060 x 0.986 | +1.020 / -1.040 | 1 | 1.76 x 1.84 | standard |
| Desert_02 | 1.970 x 2.060 x 1.061 | +1.020 / -1.040 | 1 | 1.88 x 1.97 | standard |
| Desert_03 | 1.980 x 2.060 x 1.201 | +1.020 / -1.040 | 1 | 2.06 x 2.14 | standard |
| Desert_04 | 1.970 x 2.060 x 1.147 | +1.020 / -1.040 | 1 | 2.17 x 2.27 | standard |
| Desert_05 | 1.970 x 2.483 x 1.150 | +1.444 / -1.040 | 2 | 1.84 x 2.31 | TALL |
| Desert_06 | 1.970 x 2.232 x 0.966 | +1.120 / -1.112 | 3 | 1.97 x 2.23 | TALL LOW |
| Snow_01 | 1.970 x 2.060 x 0.844 | +1.020 / -1.040 | 4 | 1.80 x 1.88 | standard |
| Snow_02 | 1.970 x 2.060 x 0.942 | +1.020 / -1.040 | 5 | 1.92 x 2.01 | standard |
| Snow_03 | 1.970 x 2.060 x 0.844 | +1.020 / -1.040 | 6 | 2.09 x 2.18 | standard |
| Snow_04 | 1.970 x 2.060 x 0.844 | +1.020 / -1.040 | 10 | 2.21 x 2.31 | standard |
| Snow_05 | 1.970 x 2.060 x 0.844 | +1.020 / -1.040 | 13 | 1.87 x 1.96 | standard |
| Snow_06 | 1.970 x 2.060 x 0.844 | +1.020 / -1.040 | 16 | 2.00 x 2.10 | standard |
| Lava_01 | 1.970 x 2.060 x 0.976 | +1.020 / -1.040 | 1 | 1.83 x 1.91 | standard |
| Lava_02 | 2.025 x 2.060 x 0.933 | +1.020 / -1.040 | 2 | 2.01 x 2.05 | standard |
| Lava_03 | 2.104 x 2.264 x 1.125 | +1.224 / -1.040 | 1 | 2.27 x 2.45 | TALL WIDE |
| Lava_04 | 2.304 x 2.492 x 1.120 | +1.452 / -1.040 | 2 | 2.64 x 2.85 | TALL WIDE |
| Lava_05 | 2.597 x 2.702 x 1.121 | +1.662 / -1.040 | 2 | 2.51 x 2.61 | TALL WIDE |
| Lava_06 | 2.963 x 2.855 x 1.122 | +1.815 / -1.040 | 2 | 3.07 x 2.96 | TALL WIDE |
| Crystal_01 | 1.970 x 2.060 x 1.087 | +1.020 / -1.040 | 1 | 1.86 x 1.95 | standard |
| Crystal_02 | 1.970 x 2.060 x 0.906 | +1.020 / -1.040 | 3 | 1.99 x 2.08 | standard |
| Crystal_03 | 1.970 x 2.060 x 1.168 | +1.020 / -1.040 | 1 | 2.17 x 2.27 | standard |
| Crystal_04 | 1.970 x 2.060 x 1.179 | +1.020 / -1.040 | 1 | 2.30 x 2.40 | standard |
| Crystal_05 | 1.970 x 2.814 x 1.200 | +1.774 / -1.040 | 2 | 1.94 x 2.77 | TALL |
| Crystal_06 | 1.970 x 2.814 x 1.038 | +1.774 / -1.040 | 4 | 2.08 x 2.97 | TALL |
| Jungle_01 | 1.970 x 2.060 x 1.063 | +1.020 / -1.040 | 1 | 1.73 x 1.81 | standard |
| Jungle_02 | 1.985 x 2.060 x 1.065 | +1.020 / -1.040 | 1 | 1.86 x 1.93 | standard |
| Jungle_03 | 2.086 x 2.060 x 1.177 | +1.020 / -1.040 | 1 | 2.13 x 2.10 | WIDE |
| Jungle_04 | 1.970 x 2.060 x 1.138 | +1.020 / -1.040 | 1 | 2.13 x 2.23 | standard |
| Jungle_05 | 1.970 x 2.624 x 1.102 | +1.584 / -1.040 | 3 | 1.80 x 2.40 | TALL |
| Jungle_06 | 1.970 x 2.624 x 1.111 | +1.584 / -1.040 | 3 | 1.93 x 2.57 | TALL |
| Storm_01 | 1.970 x 2.060 x 0.906 | +1.020 / -1.040 | 1 | 1.90 x 1.98 | standard |
| Storm_02 | 1.970 x 2.060 x 1.004 | +1.020 / -1.040 | 1 | 2.03 x 2.12 | standard |
| Storm_03 | 1.998 x 2.060 x 0.968 | +1.020 / -1.040 | 1 | 2.24 x 2.31 | standard |
| Storm_04 | 1.970 x 2.060 x 0.998 | +1.020 / -1.040 | 3 | 2.34 x 2.45 | standard |
| Storm_05 | 1.970 x 2.060 x 0.998 | +1.020 / -1.040 | 3 | 1.98 x 2.07 | standard |
| Storm_06 | 1.970 x 2.060 x 0.999 | +1.020 / -1.040 | 3 | 2.12 x 2.21 | standard |

### The special packs

| Pack | Pouch | What it is | Connected? |
|---|---|---|---|
| **Void** (`EclipseReliquary`) | the Forest_01 pouch (every stage), painted (9,5,20) | + 180 design parts (galaxy arms, rings, eye, stars, runes, the 23-segment halo and 3 debris blocks) | all welded; the 54 spinning parts carry `VoidSpin` + a pivot + a rest frame |
| **Mech** (`MechLimited`) | the Forest_01 pouch, painted (231,237,239) | + 174 parts: 5 x 6 fitted armour panels per side, pistons, reactor, turbine; 34 move | held: `MechServo` Motor6D per moving part (C0 = rest frame, C1 = identity); world: anchored, no motors |
| **Verity** (`VerityReliquary`) | **none**: nine plain yellow parts (R149) | a flat-faced sachet: face block + blocks above / below + 2 rounded edges + 4 slanted slabs; the face is a Decal on its own Front / Back | all welded; footprint = the Storm_02 pouch's box (1.97 x 2.06), depth 56% of it |

## 5. Options for the special packs (nothing changed)

**Verity: the standard pouch with a neutral copy?** The R149 reason stands (the pouch's print is in its vertex colours; a part's Color only multiplies them). A neutral twin (white vertex colours, like `FruitMeshes149`'s `_Neutral`) needs the mesh's vertices. **The place file has none**: `SeedPackMeshAssets/Storm_02/ApprovedMesh01` is a MeshPart with a MeshId, a Size, a PackLocalFrame and an empty `PhysicalConfigData`; the vertices live on Roblox's servers and every request for them is refused from here. So the options are:

1. **Keep the sachet** (R149, owner-approved look: pure yellow, face plastered). Cheapest, fully tested.
2. **Studio-side dump, then the fruit route.** A Studio script (run by the owner, whose account owns the mesh) reads each pouch with `AssetService:CreateEditableMeshAsync(Content.fromAssetId(id))`, writes its vertices / faces / normals into data modules like `ApprovedPlantMeshData1..N`; at runtime `FruitMeshes149`-style code bakes an `EditableMesh` with every vertex colour set white (a `_Neutral` twin) and the part's Color becomes the only colour. Feasible in principle, **not testable here**; needs the EditableMesh API available to the experience; large data (42 meshes) unless only Storm_02 is dumped.
3. **The same at runtime** (`CreateEditableMeshAsync` on the live MeshId, white the colours, `CreateMeshPartAsync`), per server, falling back to the sachet. Needs the experience to be allowed to read that asset as an EditableMesh; unknown, **cannot be checked here**.
4. **A generated pouch** (a parametric pillow like the fruit lathes: no vertex data needed) at the template's footprint, white vertex colours: closer to the pouch than the sachet is, but still not the same mesh; not verifiable offline.
5. A Highlight fill (flat yellow whatever the vertex colours) is **not** an option: Highlights do not draw in ViewportFrames (hotbar / Bag / Index pictures) and are capped per client.

**Void:** it already uses the standard (Forest_01) pouch. Options: keep as is (the halo is the design); hang the halo on four spokes so it reads as attached; or restack the disc layers >= .02 apart (+.04 stud of print) to clear the R149 z-fighting rule.

**Mech:** it already uses the standard pouch. Option: a neutral twin (as above) so the body is exactly the silver-white and not Forest_01's print through a white tint; or leave it (the armour panels cover most of both faces).

**Ordinary designs, "all the same pouch":** the print is baked into 42 different meshes, so one shared pouch is **not possible without re-authoring art** (choose one mesh and every pack loses its print, or re-bake a print texture over one pouch in an external tool). What can be unified without art changes: the tier / biome scale (all packs 1.00, losing the size ladder), or only the 11 tall designs' strips / `TearLipY` once the Studio check (section 6) says where each pouch really ends.

## 6. What the box reading cannot see, and how to settle it in Studio

The audit reads each MeshPart as its Size box. A part "touches" the pouch if it touches that box, which is the most generous reading (the real surface lies inside the box; the Void's / Mech's print was fitted to it by hand). So a part could still hover over the real, rounded pouch at its corners, and a tear strip inside the box could still be hidden. In Studio (Command Bar, Edit mode, read-only; **not run**), for each template clone it to the workspace, set its MeshParts `CollisionFidelity = PreciseConvexDecomposition`, anchor them at their `PackLocalFrame`, and `workspace:Raycast` with an Include filter on the clone: (1) straight down the line x = 0, z = 0 from y = 3 to read each pouch's true top / bottom (strips at 1.02 - 1.20, seal at -1.20 .. -1.04); (2) along +Z from z = -3 at every Void / Mech front-detail centre to read the real gap to the surface. A gap above ~.03 stud on the 11 tall designs or the Void's corner runes is then a measured defect to fix with those numbers.

## 7. Tests

`sh docs/proposals/R151/tests/run_packs.sh [scratch dir] [--mutations] [--suites] [--base REF]` (Roblox mock, `/opt/luau/luau`; the place file is only needed to regenerate `pack_templates.luau` with `tools/gen_pack_templates.py`):

| Part | Result |
|---|---|
| `test_packs.luau` (this checkout) | **27,151 checks, 0 failures**: 2,190 packs built and checked for structure and connection (78 stage x variant x 5 sizes x 3 coats on the ground; stages 1 / 4 / 7 / 8 also held by an R15 and an R6 carrier, 120 simulated frames each); the real `SeedPackRender` hovering 8 world packs for 120 frames; 172 context comparisons part by part (ground = held = picture = opening copy = market = mystery x1.7 = locked silhouette); 9,432 giant-test parts (4,716 tagged); 48 weathered packs; 84 pads; the special packs; the 42-template registry |
| `check_packs.py` on `dump_packs.luau` | **53 packs, 958 parts: 0 floating, 0 z-fighting** (42 designs + Void + Mech + Verity + a 25x giant + 7 pads); not counted: 54 mesh-box pairs, 32 known near-tier print layers (Void / Mech) |
| before / after (`compare_fingerprints.py`, base `c1e8829`) | 1,574 packs compared, **1,147 identical, 427 differ only in the three documented fixes** |
| the same audit on the base commit | 156 failures (all "giant"), 1 floating pack (the Void: 40 parts), 3 pads z-fighting (7 pairs) |
| `--mutations` | **13 of 13 broken copies noticed**: an unwelded tear strip, an anchored seal on a held pack, an unwelded root, the giant tags taken out, a wrong `PackLocalFrame`, a 1.1x size jump in pictures, a part count off by one, a Mech motor with the wrong C0, a seal pushed .4 off the pouch, a duplicate coplanar seal, a weather trait that adds a part, one unwelded Verity block, a Void star pushed .2 off the face |
| existing suites (`--suites`) | R149 Verity pack **673** (+ its 6 mutants), R147 Verity pack **170**, R147 Verity art **405**, veiled R122 **128 + 73 + 46**, R137 **43 + 22 + 11 + 14**, R138 **18 + 16 + 18 + 436** (+ guide flow / layout), R148 index / LIMITED tab **216**, R148 purchases **329 + 71 + 75**, R148 roster **257 + 978** (0 floating parts in 104 plant scenes), R150 and R149 `run_all.sh` (every suite in them passes), all 0 failures |

`docs/proposals/R149/tests/run_verity_pack.sh` was changed for one reason: its "every other pack builds exactly what the base commit built" compares against R148's code; its base copies of `SeedPackVisuals` / `EclipsePackArt` now first get the three R151 fixes (`tests/rebase_r151.py`), so "identical" still means "nothing else changed" (673 checks, 0 failures, its 6 mutants still noticed).

Files: `tests/` (`run_packs.sh`, `pack_world.luau` the shared world, `test_packs.luau`, `dump_packs.luau`, `check_packs.py`, `fingerprint_packs.luau`, `compare_fingerprints.py`, `mutate_packs.py`, `mkbundle_packs.py`, `pack_templates.luau` generated), `tools/gen_pack_templates.py`, `preview/` (`run_packs_preview.sh`, `packs.html`, `render_packs.mjs`, `make_packs_sheet.py`).

## 8. Changed in `src/`

* `SeedPackVisuals.lua`: the seal and tear strips of a giant pack are `GiantVisualPart`s; the pads' moss / ice are .006 thicker.
* `EclipsePackArt.lua`: the Void's stars, specks and rune strokes are backed (.026 deep, same front face).
