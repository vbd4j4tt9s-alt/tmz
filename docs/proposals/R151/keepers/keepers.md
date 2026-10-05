# Keepers: improved 3D models, revision 4 (proposal, previews only)

**Status:** waiting for your OK. Nothing in the game's code (`src/`) has changed.

Revision 4 follows your feedback on revision 3 and the reference images you sent:
- **Roblox charm, clunkier bodies.** Every keeper except The Darkened is rebuilt as a classic Roblox block build:
  - chunky blocks, wedges and cylinders with slightly bevelled edges, not hewn blobs;
  - thick limbs, big heads, hands and paws;
  - few small details, and the stud texture on the big faces.
- **Faces redone.** The rev 3 faces were "stretched" and "off" because each shape was bent over the facets of an uneven
  head. Now:
  - every head has a flat face plane, the front of a block;
  - every face shape is a flat decal laid on that plane, so nothing bends or stretches;
  - the two eyes are one outline mirrored, so they are always the same size and shape, placed symmetrically;
  - fewer, bolder shapes;
  - still two states: fierce awake, eyes closed asleep.
- **Ice Fang:** a fox head. It is streamlined, with a tapered pointed snout, big triangular ears, almond eyes and cheek
  ruffs.
- **Crystal Knight:** bulky, after your knight reference. It has:
  - huge stacked pauldrons and ribbed arms;
  - a great helm with a crest and a wing plume;
  - a layered chest, a heavy belt and thick legs.
- **Jungle King:** today's in-game gorilla, improved (your screenshots). Its colours, mask, yellow eyes, mossy
  shoulders and hunched build are kept.
- **Sand Snake:** today's in-game snake, improved (your screenshots). Its tan diamond back, viper head, yellow eyes and
  rattle are kept.
- **Lava Dragon:** after your two "Ice and Fire" fire-dragon references, built from cuboids.
- **Timber Golem and Storm Colossus:** more blocky, stacked blocks and slabs, with the same simple glowing-slit faces.
- **The Darkened:** unchanged from rev 3, as you asked. Its code is byte-for-byte the same; it is only re-rendered.
- **Still in place:**
  - the one-piece check, now passed by all eight in every pose;
  - the game's real pose frames, unchanged group names and pivots;
  - the big sleep "Z", the effects, the FBX export and the budgets.

## Look at these first
1. `keepers_faces.png`: one row of all 8 keepers, each with its awake / chase face above its asleep face.
2. `keepers_before_after.png`: every keeper today (left) and proposed (right), same camera and scale, with a 5-stud
   player. The gorilla's and the snake's "today" are now drawn from your screenshots (see section 5).
3. `keepers_lineup.png`: all keepers in a row next to 5-stud players, today on top and proposed below, with a ruler in
   studs.
4. One sheet per keeper:
   - 8 views: front, three-quarter, side, back, chase, wind-up, impact and asleep;
   - both faces, with notes beside them;
   - files `keeper_timber_golem.png`, `keeper_jungle_king.png`, `keeper_sand_snake.png`, `keeper_ice_fang.png`,
     `keeper_lava_dragon.png`, `keeper_crystal_knight.png`, `keeper_storm_colossus.png` and `keeper_the_darkened.png`.

These are real Blender models rendered in Cycles. The chase, attack and asleep views use the game's own pose frames for
that keeper, so they also show that today's animation code moves the new models without changes.

## 1. The references you sent for rev 4
I looked at every image. None of them is added to the repo. This is what I took from each:

