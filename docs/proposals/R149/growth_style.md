# R149 proposal: growth style (Grow a Garden as the reference)

Design only. Nothing under `src/`, `installers/` or `tools/` changes. Base: `b4376bf` (R149 weather head).

Owner: *"look to improve growth animations, look at grow a garden for reference"*, then: *"instead of seeing GaG style, look and propose
improvements in the growth style for GaG"*.

| Picture | What it shows |
|---|---|
| `growth_style.png` | Blueberry (bush), Apple (tree) and Watermelon (ground vine) at 8 moments, **today** row above **proposed** row. Below them is a colour strip for 6 fruits, showing each fruit's colour from 0 % to 100 % of its growth. |

How the picture was made:
- Both rows are built by the **real game modules of this checkout** (`PlantVisuals`, `PlantGrowth`, `PlantingEffects`), run on the Roblox mock.
- The "proposed" row draws the same parts with a scratch module, `preview/GrowthStyle149.luau`. That module is not in `src/`.
- The scenes are drawn with three.js. Rerun with `preview/run_growth_preview.sh`.
- Whole-plant frames use one fixed camera per plant, so the sizes compare honestly.
- Not drawn: motion (sway, bounce timing), Roblox lighting and textures. Particles are drawn as small parts.

## 0. Recommendation in one screen

- **Our growth already works the way Grow a Garden's does.** The plant grows continuously from saved timestamps. Fruit grows on the plant
  from its stalk. Every fruit rolls its own size. A fruit can only be picked when it is ripe.
- **The gaps are in feel, not in the system:**
  - the first minute looks empty;
  - leaves fade in like ghosts;
  - young fruit is the same green as the leaves, then turns a muddy brown on its way to red;
  - nothing happens at the two moments players care about, **ripe** and **harvest**;
  - a growing plant stands rigid. Once one fruit is picked, the plant stops swaying until every fruit has grown back.
- **There is also a big hidden cost.** Every growing plant near the camera has **all of its parts rewritten 20 times a second**, even when a
  4-hour plant has not visibly changed. Fixing that pays for everything else.
- **Phase 1 = items #1-#8 below**, in one release:
  - about 400 lines;
  - 3 existing files and 1 new client module;
  - most of the ripe / harvest code can be reused from the unfinished Sonnet WIP.
- **Lantern Fern and Amethyst Grape stay exactly as they look today.** Ash Tomato keeps its model; the general growth animation applies to it.

## 1. Today: what a player sees

Read from `PlantGrowth.lua`, `PlantVisuals.lua`, `GardenVisuals.client.lua`, `PlantingEffects.lua` and `PlantInspection.client.lua`. The
"today" frames in the picture show it.

