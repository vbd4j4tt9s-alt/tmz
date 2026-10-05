# R151 proposal: the base area and the walls ("Seed Festival Square")

Design proposal with renders. **Nothing in `src/` was changed**, and no installer was made. A coder builds it after you approve.

Your question (5 Oct 2026): *"I also want you to take a look at a redesign of the base area and the walls what can we add to liven up the base area"*.

**How to read this**
- **[O]** = something I measured: your place file (`sapkeyver.rbxl`, 4 Oct), the code at R150, or the scene the real start-up scripts build.
- **[I]** = my design opinion.
- **The renders are previews, not screenshots.** They run the game's real start-up scripts on your saved map, plus my scratch builder, and draw the result with three.js. There is no Roblox lighting, no material shine, no bloom and no Fredoka font. The faint tiled texture on the hub floor and walls is not drawn either.
- Coordinates are in studs. The track runs toward +Z. The hub floor top is at y = 4.

| Picture | What it shows |
|---|---|
| `base_area_today.png` | Today: the hub from above, with what's there, plus three views from player height. |
| `base_area_plan.png` | The redesign from above: its zones, the 7 murals, and the parts budget. |
| `base_area_spawn.png` | Leaving your base. Today / Phase 1 / Phase 1 + 2. |
| `base_area_street.png` | Between two bases (Base 1 and Base 3), looking into a side garden. |
| `base_area_entrance.png` | At a base entrance (Base 3): the name arch, verge and trophy-shelf slot. |
| `base_area_walls.png` | The walls up close (the Desert mural at the east alley). |
| `base_area_backwall.png` | The back wall at the end of the main avenue (the Snow mural). |
| `base_area_gate.png` | The track gate. Today / Phase 1 / Phase 1 + 2. |
| `base_area_aerial.png` | The whole hub from a drone above the gate. Today / Phase 1 / Phase 1 + 2. |
| `base_area_darkened.png` | The lamps when The Darkened turns the lights out. |
| `base_area_lowwall.png` | Your option: a 30-stud wall with a biome skyline beyond it, next to the dressed 48-stud wall. |

---

## 0. One-screen summary

**Today [O]**
- The hub is a 680 × 524 grass rectangle inside five plain 48-stud sage walls.
- The six bases stand at the edges, and the market and Verity sit in the middle.
- There is nothing between them: no paths, trees, lamps, benches or signs.
- Two back corners and two side alleys are empty.

**The idea [I]: "Seed Festival Square"**
- The hub becomes the seed thieves' village square on festival day.
- **Walls:** a cream garden rampart with a hedge on top, pilasters, towers and seven framed **biome murals**.
  - The murals run in track order: Forest and Jungle left of the gate, round the hub, back to Crystal and Storm Peaks right of the gate.
  - So the walls preview the track.
- **Gate:** a **keyboard arch** over the track gap.
  - It has one big key per biome, showing that keeper's speed.
  - On your screen, a key turns green once you're faster than that keeper.
- **Ground:** paved streets join every base, the market and the gate.
- **Life:** trees, flower beds, lamps, benches, bunting, butterflies and a Seed Fountain.
- **Bases:** each base gets an arch in its colour with the owner's name.

**Phase 1 (one release, the biggest visible change per part):**
- What it adds: the walls dressing, the 7 murals, 6 wall banners, the gate arch and its keys, the paths and plazas, and the base arches.
- Cost: **527 parts**, built once by the server. Today the hub has 4,673 visible parts (the market alone is 2,229).
- Collision: none of it collides except the two gate towers, which stand on the wall ends.
- Z-fighting: none (the R149 detector found 0 overlaps involving the new parts).

**Phase 2:** the life layer, built on each player's screen with distance detail: **609 parts**, lamps that glow in the dark, and sound zones.

**Phase 3 (options and later):** a low wall with a skyline, the trophy shelf, an event clock and live track board on the gate towers, seasonal swaps, and a lookout.

