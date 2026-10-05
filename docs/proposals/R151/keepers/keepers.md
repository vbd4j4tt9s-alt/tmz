# Keepers: improved 3D models, revision 3 (proposal, previews only)

**Status:** waiting for your OK. Nothing in the game's code (`src/`) has changed.

Revision 3 follows your feedback on revision 2:
- **Less bubbly.** The models are no longer soft, round and inflated:
  - masses are chunky hewn blocks with flat, irregular planes and bevelled edges;
  - limbs have chamfered ends;
  - the pieces are shards, spikes, longer claws and sharp horns;
  - colours are deeper, not pastel;
  - joint cores are hidden inside the limbs, so no balls show.
- **Two faces per keeper.** An awake / chase face, shown whenever the keeper is awake, and an asleep face. They replace
  the five states.
- **The Jungle King is the benchmark for attitude:** red angry eyes and a roaring mouth.
- **Timber Golem and Storm Colossus:** not human-like. They have no nose, brows, lips or rows of teeth: just two
  glowing slits and a crack. Asleep, the slits go dark, so the Golem still looks like a tree.
- **Crystal Knight:** a closed helmet. Fierce glowing slants awake, dim lines asleep.
- **The Darkened:** today's design is kept and polished: the same slim black head with its one glowing line, bright when
  awake and dim when asleep.
- **Still in place from rev 2:** the reference style, the stud texture, the big "Z", the effects and the one-piece check.

## Look at these first
1. `keepers_faces.png`: one row of all 8 keepers, each with its awake / chase face above its asleep face.
2. `keepers_before_after.png`: every keeper today (left) and proposed (right), same camera and scale, with a 5-stud
   player.
3. `keepers_lineup.png`: all keepers in a row next to 5-stud players, today on top and proposed below, with a ruler in
   studs.
4. One sheet per keeper:
   - 8 views: front, three-quarter, side, back, chase, wind-up, impact and asleep;
   - both faces, with notes beside them;
   - files `keeper_timber_golem.png`, `keeper_jungle_king.png`, `keeper_sand_snake.png`, `keeper_ice_fang.png`,
     `keeper_lava_dragon.png`, `keeper_crystal_knight.png`, `keeper_storm_colossus.png` and `keeper_the_darkened.png`.

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
| Sand Snake | T-Rex | Bold dark diamond markings and a light belly, fangs, back spines. |
| Timber Golem | Shared style | Hewn angular shapes, shard-like leaves and moss, glowing sap cracks, studs, glowing eyes. |
| Storm Colossus | Angel boss | Big glowing effects (lightning links), a strong accent colour, floating parts as a design choice. |
| Crystal Knight | Angel boss | A knight with a closed helm and a bold crest; glowing eyes only. |
| The Darkened | Today's design | Today's slim black head and glowing line, polished with the shared style: crisp angular blocks, a shard cloak, an aura effect. |

## 2. Personality, faces and body, per keeper
Every keeper has two faces:
- **Awake / chase:** shown whenever it is awake (guarding, chasing, attacking, after a catch).
- **Asleep.**

