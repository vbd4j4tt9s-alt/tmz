# Proposal: more big packs with pity, and rarer Legendary / Mythic seeds

**Status: approved and built in R137** (`docs/releases/R137.md`). The owner added:
- "the pity thing and giant drop thing has to feel random", "dont put a indicator or anything".
So the meter and drops are hidden soft ramps, not fixed counters:
- **Player:** the chance grows after 18 / 150 packs and is sure by 30 / 200.
- **Track:** it grows after 1 / 5 refreshes and is sure by 6 / 12, at a random spot.
- **Measured:** a 5x+ every ~20 packs, a 10x+ every ~120, ~7 big packs per server-hour and a 10x+ every ~36 min.

The text below is the proposal as sent.


All numbers below come from the real odds code. `odds_now.luau` dumps today's odds from the real `PackOdds112` on the mock, and `sim.py` checks its model against that dump (they match to 0.00000001%). `sim.py` then works out the new numbers and simulates 4,000 server-hours and 3 million pack openings. The full output is in `sim_output.txt`.

Track facts used below: 35 pack spots, refreshed every 5 minutes, so 420 packs per server per hour.

---

## A. Big packs

### 1. New pack sizes
Each size's chance, as 1/N:

| Size | Now | New |
|---|---|---|
| 0.5x | 1/33 | **1/50** |
| 1x | 1/1.3 | **1/1.4** |
| 1.5x | 1/7.1 | **1/5.9** |
| 2.5x | 1/22 | **1/14** |
| 3.5x | 1/71 | **1/38** |
| 5x | 1/222 | **1/100** |
| 7.5x | 1/1,000 | **1/357** |
| 10x | 1/2,857 | **1/1,111** |
| 15x | 1/10,000 | **1/4,000** |
| 20x | 1/25,000 | **1/10,000** |
| 25x | 1/100,000 | **1/25,000** |

- **5x or bigger:** 1/167 → **1/71**.
- **10x or bigger:** 1/2,000 → **1/775**.
- **Average size:** 1.19 → 1.32.
- Same as R127, this applies to every pack that rolls a size: track packs, Mech packs, treadmill bonus packs and event packs.

### 2. Big Pack Meter (personal pity, saved)
- Every pack you open that's under 5x adds 1 to your meter.
- **At 30, your next pack grows into a Big Pack (5x or more) before it opens.** You see it puff up, with a "BIG PACK!" pop and sound. Its size is rolled from the 5x+ sizes, so it's sometimes 7.5x, 10x or more.
- **Giant meter:** after 200 packs without a 10x+, your next pack becomes 10x or bigger.
- Opening any 5x+ pack, lucky or from the meter, resets the 5x meter. A 10x+ resets both.
- A small bar in the pack opening screen shows it: `Big Pack 23/30`.
- It's saved in your profile, so leaving or switching servers doesn't reset it.

### 3. Giant Pack drops (server floor)
These work like the floors that already guarantee Legendary and Mythic packs:
- **Every 30 minutes** (every 6th refresh): if no 5x+ pack spawned, one spot gets a 5x+ pack.
- **Every hour** (every 12th refresh): the same for 10x+.
- Both are announced with the rare-pack alert, so the whole server races for them.

### What this does

| | Now | New sizes | + meter / drops |
|---|---|---|---|
| Your packs per 5x+ (average) | 166 | 72 | **23.5** |
| 9 in 10 players get a 5x+ within | 383 packs | 164 | **30** |
| Your packs per 10x+ (average) | 1,954 | 803 | **145** (never more than 200) |
| 5x+ packs on a server's track per hour | 2.5 | 6.0 | **7.5** |
| 10x+ packs on a server's track | one every ~5 h | one every ~1 h 50 | **one every ~38 min** |
| Average size of the packs you open | 1.19 | 1.32 | **1.48** |

---

## B. Rarer Legendary and Mythic seeds

### Rules
1. **Every biome gets a rarity factor that grows down the list:**

   | Forest | Jungle | Desert | Snow | Lava | Crystal | Storm Peaks |
   |---|---|---|---|---|---|---|
   | ×2 | ×2.5 | ×3 | ×3.5 | ×4 | ×5 | ×6 |

   - Legendary and Mythic chances are divided by this factor in Common, Uncommon and Rare packs.
   - Epic, Legendary and Mythic packs get half the nerf: Forest ÷1.5, Jungle ÷1.75, Desert ÷2, Snow ÷2.25, Lava ÷2.5, Crystal ÷3, Storm ÷3.5. That way those packs still feel like their name.
   - So even Forest is twice as rare as now.
2. **No more "pass-up".** Desert and Crystal have no Legendary seed, so today their Legendary chance is added to the Mythic. That's why Crystal shows **Mythic 1/26** in your Index screenshot, and Desert's Mythic (Dune Lotus) is **1/6** in a Common pack. Now that share goes to the pack's normal seeds.
3. **Desert's top packs stop always giving a Mythic.** Desert has no Rare or Legendary seed, so today its Epic, Legendary and Mythic packs *always* give Dune Lotus. With the pass-up, Desert alone hands out ~22 Mythic seeds per server per hour, more than half of all Mythics. Now:
   - those packs give Prickly Pear unless the Mythic hits: 1/20 in Epic, 1/8 in Legendary, 1/5 in Mythic packs;
   - same for Crystal's Mythic pack: Diamond Vine 1/7.5, otherwise a Rare.
   - *Other option:* I design a Rare and a Legendary seed for Desert and a Legendary seed for Crystal, so no biome has a gap.
4. **Unchanged:**
   - Secret, Cosmic and King;
   - how boots' luck boosts the chances;
   - the Legendary/Mythic pack floors.
