# R148 seed roster: Desert Aloe + Sand Fruit, Mythic Fire Pepper, Legendary Moon Melon

Design: `docs/proposals/R148/seeds_plan.md` (with the owner decisions at its top). Preview: `docs/proposals/R148/seeds_new.png`. Tests: `docs/proposals/R148/tests/run_roster.sh`.
Two new ModuleScripts (`ReplicatedStorage/Roster149`, `ReplicatedStorage/DesertPlantArt149`) are in `src/MANIFEST.tsv`; the installer adds them.

**When you publish: shut down all servers.**
- Saves now carry profile version 22 (new packs carry odds version 149). An older server refuses a version-22 save ("requires a newer server") and **changes nothing**. Without that, an
  old server would turn a new pack into a legacy-odds pack for good.
- **Undo** after players have saved: the old code refuses version-22 saves until this release is installed again (the same caveat as R147).
- A gift staged by a new server and opened on an old one could lose its odds version; shutting down all servers removes that case.

## What changed
### Desert gets two seeds (Desert Index: 5 -> 7)
| | Aloe | Sand Fruit |
|---|---|---|
| Rarity | Rare | Legendary |
| Plant | a blue-green rosette of pointed leaves with 3 tall flower spikes crowded with florets, red at the bottom and yellow at the tip (one spike = one fruit) | a round barrel cactus made from the game's own cactus pieces, with 4 lumpy sand-textured fruits on its shoulders (one fruit = one fruit); a bush-type plant, so it never blocks planting |
| Grows / regrows | 960 s / 530 s | 2760 s / 1520 s |
| Cash per fruit | 10,000,000 | 26,400,000 |
| Index cash first / repeat | 10,000,000 / 2,000,000 | 26,400,000 / 5,280,000 |
| Chance in a Common Desert pack | 1/8 | 1/90 |

- **Growth variations (4 designs each).** Like the other plants, every planted Aloe and Sand Fruit shows one of four designs, chosen by its crop id (so it is always the same one, on every client, in the far view and for the harvest prompts), plus a small size / turn variation (+-2%).
  Aloes: 14 to 20 leaves, other leaf lengths and leans, other rosette spreads, spikes of other heights, leans and places (one design bunches them to one side), 21 to 25 florets a spike with a red-heavy, balanced, sunset or golden colour balance, other spot patterns.
  Sand Fruits: a round barrel, a tall one, a squat one and a ribbed one: 7 to 9 ribs, sparse to dense spines, 0 to 3 pups, and four fruits at other places on the shoulders and top and in other sizes.
  Every design keeps 3 / 4 fruits, has its own sockets and bounds, and is 124 to 128 / 88 to 100 parts. The catalog's Height / Radius are the biggest design's with the usual 5% margin (Aloe 10.3 / 5.8, Sand Fruit 14.7 / 8.5). Fire Pepper keeps its one design (at x2) with its ten small size / turn variations.
- The Aloe earns 2.04e8 per hour: a little more than the Uncommon Prickly Pear (2.00e8), less than Iceberry and the Sand Fruit.
- The old Uncommon "Aloe" seed (retired, some players hold one) is now called **Aloe Sprout**.

### Desert packs: the floor changes
- **New** Desert packs no longer roll the Prickly Pear from the Epic pack up. Epic: Aloe 1/1 and Sand Fruit 1/6 (before: Prickly Pear 95%); Legendary: Aloe 1/1 and Sand Fruit 1/5 (Prickly Pear was 87%); Mythic: Sand Fruit 1/1, about 78% (Prickly Pear was 78%).
  A Common pack still gives the Prickly Pear 1/1, Aloe 1/8 and Sand Fruit 1/90.
- **Packs you already hold** (made before this release) keep their old Desert odds: Prickly Pear as before, and they never give the Aloe or the Sand Fruit.

### Fire Pepper (Lava): Rare -> Mythic
- **Twice as big**, peppers included. 4300 s / regrow 2370 s, **285,000,000 per pepper** (was 26,916,667), index cash 360M first / 72M repeat. The seed gets a Mythic look (green calyx, curled stem, three flickering flames).
### Moon Melon (Crystal): Rare -> Legendary
- 3400 s / regrow 1870 s, **509,000,000 per fruit** (was 168,214,286), index cash 475M / 95M.
- Both keep their id, name and fruit count, so every planted crop, harvested fruit, Bag seed and Index entry stays as it is.
- **Fire Pepper and Moon Melon you already have earn the new values**: seeds in your Bag show the new rarity at once; planted crops show at the new size at once and are picked at the new value from now on, **including
  fruit that is already ripe on the plant** (285,000,000 per pepper, 509,000,000 per melon), and regrow on the new timers. Fruit already in your Bag keeps the value it was picked at.

## Packs
- New packs (and every pack made from now on) roll with odds version 149 = the R137 numbers over the new roster. Chance in a Common pack: Fire Pepper 1/800, Moon Melon 1/150; Lava's and Crystal's Rares now share their tier between two seeds (1/2 each, was 1/3).
- **Packs you already hold (no windfall): they can no longer roll Fire Pepper or Moon Melon at all**, not even at their new, rarer tiers. The seeds that shared their old Rare tier take the share
  (a banked Common Lava pack: Ember Pumpkin and Ash Tomato 1/2 each instead of 1/3; a banked Common Crystal pack: Amethyst Grape and Prism Pepper 1/2 each) and every other seed keeps exactly the odds it had.
  Holding such a pack shows the real odds, so there is no Fire Pepper or Moon Melon row. Forest, Desert, Snow, Jungle and Storm packs and Void / Mech / Verity packs are exactly as before.
- Pack tooltips (and the owner's `odds` command) now list the seeds from the commonest to the rarest, then by name (the Void, Verity and Limited Mech packs keep their own order, Verity seed first).
- Fruit of the Hour now has 53 candidates (the two new fruits); its hourly schedule reshuffles once.

## Index
- Claimed rewards stay claimed (nothing is given twice). Desert's Index grows to 7 seeds. A halfway or completion milestone you had **already reached** with the old 5 Desert seeds stays claimable: the game records it the first
  time you join after this release. New players, and players who had not reached it yet, need all seven Desert seeds (and plants) for the completion reward.

## Garden glow
- The rarity glow (a Highlight on every Legendary-and-up plant; Roblox draws 31 in all) is limited to four plants at a time (two on low graphics, which have no glow). It used to go to the four nearest; it now goes to the rarest
  first, then the nearest, so a King, Cosmic or Secret plant keeps its glow next to several Legendary or Mythic ones.

## Owner test commands
- `/test rarepacks roster @name`: four TEST packs that reveal Fire Pepper (Mythic), Moon Melon (Legendary), Aloe (Rare) and Sand Fruit (Legendary). `seed DesertAloeSeed`, `seeds desert` and `odds desert rare` include the new seeds.

## To look at in Studio (cannot be checked on the mock)
- The Aloe's leaf spots and teeth (orientation) and its denser flower spikes; the cactus' ribs and ivory spines; the Sand material (`Enum.Material.Sand`) and the fruit colour against the Desert sand; the x2 Fire Pepper beside neighbouring plants
  (placement spacing is fixed, so it may overlap them; saves are not affected). The Fire Pepper keeps its existing red pepper model at twice the size: the preview draws stand-ins, because the baked meshes are not in the repo.