| Moment | What the player sees | Snaps / pops |
|---|---|---|
| Plant a seed | The R112 dirt pile pops up with sounds, stands about 3 s and sinks. A small soil mark stays. | Fine. |
| 0-2.5 % | A brown seed ball, nothing else. | The seedling **pops in** at 2.5 %. |
| First 10 % | The plant is about **4 % of its full size** (1 % at 5 %, 20 % at 25 %). For a 20-min Ash Tomato that is 2 minutes of almost nothing. | The slow start makes early growth look stuck. |
| 12-80 % | Leaves, canopy and petals **fade in through transparency**, so the plant looks like a half see-through ghost (see the 25 % and 50 % frames). | Ghost look. Semi-transparent parts also cost more to draw on phones. |
| Fruit 0-94 % | A tiny green ball at the stalk. The fruit grows out of the stalk point, and its colour blends from **leaf green** (83,157,64) to the ripe colour over 30-94 %. | Young fruit is invisible against the leaves. On red and orange fruit the halfway colour is **olive-brown** (Apple, Strawberry, Ash Tomato and Ember Pumpkin strips in the picture). |
| Fruit 82 % | The fruit's real material switches on. | **23 of 47 plants** have Neon (or Wood / Sand) fruit parts, and those **snap** from plain to glowing at 82 %. |
| Ripe | The fruit just reaches 100 % and the harvest prompt becomes available. Legendary-and-up plants switch on their aura. | **Nothing marks the moment.** |
| Plant matures | The client rebuilds the detail model. It looks identical, and the plant starts swaying. | Invisible, except that the sway starts. |
| Harvest | The fruit **disappears in one frame**. The harvester hears a pop and sees a toast. Other players see it vanish silently. | Hard cut. |
| Regrow | A tiny green ball at the stalk; the fruit swells from there. Each regrowth rolls a new size, so it can come back smaller or bigger. | Same colour problems as above. |
| Sway | Only mature plants with **every** fruit ripe sway (at most 6 plants / 600 parts at once). Growing plants, and any plant with a regrowing fruit, are rigid. | In a garden being harvested, most plants never sway. |
| Growth pass bought | `GrowthBoostRules` shortens the remaining time. | Every growing plant **jumps** to its new size in one frame. |
| Timer | Tap or click a plant: the label shows "Sprouting / Growing / Budding / Almost ready · 1m 05s", or "READY", or "2 ready • Next 30s". | Text only, no bar. |
| Far away | The server silhouette grows in 32 steps. Streamed-out gardens refresh every 2 s. | Too far away to notice. Leave as is. |

**Cost today:**
- A growing plant within 75 studs is fully rewritten **20 times a second** (10 on low quality).
- Each rewrite sets size, position, transparency, colour, material, query and collide on **every** part.
- The 47 regular plants (not Mech / Verity) average **133 parts**: about **18,600 property writes a second per growing plant**. Ten plants growing on screen
  means about 186,000 a second. The Amethyst Grape alone (710 parts) is about 99,000 a second.
- Most of the roster grows for 15 minutes to 4 hours, so almost all of these writes change nothing visible.

## 2. What Grow a Garden does (sourced)

In this environment the network proxy blocked opening the pages themselves: the GaG Fandom / Miraheze wikis, Wikipedia, the Roblox DevForum
and the game guides. The sources below are the **search-engine results for those pages**: their titles, links and summaries. Treat the
wording as a summary, not a quote.

