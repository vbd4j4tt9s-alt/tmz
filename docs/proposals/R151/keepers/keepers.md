# Keepers: improved 3D models, revision 5 (proposal, previews only)

**Status:** waiting for your OK. Nothing in the game's code (`src/`) has changed.

Revision 5 follows your feedback on revision 4:
- **Timber Golem and Storm Colossus: today's designs, improved** (as with the snake and the gorilla).
  - Every one of today's native parts is rebuilt at its exact size, position and colour as a crisp bevelled block or
    wedge, so the silhouette and identity stay.
  - On top: a clean glowing-slit creature face (awake and asleep), a few tasteful details (moss, bark grooves, a bird's
    nest; storm-glow veins), and the studs.
  - The Colossus keeps today's floating pieces, including its floating cloud crown.
- **Ice Fang: improved.**
  - A cleaner fox head, held up on a neck.
  - Better body proportions: a deep chest, a slim waist and round haunches.
  - Blue-grey socks, and a huge bushy tail with a white tip and ice crystals.
- **Lava Dragon: a longer body.**
  - The torso is now 14.4 studs long (it was 10.6), to fit the long neck, tail and big wings, as in the "Ice and Fire"
    proportions.
  - The tail moves back with it; everything else stays.
- **Crystal Knight: a real knight's longsword, not a dagger.**
  - A long, straight, double-edged blade of 15 studs, longer than his leg, with a short point.
  - A wide gold crossguard with down-turned crystal quillons, a wrapped grip and a gold pommel with a crystal.
  - A glowing crystal fuller. His bulk stays as in rev 4.
- **Frozen:** the Sand Snake and the Jungle King (your OK on rev 4), and The Darkened. Their code is byte-for-byte the
  same as rev 4; they are only re-rendered.
- **Still in place:** the two faces, the one-piece check, the game's real pose frames, unchanged group names and pivots,
  the big sleep "Z", the effects, the FBX export and the budgets.

## Look at these first
1. `keepers_faces.png`: one row of all 8 keepers, each with its awake / chase face above its asleep face.
2. `keepers_before_after.png`: every keeper today (left) and proposed (right), same camera and scale, with a 5-stud
   player. For the Golem and the Colossus the two sides now share the same parts; compare the finish, faces and details.
3. `keepers_lineup.png`: all keepers in a row next to 5-stud players, today on top and proposed below, with a ruler in
   studs.
4. One sheet per keeper:
   - 8 views: front, three-quarter, side, back, chase, wind-up, impact and asleep;
   - both faces, with notes beside them;
   - files `keeper_timber_golem.png`, `keeper_jungle_king.png`, `keeper_sand_snake.png`, `keeper_ice_fang.png`,
     `keeper_lava_dragon.png`, `keeper_crystal_knight.png`, `keeper_storm_colossus.png` and `keeper_the_darkened.png`.

These are real Blender models rendered in Cycles. The chase, attack and asleep views use the game's own pose frames for
that keeper, so they also show that today's animation code moves the new models without changes.

## 1. References
No reference image is added to the repo. What each one contributed:
- **Ice and Fire fire dragon** (two images, rev 4): the fanned finger-strut wings with stepped membranes, the crown of
  swept horns and frills, the long stepped neck, the bone spike row to the tail tip, the toe blocks, and now the longer
  body. It is our own model in that style, from the two images and my memory of the mod (its pages are blocked here).
  More screenshots (side, front, top) would let me match it more closely.
- **Bulky knight** (rev 4): the stacked pauldrons, ribbed arms, great helm with crest and plume, layered chest, heavy
  belt and thick legs; crystal medallions replace its skulls.
- **Gorilla and snake** (in-game screenshots, rev 4): kept as you approved them.
- **Golem and Colossus:** today's in-game designs, read from their exact parts in `KeeperUpgradeData` and today's
  `KeeperAccents`:
  - the golem's chest rune and orange mushrooms;
  - the colossus's floating cloud crown.

