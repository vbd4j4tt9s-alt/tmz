# R154 performance note: B1 and B3, and a quieter Output

Owner: *"for the lag fixes we can implement B3 and B1"* (the two "bigger wins" of `docs/proposals/R153/lag_audit.md` / `perf153.md` that change what is drawn),
plus a small extra: Studio's Output was flooded with `[R112] Item picture fallback Pack|1|Pack06|None|6: Pack shape is still loading`.

Base: the R153 release head `006daa1`. `Config.Version` unchanged, line 1 of every client script is still the R152 load guard, BackgroundMusic untouched.
Measured with the real scripts on the Roblox mock, on the owner's newest place (`5ea4542b-sapkeee.rbxl`, R153 installed; its map is identical to the one the audit used).

## In one minute

- **B1: parts the scripts build under 1.5 studs cast no shadow.** At the hub plaza the sun's shadow casters within 400 studs go
  **3,337 -> 2,407 on PC (-28%), 3,276 -> 2,377 on phones (-27%)**; the casters under 1.5 studs (fruit, petals, pebbles, lamp collars, fence insets, pack seals)
  **939 -> 9**. The 9 left are the saved map's own parts (see below). Parts of 1.5 studs and more keep their shadows; characters, avatars and keepers are not touched.
- **B3: phones (tier 2): keyboard letters at 12 px/stud, 56 key rows ahead (74 before).** On the track: keys **2,288 -> 1,892** (-396), keyboard letter canvas
  **8.2 -> 5.6 M pixels (32.8 -> 22.4 MB of letter texture, -32%)**, the same 1,475 letters; the keys now end ~458 studs ahead instead of ~605 (-147). The near
  letters alone are 44% smaller (16 x 16 -> 12 x 12 pixels a stud); the far letters (4 px/stud) are unchanged. **PC (tier 3) is exactly as it was; tier 1 got the 12 px letters too in R155 (last section).**
- **Output: one line per 5 seconds** while pack shapes load (`[R112] 23 item pictures waiting for pack shapes`); a real failure still warns once.

| before -> after (R153 release -> R154) | tier 3 (PC) | tier 2 (phone) | tier 1 |
|---|---|---|---|
| hub: sun shadow casters within 400 studs | 3,337 -> 2,407 | 3,276 -> 2,377 | 3,106 -> 2,278 |
| hub: of them under 1.5 studs | 939 -> 9 | 908 -> 9 | 837 -> 9 |
| whole workspace: shadow casters | 4,826 -> 3,896 | 4,595 -> 3,767 | 4,595 -> 3,767 |
| track: keyboard keys (keycap meshes) | 3,605 -> 3,605 | **2,288 -> 1,892** | 1,496 -> 1,496 |
| track: keyboard letter canvas (M pixels = x4 MB) | 11.0 -> 11.0 | **8.2 -> 5.6** (32.8 -> 22.4 MB) | 5.7 -> 5.7 (R155: 5.7 -> 4.0, 22.8 -> 16.0 MB) |
| track: letters drawn / keyboard SurfaceGuis | 2,047 / 124 (same) | 1,475 / 92 (same) | 1,079 / 68 (same) |
| hub: keyboard letter canvas | 2.7 -> 2.7 | 2.5 -> 2.1 | 2.1 -> 2.1 (R155: 2.1 -> 1.8) |
| most keys a tier can hold (`K.KeyCap`, 22 columns) | 3,762 | **2,354 -> 1,958** | 1,540 |

(The shadow counts are the census of `lag153_census.luau` as in the audit: drawn parts within 400 studs of the runner. On the track: 92 casters within 400 studs, 11 of them
tiny, are the saved map's own and do not change; the 820 script-built tiny casters elsewhere in the workspace go. Canvas pixels are the census's estimate, PixelsPerStud x face area; 4 bytes a pixel is an upper bound for the texture.)

## What changed

