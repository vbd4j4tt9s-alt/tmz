# R110 balancing proposal: rarity ladder, boot luck, speed

**Status: proposal only.** Nothing in the game or in `src/` was changed. Nothing was run in Studio.
Tags used below: **[live]** = read from the R107 scripts or computed by running the real game modules (Luau, mocked Roblox APIs);
**[proposal]** = computed from the proposed rules; **[sim]** = rough simulator, see "Assumptions" (treat as +/- 2x).

## In short

- **Rarer top tiers, with a clear ladder.** In a basic (Common) pack with no boots: Secret **1 in 10K**, Cosmic **1 in 1M**, King **1 in 100M**,
  plus two new tiers on top: **Divine 1 in 1T** and **Eternal 1 in 1Qa**. Better packs and better boots divide these numbers.
  Common to Mythic stay close to today.
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

**Pack odds** (`ReplicatedStorage/PackOdds81.lua:4-26`, called from `SeedPackRules.lua:351-374` for packs with `OddsVersion` 81):
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
- WalkSpeed = that speed on the track, x0.4 inside the base area (`RunnerMotion.lua:2,9-15`). No cap (`Config.lua:733`).
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

{{T2}}

{{T1}}

{{T5}}

{{T6}}

**Void pack** (event, every 3rd refresh, no luck). Today it hands out a King 1 in 34, which would undercut the whole ladder. Proposed:

{{T7}}

The Mech limited pack (gems) has its own table and its King (Crowncore Tree) is 1 in 200 (`MechCatalog.lua`). It is left alone here, but see decision 6.

## 3. Proposal: boots [proposal]

Luck x2, x5, x20, x100, x500. Each boot is 2.5x to 5x the previous one, and the jumps grow toward the top. **Prices unchanged** (750K / 64.1M / 5.48B / 468B / 40T).
In the sim they already land near each boot's biome: Sand ~5 min, Frost ~20 min, Lava ~1.4 h, Crystal ~8 h, Electric ~80 h (table SIM1).
Each boot makes the next tier "farmable": no boots = Mythic, Lava boots = Secret under an hour, Crystal boots = Cosmic in a day's play, Electric = King as a long grind.

{{T3}}

## 4. Proposal: speed [proposal]

Rules (easy to re-tune):
1. Keeper "close" speed x1.6 per biome: 20, 32, 50, 80, 128, 205, 330. "Mid" = x1.15, "far" = x1.3 (same shape everywhere).
2. The speed you need for a biome = keeper close speed x1.10: 24, 35, 55, 88, 141, 226, 363. At that speed the keeper settles ~75-80 studs behind you in every biome
   (today 64-100 studs, uneven).
3. Points for each step = 1, 3, 6, 10, 20, 40 minutes of treadmill on the machine named for your current biome (plus the trail one tier lower).
   Machines, trails, the 100 points/s base, and all prices stay as they are. Only `PointCurve` and `KeeperSpeeds` change (data only).
4. Keep `{100B, 500}` and the +0.1-per-10x tail, so nobody at the top loses speed.

{{S1}}

{{S2}}

{{S3}}

Players between about 1K and 10M saved points run 20-25% slower than today (e.g. 10K points: 48 -> 36, which is Jungle but no longer Desert; a few minutes of treadmill fixes it).
Players between 100M and 10B run faster.

## 5. Simulation results [sim]

{{SIM1}}

{{T4}}

{{SIM2}}

{{SIM3}}

For reference, R108 (undone) went the other way on rarity: it made the rare tiers **more** common and capped boots at x5 [computed with the same formula]:

{{R108}}

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
- New tiers need a name, color, reveal and rank everywhere tiers are listed: `SeedPackRules.Rarities/RarityOrder`, the R37 re-tier table (`SeedPackRules.lua:163`, `PlantCatalog`),
  `GardenTheme.Rarities`, `RarityRevealSequence`, `BalanceRules.RarityWeights`, `VoidPackOdds85`, `CropFilters`, `NoticeCopy83`, the `Hotbar` and `GamePassClient` scripts.
- Test in Studio: `/test odds <biome> <tier> <luck>` for every pack, the stochastic check above, and a fresh profile playthrough of the first hour.

## 9. Files

Scripts and raw outputs: `/tmp/claude-0/-home-user-tmz/3b81e797-bc5f-5803-9d1a-e4f30034f130/scratchpad/balance/`
(`bundle.py` runs the real modules in Luau; `data.py` live values; `current_odds.py` verified port; `proposed.py` the proposal; `sim.py` simulator;
`analysis.py` and `speed_sim_tables.py` produce `out_rarity.md`, `out_speed.md`, `out_sim.md`; `PackOdds110_draft.luau` Luau reference; `run_xcheck.luau` cross-check).
The scratchpad is temporary; copy it into the repo if you want to keep it.
