# R113 economy proposal: sell values, shop prices, treadmill, fence

**Status: proposal only. Nothing under `src/` changed.** Numbers come from the real modules run in Luau
(`R113_economy/dump_economy.luau` -> `econ_live.tsv`) and a simulator of one active player (`R113_economy/sim.py`).
Nothing was run in Studio. Re-run everything: `docs/proposals/R113_economy/run_all.sh` (about 1 minute).
R112 odds, boot luck (Sand x50 ... Thunder x50M), keeper speeds and the speed curve are **not** changed.

## In short

- **Today the first hour is a shopping spree, and after about 80 h there is nothing left to buy.** A simulated active
  player buys 10 items in the first 40 minutes (3 machines, 3 trails, 2 boots, 3 fences). By 80 h they own everything, and cash
  just piles up (70T at 100 h).
- **Dune Lotus (Desert, "Mythic") is almost half of all Desert pulls, because Desert has no Rare or Legendary seed. It pays 180M
  in one harvest.** A Desert pack is worth more one-off cash than a Snow pack, and 15 minutes in you are picking 180M fruits.
- **Kings are worth less than Secrets and Cosmics from the same biome.** Examples: Storm's Pulsar Starfruit (King, 1 in a trillion) pays 2.5B a fruit,
  and Blackout Bloom (Secret) pays 5B. Lava's Ember Emperor (King) pays 400M, and Lava Lotus (Legendary) pays 900M. The paid Mech King
  (1 in 200 per gem pack) pays 10B, which is 4x a Storm King.
- **The fence upgrade does almost nothing.** All 6 tiers together cost 30T and give +5% growth speed and a +5% size bonus, which rounding mostly erases.
- **Proposal:**
  1. Sell values come from one rule: *income per plant = biome base x tier multiplier*.
     - Biome base goes up about x3 per biome: Forest 1K/s, Jungle 3K, Desert 10K, Snow 30K, Lava 100K, Crystal 300K, Storm 1M.
     - Tier multiplier: Common 1, Uncommon 1.6, Rare 2.5, Legendary 4, Mythic 7, Secret 20, Cosmic 60, **King 500**.
     - A King plant earns 25x a Secret and 200x a Rare of its biome. A Storm King fruit sells for 61B (today 2.5B).
     - Dune Lotus is priced as a Rare (15M instead of 180M). Single-harvest plants pay 10 minutes of their tier's income.
  2. Prices are re-tuned so each purchase lands on a target time. Early items come fast, late ones take long but come steadily:
     - Machines: 5 min, 30 min, 1.5 h, 5 h, 15 h, 40 h.
     - Trails: 10 min, 45 min, 3 h, 10 h, 30 h, 80 h.
     - Boots: 15 min, 2 h, 8 h, 24 h, 60 h.
     - Fences: 20 min to 100 h. Each fence tier now adds **+8% sell value**, up to +48%.
  3. Machine and trail multipliers stay as they are.
- **Result (simulated, median active player):**

  | | Storm | Thunder Boots | Last treadmill | Everything owned |
  |---|---|---|---|---|
  | Today | 14 h | 40 h | 58 h | ~80 h |
  | Proposed | 17 h | 61 h | 42 h | ~100 h |

  Every item is bought between 5 minutes and 100 hours, and no item is instant or out of reach.

## Assumptions (simulator, `sim.py`)

- **Active play only.** Each 5-minute pack refresh the player:
  - raids the top 2 unlocked biomes and gets 60% of their 5 packs (other players take the rest). A run takes 2 x camp distance / speed + 15 s.
  - spends up to 75 s harvesting, 1 fruit per second, picking the most valuable fruits first, then sells everything.
  - spends at least 60 s on the treadmill, plus any time left over.
- **Every seed is planted.** The garden fits about 1,800 plants: the server only enforces 3-stud spacing in 10 beds
  (`Config.lua:524-526, 633-644`). So late-game income is limited by how fast you pick, not by space. This is the main reason fruit value per pick matters.
