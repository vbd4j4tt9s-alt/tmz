# Keepers: improved 3D models (proposal, previews only)

**Status:** waiting for your OK. Nothing in the game's code (`src/`) has changed.

## Look at these first
1. `keepers_before_after.png`: every keeper today (left) and proposed (right), same camera, same scale, with a 5-stud player.
2. `keepers_lineup.png`: all keepers in a row next to a 5-stud player, today on top and proposed below, with a ruler in studs.
3. One sheet per keeper (front, three-quarter, side, back, chase, attack wind-up, attack impact, asleep):
   `keeper_timber_golem.png`, `keeper_jungle_king.png`, `keeper_sand_snake.png`, `keeper_ice_fang.png`,
   `keeper_lava_dragon.png`, `keeper_crystal_knight.png`, `keeper_storm_colossus.png`, `keeper_the_darkened.png`.

These are real Blender models rendered in Cycles. The chase, attack and asleep poses are not hand-posed. They are the
exact frames the game's own pose code produces for that keeper, so the previews also show that today's animation code
can move the new models without changes.

## 1. What "Steal an Egg" does well

**What I could and could not see.** This environment blocks web pages and image hosts. I tried the Roblox game page,
YouTube, the Fandom wiki and about ten guide sites, and every one was refused. The only thing that came through was
the text of search-result summaries. **I did not see a single picture or video of Steal an Egg's guardians.** Everything
in the "Inferred" paragraph below is my guess, not something I saw.

What the sources say (text only):
- Each biome has one guardian, and it is an animal that matches the biome: Chicken (Forest), Swan (Lake), Scorpion
  (Desert), Tiger (Jungle), Yeti (Snow), Hellhound (Volcano), Moby (Abyss Ocean), T-Rex (Prehistoric), Dragon (Cosmic).
  Later areas add an Oni Tiger (Cherry Blossom) and a King Gorilla boss (Titan Temple).
- Picking up an egg wakes the guardian. It chases you until you reach your base or it catches you. A catch ragdolls you
  and you drop the egg.
- Guardians get faster in deeper biomes. One guide says the Yeti is "much bigger than the early-game guardians, so it is
  easy to keep track of while running back, but harder to dodge". Chickens "patrol slowly and have a tiny radius".
- Bosses such as the Gorilla King chase whoever holds a stolen egg, and their pathing breaks against tight walls.

