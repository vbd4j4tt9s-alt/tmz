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
| Plant | a blue-green rosette of pointed leaves, 3 tall red-orange flower spikes (one spike = one fruit) | a leaning desert palm with 8 arching fronds, 4 bunches of 3 sand-gold fruits (one bunch = one fruit; a solid, climbable trunk) |
| Grows / regrows | 960 s / 530 s | 2760 s / 1520 s |
| Cash per fruit | 10,000,000 | 26,400,000 |
| Index cash first / repeat | 10,000,000 / 2,000,000 | 26,400,000 / 5,280,000 |
| Chance in a Common Desert pack | 1/8 | 1/90 |

- The Aloe earns 2.04e8 per hour: a little more than the Uncommon Prickly Pear (2.00e8), less than Iceberry and the Sand Fruit.
- Old Desert packs (made before this release) never give the two new seeds. The old Uncommon "Aloe" seed (retired, some players hold one) is now called **Aloe Sprout**.

### Fire Pepper (Lava): Rare -> Mythic
- **Twice as big**, peppers included. 4300 s / regrow 2370 s, **285,000,000 per pepper** (was 26,916,667), index cash 360M first / 72M repeat. The seed gets a Mythic look (green calyx, curled stem, three flickering flames).
### Moon Melon (Crystal): Rare -> Legendary
- 3400 s / regrow 1870 s, **509,000,000 per fruit** (was 168,214,286), index cash 475M / 95M.
- Both keep their id, name and fruit count: every planted crop, harvested fruit, Bag seed and Index entry stays as it is. Planted copies earn the new value from the next harvest and show at the new size at once.

## Packs
- New packs (and every pack made from now on) roll with odds version 149 = the R137 numbers over the new roster. Chance in a Common pack: Fire Pepper 1/800, Moon Melon 1/150; Lava's and Crystal's Rares now share their tier between two seeds (49.5%, was 33%).
- **Packs you already hold (no windfall):** Forest, Desert, Snow, Jungle and Storm packs, and Void / Mech / Verity packs, are exactly as before. **Lava and Crystal packs now roll like new ones**: Fire Pepper and Moon Melon are at their new tiers
  (in a Common Lava pack Fire Pepper is 1/800 instead of about 1/3, in a Common Crystal pack Moon Melon is 1/150), Ember Pumpkin / Ash Tomato / Amethyst Grape / Prism Pepper share the Rare tier two ways, and a Mythic Lava pack is now
  Fire Pepper 16% + Lava Lotus 82%, a Mythic Crystal pack Moon Melon 85% + Diamond Vine 13%. Holding such a pack shows the real odds.
- Fruit of the Hour now has 53 candidates (the two new fruits); its hourly schedule reshuffles once.

## Index
- Claimed rewards stay claimed (nothing is given twice). Desert's Index grows to 7 seeds: a halfway or completion milestone you reached with the old 5 Desert seeds stays claimable.

## Owner test commands
- `/test rarepacks roster @name`: four TEST packs that reveal Fire Pepper (Mythic), Moon Melon (Legendary), Aloe (Rare) and Sand Fruit (Legendary). `seed DesertAloeSeed`, `seeds desert` and `odds desert rare` include the new seeds.

## To look at in Studio (cannot be checked on the mock)
- The Aloe's leaf spots and teeth (orientation), the palm's frond droop and the sand-gold fruit against the Desert sand, the x2 Fire Pepper beside neighbouring plants (placement spacing is fixed, so it may overlap them; saves are not affected).