- **Spending:** the player buys the cheapest affordable next item among machine, trail, boots and fence. Free player: no passes, no gems, no Robux.
- **Size, Gold/Diamond and weather bonuses average +1.8% per fruit.** Measured with the real `PlantRules.Fruit` over 40K rolled seeds. They are exciting when they hit, but they don't move the economy.
- **Unlocking a biome needs speed of at least the keeper's close speed x1.10.** These are the R112 values: 24/35/55/88/141/226/363 (spec S1).
- **Odds are the live R112 odds**, dumped per biome x pack x boot from the real `SeedPackRules` and `PackOdds112`, with the real pack spawn mix.
- **Medians of 40 simulated players.** Treat any single number as good to about ±20%. The sensitivity table shows how much the assumptions matter.

## Current economy map (live R112, file:line)

| What | Where | Value |
|---|---|---|
| Fruit value per seed | `BalanceValues81.lua:2` `SeedValues`, overridden by `EconomyBalance90.lua:13-23` `FruitValues`, applied in `PlantCatalog.lua:132-135` | table below ("now") |
| Single-harvest seeds (Sunflower, Aurora Lily, Lava Lotus, Dune Lotus) | `PlantCatalog.lua:127-130` (`Regrows=false`) | pay once |
| Timings (grow `Seconds`, `RegrowSeconds`, `FruitCount`) | `PlantCatalog.lua:2` (+ Crowncore regrow `EconomyBalance90.lua:24`) | unchanged by this proposal |
| Size, Gold/Diamond, weather multipliers | `BalanceRules.lua:20-24`, `WeatherTraits.lua:4,117-120`, `PlantRules.lua:59-88` | cash x = size (1-3) + Gold 2 / Diamond 3 + Drippy 1.5 / Frosted 2 / Charged 2.5, added together (max x8). Average x1.018 |
| Pack traits | `BalanceRules.lua:11-14` | Gold 4.5%, Diamond 0.5%, weather 2%, size x1 at 80.8% |
| Index cash on every pack opened | `BalanceValues81.lua:2` `IndexFirst` / `IndexRepeat`, scaled by `EconomyBalance90.lua:29-33`, paid by `PremiumProgress.lua:226-229` | table below |
| Index gems | `BalanceValues81.lua:23-25` | 10 at halfway, 20 per biome, 100 for everything |
| Harvest / sell | `PlayerDataService.lua:1442` (one fruit per pick), `:1542` sell all; bag holds 500 (`Config.lua` `MaxSavedHarvests`) | |
| Machines (treadmill) | multipliers `BalanceValues81.lua:11`; costs `EconomyBalance90.lua:6` (overrides `BalanceValues81.lua:17`); applied `Config.lua:734,738` | x1/4/20/100/600/4K/30K; 0/250K/11.9M/562M/26.7B/1.27T/60T |
| Trails | multipliers `BalanceValues81.lua:2`; costs `EconomyBalance90.lua:7-8`; applied `Config.lua:735,739` | x1.5-6; 200K/10.4M/538M/27.9B/1.45T/75T |
| Boots | luck `BalanceValues81.lua:14`; costs `EconomyBalance90.lua:9`; applied `Config.lua:740` | x50...x50M; 750K/64.1M/5.48B/468B/40T |
| Fence | costs `EconomyBalance90.lua:10` via `GardenFenceRules.lua:28`; effect `GardenFenceRules.lua:16-19`; buttons `GardenUpgradeService.lua:31-83` | 500K/18M/646M/23.2B/835B/30T; +0.8% per tier, 5% max |
| Training | 100 pts/s x machine x trail x2 speed pass (`Config.lua:733`, `BalanceRules.lua:17-19`) | |
| Speed curve | `BalanceValues81.lua:16` (R112) | not changed |
| Unused legacy prices | `Config.lua:101-110,245-262` (overwritten at `:734-740`); `Config.SellValueByRarity` `:181` (old loot) | dead data, harmless |
| Cash cap | `EconomyBalance90.lua:3` `MaxCash` 900T; `MaxBaseFruitValue` 10B, which is only shown in owner text (`OwnerUpdateCommands82.lua:38`) | |
| Gems | `MechCatalog.lua:2-3`: 1 gem = 1T cash (`PremiumProgress.lua:89-96`); Mech pack 80 gems; Growth pass 500, Speed pass 400 gems | |
| Robux bundles | `PremiumPricing.lua:2-25` | cash +30B/100B/300B/650B/1.4T; speed +250K...+25M points |
| Mech (gem pack) plants | `MechCatalog.lua:4` | Legendary 48% ... King 0.5% (Crowncore 10B/fruit) |