| Reference | What it shows | What I used |
|---|---|---|
| Dragon 1 (a modelling-tool render, plain orange) | A blocky dragon in the "Ice and Fire" style, made only of cuboids. Huge spread wings: each is a thick angled arm beam and a fan of long rectangular finger struts from the wrist, with stepped membrane panels between them and small claw tips. A blocky head with a long square snout and a tall crown of swept-back horn and frill spikes. A short thick neck, a row of thin back spikes, a chunky low body and sturdy legs with separate stubby toe blocks. | The fanned strut wings with stepped membranes and claw tips, the head crown, the long square snout, the low chunky body and the toe blocks. |
| Dragon 2 (described to me; not saved to disk) | An "Ice and Fire" fire dragon in flight, a Minecraft-style render. A long slim charcoal body and a long stepped neck. An open jaw with a red mouth and white block teeth, and a small yellow eye. Bone-tan horns, and a continuous row of tan spikes from the neck to the tip of a long tapering tail. Dark wing beams, lighter membranes with stripes along the fingers and tan claws. Lighter scale bands under the belly and neck. | The long stepped neck, the bone spike row from the neck to the tail tip, the long tail, the red mouth with white block teeth, the striped membranes, the bone claws and the lighter belly bands. |
| Knight (a Blender viewport) | A bulky, R6-proportioned armoured knight, dark and aggressive. Huge layered pauldrons (stacked, angled slabs) wider than the torso. Thick arms with horizontal ribbed bands, and a skull ornament on the outer arm. A closed great helm with a vertical crest ridge and a feather / wing plume on one side. A chest plate with a centre ridge and layered plates, a heavy belt, skull ornaments on the thighs and chunky leg armour. | All of the bulk and layering. Crystal medallions replace the skulls; purple / lavender armour; glowing visor eyes; a crystal blade. |
| Gorilla (3 in-game screenshots) | Today's Jungle King: dark brown shaggy fur in chunky low-poly masses, hunched on its knuckles. A grey-green face mask and chest plate, heavy brows, glowing yellow angled eyes and a dark mouth with small teeth. Green moss on the shoulders and upper arms; a broad back and thick arms. | Everything listed, kept and polished (section 2). |
| Snake (3 in-game screenshots) | Today's Sand Snake: a long rattlesnake in tan / beige with a darker brown diamond pattern along the back. A wedge-shaped viper head with a yellow eye, a dark eye stripe and small golden horns over the eyes. A golden lower jaw, a red tongue, and a small rattle with a light tail tip. It rears up in an S-curve when chasing. | Everything listed, kept and polished (section 2). |

**Ice and Fire:**
- The dragon follows the "Ice and Fire" fire-dragon style from your two images and from my general memory of that
  mod. The web and image sites are blocked here, so I could not look up the mod itself.
- It is our own model in that style, not a copy of the mod's assets.
- If you want it closer, send more screenshots (side, front and top views help most).

The rev 3 references (the six Steal an Egg screenshots) still set the general style: chunky shapes, studs, bold
markings, glowing eyes, big effects and the big sleep "Z".

## 2. Each keeper: personality, faces and body
Every keeper has two faces:
- **Awake / chase:** shown whenever it is awake (guarding, chasing, attacking, after a catch).
- **Asleep.**