| Keeper | Personality | Awake / chase face | Asleep face | Body, pose, details | Idle fidget (idea) | Effects (particles) |
|---|---|---|---|---|---|---|
| Timber Golem (Forest) | Grumpy old tree that hates being woken: a heavy, silent glare from two glowing slits; a bird lives in its crown. | Not human. Two glowing amber-green slits in dark bark hollows under a heavy mossy bark ledge, and a jagged dark crack. | The slits go dark and the crack thins, so the disguised tree shows no face. | Hewn bark trunk with grooves, glowing sap cracks, moss mantle, an angular leaf crown with leaf shards, a bird's nest with a blue bird, red mushrooms. **The left arm is a huge club log with a sprouting branch; the right arm is smaller.** Root-claw feet. Still sleeps disguised as a tree. | Scratches its bark with the small arm; the bird hops and chirps; leaves drift down. | Falling leaves, spores, sap drips, dust on the hammer slam. |
| Jungle King (Jungle) | Cocky, furious king: roars in your face, flashes a gold fang, crown tilted, chest out, loves an audience. | **The benchmark.** Red glowing angry eyes in dark sockets, heavy dark brows, a roaring mouth with fangs, lower fangs, a red inside and one gold fang. | Closed eyes on cream lids, relaxed brows, mouth hanging open snoring, drool. | Navy fur, spiky shoulder tufts, cream mask and jagged chest, tilted gold crown with a red gem, gold arm band, chin up, chunky knuckle-walking arms. | Beats his chest twice and adjusts his crown. | Chest-beat shockwave, dust, leaves, red eye glow. |
| Sand Snake (Desert) | Sly, venomous trickster: narrowed slit eyes, a hiss and two long fangs; strikes before you see it move. | Narrowed yellow slit-pupil eyes under scaled brow ridges, a hissing mouth with two long fangs, the forked tongue. | Closed eyes, relaxed brows, a closed mouth. | Deep ochre faceted body with dark diamond saddles, a hood with two big eye-spot markings, horns, spines along the back. | Flicks its tongue, sways its head, rattles the tail. | Sand swirl, dust trail. The rattle still buzzes. |
| Ice Fang (Snow) | Proud, cold hunter: chin up, icy glare, bares its sabres the moment it sees you. | Icy cyan slit-pupil eyes in dark sockets, heavy blue brows, a snarl between the sabres. | Closed eyes, relaxed brows, a closed mouth. | Chin up, ice horns, bold deep-blue swirls and stripes, spiky ruff, steel armour with sapphires built in, crystal tail, long ice claws. | Licks a paw, then lifts its head and flicks the crystal tail. | Frost aura, snowflake sparkles, icy breath on the roar. |
| Lava Dragon (Lava) | Hot-headed and furious: glares, snarls fire, snorts smoke even in its sleep. | Furious yellow slit-pupil eyes under black brow plates, a snarl with fangs and a fire-orange inside. | Closed eyes, still-grumpy brows, a closed mouth, smoke puffs. | Charcoal hewn plates, glowing flaming back spikes, lava seams and cheek cracks, bone horns, flaming tail tip, long claws. | Snorts two smoke puffs, stomps, the back flames flare. | Flames on spikes and tail, embers, nostril smoke. |
| Crystal Knight (Crystal) | Stern, merciless sentinel: stands to attention, sword ready, two burning slits in a closed helm. | **Eyes only.** Two fierce glowing slants in the visor slit. | Two dim flat lines. | **Closed helmet, no face.** Steel-violet bevelled armour, tall crystal crest and plume, gold brow band, nose guard, breathing holes, tabard with a gold emblem, crystal pauldrons, crystal blade. | Straightens up, taps the hilt, turns the helm left and right like a guard on patrol. | Crystal sparkles, a sword slash trail, shards on impact. |
| Storm Colossus (Storm) | A walking storm of rock: no face, only two burning slits and a crackling jaw; fists float on storm power. | Not human. Two glowing cyan slits in dark hollows under a rock ledge, and a glowing jagged crack across the jaw. | The slits and the crack go dark. | Dark storm rock, rock tusks, storm-cloud mane, copper lightning-rod horns, glowing lightning cracks, storm shards in the hips. **Floating shoulder rocks, fists and crystal storm cores (by design), linked by lightning.** | Punches its floating fists together (sparks), cracks its neck. | Lightning arcs between the body and the floating parts, sparks, a rain cloud. |
| The Darkened (Void event) | Silent and wrong: today's faceless black head and its one glowing line; it never speaks, it tilts its head and stares. | **Today's head.** The one line glows bright void purple and pulses. | The line dims to a thin dark glow. | **Today's design, polished.** The same slim black head, proportions and part positions, with: crisp bevelled blocks for today's plain blocks; angular cores for today's ball joints; metal ribs; a glowing chest slit; angular pauldrons with shards; a tattered cloak; long claws; knee and toe spikes; subtle purple markings on the head. | A slow head tilt; the line flickers; long claws drum the air. | Void wisps from the cloak hem, hands and feet; the line pulses and leaves a faint trail while chasing. |