## Problems found

1. **Too fast early** (see the sim tables): 10 purchases in 40 minutes. Mint, Machine 2, Sand boots and Fence 2 all come in the first ~10 minutes.
   Everything up to Machine 4 is gone by 40 min.
2. **Dune Lotus (the "Desert money issue")**:
   - Desert odds pass the Rare and Legendary share up to Mythic, so Dune Lotus is 44% of Desert pulls (57% with Thunder boots).
   - At 180M a harvest, an average Desert pack pays 79M one-off. That beats Snow (39M), the next biome. It is also 225x Prickly Pear, the only other common Desert seed.
3. **Kings are worth too little.** At R112 odds a King is 1 in 1T with no boots and 1 in ~1,000 packs with Thunder boots.
   Yet Solar Starfruit (70M) < Dune Starfruit (Secret, 250M); Ember Emperor (400M) < Lava Lotus (Legendary, 900M) / Obsidian Maw (1B) / Boom Bloom (1.5B);
   Prism Monarch (800M) < Hollow Geode (1.5B) / Orbit Lotus (2.5B); Pulsar Starfruit (2.5B) < Tempest Lotus (Mythic, 3B) / Blackout Bloom (5B).
   Kings have more fruits, so their income per plant is only about 1.5-2x a Cosmic's.
4. **Tiers are uneven inside a biome.** Forest Elderbloom (Mythic) earns 145M/h vs Watermelon 11M/h (13x), while Sunflower (Legendary) is a 6M one-off.
   Single-harvest Legendaries (Aurora Lily 270M, Lava Lotus 900M) out-pay their biome's Secret per pick.
5. **Dead fence.** All 6 tiers cost 30T for +5% speed (and a size bump that the half-step rounding mostly removes). The greedy player buys it anyway,
   so today it just drains cash.
6. **Nothing left to buy late.** The last item (Royal trail) comes at ~80 h. After that, income of ~5-8T/h has no use except gems at 1T each.
7. **Gem/Robux side (for awareness, not changed here):**
   - A 49-Robux +30B cash bundle is well under an hour of play at 5 h, and nothing at 50 h.
   - The +25M speed bundle is about 146 speed, which jumps a new player straight to Lava.
   - The Mech King (1 in 200 per 80-gem pack) out-earns a trillion-to-one Storm King.
   - The speed pass barely changes progress, because prices, not training, are what hold players back (sensitivity table).

## Proposal

### Sell values (one rule)

- `R = BIOME_BASE[biome] x TIER_MULT[tier]` (cash per second per plant).
- Regrowing plants: `Value per fruit = R x RegrowSeconds / FruitCount`.
- Single-harvest plants: `Value = R x 600` (ten minutes of income in one pick).
- `IndexRepeat = R x 30 s`, `IndexFirst = R x 300 s`.

Values are rounded to 3 significant figures. Grow times, regrow times and fruit counts don't change (they are tied to the art).
Mech plants use the Storm base, but with Cosmic x40 and King x100 because the paid pack rolls them at 1 in 40 / 1 in 200.

| | Common | Uncommon | Rare | Legendary | Mythic | Secret | Cosmic | King |
|---|---|---|---|---|---|---|---|---|
| Tier multiplier | 1 | 1.6 | 2.5 | 4 | 7 | 20 | 60 | **500** |

| Biome | Forest | Jungle | Desert | Snow | Lava | Crystal | Storm |
|---|---|---|---|---|---|---|---|
| Base income per plant (cash/s) | 1K | 3K | 10K | 30K | 100K | 300K | 1M |