## 2. Each keeper: personality, faces and body
Every keeper has two faces:
- **Awake / chase:** shown whenever it is awake (guarding, chasing, attacking, after a catch).
- **Asleep.**

| Keeper | Personality | Awake / chase face | Asleep face | Body, pose, details | Effects (particles) |
|---|---|---|---|---|---|
| Timber Golem (Forest) | Grumpy old tree that hates being woken: a heavy, silent glare from under its leafy hood; a bird nests on top. | Today's hollow face, now clean: two glowing green slits and a glowing jagged crack, under today's heavy brows (now angled into a scowl). | The slits dim to thin lines and the crack goes out. Asleep it still turns into a tree with the face hidden, as today. | **Today's golem, improved.** All of today's parts as crisp bevelled blocks and wedges, in today's colours: the brown trunk with its split-bark beard, the moss shoulders, the big green stepped leaf hood with its slopes, the stump head with broken-crown wedges and crown branches, the block arms with dark root knuckles, leafy shoulder tiers and boughs, and the wide root legs with wedge feet and toes. New on top: today's green chest rune as a glowing rune in a dark knothole, today's orange mushrooms, moss drips and tufts, bark grooves and bands, a few bright leaf cubes, and a little bird's nest with a blue bird on the hood. | Falling leaves, spores, the rune pulses, dust on the hammer slam. |
| Jungle King (Jungle) | *Frozen (rev 4).* | | | | |
| Sand Snake (Desert) | *Frozen (rev 4).* | | | | |
| Ice Fang (Snow) | Proud, cold snow fox: head high, sly icy glare, bares its sabres when it sees you. | Almond icy-cyan eyes with slit pupils and dark eyeliner flicks, slanted blue lid lines, and small teeth under the snout. | Closed eyes; the flicks stay. | **Improved.** The head is held up on a neck and is cleaner: a compact cranium, a tapered pointed white snout, big triangular ears with blue inner ears and blue tips, white cheek ruffs, a small blue forehead diamond and a sapphire, and two sabre fangs (the rev 4 bridge stripe and cheek bars are gone). The body is fox-shaped: a deep chest with a white ruff, a slim waist, round haunches, a few bold blue bands, the silver-and-sapphire collar, saddle and shoulder plates, blue-grey socks, big paws with ice claws, and a huge bushy tail with a white tip and ice crystals. | Frost aura, snowflakes, icy breath on the snarl. |
| Lava Dragon (Lava) | Hot-headed and furious: glares, snarls fire, snorts smoke even in its sleep. | As rev 4. | As rev 4. | **A longer body.** The torso now runs 14.4 studs (was 10.6): the chest reaches further forward and the hips further back over the tail root, so the long neck, long tail and big wings sit in proportion. It has one more scale band, more belly plates and a longer row of back spikes (12, with 6 flaming). The tail moves back with the body (a hidden tail root spans the gap). Everything else as rev 4. | As rev 4. |
| Crystal Knight (Crystal) | Stern, merciless sentinel: plants his feet, longsword ready. | As rev 4. | As rev 4. | **A real knight's longsword.** A straight, double-edged blade 15 studs long (his leg is about 12.7) with bright edges and a glowing crystal fuller, ending in a short point instead of the rev 4 dagger taper. A wide gold crossguard with down-turned quillons tipped with crystals, a blade collar, a wrapped grip and a gold pommel with a crystal. His bulk is as in rev 4. | Crystal sparkles, a sword slash trail, shards on impact. |
| Storm Colossus (Storm) | A walking storm of slate: no face, only two burning slits and a crackling jaw; fists, shoulders and legs hang on storm power under its own thundercloud. | Two glowing slits and a glowing jagged crack on a dark visor (today's face shadow), under a rock brow. | The slits dim, the crack goes dark. | **Today's colossus, improved.** All of today's parts as crisp bevelled blocks and wedges, in today's colours: the dark slate core with the chest mantle and the glowing lightning bolt; the tilted shoulder rocks with V-shaped thunder prongs; the heavy fists with glowing bands; the glowing charged joints; the suspended shins with charged knees and wedge feet. Today's storm-cloud crown floats over the head as chunky cloud blocks. Improved: today's sloping wedge head is now a clean block head with the slope kept as a crest, a rock brow, cheek plates and a heavy chin. New: storm-glow veins off the bolt, charged hip cores over the knees, knuckle and toe blocks. | Lightning arcs linking the floating pieces, sparks, flashes in the cloud crown, rain. |
| The Darkened (Void event) | *Unchanged (rev 3).* | | | | |

## 3. How the two faces work
**The faces themselves:**
- Every face is a set of flat plates on a flat face plane: the front of the head or muzzle, the snake's head sides, the
  golem's hollow face and the colossus's visor.
- Each plate has an even thickness and is sunk into the head, so it always touches the head.
- The eyes are one outline drawn once and mirrored, so both eyes have the same size and shape and sit symmetrically.

**In Roblox: two face parts per keeper, swapped by hiding one of them.**
- **The parts:** each keeper's Head group has the parts of the awake face (`Head_Face_Chase`, plus `Head_Eyes_Chase`
  for its glowing eyes) and of the asleep face (`Head_Face_Asleep`, and `Head_Eyes_Asleep` where the asleep eyes still
  glow dimly).
  - The Knight's and The Darkened's faces are glow parts only.
  - The Golem's and the Colossus's glowing slits and crack are in `Head_Eyes_Chase`.
