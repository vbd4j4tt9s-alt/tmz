# R154: the clover's x2 on every pack, and no single-seed packs

Owner answers to the R153 open questions:
1. "the 2x luck is universal": the 4 Leaf Clover must double luck everywhere.
2. "the elderbloom only pack is not supposed to be intentional": no pack may be (almost) one seed, at any luck.

Code: `PackLuck154` (new, frozen), the outermost wrapper at the end of `SeedPackRules`, `BalanceValues81` (the cap), `PlayerDataService` (the cap, the open),
`ChestService` (hold tooltip), `HubDisplayService` (BEST PULL odds), `RarePackTests`, `SeedRarity153`, the owner `odds` command, shop and card text.
`Config.Version` is unchanged.

## 1. The clover's x2, everywhere

### The cap
Luck was capped at x50M, the same as Thunder Boots, so the clover added nothing at the top. Now a pass raises the cap by as much as it multiplies:
a player's cap is `MaxLuck` (50M) x their passes. `BalanceValues81.LuckCeiling` (100M) is the highest luck any roll takes. `PackOdds112` / `PackOdds137`
clamp to it, and so do the HUD and `/test odds`.

| Boots | No clover | With clover: before | With clover: after |
|---|---|---|---|
| none | x1 | x2 | x2 |
| Sand ... Lava, Crystal (x50 ... x1M) | x50 ... x1M | x100 ... x2M | x100 ... x2M |
| Thunder (x50M), real or owner test boots | x50M | **x50M** | **x100M** |

The per-tier ceilings inside a pack still apply: King at most 1%, Cosmic 5%, Secret 25%, Mythic 45% of a pack, unless the pack's own chance is higher.
At Thunder Boots the clover still moves 32 of the 42 biome packs. Examples: Desert Common pack King 1/20K -> 1/10K; every Pack01-05 King in the King biomes x2;
Forest / Jungle Pack01-03 Mythic x1.12. The other 10 packs (every Mythic pack, and Forest / Jungle Pack04-05) are already at those ceilings at x50M,
so x100M changes nothing there. **Owner call:** raising those ceilings for clover owners would be a separate change.

### Where the luck applies
Every seed comes from opening a pack (`PlayerDataService:OpenSeedPack` -> `SeedPackRules.Roll`), and that call now gets both the boots-and-pass luck and the
pass luck on its own. So the clover reaches every pack, whichever way it was got:

- **World / stolen packs:** boots x clover.
- **Bonus roll / treadmill rolls:** boots x clover. The roll gives a Pack01-06 or a Void pack (OddsVersion 149).
- **Daily quest / login mystery packs:** boots x clover, or the clover alone for the day-7 Void pack.
- **Mystery pedestal:** Pack02-06 with boots x clover, or a Void pack with the clover alone.
- **Free starter pack:** its 2x rate boost, then boots x clover.
- **Limited Mech pack (bought):** the clover alone. Mech purchases make packs; the seed is rolled on open.
- **Void giveaway pack, Verity pack:** the clover alone.
- **Banked world packs, OddsVersion 112 / 137:** boots x clover, up to x100M.

Which pack TIER the bonus roll, the daily packs or the pedestal hand out was never luck-based (boots don't change it either), and it stays that way.
Packs banked before R112 (OddsVersion 81 / none) keep their R112 mapping to the old boots (x1.15-x2). That covers a pre-R112 Void pack too
(Secret 80 / Cosmic 17 / King 3): the clover isn't added there.

Also updated so they read the clover's luck: the hold tooltip (a pack's real odds), BEST PULL's stored chance, and `/test odds event|verity [clover]`.

### The fixed-odds packs (Void, Verity, Mech)
These packs had no luck at all. **Only the clover's x2 applies to them** (boots still never do). The two lucks are separated with a new last argument
of `SeedOdds` / `Roll` (`passLuck` = `PlayerDataService:PassLuck`).

