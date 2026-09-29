# R110 balancing proposal: rarity ladder, boot luck, speed

**Status: proposal only.** Nothing in the game or in `src/` was changed. Nothing was run in Studio.
Tags used below: **[live]** = read from the R107 scripts or computed by running the real game modules (Luau, mocked Roblox APIs);
**[proposal]** = computed from the proposed rules; **[sim]** = rough simulator, see "Assumptions" (treat as +/- 2x).

## In short

- **Rarer top tiers, with a clear ladder.** In a basic (Common) pack with no boots: Secret **1 in 10K**, Cosmic **1 in 1M**, King **1 in 100M**,
  plus two new tiers on top: **Divine 1 in 1T** and **Eternal 1 in 1Qa**. Better packs and better boots divide these numbers.
  Common to Legendary stay close to today; Mythic gets somewhat rarer (1 in 77 -> 1 in 200 in a Common pack).
- **Two existing seeds become the new top tiers** (no new art): Prism Monarch (Crystal) becomes Divine, Pulsar Starfruit (Storm) becomes Eternal.
- **Boots get a real hierarchy:** x2, x5, x20, x100, x500 (today x1.15 to x2, and luck is capped at 2). Prices stay as they are.
- **What it feels like** for an active late-game player (~70 packs/hour):
  no boots: a Secret every ~7 h. Electric boots: Secret every ~15 min, Cosmic every ~2 h, King every ~140 h.
  Divine and Eternal are effectively never: even 1,000 players all in Electric boots would see a Divine about once every 2 months, and an Eternal about once every 160 years.
  That is normal for "1 in 1T+" items in Roblox RNG games, but players should be told.
  Today, by comparison, a King drops about every 2 hours and a Secret within the first half hour.
- **Speed:** each biome's keeper is 1.6x faster than the last, you need 10% more speed than the keeper to farm a biome, and each step
  takes 1, 3, 6, 10, 20, then 40 minutes of treadmill on that biome's machine. The first hour gets slower (Lava at ~1.6 h instead of ~40 min).
  The 7-hour treadmill wall before Storm goes away (Storm at ~16 h instead of ~33 h). Storm needs 363 speed instead of 440, which is easier on
  Roblox physics. Players at 100B+ points keep 500.
- **Decide before building** (details in section 7): King 1 in 100M or 1 in 1B; which seeds become Divine/Eternal; whether index "100%" should
  still require these near-impossible seeds; whether players between 1K and 10M points may get a little slower.

## 1. How it works today [live]

**Pack odds** (`ReplicatedStorage/PackOdds81.lua:4-25`, called from `SeedPackRules.lua:351-374` for packs with `OddsVersion` 81):
1. Start from `BalanceValues81.SeedWeights[pack]` (8 tiers, each pack sums to 100) (`BalanceValues81.lua:2`).
2. A tier with no seed in the biome passes its weight **up** to the next tier that exists (`PackOdds81.lua:10-16`).
3. Luck: `luck = clamp(luck, 1, 3.5)` (`:18`), then Secret/Cosmic/King weights x `luck`, Legendary/Mythic x `1 + 0.5*(luck-1)`, lower tiers x1 (`:20`).
   The Void (event) pack skips luck (`:19`).
4. Seeds of the same tier split that tier's weight evenly (`:23`). The roll is one `Random:NextNumber()` (`ChestService.lua:983` -> `PlayerDataService.lua:387`).

