# Seed roster change (R149): Desert Rare + Legendary, Lava Mythic, Crystal Legendary

Design only. Base: `9c9797e`. Everything below was **prototyped on the Roblox mock against `9c9797e`** (scratch copy,
not committed) with the real modules:
- `Config.Validate` passes.
- Every banked-pack odds row is byte-identical to the base: stages 1–7 × 9 variants × OddsVersion 0/81/112/137 ×
  6 luck levels × boost none/2. Void, Mech and Verity odds are identical for every version.
- The other 60 old plants are identical to the base (Seconds, Regrow, Value, Rarity, geometry).
- The new seeds build with 0 of 48 floating (R134 checker).
- The R137 and R147 suites pass after the test edits in §6.3.
- 1M `math.random` rolls with v149 packs match the §4 tables: Aloe 12.56%, Sand Fruit 1.116%, Fire Pepper 0.125%,
  Moon Melon 0.663%. (Plan default, superseded by owner decision 1: a banked v137 Lava pack now gives Fire Pepper 0.125%, labelled Mythic.)

The reference code in Appendix A is the code that was run.

Owner request: Lava Fire Pepper becomes Mythic (bigger peppers, more cash). Crystal Moon Melon becomes Legendary. Desert
gets a Legendary "Sand Fruit" palm and a Rare "Aloe". Check the other biomes for gaps.

## Owner decisions and implementation notes (shipped as R148). Where they differ they OVERRIDE the plan text below

The release ships as **R148**; the identifiers keep the plan's "149" (`OddsVersion` 149, `Roster149`, `DesertPlantArt149`, `NewInR149`, ...).