- **The rule:** asleep shows the asleep parts; any other state shows the awake parts. The client sets
  `LocalTransparencyModifier` to 0 on one set and 1 on the other. The game already uses this trick for the golem's
  eyes.
- **The cost:** one hidden face set per keeper, kept in memory: 16 to 152 triangles. Roblox does not draw it.

Two small code changes would be needed:
- the face switch where the client knows the keeper is asleep (`BeastAnimation`);
- a one-line skip in `KeeperContact`, so face parts and the knight's cosmetic sword point never count for hits.

**Sleeping "Z":** today's three small "z" labels become one big stylised cyan "Z" with a dark outline. The Golem keeps
no "Z", because it sleeps disguised as a tree.

**Stud texture (option):**
- The previews show it on. In Roblox it would be a stud normal map, either as a MaterialVariant or a SurfaceAppearance
  (1 tile = 1 stud).
- On a MeshPart a texture follows the mesh's UVs, so the FBX may need a second UV layout. A Studio test will tell.

## 4. No floating pieces (checked by script)
`blender/connectivity.py` builds each keeper and finds every separate piece of mesh. It counts two pieces as joined if
they touch, overlap, come within 0.02 studs, or one sits inside the other. Each keeper must be **one connected piece**,
except the Storm Colossus's floating pieces, which are part of its design. The check runs:
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
| Storm Colossus | 1 + 5 by design | 1 + 5 by design | 1 + 5 by design | 1 + 2 by design | 1 + 1 by design | 1 + 5 by design | 0 failures (see below). |
| The Darkened | 1 | 1 | 1 | 1 | 1 | 1 | 0 |

(The numbers are connected pieces. "1" means everything touches.)

**The Colossus's by-design pieces:**
- What floats is what floats today: the two suspended legs, the two charged knees above them, and the cloud crown.
- In the wind-up and the impact, some of these swing into the body.
- Today's shoulder rocks, charged joints and fists touch one another and the body, as in today's parts, so they count
  as one piece with it.

How the pieces stay joined:
- **Joints.** Each moving group has a core cube centred on its pivot, which stays in place however the group turns,
  and the parent overlaps it. The knight's body has a hip block around both leg pivots.
- **The golem's tree disguise.** Each golem piece groups today's parts that make the same move into the tree pose, so
  the tree is today's tree. The check confirms it is one piece.
- **The dragon's longer body.** The tail root runs from the tail's pivot (inside the hips) to the first tail block, so
  the tail stays joined at any swing. The wings are as rev 4.