**Where luck comes from:** the **best owned** boot (not the equipped one), clamped to **1..2** (`PlayerDataService.lua:620-636`, clamp at `:634`),
stored in the `ChestLuckMultiplier` attribute. It is recomputed on load, not saved, so changing boot values needs no save migration
(this corrects item 7 in HANDOFF's review list). The HUD also clamps to 2 (`WorldStatusHud.lua:10`), and the owner `odds` command only accepts luck 1-2 (`OwnerUpdateCommands82.lua:136`).

**Boots** (`Config.lua:255-259`, values replaced at `Config.lua:740`):

| Boot (Id) | Biome | Price | Luck | Effect today with luck applied |
|---|---|---|---|---|
| Sand Boots (RunnerHalo) | Desert | 750K | x1.15 | Secret/Cosmic/King x1.15, Legendary/Mythic x1.075 |
| Frost Boots (StormCrown) | Snow | 64.1M | x1.3 | x1.3 / x1.15 |
| Lava Boots (LavaBoots) | Lava | 5.48B | x1.5 | x1.5 / x1.25 |
| Crystal Boots (CrystalBoots) | Crystal | 468B | x1.75 | x1.75 / x1.375 |
| Electric Boots (MythicOrbit) | Storm | 40T | x2 | x2 / x1.5 |

Prices come from `EconomyScaling91.Curve(750K, 40T, 5)` (`EconomyBalance90.lua:9`). The `BootCosts` line at `BalanceValues81.lua:14` is dead: `EconomyBalance90.Apply` at `:16` overwrites it.
Luck values: `BalanceValues81.lua:10`.

**Pack tiers and supply:** 6 pack tiers (named Common, Uncommon, Rare, Epic, Legendary, Mythic in `SeedPackRules.PackTiers`) spawn at
37.9 / 25 / 15 / 7 / 10 / 5 % (`RouteBalance83.lua:5`, plus the every-5th / every-10th refresh floors in `PackSchedule81.lua:15-16`; exact average computed by running that code).
There are 5 packs per biome, 35 per server, refreshed every 300 s (`SeedPackRules.lua:6-8`). The server has 6 bases, so up to 6 players share them. You carry one pack per run.
Every pack you open also pays index cash (`IndexFirst` the first time, `IndexRepeat` after that; `PremiumProgress.lua:226`).

**Seeds:** 46 obtainable seeds; full list with tiers and odds in table T6. Stage minimum tiers: Forest/Jungle Common, Desert/Snow Uncommon, Lava/Crystal/Storm Rare (`SeedPackRules.lua:127`).

**Speed** (`Progression81.lua:7-19`, `BalanceValues81.lua:7-9`):
- Speed = `PointCurve(points)`: knots `{0,24},{800,30},{3K,38},{10K,48},{50K,64},{300K,82},{2M,110},{20M,155},{500M,215},{20B,350},{100B,500}`.
  Interpolation is linear below 2M and logarithmic from 2M. After 100B, speed grows only +0.1 per 10x points.
- WalkSpeed = that speed on the track, x0.4 inside the base area (`RunnerMotion.lua:2,9-14`). No cap (`Config.lua:733`).
- Treadmill: 100 points/s (`Config.lua:733`) x machine (x1, 4, 20, 100, 600, 4K, 30K) x trail (x1.5 to x6) x2 with the speed pass
  (`BalanceRules.lua:17-19`, `BaseService.lua:528-533`). It ticks 6 times a second in whole multiples of 5 points (`Config.lua:112,311-316`). You must stand on it (you are anchored).
- Keepers (`RouteBalance83.lua:4`, used by `KeeperPursuit.lua:11-18`): a keeper runs at its "close" speed when within 35 studs of you, speeds up to "mid" at 100 studs
  and "far" at 250+. If you are faster than "close", it can never catch you, and it settles some distance behind you (table S1).

**Things noticed while mapping** [live]:
- The effective max luck is 2, and it is clamped in three places with different limits (2, 3.5, 2).
- Desert has no Rare or Legendary seed, so their share flows up into Dune Lotus (Mythic): about **1 in 2** Desert pulls. Dune Lotus is a 180M single-harvest crop,
  which is why the early game prints money.
- Lava has no Mythic seed, so Mythic's share flows up into Obsidian Maw (Secret): Lava's "Secret" is about **1 in 8.5** today, versus about 1 in 29 elsewhere.
- Treadmill pacing has a wall at the end: on the machine named for your biome, going Lava to Crystal takes 72 min and Crystal to Storm takes **7 hours** (table S2).
- `OddsText85.lua:6` already prints exact "1/N" up to N = 1e15, so the odds UI can show 1/1Qa.

## 2. Proposal: rarity ladder [proposal]

**Data (replaces `SeedWeights`).** Integer weights that sum to 100 cannot sensibly hold 1e-15. Plain floats could, but "1 in N" is readable and matches the odds UI. So each pack gets a
**"1 in N" per tier**, and the pack's lowest tier is "the rest" (table T2). The top tiers follow one ladder: Common-pack value divided by the pack's built-in luck
(x1, 2.5, 6, 20, 60, 200).

**Boot luck rule.** chance = min( max(base, cap), base x luck^power ).
- power: Uncommon/Rare 0 (boots don't touch them), Legendary 0.2, Mythic 0.4, Secret 0.7, Cosmic/King/Divine/Eternal 1.
  So "x500 luck" is exactly x500 on Cosmic and up, and smaller on the middle tiers. This is the same idea as today's code, where Legendary/Mythic get half the luck.
- caps: Legendary 50%, Mythic 45%, Secret 25%, Cosmic 5%, King 1%, Divine/Eternal 0.1% (only the best packs with the best boots ever reach a cap).
- **Commons don't vanish:** a pack's lowest tier keeps at least 40% of its no-boot share. If boots would push it lower, the middle tiers give back first
  (Legendary, then Mythic, then Secret, each keeping at least half its normal share). Cosmic and up are never touched.
- A tier with no seed in a biome: Common..Mythic pass their share up as today, but **never into Secret or above**. Secret and above are simply not rolled there.
  This keeps "1 in 1Qa" true in every biome. It also means Lava's Obsidian Maw drops from ~1 in 8.5 to the normal Secret rate.
- Same-tier seeds in a biome split the chance evenly (as today). Luck max = 500, kept in one place (`BalanceValues81.MaxLuck`).

**Rolling 1-in-1Qa safely.** One `Random:NextNumber()` may not have enough random bits for 1e-15. Its resolution is not documented, and a 32-bit draw can't
go below ~2e-10. So roll **rarest tier first**, each with its conditional chance, and test tiny chances in stages
(for example "draw < 1e-5" several times, then the remainder). That is exact whatever the draw resolution.
Luau reference: `scratchpad/balance/PackOdds110_draft.luau` (`O.Chance`, `O.RollTier`).

### T2. Proposed per-pack odds, no boots (this is the data table that replaces `SeedWeights`)

Lowest tier of each pack = "rest". Pack spawn mix unchanged: Common 37.9%, Uncommon 25.0%, Rare 15.0%, Epic 7.0%, Legendary 10.0%, Mythic 5.0%.

| Pack (spawn %) | Uncommon | Rare | Legendary | Mythic | Secret | Cosmic | King | Divine | Eternal |
|---|---|---|---|---|---|---|---|---|---|
| Common (38%) - rest=Common 59% | 1/4 | 1/8 | 1/30 | 1/200 | 1/10K | 1/1M | 1/100M | 1/1T | 1/1Qa |
| Uncommon (25%) - rest=Common 39% | 1/3 | 1/5 | 1/15 | 1/80 | 1/4K | 1/400K | 1/40M | 1/400B | 1/400T |
| Rare (15%) | rest (42%) | 1/2.5 | 1/7 | 1/30 | 1/1.67K | 1/167K | 1/16.7M | 1/167B | 1/167T |
| Epic (7%) | - | rest (56%) | 1/3 | 1/10 | 1/500 | 1/50K | 1/5M | 1/50B | 1/50T |
| Legendary (10%) | - | rest (34%) | 1/2.5 | 1/4 | 1/167 | 1/16.7K | 1/1.67M | 1/16.7B | 1/16.7T |
| Mythic (5%) | - | - | rest (58%) | 1/2.5 | 1/50 | 1/5K | 1/500K | 1/5B | 1/5T |

For comparison, today's Mythic pack is Legendary 20% / Mythic 45% / Secret 22% / Cosmic 10% / King 3%.

### T1. Tier ladder (a biome that has every tier; averaged over the real pack spawn mix)

| Tier | Now: Common pack, no boots | Now: avg pack, no boots | Now: avg pack, best boots (x2) | Proposed: Common pack, no boots | Proposed: avg pack, no boots | Proposed: avg pack, best boots (x500) |
|---|---|---|---|---|---|---|
| Common | 1 in 1.82 | 1 in 3.69 | 1 in 3.84 | 1 in 1.7 | 1 in 3.13 | 1 in 4.85 |
| Uncommon | 1 in 3.85 | 1 in 4.33 | 1 in 4.61 | 1 in 4 | 1 in 4.14 | 1 in 4.91 |
| Rare | 1 in 7.69 | 1 in 4.44 | 1 in 5.02 | 1 in 8 | 1 in 4.32 | 1 in 5.35 |
| Legendary | 1 in 25 | 1 in 7.42 | 1 in 6.3 | 1 in 30 | 1 in 6.97 | 1 in 7.46 |
| Mythic | 1 in 76.9 | 1 in 12 | 1 in 11.2 | 1 in 200 | 1 in 16.1 | 1 in 5.03 |
| Secret | 1 in 200 | 1 in 29.4 | 1 in 21 | 1 in 10K | 1 in 515 | 1 in 15.8 |
| Cosmic | 1 in 667 | 1 in 64.8 | 1 in 47 | 1 in 1M | 1 in 51.5K | 1 in 139 |
| King | 1 in 2K | 1 in 211 | 1 in 154 | 1 in 100M | 1 in 5.15M | 1 in 10.3K |
| Divine | (new) | - | - | 1 in 1T | 1 in 51.5B | 1 in 103M |
| Eternal | (new) | - | - | 1 in 1Qa | 1 in 51.5T | 1 in 103B |

Legendary dips slightly with top boots because some of those rolls upgrade to Mythic or better; the chance of "X or better" never drops (T5).

### T5. Safety checks (computed over all 7 biomes x 6 packs x 6 boot levels)

- "Better boots / better pack never lowers the chance of getting tier X or better": 4200 comparisons, 0 violations.
- Every table sums to 1 (asserted). Smallest share left for a pack's lowest tier: 13.8% (Snow Legendary pack, Frost boots).

### T6. Every seed: tier and odds (average over the pack spawn mix)

| Biome | Seed | Tier now -> proposed | Now, no boots | Now, best boots | Proposed, no boots | Proposed, Electric x500 |
|---|---|---|---|---|---|---|
| Forest | Watermelon | Common | 1 in 3.69 | 1 in 3.82 | 1 in 3.13 | 1 in 4.78 |
| Forest | Blueberry | Uncommon | 1 in 4.33 | 1 in 4.58 | 1 in 4.14 | 1 in 4.91 |
| Forest | Apple | Rare | 1 in 8.88 | 1 in 9.91 | 1 in 8.62 | 1 in 10.7 |
| Forest | Mooncap | Rare | 1 in 8.88 | 1 in 9.91 | 1 in 8.62 | 1 in 10.7 |
| Forest | Sunflower | Legendary | 1 in 7.42 | 1 in 6.1 | 1 in 6.92 | 1 in 5.37 |
| Forest | Elderbloom | Mythic | 1 in 7.27 | 1 in 6.49 | 1 in 16.1 | 1 in 4.68 |
| Jungle | Cocoa | Common | 1 in 3.69 | 1 in 3.82 | 1 in 3.13 | 1 in 4.78 |
| Jungle | Pineapple | Uncommon | 1 in 4.33 | 1 in 4.58 | 1 in 4.14 | 1 in 4.91 |
| Jungle | Venom Vine | Rare | 1 in 8.88 | 1 in 9.91 | 1 in 8.62 | 1 in 10.7 |
| Jungle | Lantern Fern | Rare | 1 in 8.88 | 1 in 9.91 | 1 in 8.62 | 1 in 10.7 |
| Jungle | Tiger Orchid | Legendary | 1 in 7.42 | 1 in 6.1 | 1 in 6.92 | 1 in 5.37 |
| Jungle | Ancient Worldroot | Mythic | 1 in 7.27 | 1 in 6.49 | 1 in 16.1 | 1 in 4.68 |
| Desert | Prickly Pear | Uncommon | 1 in 1.99 | 1 in 2.28 | 1 in 1.78 | 1 in 2.58 |
| Desert | Dune Lotus | Mythic | 1 in 2.25 | 1 in 2.04 | 1 in 2.29 | 1 in 1.84 |
| Desert | Mirage Fig | Cosmic | 1 in 64.8 | 1 in 49.8 | 1 in 51.5K | 1 in 139 |
| Desert | Solar Starfruit | King | 1 in 211 | 1 in 163 | 1 in 5.15M | 1 in 10.3K |
| Desert | Dune Starfruit | Secret | 1 in 29.4 | 1 in 22.3 | 1 in 515 | 1 in 15.8 |
| Snow | Snow Melon | Uncommon | 1 in 1.99 | 1 in 2.09 | 1 in 1.78 | 1 in 2.58 |
| Snow | Iceberry | Rare | 1 in 4.44 | 1 in 5.02 | 1 in 4.32 | 1 in 5.35 |
| Snow | Aurora Lily | Legendary | 1 in 7.42 | 1 in 6.3 | 1 in 6.97 | 1 in 6.39 |
| Snow | Glacier Lotus | Mythic | 1 in 12 | 1 in 11.2 | 1 in 16.1 | 1 in 5.03 |
| Snow | Silent Frostbell | Secret | 1 in 29.4 | 1 in 21 | 1 in 515 | 1 in 15.8 |
| Snow | Polar Starbloom | Cosmic | 1 in 64.8 | 1 in 47 | 1 in 51.5K | 1 in 139 |
| Snow | Winter Crownwood | King | 1 in 211 | 1 in 154 | 1 in 5.15M | 1 in 10.3K |
| Lava | Fire Pepper | Rare | 1 in 4.12 | 1 in 4.49 | 1 in 3.6 | 1 in 4.72 |
| Lava | Ember Pumpkin | Rare | 1 in 4.12 | 1 in 4.49 | 1 in 3.6 | 1 in 4.72 |
| Lava | Ash Tomato | Rare | 1 in 4.12 | 1 in 4.49 | 1 in 3.6 | 1 in 4.72 |
| Lava | Lava Lotus | Legendary | 1 in 7.42 | 1 in 6.6 | 1 in 6.11 | 1 in 3.4 |
| Lava | Obsidian Maw | Secret | 1 in 8.51 | 1 in 6.46 | 1 in 515 | 1 in 15.8 |
| Lava | Boom Bloom | Cosmic | 1 in 64.8 | 1 in 50.8 | 1 in 51.5K | 1 in 139 |
| Lava | Ember Emperor | King | 1 in 211 | 1 in 167 | 1 in 5.15M | 1 in 10.3K |
| Crystal | Amethyst Grape | Rare | 1 in 4.12 | 1 in 4.43 | 1 in 3.79 | 1 in 5.57 |
| Crystal | Prism Pepper | Rare | 1 in 4.12 | 1 in 4.43 | 1 in 3.79 | 1 in 5.57 |
| Crystal | Moon Melon | Rare | 1 in 4.12 | 1 in 4.43 | 1 in 3.79 | 1 in 5.57 |
| Crystal | Diamond Vine | Mythic | 1 in 4.58 | 1 in 4.04 | 1 in 4.86 | 1 in 2.55 |
| Crystal | Hollow Geode | Secret | 1 in 29.4 | 1 in 21 | 1 in 515 | 1 in 15.8 |
| Crystal | Orbit Lotus | Cosmic | 1 in 64.8 | 1 in 47 | 1 in 51.5K | 1 in 139 |
| Crystal | Prism Monarch | King -> **Divine** | 1 in 211 | 1 in 154 | 1 in 51.5B | 1 in 103M |
| Storm | Spark Reed | Rare | 1 in 2.75 | 1 in 2.96 | 1 in 2.52 | 1 in 3.72 |
| Storm | Thunder Tulip | Rare | 1 in 2.75 | 1 in 2.96 | 1 in 2.52 | 1 in 3.72 |
| Storm | Volt Orchid | Legendary | 1 in 7.42 | 1 in 6.3 | 1 in 6.97 | 1 in 5.59 |
| Storm | Tempest Lotus | Mythic | 1 in 12 | 1 in 11.2 | 1 in 16.1 | 1 in 4.71 |
| Storm | Blackout Bloom | Secret | 1 in 29.4 | 1 in 21 | 1 in 515 | 1 in 15.8 |
| Storm | Pulsar Starfruit | King -> **Eternal** | 1 in 211 | 1 in 154 | 1 in 51.5T | 1 in 103B |
| Storm | Storm Sovereign | Cosmic | 1 in 64.8 | 1 in 47 | 1 in 51.5K | 1 in 139 |

**Void pack** (event, every 3rd refresh, no luck). Today it hands out a King 1 in 34, which would undercut the whole ladder. Proposed:

### T7. Void pack (event pack, every 3rd refresh, luck does not apply)

| Tier | Now | Proposed |
|---|---|---|
| Secret | 1 in 1.26 | rest |
| Cosmic | 1 in 5.91 | 1 in 20 |
| King | 1 in 33.5 | 1 in 20K |
| Divine | - | 1 in 200M |
| Eternal | - | 1 in 200B |

(Now: 99.5% direct roll x tier weight; 0.5% goes to a Mech roll. Proposed keeps the 0.5% Mech roll.)

The Mech limited pack (gems) has its own table and its King (Crowncore Tree) is 1 in 200 (`MechCatalog.lua`). It is left alone here, but see decision 6.

## 3. Proposal: boots [proposal]

Luck x2, x5, x20, x100, x500. Each boot is 2.5x to 5x the previous one, and the jumps grow toward the top. **Prices unchanged** (750K / 64.1M / 5.48B / 468B / 40T).
In the sim they already land near each boot's biome: Sand ~5 min, Frost ~20 min, Lava ~1.4 h, Crystal ~8 h, Electric ~80 h (table SIM1).
Each boot makes the next tier "farmable": no boots = Mythic, Lava boots = Secret under an hour, Crystal boots = Cosmic in a day's play, Electric = King as a long grind.

### T3. Boots: luck and what it buys (average pack; 72 packs/hour, active late-game player)

| Boot | Now luck | Proposed luck | Proposed: Mythic | Secret | Cosmic | King | Divine | Eternal |
|---|---|---|---|---|---|---|---|---|
| none | - | - | 1 in 16.1 (13 min) | 1 in 515 (7.2 h) | 1 in 51.5K (716 h) | 1 in 5.15M (~8.2 yr nonstop) | 1 in 51.5B (never: ~8e4 yr) | 1 in 51.5T (never: ~8e7 yr) |
| Sand | x1.15 | x2 | 1 in 12.8 (11 min) | 1 in 317 (4.4 h) | 1 in 25.8K (358 h) | 1 in 2.58M (~4.1 yr nonstop) | 1 in 25.8B (never: ~4e4 yr) | 1 in 25.8T (never: ~4e7 yr) |
| Frost | x1.3 | x5 | 1 in 9.98 (8 min) | 1 in 167 (2.3 h) | 1 in 10.3K (143 h) | 1 in 1.03M (~1.6 yr nonstop) | 1 in 10.3B (never: ~2e4 yr) | 1 in 10.3T (never: ~2e7 yr) |
| Lava | x1.5 | x20 | 1 in 8.05 (7 min) | 1 in 63.3 (53 min) | 1 in 2.58K (36 h) | 1 in 258K (3,578 h, ~5 months nonstop) | 1 in 2.58B (never: ~4e3 yr) | 1 in 2.58T (never: ~4e6 yr) |
| Crystal | x1.75 | x100 | 1 in 6.15 (5 min) | 1 in 27.8 (23 min) | 1 in 515 (7.2 h) | 1 in 51.5K (716 h) | 1 in 515M (never: ~8e2 yr) | 1 in 515B (never: ~8e5 yr) |
| Electric | x2 | x500 | 1 in 5.03 (4 min) | 1 in 15.8 (13 min) | 1 in 139 (1.9 h) | 1 in 10.3K (143 h) | 1 in 103M (never: ~2e2 yr) | 1 in 103B (never: ~2e5 yr) |

Current game for comparison (average pack, best boots x2): Mythic 1 in 11.2 (9 min), Secret 1 in 21 (17 min), Cosmic 1 in 47 (39 min), King 1 in 154 (2.1 h).

## 4. Proposal: speed [proposal]

Rules (easy to re-tune):
1. Keeper "close" speed x1.6 per biome: 20, 32, 50, 80, 128, 205, 330. "Mid" = x1.15, "far" = x1.3 (same shape everywhere).
2. The speed you need for a biome = keeper close speed x1.10: 24, 35, 55, 88, 141, 226, 363. At that speed the keeper settles ~75-80 studs behind you in every biome
   (today 64-100 studs, uneven).
3. Points for each step = 1, 3, 6, 10, 20, 40 minutes of treadmill on the machine named for your current biome (plus the trail one tier lower).
   Machines, trails, the 100 points/s base, and all prices stay as they are. Only `PointCurve` and `KeeperSpeeds` change (data only).
4. Keep `{100B, 500}` and the +0.1-per-10x tail, so nobody at the top loses speed.

### S1. Speed per biome (keeper = close / 100 studs / 250+ studs behind you)

| Biome | Keeper now | Keeper proposed | Speed you need now -> proposed (keeper close-speed x1.10) | Points for that, now -> proposed | Keeper settles this many studs behind you (now -> proposed) | Seconds base->camp at that speed (now -> proposed) |
|---|---|---|---|---|---|---|
| Forest | 20 / 22 / 25 | 20 / 23 / 26 | 24 -> 24 | 0 -> 0 | 100+ (keeps growing) -> 100+ (keeps growing) | 4.2 -> 4.2 |
| Jungle | 29 / 34 / 40 | 32 / 37 / 42 | 32 -> 35 | 1.32K -> 6K | 73 -> 74 | 12.7 -> 11.6 |
| Desert | 48 / 56 / 64 | 50 / 57 / 65 | 53 -> 55 | 22K -> 120K | 74 -> 81 | 18.1 -> 17.4 |
| Snow | 72 / 84 / 98 | 80 / 92 / 104 | 79 -> 88 | 261K -> 1.5M | 74 -> 78 | 21.5 -> 19.4 |
| Lava | 115 / 140 / 170 | 128 / 147 / 166 | 127 -> 141 | 4.65M -> 20M | 65 -> 79 | 21.0 -> 18.8 |
| Crystal | 220 / 270 / 320 | 205 / 236 / 266 | 242 -> 226 | 1.05B -> 300M | 64 -> 79 | 15.8 -> 16.9 |
| Storm | 400 / 450 / 520 | 330 / 379 / 429 | 440 -> 363 | 52.5B -> 5B | 87 -> 79 | 12.0 -> 14.5 |

### S2. Treadmill time for each step, on the machine named for the biome you are in (+ trail one tier lower)

| Step | Machine x trail | Gain/s | Treadmill time now | Treadmill time proposed |
|---|---|---|---|---|
| Forest -> Jungle | x1 x 1 | 100 | 0.2 min | 1.0 min |
| Jungle -> Desert | x4 x 1.5 | 600 | 0.6 min | 3.2 min |
| Desert -> Snow | x20 x 2 | 4K | 1.0 min | 5.8 min |
| Snow -> Lava | x100 x 3 | 30K | 2.4 min | 10.3 min |
| Lava -> Crystal | x600 x 4 | 240K | 72.3 min | 19.4 min |
| Crystal -> Storm | x4000 x 5 | 2M | 429.0 min | 39.2 min |

### S3. Points -> speed (existing saves keep their points; this is what they would run at)

| Saved points | 0 | 1K | 10K | 100K | 1M | 10M | 100M | 1B | 10B | 100B | 1T |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Speed now | 24 | 31 | 48 | 68 | 94 | 141 | 185 | 240 | 325 | 500 | 500 |
| Speed proposed | 24 | 26 | 36 | 51 | 76 | 112 | 192 | 285 | 395 | 500 | 500 |

Proposed `PointCurve` knots: {0,24}, {6000,35}, {120000,55}, {1500000,88}, {20000000,141}, {300000000,226}, {5000000000,363}, {100000000000,500} (tail +0.1 speed per 10x points after 100B, unchanged).

Players between about 1K and 10M saved points run 15-25% slower than today (e.g. 10K points: 48 -> 36, which is Jungle but no longer Desert; a few minutes of treadmill fixes it).
Players between 100M and 10B run faster.

## 5. Simulation results [sim]

### SIM1. Active-player progression (median of 40 simulated players, hours of active play)

| Milestone | Now (live R107) | Proposed odds+boots, today's speed | Proposed odds+boots+speed |
|---|---|---|---|
| reach Jungle | 5 min | 5 min | 5 min |
| reach Desert | 5 min | 5 min | 15 min |
| reach Snow | 15 min | 15 min | 35 min |
| reach Lava | 40 min | 45 min | 1.6 h |
| reach Crystal | 6.0 h | 6.4 h | 4.1 h |
| reach Storm | 33.2 h | 37.5 h | 16.0 h |
| buy Sand | 5 min | 5 min | 5 min |
| buy Frost | 10 min | 10 min | 20 min |
| buy Lava | 52 min | 1.1 h | 1.4 h |
| buy Crystal | 5.7 h | 8.9 h | 7.7 h |
| buy Electric | 74.8 h | 96.6 h | 82.4 h |
| last treadmill (x30000) | 125.9 h | 173.7 h | 159.9 h |
| first Rare seed | 0 min | 0 min | 0 min |
| first Legendary seed | 5 min | 5 min | 2 min |
| first Mythic seed | 5 min | 5 min | 8 min |
| first Secret seed | 25 min | 1.3 h | 2.0 h |
| first Cosmic seed | 45 min | 12.5 h | 11.5 h |
| first King seed | 1.3 h | not reached | 11.5 h (2% of runs) |
| first Divine seed | not reached | not reached | not reached |
| first Eternal seed | not reached | not reached | not reached |
| late-game packs/hour | 72 | 72 | 72 |

A run stops once everything is bought and Storm is reached, so "not reached" means not within that time (about 125-175 h).

### T4. Time to see a "1 in N" item (top-tier rule: full luck, so N is divided by pack luck x boot luck)

Average built-in pack luck for top tiers over the spawn mix = x19.4.

| Base 1 in N | No boots | Lava boots (x20) | Electric boots (x500) | Whole game, 1,000 players all with Electric boots |
|---|---|---|---|---|
| 1M (Cosmic) | 716 h | 36 h | 1.4 h | <1 min |
| 100M (King) | ~8.2 yr nonstop | 3,578 h, ~5 months nonstop | 143 h | 9 min |
| 1B (reference) | ~81.6 yr nonstop | ~4.1 yr nonstop | 1,431 h, ~2 months nonstop | 1.4 h |
| 1T (Divine) | never: ~8e4 yr | never: ~4e3 yr | never: ~2e2 yr | 1,431 h, ~2 months nonstop |
| 1Qa (Eternal) | never: ~8e7 yr | never: ~4e6 yr | never: ~2e5 yr | never: ~2e2 yr |

### SIM2. Sensitivity (proposed odds+boots+speed; median hours)

| Assumption changed | reach Storm | buy Crystal boots | buy Electric boots | first Secret | first Cosmic |
|---|---|---|---|---|---|
| baseline (share 0.6, overhead 15 s, garden 40, harvest 50%) | 16.0 h | 7.7 h | 82.3 h | 1.7 h | 12.0 h |
| crowded server: share 0.3 | 11.8 h | 8.3 h | 86.3 h | 2.0 h | 19.2 h |
| solo server: share 1.0 | 25.1 h | 9.5 h | 85.5 h | 1.7 h | 12.1 h |
| garden 20 plants | 21.7 h | 9.8 h | 137.9 h | 1.8 h | 13.7 h |
| garden 80 plants | 12.9 h | 6.8 h | 54.4 h | 1.8 h | 10.5 h |
| harvest efficiency 25% | 24.1 h | 11.4 h | 147.9 h | 1.3 h | 12.5 h |
| overhead 30 s per pack | 24.0 h | 9.5 h | 89.2 h | 2.1 h | 14.2 h |

### SIM3. Pack throughput at the speed you need for each biome (proposed speeds)

| Biome | Round trip + 15 s overhead | Max packs/hour if you take all 5 per refresh | ...if you get 3 of 5 |
|---|---|---|---|
| Forest | 23 s | 60 | 36 |
| Jungle | 38 s | 60 | 36 |
| Desert | 50 s | 60 | 36 |
| Snow | 54 s | 60 | 36 |
| Lava | 53 s | 60 | 36 |
| Crystal | 49 s | 60 | 36 |
| Storm | 44 s | 60 | 36 |

At the intended speeds every run is short enough to take all 5 packs of a biome before the next refresh, so the limit is pack supply (5 per biome per 300 s, shared by up to 6 players), not speed. Players also raid the biome below, so the sim sees ~70 packs/hour late game.

For reference, R108 (undone) went the other way on rarity: it made the rare tiers **more** common and capped boots at x5 [computed with the same formula]:

| Tier (avg pack) | Now, best boots x2 | R108 (undone), no boots | R108, best boots x5 |
|---|---|---|---|
| Mythic | 1 in 11.2 | 1 in 10.5 | 1 in 8.21 |
| Secret | 1 in 21 | 1 in 23.6 | 1 in 11.4 |
| Cosmic | 1 in 47 | 1 in 48.1 | 1 in 23.6 |
| King | 1 in 154 | 1 in 114 | 1 in 53.6 |

## 6. Assumptions (not verified in Studio)

- **Computed from real code** (ran the actual modules in Luau with mocked Roblox APIs): all current odds (1,890 values; the Python port matches to 5e-9 percentage points),
  pools, seed values and index cash, pack spawn mix, camp distances after all route transforms (Forest 100, Jungle 405, Desert 955, Snow 1705, Lava 2655, Crystal 3830, Storm 5280 studs from the base line).
- **Proposal math cross-checked**: the Luau draft and the Python model agree on all 1,212 tier probabilities (worst relative difference 2e-15).
  The staged roll was tested at 1e8 trials (3001 / 2974 / 3044 hits vs 3000 expected). "Better boot/pack never lowers the chance of tier X or better": 0 violations in 4,200 checks.
- **Sim assumptions** (all guesses): the player gets 60% of the 5 packs in each of the 2 best biomes they can outrun; 15 s overhead per pack (steal, dodge, open, plant);
  they need keeper close speed x1.10 to farm a biome; every seed is planted in a 40-plant garden (the worst plant is replaced) and harvested at 50% efficiency;
  time not spent raiding is spent on the treadmill; they buy the cheapest available machine/trail/boot; no speed pass, no Robux packs, no Void events, no fence bonus.
  Size, mutation and weather cash bonuses are ignored. Table SIM2 shows the swing: Electric boots at 54-148 h depending on garden assumptions.
- "Hours to see one" in T3/T4 uses 72 packs/hour (the sim's late-game rate).
- Physics safety at 360-500 WalkSpeed, keeper lunges and the 5.5-stud catch radius were not modeled.

## 7. Open decisions for the owner

1. **King: 1 in 100M (recommended) or 1 in 1B?** At 100M, a King is a long grind with Electric boots (~140 h). At 1B it becomes a lottery (~1,400 h), and the
   Desert/Snow/Lava index can't realistically be finished.
2. **Divine/Eternal seeds:** promote Prism Monarch and Pulsar Starfruit (no new art, but Crystal and Storm lose their King), or add two new seeds later.
   Tier names are placeholders.
3. **Index "100%" rewards** (`PremiumProgress.lua:211` needs every seed): with this proposal, Crystal and Storm can't be completed.
   Suggestion: count seeds up to Cosmic (or King) for the 20-gem reward, and show Divine/Eternal as bonus entries.
4. **Existing copies** of Prism Monarch / Pulsar Starfruit: rarity is looked up by seed ID, so they would show as Divine/Eternal at once. Keep that (fun collector items) or not?
5. **Unopened packs** banked before the update: keep today's odds (they keep `OddsVersion` 81, which the code already supports) or switch to the new ones.
6. **Void pack and Mech pack:** accept the Void table above; decide whether the gem-bought Mech pack may keep a 1 in 200 King.
7. **Speed:** OK to make the first hour slower and reach Storm sooner? OK that players with 1K-10M points get a bit slower?
8. **Boot sizes:** x2/x5/x20/x100/x500 OK? If you later add a luck gamepass or potions, they multiply with boots, so leave room (for example x2 max).
9. **Content gaps:** Desert has no Rare/Legendary seed and Lava has no Mythic. Leave them, or fill them later.
10. Optional: a cross-server announcement (MessagingService) when anyone rolls King or higher; that is where 1-in-1T items get their hype.

## 8. If approved: what would change (for the implementation pass, not done)

- Data: `BalanceValues81` (new `OneIn` table, `BootLuck`, `MaxLuck`, `PointCurve`, `KeeperSpeeds` override, Void table). `RouteBalance83.KeeperSpeeds` could also be edited directly.
- Odds/roll: a new `PackOdds110` (the draft rules), a new `OddsVersion` so old packs keep old odds, and a staged roll in `SeedPackRules.Roll`.
  `ChestService.lua:983` currently passes one number, so `OpenSeedPack` would take a draw function or a `Random` instead.
- Luck clamps: `PlayerDataService.lua:634`, `WorldStatusHud.lua:10`, `OwnerUpdateCommands82.lua:79,136`, `StudioTestHelp` text, all set to `MaxLuck`.
- New tiers need a name, color, reveal and rank everywhere tiers are listed: `SeedPackRules.Rarities/RarityOrder`, the R37 re-tier table (`SeedPackRules.lua:164`, `PlantCatalog`),
  `GardenTheme.Rarities`, `RarityRevealSequence`, `BalanceRules.RarityWeights`, `VoidPackOdds85`, `CropFilters`, `NoticeCopy83`, the `Hotbar` and `GamePassClient` scripts.
- Test in Studio: `/test odds <biome> <tier> <luck>` for every pack, the stochastic check above, and a fresh profile playthrough of the first hour.

## 9. Files

Scripts and raw outputs: `docs/proposals/R110_balance/`
(`bundle.py` runs the real modules in Luau; `data.py` live values; `current_odds.py` verified port; `proposed.py` the proposal; `sim.py` simulator;
`analysis.py` and `speed_sim_tables.py` produce `out_rarity.md`, `out_speed.md`, `out_sim.md`; `PackOdds110_draft.luau` Luau reference; `run_xcheck.luau` cross-check).
(Copied into the repo from the working folder.)
