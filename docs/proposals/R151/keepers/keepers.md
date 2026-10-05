# Keepers: improved 3D models, revision 2 (proposal, previews only)

**Status:** waiting for your OK. Nothing in the game's code (`src/`) has changed.

Revision 2 follows your feedback and your six Steal an Egg screenshots:
- **Faces** now have life: eye whites, big glowing irises, pupils, white highlights, eyelids, brows and mouths.
- **Five face states** per keeper, swapped by what the keeper is doing.
- **A personality** per keeper, shown in its face and body.
- **The reference style:** chunky, angular low-poly, studs, bold markings, big effects and a big "Z" when asleep.
- **No floating pieces** except the Storm Colossus, which you allowed. This is checked automatically.
- **The Crystal Knight** keeps a closed helmet: only his eyes change.

## Look at these first
1. `keepers_faces.png`: every keeper's face in all five states (idle, spotted you / chase, attack, asleep, caught you / gloat).
2. `keepers_before_after.png`: every keeper today (left) and proposed (right), same camera and scale, with a 5-stud player.
3. `keepers_lineup.png`: all keepers in a row next to 5-stud players, today on top, proposed below, ruler in studs.
4. One sheet per keeper, with 8 views (front, three-quarter, side, back, chase, wind-up, impact, asleep) and its five
   face states:
   `keeper_timber_golem.png`, `keeper_jungle_king.png`, `keeper_sand_snake.png`, `keeper_ice_fang.png`,
   `keeper_lava_dragon.png`, `keeper_crystal_knight.png`, `keeper_storm_colossus.png`, `keeper_the_darkened.png`.

These are real Blender models rendered in Cycles. The chase, attack and asleep views use the game's own pose frames for
that keeper, so they also show that today's animation code moves the new models without changes.

## 1. The references (your screenshots)
I looked at your six screenshots. They are not added to the repo, because they are another game's images. This is what
I saw:

| Reference | What it looks like |
|---|---|
| Mitsui (Japanese biome) | A white wolf / fox, curled up asleep. Angular white body with spiky white fur shards, bold red swirl markings on body and face, red horns sweeping back, pink cherry blossoms along the back, a glowing red eye with red eye markings, a pink lightning aura, and a big "Z". |
| Jungle King (gorilla) | Towers over the player. Navy fur with the stud texture, huge spiky shoulder tufts, a cream face mask and chest with a jagged edge, a spiky gold crown with a gem, a gold arm band, red glowing angry eyes under heavy brows, and a wide roaring mouth with fangs and a red inside. It roars even asleep, with a big cyan "Z" in front of it. |
| Lava dragon | Charcoal angular plates with studs, a row of flaming spikes along the back, orange lava blocks along the spine, and a flaming tail tip. Asleep, with a big "Z". |
| T-Rex | Green with bold dark stripes, a cream belly, and an open toothy jaw. Asleep, with "ZZ". |
| Moby (whale) | A white blocky whale with a dark square eye. Asleep, with a "Z". |
| Winged angel / knight boss | Huge, split into white-gold and red-black halves, with glowing halo rings and fire effects. |

What they share:
- Chunky, angular, faceted low-poly shapes, not smooth blobs.
- The Roblox stud texture on big surfaces.
- Bold markings: swirls and stripes.
- Strong contrast between body and accent colours.
- Glowing eyes.
- Big particle effects: fire, auras, lightning.
- A big stylised "Z" over a sleeping keeper.
- They are 3 to 6 times taller than the player.
- Nothing floats except the effects.

Earlier text research: a web search for "Mitsui" found nothing. The web pages and image hosts were blocked here
(Roblox, YouTube, Fandom, guide sites). Search summaries name a "Kitsune" as the Cherry Blossom guardian, which may be
the same fox-like keeper, but I cannot confirm that. Everything in the table above comes from your screenshots only.

**What each of our keepers takes from which reference:**