**What you need to choose** (section 6):
1. The theme.
2. Wall height and style.
3. The palette.
4. Base arches yes or no.
5. Speeds on the gate keys.
6. Whether decorations are solid.
7. The fountain's centrepiece.

---

## 1. Today: what the base area looks and feels like

Picture: **`base_area_today.png`**. It's the top view of your saved map after the real start-up scripts ran, plus three views from player height.

### Layout, measured [O]

| Thing | Where and what |
|---|---|
| Hub floor | `Lobby/LobbyFloor`: 680 × 524 (x −340…340, z −623…−99), green plastic (82,180,87). A faint tiled texture (asset 6372755229, 80 % transparent) covers its top. |
| Walls | Five parts in `ChestChaseWalls`, all **48 studs high** (y 3–51) and 5 thick, sage plastic (139,165,111), with the same faint texture. **Front walls:** two pieces, x ±94…±335. **Back wall:** z −623…−618. **Side walls:** x ±335…±340. |
| Wall trim | `GardenHubDesign`: a 1-stud wood-plank cap on each wall, and 13 thin timber strips (0.8 × 47). That's all the decoration they have. |
| Track gap | 188 studs between the front walls. The track is 180 wide and starts at z −100. Its side walls are also 48 high, at \|x\| 89–94. |
| Safe line | A neon line at z −99.3, 180 wide, plus a "SAFE ZONE" ground title. The FOREST spacebar sits at z −100…−92. |
| Spawn | Everyone spawns **inside their own base**, at the entrance, facing the hub. The fallback spawn is at (0, 4.1, −141), facing the track. |
| Bases | Six plots of 180 × 118 (pad top y = 5). **Bases 1 and 3:** x −325…−145. **Bases 2 and 4:** x 145…325. **Bases 5 and 6:** x ±15…±133, z −602…−422. |
| Base openings | Each opening is **32 studs** wide and faces the hub centre. **Bases 1–4:** at x ±147, z −180.5 or −358. **Bases 5 and 6:** at x ±74, z −424. |
| Base contents | The garden fence (`GardenFenceArt`, 7 upgrade tiers, 144–189 parts) and 10 garden beds. The treadmill (127–223 parts). The mystery pedestal (25 parts). The bonus board. |
| Base markers | An owner badge 64 studs up (R131), the client's home marker (R132), and the base colour (`BaseColor`): 1 red, 2 blue, 3 gold, 4 purple, 5 green, 6 orange. |
| Market | `MarketLayout` at (0, 4, −269.3), scaled ×1.7, so its footprint is about 51 × 43. Its porch and the Fruit of the Hour pedestal (−20, −299) face **away** from the spawn, toward Verity. It has 2,229 parts, 1,968 of them the showcase. |
| Verity | A dais of radius 14 at (0, 4, −340) with her 22-stud ball. The event ends 1 Nov. |
| Leaderboards | Top Speed (x 104…128) and Most Cash (x −128…−104), both at z −113, in front of the front walls beside the gap. |
| Empty | **Two back corners**, about 190 × 198 each (x ±145…±335, z −420…−618). These are reserved: the R151 Best Pull Today and Biggest Fruit Today displays are being built there now. **Two side alleys**, 52 wide, between Bases 1/3 and 2/4. A **30-stud lane** between Bases 5 and 6. A **290 × 320 middle** of grass around the market. |
| Lighting and sound | The sun is fixed at 14:12 (no day/night). The hub plays quiet birds (0.018) and leaves (0.022). |

### How it feels [I]
- **"A walled field."** From your base you see flat grass, the market's back wall, a fence 300 studs away, and a 48-stud green wall all round (`base_area_spawn.png`, left).
- **The walls are the biggest thing on screen and say nothing.** Between bases they fill the view (`base_area_street.png`, left).
- **Nothing tells you where to go.** There are no routes from your base to the market or the gate. The track gap is just a hole between two walls (`base_area_gate.png`, left).
- **Nothing to look at on the way.** The routes players walk most (base → gate, base → market) cross empty grass.
- **Two good things already exist.** The market is a real landmark, and the bases have strong colours and fences. The redesign builds on both.