**Dune Lotus** is valued as a Rare, because in practice it is Desert's Rare (the odds stay Mythic, as approved). It pays 15M once instead of 180M.

### Plants: value per fruit, income per plant, index cash (current -> proposed)

| Biome | Plant | Tier | Fruits x regrow | Value/fruit now | proposed | Income/plant/h now | proposed | Index first/repeat now | proposed |
|---|---|---|---|---|---|---|---|---|---|
| Forest | Watermelon | Common | 2 x 33s | 50K | **16.5K** | 10.9M | 3.6M | 50K / 10K | 300K / 30K |
| Forest | Blueberry | Uncommon | 4 x 50s | 50K | **20K** | 14.4M | 5.76M | 100K / 20K | 480K / 48K |
| Forest | Apple | Rare | 4 x 82s | 100K | **51.3K** | 17.6M | 9.01M | 200K / 40K | 750K / 75K |
| Forest | Mooncap | Rare | 1 x 47s | 300K | **118K** | 23M | 9.04M | 25K / 5K | 750K / 75K |
| Forest | Sunflower | Legendary | single, 100s | 6M | **2.4M** | once | once | 500K / 100K | 1.2M / 120K |
| Forest | Elderbloom | Mythic | 5 x 62s | 500K | **86.8K** | 145M | 25.2M | 1.25M / 250K | 2.1M / 210K |
| Jungle | Cocoa | Common | 4 x 72s | 87.5K | **54K** | 17.5M | 10.8M | 175K / 35K | 900K / 90K |
| Jungle | Pineapple | Uncommon | 1 x 87s | 700K | **418K** | 29M | 17.3M | 350K / 70K | 1.44M / 144K |
| Jungle | Venom Vine | Rare | 1 x 103s | 2M | **773K** | 69.9M | 27M | 167K / 33.3K | 2.25M / 225K |
| Jungle | Lantern Fern | Rare | 4 x 103s | 350K | **193K** | 48.9M | 27M | 700K / 140K | 2.25M / 225K |
| Jungle | Tiger Orchid | Legendary | 3 x 119s | 1.17M | **476K** | 106M | 43.2M | 1.75M / 350K | 3.6M / 360K |
| Jungle | Ancient Worldroot | Mythic | 6 x 134s | 1.46M | **469K** | 235M | 75.6M | 4.38M / 875K | 6.3M / 630K |
| Desert | Prickly Pear | Uncommon | 3 x 82s | 800K | **437K** | 105M | 57.6M | 1.2M / 240K | 4.8M / 480K |
| Desert | Dune Lotus | Mythic | single, 270s | 180M | **15M** | once | once | 15M / 3M | 7.5M / 750K |
| Desert | Mirage Fig | Cosmic | 5 x 231s | 40M | **27.7M** | 3.12B | 2.16B | 100M / 20M | 180M / 18M |
| Desert | Solar Starfruit | King | 5 x 255s | 70M | **255M** | 4.94B | 18B | 175M / 35M | 1.5B / 150M |
| Desert | Dune Starfruit | Secret | 1 x 528s | 250M | **106M** | 1.7B | 723M | 125M / 25M | 60M / 6M |
| Snow | Snow Melon | Uncommon | 2 x 132s | 4.5M | **3.17M** | 245M | 173M | 4.5M / 900K | 14.4M / 1.44M |
| Snow | Iceberry | Rare | 4 x 165s | 4.5M | **3.09M** | 393M | 270M | 9M / 1.8M | 22.5M / 2.25M |
| Snow | Aurora Lily | Legendary | single, 330s | 270M | **72M** | once | once | 22.5M / 4.5M | 36M / 3.6M |
| Snow | Glacier Lotus | Mythic | 1 x 198s | 112M | **41.6M** | 2.05B | 756M | 56.2M / 11.2M | 63M / 6.3M |
| Snow | Silent Frostbell | Secret | 3 x 312s | 112M | **62.4M** | 3.89B | 2.16B | 169M / 33.8M | 180M / 18M |
| Snow | Polar Starbloom | Cosmic | 1 x 344s | 600M | **619M** | 6.28B | 6.48B | 300M / 60M | 540M / 54M |
| Snow | Winter Crownwood | King | 6 x 377s | 150M | **943M** | 8.59B | 54B | 450M / 90M | 4.5B / 450M |
| Lava | Fire Pepper | Rare | 4 x 198s | 18M | **12.4M** | 1.31B | 902M | 36M / 7.2M | 75M / 7.5M |
| Lava | Ember Pumpkin | Rare | 2 x 231s | 36M | **28.9M** | 1.12B | 901M | 36M / 7.2M | 75M / 7.5M |
| Lava | Ash Tomato | Rare | 4 x 264s | 18M | **16.5M** | 982M | 900M | 36M / 7.2M | 75M / 7.5M |
| Lava | Lava Lotus | Legendary | single, 540s | 900M | **240M** | once | once | 75M / 15M | 120M / 12M |
| Lava | Obsidian Maw | Secret | 1 x 393s | 1B | **786M** | 9.16B | 7.2B | 83.3M / 16.7M | 600M / 60M |
| Lava | Boom Bloom | Cosmic | 1 x 434s | 1.5B | **2.6B** | 12.4B | 21.6B | 750M / 150M | 1.8B / 180M |
| Lava | Ember Emperor | King | 6 x 475s | 400M | **3.96B** | 18.2B | 180B | 1.2B / 240M | 15B / 1.5B |
| Crystal | Amethyst Grape | Rare | 4 x 330s | 75M | **61.9M** | 3.27B | 2.7B | 150M / 30M | 225M / 22.5M |
| Crystal | Prism Pepper | Rare | 4 x 396s | 75M | **74.3M** | 2.73B | 2.7B | 150M / 30M | 225M / 22.5M |
| Crystal | Moon Melon | Rare | 2 x 462s | 150M | **173M** | 2.34B | 2.7B | 150M / 30M | 225M / 22.5M |
| Crystal | Diamond Vine | Mythic | 4 x 660s | 350M | **347M** | 7.64B | 7.57B | 700M / 140M | 630M / 63M |
| Crystal | Hollow Geode | Secret | 1 x 474s | 1.5B | **2.84B** | 11.4B | 21.6B | 750M / 150M | 1.8B / 180M |
| Crystal | Orbit Lotus | Cosmic | 1 x 523s | 2.5B | **9.41B** | 17.2B | 64.8B | 1.25B / 250M | 5.4B / 540M |
| Crystal | Prism Monarch | King | 6 x 573s | 800M | **14.3B** | 30.2B | 539B | 2.4B / 480M | 45B / 4.5B |
| Storm | Spark Reed | Rare | 3 x 380s | 200M | **317M** | 5.68B | 9.01B | 300M / 60M | 750M / 75M |
| Storm | Thunder Tulip | Rare | 3 x 380s | 200M | **317M** | 5.68B | 9.01B | 300M / 60M | 750M / 75M |
| Storm | Volt Orchid | Legendary | 3 x 438s | 650M | **584M** | 16B | 14.4B | 975M / 195M | 1.2B / 120M |
| Storm | Tempest Lotus | Mythic | 1 x 496s | 3B | **3.47B** | 21.8B | 25.2B | 1.5B / 300M | 2.1B / 210M |
| Storm | Blackout Bloom | Secret | 1 x 554s | 5B | **11.1B** | 32.5B | 72.1B | 2.5B / 500M | 6B / 600M |
| Storm | Pulsar Starfruit | King | 5 x 613s | 2.5B | **61.3B** | 73.4B | 1.8T | 6.25B / 1.25B | 150B / 15B |
| Storm | Storm Sovereign | Cosmic | 6 x 670s | 1.5B | **6.7B** | 48.4B | 216B | 4.5B / 900M | 18B / 1.8B |
| Mech | Plasma Pepper | Legendary | 3 x 150s | 250M | **200M** | 18B | 14.4B | 375M / 75M | 1.2B / 120M |
| Mech | Holo Melon | Mythic | 1 x 240s | 1.5B | **1.68B** | 22.5B | 25.2B | 750M / 150M | 2.1B / 210M |
| Mech | Prism Lotus | Mythic | 1 x 300s | 2B | **2.1B** | 24B | 25.2B | 1B / 200M | 2.1B / 210M |
| Mech | Holo Apple Tree | Secret | 4 x 420s | 1B | **2.1B** | 34.3B | 72B | 2B / 400M | 6B / 600M |
| Mech | Nebula Vine | Cosmic | 3 x 600s | 2.5B | **8B** | 45B | 144B | 3.75B / 750M | 12B / 1.2B |
| Mech | Crowncore Tree | King | 1 x 450s | 10B | **45B** | 80B | 360B | 5B / 1B | 30B / 3B |

