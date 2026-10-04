# Seed roster change (R149): Desert Rare + Legendary, Lava Mythic, Crystal Legendary

Base: `9c9797e`. Written as a design and prototyped on the Roblox mock against `9c9797e`, then shipped as R148 with the owner decisions below, which
OVERRIDE the plan text where they differ. The shipped code is in the repo (Appendix A lists the files); the numbers below were checked against it:
- `Config.Validate` passes.
- Every banked-pack odds row of every biome except Lava and Crystal is byte-identical to the base: stages 1-7 x 9 variants x OddsVersion 0/81/112/137 x
  6 luck levels x boost none/2. In the Lava and Crystal rows only the promoted seed and its old tier-mates differ (owner decision 1). Void, Mech and Verity odds are
  identical for every version.
- The other 60 old plants are identical to the base (Seconds, Regrow, Value, Rarity, geometry); only Fire Pepper and Moon Melon change, as designed.
- The new seeds and plants build with 0 floating parts (R134 checker).
- The R137 and R147 suites pass after the test edits in section 6.3.
- 1M `math.random` rolls with v149 packs match the section 4 tables: Aloe 12.56%, Sand Fruit 1.116%, Fire Pepper 0.125%, Moon Melon 0.663%. A banked pack never rolls
  Fire Pepper or Moon Melon (owner decision 1).

Owner request: Lava Fire Pepper becomes Mythic (bigger peppers, more cash). Crystal Moon Melon becomes Legendary. Desert
gets a Legendary "Sand Fruit" (planned as a palm; shipped as a round cactus, owner decision 3) and a Rare "Aloe". Check the other biomes for gaps.

## Owner decisions and implementation notes (shipped as R148). Where they differ they OVERRIDE the plan text below

The release ships as **R148**; the identifiers keep the plan's "149" (`OddsVersion` 149, `Roster149`, `DesertPlantArt149`, `NewInR149`, ...).

**1. No windfall for banked packs: they cannot roll the two promoted seeds at all.** A pack made before the update (odds version none / 0 / 81 / 112 / 137) never gives
Fire Pepper or Moon Melon, not even at their new, rarer tiers: `SeedPackRules` drops the `Roster149.Promote` ids from the banked pools, next to the two new seeds (there is
no per-version rarity table any more). The seeds that shared their old Rare tier absorb the promoted seed's share, and the empty Mythic / Legendary tier hands up exactly as it
did before. Banked Desert packs still never give the Aloe or the Sand Fruit. New (149) packs have all four.
Checked against the base commit by `tests/run_roster.sh` (every banked version none / 0 / 81 / 112 / 137, all 9 variants Small / Standard / Grand / Pack01-06, 6 luck levels, with and without the 2x boost):
- **Byte-identical**: every Forest, Desert, Snow, Jungle and Storm row (2,196 of the 3,024 banked odds rows), every Void / Mech / Verity row, every seeded roll of those biomes, and, in every
  Lava / Crystal row, every seed that is not a tier-mate of the promoted seed.
- **Changed**: only the Lava and Crystal rows that listed the promoted seed (828 rows). In each, ONLY the promoted seed (it drops to 0) and the seeds of its old Rare tier move
  (`check_roster_diff.py` allows nothing else, and requires that they absorb exactly its share): Ember Pumpkin / Ash Tomato in Lava, Amethyst Grape / Prism Pepper in Crystal.
  Percent per seed, boots x1, before -> after, in a Common / Uncommon / Rare / Epic / Legendary / Mythic pack of odds version 137 (every pack made since R137):

  | Banked 137 pack | Common | Uncommon | Rare | Epic | Legendary | Mythic |
  |---|---|---|---|---|---|---|
  | Lava: Fire Pepper | 33.05 -> 0 | 32.77 -> 0 | 32.12 -> 0 | 28.82 -> 0 | 27.80 -> 0 | 0 (as before) |
  | Lava: Ember Pumpkin / Ash Tomato (each) | 33.05 -> 49.58 | 32.77 -> 49.15 | 32.12 -> 48.18 | 28.82 -> 43.23 | 27.80 -> 41.70 | 0 |
  | Lava: Lava Lotus and the rest | same | same | same | same | same | same (97.98) |
  | Crystal: Moon Melon | 33.30 -> 0 | 33.24 -> 0 | 33.09 -> 0 | 32.15 -> 0 | 30.35 -> 0 | 28.22 -> 0 |
  | Crystal: Amethyst Grape / Prism Pepper (each) | 33.30 -> 49.94 | 33.24 -> 49.86 | 33.09 -> 49.64 | 32.15 -> 48.23 | 30.35 -> 45.53 | 28.22 -> 42.32 |
  | Crystal: Diamond Vine and the rest | same | same | same | same | same | same |

  The older versions do the same in their own tier math (Fire Pepper in a Common Lava pack: v112 32.2 -> 0, v81 31.3 -> 0, no version 25 -> 0; Ember / Ash 32.2 -> 48.3, 31.3 -> 47, 25 -> 37.5); every seed outside the
  old Rare tier keeps exactly its old odds in every version. The Secret / Cosmic / King seeds never move.
- The hold tooltip of a banked pack lists exactly the seeds it can roll (so no Fire Pepper / Moon Melon row): it reads the pack's own odds. A new Lava pack shows "Fire Pepper Seed: 1/800".
  `odds <biome> <tier>` shows the new packs.

