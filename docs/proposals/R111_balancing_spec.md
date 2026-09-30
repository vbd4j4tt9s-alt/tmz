# Balancing spec: rarity ladder, boot luck, speed, no base slow zone

**Status: implemented in `src/`, tested offline (Luau CLI + mocks), not run in Studio.** Code labels say **R112** because
R111 was used for the tutorial v2 release while this was being built; this file and `docs/proposals/R111_balance/`
keep the requested names. Checks: `docs/proposals/R111_balance/run_all.sh` (about 3 minutes).

## In short

- **King is 1 in 1 trillion** in a Common pack with no boots (Uncommon 1/400B, Rare 1/167B, Epic 1/50B, Legendary 1/16.7B,
  Mythic pack 1/5B). Secret 1/10K and Cosmic 1/1M in a Common pack. 8 tiers, no new tiers, every seed keeps its tier.
- **Boots:** Sand x5, Frost x50, Lava x2K, Crystal x100K, Electric x5M (shown like that in the HUD and the shop). King gets
  the full luck; lower tiers get a gentler share (luck^0.40 on Cosmic ... ^0.08 on Legendary), so Mythic/Secret/Cosmic feel
  like the approved proposal. **Electric boots: a King about every 143 hours of active play.** Crystal boots: ~7,200 h (a lottery).
- **Packs banked before the update keep their old odds** (and the old boot luck, x1.15 to x2). The gem Mech pack is unchanged.
- **Speed:** keepers x1.6 per biome, you need 10% more than the keeper. Every run from base to a camp takes 12 to 19 s at the
  speed you need (Forest 4 s). The first minute on the treadmill is front-loaded (26 at 5 s, 31 at 30 s, 35 at 1 min).
- **No more slow zone in the base:** everyone moves at full speed everywhere (a new player: 24 instead of 9.6). The anti-cheat
  reads the same single value, so client and server still agree (0 false corrections in the tests).

## Final tables

### F1. What players experience (Storm Peaks, average pack over the real spawn mix, 72 packs/hour)

Chance per pack of that tier **or better**, and average active time to see one.

| Boot (shown luck) | Mythic+ | Secret+ | Cosmic+ | King |
|---|---|---|---|---|
| none | 1 in 15.6 (13 min) | 1 in 510 (7.1 h) | 1 in 51.5K (716 h) | 1 in 51.5B (never) |
| Sand (x5) | 1 in 12.5 (10 min) | 1 in 324 (4.5 h) | 1 in 27.1K (376 h) | 1 in 10.3B (never) |
| Frost (x50) | 1 in 9.48 (8 min) | 1 in 170 (2.4 h) | 1 in 10.8K (150 h) | 1 in 1.03B (never) |
| Lava (x2K) | 1 in 7.05 (6 min) | 1 in 59.8 (50 min) | 1 in 2.46K (34 h) | 1 in 25.8M (~41 yr nonstop) |
| Crystal (x100K) | 1 in 4.99 (4 min) | 1 in 26.3 (22 min) | 1 in 515 (7.1 h) | 1 in 515K (7,156 h, ~10 months nonstop) |
| Electric (x5M) | 1 in 3.57 (3 min) | 1 in 14.4 (12 min) | 1 in 141 (2.0 h) | **1 in 10.3K (143 h)** |

Same numbers in Desert/Snow/Lava/Crystal for Secret+ and up (each has one King seed). Forest/Jungle have no Secret+ seeds.

### F2. Per-pack odds, no boots (the lowest tier of each pack gets the rest)

| Pack | Uncommon | Rare | Legendary | Mythic | Secret | Cosmic | King | King with Electric |
|---|---|---|---|---|---|---|---|---|
| Common | 1/4 | 1/8 | 1/30 | 1/200 | 1/10K | 1/1M | 1/1T | 1/200K |
| Uncommon | 1/3 | 1/5 | 1/15 | 1/80 | 1/4K | 1/400K | 1/400B | 1/80K |
| Rare | rest | 1/2.5 | 1/7 | 1/30 | 1/1.67K | 1/167K | 1/167B | 1/33.3K |
| Epic | - | rest | 1/3 | 1/10 | 1/500 | 1/50K | 1/50B | 1/10K |
| Legendary | - | rest | 1/2.5 | 1/4 | 1/167 | 1/16.7K | 1/16.7B | 1/3.33K |
| Mythic | - | - | rest | 1/2.5 | 1/50 | 1/5K | 1/5B | 1/1K |

