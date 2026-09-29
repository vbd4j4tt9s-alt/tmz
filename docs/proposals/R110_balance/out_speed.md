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