| Our keeper | Taken from | How |
|---|---|---|
| Jungle King | Jungle King (very close in spirit) | Navy fur, spiky shoulder tufts, cream face mask and jagged cream chest, spiky gold crown with a red gem, gold arm band, red glowing angry eyes, roaring mouth with fangs and a red inside. |
| Lava Dragon | Lava dragon | Charcoal angular plates, glowing flaming spikes along the back (flame effects), orange lava seams, flaming tail tip. |
| Ice Fang | Mitsui | The bold-marking idea in ice blue: swirls on shoulders and haunches, eye markings, ice-crystal horns sweeping back, spiky fur shards. Your silver-and-sapphire armour stays. |
| Sand Snake | T-Rex | Bold dark diamond markings and a light belly, a toothy mouth, back spines. |
| Timber Golem | Shared style | Angular shapes, shard-like leaves and moss, glowing sap cracks, studs, a bold face. |
| Storm Colossus | Angel boss | Big glowing effects (lightning links), a strong accent colour, floating parts as a design choice. |
| Crystal Knight | Angel boss | A knight with a closed helm and a bold crest; glowing eyes only. |
| The Darkened | Shared style | Faceted shard cloak, bold markings on the mask, an aura effect. |

## 2. Personality, faces and body, per keeper
Every keeper has five face states:
- idle / guarding;
- spotted you / chase (angry);
- attack (roar, yell);
- asleep (closed eyes, drool or smoke);
- caught you / gloat (laughing, smug).

| Keeper | Personality | Face states | Body, pose, details | Idle fidget (idea) | Effects (particles) |
|---|---|---|---|---|---|
| Timber Golem (Forest) | Grumpy old forest grump: hates being woken, glares from under mossy brows, a bird lives in his hair. | Idle: heavy lids, one brow lower, frown. Chase: brows slammed down, wooden teeth bared. Attack: roar. Asleep: closed eyes, "o" mouth, sap drool. Gloat: lopsided toothy grin, squinting. | Bushy moss brows, moss beard, glowing sap cracks, red mushrooms, a bird's nest with eggs and a little blue bird on the crown. **The left arm is a huge club log with a sprouting branch; the right arm is smaller.** Still sleeps disguised as a tree. | Scratches his bark; the bird hops and chirps; leaves drift down. | Falling leaves, spores, sap drips, dust on the hammer slam. |
| Jungle King (Jungle) | Cocky show-off king: smirks with a gold tooth, chest puffed out, crown tilted, loves an audience. | Idle: one brow up, half-lidded smirk, gold tooth. Chase: snarl with fangs. Attack: huge roar. Asleep: mouth hanging open, drool. Gloat: laughing, eyes squeezed shut. | Chin up, puffed pecs, tilted crown, gold arm band on one arm, spiky forearm tufts. | Beats his chest twice and adjusts his crown. | Chest-beat shockwave, dust, leaves, red eye glow. |
| Sand Snake (Desert) | Sly, smug trickster: half-lidded eyes, a lopsided smirk, always looks like it knows something you do not. | Idle: heavy lids, one brow raised, smirk. Chase: narrowed eyes, hiss with fangs. Attack: wide eyes, gaping mouth. Asleep: closed eyes, lazy smile, drool. Gloat: sly closed-eye smile. | Head tilted, hood with two big eye-spot markings, horns, spines along the back. | Flicks its tongue, sways its head, rattles the tail. | Sand swirl, dust trail. The rattle still buzzes. |
| Ice Fang (Snow) | Proud, noble guardian: chin up, calm and composed, only bares its sabres when it means it. | Idle: calm half lids, faint smile. Chase: fierce. Attack: roar. Asleep: peaceful closed eyes. Gloat: proud wink and smug smile. | Chin up, ice horns, bold ice-blue swirls and stripes, spiky ruff, armour built in. | Licks a paw, then lifts its head and flicks the crystal tail. | Frost aura, snowflake sparkles, icy breath on the roar. |
| Lava Dragon (Lava) | Hot-headed: always furious, snorts smoke when annoyed, roars at the slightest thing. | Idle: furrowed brows, pout, smoke puffs. Chase: yelling. Attack: roar with a fire-orange mouth. Asleep: closed eyes, smoke. Gloat: toothy grin, squint. | Charcoal plates, glowing flaming back spikes, lava seams and cheek cracks, flaming tail tip. | Snorts two smoke puffs, stomps, the back flames flare. | Flames on spikes and tail, embers, nostril smoke. |
| Crystal Knight (Crystal) | Stern, by-the-book sentinel: stands to attention, sword upright, never lets anything slide. | **Eyes only, glowing in the visor slit.** Idle: calm narrow bars. Chase: sharp angry slants. Attack: wide, bright, flared. Asleep: dim flat lines. Gloat: happy ^ ^ arcs. | **Closed helmet, no face.** Tall crystal crest and plume, gold brow band, nose guard, breathing holes, tabard with a gold emblem, crystal pauldrons, crystal blade. | Straightens up, taps the hilt, turns the helm left and right like a guard on patrol. | Crystal sparkles, a sword slash trail, shards on impact. |
| Storm Colossus (Storm) | Loud brute: shouts everything, huge underbite, laughs like thunder; fists float on storm power. | Idle: grumpy frown. Chase: yelling. Attack: thunder roar, glowing blue mouth. Asleep: snoring, drool. Gloat: thunder laugh, eyes shut. | Huge jaw with tusks, storm-cloud mane, copper lightning-rod horns, glowing lightning cracks. **Floating shoulder rocks and fists (by design), linked by lightning.** | Punches its floating fists together (sparks), cracks its neck. | Lightning arcs between body and floating parts, sparks, a rain cloud. |
| The Darkened (Void event) | Creepy and silent: never speaks, tilts its head, stares; the smile is the scariest part. | Idle: blank stare, tiny mouth. Chase: wide staring eyes. Attack: the mask splits into a jagged grin. Asleep: closed eyes. Gloat: crescent eyes, a far-too-wide smile. | Tilted head, hood, shard cloak, void markings and glowing cleft on the mask, long claws. | Slow head tilt, fingers drum the air, the cloak drifts. | Purple void smoke and motes, eye trails while chasing. |