### What an average pack is worth, per biome (no boots / Thunder boots)

Garden income the pack adds (cash per hour if every fruit is picked), plus one-off single-harvest cash.

| Biome | now: adds /h | now: one-off | proposed: adds /h | proposed: one-off |
|---|---|---|---|---|
| Forest | 20.7M / 44.3M | 867K / 1.32M | 6.21M / 9.42M | 347K / 529K |
| Jungle | 56.3M / 99.8M | 0 / 0 | 24.8M / 37.8M | 0 / 0 |
| Desert | 62.5M / 217M | 78.7M / 102M | 33.7M / 121M | 6.56M / 8.49M |
| Snow | 364M / 1.03B | 38.7M / 48M | 211M / 583M | 10.3M / 12.8M |
| Lava | 967M / 1.59B | 147M / 278M | 766M / 1.55B | 39.3M / 74.2M |
| Crystal | 3.8B / 5.72B | 0 / 0 | 3.74B / 7.53B | 0 / 0 |
| Storm | 8.22B / 14.1B | 0 / 0 | 10.9B / 23.1B | 0 / 0 |

### Prices and buy times (median active hours, 40 simulated players)

| Item | Effect | Price now | Bought at (now) | **Proposed price** | Target | Bought at (proposed) |
|---|---|---|---|---|---|---|
| Machine 2 (Jungle) | x4 training | 250K | 5 min | **150K** | 5 min | 5 min |
| Machine 3 (Desert) | x20 training | 11.9M | 15 min | **85M** | 30 min | 30 min |
| Machine 4 (Snow) | x100 training | 562M | 40 min | **1.5B** | 1.5 h | 1.5 h |
| Machine 5 (Lava) | x600 training | 26.7B | 2.9 h | **45B** | 5.0 h | 5.1 h |
| Machine 6 (Crystal) | x4000 training | 1.27T | 11.5 h | **2.5T** | 15.0 h | 15.4 h |
| Machine 7 (Storm) | x30000 training | 60T | 57.9 h | **60T** | 40.0 h | 42.2 h |
| Mint trail | x1.5 training | 200K | 5 min | **5M** | 9 min | 10 min |
| Arc trail | x2 training | 10.4M | 15 min | **130M** | 45 min | 45 min |
| Solar trail | x3 training | 538M | 30 min | **10B** | 3.0 h | 2.9 h |
| Aurora trail | x4 training | 27.9B | 3.5 h | **600B** | 10.0 h | 9.3 h |
| Nebula trail | x5 training | 1.45T | 14.3 h | **20T** | 30.0 h | 29.1 h |
| Royal trail | x6 training | 75T | 79.8 h | **150T** | 80.0 h | 79.3 h |
| Sand boots | x50 luck | 750K | 10 min | **12M** | 18 min | 15 min |
| Frost boots | x500 luck | 64.1M | 20 min | **2.5B** | 2.0 h | 2.0 h |
| Lava boots | x20K luck | 5.48B | 1.5 h | **200B** | 8.0 h | 7.6 h |
| Crystal boots | x1M luck | 468B | 6.5 h | **13T** | 25.0 h | 23.9 h |
| Thunder boots | x50M luck | 40T | 40.3 h | **150T** | 70.0 h | 60.9 h |
| Fence 2 (Mossy Cobble) | 0.8% faster; proposed +8% sell | 500K | 10 min | **12M** | 15 min | 20 min |
| Fence 3 (Dune Stone) | 1.7% faster; proposed +16% sell | 18M | 20 min | **200M** | 1.0 h | 1.0 h |
| Fence 4 (Frostwall) | 2.5% faster; proposed +24% sell | 646M | 50 min | **25B** | 4.0 h | 3.8 h |
| Fence 5 (Prismwall) | 3.3% faster; proposed +32% sell | 23.2B | 2.3 h | **1T** | 12.0 h | 11.3 h |
| Fence 6 (Emberwall) | 4.2% faster; proposed +40% sell | 835B | 8.7 h | **30T** | 35.0 h | 34.2 h |
| Fence 7 (Stormline) | 5.0% faster; proposed +48% sell | 30T | 28.3 h | **160T** | 90.0 h | 99.5 h |