---

## 2. The concept: Seed Festival Square

### Why this theme [I]
- **It's the game's own story.** You steal seed packs, grow them at your base and sell at the market. A village square on market-festival day (bunting, lanterns, flower beds, a fountain) is where those people would live. It needs no new lore.
- **The walls preview the track.** Seven murals run round the hub in track order, starting and ending at the gate. New players learn "Forest, Jungle, Desert, Snow, Lava, Crystal, Storm" just by looking around. Each mural shows its number and name.
- **It uses the track's own motif.** The gate is a row of the keyboard's keycaps (the place's `R142Keycap` mesh). The murals carry number keys. The run-up is paved in the seven biome colours.
- **It suits the game's style.** Chunky cartoon shapes, candy colours, gold trims. Everything is built from blocks, wedges, balls and cylinders, plus the existing keycap mesh. No new uploads.

### Palette (default) [I]
- Walls: cream plaster (243,231,206).
- Plinths: warm stone (178,166,147).
- Trims: gold (244,196,86).
- Hedges: green (86,162,74).
- Tower roofs: coral (230,96,84) and teal (52,168,160). Teal matches the market roof.
- Streets: cream cobble (222,206,172).
- Squares: terracotta brick (214,142,110).
- Lamps: dark teal metal.
- Each base keeps its own colour on its arch, banner, curbs and mat.

### Zones (picture: `base_area_plan.png`)
1. **Track gate and run-up.** The keyboard arch with a 7-lane biome-coloured run-up up to the existing safe line. The leaderboards stay where they are.
2. **Front street.** Joins the gate run-up, the avenue and the ring.
3. **Welcome lawns**, either side of the avenue: trees, flower beds, benches and the main signpost.
4. **Market square.** Brick paving round the market, with planters, benches and bunting to the market's eaves.
5. **Stage circle.** Verity's dais now; after 1 Nov it's the stage for event hosts and seasonal NPCs (benchmark §6.3).
6. **Seed Fountain.** The centrepiece, between the stage and the back bases.
7. **Ring street**, past all six base entrances. Each base gets a short paved spur with curbs and a mat in its colour.
8. **Side gardens** in the two alleys:
   - the **Desert garden** (+X side): palms, cacti, a sandy nook and benches;
   - the **Lava garden** (−X side): ember-coloured trees and glowing rocks.
   - Each ends at its mural.
9. **Back lane** between Bases 5 and 6: pines, ending at the **Snow** mural on the main axis.
- **Reserved:** the two back corners. Nothing is built there; the streets stop at their edge.

### 2.1 Walls [O + I]
The five saved wall parts **keep their size, position and collision**. They still block exactly where they block today. Only their look changes, and the rest is added in front of them:

**Phase 1**
- **Recolour:** cream Plaster instead of sage plastic.
- **Hidden:** the 13 old timber strips are hidden (`Transparency` 1).
- **Stone plinth**, 6 studs high, 1.2 studs out from the wall.
- **Gold string course** at y 34.
- **36 pilasters** (7 wide), each with a gold cap and a **topiary ball** on top.
- **A clipped hedge** along the whole wall top, 6.3 high and 1 stud over each face. It hides the old wood caps. The skyline then reads "garden", not "prison".
- **Four round corner towers** with stepped coral and cream roofs and a gold ball. They mostly sit outside the hub and reach only 6.5 studs in.
- **Seven framed biome murals**, 44 × 27, at y 15–42:
  - each is a relief built from about 16 parts (sky, sun, hills, pines, a pyramid, a volcano with neon lava, crystals, a lightning bolt …);
  - each has a gold frame, a half-round crest in the biome colour with a **number key**, and a plaque such as "3 · 🌵 DESERT";
  - they sit at the four ends of the hub's axes and on the front wall.
- **Six base banners** in each base's colour ("BASE 1" …), hanging on the wall behind each base. You can tell which colour is yours from across the hub.

**Phase 2**
- **14 wall lanterns** on the pilasters beside the murals. They glow in the dark.

**Option (Phase 3, your choice): low wall + skyline** (`base_area_lowwall.png`)
- The saved wall turns invisible but **keeps blocking**, and its faint texture is hidden too.
- In front of it stands a **30-stud** dressed wall.
- Far biome silhouettes stand beyond it, in track order: Forest hills, Jungle domes, a Desert pyramid, Snow peaks, a Lava volcano, Crystal spires and a Storm peak.
- That's 41 client parts, none of which collide. The silhouettes in the preview are rough placeholders; the real ones would be layered and softened by the haze.
- The hub feels open and part of the world. The risk is the invisible barrier between y 34 and 51 (section 5).

### 2.2 Ground: paths and plazas [O + I]
- **Streets** are 14–18 wide in cream cobble. **Squares** are brick. **Round plazas** are discs.
- **Heights** are layered so no two pavings share a plane:
  - rectangles at a top of 4.20, never overlapping each other;
  - discs at 4.14 (the stage, under the market square) or 4.26 (over a street);
  - curbs and mats at 4.32;
  - the gate run-up lanes at **4.06**, so the saved "SAFE ZONE" ground title (4.12–4.20) still draws on top.
- **Base spurs** run from each base's pad edge to the ring street, the full width of the 32-stud opening. Their curbs and a round **welcome mat** are in the base's colour.
- **What stays the same:** the floor, the base pads and every route. All paving is flat, has no collision, and adds only 0.06–0.32 studs, so nothing changes for running, digging or carrying.

### 2.3 Life (Phase 2, built on each player's screen) [I]
| Item | Count / detail |
|---|---|
| **Trees** (4–8 parts each) | 24 round, blossom and apple trees; 4 palms and 2 cacti in the Desert garden; 4 ember trees and 2 glowing rocks in the Lava garden; 4 pines in the back lane. |
| **Flower beds** | 13 raised round beds: cream rims, flowers in warm or cool sets. |
| **Base flower verges** | One beside each opening, in the base colour plus white and yellow. |
| **Lamp posts** | 22 along the streets and squares. **8 carry a real light.** Every lantern is neon, so they read even by day. |
| **Benches** | 13: four round the fountain, the garden nooks, the lawns, the market square and the back lane. |
| **Signposts** | 2. Boards: "THE TRACK", "MARKET", "SEED FOUNTAIN", and **the owners' names** of the bases each way (from `BaseOwnerDisplayName`; "Base 6" when free). |
| **Bunting** | 6 strings (46 pennants): across the avenue and from the market square's lamps to the market's eaves. |
| **Seed Fountain** (14 parts) | A cream basin with a gold rim, glass water, a bowl, and a jet holding up a **giant seed pack**. In-game that's `SeedPackVisuals.Bag`, turning slowly. The preview shows a stand-in box. |
| **Butterflies** | 12 pairs of wings by the flower beds, animated on the client. Optional extra, not built in the preview: 3 bird silhouettes (2 wedges each) circling high over the gardens. |
| **Falling petals** | Particle emitters on the blossom trees (Rate 2). |

- **Sound zones.** These use only the five existing ambience loops in `BiomeMood.Audio`:
  - birds louder (0.018 → about 0.03) within about 60 studs of the tree lawns and gardens;
  - leaves near the hedge walls;
  - a faint crystal hum by the Crystal mural;
  - a faint rumble by the Lava garden's rocks.
  - There is no water loop among the existing sounds, so the fountain stays silent unless you add a library sound.
- **Lamps in the dark.** There is no day/night yet. The client turns the lamp lights on whenever the lighting goes dark: The Darkened's blackout (`EnvironmentLighting.Level` > 0.3) or a Rain or Thunderstorm. See `base_area_darkened.png`. With a future hub day/night (benchmark M4) the same lamps become night lamps.

### 2.4 Each base [O + I]

**The entrance arch (Phase 1)**
- Two plaster posts stand just outside the 32-stud opening, on the fence line. Each has a ball in the base colour and a pennant.
- Between them is a **beam in the base colour**, reading **"LEO'S BASE"** on the outside ("FREE BASE" when nobody owns it) and **"BASE 3"** on the inside.
- On top sits a **number medallion**, readable from both sides.
- The beam's gold trim is 14.3 studs above the pad, so carriers and the follow camera pass under it.
- The opening, the fence art of all 7 tiers, the treadmill, the pedestal, the plots, the bonus board, the owner badge and the home marker are **untouched**.

**Also**
- **Phase 2:** a flower verge outside the fence on the right of the opening, and the spur, curbs and mat (Phase 1, under paths).
- **Reserved slots:**
  - the **trophy shelf** (benchmark M2) on the left of the opening, facing the street (a ghost in the renders);
  - lamp sockets on the arch posts;
  - gem decorations later, on fixed spots, never free building.

> ⚠ `GardenFenceArt` says *"The 32-stud opening has no arch, tall posts, beam, name board or roof"*. That was a deliberate choice before this repo's history. I don't know the reason: maybe camera clipping, maybe looks. **Please confirm you want arches back** (choice 4). The alternative is two tall banner poles without a beam.

### 2.5 Track gate and view [O + I]
- **Two round gate towers** stand on the front wall ends (x ±99, z −100, 16 wide, 66 tall), with teal stepped roofs.
  - Their inner edge is at \|x\| 91, outside the 180-wide run-up and track (\|x\| ≤ 90).
  - They clear the Top Speed and Most Cash boards.
  - These are the only new parts with collision, so nobody runs through solid-looking masonry.
- **An arch beam 40 studs up** (y 44–56) spans the gap, with haunches and gold trims.
  - On its hub face hang **7 big keycaps**, one per biome in track order, Forest on the left as you face the track.
  - Each key shows the biome's emoji, its name and **the keeper's speed number**: Forest 0, Jungle 3,800, Desert 92K, Snow 1.2M, Lava 16M, Crystal 160M, Storm Peaks 2.6B. These are the same numbers the keeper signs show (`KeeperPursuit.EscapeSpeed` with the `KeeperSpeedLabels` rounding).
  - On each player's own screen a key turns **green with ✓** once they're faster. Players see where they stand before they run.
- **Above the keys:** 7 biome flags and a **"THE TRACK"** sign on a half-round coral crest.
- **The run-up:** 7 lanes, one per biome colour, from the front street to the existing safe line.
- **The view down the track:** you can already see down the track through the gap, but the keyboard is drawn only near the runner. A lookout on a gate tower is a Phase 3 option (section 4).

### 2.6 Readability: "where's my base? where's the track?" [I]
- **The track:** the gate towers (80 studs with roofs) and flags show above everything in the hub. Both signposts point to it, and the avenue and the run-up lead straight to it.
- **My base:**
  - your name on your arch, in your colour;
  - your colour on the spur's curbs and mat and on your wall banner;
  - your number on the medallion and the banner;
  - the signposts list owners' names;
  - the existing home marker and owner badge.

### 2.7 Gameplay safety checklist (design rules for the coder)
- **Walls:** the saved walls are unchanged in size, position and `CanCollide`. Only their colour and material change, plus `Transparency` in the low-wall option.
- **New parts:** all `Anchored`, with `CanTouch` and `CanQuery` off. **No collision** except the gate towers.
  - Fast runners never trip on a lamp or bench. HANDOFF notes FallingDown after high-speed wall hits.
  - Raycasts (shovel, bats, camera) ignore decor.
- **Clear of every gameplay piece:** nothing sits on a base pad or garden plot, or on the fence line except the arch posts beside the opening. Nothing touches a treadmill, mystery pedestal, spawn, the run-up or track area (\|x\| < 90 north of the walls), the safe line, the leaderboards, or the market and Verity footprints.
- **Clearances:** base arch beams 14.3 studs over the pad, the gate beam 40, the gate keys 38.5.
- **Sightlines:** trees stand off the streets and the avenue axis. From your base you still see the market, and from the gate you see the stage. The fences and the 32-stud openings keep their view into bases for thieves and defenders.
- **The reserved corners stay empty.**

---

## 3. Renders
Each sheet puts TODAY next to AFTER, from the same camera.
- **Three-way sheets:** spawn, gate and aerial show TODAY | PHASE 1 on top and PHASE 1 + 2 large below.
- **People for scale:** the blocky avatars are 5 studs tall.
- **Cameras:** above the avatar's head, like Roblox's follow camera.
- **The "Ben", "Mia", "Leo", "Zoe", "Sam" owners** are test names. Base 6 is shown free.

- `base_area_spawn.png`: leaving Base 1.
- `base_area_street.png`: between Base 1 and Base 3, into the Lava garden.
- `base_area_entrance.png`: at Base 3's entrance.
- `base_area_walls.png`: the walls up close (the Desert mural).
- `base_area_backwall.png`: down the back lane to the Snow mural.
- `base_area_gate.png`: the track gate.
- `base_area_aerial.png`: the drone view.
- `base_area_plan.png`: top view with zones.
- `base_area_darkened.png`: the lamps in the dark.
- `base_area_lowwall.png`: the low-wall option.

Known preview limits:
- Verity is her real 22-stud ball, but her smiley decal isn't drawn.
- The fountain's pack is a stand-in box.
- Fruit in the market showcase is skipped: its approved meshes aren't available offline.
- Plaster, brick and cobble are approximations.

---

## 4. Phased plan

### Phase 1: the frame (one release)
- **What changes:**
  - walls dressing: recolour, plinth, course, pilasters, topiary, hedge, corner towers;
  - 7 murals and 6 wall banners;
  - the track gate: towers, arch, 7 speed keys, flags, crest;
  - paths and plazas, including the biome run-up and the base spurs;
  - the 6 base arches with name beams and medallions;
  - a tiny client script that ticks the gate keys green for the local player.
- **Parts: 527** (Walls 147, Murals 166, Banners 24, Gate 52, Paths 54, Base arches 84), plus 52 SurfaceGuis. That's +11 % on today's 4,673 visible hub parts.
  - Most are big, plain and anchored.
  - Paving and mural pieces have shadows off.
  - The walls and gate model should use `ModelStreamingMode = Persistent`, as Verity's model does, so the frame never pops in.
- **Files:**
  - New: `ServerScriptService/ChestChaseServer/HubDecor151.lua`, a port of `BuildServer` in `preview/HubDressing151.luau`.
  - `MapService.lua`: call `HubDecor151.Apply(mapRoot)` once after `MarketLayout` / `GardenBaseLayout` (after `ZFightFix149`).
  - Name beams follow `BaseOwnerDisplayName`. Either HubDecor151 listens to the attribute (no change elsewhere), or `GardenFenceArt.UpdateOwner` updates them.
  - New client: `StarterPlayerScripts/HubGateKeys151.client.lua` (about 30 lines, the `KeeperSpeedLabels` rule), or fold it into `KeeperSpeedLabels.client.lua`.
  - `Config.Version` bump, and the installer.
- **Tests to add:**
  - run `docs/proposals/R149/tests/run_zfight.sh` on the new scene (this proposal's check: 0 findings);
  - a mock test that the 5 wall parts keep their CFrame, Size and CanCollide;
  - only the gate towers collide;
  - no new part overlaps a base pad, fence opening, treadmill, pedestal, spawn, the \|x\| < 90 run-up north of z −150, the safe line or the leaderboards;
  - arch clearances;
  - the part budget.
- **Risks:**
  - The deliberate "no arch" note in `GardenFenceArt` (choice 4).
  - The Plaster material and the walls' existing faint texture may tint differently in Studio: check one wall before shipping (fallback SmoothPlastic).
  - SurfaceGui count on phones: keep PixelsPerStud ≤ 40 and add `MaxDistance` (about 300) on small labels.
  - The R151 displays: they need only the corners. Their final size isn't known to me; the plan keeps 20+ studs of clearance.

### Phase 2: life (one release)
- **What changes:**
  - trees and themed gardens, flower beds and verges;
  - 22 lamps (8 with lights) and 14 wall lanterns that switch on in the dark;
  - 13 benches, 2 signposts with owner names, 6 bunting strings;
  - the Seed Fountain with a real `SeedPackVisuals.Bag` pack;
  - butterflies and petals;
  - ambience zones.
- **Parts: 609**, built **on each player's screen**, plus 17 SurfaceGuis.
- **Detail by distance:**
  - full detail within about 220 studs;
  - beyond that, only tree crowns, lamps and the fountain;
  - flowers, butterflies, bunting and benches hidden;
  - one grid check every 0.5 s, like `KeyboardTrack` and `DistantGardens`.
  - FastMode and Reduced Motion: no butterflies, no petals, static bunting.
- **Files:**
  - New: `ReplicatedStorage/HubLifeArt151.lua` (the builders) and `StarterPlayerScripts/HubLife151.client.lua` (build, detail by distance, lamps on in the dark, butterflies).
  - `BiomeMood.lua`: hub sound zones in `SoundTargets` for stage 0.
  - The fountain uses `SeedPackVisuals`.
- **Risks:**
  - Client build time on weak phones: build in chunks over a few frames.
  - Lights: keep at most 8 PointLights on, none casting shadows.
  - Taste: the gardens' themes and the number of trees are easy to tune.

### Phase 3: options and the future
- **Low wall + skyline**, your choice (41 client parts, `base_area_lowwall.png`). Risk: players see sky above a wall that still blocks; nobody can reach y 34 in the hub today.
- **Trophy shelf** in each base's reserved slot (benchmark M2), and gem decorations on fixed sockets.
- **Gate tower boards:** an **event clock** on the +X tower (pairs with Event Hours, benchmark Q1) and the **live track board** on the −X tower (benchmark M1). The slots are shown as ghosts.
- **Lookout:** a balcony on a gate tower to watch the track. It needs stairs, collision and a check that nobody can reach the wall tops.
- **Seasonal swaps (October):** topiary balls become jack-o'-lanterns (the baked Ember Pumpkin mesh), bunting turns orange and purple, lanterns go amber. A date switch in `LimitedEvent` (benchmark Q3).
- **Hub day/night** (benchmark M4): the lamps are already there.

### Budget summary [O]
| | Parts | Built by | Collision | SurfaceGuis |
|---|---|---|---|---|
| Today's hub (visible) | 4,673 | saved map + server | as today | — |
| Phase 1 | 527 | server, once | gate towers only | 52 |
| Phase 2 | 609 | each client, with detail by distance | none | 17 |
| Phase 3 low-wall option | 41 (+5 visible wall parts) | client | none | — |
| Z-fighting with R151 parts | **0** (whole map: 163 before, 163 after) | R149 detector | | |

---

## 5. Risks in one list
- **Arches:** the base openings were deliberately left without arches (`GardenFenceArt` note). Confirm.
- **Low wall:** a 30-stud visible wall with a 48-stud invisible barrier. Players never reach that height in the hub today, but say no if invisible walls bother you.
- **Streaming:** if the frame isn't Persistent, far walls could pop in on phones.
- **Phones:** 1,136 extra parts in total, mostly static. Phase 2 is client-side with distance detail. Lights are limited to 8. Check with the device emulator.
- **Looks we can't see here:** the Roblox Plaster, Brick and Cobblestone materials, Future versus ShadowMap lighting (benchmark M6), and the walls' faint texture over the new colour.
- **Verity:** her event ends 1 Nov. The stage circle stays as an event stage.
- **The displays:** if the R151 Best Pull and Biggest Fruit displays come out bigger than the corners, the Desert and Lava gardens and the ring street still leave a clear approach.
- **Decor without collision:** walking through a tree trunk is a cartoon convention. If you'd rather have solid trunks and benches, it's a one-line change, but fast runners may trip.

---

## 6. Your choices
1. **Theme:**
   - **A. Seed Festival Square** (this proposal);
   - B. Garden Castle: grey stone, crenellations instead of the hedge, banners;
   - C. Candy Keyboard Plaza: keycaps everywhere, pastel walls by biome.
2. **Wall height and style:**
   - **A. the dressed 48-stud wall** (Phase 1);
   - B. a 30-stud wall with a skyline (`base_area_lowwall.png`);
   - C. crenellations instead of the hedge.
3. **Palette:**
   - **cream, gold and hedge green** (default);
   - pastel candy walls, each side in its murals' biome colours;
   - warm terracotta.
4. **Base arches:** yes, with "NAME'S BASE" (default), just the name, or no beam (two banner poles).
5. **Gate keys show the keeper speeds:** yes (default), or only the biome names.
6. **Decorations solid?** No (default), or solid trunks and benches.
7. **Fountain centrepiece:**
   - **a giant seed pack on a water jet** (default);
   - a giant Void pack (benchmark §6.3);
   - today's Fruit of the Hour.
8. **Murals:** relief scenes, about 16 parts each (default), or simpler flat panels (about 6 parts each).

---

## 7. How the previews were made (reproducible)
`sh docs/proposals/R151/preview/run_base_area_preview.sh <scratch dir> [place.rbxl]`
1. **Read the map.** `docs/proposals/R149/tools/rbxl_geom.py --tree` reads `Workspace.ChestChaseMap` from your place file. The R149 Roblox mock loads it: `tools/tests/roblox.luau`, `inventory_R113/tests/world.luau` and `R149/tests/zfight_world.luau`.
2. **Build the scenes.** `preview/base_area_scene.luau` runs **this checkout's real start-up scripts**:
   - `MapService.new` (MarketLayout, GardenBaseLayout, TrackExpansion83 …);
   - the six treadmills, the garden fences, the mystery pedestals, Verity's dais and the leaderboards;
   - the keyboard client.
   - For the redesign it then runs `preview/HubDressing151.luau`, the scratch builder written as plain Roblox Luau so it can be ported.
   - There are four scenes: today, Phase 1, Phase 1 + 2 (with the slot ghosts), and the low wall.
3. **Count and check.**
   - `preview/count_base_area_parts.py` counts the parts.
   - `preview/check_base_area_zfight.py` runs the **R149 z-fighting detector** (`R149/tools/zfight.py`, the rules `run_zfight.sh` uses) on today and the redesign. **Result: 0 counted findings involving an R151 part, in both the tall and low variants.**
   - The 163 findings on the whole map are the pre-existing ones: keyboard, market fruit art and track meshes, the same before and after.
   - Getting to zero took fixes during design: arch footings against fence foundations, curb ends, bench legs, snow caps on the mural mountains, and the tower bottoms.
4. **Render.** `preview/render_base_area.mjs` draws `preview/base_area_views.json`'s cameras with three.js (`preview/base_area.html`) in headless Chromium (swiftshader). `preview/make_base_area_sheets.py` writes the PNGs.