| # | GaG trait | Source (search result) | Us today |
|---|---|---|---|
| G1 | A crop goes from a small sprout, through maturing, to harvestable at 100 %. Crops keep growing while the player is offline. | GaG wiki "Mechanics" (growagarden.fandom.com/wiki/Mechanics); beebom.com "8 Beginner Tips and Tricks"; thegamer.com beginner tips | Same: continuous, timestamp-driven, grows offline. |
| G2 | Ripe fruit is collected by holding E (tap on mobile). | thegamer.com "How To Get Huge Crops"; beebom.com "Harvest Tool" guide | Same (hold-to-harvest prompt on ripe fruit only). |
| G3 | Multi-harvest crops keep bearing fruit after picking. Single-harvest crops are removed. | growagardencalculator.ca wiki "Crops"; beebom.com tips | Same (`Regrows`, `Mode='whole'`). |
| G4 | **Fruit size is visual and random**: bigger looks bigger, weighs more and sells for more. Sprinklers raise the odds of big fruit. | gamerant.com "How to Get Big Plants"; pcgamer.com "How to get bigger crops" | Same idea: each fruit rolls its own size, and rare rolls are 1.25-1.75x. **Nothing celebrates a big roll.** |
| G5 | Mutations are loud visuals: **Wet** = a dripping water-droplet animation; **Shocked** = neon glow plus light particles; **Frozen** = the fruit sits in a block of ice; **Gold / Rainbow** = recolour. | deltiasgaming.com mutations guide; pockettactics.com; sportskeeda.com | We have coats and weather effects. Out of scope here. |
| G6 | "Ripe" Sugar Apple: a rare **purple colour variant**, cosmetic only. | roonby.com "How to Get Ripe Sugar Apple" | Colour as a ripeness cue: see #6. |
| G7 | "Evo" plants (Seed Stages event): 4 stages, **each bigger and more detailed**. | GaG wiki "Seed Stages Event" | Not used. That would mean a separate model per stage (see Skip S4). |
| G8 | On PC, hovering a plant shows its growth and sprinkler time. One forum post says the growth-time readout was test-server only. | GaG wiki discussion "How can you see the duration of sprinklers and the growth time of plants?" | We show a tap / click label with a time (see #11). |
| G9 | Developers who rebuild GaG growth scale **part sizes from attachment points over a 0-1 growth value** instead of swapping models. The poster adds that the exact method "is impossible to know". | devforum.roblox.com "Plant Growing System Like Grow A Garden" | Same method (`PlantGrowth.Apply`). |

**Not from a source.** These come from general knowledge of GaG gameplay and were not verified here:
- In GaG a fruit appears small on the plant and enlarges until it is ripe.
- The collect prompt shows only on ripe fruit.
- The base game has **no special "it's ripe" effect**. The visual reward is size and mutation effects.

So the ripe bounce, the harvest pop and the sprout pop below are **our own ideas**, in the spirit of GaG's chunky, readable style. They do not
copy a GaG feature.

A search result describing an "Unripe / Ripened / Lush" stage system came from a different game's wiki (Garden Horizons). It is not used here.

## 3. Proposed improvements

Cost says "lines" for the code change, not counting tests. Every item is **client-only and cosmetic**:
- no change to saved crops, timing, readiness, prices, prompts or collision;
- no per-plant Heartbeat connections and no TweenService;
- everything runs inside the existing 20 Hz `GardenVisuals` animation step and the `PlantAnimationBatch`;
- the existing LOD / streaming planner and the `ClientFxBudget` tiers decide which plants animate. Phones run at tier 2.

### Must (phase 1)

**#1 Write only what moved (invisible; pays for the rest).**
- *What the player sees:* nothing changes on screen.
- *Why:* today every growing plant is rewritten in full 20 times a second (see §1).
  - Rewrite a plant only when its growth has moved by at least 1/600 of the way. That is about 0.17 % of its size, which is invisible.
  - Write colour, material and transparency only when they change.
  - Move positions through the existing batch (`BulkMoveTo`).
  - A 15-minute plant then updates every 1.5 s instead of 20 times a second, **30x fewer writes**. A 4-hour plant updates every 24 s. The 60-s
    Watermelon updates 10 times a second instead of 20.
- *Cost:* faster on phones. About 35 lines in `PlantGrowth` and `GardenVisuals`. (The WIP's `WriteSteps` idea.)
- *Risk:* medium. This is the central writer, which the server silhouette also uses. Check the `PlantAnimationMoves` / `PlantAnimationStepMs`
  Studio stats before and after.

**#2 Growing and regrowing plants sway.**
- *What the player sees:* every plant moves gently in the wind, not only fully ripe ones. Picking a fruit no longer freezes the plant.
- *Why:* a garden is mostly growing or regrowing plants, and today those are all rigid.
- *Cost:* it uses the **existing** sway budget: 6 plants / 600 parts near the camera, with no higher cap. These are the same batched moves
  that ripe plants already get.
  - The growth writer (#1) keeps each part's grown pose, and the sway rig just moves it. So a swaying growing plant costs one batched move per
    part per tick, not today's 7 property writes per part.
  - About 25 lines in `PlantGrowth`, `GardenVisuals` and `PlantAnimationBatch`.
- *Risk:* low to medium. The sway rig and the growth writer must not fight over the regrowing fruit's parts; the WIP already solved this with a
  skip list.

**#3 Sprout pop, timed to the dirt pile.**
- *What the player sees:* the seed sits under the R112 dirt pile. As the pile sinks (about 3 s after planting), a seedling springs up and opens its
  two seed leaves (frame "4 s after planting"). It then hands over smoothly to the real plant at 7-17 %.
- *Why:* planting is the first moment of the loop. Today the seedling pops in late and tiny (0.1 stud).
- *Cost:* the 3 seedling parts already exist. It is driven by the saved planting time, so every client agrees and late joiners just see the
  settled seedling. About 20 lines in `PlantGrowth`.
- *Risk:* low.

**#4 Fast-start growth curve.**
- *What the player sees:* the plant is clearly visible early on.

  | Growth time | 5 % | 10 % | 25 % | 50 % | 75 % |
  |---|---|---|---|---|---|
  | Today (size) | 1 % | 4 % | 20 % | 56 % | 87 % |
  | Proposed (size) | 5 % | 13 % | 35 % | 66 % | 89 % |
- *Why:* players watch right after planting. Long plants (15 min to 4 h) look stuck for minutes today.
- *Cost:* 2 lines in `PlantGrowth`. The server silhouette uses the same module, so near and far views stay the same size.
- *Risk:* low. Fruit timing and readiness are unchanged; only the drawing changes.

**#5 Solid leaves that grow out of the stem.**
- *What the player sees:* leaves, canopy pieces and petals keep their real opacity. Each one grows out from the point where it joins the stem,
  lower leaves first. This replaces today's ghost fade (frames 25 % and 50 %).
- *Why:* it looks alive instead of half-loaded.
- *Cost:* the same number of writes as today, and **fewer semi-transparent parts**, which are cheaper to draw on phones. The join point is
  worked out once when the plant is captured. About 30 lines in `PlantGrowth`.
- *Risk:* low to medium. Unusual art could grow from the wrong end. Run the R134 floating check at 25 / 50 / 75 % for every plant, and keep a
  per-plant opt-out list.

**#6 Fruit that reads as unripe, then ripens cleanly.**
- *What the player sees:*
  - a young fruit is a **pale green made from its own colour pattern**: a melon keeps its stripes, and shading stays;
  - it swells, plumps 5 % past full size and settles exactly at ripe;
  - its ripe colour arrives in the last 45 % along a bright path, green -> yellow -> orange -> red for red fruit, instead of mud. See the colour
    strip in the picture;
  - Neon and other special materials switch on **at the ripe moment** together with #7, instead of snapping at 82 %.
- *Why:* young fruit is visible against the leaves, there is no "rotten" middle colour, and the glow becomes part of the ripe moment.
- *Cost:* the same writes as today. About 35 lines in `PlantGrowth`, including small colour helpers (`Color3:ToHSV` / `fromHSV`).
- *Risk:* low. Mutated (coated) fruit keeps today's rule of no colour blend.

**#7 Ripe moment: one bounce and a few glints.**
- *What the player sees:* when a fruit becomes ripe, it bounces once (+10 %, back, settle, 0.8 s) and 3-4 small glints pop around it. It does
  not keep looping.
- *Why:* this is the "ding" of the loop. Today nothing marks it.
- *Cost:*
  - limits: at most 6 cues every 2 s across the whole garden, at most 4 fruits bouncing at once, and only plants near the camera and on screen;
  - 4 shared particle emitters that fire short bursts and are never left running;
  - switched off by the player's reduced-motion setting and on low quality.
  - New client module `PlantGrowthFx`, about 150 lines (from the WIP), plus about 15 lines in `GardenVisuals`.
- *Risk:* low. It is cosmetic and switches itself off after 3 errors.

**#8 Harvest pop.**
- *What the player sees:* the picked fruit squashes, stretches up and shrinks away in 0.36 s, with a small puff in its own colour, lightened.
  A new bud then starts at the stalk.
- *Why:* today the fruit vanishes in one frame. This is the most repeated action in the game.
- *Cost:* it animates the picked fruit's **own** parts, which are thrown away right after anyway, so no clone and no new parts. At most 2-5 pops at
  once. About 70 lines in `PlantGrowthFx`, plus about 8 lines in `GardenVisuals`.
- *Risk:* low.
- **Owner change (as built):** the squash / stretch / puff is replaced by "when harvesting just change it so that it floats into the player and
  disappears after and appears in the players inventory". See section 7.

### Nice (phase 2)

**#9 A blossom before each fruit.**
- *What the player sees:* a small 5-petal flower, sized from its fruit, opens at the stalk. Its petals drop as the fruit sets (frames
  "regrow 15 %" and Watermelon 50 %). It tells the player a fruit is coming.
- *Cost:* 5 temporary parts per growing fruit, for the first 20 % of that fruit only, then removed. About 35 lines.
- *Risk:* low. Its colour could come from the plant's flower colour later.

**#10 Glide instead of jump.**
- *What the player sees:* when the growth pass is bought (or any other sudden speed-up), plants grow into their new size over about 0.35 s
  instead of snapping.
- *Cost:* about 30 lines (the WIP's `Follow`). Only plants that are gliding are stepped per frame, capped at 2-6.
- *Risk:* low.

**#11 Progress bar on the selected plant.**
- *What the player sees:* a thin bar under today's tap / click label, filling with the same progress as the timer text.
- *Cost:* user interface only, and only for the one selected plant. About 25 lines in `PlantInspection`.
- *Risk:* low.

**#12 Celebrate a big roll; watchers hear the pop.**
- *What the player sees:*
  - a fruit that rolled 1.5x or more gets a bigger glint burst when it ripens. Size is GaG's main reward (G4);
  - other players nearby hear a quieter harvest pop.
- *Cost:* about 15 lines in `PlantGrowthFx`.
- *Risk:* low.

### Skip

| | Idea | Why not |
|---|---|---|
| S1 | A timer or bar always shown over every plant | One floating label per plant, for every plant in every visible garden, is real UI cost on phones. #11 covers the need. |
| S2 | A tween or Heartbeat connection per plant or per part | Breaks the batching rule. It scales with the number of plants, not with what is on screen. |
| S3 | A permanent glow, sparkle or Highlight on every ripe fruit | Particles never stop, and Roblox draws at most 31 Highlights (R148). #7 is a one-off burst instead. |
| S4 | Separate models per growth stage (GaG "Evo" style, G7) | 3-4x the art for every plant, plus visible swaps. Continuous growth already matches GaG's normal crops. |
| S5 | Picked fruit dropping with physics | Network and physics cost, and fruit rolling around the garden. |
| S6 | Smoother far-away silhouettes | Too far to notice. They already use the same growth module. |
| S7 | A growth sound loop, or beats at 33 / 66 % | Noise for plants that mostly grow while nobody watches. |

## 4. Exclusions

- **Lantern Fern and Amethyst Grape: their look is frozen.**
  - They stay on today's drawing at every moment: the same curve, ghost-fade leaves, colours, materials and bud.
  - They get no seedling change, no blossom, no growing sway, no ripe bounce and no harvest pop.
  - Only #1 applies. It draws the same pictures with fewer writes, and it matters most for the Amethyst Grape, the heaviest plant in the game.
  - The scratch module already has this list (`LookFrozen`).
- **Ash Tomato keeps its model.** The general growth animation (#2-#8) moves and recolours its existing parts, and its Neon ember seams light
  up at the ripe moment instead of at 82 %. No new geometry, apart from the temporary seedling (and the blossom, if #9 is approved).
- **Plants with their own systems are not touched:** Mech holograms (`MechGrowth`), Verity (`VerityGrowth`), the giant Dune Starfruit (no sway
  by design), and the Obsidian Maw / Silent Frostbell / floating-petal motions.

## 5. Phase 1: what "approve" means

**Approve phase 1 = items #1 to #8, in one release.**

| Item | Lines (approx.) | Files |
|---|---|---|
| #1 Write only what moved | 35 | `PlantGrowth`, `GardenVisuals` |
| #2 Sway while growing | 25 | `PlantGrowth`, `GardenVisuals`, `PlantAnimationBatch` |
| #3 Sprout pop | 20 | `PlantGrowth` |
| #4 Fast-start curve | 2 | `PlantGrowth` |
| #5 Solid leaves | 30 | `PlantGrowth` |
| #6 Fruit ripening | 35 | `PlantGrowth` |
| #7 Ripe bounce + glints | 165 | new `PlantGrowthFx`, `GardenVisuals` |
| #8 Harvest pop | 80 | `PlantGrowthFx`, `GardenVisuals` |
| Tests | about 120 | mock tests (see below) |

- **Reuse:** the unfinished Sonnet WIP (`PlantGrowthCurves` + `PlantGrowthFx`, about 430 lines, in the session scratchpad, not in the repo) already drafts #3, the swell, #7, #8, #10 and
  the write limit. Phase 1 would take its curves and particle pool, not its diff as-is.
- **Checks before shipping:**
  - mock tests: the poses of every plant at 0 / 25 / 50 / 75 / 100 %, nothing floating (R134 check), and the frozen plants pose exactly as today;
  - the effect limits per quality tier;
  - in Studio, a full growing garden with `PlantAnimationStepMs` / `PlantAnimationMoves` recorded before and after.

> **One word to approve phase 1: "approve".** Say "phase 2 too" to add #9-#12.

## 6. Files

- `growth_style.png`: the picture.
- `preview/run_growth_preview.sh <scratch> [node_modules]`: reruns everything. It needs `/opt/luau`, python3 + Pillow, node + playwright and
  three@0.169.0.
- `preview/GrowthStyle149.luau`: the proposed drawing (scratch; it runs on the real `PlantGrowth.Capture` state).
- `preview/dump_growth.luau`: builds every frame with the real modules and prints the scenes, the INFO rows, the colour strips and the size table.
- `preview/render_growth.mjs`: draws the scenes with `fruit_models.html` (shared with the fruit-model preview).
- `preview/make_growth_sheet.py`: composes the sheet.

## 7. As built (phase 1)

Items #1 to #7 are built as specified above. **#8 follows the owner's change**: the picked fruit floats into the harvesting player and
the item then shows in their inventory.

- **Flight:** the picked fruit's own parts (no clone) lift off and fly along a smooth arc to the harvester's `HumanoidRootPart` plus 0.9 studs,
  following the player if they move. They take 0.4 to 0.7 s (longer for a far player), shrink to 55 % and vanish on arrival. Gold / Diamond /
  mutated / giant fruit keep their colours and materials. Other players see the same flight to the garden's owner (the harvester), because the
  plant's attribute change already replicates to everyone; nothing new is sent.
- **Inventory:** the server adds the item at once and nothing about the data changes. On the harvester's client the new module `HarvestArrival`
  holds the item's *appearance* in the hotbar / Bag until the fruit lands (at most 1.5 s, then it shows anyway). The matching slot (or the Bag
  button when the slot is not visible) then flashes for 0.32 s.
- **Limits:** at most 8 flights and 200 parts at once (5 / 120 on phones); beyond that, or with reduced motion, or on the lowest quality tier, the
  fruit vanishes at once as before and nothing is held. One per-frame step for all flights, no per-fruit connection. A harvester who leaves,
  dies or streams out, or a plant that streams out, removes the fruit and releases the inventory.
- **Not touched:** Lantern Fern and Amethyst Grape keep today's exact look (no flight, no sway change); Mech, Verity, Starfruit, Maw, Frostbell and
  floating-petal plants are skipped by `PlantGrowthFx`.
- **Tests:** `tests/run_growth.sh <dir>` runs the six growth suites, the floating-parts check and the write benchmark; `... mutate` plants 20
  mutations that the suites must catch.
- **Preview:** `growth_style_built.png` (before vs now, the real modules); `preview/run_growth_preview.sh` renders it.