| | Change | Where |
|---|---|---|
| B1 | `SmallShadow154` (new, ReplicatedStorage): `Keeps(size)` / `Part(part)` / `Tree(root)`. A part whose largest side is under 1.5 studs gets `CastShadow=false`; a part that already casts nothing stays that way; a big part is never written. Called once where a builder makes or settles a part. No workspace listener, no scan | `MarketLayout` (the market's own parts at their FINAL size: it is built at 1/1.7 of it and scaled, so a 0.9-stud lantern cap that ends 1.53 keeps its shadow; the showcase maker's parts; `settle()` after `ScaleTo` for the fruit, plants and packs), `GardenFenceArt`, `HubDecorKit151.Part` (HubLife pebbles, petals, collars), `LeaderboardLandscape`, `SeedPackVisuals.part` (pack seals and tear strips) |
| B3 | `KeyboardTrack.lua` holds the numbers: `Tiers[2].Ahead = 56` (Side across the track 42 rows, was 51), `Legend.PixelsPerStudByTier = {[2]=12}`, and the helpers `K.NearPPS(tier)`, `K.NearText(pps)`, `K.RetuneLetters(...)`. The client only reads them: `PPS` / `TEXT` follow the tier (`Far.Tune`, called next to R153's `Far.Limit` at the two places a tier is decided) and a tier change re-applies them to every strip (bound and waiting in the pool) and every pressed-key letter | `KeyboardTrack.lua`; `KeyboardTrack.client.lua`: one function (`Far.Tune`, after `local klAll`) and `;Far.Tune()` after the two `Far.Limit()` calls. No new local in `start()` |
| Log | `ItemPictures`: a build that fails with "... is still loading" is counted per kind (pack shapes, fruit meshes, plant meshes, the Verity pouch) and summarised once every 5 s; a real failure still warns once with its key and reason. Retry times, pictures and holders are unchanged | `ItemPictures.lua` |

### Consistent with R153's D8

D8 renders the far letters to 500 studs on tier 2 (`Legend.FarMaxDistanceByTier[2]`). B3 does not change the far letters (still 4 px / stud, `FarAhead` 44 rows =
360 studs) and the 500 still covers them with a camera zoomed out to 128 studs (360 + 128 < 500; checked in `test_keyboard` 9b). `Far.Limit()` (D8) and `Far.Tune()`
(B3) are called side by side, so a tier change re-applies both. The keys' window is now smaller than the far letters' reach is long on no tier (`FarAhead` 44 <= `Ahead`
56; the R152 rule "letters lie inside the key window" holds). R154 left tier 1 (FastMode / slow devices) at 16 px / stud, because B3 was approved for phones on tier 2; R155 added `PixelsPerStudByTier[1]=12` (last section).

## Not touched on purpose (B1)

The audit counted the Crystal Wilds shards (233) among the script-built tiny parts. They are **in the saved map** (`Obby/Biomes/Biome_5_CRYSTAL_WILDS/BiomeScenesV092`), like the
Old oak grove flowers: 295 drawn parts under 1.5 studs in all, and "don't touch the saved map's own parts" holds (the census proves they are as they were). If you want those
shadows gone too, it is a Studio edit (optional, one minute; Ctrl+Z undoes it):

```lua
-- Command Bar, in Studio: shadows off for the saved map's tiny parts
local n=0
for _,d in ipairs(workspace.ChestChaseMap:GetDescendants()) do
  if d:IsA('BasePart') and d.CastShadow and math.max(d.Size.X,d.Size.Y,d.Size.Z)<1.5 then d.CastShadow=false n+=1 end
end
print(n)
```

## How it was proven (all on the owner's newest place)

Run each with its own scratch dir: `sh <runner> <dir> <place.rbxl>`.

| Suite | Result |
|---|---|
| R149 `run_keyboard.sh` | 704 checks, 0 failures (+ the place scene, 21 checks). Updated narrowly: tier 2 keys reach >= 455 studs (was 600) and 340 across (was 380); the letter audit reads the tier's pixels a stud; the stand-in scenario runs on tiers 2 and 3 (a phone now fills its smaller window inside one frame's budget, so only tier 3 still needs stand-ins). New section 9b: `K.NearPPS` / `K.NearText` / `Tiers[2].Ahead`, every strip (bound and parked) and pressed-key letter at 12 px/stud on tier 2 and 16 on tiers 3 and 1, re-applied on every tier change, the far-letter limit still covers the letter window. Six new mutations (R154ONLY=1), 6 of 6 caught; the D8 mutation target that R153 left stale is fixed |
| R153 `run_perf153.sh` (base = the R153 release's code: R154's two changes and the R153 patch undone) | all checks passed. hub x 6 runs: 73 shots each, offscreen 54 + same-visible 19; keyboard tier 3 and tier 1 identical (44 / 44); **tier 2: 9 identical + 35 same-visible**; keepers (6 x 420), seed opening on desktop / phone / low (every sound schedule), hotbar, speed popups, 1,574 packs: identical; PlayerGui on a PC and a phone, the track packs' outlines: as in R153 |
| R152 `run_perf152.sh` (its own base: the R152 patch off; B1 and B3 are on both sides here, so nothing about them differs) | all checks passed: hub x 6 (identical 19 + offscreen 54), keyboard x 3 identical (44 / 44 / 44), keepers x 6 same-visible, seed opening x 15 (every sound schedule) identical / same-visible, hotbar, popups, 1,574 packs identical |
| `run_load_guard.sh`, R152 `run_zfight_sweep.sh` | pass (the sweep: every variant, 0 failed steps) |
| hub / market / growth: R149 market + growth, R135 / R132 market, R131 fences, R151 hub displays, hub trees, Cloudy lanterns, base area | pass |
| packs: R151 packs, R152 Void giveaway, R153 pack parts, R152 `run.sh` | pass |
| R154 `run_perf154.sh` | static (-O0 compile of every changed script, load guard, BackgroundMusic, Config.Version, manifest, no listener, no model names), `test_small_shadow154` (12 checks), `run_item_log154.sh` (10 checks; fails on the R153 module), `run_census154.sh` (below) |