- **The knight's sword.** The grip sits in the gauntlet; the blade, guard and pommel are one block chain.
- **Faces.** Every face plate is sunk into the head, and each plate on top of another is sunk through it.

## 5. What "today" shows
- **Exact parts:** the Golem, Knight, Colossus and The Darkened are drawn from their native parts in the game's source.
- **From your screenshots:** the Jungle King and the Sand Snake.
  - The shapes are the hull of the game's sample points plus the exact config details.
  - The colours come from your screenshots.
- **Stand-ins:** Ice Fang and the Lava Dragon are still stand-ins (hull and assumed colour).

## 6. What stays the same
- **Gameplay:** speed, strike distance and timing, and the catch rule.
  - **The knight's sword reach for hits is unchanged.** His blade is split: the `Sword` part reaches exactly as far as
    today's sword, and the extra length is a separate `Sword_Point` part.
  - `Sword_Point` is flagged cosmetic in the manifest, and `KeeperContact` would skip it, like the face parts.
- Fling and ragdoll, sounds and voices.
- Sleep and wake, and the golem's tree disguise.
- Group names and pivots, so the existing animation code is unchanged.
- The Darkened, the Jungle King and the Sand Snake, entirely.
- **Sizes:**
  - Groups stay close to today's boxes.
  - The golem and the colossus are today's parts, so their sizes are today's, apart from the small additions.
  - The longer dragon body and tail, the knight's longsword, Ice Fang's ears and tail, crowns, crests and spikes reach
    further.
  - Every group's overshoot is listed in `fbx/keeper_<name>.json`.