The mechanism is the biome packs' own. Each tier above the pack's lowest gets its chance x luck^Power (King ^1, Cosmic ^.40, Secret ^.28, Mythic ^.16,
Legendary ^.08), and the lowest tier gives that up, keeping at least 40% of its share. Other details:
- A pack's branches keep their size: the Void pack's 1/200 Mech roll is a Mech-pack roll with the clover.
- The Verity seed is the Verity pack's King.
- No tier ceiling here: these packs only ever see x1 or x2.

**Limited Mech pack:**

| Seed | Before | With clover |
|---|---|---|
| Plasma Pepper (Legendary) | 48% (1/2) | 40.28% (1/2) |
| Holo Melon (Mythic) | 26% (1/4) | 29.05% (1/3) |
| Prism Lotus (Mythic) | 16% (1/6) | 17.88% (1/6) |
| Holo Apple Tree (Secret) | 7% (1/14) | 8.50% (1/12) |
| Nebula Vine (Cosmic) | 2.5% (1/40) | 3.30% (1/30) |
| Crowncore Tree (King) | 0.5% (1/200) | 1% (1/100) |

**Void pack:**

| Seed | Before | With clover |
|---|---|---|
| each of the 5 Secrets | 18.9% (1/5) | 18.59% (1/5) |
| each of the 5 Cosmics | 0.995% (1/101) | 1.313% (1/76) |
| each of the 5 Kings | 1/1.01B | 1/503M |
| Mech roll (total) | 1/200 | 1/200 |
| Plasma Pepper | 1/417 | 1/497 |
| Holo Melon | 1/769 | 1/688 |
| Prism Lotus | 1/1,250 | 1/1,120 |
| Holo Apple Tree | 1/2,860 | 1/2,350 |
| Nebula Vine | 1/8,000 | 1/6,060 |
| Crowncore Tree | 1/40K | 1/20K |

**Verity pack:**

| Seed | Before | With clover |
|---|---|---|
| Verity | 1% (1/100) | 2% (1/50) |
| each of the 5 Secrets | 18.72% (1/5) | 18.22% (1/5) |
| each of the 5 Cosmics | 0.985% (1/102) | 1.287% (1/78) |
| Plasma Pepper | 1/419 | 1/498 |
| Holo Melon | 1/773 | 1/699 |
| Prism Lotus | 1/1,260 | 1/1,140 |
| Holo Apple Tree | 1/2,870 | 1/2,390 |
| Nebula Vine | 1/8,040 | 1/6,160 |