### Exactly the differences the perf suites allow (`docs/proposals/R154/tests/perf154_opts.luau`)

`perf153_off.py` now undoes R154's B1 and B3 first (`perf154.patch`), then the R153 patch, so `run_perf153.sh`'s base side is the R153 release's own code; both sides are
fingerprinted the same way and these are the only places they may differ:

1. **B1.** A part whose largest side is under 1.5 studs is compared without its `CastShadow` (written or not, true or false). A part of 1.5 studs or more is compared with it:
   bigger parts keep their shadows, exactly. (The saved map's small parts and the characters are covered by `run_census154.sh`, which compares them as numbers.)
2. **B3, tiers 2 and 1 (R155: tier 1 too).** The near letters (the SurfaceGuis `Letters` of the strips and `KeyLegend` of the pressed keys): `PixelsPerStud` and the labels' `TextSize` left out, their
   `Size` and `Position` compared in studs (pixels / PixelsPerStud), so the same letters on the same spots at 16 and at 12 pixels a stud compare equal.
3. **B3, tier 2 only (tier 1's key window is unchanged).** Of the keys only the rows the phone's window WANTS are compared, on both sides: up to 56 rows (74 before) in the camera's way and 28 behind (unchanged),
   42 each way across the track or looking down (51 before); every key inside is compared with its colour, height and size. Rows kept beyond them (the hysteresis band, the old
   long side while a turn lets go of it) depend on what was bound before, which the smaller window changes. The transient stand-in slabs (`KeyFiller`) are not compared.
4. **B3, tier 2 only.** The pooled click voices keep the last click's pitch, volume and anchor place; which click was last depends on whether a teleported runner lands on a key
   that was already dressed (a click) or dressed that moment (silent), and the shorter window dresses fewer keys ahead. Left out for `KeyClickSound` / `KeyClick` only.

Nothing on tier 3 is allowed to differ, on tier 1 only the near letters (R155), and nothing else on tier 2: the strips, far letters, bars, bed, ground, holes, every sound schedule and every other area are
compared as before (see the table above: identical).

### `run_census154.sh` (rules, then the before -> after tables)

(After the hub merge: the base side is this checkout with `perf154.patch` undone, so the hub tidy, bed ramps and trampolines are on both sides and only B1 / B3 differ. With the tidy in, the hub plaza at tier 3 is 3,186 -> 2,315 casters within 400 studs, 871 -> 0 script-built under 1.5 studs. `R154_BASE=006daa1` gives the old R153-release comparison.)

Builds the census world (the place + every real start-up builder + the hub / keyboard / snow clients) with the R153 release and with this checkout, per tier 3 / 2 / 1 at the hub
and on the track, and checks: no script-built drawn part under 1.5 studs casts a shadow (930 -> 0 at the hub on PC); the saved map's parts are the same (295 tiny casters, the same
casters and non-casters); characters and avatars (any model with a Humanoid) are the same; parts of 1.5 studs and more cast / do not cast exactly as before (it caught the market's
1.7x scaling: see `MarketLayout` above); tier 3 of the keyboard is identical; tier 2 has fewer keys and a smaller letter canvas and no more letters; tier 1 (R155) has the same keys and letters and a smaller letter canvas.

## For the other agent working on `KeyboardTrack.client.lua`

The file is over Roblox's 200-locals limit at `-O0` at the R153 release already (`barTouched`, line ~1172), and this change adds no local (checked: the same error at the same
place). The three places it touches: `function Far.Tune()` (one line plus a comment) right after `local klAll={}`, and `;Far.Tune()` after `Far.Limit()` at the two places a tier
is decided. It assigns `PPS` and `TEXT` (declared in `local LG=C.Legend;local PPS=...;local TEXT=...`), so if those move into a table, `Far.Tune` and the uses in `letterGui`,
`letterLabel`, `newStrip` and `bindStrips` follow. The numbers and the retuning helper are in `KeyboardTrack.lua`, not in the client.