Sources (search summaries only; the pages themselves were blocked):
[games.gg biomes guide](https://games.gg/roblox/guides/steal-an-egg-biomes-guide/),
[Eldorado biomes and guardians](https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-biomes-and-speed-requirements/),
[stealaneggwiki.net zones](https://stealaneggwiki.net/zones),
[steal-an-egg-game.wiki guardians](https://steal-an-egg-game.wiki/guide/guardians),
[Sportskeeda biomes](https://www.sportskeeda.com/roblox-news/all-steal-an-egg-biomes),
[Lolga biomes and guardians](https://www.lolga.com/news/all-steal-an-egg-biomes-zone-order-speed-requirements-guardians),
[stealanegg.pro biomes](https://stealanegg.pro/locations/biomes),
[Roonby glitch guide (Gorilla King)](https://roonby.com/2026/09/04/6-glitch-in-steal-an-egg-guide-is-it-true/),
[Playgama game summary](https://playgama.com/game/steal-an-egg-grow-animals),
[Roblox game page](https://www.roblox.com/games/107778070777162/Steal-An-Egg) and
[Fandom T-Rex page](https://stealanegg.fandom.com/wiki/T-Rex) (both blocked). A search for the "Monsters Are Coming"
update found only names (a Monster Egg with six monsters; the Gorilla King guards Titan Temple), not looks.

**Inferred (not seen):** games in this "Steal a ..." family usually use chunky, rounded cartoon creatures with big heads,
big eyes, bright flat colours and no outlines. The quote about the Yeti suggests the bigger guardians are made to be read
at a glance while you run away. Please compare with the real game. If its guardians look different (for example blocky
or realistic), tell me and I will change the style.

What I took for our keepers:
1. **One instantly recognisable creature per biome.** Ours already have this. Keep each one's identity.
2. **Size grows with the biome.** Ours already do this. Keep today's sizes.
3. **Read the face while running away.** When a keeper chases you, you mostly see its face. So the new models have big
   heads, big glowing eyes, angry brows and open jaws.
4. **Smooth, chunky shapes and a clean silhouette** instead of boxes, with bright two-tone biome colours.

## 2. Today's keepers (what I found in the code)

| Biome | Keeper | What it is | Built from | Height in the line-up (player = 5) |
|---|---|---|---|---|
| Forest | Timber Golem | tree golem that sleeps disguised as a tree | 63 native blocks and wedges + 3 accent parts | 26 studs (5x) |
| Jungle | Jungle King | silverback gorilla | 23 uploaded MeshParts | 16 studs (3x) |
| Desert | Sand Snake | 9-segment snake with a raised head and a tail rattle | 17 uploaded MeshParts + 3 accent parts | 8 tall, 35 long |
| Snow | Ice Fang | sabre-tiger in silver-and-sapphire armour (R149) | 21 uploaded MeshParts + 41 accent and armour parts | 11 tall, 33 long |
| Lava | Lava Dragon | winged dragon | 27 uploaded MeshParts (wings enlarged x1.35 by code) | 19 tall (wings up), 33 wide |
| Crystal | Crystal Knight | armoured knight with a sword | 50 native blocks + 3 orbiting shards | 34 studs (7x) |
| Storm | Storm Colossus | floating stone giant | 30 native blocks + a 5-puff cloud crown | 36 studs (41 with clouds) |
| Void event | The Darkened | tall veiled figure | 43 native blocks | 19 studs |

- The rig config still has the old Moss Boar, Crystal Beast and Storm Wing meshes for stages 1, 5 and 7. Since R38 the
  game replaces those three with the golem, the knight and the colossus, so players never see those animals.
- **How they move.** Keepers use no Humanoid animations and no Motor6Ds. Every part carries its group name (Head, Body,
  Jaw, legs, arms, wings, tail, Segment1 to Segment9) and its rest position. Each frame the client works out one frame per
  group (`BeastPose` / `KeeperUpgradePose`, then the attack, signature-strike and polish layers) and moves every part at
  once (`BulkMoveTo`). The server poses the same groups (`KeeperStrikeFrames`) to test body contact. The Darkened works the
  same way with its own 17 groups (`VeiledKeeper81`).
- **How catches work.** A catch happens when the player is within the keeper's strike distance (`KeeperCombat`, not tied
  to the model) or when a visible keeper part touches the player's body. Only the second rule depends on the model's shape.

## 3. Per keeper: what changes and why

All eight keep their creature, biome colours, role, groups and size. Triangle counts are for the whole keeper.

| Keeper | What changes | Mesh parts (today) | Triangles |
|---|---|---|---|
| **Timber Golem** | Round barrel trunk with carved bark grooves. Big cloud-shaped leaf crown. Glowing green eyes in carved sockets, heavy brows and a jagged wooden grin. Log arms with root fingers, mushroom shelves and moss. **It still sleeps disguised as a tree:** each new piece follows today's tree pose. The chest rune and mushrooms (accent parts today) are now in the mesh. | 13 (63 + 3) | 10,844 |
| **Jungle King** | Bigger head with a heavy V-shaped brow, glowing amber eyes, muzzle and fangs. Huge shaped arms with knuckle fists, a silver saddle on the back, a vine sash and vine bracers, and a gold leaf crown with a glowing orchid. | 9 (23) | 9,362 |
| **Sand Snake** | Wide hood with spectacle marks, big amber slit eyes, little viper horns, fangs and a forked tongue. Thicker round body with a diamond saddle pattern on every segment. The rattle stays an accent, so it still buzzes. | 12 (17 + 3) | 9,210 |
| **Ice Fang** | Rounder head with big ice-blue eyes, cheek ruffs, sabre fangs and ears. Crisp tiger stripes, thick legs and big paws with ice claws. **The R149 silver-and-sapphire armour** (helm and sapphire, collar, pauldrons, saddle) and the ice spines are now part of the mesh, which replaces 41 extra parts. | 9 (21 + 41) | 10,436 |
| **Lava Dragon** | Big head with bone horns, glowing red slit eyes, a toothy jaw and glowing nostrils. Round body with gold belly plates. A glowing lava seam down the spine and a flame on the tail tip (Neon parts, like today's glow parts). Bat wings with bones and scalloped orange skin, at today's in-game wing size. | 14 (27) | 8,568 |
| **Crystal Knight** | Rounded helm with a T-visor and two glowing eyes, a crystal crest, crystal clusters on the shoulders, and a glowing crystal heart in the chest. Crystal blade with a glowing core. The three orbiting shards stay. | 12 (50 + 3) | 7,088 |
| **Storm Colossus** | Boulder body and head with an angry brow and glowing eyes, and a lightning bolt in the chest. Floating fists with glowing bands, glowing joints, and thunder prongs on the shoulders. The drifting cloud crown stays. | 12 (30 + 5) | 6,128 |
| **The Darkened** | Pale mask with glowing violet eyes and the glowing cleft. A hood, a tattered cloak and long claws. **Hit shapes stay as they are:** each body piece fits inside the box of the part it replaces, and the hood, cloak and claws are cosmetic (never hit). | 24 (43) | 5,932 |

## 4. How it would be implemented

**Built in Blender (done for the preview):**
- One mesh per moving group, with the same group names and pivots the game uses today. Eyes are separate small parts with
  the same flag as today (`KeeperEyeGlow`), so they still go dark while asleep and glow when awake. Glow pieces are
  separate small parts that would use Neon.
- Colours come from one tiny palette texture per keeper (256 x 256 px). Vertex colours are included too.
- The models are sized to today's group boxes. Most groups stay within 1 stud of today's box. The few that go further
  (up to 1.7 studs) are:
  - the tiger's ice spines on its back;
  - the gorilla's leaf crown;
  - the dragon's tail spikes;
  - the ends of three snake segments, which tuck into the next segment.

  The Darkened stays within 0.1 stud of today's boxes. Exact numbers per group are in `fbx/keeper_<name>.json`
  ("Overshoot").

**What you would do:**
1. In Studio, open the 3D Importer and import each `fbx/keeper_<name>.fbx`. Check that the parts come in at the sizes
   listed in `fbx/keeper_<name>.json` (1 unit = 1 stud, facing -Z). Upload them.
2. Put the eight imported models in ServerStorage (I will give the exact folder name), save, and send me the place file.

**What I would do in the next release, after your OK:**
1. Fill `KeeperRigConfig` with the new parts from the manifests: names, groups, centres, sizes, eye and glow flags, and
   new floor sample points. Pivots stay the same.
2. Make `BeastModels` use the new models for all seven stages. The golem, knight and colossus move from blocks to meshes.
   Bump the visual version so keepers already placed in the world re-dress.
3. Give the golem's pieces their tree pose. This is already worked out, because each piece follows one of today's parts.
4. Retire the accents that are now in the meshes (the golem's rune and mushrooms, the tiger's spines and armour). Keep
   the snake's rattle, the knight's shards and the colossus's clouds.
5. Dragon: the new wings are already at in-game size, so remove the old x1.35 wing stretch for them.
6. The Darkened: swap its blocks for the new mesh parts, using the same groups and offsets.
7. Run the keeper test suites (strikes, contact, polish). Then you check them in Studio.

## 5. What stays the same
Speed, strike distance, strike timing, the catch rule, fling and ragdoll, sounds and voices, effects, sleep and wake,
the golem's tree disguise, the animated accents (rattle, shards, clouds), names and speed signs.

## 6. Phone cost
| | Today | Proposed |
|---|---|---|
| Parts moved per keeper each frame (with accents) | 20 to 66 (golem 66, tiger 62, knight 53) | 9 to 24 (golem 13, tiger 9, knight 15) |
| Triangles per keeper | unknown: the uploaded meshes cannot be read here | 5,900 to 10,800 |
| Biggest single mesh | unknown | about 3,300 triangles (Roblox allows 20,000 per mesh) |
| Textures | one texture per textured mesh | one 256 x 256 palette per keeper |

- **Target:** under 12,000 triangles per keeper. All eight meet it.
- A **lite build** is ready if phones struggle. It uses the same shapes with fewer segments: about 2,300 to 5,600
  triangles per keeper (`KEEPER_DETAIL=0.6` in the scripts).
- Fewer parts per keeper means less work in the per-frame move. I have not measured this on a device.

## 7. Risks
- **The reference was not seen.** The style is my best reading of the genre. Please compare with the real game.
- **Today's snake, tiger, dragon and gorilla are stand-ins** in the "before" images. Their meshes cannot be downloaded
  here, so each part is drawn as the hull of the game's own sample points, in an assumed colour. Compare with Studio.
- **Touch catches follow the new shapes.** Catches by distance do not change. Catches by body touch would use the new
  shapes, which differ from today's boxes by up to about 1.7 studs in a few places. The tests and a Studio check would confirm this.
- **Import.** I checked the FBX files by re-importing them in Blender: every part comes back at the listed size. I have
  not tested them in Studio.
- **Vertex colours.** I am not sure Roblox shows imported vertex colours, so the palette texture is the main colouring.
- **Neon** looks brighter in Roblox than in these renders.
- **Snake wind-up.** In the snake's wind-up frame the head and neck lift clear of the body. Today's snake does the same,
  because it is the game's pose and not the model (I checked it with the stand-in). A small change to the snake's coil
  could close the gap later. It is optional.
- **Install together.** The game only animates a keeper whose part count matches the config. The models and the config
  must go in together, in one install.

## 8. Choices for you
- **A. Style:** chunky and rounded, as shown (my pick). Or tell me what the real Steal an Egg guardians look like and I
  will match them.
- **B. Detail:** full (5,900 to 10,800 triangles) or lite (2,300 to 5,600).
- **C. Which keepers first:**
  - Option 1, the block-built ones: Golem, Knight, Colossus and The Darkened. Their "before" images are exact, so the
    gain is easiest to judge.
  - Option 2, early biomes first: Forest, then Jungle, then Desert. These are the keepers every player meets.
- **D. Tiger armour:** baked into the mesh, as shown. Or keep it as separate parts so it can still be changed on its own.
- **E. The Darkened:** include it, or leave it as it is.

## Files
- `keepers_before_after.png`, `keepers_lineup.png`, `keeper_<name>.png`: the previews.
- `fbx/keeper_<name>.fbx`: one per keeper. One mesh per part, placed on the rig, with the palette texture embedded.
- `fbx/keeper_<name>_atlas.png`: the palette texture.
- `fbx/keeper_<name>.json`: per part, its name, group, centre, size, triangles and flags. Per group, its new box against
  today's box and new floor sample points.
- `blender/`: the scripts.
  - `kit.py`: shapes, palette, scene and render helpers.
  - `proposed.py`: the eight models.
  - `today.py`: today's keepers.
  - `assemble.py`, `render_all.py`: the Blender run.
  - `compose_sheets.py`: the layouts.
  - `dump_poses.luau`: the game's real pose frames.
  - `data.py`, `luaparse.py`: read the game's Lua data.
  - `check_fbx.py`: the FBX re-import check.
  - `tricount.py`: the triangle counts.
  - `run.sh`: rebuilds everything.

## How this was made (what was run and what was reasoned)
- **Run:**
  - Blender 4.5 (Python module) built every model by script, rendered every image in Cycles on the CPU, and exported
    the FBX files.
  - The game's own Luau modules (`BeastPose`, `KeeperSignatureStrike`, `VeiledKeeper81`, `KeeperAccents`) ran on the
    repo's offline Roblox mock to produce the poses and accent parts.
  - The FBX files were re-imported and checked against the manifests.
- **Reasoned, not run:**
  - The reference style, since no images were seen.
  - How Studio's importer will treat the files.
  - The phone cost, since nothing was measured on a device.