Shop and card text: "x2 luck on EVERY pack u open!" (`GamePassCatalog` description adds the 🍀; the card's line is the same without it).

## 2. No single-seed pack: the 80% rule

This is the **last step** of every roll and every odds table of a live pack, after luck, the starter boost and the clover. It holds whatever the luck source is.

**When one seed would take more than 80% of a pack's rolls:**
1. **1% goes to an upgrade**, taken from that top seed. The upgrade is the seeds of the next tier above the top seed in that pack, split evenly; in every real
   case that is the biome's signature seed of that tier. When nothing is rarer than the top seed, the 1% goes to the pack's rarest seed instead.
2. **The top seed keeps at most 80%.**
3. **The rest goes to the other seeds** in proportion to their own share, so they hold at least 19% between them, plus the 1%.

A pack at 80% or less is untouched and rolls exactly as before, with the same draws (a seed at exactly 80% counts as not over).

**Live means:**
- a world pack at OddsVersion 149, which is every pack made since R148;
- the current Void pack;
- every Verity and Mech pack.

Banked world packs (OddsVersion 137 / 112 / 81 / none) are not changed. That keeps the R148 "no windfall" decision.

**Where it acts (biome packs; nothing else ever exceeds 80%):**

| Pack | Top seed | Acts at luck |
|---|---|---|
| Desert Common (Pack01) | Prickly Pear 86.2% | x1 to about x13M |
| Snow Common (Pack01) | Snow Melon 86.4% | x1 to about x33M |
| Snow Epic (Pack04) | Iceberry 80.5% | x1 to x1.26 |
| Snow Mythic (Pack06) | Aurora Lily 80.2% | x1 to x1.05 |
| Lava Mythic (Pack06) | Lava Lotus 82.0% | x1 to x1.8 |
| Crystal Mythic (Pack06) | Moon Melon 84.7% | x1 to x4.4 |
| Storm Mythic (Pack06) | Volt Orchid 86.6% | x1 to x8.7 |

At high luck every pack spreads out by itself: tiers grow and the lowest gives way. No live pack collapses toward one seed at high luck. The risk was at
LOW luck, where the lowest tier is at its biggest.

**The Forest Mythic pack the owner looked at.** It is two seeds at every luck and never reaches the rule. "Only Elderbloom" was the `/test rarepacks mythic` pack (see 3).

| Luck | Before | After |
|---|---|---|
| x1 | Sunflower 73.3% / Elderbloom 26.7% | same |
| x1M | Sunflower 55% / Elderbloom 45% | same |
| x50M | Sunflower 55% / Elderbloom 45% | same |
| x100M (Thunder Boots + clover) | Sunflower 55% / Elderbloom 45% | same |

Elderbloom is at its 45% Mythic ceiling from about x1,000 up.

**Packs the rule changes, at luck x1:**

| Pack | Before | After |
|---|---|---|
| Desert Common | Prickly Pear 86.21, Aloe 12.5 (1/8), Sand Fruit 1/90, Dune Lotus 1/600, Dune Starfruit 1/10K, Mirage Fig 1/1M, Solar Starfruit 1/1T | Prickly Pear 80, **Aloe 18.23 (1/5)**, Sand Fruit 1/65, Dune Lotus 1/435, Dune Starfruit 1/7,260, Mirage Fig 1/726K, Solar Starfruit 1/726B |
| Snow Common | Snow Melon 86.39, Iceberry 12.5 (1/8), Aurora Lily 1/105, Glacier Lotus 1/700, Secret 1/10K, Cosmic 1/1M, King 1/1T | Snow Melon 80, **Iceberry 18.46 (1/5)**, Aurora Lily 1/75, Glacier Lotus 1/501, Secret 1/7,160, Cosmic 1/716K, King 1/716B |
| Snow Epic (Pack04) | Iceberry 80.54, Aurora Lily 14.81 (1/7), the rest | Iceberry 79.54, **Aurora Lily 15.81 (1/6)**, the rest unchanged |
| Snow Mythic | Aurora Lily 80.2, Glacier Lotus 17.78 (1/6), the rest | Aurora Lily 79.2, **Glacier Lotus 18.78 (1/5)**, the rest unchanged |
| Lava Mythic | Lava Lotus 81.98, Fire Pepper 16 (1/6), Obsidian Maw 1/50, Boom Bloom 1/5,000, Ember Emperor 1/5B | Lava Lotus 80, **Fire Pepper 17.87 (1/6)**, Obsidian Maw 1/47, Boom Bloom 1/4,740, Ember Emperor 1/4.74B |
| Crystal Mythic | Moon Melon 84.65, Diamond Vine 13.33 (1/8), Hollow Geode 1/50, Orbit Lotus 1/5,000, Prism Monarch 1/5B | Moon Melon 80, **Diamond Vine 17.5 (1/6)**, Hollow Geode 1/40, Orbit Lotus 1/4,040, Prism Monarch 1/4.04B |
| Storm Mythic | Volt Orchid 86.55, Tempest Lotus 11.43 (1/9), Blackout Bloom 1/50, Storm Sovereign 1/5,000, Pulsar Starfruit 1/5B | Volt Orchid 80, **Tempest Lotus 17.15 (1/6)**, Blackout Bloom 1/35, Storm Sovereign 1/3,540, Pulsar Starfruit 1/3.54B |

The upgrade is in **bold**. The Desert and Snow Common packs at x1M, for example, go to 80 / Aloe 14.3 and 80 / Iceberry 14.8.

**Choices made:**
- The other seeds share the freed part **in proportion**, so a pack keeps its shape. The cost is that the rare seeds of these 7 packs get up to x1.41
  (Storm Mythic) while the rule acts. The alternative was to give it all to the upgrade seed and keep the rare odds exact; it's a one-line switch if the owner prefers it.
- **The fixed display does not move.** `SeedRarity153` (the Index, the reveal card, chat, the plaque) reads `SeedPackRules.RawSeedOdds`, the home pack's base-luck
  table before the rule and without the clover. So every seed keeps its R153 number: Secret 1/10K, Cosmic 1/1M, King 1/1T in every biome, Aloe and Iceberry 1/8.
  It is the seed's original rate, as R153 intended. The rule does change base-luck odds, but only in the 7 packs above. A pack's own odds (the hold tooltip,
  `/test odds`) show the real shaped numbers.

## 3. `/test rarepacks <rarity>`

It used to reveal the roster's FIRST seed of that rarity (Mythic was always Elderbloom, in a Forest Mythic pack). Now it is a **random real seed of that
rarity from any biome**: every seed of that rarity a biome pack can roll today, evenly. The command names no biome, so "any biome" fits. The TEST pack is that
seed's biome's Mythic pack.

It is still a guaranteed TEST reveal, never announced. `rarepacks` (all five), `mech`, `verity` and `roster` are as before.

## 4. Tests

**`docs/proposals/R154/tests/run_luck_odds.sh`** (in `tools/tests/run_all_suites.sh`) runs `test_luck_odds.luau` on the R153 clover world. It checks:
- **The doubled cap:** every boot x2, owner test boots, `PackOdds112` / `137` at x100M, a King doubling, an open handing over both lucks.
- **Fixed-odds packs with and without the clover:**
  - Without it they keep their exact old tables, and boots never change them.
  - With it, tier by tier: King x2, Cosmic x2^.40 and so on.
  - The branches keep their size, and junk pass luck counts as none.
  - 60,000 real rolls follow the tables, and the exact roll reaches 1-in-500M Kings.
  - A real open of each by a clover owner goes through the clover's roll.
- **The 80% invariant** over every pack x OddsVersion 149 / none x luck (1, 10, 1e3, 1e6, 5e7, 1e8 plus a dense sweep) x starter boost, plus Void / Verity / Mech x clover:
  - every table is compared with an independent re-implementation of the rule;
  - banked versions are untouched;
  - 60,000 real rolls follow the shaped tables;
  - the shaped roll is still exact at 1 in 726B.
- **`/test rarepacks` randomness:** every seed of the rarity comes up, in its biome, and is revealed exactly.
- **The display unchanged at base luck:** all 54 seeds.
- **10 teeth mutations:** each one must fail the suite.

**R153 suites updated for the owner's decisions:**
- `run_seed_rarity.sh` (via `R154/tests/check_r154_dump.py`): the roll dump must equal the R152 base except the live packs over 80%. Each such line must equal the
  checker's own re-implementation; the Index numbers still equal the base.
- `test_seed_rarity` section 9: a live pack's favourite is at most 80%.
- `run_clover.sh`: the cap tests expect x100M; an `old_cap` mutation; the pass-id scan skips the release notes and handoff, which name the id for the publish checklist.
- Frozen hashes: `docs/proposals/R151/tests/frozen.sha256` has R154 notes for `PackOdds112` / `137`, `SeedPackRules` and the new `PackLuck154`.
- `R148/tests/test_roster*.luau`: the plan's tables and the Index chips read `RawSeedOdds`; the live Desert Common rolls and tooltip follow the rule (Aloe 1/5, Sand Fruit 1/65).

**Results** (private scratch dirs, one suite at a time), all PASS:
- R154 luck_and_odds, with 10/10 teeth;
- R153 seed_rarity, with teeth; R153 clover; R153 `run.sh`; R153 fixes_server;
- R137; R140 daily; R150 bonus_ui;
- R148 index_limited and roster;
- R151 packs, rare_pull, announce, hub_displays and pack_shapes;
- R147 verity and verity_pack; R149 verity_pack; R152 seed_opening.

The full runner was not run.

Not checked: anything in real Studio, including the HUD showing ×100M and the shop card's new line fitting on a real phone.