## If the patched code is edited later

`perf154.patch` is the diff of the B1 + B3 changes: `git diff 006daa1 <last B1/B3 commit> --diff-filter=M -- src ':!src/MANIFEST.tsv' ':!src/ReplicatedStorage/ItemPictures.lua' > docs/proposals/R154/tests/perf154.patch`.
`perf153_off.py` stops and says so when a hunk no longer applies.

## R155: the lighter keyboard on tier 1 too

Owner: *"yes"* to "use the lighter phone keyboard on the lowest graphics setting too?". `KeyboardTrack.lua`: `Legend.PixelsPerStudByTier = {[1]=12,[2]=12}`, so the near
letters are 12 px / stud on tier 1 as well as tier 2 (16 on tier 3, unchanged). The client reads it through `K.NearPPS` / `Far.Tune`, so `KeyboardTrack.client.lua` only
got a comment changed (no new local; `check_compile_O0.sh` passes). **Key rows ahead for tier 1 are left alone: it has 45 already, under tier 2's 56**, so its key window,
its keys and its hysteresis band are exactly as they were.

| tier 1 (R154 -> R155) | track | hub |
|---|---|---|
| keyboard keys (keycap meshes) | 1,496 -> 1,496 | 543 -> 543 |
| letters drawn / keyboard SurfaceGuis | 1,079 / 68 (same) | 416 / 28 (same) |
| keyboard letter canvas (M pixels) | **5.7 -> 4.0** | 2.1 -> 1.8 |
| = letter texture, MB (4 bytes a pixel, an upper bound) | **22.8 -> 16.0 (-30%)** | 8.4 -> 7.2 |
| most keys the tier can hold (`K.KeyCap`, 22 columns) | 1,540 -> 1,540 | |

(The canvas falls by less than the near letters' (12 / 16)^2 = 56% because the far letters, 4 px / stud, are unchanged. Tier 2 does the same: 8.2 -> 5.6.)

Tests: `perf154_opts.luau` lets the near letters differ on tiers 2 and 1 (their `PixelsPerStud` and `TextSize` left out, `Size` / `Position` compared in studs), and only the keys,
click voices and stand-in slabs stay tier-2-only; `check_census154.py` now wants tier 1 to have the same keys, SurfaceGuis, letters and instances and a canvas of 60-80% (track) or 70-95% (hub) of
before (tier 3 identical, tier 2 as before); `perf154.patch` was regenerated (the B3 hunks of `KeyboardTrack.lua` and the client comment), and `perf153_off.py` still undoes it
cleanly, so the base side of `run_perf153.sh` is the R153 release's own code; the R149 keyboard test's section 9b now checks tier 1 at 12 px (strips bound and parked, pressed-key
letters, a key pressed on tier 1, every change between tiers 3, 2 and 1) and that tier 1 keeps 45 rows ahead; two new mutations (tier 1 back to 16 px, tier 1 at 56 rows).

**Results** (R155, owner place `b4f113d1-sapkeyver.rbxl` for the fingerprints, `5ea4542b-sapkeee.rbxl` for the census), all PASS: R149 `run_keyboard.sh` (711 checks, + the place scene's 21; `R154ONLY=1 ... mutate`:
8 of 8 caught, the 6 of R154 and the 2 new); R153 `run_perf153.sh` (keyboard fingerprints per tier: tier 3 identical 44 / 44, **tier 2 identical 9 + same-visible 35, tier 1 identical 44 / 44**
with the near letters compared in studs); R152 `run_perf152.sh`; R154 `run_perf154.sh` (census above); R152 `run_load_guard.sh` and `run_zfight_sweep.sh` (every variant, 0 failed steps);
`check_compile_O0.sh` (every script, at most 180 registers). Fixed on the way: the R149 test's label audit read a strip's letters at the module's 16 px / stud, which is only right on tier 3;
it now reads the strip's own pixels a stud (the audit still puts every label over its key's centre).