## 3. How the face states would work in Roblox
**Route: one small face mesh per state, swapped by hiding the others.**
- Each keeper's Head group gets 5 small MeshParts (`Head_Face_Idle` ... `Head_Face_Gloat`). Each one holds the
  eyelids, brows, mouth and cheeks for that state.
- The eye whites, irises and highlights stay on the head all the time.
- The client shows exactly one face part by setting `LocalTransparencyModifier` to 0 on it and 1 on the others. This is
  the same trick the game already uses for the golem's eyes.

Why this route:
- **Instant and robust.** There is no network traffic, no texture download and no pop-in. It works with the Neon eyes.
- **Faces stay 3D.** They keep their shape on a curved head.
- **Why not decals or textures.** That needs 5 uploaded images per keeper, which lie flat on curved heads and can show
  blank for a moment the first time they switch. Swapping a SurfaceAppearance costs more memory.
- **The cost.** 4 hidden parts per keeper, kept in memory. Roblox does not draw them.

When each state shows (taken from today's keeper states):

| Keeper state | Face shown |
|---|---|
| sleeping / guarding | Asleep |
| alerted, chasing, dashing | Chase |
| attack window | Attack |
| a landed catch (today's taunt window) | Gloat |
| returning home | Idle |

Two small code changes would be needed: the face switch in `BeastAnimation`, and a one-line skip in `KeeperContact` so
the face parts never count for hits. The Knight works the same way with five glowing eye parts. Asleep, the existing eye
logic already dims them.

**Sleeping "Z":** make today's three small "z" labels into one big stylised cyan "Z" with a dark outline, like the
references. This only changes the existing sleep labels, with no new asset. The Golem keeps no "Z", because it sleeps
disguised as a tree. In the previews the "Z" is a stand-in mesh that is turned to face the camera before each render,
as a BillboardGui does in game.

**Stud texture (option):** the previews show it on. In Roblox it would be a stud normal map, either as a MaterialVariant
or a SurfaceAppearance (1 tile = 1 stud). This needs a Studio test: on a MeshPart a texture follows the mesh's UVs, and
today's UVs point at the colour palette, so the FBX may need a second UV layout. You can also leave the studs off.

## 4. No floating pieces (checked by script)
`blender/connectivity.py` builds each keeper and finds every separate piece of mesh. It counts two pieces as joined if
they touch, overlap, come within 0.02 studs, or one sits inside the other. Each keeper must be **one connected piece**.
The check runs:
- in the rest pose, with all five face states shown at once;
- in every rendered pose (the game's real frames), with that pose's face state.

Effects (fire, lightning, the "Z") are not meshes and are skipped.

| Keeper | Rest (all faces) | Stand / idle | Chase | Wind-up | Impact | Asleep | Gloat | Floating pieces |
|---|---|---|---|---|---|---|---|---|
| Timber Golem | 1 | 1 | 1 | 1 | 1 | 1 (tree) | 1 | 0 |
| Jungle King | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Sand Snake | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Ice Fang | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Lava Dragon | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Crystal Knight | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Storm Colossus | 1 + 6 by design | 1 + 6 by design | 1 + 6 by design | 1 + 6 by design | 1 + 6 by design | 1 + 6 by design | 1 + 6 by design | 0 failures; 6 by design: 2 shoulder rocks, 2 fists, 2 storm-core orbs |
| The Darkened | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 |

(The numbers are connected pieces. "1" means everything touches.)

How the gaps the check found were closed:
- **Snake wind-up.** The game's coil lifts the head about 2.4 studs off the body. The neck now has a root that runs down
  into the first body segment. At rest it is hidden inside the body and under the floor; in the coil it spans the gap.
- **Joints.** Each moving group has a ball at its pivot, which stays in place however the group turns, and the parent
  part overlaps it. This covers the dragon's wing shoulders, the jaw hinges, and the hips and shoulders of the golem,
  knight and gorilla.
- **Small details.** Nostrils, teeth, horn bases, hood marks, ribs and the chest crack were sunk into the body, and
  painted bands are always sunk into the surface. The faceted shapes sit slightly inside the ideal curve, so details
  placed on the curve were floating.
- **The Darkened's feet.** When its knees fold asleep, foot and shin would part. A cosmetic ankle ball keeps them
  joined, and its hit boxes stay as they are today.
- **Accents.** The Knight's orbiting shards and the Colossus's floating cloud are retired: the crest and the cloud mane
  replace them. The Snake's rattle is checked too and touches the tail.

## 5. What stays the same
- Speed, strike distance and timing, and the catch rule.
- Fling and ragdoll, sounds and voices.
- Sleep and wake, and the golem's tree disguise.
- Group names and pivots, so the existing animation code is unchanged.
- Sizes: each part fits today's group boxes within about 1 stud. The exceptions are crowns, crests, horns and spikes on
  top, listed per group in `fbx/keeper_<name>.json`. The Darkened's body pieces stay inside its hit boxes, and its new
  hood, cloak, claws and ankles are cosmetic.
- Heights in the lineup (studs, today to proposed):
  - Golem 25.5 to 27.0;
  - Jungle King 15.6 to 17.4 (crown);
  - Snake 8.1 to 10.7 (raised head and horns);
  - Ice Fang 10.9 to 10.9;
  - Dragon 18.8 to 19.6;
  - Knight 34.0 to 33.9;
  - Colossus 41.1 to 35.8 (today's floating cloud is retired);
  - The Darkened 18.5 to 20.4 (hood).

## 6. Phone cost
| Keeper | Triangles on screen (lite build) | With all 5 face states in memory | Mesh parts (today) |
|---|---|---|---|
| Timber Golem | 9,028 (7,032) | 16,708 | 19 (63 blocks + 3) |
| Jungle King | 5,866 (4,446) | 13,086 | 13 (23) |
| Sand Snake | 6,090 (4,306) | 12,302 | 17 (17 + 3) |
| Ice Fang | 7,254 (5,618) | 12,918 | 14 (21 + 41) |
| Lava Dragon | 6,948 (5,324) | 13,608 | 23 (27) |
| Crystal Knight | 3,506 (2,646) | 4,306 | 16 (50 + 3) |
| Storm Colossus | 4,706 (3,498) | 11,918 | 20 (30 + 5) |
| The Darkened | 5,844 (4,250) | 11,172 | 31 (43) |

- **Target:** under 10,000 triangles on screen per keeper. All eight meet it.
- The largest single mesh is about 2,400 triangles; Roblox allows 20,000.
- One 256 x 256 palette texture per keeper.
- Fewer parts than today for six of the eight keepers. The snake and the Darkened land about level.
- Hidden face parts are not drawn, but they still move with the head. The client could skip moving hidden parts.
- Not measured on a device.

## 7. How it would be implemented (after your OK)
**What you would do:**
1. In Studio, import each `fbx/keeper_<name>.fbx` with the 3D Importer. Check the part sizes against
   `fbx/keeper_<name>.json` (1 unit = 1 stud, facing -Z), then upload.
2. Put the eight models in ServerStorage (I will give the folder name), save, and send me the place.

**What I would do in the next release:**
1. Fill `KeeperRigConfig` from the manifests: parts, groups, centres, sizes, eye, glow and face-state flags, and new
   floor samples. Pivots stay unchanged.
2. Make `BeastModels` use the new models for all seven stages, and bump the visual version.
3. Add the face-state switch to `BeastAnimation`, and make `KeeperContact` skip face parts.
4. Golem: give each piece its tree pose. This is already worked out from today's parts.
5. Retire the accents that are now in the meshes or would float:
   - the golem's rune and mushrooms;
   - the tiger's spines and armour;
   - the knight's shards;
   - the colossus's cloud.

   Keep the snake's rattle.
6. Dragon: the wings are exported at in-game size, so remove the old x1.35 wing stretch.
7. The Darkened: swap its blocks for the new parts, using the same groups and offsets.
8. Restyle the sleep "Z" and add the particle effects listed above.
9. Run the keeper test suites. Then you check it in Studio.

## 8. Risks
- **The references are six screenshots.** I matched what they show. I made no other claims about the reference game.
- **Today's images are partly stand-ins.** The snake, tiger, dragon and gorilla are drawn from the game's sample points
  in an assumed colour, because their meshes can't be downloaded here. The golem, knight, colossus and The Darkened
  are their exact parts.
- **Body-touch catches follow the new shapes.** Distance catches are unchanged.
- **Untested in Studio:** the FBX import (it round-trips in Blender), vertex colours, how the stud texture tiles on a
  MeshPart, and how bright Neon looks.
- **The lite build is not connectivity-checked.** Only the full build was checked; the lite build should be re-checked
  if you choose it.
- **One install.** The game only animates a keeper whose part count matches the config, so the models and the config
  must go in together.

## 9. Choices for you
- **A.** This style (faceted, studs, bold markings) as shown, or the same models without the stud texture.
- **B.** Full detail, or the lite build.
- **C. Which keepers first:**
  - Option 1: the Jungle King and the Lava Dragon. They are closest to your references.
  - Option 2: biome order, starting with Forest.
- **D. Tiger armour:** built into the mesh, or kept as separate parts.
- **E. The Colossus cloud:** a floating cloud above the head (by design), or the attached cloud mane shown.
- **F. The Darkened:** include it, or leave it as it is.

## Files
- **Previews:** `keepers_faces.png`, `keepers_before_after.png`, `keepers_lineup.png` and `keeper_<name>.png`.
- **In `fbx/`:**
  - `keeper_<name>.fbx`: one mesh per part, placed on the rig, including the five face states, with the palette texture
    embedded. Effects are not included.
  - `keeper_<name>_atlas.png`: the palette texture.
  - `keeper_<name>.json`: for each part, its name, group, centre, size, triangles, eye, glow and face-state flags, the
    golem's tree mapping, and the Darkened's cosmetic flags. For each group, its bounds against today's and its floor
    samples.
- **In `blender/`:**
  - `proposed.py`: the eight models.
  - `faces.py`: eyes, lids, brows and mouths.
  - `kit.py`: shapes, studs, the "Z", the connectivity graph and the render helpers.
  - `connectivity.py`: the no-floating-pieces check.
  - `assemble.py`, `render_all.py`, `compose_sheets.py`: building, rendering and laying out the previews.
  - `today.py`: today's keepers.
  - `dump_poses.luau`: the game's real pose frames.
  - `data.py`, `luaparse.py`: reading the game's data.
  - `check_fbx.py`, `tricount.py`: the FBX check and the triangle counts.
  - `run.sh`: rebuilds everything.

## How this was made (what was run and what was reasoned)
**Run:**
- Blender 4.5 (the Python module) built every model by script and rendered every image in Cycles on the CPU.
- The FBX files were exported and re-imported (`check_fbx.py`): every part came back, and the worst centre or size
  difference against the manifests was 0.0001 studs. The largest FBX is 544 KB, under the 5 MB limit.
- The connectivity check (table above) ran on the rest pose and on every rendered pose.
- The poses come from the game's own Luau modules (`BeastPose`, `KeeperSignatureStrike`, `VeiledKeeper81` and
  `KeeperAccents`), run on the repo's offline Roblox mock.

**Reasoned, not run:**
- Matching the screenshots' style.
- Studio import, the stud texture tiling and vertex colours.
- The cost on phones.