**1. No windfall for banked packs.** `Roster149.RarityBefore = {}` (the plan's owner option). A pack banked before the update rolls Fire Pepper /
Moon Melon at their NEW tiers (Mythic / Legendary), exactly like a new pack. Banked Desert packs still never give the Aloe or the Sand Fruit.
Checked against the base commit by `tests/run_roster.sh` (every odds version none / 81 / 112 / 137, 9 pack variants, 6 luck levels, with and without the 2x boost):
- **Byte-identical**: every Forest, Desert, Snow, Jungle and Storm pack (2,160 of 3,024 odds rows), every Void / Mech / Verity row, every seeded roll of those biomes.
- **Changed**: only Lava and Crystal packs (864 rows). Fire Pepper / Moon Melon now sit in their new tier, so the seeds that shared their old Rare tier split it
  between two instead of three, and a Mythic pack's floor is now the Legendary. A banked 137 pack (every pack made since R137) now rolls exactly like a new 149 pack
  (same roster there). Percent per seed, boots x1, before -> after, Common / Uncommon / Rare / Epic / Legendary / Mythic pack:

  | Banked 137 pack | Common | Uncommon | Rare | Epic | Legendary | Mythic |
  |---|---|---|---|---|---|---|
  | Lava: Fire Pepper | 33.05 -> 0.125 | 32.77 -> 0.3125 | 32.12 -> 0.833 | 28.82 -> 4 | 27.80 -> 10 | 0 -> 16 |
  | Lava: Ember Pumpkin / Ash Tomato (each) | 33.05 -> 49.52 | 32.77 -> 49.00 | 32.12 -> 47.77 | 28.82 -> 41.23 | 27.80 -> 36.70 | 0 |
  | Lava: Lava Lotus | 0.833 (same) | 1.667 (same) | 3.571 (same) | 13.33 (same) | 16 (same) | 97.98 -> 81.98 |
  | Crystal: Moon Melon | 33.30 -> 0.667 | 33.24 -> 1.333 | 33.09 -> 2.857 | 32.15 -> 11.11 | 30.35 -> 13.33 | 28.22 -> 84.65 |
  | Crystal: Amethyst Grape / Prism Pepper (each) | 33.30 -> 49.61 | 33.24 -> 49.20 | 33.09 -> 48.21 | 32.15 -> 42.68 | 30.35 -> 38.86 | 28.22 -> 0 |

  In 137 packs only the promoted seed, its old tier-mates and (Mythic pack) Lava Lotus move; in 112 packs the Mythic tier moves too (Diamond Vine in a Common Crystal pack 3.83 -> 0.5);
  the Secret / Cosmic / King seeds do not move in either. Banked 112 / 81 / no-version packs use their own older tier math and re-split
  the same way (Fire Pepper in a Common Lava pack: 32.2 -> 0.5 (v112), 31.3 -> 1.3 (v81), 25 -> 5.9 (none)); in those old versions the other seeds of the
  biome also move a little because their weights are normalised (e.g. Obsidian Maw in a Common v81 Lava pack 1.8 -> 0.5).
- The hold tooltip of a banked 137 Lava pack reads "Fire Pepper Seed: 1/800" (it read 1/3 under the plan's default); `Rules.GetRarity` needs no pre-R149 mapping.

**2. The Rare Aloe out-earns the Uncommon Prickly Pear.** Aloe `Value = 10,000,000` (the plan's rule alone gave 7,680,000; 9,900,000 is the least that passes).
Derived: 2.04e8 per hour (Prickly Pear 2.00e8, Iceberry 2.73e8, Sand Fruit 2.50e8: every ladder below still increases), Index cash 10,000,000 first / 2,000,000 repeat.

**3. Found while implementing** (not owner decisions):
- The Sand Fruit's bunch stalks start inside the crown heart and end inside their fruits (the plan's art left every bunch's fruit 0.09 studs off its stalk, which the
  R134 check_floating run on the plant scene flagged). Fruit centres are at y 9.82 instead of 9.59; Height / Radius are unchanged.
- `ChestIndex.client.lua` had moved on since the plan was written (`rewardState`); A.7 is applied to the current file.
- Existing tests that needed edits beyond section 6.3: `R137/tests/test_packs.luau` (Lava / Crystal rows are no longer the approved 137 model's; the Desert rows are
  checked at version 137 explicitly), `R137/tests/test_index.luau` (header total 94), `polish_R124/tests/test_growth.luau` (loads the catalog without the roster change,
  because the roster plants are written after the pacing and exempt from it) and `R147/tests/test_verity_art.luau`.
- The Aloe seed is the tallest seed in the game (3.34 studs high; the next is 3.12): a pointed body plus its flower spike.
- `docs/proposals/R148/tests/` (run_roster.sh, dump_roster.luau, check_roster_diff.py, test_roster.luau, test_roster_art.luau) and `preview/` + `seeds_new.png` hold the tests and the preview.

---

## 0. Decisions in one screen

| # | Decision |
|---|---|
| D1 | **New ids** `DesertAloeSeed` (Rare, name "Aloe") and `SandFruitSeed` (Legendary, name "Sand Fruit") in Desert save slots **9 and 10**. Slots 1–8 keep their ids, the retired ones included. Retired `AloeSeed` / `DesertRoseSeed` / `AgaveSeed` / `SunKingPalmSeed` are never reused. |
| D2 | **Promotions** `FirePepperSeed` → Mythic and `MoonflowerSeed` → Legendary. Ids, names and **FruitCount stay** (4 and 2). FruitCount must stay: a saved crop's `FruitStates` are validated against it, and changing it makes `DecodeGarden` reject the player's whole garden ("Invalid plant traits"). |
| D3 | All plant numbers are written **after** `GrowthPace125.Apply`, in a new `Roster149.ApplyPlants`, and are flagged `Roster149=true` (exempt from pacing). **Do not** put the promoted or new plants through the pacing. Moon Melon is the Rare group's slowest raw entry (840 s → 1800 s). Taking it out of that group, or adding seeds outside the group's raw range, re-spreads the time and value of **every** Rare/Legendary/Mythic plant in the game. |
| D4 | **New `OddsVersion` 149** for every pack made from now on. It uses PackOdds137's frozen numbers over today's roster. **Packs already banked keep their exact per-seed odds** (owner rule since R112/R137): they roll the roster they were made with. That means no Aloe or Sand Fruit. ~~Fire Pepper / Moon Melon stay in their Rare tier~~ (owner decision 1: they roll at their NEW tiers). The seed they hand out is today's seed, so the reveal shows the new rarity. No PackOdds table changes. |
| D5 | **ProfileVersion 21 → 22.** An old server would read OddsVersion 149 as invalid → `nil` and re-save the pack as a legacy-odds pack for good. The R147 precedent, where Verity packs became Standard packs on an old server, is the same failure. |
| D6 | **Index safety**: claimed rewards stay claimed (no duplicates). Desert grows from 5 to 7 entries, so a halfway or completion milestone reached with the **old 5-seed roster** stays claimable on both server and client, and nothing is taken away. |
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

Side effect, and an improvement: R137's "missing floor steps down" quirk goes away. Desert Epic/Legendary packs now
floor at Rare (Aloe) instead of Prickly Pear, and the Desert, Lava and Crystal Mythic packs floor at their Legendary.

Final roster. **Bold** = changed. Ids in brackets; slot = save stage/index.

| Biome (stage) | Common | Uncommon | Rare | Legendary | Mythic | Secret | Cosmic | King |
|---|---|---|---|---|---|---|---|---|
| Forest (1) | Watermelon | Blueberry | Apple, Mooncap | Sunflower | Elderbloom | – | – | – |
| Jungle (6) | Cocoa | Pineapple | Venom Vine, Lantern Fern | Tiger Orchid | Ancient Worldroot | – | – | – |
| Desert (2) | – | Prickly Pear | **Aloe** [DesertAloeSeed, 2/9] | **Sand Fruit** [SandFruitSeed, 2/10] | Dune Lotus | Dune Starfruit (slot 5/4) | Mirage Fig | Solar Starfruit |
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
- **Banked packs** (made before the update): owner decision 1 (top of this file). They roll Fire Pepper / Moon Melon at their NEW tiers (Fire Pepper 1/800 in a Common Lava pack, no windfall);
  the plan's default (~1/3, handed out as a Mythic or Legendary) is not used. Banked Desert packs never give the new seeds.

---

## 3. New seeds: full data

| | **Aloe** | **Sand Fruit** |
|---|---|---|
| Id / slot | `DesertAloeSeed`, Desert save stage 2, index 9 | `SandFruitSeed`, stage 2, index 10 |
| Rarity / rank | Rare / 3 | Legendary / 4 |
| Seed name (catalog) | "Aloe" ("Aloe Seed") | "Sand Fruit" ("Sand Fruit Seed") |
| Plant `Name` / `HarvestName` | Aloe / Aloe bloom (UI: "Aloe Bloom") | Sand Fruit / Sand fruit |
| Plant | blue-green aloe rosette with 3 red-orange flower spikes. **Harvest = one flower spike**; the rosette stays and the spike regrows | leaning desert palm, 8 arching fronds, 4 bunches of 3 sand-gold fruits. **Harvest = one bunch** |
| Tree / Mode | false / repeat | **true** (solid trunk, climbable like Apple/Cocoa) / repeat |
| FruitCount | 3 | 4 |
| First grow / regrow | 960 s / 530 s | 2760 s / 1520 s |
| Value per fruit | **10,000,000** (owner; the rule gave 7,680,000) | 26,400,000 |
| Income / h | **2.04e8** (the rule: 1.56e8) | 2.50e8 |
| Index cash first / repeat | **10,000,000 / 2,000,000** | 26,400,000 / 5,280,000 |
| Art bounds (Height / Radius) | 8.243 / 5.211 | 14.182 / 7.252 |
| Spec parts / detail cost | 96 / 97 | 99 / 100 |
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
- **Banked world packs** (OddsVersion 137 / 112 / 81 / none) roll inside a "pre-R149 roster" scope (Appendix A.1):
  - the new seeds are filtered out of `ObtainablePool`;
  - `GetRarity` returns the plan's pre-R149 rarity (Rare) for Fire Pepper / Moon Melon only while `Roster149.RarityBefore` lists them; it is EMPTY (owner decision 1), so they keep their new tiers;
  - the rarity the roll returns is the seed's rarity today (so the reveal and the record say Mythic/Legendary).

**Hold tooltip** (`ChestService:_holdPack`, `record.OddsVersion or 0`) needs no change and stays correct:
- A 149 Lava pack shows Fire Pepper 1/800.
- A banked 137 Lava pack shows Fire Pepper 1/800 (owner decision 1; it would have been 1/3) — what it will really roll.
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

Desert before (137): Prickly Pear 99.8232 / 99.5581 / 98.8283 / 94.798 / 86.894 / 77.98. The rest is as above.

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
- Built at scale 1 and multiplied by `A.AloeScale = 1.5`. Numbers below are before ×1.5.
- Leaf = 2 Wedges forming a pointed fleshy blade: thickness 0.36–0.42 along the leaf normal, triangular outline.

| Part | Shape × count | Geometry | Colour (RGB) | g / role |
|---|---|---|---|---|
| Rosette heart | Ball ×1 | 1.1×0.7×1.1 at y .35 | 98,150,128 | 0 Stem |
| Outer leaves | 7 × Wedge pair | len 3.4, width .9, thick .42; base r .35, y .25; 28° above level; yaw k·51.4° | 88,140,122 / 100,154,134 | 0 Leaf |
| Middle leaves | 6 × pair | 3.0 / .8 / .40; r .25, y .35; 48°; yaw 25.7°+k·60° | 100,156,138 / 112,168,148 | 0 Leaf |
| Inner leaves | 4 × pair | 2.4 / .65 / .36; r .12, y .45; 68°; yaw 45°+k·90° | 116,172,152 / 128,184,160 | 0 Leaf |
| Leaf spots | Ball ×14 | 2 per outer leaf, on the upper face at 30% / 55% of length; .04×.24×.15 | 204,228,214 | 0 Leaf |
| Leaf teeth | thin Ball spike ×14 | 1 per outer-leaf margin at 50%, leaning to the tip; .06×.24×.06 | 176,120,96 | 0 Leaf |
| Flower stalk | Cylinder ×3 | d .16; length 4.6 / 4.0 / 3.5; socket r .15, y .7 at yaw 15° / 135° / 255°; tilted 10° outward | 126,146,100 | g Fruit |
| Florets | Ball ×27 | 9 per spike on its top 40%, spiral 137.5°, hanging 30° below level; .16×.42×.16 | lower 4: 236,96,48 · next 3: 250,150,60 · top 2: 240,196,92 | g Fruit |
| Bud tip | Ball ×3 | .18×.30×.18 at the stalk tip | 226,206,110 | g Fruit |

- **Total 96 parts.** Sockets sit at the heart (y 1.05 after ×1.5).
- FruitCenter = 80% up the stalk; FruitRadius = 0.3 × stalk length (2.07 / 1.80 / 1.575).
- The stalk is role **Fruit**, not Stem. `HarvestSpec` drops Stem parts from held items, which would leave floating florets.

### 5.3 Sand Fruit palm (`DesertPlantArt149`, Legendary)
Final studs, no scale factor.

| Part | Shape × count | Geometry | Colour | g / role |
|---|---|---|---|---|
| Root flare | Cylinder ×1 | d 2.0, y 0–0.6 | 128,94,58 Wood | 0 Stem |
| Root toes | Wedge ×3 | .35×.5×.9 at r 1.05, yaw 30° / 150° / 270° | 120,88,54 Wood | 0 Stem |
| Trunk | Cylinder ×5 | through (x,y) (0,0)→(.05,2.2)→(.2,4.4)→(.45,6.6)→(.75,8.8)→(1.1,11.0), z 0, d 1.45→1.05 | alternating 150,110,70 / 136,99,62 Wood | 0 Stem |
| Trunk rings | Cylinder ×5 | .22 long at each joint, d +.25 | 112,80,50 Wood | 0 Stem |
| Crown heart | Ball ×1 | 1.7×1.3×1.7 at (1.1, 11.4, 0) | 108,130,60 | 0 Leaf |
| Dry frond boots | 4 × Wedge pair | len 1.1, w .55, t .18, pointing out and down at yaw 45°+k·90° | 170,130,80 / 158,120,72 | 0 Leaf |
| Fronds | 8 × (rachis Cylinder + inner pair + outer pair) = 40 | yaw k·45° (+6° on odd k); rachis d .14, len 3.0; inner blade len 3.0, w 1.5, t .12, rising 25° (18° on odd k); outer blade len 3.2, w 1.2, drooping −25° | inner 86,150,72 / 98,164,80 · tips 98,160,76 / 124,160,82 · rachis 120,150,70 | 0 Leaf |
| Young fronds | 2 × pair | len 2.6, w 1.0, 65° up, yaw 90° / 270° | 112,176,86 / 124,186,94 | 0 Leaf |
| Bunch stalk | Cylinder ×4 | d .18, len .9; from socket = crown + out·.95 − (0,.6,0), at yaw 22.5°+k·90° | 140,110,60 | g Fruit |
| Sand fruits | **Sphere** ×12 | Ø1.05, 3 per bunch, .42 around the bunch centre | 222,182,112 / 214,170,98 / 230,192,124 | g Fruit |
| Dune-ripple bands | Ball ×12 | 1.1×.16×1.1, slightly tilted, on each fruit | 184,138,78 | g Fruit |
| Sand sparkle | Ball ×4 | Ø.18, **Neon** | 255,236,170 | g Fruit |

- **Total 99 parts.** Sockets at y 10.8, FruitCenters at y 9.59, FruitRadii 1.05.
- Fruits hang under the crown, clear of the fronds. Nothing goes below the soil (only the trunk base touches y 0).
- Trunk collision parts (non-Leaf) cost 14, within `Supports`' 24 budget.

### 5.4 Seeds (loose seed, Bag, Index, reveal)

| Seed | top / bottom / ink | pattern | shape (`SeedSignatures.Shapes`) | signature (`SeedSignatures`) | parts |
|---|---|---|---|---|---|
| Aloe | `5d9f8c` / `c3dcc0` / `f2f6e6` | Dots | Pointed | 3 fleshy blue-green blades on top (88,150,128), a flower stalk with 4 red-orange florets | 42 |
| Sand Fruit | `d6a35c` / `f6e3b4` / `a8733c` | Stripes (signature overrides it to None) | Round | 3 dune-ripple lines on the skin (ink), a tiny palm crown (trunk plus 5 fronds), 2 Neon sand sparkles marked `Twinkle` | 69 |
| Fire Pepper | unchanged (`c63929` / `ffb45b` / `ffedac`, Specks, Bean) | | | **new**: 4-leaf green calyx, curled stem, 3 Neon flame wisps on its shoulders marked `Flicker` | 46 |

- R134 floating check: 0 of 48 seeds. Legendary+ parts animate client-side (Twinkle, Flicker); Aloe (Rare) is static.

### 5.5 Fire Pepper size bump
- Done in `ApprovedPlantArt.Get` with the same pattern as the existing AncientWorldroot ×1.20 block: positions and sizes ×2, rotations unchanged. Matching catalog metadata ×2 in `Roster149.ApplyPlants`.
- **Uniform ×2, not fruit-only**: the lowest pepper hangs 2.57 studs under its socket at y 2.65. Scaling fruit more than the body buries it in the soil. Lowest point after ×2 is −0.05 (the stem base, as today).
- **Prism Pepper must not change**: same meshes, different module.
- Baked meshes take `Size`, so no new mesh is needed.

### 5.6 Growth, effects, budgets
- **Growth** is generic (`PlantGrowth`): Aloe uses the "Bush" profile (leaves fade in, spikes grow from their sockets); the palm uses "Tree" (trunk grows, bunches grow from sockets). No per-stage art is needed.
- **Effects** come automatically from plant `Rarity` (PlantEffects): Sand Fruit and Moon Melon get the Legendary aura (Moon also keeps its "Moon" motes); Fire Pepper gets the Mythic aura plus Lava "Ember" motes; Aloe gets nothing (Rare, and Desert has no profile, like Prickly Pear).
- **Budgets**: Aloe ≤ 100 parts (96); palm ≤ 110 (99); Fire Pepper 34 (unchanged). PlantDetailPlanner screen budget is 1400.
- **To eyeball in Studio** (cannot be checked here): aloe teeth and spots orientation, frond droop, sand-fruit colour against Desert sand, the ×2 Fire Pepper beside neighbouring plants (it may overlap them; placement spacing is fixed and saves are not affected).

---

## 6. Implementation

### 6.1 Files (in this order). Exact code is in Appendix A.

| File | Change |
|---|---|
| **NEW** `src/ReplicatedStorage/Roster149.lua` | Constants plus `ApplyPlants` / `ApplyBalance` (A.2). No requires at load. |
| **NEW** `src/ReplicatedStorage/DesertPlantArt149.lua` | Aloe and palm art (A.3). No requires. |
| `SeedPackRules.lua` | (1) After the `Rules.SeedDesigns={...}` literal (before `-- V139: preserve…`), require Roster149 and append its 2 designs. (2) After the R37 rarity loop, the promotions, Fire Pepper's design text and `AloeSeed.name='Aloe Sprout'`. (3) **Between the R137 block and the R147 Verity block**: the R149 odds block (A.1). Verity must stay outermost. |
| `PlantCatalog.lua` | Last line before `return Catalog`, **after** `GrowthPace125.Apply`: `require(script.Parent.Roster149).ApplyPlants(Catalog)`. |
| `GrowthPace125.lua` | `Exempt`: add `or def.Roster149==true`. |
| `BalanceValues81.lua` | Before `T.Version=91`: `require(script.Parent.Roster149).ApplyBalance(T)`. Do **not** add the new ids to `T.SeedValues`: the PlantCatalog loop asserts that a plant exists at that point. |
| `ApprovedPlantArt.lua` | Require `DesertPlantArt149` and route it in `Has` and `Get` (right after Verity); add the FirePepper ×2 block next to AncientWorldroot's (A.4). |
| `SeedSignatures.lua` | Before `function S.Get`: the 2 shapes and 3 signatures (A.5). |
| `Config.lua` | Base `Validate`: allow Desert 10 (`#seedCatalog == 8 or (stage == 2 and #seedCatalog == 10)`). Last block: `Config.Version='V151 R149'` (or the release's tag) and **`ProfileVersion=22`** (one more than the last shipped value). |
| `PremiumProgress.lua` | `IndexProgress(player,stage,beforeR149)`, new `IndexMilestone`, `BiomeComplete` and `ClaimIndexBiomeHalf` use it (A.6). |
| `ChestIndex.client.lua` | `counts(stage,beforeR149)` plus `milestones(stage)`, used by the reward dots and the half/completion buttons (A.7). Card order is already by rarity (`LayoutOrder = rank·10000 + index`). |
| `RarePackTests.lua` | Selector `roster` (A.8). |
| `StudioTestHelp.lua` | Append to the `/test rarepacks` row: `; rarepacks roster four TEST packs that reveal Fire Pepper, Moon Melon, Aloe and Sand Fruit.` Keep the `rarepacks verity` text. |
| `docs/COMMANDS.md`, release notes, `src/MANIFEST.tsv` | Command row; notes (shut down all servers); 2 ModuleScript rows: `ReplicatedStorage/Roster149` and `ReplicatedStorage/DesertPlantArt149`. The installer adds these 2 new ModuleScripts. |

**No change** to: PackOdds81/112/137, BalanceRules, EconomyBalance90 (its Fire Pepper/Moon Melon entries are superseded after pacing), FruitOfHour, MarketLayout, VoidPackOdds85, VerityPackOdds, MysteryPackRules, DailyProgress, ChestService, PlayerDataService, PlantVisuals, PlantEffects, PlantGrowth, GardenDisplayNames.

### 6.2 New tests: `docs/proposals/R148/tests/`

**`run_roster.sh`**:
- Extracts the base with `git -C "$REPO" archive 9c9797e src | tar -x -C "$OUT/base"`.
- Copies `treadmill_bonus_R123/tests/mkbundle.py` + `world.luau` into the same relative layout under `$OUT/base` and under the checkout, and bundles both.
- Runs `dump_roster.luau` (A.9) on both and diffs the output. **Only these lines may differ**:
  - `PLANT AloeSeed` (name only; `BASE` = the commit before the change, default `cba4032`, not `9c9797e`: R148 had moved on)
  - `PLANT FirePepperSeed` and `PLANT MoonflowerSeed`
  - added `PLANT DesertAloeSeed` and `PLANT SandFruitSeed`
  - `VOID 149` (the base reads 149 as unknown)
  - `ODDS` and `ROLL` lines of **Lava (4) and Crystal (5) only** (owner decision 1); every other line, for every banked version, must be identical. The dump runs all 7 stages; the checker also requires that
    the Secret / Cosmic / King seeds do not move in 112 / 137 packs, no banked roll ever gives a new seed, and promoted seeds carry their new label
  - `FOH` (51 → 53)
- Then runs the two tests below.

**`test_roster.luau`** (server world, real modules):
1. **Constants and catalog**:
   - `#SeedDesigns==54`, with Verity last.
   - The 2 specs: stage/SaveStage 2, index 9/10, rarities, colours.
   - Retired ids are still retired and still decode (`GetSeedById`); `AloeSeed` shows as "Aloe Sprout Seed".
   - `GetRarity`: Fire Pepper Mythic, Moon Melon Legendary.
   - `SeedCatalogByStage[2]` has 10 entries; `[2][9]`/`[2][10]` are the new ids.
   - `Config.Validate()` passes.
   - `ObtainablePool(2)` has 7 seeds; pools 4 and 5 have the same membership as before.
2. **Plants**:
   - The exact §2/§3 numbers, plus `Name`, `HarvestName`, `Tree`, `Mode`, `FruitCount`, `Roster149=true`, `Pace.Exempt`.
   - Fire Pepper Height/Radius/Sockets/FruitCenters/FruitRadii are exactly ×2 of the base (base: H 6.3090, R 3.1725, socket 4 (1.34, 2.65, −1.10), radius 1.6046).
   - New plants' geometry equals `DesertPlantArt149.Get`.
   - All values are ≤ 9e10 and integers; seconds ≤ 86400.
   - Income ladders of §2/§3 are strictly increasing.
3. **Odds**:
   - Every v149 row of the §4 tables (1e-9); stages 1/3/6/7 at 149 equal 137.
   - `OddsVersion==149`, `ValidOddsVersion(149)`, and a v150 pack decodes as nil.
   - Void/Verity/Mech identical across nil/0/81/112/137/149; Void 149 = Void 137.
   - Hold tooltip via the real `ChestService:_holdPack` rows: a 149 Lava pack has "Fire Pepper Seed: 1/800"; a 137 Lava pack also has "Fire Pepper Seed: 1/800" (owner decision 1); a 137 Desert pack has no Aloe or Sand Fruit row.
   - 1,000,000 `math.random` rolls:
     - 149 Desert Pack01: Aloe 12.5 ± 0.2%, Sand Fruit 1.11 ± 0.05%.
     - 137 Lava Pack01: Fire Pepper 0.125 ± 0.02% (it was ≈ 33%) and its returned rarity is "Mythic"; 137 Crystal Pack01: Moon Melon 0.667 ± 0.04%, "Legendary".
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
   - `IndexMilestone`:
     - old 2/5 → nothing;
     - old 3/5 (6 of 10 points) → half only;
     - old 5/5 → full;
     - claim each once, and a second claim answers "ALREADY CLAIMED";
     - a player who claimed before cannot claim again;
     - Lava/Crystal milestones are unchanged.
6. **Commands**:
   - `rarepacks roster` gives 4 TEST packs revealing Mythic / Legendary / Rare / Legendary.
   - The help row text is right.
   - `seed DesertAloeSeed` and `seeds desert` include the new seeds.
   - `odds desert rare` shows "Aloe Seed: 1/2.5".
7. **Fruit of the Hour**: 53 candidates including both new ones, never Verity.

**`test_roster_art.luau`** (client world `inventory_R113`):
- The new plants build in every mode: ripe; growing at body .1/.5/.9; one harvest item per group; `Supports` with trunk collision.
- 96 and 99 specs; nothing below y −0.05; groups 1..N present; sockets, centres, Height and Radius equal the catalog.
- Fire Pepper art is exactly ×2 of the base's `ApprovedPlantArt` (git show `9c9797e`, like R147's art test) for every spec: z and position ×2, rotation equal.
- Prism Pepper, Moon Melon, Prickly Pear, Dune Lotus, Apple and Lava Lotus build identically to the base (fingerprint like `test_verity_art`).
- Seeds: the 3 signatures build (42 / 69 / 46 parts); `SeedAnim` is Twinkle×2 on Sand Fruit and Flicker×3 on Fire Pepper.
- `PlantEffects` aura: on Sand Fruit, Moon Melon and Fire Pepper; none on Aloe.
- The Index Desert tab shows 7 cards in rarity order.
- ChestIndex parity: a player complete under the old roster sees the reward dot and a lit claim button.

### 6.3 Existing suites that change
Each edit below was checked on the prototype.
- **`R147/tests/test_verity_pack.luau`** (170 checks, 9 change):
  - L144: `#Rules.SeedDesigns==54` ("47 biome + 6 Mech + Verity").
  - L167: the `changed` list sorted must equal exactly `FirePepperSeed,MoonflowerSeed`.
  - L169: `nPlants==65`.
  - L173: `#cands==53` and `plain` = `FohBefore` plus `DesertAloeSeed,SandFruitSeed` (sorted).
  - L321, L360, L362, L368, L376: the converted Verity pack's version `137` → `Rules.OddsVersion`. Leave the explicit `OddsVersion=137` AddChest calls alone.
- **`R137/tests/test_packs.luau`** (41 checks, 0 failures after these edits):
  - `tiers(odds)` uses `Rules.RarityBeforeR149[id] or Rules.GetRarity(id)` (an empty map: today's rarity); the Lava / Crystal rows of the approved model are skipped (30 of 42 rows are compared).
  - L44: `Rules.OddsVersion==149`.
  - L47 and L51: pass version `137` explicitly.
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
- **No windfall** from banked Lava/Crystal packs (owner decision 1); they re-split with the new tiers (table at the top). Toggle: `Roster149.RarityBefore`.
- **Index**: no duplicate claims, nothing lost (D6). Desert's Index shows 7 entries; players who already claimed see their claim as done.

---

## Appendix A: reference code (prototyped, compiles, results above)

### A.1 `SeedPackRules.lua`

Insert after the `Rules.SeedDesigns={...}` literal:
```lua
-- R149 (owner): Desert's new Rare (Aloe) and Legendary (Sand Fruit), in Desert's save slots 9 and 10 (Roster149).
local Roster149=require(script.Parent.Roster149)
for _,spec in ipairs(Roster149.Designs)do table.insert(Rules.SeedDesigns,table.clone(spec))end
```
Insert after the R37 loop (`for id,rarity in pairs({SolarStarfruitSeed='King',...})do ... end`):
```lua
-- R148 (owner): Fire Pepper is Lava's Mythic and Moon Melon Crystal's Legendary in every pack, banked ones included
-- (Roster149.RarityBefore is empty; see the odds block). The retired Uncommon AloeSeed gets a distinct display name; its id never changes.
for id,rarity in pairs(Roster149.Promote)do Rules.SeedRarityById[id]=rarity;Rules.SeedDesignById[id].rarity=rarity end
Rules.SeedDesignById.FirePepperSeed.design='red to orange, cream pepper flecks, a curled green stem cap and three flickering flame wisps'
Rules.SeedDesignById.AloeSeed.name='Aloe Sprout'
```
Insert between the R137 block (ends after `Rules.Roll=function ... N137.Roll(...) end`) and `-- R147 (owner): the Verity pack. The OUTERMOST wrapper`:
```lua
-- R148 (owner, roster change): new world/event packs carry OddsVersion 149 = PackOdds137's numbers over today's roster
-- (Desert Aloe Rare + Sand Fruit Legendary, Fire Pepper Mythic, Moon Melon Legendary). A pack made before this release
-- (OddsVersion 137, 112, 81 or none) rolls the roster it was made with, minus the two new seeds. OWNER (no windfall): Fire Pepper
-- and Moon Melon keep their NEW tiers in banked Lava / Crystal packs (Roster149.RarityBefore is empty), so they are rare there
-- and the seeds that shared their old Rare tier split it between fewer seeds. Every other biome, Void, Mech and Verity are as before
-- (Verity's wrapper stays outermost). The final text of this block is in src/ReplicatedStorage/SeedPackRules.lua.
Rules.NewInR149=Roster149.New
Rules.RarityBeforeR149=Roster149.RarityBefore
Rules.OddsVersion=149
Rules.OddsVersions[149]=true
local rollPre149,oddsPre149=Rules.Roll,Rules.SeedOdds
local livePool,liveRarity=Rules.ObtainablePool,Rules.GetRarity
local legacyDepth=0 -- > 0 only while a pre-R149 world pack is rolled or priced (never yields)
local legacyPools=setmetatable({},{__mode='k'})
function Rules.ObtainablePool(config,stage)
 local pool=livePool(config,stage)
 if legacyDepth==0 or not pool then return pool end
 local byStage=legacyPools[config];if not byStage then byStage={};legacyPools[config]=byStage end
 if not byStage[stage]then
  local out={};for _,seed in ipairs(pool)do if not Roster149.New[seed.Id]then out[#out+1]=seed end end;byStage[stage]=out
 end
 return byStage[stage]
end
function Rules.GetRarity(seedId)
 local old=legacyDepth>0 and Roster149.RarityBefore[seedId]
 if old then return old,Rules.Rarities[old]end
 return liveRarity(seedId)
end
local function worldPack(stage,variantKey)return type(stage)=='number'and stage>=1 and stage<=7 and variantKey~='EclipseReliquary'and variantKey~='MechLimited'end
local function legacy(fn,...)
 legacyDepth+=1
 local result=table.pack(pcall(fn,...))
 legacyDepth-=1
 if not result[1]then error(result[2],0)end
 return table.unpack(result,2,result.n)
end
Rules.SeedOdds=function(config,stage,variantKey,luck,version,boost)
 if version==nil then version=149 end
 if version==149 then return oddsPre149(config,stage,variantKey,luck,N137.Version,boost)end
 if worldPack(stage,variantKey)then return legacy(oddsPre149,config,stage,variantKey,luck,version,boost)end
 return oddsPre149(config,stage,variantKey,luck,version,boost)
end
Rules.Roll=function(config,stage,draw,luck,variantKey,version,boost)
 if version==149 then return rollPre149(config,stage,draw,luck,variantKey,N137.Version,boost)end
 if worldPack(stage,variantKey)then
  local seed=legacy(rollPre149,config,stage,draw,luck,variantKey,version,boost)
  return seed,seed and(liveRarity(seed.Id))
 end
 return rollPre149(config,stage,draw,luck,variantKey,version,boost)
end
```
Why this is safe:
- Every older path looks up `Rules.ObtainablePool` / `Rules.GetRarity` as fields at call time, so the scope reaches them. This is checked: no module caches them.
- `SeedOdds(nil version)` still means "current" (used by Index chips); `Roll(nil)` still means "unversioned legacy".
- The Void/Verity pools never see the legacy scope.

### A.2 `src/ReplicatedStorage/Roster149.lua` (new)
```lua
-- R149 (owner): seed roster change. Desert gets a Rare (Aloe) and a Legendary (Sand Fruit, grown on a palm); Fire Pepper
-- becomes Lava's Mythic (twice the size, far more cash per pepper); Moon Melon becomes Crystal's Legendary.
-- Shared constants. Nothing is required at load time (SeedPackRules, BalanceValues81 and PlantCatalog read it).
local R={Version=149}
-- Seeds added in R149: packs made before R149 (OddsVersion 137 / 112 / 81 / none) never roll them.
R.New={DesertAloeSeed=true,SandFruitSeed=true}
-- The promoted seeds' rarity now, and the rarity packs made before R149 roll them at. OWNER: R.RarityBefore is EMPTY, so banked Lava /
-- Crystal packs roll Fire Pepper / Moon Melon at their new tiers (the plan's default kept them Rare; Desert stays as before).
R.Promote={FirePepperSeed='Mythic',MoonflowerSeed='Legendary'}
R.RarityBefore={} -- OWNER: banked packs follow the new tiers (the plan's default was {FirePepperSeed='Rare',MoonflowerSeed='Rare'})
-- SeedPackRules.SeedDesigns rows. Desert save slots 9 and 10 (slots 1-8 keep their ids, retired ones included).
R.Designs={
 {biome='Desert',index=9,name='Aloe',rarity='Rare',design='sea green to pale sage, cream leaf spots, three fleshy aloe blades and a red-orange flower spike',
  pattern='Dots',top='5d9f8c',bottom='c3dcc0',ink='f2f6e6',addition='none',stage=2,id='DesertAloeSeed'},
 {biome='Desert',index=10,name='Sand Fruit',rarity='Legendary',design='sand gold to warm cream, dune-ripple stripes, a tiny palm crown and twinkling sand sparkles',
  pattern='Stripes',top='d6a35c',bottom='f6e3b4',ink='a8733c',addition='none',stage=2,id='SandFruitSeed'},
}
-- Final plant numbers, written after GrowthPace125 (Roster149=true keeps the pacing off them).
-- Rule (EconomyBalance90 + GrowthPace125): income/s = biome base x tier, halved by the R125 pacing; value per fruit =
-- income x RegrowSeconds / FruitCount. Bases: Desert 34760, Lava 137578, Crystal 272073; tiers Rare 2.5, Legendary 4, Mythic 7.
R.Plants={
 DesertAloeSeed={Name='Aloe',HarvestName='Aloe bloom',Rarity='Rare',Rank=3,Tree=false,FruitCount=3,Seconds=960,RegrowSeconds=530,Value=10000000},       -- 2.04e8/h (OWNER: out-earns Prickly Pear; the rule gave 7680000)
 SandFruitSeed={Name='Sand Fruit',HarvestName='Sand fruit',Rarity='Legendary',Rank=4,Tree=true,FruitCount=4,Seconds=2760,RegrowSeconds=1520,Value=26400000}, -- 2.50e8/h
 FirePepperSeed={Rarity='Mythic',Rank=5,Seconds=4300,RegrowSeconds=2370,Value=285000000},  -- 1.73e9/h (FruitCount stays 4: saved crops depend on it)
 MoonflowerSeed={Rarity='Legendary',Rank=4,Seconds=3400,RegrowSeconds=1870,Value=509000000}, -- 1.96e9/h (FruitCount stays 2)
}
-- Index cash {first, repeat}. New seeds: one base fruit / a fifth of it. Promoted seeds: the old amounts x new / old fruit value
-- (the EconomyBalance90.Apply convention).
R.Index={DesertAloeSeed={10000000,2000000},SandFruitSeed={26400000,5280000},FirePepperSeed={360000000,72000000},MoonflowerSeed={475000000,95000000}}
R.FirePepperArtScale=2 -- the Fire Pepper plant and its peppers: art, sockets, fruit centres, radii and bounds
function R.ApplyBalance(T)
 for id,cash in pairs(R.Index)do T.IndexFirst[id]=cash[1];T.IndexRepeat[id]=cash[2]end
end
local function scaled(points,f)local out={};for i,p in ipairs(points)do out[i]={p[1]*f,p[2]*f,p[3]*f}end;return out end
function R.ApplyPlants(catalog)
 local Art=require(script.Parent.DesertPlantArt149)
 for _,spec in ipairs(R.Designs)do
  local n=R.Plants[spec.id];local art=Art.Get(spec.id)
  catalog[spec.id]={Id=spec.id,Name=n.Name,Biome='Desert',Stage=2,Rarity=n.Rarity,Rank=n.Rank,Tree=n.Tree,Mode='repeat',HarvestName=n.HarvestName,
   FruitCount=n.FruitCount,Roster149=true,Sockets=scaled(art.Sockets,1),FruitCenters=scaled(art.FruitCenters,1),FruitRadii=table.clone(art.FruitRadii),
   Height=art.Height,Radius=art.Radius,BaseScale=1,AuthoredHeight=art.Height,Seconds=n.Seconds,RegrowSeconds=n.RegrowSeconds,Value=n.Value}
 end
 for id in pairs(R.Promote)do
  local d,n=catalog[id],R.Plants[id]
  d.Rarity=n.Rarity;d.Rank=n.Rank;d.Seconds=n.Seconds;d.RegrowSeconds=n.RegrowSeconds;d.Value=n.Value
  d.Roster149=true;d.BaseSeconds=nil;d.GrowthFactor=nil
 end
 local d,f=catalog.FirePepperSeed,R.FirePepperArtScale
 d.Height*=f;d.Radius*=f;d.Sockets=scaled(d.Sockets,f);d.FruitCenters=scaled(d.FruitCenters,f)
 local radii={};for i,r in ipairs(d.FruitRadii)do radii[i]=r*f end;d.FruitRadii=radii
 -- The retired Uncommon AloeSeed (players may still hold one) gets its own display name; its id never changes.
 catalog.AloeSeed.Name='Aloe Sprout';catalog.AloeSeed.HarvestName='Aloe sprout'
end
return R
```
(The promoted plants' geometry tables are replaced, never mutated in place: they are shared with `ApprovedPlantCatalog`.)

### A.3 `src/ReplicatedStorage/DesertPlantArt149.lua` (new)
```lua
-- R149 (owner): plant art of Desert's two new seeds, in the RarityRework spec format PlantVisuals reads (like VerityPlantArt).
--  * DesertAloeSeed (Rare, "Aloe"): a blue-green rosette of thick pointed leaves (pale spots, red-brown teeth) with three tall
--    red-orange flower spikes. Each spike is one fruit (group 1-3); harvesting it leaves the rosette.
--  * SandFruitSeed (Legendary, "Sand Fruit"): a leaning desert palm (ringed trunk, eight arching fronds) with four bunches of
--    three round sand-gold fruits under the crown. Each bunch is one fruit (group 1-4).
-- Built once per id; numbers are studs at PlantScale 1. No requires (ApprovedPlantArt and Roster149 load it).
local A={}
local V,CF=Vector3.new,CFrame.new
A.AloeScale=1.5
A.Ids={DesertAloeSeed=true,SandFruitSeed=true}
function A.Is(id)return A.Ids[id]==true end
local function comps(cf)local x,y,z,a,b,c,d,e,f,g,h,i=cf:GetComponents();return {x,y,z,a,b,c,d,e,f,g,h,i}end
-- A frame at `pos` whose local Y runs along `dir` and whose local X is `normal` (made perpendicular to dir).
local function along(pos,dir,normal)
 local y=dir.Unit;local x=(normal-y*normal:Dot(y)).Unit
 return CFrame.fromMatrix(pos,x,y)
end
local function new()
 local specs={}
 local self={Specs=specs}
 function self.add(s)s.p=1;s._ArtIndex=#specs+1;specs[#specs+1]=s;return s end
 -- A pointed leaf of two Wedges: base at `base`, tip at base+dir*len, width across, thickness along `up`.
 function self.blade(base,dir,up,len,width,thick,k1,k2,g,role,name)
  local L=along(base,dir,up)
  self.add({s='Wedge',z={thick,len,width/2},c=comps(L*CF(0,len/2,-width/4)),k=k1,m='SmoothPlastic',t=0,g=g,r=role,f=name})
  self.add({s='Wedge',z={thick,len,width/2},c=comps(L*CF(0,len/2,width/4)*CFrame.Angles(0,math.pi,0)),k=k2,m='SmoothPlastic',t=0,g=g,r=role,f=name})
  return L
 end
 -- A round rod from a to b (spec 'Cylinder': z = {diameter, length, diameter}, axis = local Y).
 function self.rod(a,b,d,k,m,g,role,name)
  local dir=b-a;local side=math.abs(dir.Unit.Y)>.98 and V(1,0,0)or V(0,1,0)
  return self.add({s='Cylinder',z={d,dir.Magnitude,d},c=comps(along((a+b)/2,dir,side)),k=k,m=m or'SmoothPlastic',t=0,g=g,r=role,f=name})
 end
 function self.ball(shape,pos,size,k,m,g,role,name,frame)
  return self.add({s=shape,z=size,c=comps(CF(pos)*(frame or CF())),k=k,m=m or'SmoothPlastic',t=0,g=g,r=role,f=name})
 end
 return self
end
local function bounds(art)
 local top,radius=0,0
 for _,s in ipairs(art.Specs)do
  local c=s.c;local z=s.z
  local ey=(math.abs(c[7])*z[1]+math.abs(c[8])*z[2]+math.abs(c[9])*z[3])/2
  local ex=(math.abs(c[4])*z[1]+math.abs(c[5])*z[2]+math.abs(c[6])*z[3])/2
  local ez=(math.abs(c[10])*z[1]+math.abs(c[11])*z[2]+math.abs(c[12])*z[3])/2
  top=math.max(top,c[2]+ey);radius=math.max(radius,math.sqrt(c[1]^2+c[3]^2)+math.max(ex,ez))
 end
 art.Height=math.floor(top*1000+.5)/1000;art.Radius=math.floor(radius*1000+.5)/1000
end
-- Aloe ----------------------------------------------------------------------------------------------------------------
local function aloe()
 local S=A.AloeScale;local b=new();local up=V(0,1,0)
 b.ball('Ball',V(0,.35,0)*S,{1.1*S,.7*S,1.1*S},{98,150,128},nil,0,'Stem','Rosette heart')
 -- three rings: count, first yaw (deg), base radius, base y, elevation (deg), length, width, thickness, two colours, outer?
 local rings={
  {7,0,.35,.25,28,3.4,.9,.42,{88,140,122},{100,154,134},true},
  {6,25.7,.25,.35,48,3.0,.8,.40,{100,156,138},{112,168,148},false},
  {4,45,.12,.45,68,2.4,.65,.36,{116,172,152},{128,184,160},false},
 }
 for _,r in ipairs(rings)do
  for k=0,r[1]-1 do
   local a=math.rad(r[2]+k*360/r[1]);local out=V(math.cos(a),0,-math.sin(a));local e=math.rad(r[5])
   local dir=out*math.cos(e)+up*math.sin(e);local t=V(math.sin(a),0,math.cos(a));local n=t:Cross(dir)
   local base=(out*r[3]+V(0,r[4],0))*S
   local L=b.blade(base,dir,n,r[6]*S,r[7]*S,r[8]*S,r[9],r[10],0,'Leaf','Aloe leaf')
   if r[11]then
    -- outer leaves: two pale spots on the upper face and one red-brown tooth on each margin (halfway up)
    for _,s in ipairs({.3,.55})do
     local w=r[7]*(1-s)
     b.ball('Ball',(L*CF((r[8]/2+.01)*S,s*r[6]*S,(s<.4 and -1 or 1)*w*.22*S)).Position,{.04*S,.24*S,.15*S},{204,228,214},nil,0,'Leaf','Aloe leaf spot',L.Rotation)
    end
    for _,side in ipairs({-1,1})do
     -- a thin spike leaning out of the margin toward the tip
     local s=.5;local w=r[7]*(1-s)
     local spike=L:VectorToWorldSpace(V(0,.6,side)).Unit
     local root=(L*CF(0,s*r[6]*S,side*w/2*S)).Position
     b.add({s='Ball',z={.06*S,.24*S,.06*S},c=comps(along(root+spike*.1*S,spike,up)),k={176,120,96},m='SmoothPlastic',t=0,g=0,r='Leaf',f='Aloe leaf tooth'})
    end
   end
  end
 end
 -- three flower spikes (groups 1-3): a stalk from the heart, tilted 10 degrees out, with 9 tubular florets on its top 40%
 local spikes={{15,4.6},{135,4.0},{255,3.5}}
 local art={Sockets={},FruitCenters={},FruitRadii={}}
 for g,sp in ipairs(spikes)do
  local a=math.rad(sp[1]);local out=V(math.cos(a),0,-math.sin(a));local tilt=math.rad(10)
  local dir=(up*math.cos(tilt)+out*math.sin(tilt)).Unit
  local socket=(out*.15+V(0,.7,0))*S;local len=sp[2]*S;local tip=socket+dir*len
  b.rod(socket,tip,.16*S,{126,146,100},nil,g,'Fruit','Aloe flower stalk')
  for i=0,8 do
   local f=.6+.4*i/9;local yaw=math.rad(sp[1]+i*137.5);local o=V(math.cos(yaw),0,-math.sin(yaw))
   local at=socket+dir*(len*f)+o*.12*S
   local hang=(o*math.cos(math.rad(-30))+up*math.sin(math.rad(-30))).Unit -- florets hang 30 degrees below level
   local color=i<4 and{236,96,48}or i<7 and{250,150,60}or{240,196,92}
   b.add({s='Ball',z={.16*S,.42*S,.16*S},c=comps(along(at+hang*.18*S,hang,up)),k=color,m='SmoothPlastic',t=0,g=g,r='Fruit',f='Aloe floret'})
  end
  b.ball('Ball',tip+dir*.1*S,{.18*S,.3*S,.18*S},{226,206,110},nil,g,'Fruit','Aloe bud tip',along(V(),dir,V(1,0,0)).Rotation)
  local center=socket+dir*(len*.8)
  art.Sockets[g]={socket.X,socket.Y,socket.Z};art.FruitCenters[g]={center.X,center.Y,center.Z};art.FruitRadii[g]=len*.3
 end
 art.Specs=b.Specs;art.RarityRework=true;bounds(art);return art
end
-- Sand Fruit palm --------------------------------------------------------------------------------------------------
local function palm()
 local b=new();local up=V(0,1,0)
 -- root flare and trunk: 5 segments leaning toward +X, darker rings at the joints
 b.rod(V(0,0,0),V(0,.6,0),2.0,{128,94,58},'Wood',0,'Stem','Palm root flare')
 for k=0,2 do
  local a=math.rad(30+k*120);local out=V(math.cos(a),0,-math.sin(a))
  b.add({s='Wedge',z={.35,.5,.9},c=comps(along(out*1.05+V(0,.25,0),up,out)*CFrame.Angles(0,math.pi/2,0)),k={120,88,54},m='Wood',t=0,g=0,r='Stem',f='Palm root toe'})
 end
 local joints={V(0,0,0),V(.05,2.2,0),V(.2,4.4,0),V(.45,6.6,0),V(.75,8.8,0),V(1.1,11.0,0)}
 local diam={1.45,1.35,1.25,1.15,1.05}
 for i=1,5 do
  b.rod(joints[i],joints[i+1],diam[i],i%2==1 and{150,110,70}or{136,99,62},'Wood',0,'Stem','Palm trunk')
  local d=(joints[i+1]-joints[i]).Unit
  b.rod(joints[i+1]-d*.11,joints[i+1]+d*.11,diam[i]+.25,{112,80,50},'Wood',0,'Stem','Palm trunk ring')
 end
 local crown=V(1.1,11.4,0)
 b.ball('Ball',crown,{1.7,1.3,1.7},{108,130,60},nil,0,'Leaf','Palm crown heart')
 -- four dried frond boots under the crown
 for k=0,3 do
  local a=math.rad(45+k*90);local out=V(math.cos(a),0,-math.sin(a))
  b.blade(crown+out*.45-V(0,.55,0),(out*.8-up*.6).Unit,up,1.1,.55,.18,{170,130,80},{158,120,72},0,'Leaf','Dry frond boot')
 end
 -- eight fronds: a rising inner blade with a rachis, then a drooping outer blade
 for k=0,7 do
  local a=math.rad(k*45+(k%2)*6);local out=V(math.cos(a),0,-math.sin(a))
  local e1,e2=math.rad(k%2==0 and 25 or 18),math.rad(-25)
  local d1=out*math.cos(e1)+up*math.sin(e1);local d2=out*math.cos(e2)+up*math.sin(e2)
  local t=V(math.sin(a),0,math.cos(a))
  local base=crown+out*.5
  b.rod(base,base+d1*3.0,.14,{120,150,70},nil,0,'Leaf','Palm frond rachis')
  b.blade(base,d1,t:Cross(d1),3.0,1.5,.12,{86,150,72},{98,164,80},0,'Leaf','Palm frond')
  b.blade(base+d1*3.0,d2,t:Cross(d2),3.2,1.2,.12,{98,160,76},{124,160,82},0,'Leaf','Palm frond tip')
 end
 -- two young fronds standing up in the middle
 for k=0,1 do
  local a=math.rad(90+k*180);local out=V(math.cos(a),0,-math.sin(a));local e=math.rad(65)
  local d=out*math.cos(e)+up*math.sin(e);local t=V(math.sin(a),0,math.cos(a))
  b.blade(crown+V(0,.4,0),d,t:Cross(d),2.6,1.0,.12,{112,176,86},{124,186,94},0,'Leaf','Young palm frond')
 end
 -- four bunches (groups 1-4) between the fronds: a stalk and three round sand fruits, each with a dune-ripple band
 local art={Sockets={},FruitCenters={},FruitRadii={}}
 local skins={{222,182,112},{214,170,98},{230,192,124}}
 for g=1,4 do
  local a=math.rad(22.5+(g-1)*90);local out=V(math.cos(a),0,-math.sin(a))
  local socket=crown+out*.95-V(0,.6,0)
  local tip=socket+(out*.5-up*.78).Unit*.9
  -- R134 floating check: the stalk starts INSIDE the crown heart and its tip ends inside the three fruits (centres .47 from it, radius .525)
  b.rod(crown+out*.45-V(0,.3,0),tip,.18,{140,110,60},nil,g,'Fruit','Sand fruit stalk')
  local center=tip-V(0,.22,0)
  for j=0,2 do
   local ja=a+math.rad(j*120+60);local o=V(math.cos(ja),0,-math.sin(ja))
   local p=center+o*.42-V(0,.05*j,0)
   b.ball('Sphere',p,{1.05,1.05,1.05},skins[j+1],nil,g,'Fruit','Sand fruit')
   b.ball('Ball',p+V(0,.08,0),{1.1,.16,1.1},{184,138,78},nil,g,'Fruit','Sand fruit ripple',CFrame.Angles(.18,0,.1))
  end
  b.ball('Ball',center+V(math.cos(a)*.42,.42,-math.sin(a)*.42),{.18,.18,.18},{255,236,170},'Neon',g,'Fruit','Sand sparkle')
  art.Sockets[g]={socket.X,socket.Y,socket.Z};art.FruitCenters[g]={center.X,center.Y,center.Z};art.FruitRadii[g]=1.05
 end
 art.Specs=b.Specs;art.RarityRework=true;bounds(art);return art
end
local built={}
function A.Get(id)
 if not A.Is(id)then return nil end
 if not built[id]then built[id]=id=='DesertAloeSeed'and aloe()or palm()end
 return built[id]
end
return A
```

### A.4 `ApprovedPlantArt.lua`
```lua
local Verity=require(RS:WaitForChild('VerityPlantArt'))
local Desert149=require(RS:WaitForChild('DesertPlantArt149')) -- R149: the Aloe and the Sand Fruit palm
function Art.Has(id)return Verity.Is(id)or Desert149.Is(id)or Mech.Get(id)~=nil or Rarity.Has(id)or Trees.Has(id)or Index[id]~=nil end
...
function Art.Get(id,crop)
 if Verity.Is(id)then return Verity.Get(id)end
 if Desert149.Is(id)then return Desert149.Get(id)end
 ...
  -- inside `if not loaded[id]then`, before the AncientWorldrootSeed block:
  if id=='FirePepperSeed'then
   -- R149 (owner): the Mythic Fire Pepper is twice as big, peppers included (Roster149.FirePepperArtScale).
   local f=require(RS:WaitForChild('Roster149')).FirePepperArtScale
   local scaled={};for i,source in ipairs(loaded[id])do
    local d=table.clone(source);d.Specs={};d.Sockets={};d.FruitCenters={};d.FruitRadii={};d.Height*=f;d.Radius*=f
    for j,s in ipairs(source.Specs)do local p=table.clone(s);p.z=table.clone(s.z);p.c=table.clone(s.c);for axis=1,3 do p.z[axis]*=f;p.c[axis]*=f end;d.Specs[j]=p end
    for _,field in ipairs({'Sockets','FruitCenters'})do for j,p in ipairs(source[field])do d[field][j]={p[1]*f,p[2]*f,p[3]*f}end end
    for j,r in ipairs(source.FruitRadii)do d.FruitRadii[j]=r*f end;scaled[i]=d
   end;loaded[id]=scaled
  end
```
`Art.Key` needs no change: the new ids fall through to `return id`.

### A.5 `SeedSignatures.lua`
Insert before `function S.Get(id)`:
```lua
-- R149 (owner): Desert's Aloe (Rare) and Sand Fruit (Legendary), and Fire Pepper now Mythic.
S.Shapes.DesertAloeSeed='Pointed';S.Shapes.SandFruitSeed='Round'
Sig.DesertAloeSeed={Draw=function(k) -- three fleshy blue-green aloe blades on top and a red-orange flower spike
 local y=k.H-.03
 for _,t in ipairs({-.6,0,.6})do
  local dir=k.V(math.sin(t)*.75,1,math.cos(t)*.15)
  k.lay('Aloe blade',k.V(math.sin(t)*.06,y,0)+dir.Unit*.2,dir,.46-math.abs(t)*.12,.15,.08,k.RGB(88,150,128))
 end
 k.line('Aloe flower stalk',k.V(.04,y,0),k.V(.12,y+.62,0),.05,k.RGB(126,146,100))
 for j=0,3 do k.oval('Aloe floret',k.V(.1+.03*(j%2),y+.36+j*.08,-.03),k.V(.07,.13,.07),j<2 and k.RGB(236,96,48)or k.RGB(250,170,70))end
end}
Sig.SandFruitSeed={Pattern='None',Draw=function(k) -- dune ripples on the skin, a tiny palm crown on top, two twinkling sand sparkles
 for i,y in ipairs({.24,-.02,-.28})do
  local pts={};for j=0,10 do pts[#pts+1]={-1.1+j*.22,y+math.sin(j*.8+i)*.05}end
  onSurface(k,'Dune ripple',pts,.012,.04,k.ink)
 end
 local y=k.H-.03
 k.line('Palm trunk',k.V(0,y,0),k.V(.04,y+.22,0),.07,k.RGB(140,104,64))
 ring3(5,function(t)local dir=k.V(math.sin(t),.25,math.cos(t));k.lay('Palm frond',k.V(.04,y+.23,0)+dir.Unit*.16,dir,.34,.13,.05,k.RGB(96,156,74))end)
 for _,v in ipairs({{-.3,.1},{.28,-.16}})do
  local z=(k.front(v[1],v[2])or-.3)-.02
  k.anim(k.oval('Sand sparkle',k.V(v[1],v[2],z),k.V(.07,.07,.04),k.RGB(255,240,180),nil,Enum.Material.Neon),'Twinkle')
 end
end}
Sig.FirePepperSeed={Draw=function(k) -- Mythic: a curled green stem cap and three flickering flame wisps on its shoulders
 local y=k.H-.04
 ring3(4,function(t)local dir=k.V(math.sin(t),-.3,math.cos(t));k.lay('Pepper calyx',k.V(0,y,0)+dir.Unit*.12,dir,.26,.12,.05,k.RGB(70,130,60))end)
 k.path('Pepper stem',{k.V(0,y,0),k.V(.04,y+.16,0),k.V(.13,y+.24,0),k.V(.2,y+.2,0)},.06,k.RGB(70,130,60))
 local cx,hw=k.span(y-.12)
 for i,f in ipairs({-.6,0,.6})do
  local tall=i==2 and .1 or 0
  k.anim(k.oval('Flame wisp',k.V(cx+f*hw,y-.02+.17+tall/2,.04),k.V(.12,.34+tall,.08),i==2 and k.RGB(255,215,80)or k.RGB(255,140,40),CFrame.Angles(0,0,-f*.5),Enum.Material.Neon),'Flicker')
 end
end}
```

### A.6 `PremiumProgress.lua`
Replace `IndexProgress` and `BiomeComplete`:
```lua
 -- R149: beforeR149 = count the roster before Desert's Aloe and Sand Fruit (PackRules.NewInR149 left out).
 function Data:IndexProgress(player,stage,beforeR149)
  local pool=PackRules.ObtainablePool(self.Config,stage)or{};local folder=self:GetOrCreateDiscoveredSeeds(player);local state=self:GetPremium(player)
  local seeds,plants,total=0,0,0
  for _,seed in ipairs(pool)do
   if not(beforeR149 and PackRules.NewInR149[seed.Id])then
    total+=1;local v=folder:FindFirstChild(seed.Id);if v and v.Value then seeds+=1 end;if state.Plants[seed.Id]then plants+=1 end
   end
  end
  return seeds,plants,total
 end
 -- R149: a milestone reached with the roster before R149 stays claimable (Desert's Index grew from 5 to 7 seeds), so an
 -- unclaimed halfway / completion reward is never taken away. ChestIndex shows the same rule.
 function Data:IndexMilestone(player,stage,full)
  for _,before in ipairs({false,true})do
   local seeds,plants,total=self:IndexProgress(player,stage,before)
   if total>0 and(full and seeds==total and plants==total or not full and seeds+plants>=total)then return true end
  end
  return false
 end
 function Data:BiomeComplete(player,stage)return self:IndexMilestone(player,stage,true)end
```
In `ClaimIndexBiomeHalf`, replace the two lines `local seeds,plants,total=self:IndexProgress(player,stage)` and `if total<=0 or seeds+plants<total then return false,'REACH HALF OF THIS INDEX'end` with:
```lua
  if not self:IndexMilestone(player,stage,false)then return false,'REACH HALF OF THIS INDEX'end
```

### A.7 `ChestIndex.client.lua`
Replace `counts`, and add `milestones` right after it:
```lua
local NewInR149=require(RS.SeedPackRules).NewInR149 -- R149
local function counts(stage,beforeR149)
 local seeds,plants,total=0,0,0
 for _,entry in ipairs(catalog:GetChildren())do local id=entry:GetAttribute('SeedId');if entry:GetAttribute('Stage')==stage and type(id)=='string'and id~=''and not(beforeR149 and NewInR149[id])then total+=1;if owned('DiscoveredSeeds',id)then seeds+=1 end;if owned('DiscoveredPlants',id)then plants+=1 end end end
 return seeds,plants,total
end
-- R149: the halfway / completion milestones, also reached with the roster before R149 (PremiumProgress:IndexMilestone).
local function milestones(stage)
 local half,full=false,false
 for _,before in ipairs({false,true})do
  local seeds,plants,total=counts(stage,before)
  if total>0 then half=half or seeds+plants>=total;full=full or(seeds==total and plants==total)end
 end
 return half,full
end
```
In `waiting(stage)`, replace the two milestone lines with:
```lua
  local half,full=milestones(stage)
  if half and not halfTaken then n+=1 end
  if(full or backpay>0)and not taken then n+=1 end
```
In the render:
- `local complete=total>0 and seeds==total and plants==total` → `local reachedHalf,complete=milestones(selected)`
- `local halfway=total>0 and(seeds+plants)>=total` → `local halfway=reachedHalf`

The progress text and bar keep using the live `seeds/plants/total`.

### A.8 `RarePackTests.lua`
Replace the "Use /test rarepacks …" line with:
```lua
 -- R149: rarepacks roster = four TEST packs that reveal the R149 seeds (Fire Pepper, Moon Melon, Aloe, Sand Fruit).
 if selector=='roster'then for _,id in ipairs({'FirePepperSeed','MoonflowerSeed','DesertAloeSeed','SandFruitSeed'})do table.insert(selected,Packs.SeedDesignById[id])end end
 if #selected==0 then return false,'Use /test rarepacks [mech|verity|roster|legendary|mythic|secret|cosmic|king].'end
```

### A.9 `dump_roster.luau` (regression dump; run on the base and on the change, then diff)
```lua
--!nocheck
local W=require('./world');local R=W.R;local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return {}end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
W.env.bit32=bit32
local Config=W.require(folder.Config);local Rules=W.module('SeedPackRules');local Hour=W.module('FruitOfHour')
print('VALIDATE',pcall(Config.Validate))
local ids={};for id in pairs(Config.GardenPlants)do ids[#ids+1]=id end;table.sort(ids)
local function pts(t)local o={};for _,p in ipairs(t or{})do o[#o+1]=('%.4f,%.4f,%.4f'):format(p[1],p[2],p[3])end;return table.concat(o,';')end
for _,id in ipairs(ids)do local d=Config.GardenPlants[id];local r={};for _,x in ipairs(d.FruitRadii or{})do r[#r+1]=('%.4f'):format(x)end
 print(('PLANT %s|%s|%s|%s|%s|%s|%s|%s|%s|%.4f|%.4f|%s|%s|%s|%s'):format(id,tostring(d.Seconds),tostring(d.RegrowSeconds),tostring(d.Value),tostring(d.Rarity),tostring(d.Rank),
  tostring(d.FruitCount),tostring(d.Name),tostring(d.HarvestName),d.Height,d.Radius,pts(d.Sockets),pts(d.FruitCenters),table.concat(r,';'),tostring(d.Regrows)))end
local function canon(t)local k={};for id,p in pairs(t or{})do k[#k+1]=id..'='..string.format('%.12g',p)end;table.sort(k);return table.concat(k,' ')end
for stage=1,7 do for _,v in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand'})do for _,ver in ipairs({0,81,112,137})do
 for _,l in ipairs({1,50,500,20000,1000000,50000000})do for _,b in ipairs({0,2})do
  print(('ODDS %d %s v%d L%g B%d %s'):format(stage,v,ver,l,b,canon(Rules.SeedOdds(Config,stage,v,l,ver,b==2 and 2 or nil))))
 end end end end end
for _,ver in ipairs({'nil',0,81,112,137,149})do local version=ver~='nil'and ver or nil
 print('VOID '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,7,'EclipseReliquary',1,version)))
 print('VERITY '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,7,'VerityReliquary',1,version)))
 print('MECH '..tostring(ver)..' '..canon(Rules.SeedOdds(Config,8,'MechLimited',1,version)))end
for _,ver in ipairs({'nil',81,112,137})do for _,stage in ipairs({2,4,5})do for _,v in ipairs({'Pack01','Pack04','Pack06'})do
 local s=12345;local function draw()s=(s*1103515245+12345)%2147483648;return s/2147483648 end
 local counts={}
 for _=1,4000 do local seed,rar=Rules.Roll(Config,stage,ver=='nil'and draw()or draw,1,v,ver~='nil'and ver or nil);local k=(seed and seed.Id or'nil')..':'..tostring(rar);counts[k]=(counts[k]or 0)+1 end
 local k={};for id,n in pairs(counts)do k[#k+1]=id..'='..n end;table.sort(k)
 print(('ROLL %s %d %s %s'):format(tostring(ver),stage,v,table.concat(k,' ')))end end end
print('FOH '..#Hour.Candidates()..' '..table.concat(Hour.Candidates(),','))
```