### Milestones (median active hours)

| Milestone | now | proposed |
|---|---|---|
| reach Jungle | 5 min | 5 min |
| reach Desert | 15 min | 15 min |
| reach Snow | 35 min | 55 min |
| reach Lava | 1.4 h | 2.5 h |
| reach Crystal | 4.2 h | 6.4 h |
| reach Storm | 13.6 h | 17.3 h |
| first Mythic | 10 min | 10 min |
| first Secret | 1.9 h | 2.5 h |
| first Cosmic | 7.6 h | 18.2 h |
| first King | 57.1 h (90% of players by 100 h) | 76.3 h (82% by 100 h) |

### Active player after 1 / 5 / 20 / 50 / 100 hours (medians)

| Hours | | Cash on hand | Earned total | Machine | Trail | Boots | Fence | Top biome | Speed | Packs opened |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | now | 989M | 2.84B | 4/7 | 3/6 | 2/5 | 4/7 | Snow | 108 | 45 |
| 1 | **proposed** | 128M | 507M | 3/7 | 2/6 | 1/5 | 3/7 | Snow | 89 | 46 |
| 5 | now | 135B | 220B | 5/7 | 4/6 | 3/5 | 5/7 | Crystal | 248 | 207 |
| 5 | **proposed** | 28.9B | 83.2B | 4/7 | 3/6 | 2/5 | 4/7 | Lava | 187 | 201 |
| 20 | now | 7.87T | 12T | 6/7 | 5/6 | 4/5 | 6/7 | Storm | 414 | 906 |
| 20 | **proposed** | 4.67T | 9.05T | 6/7 | 4/6 | 3/5 | 5/7 | Storm | 388 | 884 |
| 50 | now | 32.9T | 107T | 6/7 | 5/6 | 5/5 | 7/7 | Storm | 485 | 2346 |
| 50 | **proposed** | 63.2T | 191T | 7/7 | 5/6 | 4/5 | 6/7 | Storm | 500 | 2324 |
| 100 | now | 70.7T | 280T | 7/7 | 6/6 | 5/5 | 7/7 | Storm | 500 | 4746 |
| 100 | **proposed** | 87.4T | 592T | 7/7 | 6/6 | 5/5 | 7/7 | Storm | 500 | 4724 |