Boot rule: chance = min(max(base, cap), base x luck^power). Power: King 1, Cosmic 0.40, Secret 0.28, Mythic 0.16,
Legendary 0.08, lower 0. Caps: Legendary 50%, Mythic 45%, Secret 25%, Cosmic 5%, King 1%. The pack's lowest tier keeps at
least 40% of its no-boot share (Legendary, then Mythic, then Secret give back first; Cosmic and King are never touched).
A tier missing from a biome passes its share up to the next tier up to Mythic, never into Secret+.

**Void (event) pack:** 1/200 Mech branch as before, then King 1 in 200M, Cosmic 1 in 20, Secret the rest (overall King
1 in 201M, Cosmic 1 in 20.1). Was King 1 in 34. Luck does not apply.

### S1. Tracks vs speed (geometry unchanged; camp distance from the base line)

"Need" = keeper close speed x1.10 (Forest: the starting 24). "Prev" = the previous biome's need (your first try).

| Biome | Length | Camp at | Keeper close/mid/far | Need | To camp @need | To camp @prev | Cross @need | Cross @prev | Round trip +15 s | Keeper settles |
|---|---|---|---|---|---|---|---|---|---|---|
| Forest | 180 | 100 | 20/23/26 | 24 | 4.2 s | - | 7.5 s | - | 23 s | 150 studs back |
| Jungle | 450 | 405 | 32/37/42 | 35 | 11.6 s | 16.9 s | 12.9 s | 18.8 s | 38 s | 74 |
| Desert | 650 | 955 | 50/57/65 | 55 | 17.4 s | 27.3 s | 11.8 s | 18.6 s | 50 s | 82 |
| Snow | 850 | 1705 | 80/92/104 | 88 | 19.4 s | 31.0 s | 9.7 s | 15.5 s | 54 s | 78 |
| Lava | 1050 | 2655 | 128/147/166 | 141 | 18.8 s | 30.2 s | 7.4 s | 11.9 s | 53 s | 80 |
| Crystal | 1300 | 3830 | 205/236/266 | 226 | 16.9 s | 27.2 s | 5.8 s | 9.2 s | 49 s | 79 |
| Storm | 1600 | 5280 | 330/379/429 | 363 | 14.5 s | 23.4 s | 4.4 s | 7.1 s | 44 s | 79 |

**Verdict: passes, no geometry change needed.** Base-to-camp at the needed speed sits in a 12-19 s band from Jungle to
Storm (neighbours within 1.5x; the only big step is the 4 s tutorial Forest to Jungle); a first try at the previous
biome's speed takes 17-31 s; nothing is over 31 s. Every run leaves time to take all 5 packs of a biome per 300 s refresh.
One thing to know: time spent *inside* the last biomes gets short (crossing Storm takes 4.4 s at 363), because speed
grows 1.6x per biome while biome length grows about 1.25x. Most of a Storm run is spent crossing the earlier biomes.

### N1. First 10 minutes: speed vs time on the starter treadmill (100 points/s; twice as fast with the speed pass)

| Treadmill time | Points | Live (R110) | Approved proposal | **Final** | vs Forest keeper (20) | vs Jungle keeper (32) |
|---|---|---|---|---|---|---|
| 0:00 | 0 | 24.0 | 24.0 | **24.0** | 1.20x faster | too slow |
| 0:05 | 500 | 27.8 | 24.9 | **26.0** | 1.30x | too slow |
| 0:15 | 1,500 | 32.5 | 26.8 | **28.0** | 1.40x | too slow |
| 0:30 | 3,000 | 38.0 | 29.5 | **31.0** | 1.55x | too slow |
| 0:45 | 4,500 | 40.1 | 32.2 | **33.0** | 1.65x | 1.03x |
| 1:00 | 6,000 | 42.3 | 35.0 | **35.0** | 1.75x | 1.09x (Jungle ready) |
| 2:00 | 12,000 | 48.8 | 36.1 | **36.1** | 1.80x | 1.13x |
| 5:00 | 30,000 | 56.0 | 39.2 | **39.2** | 1.96x | 1.23x |
| 10:00 | 60,000 | 64.7 | 44.5 | **44.5** | 2.22x | 1.39x |

- **Start stays 24** everywhere (base, garden, lobby, market, track). That is 1.5x Roblox's default 16 (1.2x after this
  game's 1.25x avatar scale), so it feels free. Raising it would ripple into `Config.BaseWalkSpeed` (startup assert),
  old-save speed migration (`LegacySpeedToStat`) and the run-animation calibration (1.0x at 24), for little gain.