- **Heights in the lineup** (studs, today to proposed):
  - Golem 25.5 to 27.8 (the bird on the hood);
  - Jungle King 15.6 to 17.3;
  - Snake 8.1 to 9.6;
  - Ice Fang 10.9 to 13.3 (head held up, ears);
  - Dragon 18.8 to 19.0;
  - Knight 34.0 to 35.0;
  - Colossus 41.2 to 40.6 (today's cloud crown kept);
  - The Darkened 18.5 to 18.5 (unchanged).
- **Asleep, the longsword's point goes into the floor.** Today's sleep pose holds the sword point-down, with the tip
  just touching the ground (+0.07 studs). The longer blade goes about 6 studs further, so it looks planted in the
  ground like a knight resting on his sword; it is cosmetic, so it does not affect catches. If you prefer it not to
  clip, there are two options:
  - tilt the sword forward about 50 degrees in the sleep pose (one value in the pose code);
  - shorten the blade.

## 7. Phone cost
| Keeper | Triangles on screen | With both faces in memory | Mesh parts (today) |
|---|---|---|---|
| Timber Golem | 5,088 | 5,112 | 14 (63 blocks + 3) |
| Jungle King | 3,836 | 3,988 | 10 (23) |
| Sand Snake | 5,384 | 5,480 | 14 (17 + 3) |
| Ice Fang | 4,952 | 5,048 | 11 (21 + 41) |
| Lava Dragon | 9,688 | 9,784 | 20 (27) |
| Crystal Knight | 6,832 | 6,856 | 15 (50 + 3) |
| Storm Colossus | 3,044 | 3,068 | 16 (30 + 5) |
| The Darkened | 3,172 | 3,188 | 25 (43) |

- **Target:** under 10,000 triangles on screen per keeper. All eight meet it; the dragon, with its two big fanned wings
  and now a longer body, is the heaviest.
- The largest single mesh is a dragon wing at 2,124 triangles; Roblox allows 20,000.
- One 256 x 256 palette texture per keeper.
- **Parts:** fewer than today for every keeper.
- Not measured on a device.

## 8. How it would be implemented (after your OK)
**What you would do:**
1. In Studio, import each `fbx/keeper_<name>.fbx` with the 3D Importer. Check the part sizes against
   `fbx/keeper_<name>.json` (1 unit = 1 stud, facing -Z), then upload.
2. Put the eight models in ServerStorage (I will give the folder name), save, and send me the place.

**What I would do in the next release:**
1. Fill `KeeperRigConfig` from the manifests: parts, groups, centres, sizes, eye, glow, face and cosmetic flags, and
   new floor samples. Pivots stay unchanged.
2. Make `BeastModels` use the new models for all seven stages, and bump the visual version.
3. Add the two-face switch (asleep or awake) to `BeastAnimation`. Make `KeeperContact` skip face parts and the
   knight's cosmetic sword point.
4. Golem: give each piece its tree pose. This is today's tree, worked out from today's parts.
5. Retire the accents that are now in the meshes:
   - the golem's rune and mushrooms;
   - the tiger's spines and armour;
   - the knight's shards;
   - the colossus's cloud (now a floating mesh piece of its head).

   Keep the snake's rattle.
6. Dragon: the wings are exported at in-game size, so remove the old x1.35 wing stretch.
7. The Darkened: swap its blocks for the polished parts, using the same groups, offsets and sizes.
8. Restyle the sleep "Z" and add the particle effects listed above.
9. Run the keeper test suites. Then you check it in Studio.

## 9. Risks
- **The Ice and Fire dragon is from your two images and my memory of the mod.** I could not open the mod's pages
  here.
- **Today's images are partly stand-ins.** Ice Fang and the dragon are drawn from the game's sample points in an
  assumed colour.
- **Body-touch catches follow the new shapes.** Distance catches are unchanged, and the knight's extra blade is
  cosmetic.
- **Untested in Studio:** the FBX import (it round-trips in Blender), vertex colours, how the stud texture tiles on a
  MeshPart, and how bright Neon looks.
- **One install.** The game only animates a keeper whose part count matches the config, so the models and the config
  must go in together.

## 10. Choices for you
- **A.** Studs on, as shown, or the same models without the stud texture.
- **B. Which keepers first:**
  - Option 1: the Jungle King and the Sand Snake (approved).
  - Option 2: biome order, starting with Forest.
- **C. The dragon:** as shown, or send more "Ice and Fire" screenshots to match it more closely.
- **D. The knight asleep:** the sword point planted in the ground, as shown, or the sword tilted forward in the sleep
  pose.

## Files
- **Previews:** `keepers_faces.png`, `keepers_before_after.png`, `keepers_lineup.png` and `keeper_<name>.png`.
- **In `fbx/`:**
  - `keeper_<name>.fbx`: one mesh per part, placed on the rig, including both faces, with the palette texture
    embedded. Effects are not included.
  - `keeper_<name>_atlas.png`: the palette texture.
  - `keeper_<name>.json`:
    - for each part: its name, group, centre, size, triangles, eye, glow, face and cosmetic flags, and the golem's
      tree mapping;
    - for each group: its bounds against today's, and its floor samples.
- **In `blender/`:**
  - `proposed.py`: the eight models. The Golem and the Colossus read today's parts from `KeeperUpgradeData`.
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
- The FBX files were exported and re-imported (`check_fbx.py`). Every part came back, and the worst centre or size difference against the manifests was at
  most 0.0001 studs. The largest FBX is 267 KB, under the 5 MB limit.
- The connectivity check (table above) ran on the final models, in the rest pose and every rendered pose.
- The triangle counts were taken with `tricount.py`.
- The knight's lowest sword point was measured in every pose, today's sword against the new one.
- The poses come from the game's own Luau modules (`BeastPose`, `KeeperSignatureStrike`, `VeiledKeeper81` and
  `KeeperAccents`), run on the repo's offline Roblox mock.
- The frozen sections (Jungle King, Sand Snake, The Darkened) were checked to be byte-identical to rev 4.

**Reasoned, not run:**
- How "improved but the same identity", "cleaner fox" and "proper longsword" read.
- The "Ice and Fire" look beyond your two images.
- Studio import, the stud texture tiling and vertex colours.
- The cost on phones.