| Keeper | Personality | Awake / chase face | Asleep face | Body, pose, details | Effects (particles) |
|---|---|---|---|---|---|
| Timber Golem (Forest) | Grumpy old tree that hates being woken; a bird lives in its crown. | Not human. Two glowing green slits in dark hollows under a heavy bark ledge, and a jagged dark crack. | The slits go dim and the crack thins, so the disguised tree shows no face. | **More blocky.** Two stacked trunk blocks, a moss slab with hanging moss, dark bark planks, glowing sap cracks and bracket fungi. A block stump head and a stepped crown of leaf blocks with a nest, eggs and a blue bird. **The left arm is a huge club block with a sprouting branch; the right is smaller.** Block feet with root toes. Still sleeps disguised as a tree. | Falling leaves, spores, sap drips, dust on the hammer slam. |
| Jungle King (Jungle) | Grumpy jungle king: hunched on his knuckles, glares, roars in your face, wears a crown of moss. | Glowing yellow angry eyes in dark sockets on the flat grey-green mask, under a heavy V brow. A roaring mouth with teeth and fangs on the muzzle. | Closed eyes and a round snoring mouth. | **Today's gorilla, improved.** The same dark brown fur, grey-green mask and chest plate, yellow eyes, moss on the shoulders and upper arms, and hunched knuckle-walking build. Now chunky blocks with a broad back, vine bands on the forearms, leaf accents, grey-green knuckle pads, and a small moss crown with leaf points and one pink flower. | Chest-beat shockwave and dust, falling leaves, yellow eye glow. |
| Sand Snake (Desert) | Sly desert rattler: rears up in an S, narrows its yellow eyes and flashes its fangs. | On each flat side of the head: a fierce yellow slit eye under a dark brow bar. The mouth opens red, with two white fangs. | A closed-eye line on each side; mouth closed. | **Today's snake, improved.** The same tan body with brown diamonds (tan centres) along the back and half-diamonds on the sides. The same wedge viper head with the dark eye stripe, small golden horns on the brow ridges, the golden lower jaw, the forked tongue and the rattle. Now chunkier block segments and a bigger, more readable head, with a brown chevron on top. | Sand swirl, dust trail; the rattle still buzzes. |
| Ice Fang (Snow) | Proud, cold snow fox: chin up, sly icy glare, bares its sabres when it sees you. | Almond icy-cyan eyes with slit pupils, slanted blue brows, and a row of small teeth under the snout. | Closed eyes, relaxed brows. | **A fox head:** a streamlined head with a tapered pointed snout, big triangular ears with blue insides, almond eyes, white cheek ruffs and a blue bridge stripe. Still the Snow keeper: icy white and blue, bold blue stripes and cheek marks, the silver-and-sapphire saddle, collar and leg plates, two sabre fangs, ice-blue claws, and a bushy block tail ending in ice crystals. | Frost aura, snowflakes, icy breath on the snarl. |
| Lava Dragon (Lava) | Hot-headed and furious: glares, snarls fire, snorts smoke even in its sleep. | Furious yellow slit-pupil eyes under angled brow blocks. The open jaw glows fire-orange between white block teeth. | Grumpy closed eyes; smoke puffs (effect). | **The "Ice and Fire" style in cuboids.** A low chunky charcoal body with dark red scale bands, glowing lava seams and orange belly plates. A long stepped neck and a long square snout with block teeth. A crown of swept bone horns, cheek frills and crest spikes. Bone spikes from the neck to the tail tip, several of them flaming. Sturdy legs with bone toe blocks, and a long tail ending in a glowing spade. **Wings:** a thick arm beam and a fan of five finger struts, with stepped, striped membranes and bone claw tips. | Flames on the back spikes and tail tip, embers, nostril smoke, fire glow in the jaw. |
| Crystal Knight (Crystal) | Stern, merciless sentinel: plants his feet, sword ready, two burning slits in a closed great helm. | Two fierce glowing slants in the visor slit. | Two dim flat lines. | **Bulky, after your reference.** Three stacked, angled pauldron slabs per shoulder with crystals; ribbed upper arms with a crystal medallion; chunky ribbed gauntlets. A closed great helm with a crest ridge over the top and down the front, a crystal crest and a crystal wing plume. A layered chest with a centre ridge and a crystal core. A thick gorget, a heavy belt with a crystal buckle, tassets with crystal medallions, thick thighs with crystal medallions, knee plates, greaves and big boots. The crystal blade. | Crystal sparkles, a sword slash trail, shards on impact. |
| Storm Colossus (Storm) | A walking storm of stacked rock: no face, only two burning slits and a crackling jaw; fists float on storm power. | Not human. Two glowing cyan slits in dark hollows under a rock ledge, and a glowing jagged crack across the jaw. | The slits go dim, the crack goes dark. | **More blocky:** a stacked rock torso, a mantle slab, pec slabs, block hips and rock shards. A block head with a protruding jaw, rock tusks, copper lightning-rod horns and a cloud mane of cloud blocks. **Floating shoulder rocks, fists (with copper bands) and crystal storm cores, by design**, linked by lightning. | Lightning arcs, sparks, a rain cloud. |
| The Darkened (Void event) | Silent and wrong: today's faceless black head and its one glowing line. | The line glows bright void purple. | The line dims. | **Unchanged from rev 3.** | Void wisps; the line pulses. |