- **Forest keeper, new player at 24:** in a straight-line chase with the real `KeeperPursuit` (0.5 s notice, hits from
  +0.85 s), starting only 5 studs from the keeper, it never gets closer than 23 studs (reach 9) and settles 150 back.
- **First speed-ups:** new knots `{500,26},{1500,28},{3000,31}` before the approved `{6000,35}`. The speed number keeps
  climbing through the first minute, and Jungle (35) is ready after 1 minute on the first machine, as approved. From
  6,000 points on, the curve is exactly the approved one (`{120K,55},{1.5M,88},{20M,141},{300M,226},{5B,363},{100B,500}`).

Saved points -> speed (existing saves keep their points):

| Points | 0 | 1K | 10K | 100K | 1M | 10M | 100M | 1B | 10B | 100B | 1T |
|---|---|---|---|---|---|---|---|---|---|---|---|
| live | 24 | 31 | 48 | 68 | 94 | 141 | 185 | 240 | 325 | 500 | 500 |
| final | 24 | 27 | 36 | 51 | 76 | 112 | 192 | 285 | 395 | 500 | 500 |

## What changed

| Script | Change |
|---|---|
| `ReplicatedStorage/PackOdds112` (**new ModuleScript**, parent ReplicatedStorage) | Odds tables, boot rule, floor guard, Void table, exact staged roll (`Chance`, `RollTier`, `Roll`), old-luck mapping. |
| `ReplicatedStorage/BalanceValues81` | `PointCurve` (above), `BootLuck {5,50,2000,100000,5000000}`, `MaxLuck = 5000000` (the only luck cap). |
| `ReplicatedStorage/RouteBalance83` | `KeeperSpeeds` = x1.6 ladder (feeds `BalanceValues81`, keeper floors, return speed, `/test routes`). |
| `ReplicatedStorage/RunnerMotion` | `BaseAreaRatio .4 -> 1` (kept as the single switch); `BoundaryStep` returns early when the ratio is 1. |
| `ReplicatedStorage/SeedPackRules` | New layer: OddsVersion 112 packs use PackOdds112; `Roll` takes a draw function; older versions keep their code with luck mapped back to the old boots; `Rules.OddsVersion`. |
| `ReplicatedStorage/OddsText85` | Denominators from 1M read `1/1M`, `1/16.7B`, `1/1T`; fixed a tiny-odds case that printed `≈0/1`. |
| `ReplicatedStorage/WorldStatusHud` | Luck clamp -> `MaxLuck`; shows `×5M`, `×100K` (formatter already existed). |
| `ReplicatedStorage/ShopMenu` | Boot/trail benefit uses the same formatter (`×5M` instead of `×5000000`). |
| `ReplicatedStorage/StudioTestHelp` | `/test odds` text: luck 1-5000000. |
| `ChestService` | World packs get `OddsVersion = PackRules.OddsVersion`; opening passes `function() return PackRandom:NextNumber() end`. |
| `PlayerDataService` | Luck clamp -> `MaxLuck`; **load keeps OddsVersion 112** (it dropped anything but 81 to nil). |
| `OwnerUpdateCommands82` | `odds`, `voidcheck`, `packset`, `eclipse` use the current version; luck limit/text from `MaxLuck`. |
| `StudioTestCommands`, `VeiledEvent81` | Test packs / Void pack carry the current version. |
| `src/MANIFEST.tsv` | Row for PackOdds112 (for the sourcemap). |

Not changed on purpose: `PackOdds81` (its `clamp(luck,1,3.5)` is the frozen v81 rule and now only ever receives the
mapped old luck <= 2; raising it to MaxLuck would let banked packs roll King almost every time with Electric boots),
`Config` (line 740 already copies `BootLuck`; Version not bumped), `EconomyService`, `RunnerController`, map/track scripts,
the Mech pack, and the files owned by the other agent.

## Tests (all offline; outputs in `R111_balance/out_*.txt`)

- **Luau vs Python:** 3,510 seed odds (7 biomes x 6 packs x 13 luck values, real `SeedPackRules`+`PackOdds112`) vs the
  independent model: max relative difference 2.4e-15. OddsVersion 81 packs through the new code vs the verified port of
  the old odds (with the old-luck mapping): 3,510 values, max relative 2.2e-16. Void: 15 seeds, 1.3e-16.
