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

### T4. Time to see a "1 in N" item (top-tier rule: full luck, so N is divided by pack luck x boot luck)

Average built-in pack luck for top tiers over the spawn mix = x19.4.

| Base 1 in N | No boots | Lava boots (x20) | Electric boots (x500) | Whole game, 1,000 players all with Electric boots |
|---|---|---|---|---|
| 1M (Cosmic) | 716 h | 36 h | 1.4 h | <1 min |
| 100M (King) | ~8.2 yr nonstop | 3,578 h, ~5 months nonstop | 143 h | 9 min |
| 1B (reference) | ~81.6 yr nonstop | ~4.1 yr nonstop | 1,431 h, ~2 months nonstop | 1.4 h |
| 1T (Divine) | never: ~8e4 yr | never: ~4e3 yr | never: ~2e2 yr | 1,431 h, ~2 months nonstop |
| 1Qa (Eternal) | never: ~8e7 yr | never: ~4e6 yr | never: ~2e5 yr | never: ~2e2 yr |

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

### T7. Void pack (event pack, every 3rd refresh, luck does not apply)

| Tier | Now | Proposed |
|---|---|---|
| Secret | 1 in 1.26 | rest |
| Cosmic | 1 in 5.91 | 1 in 20 |
| King | 1 in 33.5 | 1 in 20K |
| Divine | - | 1 in 200M |
| Eternal | - | 1 in 200B |

(Now: 99.5% direct roll x tier weight; 0.5% goes to a Mech roll. Proposed keeps the 0.5% Mech roll.)