## 3. How the two faces work
**The faces themselves:**
- Every face is a set of flat plates on a flat face plane (the front of a block): the front of the head, the muzzle, or,
  on the snake, the flat sides of its wedge head.
- Each plate has an even thickness and is sunk into the head, so it always touches the head.
- The eyes are one outline drawn once and mirrored, so both eyes have the same size and shape and sit symmetrically.
- The awake face uses a few bold shapes: a dark socket, the glowing eye, a pupil, a brow bar, and a mouth with a few
  big teeth. The asleep face is a thick closed-eye line and a small mouth.

**In Roblox: two face parts per keeper, swapped by hiding one of them.**
- **The parts:** each keeper's Head group has the parts of the awake face (`Head_Face_Chase`, plus `Head_Eyes_Chase`
  for its glowing eyes) and of the asleep face (`Head_Face_Asleep`, and `Head_Eyes_Asleep` where the asleep eyes still
  glow dimly).
  - The Knight's and The Darkened's faces are glow parts only.
  - The Colossus's glowing slits and crack are in `Head_Eyes_Chase`.
- **The rule:** asleep shows the asleep parts; any other state shows the awake parts. The client sets
  `LocalTransparencyModifier` to 0 on one set and 1 on the other. The game already uses this trick for the golem's
  eyes.
- **Why this route:**
  - It is instant: no network traffic, no texture download, no pop-in.
  - It is one yes / no test (asleep or not).
  - Decals would need images uploaded per keeper and can show blank for a moment on first use.
- **The cost:** one hidden face set per keeper, kept in memory: 16 to 152 triangles. Roblox does not draw it.

Two small code changes would be needed: the face switch where the client knows the keeper is asleep (`BeastAnimation`),
and a one-line skip in `KeeperContact` so face parts never count for hits.

**Sleeping "Z":** make today's three small "z" labels into one big stylised cyan "Z" with a dark outline. This only
changes the existing sleep labels, with no new asset. The Golem keeps no "Z", because it sleeps disguised as a tree.

**Stud texture (option):**
- The previews show it on. In Roblox it would be a stud normal map, either as a MaterialVariant or a SurfaceAppearance
  (1 tile = 1 stud).
- The block shapes suit it much better than rev 3's facets.
- On a MeshPart a texture follows the mesh's UVs, so the FBX may need a second UV layout. A Studio test will tell.

## 4. No floating pieces (checked by script)
`blender/connectivity.py` builds each keeper and finds every separate piece of mesh. It counts two pieces as joined if
they touch, overlap, come within 0.02 studs, or one sits inside the other. Each keeper must be **one connected piece**.
The check runs:
- in the rest pose, with both faces shown at once;
- in every rendered pose (the game's real frames), with that pose's face.

Effects (fire, smoke, wisps, lightning, the "Z") are not meshes and are skipped.

| Keeper | Rest (both faces) | Stand | Chase | Wind-up | Impact | Asleep | Floating pieces |
|---|---|---|---|---|---|---|---|
| Timber Golem | 1 | 1 | 1 | 1 | 1 | 1 (tree) | 0 |
| Jungle King | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Sand Snake | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Ice Fang | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Lava Dragon | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Crystal Knight | 1 | 1 | 1 | 1 | 1 | 1 | 0 |
| Storm Colossus | 1 + 6 by design | 1 + 6 by design | 1 + 6 by design | 1 + 4 by design | 1 + 6 by design | 1 + 6 by design | 0 failures. By design: 2 shoulder rocks, 2 fists, 2 crystal storm cores. In the wind-up, the left fist and the right shoulder rock touch the body. |
| The Darkened | 1 | 1 | 1 | 1 | 1 | 1 | 0 |

(The numbers are connected pieces. "1" means everything touches.)

How the pieces stay joined:
- **Joints.** Each moving group has a core cube centred on its pivot, which stays in place however the group turns,
  and the parent overlaps it.
  - Each cube is a little under its nominal size, so it never shares a face with a block of the same width.
  - The knight's body has a hip block around both leg pivots, so the legs touch it at any swing.
- **The dragon's wings.** Every finger strut starts inside the wrist block, every membrane runs through the struts on
  its edges, and the wing's core cube sits in the body. They stay one piece in all poses.
- **The snake.** Each segment has a core cube at its front pivot, inside the segment ahead. In the coil wind-up the head
  lifts about 2.4 studs off the body; the neck's hidden root spans the gap. The rattle (today's accent) touches the
  tail tip.