**2. The Rare Aloe out-earns the Uncommon Prickly Pear.** Aloe `Value = 10,000,000` (the plan's rule alone gave 7,680,000; 9,900,000 is the least that passes).
Derived: 2.04e8 per hour (Prickly Pear 2.00e8, Iceberry 2.73e8, Sand Fruit 2.50e8: every ladder below still increases), Index cash 10,000,000 first / 2,000,000 repeat.

**3. Art, after the owner looked at the preview.** "Use assets that are already in the game; make it a ROUND CACTUS with sand fruits growing from it; the sand fruit will just be sand-textured balls
with slight shape" and, for the Aloe, "increase the amount of ticks on the stick, make it fuller and more vibrant" (section 5):
- **Sand Fruit is a round barrel cactus, not a palm.** Built from the game's own cactus pieces (read from `ApprovedPlantArt6` and `AgaveSeedArt45` when the plant is built, with the same values as fallback): the
  Prickly Pear's stem green, the Crown Cactus' rib and ivory spine, the Prickly Pear's fruit attachment. Four fruits grow out of its shoulders, each a lumpy `Enum.Material.Sand` ball with a lump and a nub.
  95 parts; the seed is a sandy round seed with the same cactus nub and spines. It is a **Bush-type** plant (`Tree=false`): no trunk collision, it never blocks planting.
- **Aloe: much denser and more vibrant.** 24 florets on each spike (it was 9), saturated red at the bottom grading through orange to yellow at the tip, richer blue-green leaves, 127 parts.
- **Fire Pepper art is unchanged** (the existing red pepper model x2). The preview draws stand-ins for its baked meshes, which are not in the repo.

**4. The Index fallback applies only to players who had already reached the milestone.** Desert's Index grew from 5 to 7 seeds. On the first load after the update the server records which Desert milestones
(halfway / complete) the player had already met with the old 5 seeds (`Premium.OldRoster148`, saved, sanitised on decode; a new player starts with an empty record) and publishes them as `IndexOldHalf2` / `IndexOldFull2`;
`IndexMilestone` and `ChestIndex` use "the live milestone OR that flag". A new player, or an old one who had not got there, needs the live seven. Claimed rewards stay claimed, so nothing pays twice.

**5. The rarity auras are prioritised.** Every plant of rank 4 or more (Legendary and up) wears a `Highlight`, and Roblox draws at most 31 in all. GardenVisuals already let only four plants (two in low mode, which makes no aura)
carry effects, but gave the slots out nearest-first, so a few near Legendary or Mythic plants could crowd out a King, Cosmic or Secret one. The slots now go by rarity rank first, then distance (`PlantEffects.GrantSlots`).

**6. Pack tooltips and the `odds` command list their rows by rarity rank (commonest first), then name** (`SeedPackRules.OddsRows`), not in save-slot order. The Void, Verity and Limited Mech packs keep their pool order (the Verity pack still lists the Verity seed first, R147).

**7. What existing Fire Pepper / Moon Melon copies do.** Seeds in Bags show the new rarity at once; planted crops, including fruit that is already ripe on the plant, are picked at the NEW value
(`PlantRules.Fruit` reads the definition at the pick: 285,000,000 per pepper, 509,000,000 per melon) and regrow on the new timers; harvested fruit already in a Bag keeps its saved value.
**New Desert packs drop the Prickly Pear from their Epic, Legendary and Mythic rows** (Epic: Aloe 78.1% / Sand Fruit 16.7%; Legendary: 66.9% / 20%; Mythic: Sand Fruit 78.0%; before: Prickly Pear 94.8% / 86.9% / 78.0%).
Banked Desert packs keep their old rows.

**8. Found while implementing** (not owner decisions):
- `ChestIndex.client.lua` had moved on since the plan was written (`rewardState`); the Index changes are applied to the current file.
- Existing tests that needed edits beyond section 6.3: `R137/tests/test_packs.luau` (`tiers()` reads today's rarity; all 42 rows are compared at version 137 and at 112, Lava and Crystal included, because the tier-mates absorb the
  promoted seed's share and so every tier's chance is the approved model's; the 1/800 and 1/150 checks read new packs), `R137/tests/test_index.luau` (header total 94), `polish_R124/tests/test_growth.luau` (loads the catalog without the roster change,
  because the roster plants are written after the pacing) and `R147/tests/test_verity_art.luau`.
- `GrowthPace125.Exempt` does not look at a `Roster149` flag: `PlantCatalog` applies the roster numbers AFTER the pacing, and that order is what keeps the pacing off them (the flag on the catalog entries is only a marker).
- `docs/proposals/R148/tests/` (run_roster.sh, dump_roster.luau, check_roster_diff.py, test_roster.luau, test_roster_art.luau) and `preview/` + `seeds_new.png` hold the tests and the preview.

---

## 0. Decisions in one screen

| # | Decision |
|---|---|
| D1 | **New ids** `DesertAloeSeed` (Rare, name "Aloe") and `SandFruitSeed` (Legendary, name "Sand Fruit") in Desert save slots **9 and 10**. Slots 1–8 keep their ids, the retired ones included. Retired `AloeSeed` / `DesertRoseSeed` / `AgaveSeed` / `SunKingPalmSeed` are never reused. |
| D2 | **Promotions** `FirePepperSeed` → Mythic and `MoonflowerSeed` → Legendary. Ids, names and **FruitCount stay** (4 and 2). FruitCount must stay: a saved crop's `FruitStates` are validated against it, and changing it makes `DecodeGarden` reject the player's whole garden ("Invalid plant traits"). |
| D3 | All plant numbers are written **after** `GrowthPace125.Apply`, in a new `Roster149.ApplyPlants` (the order is what keeps the pacing off them; the `Roster149=true` flag on their entries is a marker, not an exemption). **Do not** put the promoted or new plants through the pacing. Moon Melon is the Rare group's slowest raw entry (840 s → 1800 s). Taking it out of that group, or adding seeds outside the group's raw range, re-spreads the time and value of **every** Rare/Legendary/Mythic plant in the game. |
| D4 | **New `OddsVersion` 149** for every pack made from now on. It uses PackOdds137's frozen numbers over today's roster. **Packs already banked keep their exact per-seed odds** (owner rule since R112/R137): they roll the roster they were made with. That means no Aloe or Sand Fruit. ~~Fire Pepper / Moon Melon stay in their Rare tier~~ (owner decision 1: banked packs cannot roll them at all; their old tier-mates absorb the share). The seeds they hand out are today's seeds, so the reveal shows today's rarity. No PackOdds table changes. |
| D5 | **ProfileVersion 21 → 22.** An old server would read OddsVersion 149 as invalid → `nil` and re-save the pack as a legacy-odds pack for good. The R147 precedent, where Verity packs became Standard packs on an old server, is the same failure. |
| D6 | **Index safety**: claimed rewards stay claimed (no duplicates). Desert grows from 5 to 7 entries. A halfway or completion milestone a player had **already reached with the old 5-seed roster** stays claimable on both server and client (recorded once on the first load after the update, owner decision 4); everyone else needs the live seven. |
| D7 | Void, Verity, Mech, Fruit of the Hour rules, Market, PackOdds81/112/137, BalanceRules and VoidPackOdds85 are unchanged. Fruit of the Hour automatically gains the 2 new fruits (51 → 53). |

---

## 1. Audit and final roster

Gaps today (real Config on the mock):
- Desert has no Rare and no Legendary.
- Lava has no Mythic.
- Crystal has no Legendary.
- Forest, Jungle, Snow and Storm have Rare, Legendary and Mythic.

Other "gaps" are by design, not asked for, and left alone:
- Forest and Jungle have no Secret/Cosmic/King (beginner biomes; the Void pack excludes them too).
- Desert and Snow have no Common (biome floor is Uncommon).
- Lava, Crystal and Storm have no Common/Uncommon (biome floor is Rare).

Side effect, and an improvement: R137's "missing floor steps down" quirk goes away for new packs. In a new Desert Epic, Legendary and Mythic pack the Prickly Pear is no longer a roll at all
(Epic: Aloe 78.1% / Sand Fruit 16.7%; Legendary: 66.9% / 20%; Mythic: Sand Fruit 78.0%; before: Prickly Pear 94.8% / 86.9% / 78.0%). The Desert, Lava and Crystal Mythic packs floor at their Legendary.
Banked Desert packs keep their old rows.

Final roster. **Bold** = changed. Ids in brackets; slot = save stage/index.

| Biome (stage) | Common | Uncommon | Rare | Legendary | Mythic | Secret | Cosmic | King |
|---|---|---|---|---|---|---|---|---|
| Forest (1) | Watermelon | Blueberry | Apple, Mooncap | Sunflower | Elderbloom | – | – | – |
| Jungle (6) | Cocoa | Pineapple | Venom Vine, Lantern Fern | Tiger Orchid | Ancient Worldroot | – | – | – |
| Desert (2) | – | Prickly Pear | **Aloe** [DesertAloeSeed, 2/9] | **Sand Fruit** [SandFruitSeed, 2/10] (a round cactus) | Dune Lotus | Dune Starfruit (slot 5/4) | Mirage Fig | Solar Starfruit |
| Snow (3) | – | Snow Melon | Iceberry | Aurora Lily | Glacier Lotus | Silent Frostbell | Polar Starbloom | Winter Crownwood |
| Lava (4) | – | – | Ember Pumpkin, Ash Tomato | Lava Lotus | **Fire Pepper** (was Rare) | Obsidian Maw | Boom Bloom | Ember Emperor |
| Crystal (5) | – | – | Amethyst Grape, Prism Pepper | **Moon Melon** (was Rare) | Diamond Vine | Hollow Geode | Orbit Lotus | Prism Monarch |
| Storm (7) | – | – | Spark Reed, Thunder Tulip | Volt Orchid | Tempest Lotus | Blackout Bloom | Storm Sovereign | Pulsar Starfruit |

Counts change as follows:
- Biome designs: 45 → 47.
- `#SeedDesigns`: 52 → 54 (47 biome + 6 Mech + Verity, Verity still last).
- Plants: 63 → 65.
- `SeedCatalogByStage[2]`: 8 → 10.
- Desert obtainable pool / Index: 5 → 7.
- Fruit of the Hour candidates: 51 → 53.

---

## 2. Promotions

| | Fire Pepper (`FirePepperSeed`) | Moon Melon (`MoonflowerSeed`) |
|---|---|---|
| Rarity (seed, design, plant `Rarity`/`Rank`) | Rare/3 → **Mythic/5** | Rare/3 → **Legendary/4** |
| First grow / regrow (s) | 1140 / 630 → **4300 / 2370** | 1800 / 990 → **3400 / 1870** |
| Fruit count | 4 (unchanged) | 2 (unchanged) |
| Value per fruit | 26,916,667 → **285,000,000** (×10.6) | 168,214,286 → **509,000,000** (×3.0) |
| Income / h (base) | 6.15e8 → **1.73e9** (×2.8) | 1.22e9 → **1.96e9** (×1.6) |
| Index cash first / repeat | 34,000,000 / 6,800,000 → **360,000,000 / 72,000,000** | 157,000,000 / 31,400,000 → **475,000,000 / 95,000,000** |
| Art | **×2** (plant and peppers). H 6.0 → 12.0, R 3.0 → 6.0, pepper 1.77×2.10×0.85 → 3.54×4.20×1.70 | unchanged |
| Seed look | adds a Mythic signature (§5.4) | unchanged (its Twinkle star now animates, Legendary+) |

The numbers follow the game's own rules:
- **EconomyBalance90**: income/s = biome base × tier. Bases: Desert 34,760, Lava 137,578, Crystal 272,073. Tiers: Rare 2.5, Legendary 4, Mythic 7.
- **GrowthPace125**: paced tiers keep half that income. Bands: Rare 900–1800 s, Legendary 2700–3600 s, Mythic 3600–5400 s. Regrow = 0.55 × grow, rounded to 10 s.
- Value per fruit = income × regrow / fruit count.
- Index cash is scaled by new/old fruit value (the `EconomyBalance90.Apply` convention).

Value per hour against the neighbours. All ladders stay strictly increasing:

| Ladder | Values (income/h) |
|---|---|
| Lava | Ember/Ash (Rare) 6.2e8 < Lava Lotus (Leg, single-harvest) 1.10e9 < **Fire Pepper 1.73e9** < Obsidian Maw (Secret) 4.95e9 < Boom Bloom 1.48e10 < Ember Emperor 1.24e11 |
| Mythic, by biome | Worldroot 8.6e7 < Dune Lotus 3.5e8 < Glacier Lotus 7.6e8 < **Fire Pepper 1.73e9** < Diamond Vine 3.43e9 < Tempest Lotus 8.21e9 |
| Crystal | Amethyst/Prism (Rare) 1.22e9 < **Moon Melon 1.96e9** < Diamond Vine 3.43e9 < Hollow Geode 9.81e9 |
| Legendary, by biome | Tiger Orchid 4.9e7 < **Sand Fruit 2.5e8** < Aurora Lily 7.9e8 < Lava Lotus 1.10e9 < **Moon Melon 1.96e9** < Volt Orchid 4.68e9 |

Grow times sit between the neighbouring biomes:
- Mythic: Jungle 3600 · Desert 3650 · Snow 3820 · **Lava 4300** · Storm 4840 · Crystal 5400.
- Legendary: Jungle 2700 · **Desert 2760** · Snow 2880 · Lava 3200 · **Crystal 3400** · Storm 3600.

**Copies players already have.** Nothing is lost, nothing is duplicated:
- **Seeds in Bags** show the new rarity at once (`GetRarity` and plant `Rarity` drive the Bag, tooltips, borders and the reveal). Planting one gives the new plant.
- **Planted crops** keep their `PlantedAt`/`MatureAt`/`ReadyAt`. Every fruit picked from now on is priced at the new Value, because `PlantRules.Fruit` reads `definition.Value` ("current growing plants earn current rates"). Each regrow after the update uses the new RegrowSeconds: slower, but more per hour. They show at ×2 size immediately. `FruitCount` is unchanged, so every saved garden still loads.
- **Harvested fruit** already in the bag keeps its saved `Value` and shows the new rarity label.
- **Index**: ids are unchanged, so discovered seeds and plants stay discovered and pending seed rewards stay as they are. Future pulls pay the new first/repeat cash. The Lava and Crystal Index membership is unchanged (7 each), so their milestones are unaffected.
- **Banked packs** (made before the update): owner decision 1 (top of this file). They cannot roll Fire Pepper or Moon Melon at all; the seeds of their old Rare tier absorb the share. The plan's default
  (~1/3, handed out as a Mythic or Legendary) and the interim "new tiers" rule (1/800) are not used. Banked Desert packs never give the new seeds.
- **Seeds and plants already held**: Fire Pepper and Moon Melon seeds in Bags, planted crops (including fruit that is already ripe on the plant, which is picked at the new value) and every Index entry carry on as described above.

---

## 3. New seeds: full data

| | **Aloe** | **Sand Fruit** |
|---|---|---|
| Id / slot | `DesertAloeSeed`, Desert save stage 2, index 9 | `SandFruitSeed`, stage 2, index 10 |
| Rarity / rank | Rare / 3 | Legendary / 4 |
| Seed name (catalog) | "Aloe" ("Aloe Seed") | "Sand Fruit" ("Sand Fruit Seed") |
| Plant `Name` / `HarvestName` | Aloe / Aloe bloom (UI: "Aloe Bloom") | Sand Fruit / Sand fruit |
| Plant | blue-green aloe rosette with 3 dense red-orange-to-yellow flower spikes (24 florets each). **Harvest = one flower spike**; the rosette stays and the spike regrows | a round barrel cactus (the game's own cactus pieces) with 4 sand-textured fruits on its shoulders. **Harvest = one fruit** |
| Tree / Mode | false / repeat | false (a Bush: no collision, never blocks planting) / repeat |
| FruitCount | 3 | 4 |
| First grow / regrow | 960 s / 530 s | 2760 s / 1520 s |
| Value per fruit | **10,000,000** (owner; the rule gave 7,680,000) | 26,400,000 |
| Income / h | **2.04e8** (the rule: 1.56e8) | 2.50e8 |
| Index cash first / repeat | **10,000,000 / 2,000,000** | 26,400,000 / 5,280,000 |
| Art bounds (Height / Radius) | 8.261 / 5.211 | 10.607 / 6.777 |
| Spec parts / detail cost | 127 / 128 | 95 / 96 |
| Index chip (Common pack) | 1/8 | 1/90 |

How the numbers were set:
- Aloe grows between Jungle's Rares (900 s) and Snow's Iceberry (1060 s).
- Rare row: Venom/Lantern 3.05e7 < **Aloe 2.04e8** < Iceberry 2.73e8 < Ember/Ash 6.2e8 < Amethyst 1.22e9 < Spark 2.94e9.
- Desert ladder: **Aloe 2.04e8** < **Sand Fruit 2.50e8** < Dune Lotus 3.47e8 < Dune Starfruit 1.25e9 < Mirage Fig 3.76e9 < Solar 3.13e10.
- Index cash for a new seed = one base fruit; the repeat amount is 1/5 of it, like every seed.

Note (owner decision 2): the plan's rule left the Aloe a little below Prickly Pear (2.0e8/h; an Uncommon, which R125 does not slow down: the same pattern as Iceberry vs Snow Melon and
Venom vs Pineapple). The owner wants the Rare Aloe above it, so its fruit is worth 10,000,000: 2.04e8 per hour, 1.02x Prickly Pear.

Retired-id hygiene: the retired Uncommon `AloeSeed`, which old players may still hold, would show as a second "Aloe Seed". It gets the display name **"Aloe Sprout"**. This is display only: `SeedDesignById.AloeSeed.name`, plant `Name`/`HarvestName`. Its id, value and timings are unchanged.

---

## 4. Odds

**Version and which packs use it.** `Rules.OddsVersion = 149`, added to `Rules.OddsVersions`, so `ValidOddsVersion(149)` is true.

All of these already stamp `PackRules.OddsVersion` and pick up 149 with **no code change**:
- Track packs (ChestService)
- Treadmill bonus packs
- Daily login packs (DailyProgress)
- The daily mystery pack (MysteryPackService)
- The tutorial starter pack (boost 2 still works)
- Void event packs (VeiledEvent81)
- Verity conversions
- Studio test packs

How each kind of pack rolls:
- **149 world packs** (stage 1–7, Pack01–06): PackOdds137 math over the live roster.
- **Void (EclipseReliquary) and Mech packs with 149** are passed down as 137, so they are **byte-identical** to today (Void 149 = Void 137 was checked).
- **Verity**: its wrapper stays outermost and ignores the version, so it is unchanged.
- The Void/Verity pools (Secret/Cosmic/King + Mech) are unchanged because no new seed is Secret+.
- **Banked world packs** (OddsVersion 137 / 112 / 81 / none) roll inside a "pre-R148 roster" scope (`SeedPackRules`, the R148 odds block):
  - the two new seeds AND the two promoted seeds (`Roster149.Promote`) are filtered out of `ObtainablePool` while a banked pack is rolled or priced (a per-config cache next to `legacyDepth`; the live pool is untouched);
  - there is no rarity mapping: every seed that can still be rolled has its live rarity, which is its old rarity, so the reveal and the record say what they always said. The seeds of the old Rare tier absorb the promoted seed's share;
  - Void, Mech and Verity packs and every other biome are exactly as before.

**Hold tooltip** (`ChestService:_holdPack`, `record.OddsVersion or 0`) needs no odds change and stays correct, because it prices the pack with the pack's own version; its rows (and `odds`) are now listed by rarity rank, then name (`PackRules.OddsRows`):
- A 149 Lava pack shows Fire Pepper 1/800.
- A banked 137 Lava pack shows no Fire Pepper row (its odds are 0, so the row is skipped), and a banked Crystal pack no Moon Melon row.
- Banked Desert packs list no Aloe or Sand Fruit (their odds are 0, so the row is skipped).
- **Index chips** (`BaseChance` = Pack01, current version) read: Aloe 1/8, Sand Fruit 1/90, Fire Pepper 1/800, Moon Melon 1/150. Prickly Pear goes from 1/1 to 1/1.2; Lava and Crystal Rares go from 1/3 to 1/2.

**Exact odds of new (v149) packs, no boots.** % (1/N as shown in game). Pack tiers are named Common, Uncommon, Rare, Epic, Legendary, Mythic (Pack01–06). Rows marked "=" are unchanged from today.

Desert:

| Seed | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Prickly Pear (Unc) | 86.2121 (1/1.2) | 77.3359 (1/1.3) | 54.0664 (1/1.8) | – | – | – |
| **Aloe** (Rare) | 12.5 (1/8) | 20 (1/5) | 40 (1/2.5) | 78.1313 (1/1.3) | 66.894 (1/1.5) | – |
| **Sand Fruit** (Leg) | 1.11111 (1/90) | 2.22222 (1/45) | 4.7619 (1/21) | 16.6667 (1/6) | 20 (1/5) | 77.98 (1/1.3) |
| Dune Lotus (Myth) = | 0.166667 (1/600) | 0.416667 (1/240) | 1.11111 (1/90) | 5 (1/20) | 12.5 (1/8) | 20 (1/5) |
| Dune Starfruit (Sec) = | 0.01 | 0.025 | 0.06 | 0.2 | 0.6 | 2 |
| Mirage Fig (Cos) = | 1/1M | 1/400000 | 1/166667 | 1/50000 | 1/16667 | 1/5000 |
| Solar Starfruit (King) = | 1/1T | 1/400B | 1/167B | 1/50B | 1/16.7B | 1/5B |

Desert before (137): Prickly Pear 99.8232 / 99.5581 / 98.8283 / 94.798 / 86.894 / 77.98 (this is still what a banked Desert pack rolls). The rest is as above.

Lava:

| Seed | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Ember Pumpkin (Rare) | 49.5158 (1/2) | 48.9978 (1/2) | 47.7673 (1/2.1) | 41.2323 (1/2.4) | 36.697 (1/2.7) | – |
| Ash Tomato (Rare) | 49.5158 (1/2) | 48.9978 (1/2) | 47.7673 (1/2.1) | 41.2323 (1/2.4) | 36.697 (1/2.7) | – |
| Lava Lotus (Leg) | 0.833333 (1/120) | 1.66667 (1/60) | 3.57143 (1/28) | 13.3333 (1/7.5) | 16 (1/6.3) | 81.98 (1/1.2) |
| **Fire Pepper** (Myth) | 0.125 (1/800) | 0.3125 (1/320) | 0.833333 (1/120) | 4 (1/25) | 10 (1/10) | 16 (1/6.3) |
| Obsidian Maw / Boom Bloom / Ember Emperor = | 0.01 / 1/1M / 1/1T | 0.025 / 1/400000 / 1/400B | 0.06 / … | 0.2 / … | 0.6 / … | 2 / 1/5000 / 1/5B |

Lava before (137):
- Fire Pepper, Ember and Ash each 33.0522 / 32.7694 / 32.1227 / 28.8216 / 27.798 / 0.
- Lava Lotus in the Mythic pack 97.98.

Crystal:

| Seed | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Amethyst Grape (Rare) | 49.6116 (1/2) | 49.1957 (1/2) | 48.2078 (1/2.1) | 42.6768 (1/2.3) | 38.8637 (1/2.6) | – |
| Prism Pepper (Rare) | 49.6116 (1/2) | 49.1957 (1/2) | 48.2078 (1/2.1) | 42.6768 (1/2.3) | 38.8637 (1/2.6) | – |
| **Moon Melon** (Leg) | 0.666667 (1/150) | 1.33333 (1/75) | 2.85714 (1/35) | 11.1111 (1/9) | 13.3333 (1/7.5) | 84.6467 (1/1.2) |
| Diamond Vine (Myth) = | 0.1 (1/1000) | 0.25 (1/400) | 0.666667 (1/150) | 3.33333 (1/30) | 8.33333 (1/12) | 13.3333 (1/7.5) |
| Hollow Geode / Orbit Lotus / Prism Monarch = | as Lava's Secret/Cosmic/King | | | | | |

Crystal before (137): each Rare 33.2966 / 33.2416 / 33.0909 / 32.1549 / 30.3536 / 28.2156.

Other notes:
- With the best boots (luck 5e7) in a Common pack: Aloe 1/8 (Rare ignores luck), Sand Fruit 1/22, Fire Pepper 1/47, Moon Melon 1/36.
- Per server-hour from track packs (60 packs per biome, tier weights 42.92/28.24/16.94/7.9/3/1, no boots or floors):
  - Aloe 15.6
  - Sand Fruit 2.8
  - Fire Pepper 0.64 (was 19.2 as a Rare)
  - Moon Melon 1.96 (was 19.8)
  - Server-wide Legendary ≈13.5 → ≈18.1/h; Mythic ≈4.5 → ≈5.1/h (R136 baseline).

---

## 5. Art direction (for the art coder)

### 5.1 Style read from the approved specs
- **Dune Lotus** (`DatePalmSeedArt45`, 137 parts) and **Lava Lotus** (125): a basal leaf ring made of **two-tone Wedge pairs**, one per leaf, the two halves a shade apart for shading. Flower = stacked Wedge petals plus a few Neon Corner "hearts". SmoothPlastic, no textures.
- **Prickly Pear** (`ApprovedPlantArt6`, 85): blocky stems, Wedge spines, flat Ball fruit shoulders. Desert palette: sage greens, pink fruit, gold crowns.
- **Fire Pepper** (`ApprovedPlantArt16`, 34): baked meshes (`SmoothFirePepper`, stems and stalks), 3 Ball sepals per pepper. Prism Pepper (`ApprovedPlantArt17`) shares the mesh family.
- **Moon Melon** (`MoonflowerSeedArt45`, 158): Wedge rind and flesh, a Neon glint.
- **Shared look**: chunky readable silhouettes; 2–3 tones per material; Neon only for small glows; Wood for bark; budgets of ~35–160 parts.
- **Format** = the "RarityRework" spec table that `PlantVisuals` reads directly. Each part is `{s,z,c(12 comps),k,m,t,g,r,f,p}`. Groups: g=0 body, g=i fruit i. Roles: Leaf/Stem/Fruit. `Sockets`/`FruitCenters`/`FruitRadii`/`Height`/`Radius` sit beside it. VerityPlantArt is the model to follow.
- **No new ApprovedMesh**: mesh data lives in ServerStorage and is not in this repo.

### 5.2 Aloe (`DesertPlantArt149`, Rare)
- Built at scale 1 and multiplied by `A.AloeScale = 1.5`. Numbers below are before x1.5.
- Leaf = 2 Wedges forming a pointed fleshy blade: thickness 0.36-0.42 along the leaf normal, triangular outline.
- Owner feedback: "increase the amount of ticks on the stick, make it fuller and more vibrant": 24 florets per spike (it was 9) and richer colours.

| Part | Shape x count | Geometry | Colour (RGB) | g / role |
|---|---|---|---|---|
| Rosette heart | Ball x1 | 1.1x0.7x1.1 at y .35 | 48,134,114 | 0 Stem |
| Outer leaves | 7 x Wedge pair | len 3.4, width .9, thick .42; base r .35, y .25; 28 deg above level; yaw k*51.4 deg | 42,124,110 / 56,142,124 | 0 Leaf |
| Middle leaves | 6 x pair | 3.0 / .8 / .40; r .25, y .35; 48 deg; yaw 25.7 deg + k*60 deg | 52,142,124 / 66,160,140 | 0 Leaf |
| Inner leaves | 4 x pair | 2.4 / .65 / .36; r .12, y .45; 68 deg; yaw 45 deg + k*90 deg | 64,160,138 / 80,178,152 | 0 Leaf |
| Leaf spots | Ball x7 | 1 per outer leaf, on the upper face at 40% of its length; .04x.24x.15 | 214,236,222 | 0 Leaf |
| Leaf teeth | thin Ball spike x7 | 1 per outer-leaf margin at 50%, leaning to the tip; .06x.24x.06 | 200,92,60 | 0 Leaf |
| Flower stalk | Cylinder x3 | d .18; length 4.6 / 4.0 / 3.5; socket r .15, y .7 at yaw 15 / 135 / 255 deg; tilted 10 deg outward | 112,150,92 | g Fruit |
| Florets | Ball x72 | **24 per spike** over the top 62% of the stalk, spiral 137.5 deg, hanging 30 deg below level; .19x.44x.19 | graded: deep red 226,44,30 -> red-orange 248,84,30 -> orange 255,138,36 -> 255,196,64 -> yellow 255,226,92 at the tip | g Fruit |
| Bud tip | Ball x3 | .20x.32x.20 at the stalk tip | 238,218,96 | g Fruit |

- **Total 127 parts** (groups: 49 body, 26 per spike). Sockets sit at the heart (y 1.05 after x1.5).
- FruitCenter = 70% up the stalk; FruitRadius = 0.3 x stalk length.
- The stalk is role **Fruit**, not Stem. `HarvestSpec` drops Stem parts from held items, which would leave floating florets.

### 5.3 Sand Fruit: a round cactus (`DesertPlantArt149`, Legendary)
Owner feedback: "use assets that are already in the game; make it a ROUND CACTUS with sand fruits growing from it; the sand fruit will just be sand-textured balls with slight shape". Final studs, no scale factor.
The pieces are the game's own cactus art, read from `ApprovedPlantArt6` (Prickly Pear: stem green `65,143,69`, fruit attachment) and `AgaveSeedArt45` (Crown Cactus: rib colour and material, ivory spine `235,225,170`) when the plant is built.

| Part | Shape x count | Geometry | Colour / material | g / role |
|---|---|---|---|---|
| Cactus body | Ball x1 | 10.8 x 9.4 x 10.8 standing on the soil | the Prickly Pear's stem green | 0 Stem |
| Pups | Ball x2 | 3.2 x 2.8 x 3.2 and 2.8 x 2.5 x 2.8 at the foot | the same green | 0 Stem |
| Ribs | Cylinder x40 | 8 ribs from the foot to the crown, 5 raised pieces each, bent round the ball | the Crown Cactus' rib | 0 Stem |
| Ivory spines | Wedge x36 | the Crown Cactus' spine x1.5: 3 per rib (24), 6 on the crown, 3 on each pup | the Crown Cactus' ivory | 0 Stem |
| Fruit stem | Cylinder x4 | .5 thick, from inside the body to the fruit | the Prickly Pear's fruit attachment | g Fruit |
| Sand fruit | Ball x4 | 2.4 x 2.0 x 2.2, squashed and tilted; one on each shoulder, between the ribs | **Enum.Material.Sand**, 4 sand tones (226,194,128 ...) | g Fruit |
| Sand fruit lump | Ball x4 | 1.3 x 1.1 x 1.25 on one side, so each fruit is slightly irregular | Sand, a shade darker | g Fruit |
| Sand fruit nub | Ball x4 | .5 x .56 x .5 on top | Sand, 236,210,150 | g Fruit |

- **Total 95 parts** (groups: 79 body, 4 per fruit). Sockets on the body's surface at latitude 46 / 38 deg, FruitCenters .92 outside it, FruitRadii 1.15, Height 10.607, Radius 6.777.
- Nothing goes below the soil. It is a Bush-type plant (`Tree=false`): no collision, so it never blocks planting. `HarvestSpec` drops the connector 'Fruit stem' from a held fruit, which leaves a ball with its lump and nub.

### 5.4 Seeds (loose seed, Bag, Index, reveal)

| Seed | top / bottom / ink | pattern | shape (`SeedSignatures.Shapes`) | signature (`SeedSignatures`) | parts |
|---|---|---|---|---|---|
| Aloe | `4a9e88` / `c3dcc0` / `f2f6e6` | Dots | Pointed | 3 fleshy blue-green blades on top (46,134,114), a flower stalk with 10 graded florets (red at the bottom, yellow at the tip) | 48 |
| Sand Fruit | `d6a35c` / `f6e3b4` / `a8733c` | Specks (the signature adds sand grains) | Round | 14 `Enum.Material.Sand` grains on the skin, a green cactus nub with 5 ivory spines on top, 2 Neon sand sparkles marked `Twinkle` | 58 |
| Fire Pepper | unchanged (`c63929` / `ffb45b` / `ffedac`, Specks, Bean) | | | **new**: 4-leaf green calyx, curled stem, 3 Neon flame wisps on its shoulders marked `Flicker` | 46 |

- R134 floating check: 0 of 48 seeds. Legendary+ parts animate client-side (Twinkle, Flicker); Aloe (Rare) is static. The Fire Pepper signature is unchanged by the art review.

### 5.5 Fire Pepper size bump
- Done in `ApprovedPlantArt.Get` with the same pattern as the existing AncientWorldroot ×1.20 block: positions and sizes ×2, rotations unchanged. Matching catalog metadata ×2 in `Roster149.ApplyPlants`.
- **Uniform ×2, not fruit-only**: the lowest pepper hangs 2.57 studs under its socket at y 2.65. Scaling fruit more than the body buries it in the soil. Lowest point after ×2 is −0.05 (the stem base, as today).
- **Prism Pepper must not change**: same meshes, different module.
- Baked meshes take `Size`, so no new mesh is needed.

### 5.6 Growth, effects, budgets
- **Growth** is generic (`PlantGrowth`): both new plants use the "Bush" profile (leaves / body fade in, spikes and fruits grow from their sockets). No per-stage art is needed.
- **Effects** come automatically from plant `Rarity` (PlantEffects): Sand Fruit and Moon Melon get the Legendary aura (Moon also keeps its "Moon" motes); Fire Pepper gets the Mythic aura plus Lava "Ember" motes; Aloe gets nothing (Rare, and Desert has no profile, like Prickly Pear).
  Each aura is a `Highlight` and Roblox draws 31 at most, so GardenVisuals hands its four effect slots out by rarity rank first, then distance (owner decision 5).
- **Budgets**: Aloe ≤ 130 parts (127); Sand Fruit cactus ≤ 100 (95); Fire Pepper 34 (unchanged). PlantDetailPlanner screen budget is 1400.
- **To eyeball in Studio** (cannot be checked here): aloe teeth and spots orientation, the cactus' ribs and spines, the Sand material's look and the fruit colour against Desert sand, the ×2 Fire Pepper beside neighbouring plants (it may overlap them; placement spacing is fixed and saves are not affected).

---

## 6. Implementation

### 6.1 Files (in this order). The shipped code is in these files (Appendix A).

| File | Change |
|---|---|
| **NEW** `src/ReplicatedStorage/Roster149.lua` | Constants (`New`, `Promote`) plus `ApplyPlants` / `ApplyBalance`. No requires at load. |
| **NEW** `src/ReplicatedStorage/DesertPlantArt149.lua` | Aloe and round-cactus art. Reads the existing cactus pieces from `ApprovedPlantArt6` / `AgaveSeedArt45` when the plant is built (optional requires, with fallback values). |
| `SeedPackRules.lua` | (1) After the `Rules.SeedDesigns={...}` literal (before `-- V139: preserve…`), require Roster149 and append its 2 designs. (2) After the R37 rarity loop, the promotions, Fire Pepper's design text and `AloeSeed.name='Aloe Sprout'`. (3) **Between the R137 block and the R147 Verity block**: the R149 odds block (banked pools without the new and the promoted seeds). Verity must stay outermost. (4) `Rules.OddsRows`: pack rows by rarity rank, then name. |
| `PlantCatalog.lua` | Last line before `return Catalog`, **after** `GrowthPace125.Apply`: `require(script.Parent.Roster149).ApplyPlants(Catalog)`. |
| `GrowthPace125.lua` | Comment only: the roster plants are kept out of the pacing by the ORDER in `PlantCatalog` (there is no `Roster149` exemption). |
| `BalanceValues81.lua` | Before `T.Version=91`: `require(script.Parent.Roster149).ApplyBalance(T)`. Do **not** add the new ids to `T.SeedValues`: the PlantCatalog loop asserts that a plant exists at that point. |
| `ApprovedPlantArt.lua` | Require `DesertPlantArt149` and route it in `Has` and `Get` (right after Verity); add the FirePepper x2 block next to AncientWorldroot's. |
| `SeedSignatures.lua` | Before `function S.Get`: the 2 shapes and 3 signatures. |
| `Config.lua` | Base `Validate`: allow Desert 10 (`#seedCatalog == 8 or (stage == 2 and #seedCatalog == 10)`). Last block: `Config.Version='V151 R149'` (or the release's tag) and **`ProfileVersion=22`** (one more than the last shipped value). |
| `PremiumProgress.lua` | `IndexProgress(player,stage,beforeR149)` (used once, to record the old milestones), `SettleOldRoster148`, `IndexMilestone` (live OR the saved flag), `Decode` (sanitises `OldRoster148`; a new player starts with `{}`), `PublishPremium` (`IndexOldHalf<i>` / `IndexOldFull<i>`). `BiomeComplete` and the claims use `IndexMilestone`. |
| `PlayerDataService.lua` | `Load`: `SettleOldRoster148` before the first `PublishPremium` (and the profile is saved when it recorded something). |
| `ChestIndex.client.lua` | `milestones(stage)` = live count OR the published `IndexOldHalf<stage>` / `IndexOldFull<stage>`, used by the reward dots and the half/completion buttons; those attributes are watched. Card order is already by rarity (`LayoutOrder = rank*10000 + index`). |
| `PlantEffects.lua`, `GardenVisuals.client.lua` | `Effects.GrantSlots`: effect slots by rarity rank, then distance. |
| `ChestService.lua`, `OwnerUpdateCommands82.lua` | Hold tooltip and `odds` rows through `PackRules.OddsRows`. |
| `RarePackTests.lua` | Selector `roster` (A.8). |
| `StudioTestHelp.lua` | Append to the `/test rarepacks` row: `; rarepacks roster four TEST packs that reveal Fire Pepper, Moon Melon, Aloe and Sand Fruit.` Keep the `rarepacks verity` text. |
| `docs/COMMANDS.md`, release notes, `src/MANIFEST.tsv` | Command row; notes (shut down all servers); 2 ModuleScript rows: `ReplicatedStorage/Roster149` and `ReplicatedStorage/DesertPlantArt149`. The installer adds these 2 new ModuleScripts. |

**No change** to: PackOdds81/112/137, BalanceRules, EconomyBalance90 (its Fire Pepper/Moon Melon entries are superseded after pacing), FruitOfHour, MarketLayout, VoidPackOdds85, VerityPackOdds, MysteryPackRules, DailyProgress, PlantVisuals, PlantGrowth, GardenDisplayNames.

### 6.2 New tests: `docs/proposals/R148/tests/`

**`run_roster.sh`**:
- Extracts the base with `git -C "$REPO" archive 9c9797e src | tar -x -C "$OUT/base"`.
- Copies `treadmill_bonus_R123/tests/mkbundle.py` + `world.luau` into the same relative layout under `$OUT/base` and under the checkout, and bundles both.
- Runs `dump_roster.luau` on both and diffs the output with `check_roster_diff.py`. **Only these lines may differ**:
  - `PLANT AloeSeed` (name only; `BASE` = the commit before the change, default `cba4032`, not `9c9797e`: R148 had moved on)
  - `PLANT FirePepperSeed` and `PLANT MoonflowerSeed`
  - added `PLANT DesertAloeSeed` and `PLANT SandFruitSeed`
  - `VOID 149` (the base reads 149 as unknown)
  - `ODDS` and `ROLL` lines of **Lava (4) and Crystal (5) only** (owner decision 1); every other line, for every banked version (none / 0 / 81 / 112 / 137) and variant (Small / Standard / Grand / Pack01-06), must be identical.
    In the Lava / Crystal rows only the promoted seed (it must be gone) and the seeds of its old Rare tier may differ, they must absorb exactly its share and never lose any; no banked roll ever gives a new or a promoted seed
  - `FOH` (51 → 53)
- Then runs the two tests below.

**`test_roster.luau`** (server world, real modules):
1. **Constants and catalog**:
   - `#SeedDesigns==54`, with Verity last.
   - The 2 specs: stage/SaveStage 2, index 9/10, rarities, colours.
   - Retired ids are still retired and still decode (`GetSeedById`); `AloeSeed` shows as "Aloe Sprout Seed".
   - `GetRarity`: Fire Pepper Mythic, Moon Melon Legendary; `PromotedInR149` lists them, there is no per-version rarity table.
   - `SeedCatalogByStage[2]` has 10 entries; `[2][9]`/`[2][10]` are the new ids.
   - `Config.Validate()` passes.
   - `ObtainablePool(2)` has 7 seeds; pools 4 and 5 have the same membership as before.
2. **Plants**:
   - The exact §2/§3 numbers, plus `Name`, `HarvestName`, `Tree`, `Mode`, `FruitCount`, `Roster149=true` (a marker), no pacing marks, and `Pace.Exempt` ignoring the flag.
   - Fire Pepper Height/Radius/Sockets/FruitCenters/FruitRadii are exactly ×2 of the base (base: H 6.3090, R 3.1725, socket 4 (1.34, 2.65, −1.10), radius 1.6046).
   - New plants' geometry equals `DesertPlantArt149.Get`.
   - All values are ≤ 9e10 and integers; seconds ≤ 86400.
   - Income ladders of §2/§3 are strictly increasing.
3. **Odds**:
   - Every v149 row of the §4 tables (1e-9); stages 1/3/6/7 at 149 equal 137.
   - `OddsVersion==149`, `ValidOddsVersion(149)`, and a v150 pack decodes as nil.
   - Void/Verity/Mech identical across nil/0/81/112/137/149; Void 149 = Void 137.
   - Banked Lava / Crystal packs (versions 0 / 81 / 112 / 137): the pinned numbers above, no Fire Pepper / Moon Melon in any of 4 versions x 9 variants x 4 luck x 2 boost rows, no promoted or new seed at any of 2001 draws.
   - Hold tooltip via the real `ChestService:_holdPack` rows: a 149 Lava pack has "Fire Pepper Seed: 1/800"; a banked 137 (or no-version) Lava pack has no Fire Pepper row; banked 137 / 112 Crystal packs have no Moon Melon row; a 137 Desert pack has no Aloe or Sand Fruit row;
     the rows (and the `odds` command's) are sorted by rarity rank, then name.
   - 1,000,000 `math.random` rolls:
     - 149 Desert Pack01: Aloe 12.5 ± 0.2%, Sand Fruit 1.11 ± 0.05%.
     - 137 Lava Pack01: no Fire Pepper, Ember 49.58%; 137 Crystal Pack01: no Moon Melon, Amethyst 49.94%.
     - 200,000 legacy Desert rolls at luck 5e7 never give a new seed.
4. **Save / load / gift** (real PlayerDataService):
   - A 149 pack keeps 149 through save/load and gift.
   - New seeds in the Bag survive save/load/gift.
   - Plant and harvest both new seeds: fruit count, values, regrow.
   - A Fire Pepper crop saved under the old catalog (4 FruitStates, old ReadyAt) still loads, validates and harvests at the new value.
   - ProfileVersion is 22, and a version-23 save is refused unchanged.
5. **Index**:
   - SeedCatalog remote entries (Stage 2, SeedIndex 9/10, Rarity, BaseChance 12.5 / 1.11111).
   - IndexFirst on the first open and IndexRepeat on a repeat for all 4 ids.
   - `IndexMilestone`, with profiles saved BEFORE the update and loaded now (so the load records the old milestones):
     - old 2/5 → nothing, and finding the rest of the old five afterwards gives no old-roster fallback (halfway at 8 of 14, complete only with all seven);
     - old 3/5 (6 of 10 points) → half only (kept), not complete even with the old five found later;
     - old 5/5 → full, both rewards claim once each (Gems 10 and 20), a second claim answers "ALREADY CLAIMED", finding the new seeds pays nothing more;
     - a player who claimed before cannot claim again;
     - a NEW player needs all seven (5 old seeds = halfway, not complete);
     - the record is saved and survives a reload; `Decode` sanitises it;
     - Lava/Crystal milestones are unchanged.
6. **Commands**:
   - `rarepacks roster` gives 4 TEST packs revealing Mythic / Legendary / Rare / Legendary.
   - The help row text is right.
   - `seed DesertAloeSeed` and `seeds desert` include the new seeds.
   - `odds desert rare` shows "Aloe Seed: 1/2.5".
7. **Fruit of the Hour**: 53 candidates including both new ones, never Verity.

**`test_roster_art.luau`** (client world `inventory_R113`):
- The new plants build in every mode: ripe; growing at body .1/.5/.9; one harvest item per group; `Supports` with no collision (neither is a tree).
- 127 and 95 specs; nothing below y -0.05; groups 1..N present; sockets, centres, Height and Radius equal the catalog; the cactus uses the existing cactus pieces and Sand fruits; the Aloe has 24 graded florets per spike.
- Fire Pepper art is exactly ×2 of the base's `ApprovedPlantArt` (git show `9c9797e`, like R147's art test) for every spec: z and position ×2, rotation equal.
- Prism Pepper, Moon Melon, Prickly Pear, Dune Lotus, Apple and Lava Lotus build identically to the base (fingerprint like `test_verity_art`).
- Seeds: the 3 signatures build (48 / 58 / 46 parts); `SeedAnim` is Twinkle x2 on Sand Fruit and Flicker x3 on Fire Pepper.
- `PlantEffects` aura: on Sand Fruit, Moon Melon and Fire Pepper; none on Aloe.
- The Index Desert tab shows 7 cards in rarity order.
- ChestIndex parity: without the server's `IndexOldHalf2` / `IndexOldFull2` flags five of seven is halfway and not complete; with them an old completer sees both reward dots and lit claim buttons, and the flags are watched.
- Effect slots: `Effects.GrantSlots` on synthetic entries, and the real GardenVisuals scheduler on a scene of five near Legendary plants plus a King, a Cosmic and a Secret plant: the three high ranks always get their aura, the fourth slot goes to the nearest
  Legendary plant, four Highlights in all (limit 31), two effect plants and no Highlight in low mode, none when off, and a late King takes the Legendary plant's slot.

### 6.3 Existing suites that change
Each edit below was checked on the prototype.
- **`R147/tests/test_verity_pack.luau`** (170 checks, 9 change):
  - L144: `#Rules.SeedDesigns==54` ("47 biome + 6 Mech + Verity").
  - L167: the `changed` list sorted must equal exactly `FirePepperSeed,MoonflowerSeed`.
  - L169: `nPlants==65`.
  - L173: `#cands==53` and `plain` = `FohBefore` plus `DesertAloeSeed,SandFruitSeed` (sorted).
  - L321, L360, L362, L368, L376: the converted Verity pack's version `137` → `Rules.OddsVersion`. Leave the explicit `OddsVersion=137` AddChest calls alone.
- **`R137/tests/test_packs.luau`** (41 checks, 0 failures after these edits):
  - `tiers(odds)` reads today's rarity; all 42 rows of the approved model are compared at version 137 and at 112 (Lava and Crystal included: the tier-mates absorb the promoted seed's share, so every tier's chance is unchanged).
  - L44: `Rules.OddsVersion==149`.
  - L47 and L51: pass version `137` explicitly; the 1/800 and 1/150 checks read new packs (no version) and a new check says banked 137 packs have no Fire Pepper / Moon Melon.
  - L78: also `Rules.ValidOddsVersion(149)`.
- **`R147/tests/test_verity_art.luau`** L377: remove `'FirePepperSeed'` from the "identical before/after" list (its ×2 is checked in `test_roster_art`).
- **`R134/tests/test_seeds.luau`**: passes unchanged (69 checks; 0 of 48 floating).
- **Rerun everything else**, as in R147's notes:
  - R140 daily (it checks `Rules.OddsVersion` dynamically) and R139/R138 starter.
  - R147 mystery / keyboard / verity / UI.
  - R136, R135, R132 fruit-of-hour, treadmill bonus, giving, shop, borders, inventory, holes.

### 6.4 Save and rollout risks
- **ProfileVersion 22 is required** (D5). **Shut down all servers on publish**, as in R147. While old servers still run, a player whose save is already 22 is kicked from them with "requires a newer server", and their data is unchanged.
- **Undo** after players have saved: old code refuses version-22 saves until R149 is reinstalled. This is the same caveat as R147; put it in the notes.
- Gifts staged by a new server and opened on an old one could lose OddsVersion 149 (it becomes legacy odds). Shutting down all servers removes this case.
- **FruitCount invariant** (D2) and **pacing order** (D3) are the two ways to corrupt data or the economy. Both are covered by tests §6.2 (2) and (4).
- **Fruit of the Hour** reshuffles its hourly schedule once at the update (the pick depends on the list length). This is cosmetic.
- **No windfall** from banked Lava/Crystal packs (owner decision 1): they cannot roll the promoted seeds and their tier-mates absorb the share (table at the top). To change it: `Roster149.Promote` is what `SeedPackRules` takes out of the banked pools.
- **Index**: no duplicate claims, nothing lost (D6, owner decision 4). Desert's Index shows 7 entries; players who had already reached a milestone keep it (a saved flag, recorded on the first load), and players who already claimed see their claim as done.

---

## Appendix A: where the code is

The prototype listings that stood here (the first draft of the odds scope, the palm, the Index fallback) were superseded by the review decisions at the top and are not repeated: the shipped code is the reference.

| What | File |
|---|---|
| Constants, plant numbers, Index cash, `ApplyPlants`, `ApplyBalance` | `src/ReplicatedStorage/Roster149.lua` |
| Aloe and round-cactus art | `src/ReplicatedStorage/DesertPlantArt149.lua` |
| Odds scope for banked packs, `OddsRows`, designs, rarities | `src/ReplicatedStorage/SeedPackRules.lua` (the R148 blocks) |
| Fire Pepper x2 art, routing | `src/ReplicatedStorage/ApprovedPlantArt.lua` |
| Seed signatures | `src/ReplicatedStorage/SeedSignatures.lua` |
| Plant numbers after the pacing | `src/ReplicatedStorage/PlantCatalog.lua`, `GrowthPace125.lua` |
| Index milestones (live OR the saved old-roster flag), `OldRoster148` | `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua`, `PlayerDataService.lua` |
| Client Index | `src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua` |
| Effect slots by rarity | `src/ReplicatedStorage/PlantEffects.lua` (`GrantSlots`), `GardenVisuals.client.lua` |
| Sorted tooltip and `odds` rows | `ChestService.lua`, `OwnerUpdateCommands82.lua` |
| Test pack `roster` | `RarePackTests.lua` |
| Tests, the regression dump and the preview | `docs/proposals/R148/tests/`, `docs/proposals/R148/preview/`, `docs/proposals/R148/seeds_new.png` |