- **Monotonic:** 3,360 checks (better boot, better pack, every "tier X or better"): 0 violations. Lowest tier keeps >= 40.0%
  of its no-boot share everywhere (binding case: Forest Legendary pack, Frost boots). 252/252 tables sum to 1.
- **Staged roll** (real code): 51 frequency checks incl. p=4e-6 with the real 1e-5 gate at 1e8 trials (390 vs 400),
  p=3e-5 through 5 gates (599 vs 600), synthetic King 3e-6 in RollTier (147 vs 150), 5 real pack tables and the Void pack
  at 2e6 rolls each; worst |z| = 2.33. With a 32-bit random draw, 1 in 1T is off by 0.0015% staged; a single draw would be
  either impossible or 230x too common.
- **Real open path** (`ChestService:_activatePack` -> `PlayerDataService:OpenSeedPack` -> `Roll`): 75,600 packs over every
  biome x pack x boot, 0 errors / invalid rewards; OddsVersion 81 packs still roll the old odds (Storm Mythic pack, Electric:
  King 3.6% as before vs 0.10% for a new pack; 2M-roll check 3.57% vs 3.58%); legacy unversioned, Void 81/112 and Mech packs open; a bare number is refused
  for v112; `RefreshBoostMultipliers` gives 5 / 50 / 2000 / 100000 / 5000000 and clamps a fake 1e9 boot to 5e6.
- **Movement:** real `RunnerMotion` + `MovementGuard.Check` + `BaseService:_stabilizeHorizontalVelocity` on a simulated
  runner (60 Hz client, 10 Hz server, 0-3 frames replication jitter), speeds 24-500, in base / across the line / diagonal /
  on track: **0 corrections, 0 server velocity clamps, server WalkSpeed always equals the client ceiling**. Over-speed
  clients (2x) are still corrected in the base and on the track alike. With the old ratio the same run shows the base
  zone enforcing 40%, and one boundary clamp at 363 that no longer happens.
- Every changed file compiles (`luau-compile`); luau-lsp: the same set of findings as the pre-change files (nothing new).

## Dampener removal: what else was checked

All consumers read `RunnerMotion.BaseAreaRatio` through `ZoneCap`/`AtPosition`/`TravelAllowance`/`BoundaryStep`
(client RunnerController cap and boundary step, MovementGuard allowance and burst, BaseService WalkSpeed and the 1.15x
velocity clamp, ChaseService speed restore). With the ratio at 1 they all return the earned speed, so they agree by
construction, and the simulation confirms it. Nothing else used the slow zone: garden, market and pack prompts are
ProximityPrompts with fixed ranges; treadmill mounting checks "standing on the belt" each Heartbeat at any speed;
braking is instant on release (RunnerMotion.Step), so stopping at a prompt is unchanged; fences and walls are handled
by the client sweep (same as on the track at 500) and the server barrier sweep does not include base fences (unchanged);
teleports reset MovementGuard as before; `MapService:146` still sets the track line (now only used if the ratio is
lowered again). The tutorial's "SAFE ZONE" is about keepers stopping at the line, not speed.

## Defaults applied (owner did not decide)

1. Unopened packs banked before the update keep OddsVersion 81 odds, and use the old boot luck (x1.15..x2, from the best
   boot owned) so they are not boosted by the new x5M.
2. Void (event) pack: proposal T7 with King 1 in 200M (non-Mech rolls), Cosmic 1 in 20, Secret the rest; Mech branch 1/200 kept.
3. Gem Mech pack unchanged (its King stays 1 in 200).
4. Starting speed kept at 24 (see N1); Forest keeper kept at the approved 20/23/26.

## Risks and what to check in Studio

- **Index 100% still needs every seed:** 5 King seeds, one per biome from Desert on. With Electric boots that is ~143 h of
  farming *each* biome (~700 h total). Crystal/Storm completion gems follow the same rule.
- Shown luck (x5M) is much larger than its effect on Mythic (~x12); players may expect more. King really gets x5M.
- Players with banked old packs open them at the old, much better odds (a finite stock, capped by inventory size).
- Players with 6K-300M saved points are slower than today (approved); 300M-100B faster.
- Fast players now run at full speed in their base; check it feels controllable at 500 (`/test movespeed 500`): garden
  planting, market, standing on the treadmill, no rubber-banding when crossing the base line.