- **Faces.** Every face plate is sunk into the head, and each plate on top of another is sunk through it.
- **Accents.** The Knight's orbiting shards and the Colossus's floating cloud stay retired; the crest and the cloud
  mane replace them.

## 5. What "today" shows
- **Exact parts:** the Golem, Knight, Colossus and The Darkened are drawn from their native parts in the game's source.
- **From your screenshots:** the Jungle King and the Sand Snake.
  - Their uploaded meshes still can't be downloaded here, so the shapes are the hull of the game's own sample points,
    plus their exact untextured details from `KeeperRigConfig`: the gorilla's mask, chest plate, yellow eye bar and arm
    moss, and the snake's eye bar, brow and golden jaw.
  - The colours now come from your screenshots: the gorilla's dark brown, and the snake's tan with a brown diamond
    pattern.
  - They are labelled "TODAY - from owner screenshots".
- **Stand-ins:** Ice Fang and the Lava Dragon are still stand-ins (hull and assumed colour).

## 6. What stays the same
- Speed, strike distance and timing, and the catch rule.
- Fling and ragdoll, sounds and voices.
- Sleep and wake, and the golem's tree disguise.
- Group names and pivots, so the existing animation code is unchanged.
- The Darkened, entirely (rev 3).
- **Sizes:**
  - Groups stay close to today's boxes.
  - Crowns, crests, horns, ears, plumes, back spikes and the Colossus mantle reach further.
  - Every group's overshoot is listed in `fbx/keeper_<name>.json`.