5. **Packs people already have keep their old odds.** That covers packs on the track, in Bags and in gardens. The new odds get their own version number, like R112 did.

### Common pack (what the Index shows)

| Biome | Legendary now | Legendary new | Mythic now | Mythic new |
|---|---|---|---|---|
| Forest | 1/30 | **1/60** | 1/200 | **1/400** |
| Jungle | 1/30 | **1/75** | 1/200 | **1/500** |
| Desert | — | **—** | 1/6.1 | **1/600** |
| Snow | 1/30 | **1/105** | 1/200 | **1/700** |
| Lava | 1/30 | **1/120** | — | **—** |
| Crystal | — | **—** | 1/26 | **1/1,000** |
| Storm Peaks | 1/30 | **1/180** | 1/200 | **1/1,200** |

### Whole server, per hour
Seeds from track packs, not counting boots or the pack floors:
- **Legendary:** 30.7 → **13.5**.
- **Mythic:** 37.2 → **4.5**. That would be 11.6 if Desert's top packs kept always giving a Mythic.

<details><summary>Every pack in every biome</summary>

In a Mythic pack, Legendary is the minimum. So when the Mythic gets rarer, Legendary goes *up* there; that's expected.

| Biome | Pack | Legendary now → new | Mythic now → new |
|---|---|---|---|
| Forest | Common | 1/30 → 1/60 | 1/200 → 1/400 |
| Forest | Uncommon | 1/15 → 1/30 | 1/80 → 1/160 |
| Forest | Rare | 1/7 → 1/14 | 1/30 → 1/60 |
| Forest | Epic | 1/3 → 1/4.5 | 1/10 → 1/15 |
| Forest | Legendary | 1/2.5 → 1/3.8 | 1/4 → 1/6 |
| Forest | Mythic | 1/1.7 → 1/1.4 | 1/2.5 → 1/3.8 |
| Jungle | Common | 1/30 → 1/75 | 1/200 → 1/500 |
| Jungle | Uncommon | 1/15 → 1/38 | 1/80 → 1/200 |
| Jungle | Rare | 1/7 → 1/18 | 1/30 → 1/75 |
| Jungle | Epic | 1/3 → 1/5.2 | 1/10 → 1/18 |
| Jungle | Legendary | 1/2.5 → 1/4.4 | 1/4 → 1/7 |
| Jungle | Mythic | 1/1.7 → 1/1.3 | 1/2.5 → 1/4.4 |
| Desert | Common | — | 1/6.1 → 1/600 |
| Desert | Uncommon | — | 1/3.6 → 1/240 |
| Desert | Rare | — | 1/1.7 → 1/90 |
| Desert | Epic | — | 1/1 → 1/20 |
| Desert | Legendary | — | 1/1 → 1/8 |
| Desert | Mythic | — | 1/1 → 1/5 |
| Snow | Common | 1/30 → 1/105 | 1/200 → 1/700 |
| Snow | Uncommon | 1/15 → 1/52 | 1/80 → 1/280 |
| Snow | Rare | 1/7 → 1/25 | 1/30 → 1/105 |
| Snow | Epic | 1/3 → 1/6.8 | 1/10 → 1/22 |
| Snow | Legendary | 1/2.5 → 1/5.6 | 1/4 → 1/9 |
| Snow | Mythic | 1/1.7 → 1/1.2 | 1/2.5 → 1/5.6 |
| Lava | Common | 1/30 → 1/120 | — |
| Lava | Uncommon | 1/15 → 1/60 | — |
| Lava | Rare | 1/7 → 1/28 | — |
| Lava | Epic | 1/3 → 1/7.5 | — |
| Lava | Legendary | 1/2.5 → 1/6.2 | — |
| Lava | Mythic | 1/1 → 1/1 | — |
| Crystal | Common | — | 1/26 → 1/1,000 |
| Crystal | Uncommon | — | 1/13 → 1/400 |
| Crystal | Rare | — | 1/5.7 → 1/150 |
| Crystal | Epic | — | 1/2.3 → 1/30 |
| Crystal | Legendary | — | 1/1.5 → 1/12 |
| Crystal | Mythic | — | 1/1 → 1/7.5 |
| Storm Peaks | Common | 1/30 → 1/180 | 1/200 → 1/1,200 |
| Storm Peaks | Uncommon | 1/15 → 1/90 | 1/80 → 1/480 |
| Storm Peaks | Rare | 1/7 → 1/42 | 1/30 → 1/180 |
| Storm Peaks | Epic | 1/3 → 1/10 | 1/10 → 1/35 |
| Storm Peaks | Legendary | 1/2.5 → 1/8.8 | 1/4 → 1/14 |
| Storm Peaks | Mythic | 1/1.7 → 1/1.2 | 1/2.5 → 1/8.8 |

</details>

---

## What players will feel
- **Way more giant packs:**
  - about 3× as many 5x+ packs on the track, and 10x+ about every 40 minutes instead of every 5 hours;
  - everyone gets a 5x+ at least every 30 packs.
- **Legendary seeds are about half as common**, and Mythic seeds about 1/8 as common. Late biomes are the rarest.
- **Money:** bigger packs grow bigger plants, so income goes up (average pack size +24% with the meter). Fewer Legendary and Mythic seeds take some of that back. I can re-check the income per hour once you pick the numbers.

## Your call
1. The size table: OK?
2. The meter at 30 packs for 5x+ and 200 for 10x+?
3. Giant drops every 30 min (5x+) and every hour (10x+)?
4. Biome factors ×2 to ×6, with half for Epic/Legendary/Mythic packs?
5. Desert and Crystal: the step-down above, or should I design the missing seeds?
