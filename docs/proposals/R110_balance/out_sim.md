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