- **Heights in the lineup** (studs, today to proposed):
  - Golem 25.5 to 28.6 (stepped crown and nest);
  - Jungle King 15.6 to 17.3 (moss crown);
  - Snake 8.1 to 9.6;
  - Ice Fang 10.9 to 12.1 (ears);
  - Dragon 18.8 to 19.0;
  - Knight 34.0 to 35.0;
  - Colossus 41.2 to 36.5 (today's floating cloud is retired);
  - The Darkened 18.5 to 18.5 (unchanged).

## 7. Phone cost
| Keeper | Triangles on screen | With both faces in memory | Mesh parts (today) |
|---|---|---|---|
| Timber Golem | 4,524 | 4,596 | 16 (63 blocks + 3) |
| Jungle King | 3,836 | 3,988 | 10 (23) |
| Sand Snake | 5,384 | 5,480 | 14 (17 + 3) |
| Ice Fang | 5,172 | 5,292 | 11 (21 + 41) |
| Lava Dragon | 9,016 | 9,112 | 20 (27) |
| Crystal Knight | 6,124 | 6,148 | 13 (50 + 3) |
| Storm Colossus | 4,016 | 4,088 | 15 (30 + 5) |
| The Darkened | 3,172 | 3,188 | 25 (43) |

- **Target:** under 10,000 triangles on screen per keeper. All eight meet it; the dragon, with its two big fanned wings,
  is the heaviest.
- The largest single mesh is 2,124 triangles (a dragon wing); Roblox allows 20,000.
- One 256 x 256 palette texture per keeper.
- **Parts:** fewer than today for every keeper, 10 to 25.
- **The lite build** is no longer needed: block shapes have no segments to drop, so it saves nothing (1 % on the
  Colossus).
- Not measured on a device.

## 8. How it would be implemented (after your OK)
**What you would do:**
1. In Studio, import each `fbx/keeper_<name>.fbx` with the 3D Importer. Check the part sizes against
   `fbx/keeper_<name>.json` (1 unit = 1 stud, facing -Z), then upload.
2. Put the eight models in ServerStorage (I will give the folder name), save, and send me the place.

**What I would do in the next release:**
1. Fill `KeeperRigConfig` from the manifests: parts, groups, centres, sizes, eye, glow and face flags, and new floor
   samples. Pivots stay unchanged.
2. Make `BeastModels` use the new models for all seven stages, and bump the visual version.
3. Add the two-face switch (asleep or awake) to `BeastAnimation`, and make `KeeperContact` skip face parts.
4. Golem: give each piece its tree pose. This is already worked out from today's parts.
5. Retire the accents that are now in the meshes or would float:
   - the golem's rune and mushrooms;
   - the tiger's spines and armour;
   - the knight's shards;
   - the colossus's cloud.

   Keep the snake's rattle.
6. Dragon: the wings are exported at in-game size, so remove the old x1.35 wing stretch.
7. The Darkened: swap its blocks for the polished parts, using the same groups, offsets and sizes.
8. Restyle the sleep "Z" and add the particle effects listed above.
9. Run the keeper test suites. Then you check it in Studio.

## 9. Risks
- **The Ice and Fire dragon is from your two images and my memory of the mod.** I could not open the mod's pages
  here.
- **Today's images are partly stand-ins.** Ice Fang and the dragon are drawn from the game's sample points in an
  assumed colour; the gorilla and the snake use the same shapes, coloured from your screenshots.
- **Body-touch catches follow the new shapes.** Distance catches are unchanged.
- **Untested in Studio:** the FBX import (it round-trips in Blender), vertex colours, how the stud texture tiles on a
  MeshPart, and how bright Neon looks.
- **One install.** The game only animates a keeper whose part count matches the config, so the models and the config
  must go in together.

## 10. Choices for you
- **A.** Studs on, as shown, or the same models without the stud texture.
- **B. Which keepers first:**
  - Option 1: the Jungle King and the Sand Snake (improvements of what is live).
  - Option 2: biome order, starting with Forest.
- **C. The dragon:** as shown, or send more "Ice and Fire" screenshots to match it more closely.
- **D. Tiger armour:** built into the mesh, as shown, or kept as separate parts.
- **E. The Colossus cloud:** the attached cloud mane shown, or a floating cloud above the head (by design).

## Files
- **Previews:** `keepers_faces.png`, `keepers_before_after.png`, `keepers_lineup.png` and `keeper_<name>.png`.
- **In `fbx/`:**
  - `keeper_<name>.fbx`: one mesh per part, placed on the rig, including both faces, with the palette texture
    embedded. Effects are not included.
  - `keeper_<name>_atlas.png`: the palette texture.
  - `keeper_<name>.json`:
    - for each part: its name, group, centre, size, triangles, eye, glow and face flags, the golem's tree mapping, and
      the Darkened's cosmetic flags;
    - for each group: its bounds against today's, and its floor samples.
- **In `blender/`:**
  - `proposed.py`: the eight models.
  - `faces.py`: the flat graphic faces.
  - `kit.py`: shapes (blocks, beams, cylinders, chamfered blocks), studs, the "Z", the connectivity graph and the
    render helpers.
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
- The FBX files were exported and re-imported (`check_fbx.py`). Every part came back, and the worst centre or size difference against the manifests was under
  0.0001 studs. The largest FBX is 258 KB, under the 5 MB limit.
- The connectivity check (table above) ran on the final models, in the rest pose and every rendered pose.
- The triangle counts (`tricount.py`) were taken for the full and lite builds.
- The poses come from the game's own Luau modules (`BeastPose`, `KeeperSignatureStrike`, `VeiledKeeper81` and
  `KeeperAccents`), run on the repo's offline Roblox mock.
- The Darkened's source section was checked to be byte-identical to rev 3.

**Reasoned, not run:**
- Matching your reference images, and how "Roblox charm", "clunky" and "bulky" read.
- The "Ice and Fire" look beyond your two images.
- Studio import, the stud texture tiling and vertex colours.
- The cost on phones.