### Sensitivity (proposed economy; median hours to reach Storm / buy Thunder boots / buy Machine 7 / buy Royal)

| Assumption | Storm | Thunder | Machine 7 | Royal | Cash at 100 h |
|---|---|---|---|---|---|
| baseline (share 0.6, 75 s garden + 60 s treadmill per 5 min, 1 fruit/s) | 17.6 h | 61.5 h | 42.3 h | 79.8 h | 93.2T |
| speed pass (x2 training) | 14.8 h | 58.5 h | 40.2 h | 76.8 h | 73.3T |
| growth pass (x2 growth) | 16.2 h | 50.9 h | 37.1 h | 64.4 h | 248T |
| lazy harvester (0.5 fruit/s) | 21.4 h | 84.2 h | 54.3 h | >100 h | 78T |
| busy server (share 0.3) | 17.8 h | 71.5 h | 50.3 h | 93.4 h | 58.8T |
| solo server (share 1.0) | 17.9 h | 57.8 h | 41.3 h | 74.5 h | 98.5T |
| garden focus (150 s garden) | 18.2 h | 58.6 h | 44.7 h | 70.0 h | 348T |

**Reading the tables:**
- The proposed prices are the tuner's output (`proposal.py`, `proposed_prices.json`) rounded to 1-2 significant figures.
- Prices go up everywhere except Machine 2 and Machine 7. Early items go up the most (x20-x60), because early income used to cover them many times over.
- Late-game income in the proposal is higher than today, because Storm plants and Kings are worth more and the fence adds up to +48%. So the top prices go up only 1-4x.
- Late treadmills (Machine 6-7) now come *before* the late boots. You reach 500 speed around 50 h, then the long goals are Thunder Boots (~60 h), Royal (~80 h) and Stormline (~100 h).