## 3. How the two faces would work in Roblox
**Route: two face parts per keeper, swapped by hiding one of them.** This is the same cheap swap as rev 2, but with two
states instead of five.
- **The parts:** each keeper's Head group has the parts of the awake face (`Head_Face_Chase`, plus `Head_Eyes_Chase`
  for its glowing eyes) and the parts of the asleep face (`Head_Face_Asleep`, and `Head_Eyes_Asleep` where the asleep
  eyes still glow dimly).
  - The Knight's and The Darkened's faces are glow parts only.
  - The Colossus's glowing slits and crack are in `Head_Eyes_Chase`.
- **The rule:** asleep shows the asleep parts; any other state shows the awake parts. The client sets
  `LocalTransparencyModifier` to 0 on one set and 1 on the other. The game already uses this trick for the golem's
  eyes.
- **Why this route:**
  - It is instant and robust: no network traffic, no texture download, no pop-in.
  - It is one yes / no test (asleep or not) instead of a table of five states.
  - The faces are flat graphic shapes laid onto the head (not carved), so they stay sharp on a curved head.
  - Decals would need images uploaded per keeper, which lie flat on curved heads and can show blank for a moment on
    first use.
- **The cost:** one hidden face set per keeper, kept in memory: 16 to 1,068 triangles. Roblox does not draw it.

Two small code changes would be needed: the face switch where the client knows the keeper is asleep (`BeastAnimation`),
and a one-line skip in `KeeperContact` so face parts never count for hits.

**Sleeping "Z":** make today's three small "z" labels into one big stylised cyan "Z" with a dark outline, like the
references. This only changes the existing sleep labels, with no new asset. The Golem keeps no "Z", because it sleeps
disguised as a tree. In the previews the "Z" is a stand-in mesh that is turned to face the camera before each render,
as a BillboardGui does in game.

**Stud texture (option):** the previews show it on. In Roblox it would be a stud normal map, either as a
MaterialVariant or a SurfaceAppearance (1 tile = 1 stud). This needs a Studio test: on a MeshPart a texture follows the
mesh's UVs, and today's UVs point at the colour palette, so the FBX may need a second UV layout. You can also leave the
studs off.

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
| Storm Colossus | 1 + 6 by design | 1 + 6 by design | 1 + 6 by design | 1 + 5 by design | 1 + 6 by design | 1 + 6 by design | 0 failures. By design: 2 shoulder rocks, 2 fists, 2 crystal storm cores. In the wind-up the right shoulder rock touches the body. |
| The Darkened | 1 | 1 | 1 | 1 | 1 | 1 | 0 |

(The numbers are connected pieces. "1" means everything touches.)

How the pieces stay joined:
- **Snake wind-up.** The game's coil lifts the head about 2.4 studs off the body. The neck has a root that runs down
  into the first body segment. At rest it is hidden inside the body and under the floor; in the coil it spans the gap.
- **Joints, hidden.** Each moving group has a core at its pivot, which stays in place however the group turns, and the
  parent overlaps it. Rev 3 makes these cores small hewn blocks in the limb's own colour, kept inside the masses. The
  Darkened's cores sit where today's ball joints are, at their size or smaller.
- **Chunky shapes only grow.** The hewn planes push every point outward, never inward, so every contact the rounder rev 2
  shapes had is kept.
- **Faces.** Every face shape is laid onto the head's surface and goes into it, so it always touches the head.
- **Small details.** Nostrils, teeth, horn bases, hood marks and ribs are sunk into the body. Painted bands are always
  sunk into the surface.
- **The Darkened's feet.** When its knees fold asleep, foot and shin would part. A cosmetic ankle core keeps them joined,
  and its hit boxes stay as they are today.
- **Accents.** The Knight's orbiting shards and the Colossus's floating cloud are retired: the crest and the cloud mane
  replace them. The Snake's rattle is checked too and touches the tail.