- Studio checks: `/test odds desert common 1` and `/test odds storm mythic 5000000` (King lines `1/1T` and `1/1000`),
  `/test voidcheck` -> PASS, `/test packset storm` then open packs, `/test boots 5` -> HUD "Pack luck ×5M", shop shows
  ×5 / ×50 / ×2K / ×100K / ×5M, index card shows "King 1/1T"; a fresh profile's first minute on the treadmill; a pack
  banked before the update opens (old odds).

## R112b update (owner): Thunder Boots, King 1 in ~1,000

Every boot's luck x10: Sand x50, Frost x500, Lava x20K, Crystal x1M, **Thunder x50M** (Electric Boots renamed Thunder Boots; `MaxLuck` 50M).
A fixed Rare share now gives way first under the 40% floor guard (`Giveback` Rare, Legendary, Mythic, Secret), which removed the one
inversion x50M caused (Snow Rare pack below Uncommon pack for Legendary+). Suite re-run: 0 violations, Luau = Python to 1e-15, 75,600 opens OK.

Storm, average pack, "tier or better", time at 72 packs/h:

| Boot | Mythic+ | Secret+ | Cosmic+ | King |
|---|---|---|---|---|
| none | 1 in 16 (13 min) | 1 in 510 (7 h) | 1 in 51.5K (716 h) | never |
| Sand x50 | 1 in 9 (8 min) | 1 in 170 (2 h) | 1 in 10.8K (150 h) | never |
| Frost x500 | 1 in 8 (7 min) | 1 in 89 (1 h) | 1 in 4.3K (60 h) | never |
| Lava x20K | 1 in 6 (5 min) | 1 in 35 (29 min) | 1 in 980 (14 h) | 1 in 2.6M (never) |
| Crystal x1M | 1 in 4 (3 min) | 1 in 17 (14 min) | 1 in 205 (3 h) | 1 in 51.5K (716 h) |
| Thunder x50M | 1 in 3 (3 min) | 1 in 11 (9 min) | 1 in 80 (1 h) | **1 in 1,031 (14 h)** |

## Seed chances inside each pack type (R112b, biome with every rarity)

Pack spawn mix: Common 38%, Uncommon 25%, Rare 15%, Epic 7%, Legendary 10%, Mythic 5%.

No boots:

| Pack | Common | Uncommon | Rare | Legendary | Mythic | Secret | Cosmic | King |
|---|---|---|---|---|---|---|---|---|
| Common | 1 in 1.7 | 1 in 4 | 1 in 8 | 1 in 30 | 1 in 200 | 1 in 10K | 1 in 1M | 1 in 1T |
| Uncommon | 1 in 2.6 | 1 in 3 | 1 in 5 | 1 in 15 | 1 in 80 | 1 in 4K | 1 in 400K | 1 in 400B |
| Rare | - | 1 in 2.4 | 1 in 2.5 | 1 in 7 | 1 in 30 | 1 in 1.67K | 1 in 167K | 1 in 167B |
| Epic | - | - | 1 in 1.8 | 1 in 3 | 1 in 10 | 1 in 500 | 1 in 50K | 1 in 50B |
| Legendary | - | - | 1 in 2.9 | 1 in 2.5 | 1 in 4 | 1 in 167 | 1 in 16.7K | 1 in 16.7B |
| Mythic | - | - | - | 1 in 1.7 | 1 in 2.5 | 1 in 50 | 1 in 5K | 1 in 5B |

Thunder Boots (x50M):

| Pack | Common | Uncommon | Rare | Legendary | Mythic | Secret | Cosmic | King |
|---|---|---|---|---|---|---|---|---|
| Common | 1 in 2.6 | 1 in 4 | 1 in 8 | 1 in 7.3 | 1 in 12 | 1 in 70 | 1 in 833 | 1 in 20K |
| Uncommon | 1 in 6.5 | 1 in 3 | 1 in 10 | 1 in 6.3 | 1 in 4.7 | 1 in 28 | 1 in 333 | 1 in 8K |
| Rare | - | 1 in 5.9 | 1 in 5 | 1 in 11 | 1 in 2.2 | 1 in 12 | 1 in 139 | 1 in 3.3K |
| Epic | - | - | 1 in 4.4 | 1 in 6 | 1 in 3 | 1 in 4 | 1 in 42 | 1 in 1K |
| Legendary | - | - | 1 in 7.3 | 1 in 5 | 1 in 2.8 | 1 in 4 | 1 in 20 | 1 in 333 |
| Mythic | - | - | - | 1 in 4.2 | 1 in 2.2 | 1 in 4 | 1 in 20 | 1 in 100 |