## What implementation would touch (next round, after approval)

- **`EconomyBalance90.lua`:**
  - `FruitValues` for all 46 map seeds + 6 Mech seeds (the proposed column above).
  - `MachineCosts`, `TrailCosts`, `BootCosts`, `FenceCosts` become explicit lists instead of `Scale.Curve`.
  - Raise `MaxBaseFruitValue` 10B -> 100B (the display text; Pulsar Starfruit is 61B a fruit).
- **`EconomyBalance90.Apply`** scales `IndexFirst`/`IndexRepeat` by `new/old` value. The proposal sets them directly (R x 300 s / R x 30 s) instead.
- **Single-harvest values:** `PlantCatalog.lua:133` sets `SingleHarvestBonus=6`. The values here are final sell values, so check the bonus is display-only.
- **Fence (if decision 2 is yes):**
  - `GardenFenceRules` gets a `Value(tier)` = 1 + 0.08 x (tier-1).
  - It is applied where fruit value is computed (`PlantRules.Fruit` / `WeatherTraits.Price` caller), so previews and sales agree.
  - The planted size bonus stays.
- **Save effects:**
  - Growing plants use the new values right away (`PlantRules.lua:63`). Harvested fruit in bags keeps its saved value.
  - Owned items stay owned.
  - Cash balances are not touched. Existing rich players will be able to buy the next item right away, which is harmless since prices only go up.

## Open decisions for the owner

1. **Tier multipliers.** Should King be x500 (a King plant ~ doubles a late garden) or bigger/smaller?
   - Is x60 for Cosmic and x20 for Secret right?
   - With Thunder boots a King comes about every 1,000 Storm packs (~20 h).
2. **Fence rework:** +8% sell value per tier (up to +48%)? Or keep the fence as a cosmetic wall and make it cheap (a few minutes each)?
3. **Dune Lotus:** price it as a Rare (proposed)? Or keep it a Mythic value and add a Desert Rare/Legendary seed later, which would fix the odds flow at the source?
4. **Late-game sink** after ~100 h (income ~8T/h). Options:
   - leave gems at 1T each;
   - make gem conversion cheaper late;
   - add a rebirth/prestige, or more fence/boot tiers.
   No change is proposed yet.
5. **Robux/gem items (not changed here):**
   - Cash bundles (+30B...+1.4T) are strong at 2-10 h and useless after 30 h. Scale them to the player's income (the unused `EconomyScaling91.CashQuote` already does this)?
   - The +25M speed bundle skips 4 biomes for a new player.
   - Should the Mech King stay at 100x (45B a fruit, below a Storm King's 61B)?
6. **Speed pass:** doubling training barely changes progress now (Storm 17.6 h -> 14.8 h). Is that fine, or should it do something else?
7. **Target times:**
   - Storm ~17 h, Thunder Boots ~60 h, everything owned ~100 h of active play. Longer or shorter?
   - A "busy server" player (fewer packs) is ~15% slower. A slow harvester (0.5 fruit/s) needs ~85 h for Thunder Boots.