## 5. What stays the same
- Speed, strike distance and timing, and the catch rule.
- Fling and ragdoll, sounds and voices.
- Sleep and wake, and the golem's tree disguise.
- Group names and pivots, so the existing animation code is unchanged.
- The Darkened's look: its head, line, proportions and part positions are today's, and its body parts stay inside
  today's hit boxes.
- Sizes:
  - Each group's new box is within about 1 stud of today's.
  - The exceptions are crowns, crests, horns, back and shoulder spikes and the Colossus mantle, which reach up to about
    4 studs further.
  - Every group's overshoot is listed in `fbx/keeper_<name>.json`.
- Heights in the lineup (studs, today to proposed):
  - Golem 25.5 to 26.9;
  - Jungle King 15.6 to 17.4 (crown);
  - Snake 8.1 to 10.8 (raised head and horns);
  - Ice Fang 10.9 to 11.0;
  - Dragon 18.8 to 19.7;
  - Knight 34.0 to 34.0;
  - Colossus 41.2 to 35.9 (today's floating cloud is retired);
  - The Darkened 18.5 to 18.5 (rev 2's hood is gone; the head is today's).

## 6. Phone cost
| Keeper | Triangles on screen (lite build) | With both faces in memory | Mesh parts (today) |
|---|---|---|---|
| Timber Golem | 6,794 (6,304) | 7,020 | 15 (63 blocks + 3) |
| Jungle King | 5,100 (4,828) | 6,168 | 10 (23) |
| Sand Snake | 4,912 (4,416) | 5,836 | 14 (17 + 3) |
| Ice Fang | 6,022 (5,828) | 6,898 | 11 (21 + 41) |
| Lava Dragon | 5,628 (5,400) | 6,504 | 20 (27) |
| Crystal Knight | 2,660 (2,462) | 2,684 | 13 (50 + 3) |
| Storm Colossus | 2,730 (2,650) | 2,956 | 16 (30 + 5) |
| The Darkened | 3,172 (3,172) | 3,188 | 25 (43) |

- **Target:** under 10,000 triangles on screen per keeper. All eight meet it, and rev 3 is lighter than rev 2 (which
  was 3,506 to 9,028).
- The largest single mesh is about 1,750 triangles; Roblox allows 20,000.
- One 256 x 256 palette texture per keeper.
- **Parts:** fewer than today for every keeper. Rev 2 had 13 to 31 parts; rev 3 has 10 to 25.
- **The lite build:** it now saves little (0 to 10 %), because the chunky shapes already use few segments.
- Not measured on a device.

## 7. How it would be implemented (after your OK)
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
- **A.** This style (chunky, angular, studs, bold markings) as shown, or the same models without the stud texture.
- **B. Which keepers first:**
  - Option 1: the Jungle King and the Lava Dragon. They are closest to your references.
  - Option 2: biome order, starting with Forest.
- **C. Tiger armour:** built into the mesh, or kept as separate parts.
- **D. The Colossus cloud:** a floating cloud above the head (by design), or the attached cloud mane shown.
- **E. The Darkened:** the polished version shown, or leave it exactly as it is today.

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
  - `faces.py`: the two graphic faces.
  - `kit.py`: shapes (hewn blocks, chamfered blocks), studs, the "Z", the connectivity graph and the render helpers.
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
  difference against the manifests was under 0.0001 studs. The largest FBX is 302 KB, under the 5 MB limit.
- The connectivity check (table above) ran on the final models, in the rest pose and every rendered pose.
- The triangle counts (`tricount.py`) were taken for the full and lite builds.
- The poses come from the game's own Luau modules (`BeastPose`, `KeeperSignatureStrike`, `VeiledKeeper81` and
  `KeeperAccents`), run on the repo's offline Roblox mock.

**Reasoned, not run:**
- Matching the screenshots' style, and how "less bubbly" and "menacing" read.
- Studio import, the stud texture tiling and vertex colours.
- The cost on phones.
