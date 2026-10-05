# R152: the new keeper models are in the game

You approved the rev 6 designs (`docs/proposals/R151/keepers/`) and chose "Do it all here, game builds the keeper models itself".
So there is no import and no upload. The game carries the models as data and builds them itself when a server starts.

## What's in
- **All 8 keepers use the approved models.** That is the 7 biome keepers plus The Darkened, exactly as in rev 6. The Jungle King,
  Sand Snake and The Darkened are the frozen designs. The Storm Colossus keeps its floating cloud crown.
- **How it works:**
  - The models live in 8 small data scripts (79 KB in total).
  - When a server starts, it builds each part once with Roblox's mesh tools (the same way your baked melons and pumpkins are
    built), then puts the finished models in ServerStorage.
  - Every keeper is copied from those models. Players' devices only receive the keepers, never the data.
- **Two faces.** A sleeping keeper shows its asleep face. Awake, chasing or attacking, it shows its awake face. The golem still
  sleeps as a tree with its face hidden inside, and its rune and glowing slits go dark.
- **No change to gameplay:** same speed, strike distance and timing, catch rule, fling and ragdoll, sounds, voices, and sleep / wake.
  - The knight's long sword point and the face pieces never count for hits.
  - Body-touch catches follow the new shapes.
  - Each keeper now stands with its new feet on the ground. Before, the Ice Fang and the Lava Dragon floated a little and the
    Colossus sank 0.8 studs into the ground.
- **Retired extras, now part of the models:** the golem's rune and mushrooms, the snow keeper's spines and armour, the knight's
  orbiting shards and the colossus's separate cloud. The snake keeps its rattle. The dragon's old wing stretch is gone: its wings
  are already the right size.
- **New sleep "Z":** one big cyan Z with a dark outline (and a small z), as in the sheets. The golem has none, because it is a tree.
- **Effects.** The keepers' existing effects (dust, breath, sparks, the colossus's lightning) stay. Breath and lightning now come
  from the new mouths and the new chest. The glowing runes, lava seams and storm cracks pulse gently. No other new particles yet.
- **No studs.** The game has no stud texture that works on these parts, so they ship smooth, with the sheets' colours.

| Keeper | Mesh parts (today) | Triangles (on screen) |
|---|---|---|
| Timber Golem | 14 (63 blocks + 3) | 5,112 (5,088) |
| Jungle King | 10 (23) | 3,988 (3,836) |
| Sand Snake | 14 (17 + 3) | 5,480 (5,384) |
| Ice Fang | 11 (21 + 41) | 5,048 (4,952) |
| Lava Dragon | 20 (27) | 9,784 (9,688) |
| Crystal Knight | 15 (50 + 3) | 6,856 (6,832) |
| Storm Colossus | 18 (30 + 5) | 8,048 (7,976) |
| The Darkened | 25 (43) | 3,188 (3,172) |

`keepers_roundtrip.png` shows each approved sheet view beside the same view built from the game's data.

## How to check it in Studio
1. Turn on **Game Settings > Security > "Allow Mesh / Image APIs"**. Your melons and pack shapes already need it.
2. Start a Play session (or a live server).
   - For the first few seconds the keepers look like today's.
   - Each one switches to its new model as soon as it is asleep at its camp, which is a few seconds after the server starts.
3. Type **`/test keepermodels`** to see:
   - whether all 8 are built, and how long it took;
   - which model each keeper shows now;
   - if something failed, why.
4. **`/test keepermodels off`** puts today's keepers back, to compare (each as soon as it is idle). **`/test keepermodels auto`** goes
   back to the new ones. Nothing is saved: a new server is always on the new models.
5. Look at a sleeping keeper (asleep face, the big Z), wake one (awake face) and get hit by one.
   - Check that the golem turns into its tree and back.
   - Check how bright the Neon eyes and cracks look.

## What happens if it is off or fails
- **If "Allow Mesh / Image APIs" is off,** every keeper stays exactly as it is today. The game logs one warning, and
  `/test keepermodels` tells you to turn the setting on.
- **If one keeper fails to build** (for example, the server runs out of mesh memory), only that keeper stays as today's. The others
  still switch.
- **A keeper never switches mid-chase.** It waits until it is back asleep at its camp.
- The Darkened switches at its next spawn.

## Risks
- **Not run in Studio yet.** Everything was checked on the offline Roblox stand-in (1,500+ checks), against the approved
  manifests and with a Blender render of the decoded data. Still untested in real Roblox:
  - the colours on the parts;
  - the build time on a live server (expected a few seconds);
  - how bright the Neon looks.
- **Hits follow the new shapes.** Each body part's hit shape is its outline (a "hull"). The wide pieces (the dragon's wings, the
  colossus's boulders, Ice Fang's wider body) can touch a player a little sooner than today's. Distance catches are unchanged.
- **The first seconds of a server** show today's keepers, then each switches once while asleep. Players at a camp may see the
  switch.
- **The knight asleep:** his longer blade's point goes into the ground, as you saw in the sheets. The point never counts for hits.
