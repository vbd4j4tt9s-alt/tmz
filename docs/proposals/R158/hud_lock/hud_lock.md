# R158 PC HUD lock + MENU higher

## What the owner asked (10 Oct)
- With a 1900 x 313 screenshot of the bottom of the 1920 x 1080 PC HUD (balances bottom-left with their + buttons, the hotbar in the centre with the two pity bars
  over it, the luck rows, the two timers and THE DARKENED card bottom-right): "this should be the absolute layout of gui for all devices throughout, dont look into
  portrait its a waste of time, just keep this all the same except for mobile which the layout is currently ok and frozen. menu can also be higher".
- After the preview: "Menu should sit at A" (the MENU button's centre one third of the way down), and "make sure menu size is not too small and somewhat consistent
  with the original sizes, basically shrinking is ok but just not too much that it looks off or different".

## The idea (previews: `menu_higher.png`, `pc_scale.png`)
- The PC HUD (every window size, consoles too) is laid out as a 1920 x 1080 window and then shrunk to fit. Scale = the smaller of width / 1920 and height / 720,
  never above 1.0. A smaller window shows the same arrangement, only smaller. Nothing is rearranged any more (no 5-slot hotbar, no shorter balance rows).
- MENU sits at option A: its centre is one third of the way down. The wheel opens round it, clear of the balances at every size.
- Phones and tablets (anything with a touch screen) do not change at all. Portrait is not touched.
- `menu_higher.png`: today / A / B on five window sizes. `pc_scale.png`: the shrunk layout on four window sizes (MENU is drawn without a floor there).

## The preview tools (`preview/`)
`sh preview/run_hud_lock158.sh <scratch dir>` draws both pictures from this checkout's real scripts on the Roblox mock (headless Chromium for the picture).
They are approximate, not Studio screenshots.

## Built (10 Oct)
Pictures drawn from the built code (the real scripts on the Roblox mock; approximate, not Studio screenshots): `built_menu.png` (the five PC sizes, wheel closed and open) and
`built_scale.png` (your screenshot's bottom strip, then the same arrangement on four windows, with every piece outlined). Re-draw: `sh preview/run_built158.sh <scratch dir>`.

**On a computer (every window size, consoles too)**
- The HUD is laid out as a 1920 x 1080 window and drawn smaller to fit. The scale is the smaller of width / 1920 and height / 720, never above 1.0. Nothing is rearranged any more: ten
  82 px slots and the Bag, the three 56 px balance rows with their + buttons, the two pity bars and the held item's name rows over the hotbar, the luck rows, the timers and THE DARKENED
  card. The balances are always full size for the scale (the old "shorter rows" rule is gone).
- MENU sits at option A: its centre is a third of the way down. It shrinks only down to 85% of its size (54.4 px instead of 64). Its five options and every badge (INDEX, DAILY, the red "!"
  on the closed button) and the friend chip shrink with it, so they stay in proportion. If the open wheel at that size would not fit between the top and the balances, the MENU button moves
  (it did only at 640 x 360: 1 px lower; at 1920 x 300 the wheel's circle gets tighter) instead of getting smaller.
- BASE / TRACK and Roblox's own top bar keep their real size.
- The hotbar and the balances have no size floor: they shrink with the window, the same amount as everything else. A floor cannot work for them: ten slots, the balances and the status card
  need about 1700 px of laid-out width, so on an 800 px wide window the most a floor could give is 0.47 instead of 0.42 (slots 39 px instead of 34), with the pieces packed 16 px apart.
  Only MENU stays bigger.

| window | HUD scale | MENU scale | laid out as | MENU centre | MENU hub / options | open wheel | gap to balances | hotbar slot | balance row |
|---|---|---|---|---|---|---|---|---|---|
| 1920 x 1080 | 1.00 | 1.00 | 1920 x 1080 | 360 | 64 px | 226 to 503 | 379 | 82 px | 56 px |
| 1366 x 768 | 0.71 | 0.85 | 1920 x 1079 | 256 | 54.4 px | 142 to 378 | 250 | 58 px | 40 px |
| 1280 x 720 | 0.67 | 0.85 | 1920 x 1080 | 240 | 54.4 px | 126 to 362 | 226 | 55 px | 37 px |
| 1024 x 768 | 0.53 | 0.85 | 1920 x 1440 | 256 | 54.4 px | 142 to 378 | 285 | 44 px | 30 px |
| 800 x 600 | 0.42 | 0.85 | 1920 x 1440 | 200 | 54.4 px | 86 to 322 | 196 | 34 px | 23 px |

(All numbers are screen px of the game area under Roblox's top bar.)

**On a phone or a tablet: nothing changed.** A test (`tests/test_touch_lock158.luau`, run by `tests/run_hud158.sh`) takes fingerprints of 25 touch screens (landscape and portrait phones,
a phone with insets, tablets) from the code as it was before this change and fails if any number moves: the layout, the HUD boxes, the real hotbar, balances, status HUD, pity bars, wheel,
DAILY and BASE / TRACK GUI trees, the bars and BONUS ROLL spots, the SKIP pill, the reveal card's band and the tutorial's boxes. A second test (`tests/test_pc_hud158.luau`) checks the computer
HUD on 14 windows: the scale, every piece in its place, MENU's size and place, and that nothing overlaps with the wheel open.

**Tests changed on purpose** (they described the old computer layout): R128 `test_hud` (the hotbar shrinking / 72 px slots), R140 `test_daily_client` (the wheel's offsets are now screen px and
the layout emulation knows the HUD's UIScale), R150 `test_bonus_layout` (the button had a third, smaller size on crowded small PC windows: two sizes remain), R152 `test_sale_money` (the
counters' places are scaled), R155 `test_pity_bars155` (the bars' own numbers are HUD px; the real size is times the scale), R157 `test_hud157` / `test_hud157_client` (balances never shorter,
MENU a third down, no 640 x 360 ring, the tools tile is free while the wheel is open) and `test_hudlayout_cache157` (the computer fingerprints are the new layout; the key has 16 slots now:
the computer layout no longer asks PityBars155; the phone fingerprints are byte-for-byte R157's).

## Review follow-ups (10 Oct)
A review of the built HUD lock found six small things. All six are fixed on computers only. Phones and tablets did not change: `tests/test_touch_lock158.luau` passes untouched. At scale 1
(1920 x 1080 and bigger) nothing changed either: its fingerprints are the same as before. The new checks are section 7 of `tests/test_pc_hud158.luau` (run on all 14 windows) and ten new
"teeth" in `tests/run_hud158.sh` (each fix is taken out once; the test must notice).

**1. Small text was too small on small windows.** The text rules (a smallest size, and the switch to the short words) were written in HUD px, and a window at scale 0.42 shrinks HUD px
too: a rule of "8 px" gave 3.3 px on the screen. Now each smallest size is a real screen size. A smallest size m becomes m / scale in HUD px (7 real px at scale 0.42 is 17 HUD px), but never
more than one line of its own box holds, and at scale 1 it is the same number as before. How:
- `GardenTextFit.Floor(minimum, scale, height)` does the sum. `GardenTextFit` finds the scale from the UIScale named `HudScale` above the label (the name is now a contract; `WorldStatusHud`
  names its UIScale that way too, on a computer under scale 1 only). Only small minimums (up to 9 px) are treated as "readable text"; bigger ones (the wallet's 29, the status card's 13 and
  16) are the label's design size and keep their HUD value. So the wallet and the status numbers are not changed.
- Slot names (`Hotbar.client.lua`): smallest 7 real px where the strip can hold it. The name strip is 24 HUD px tall and holds two lines (two-word names), so its smallest size is
  at most what two lines hold, 9 HUD px (a bigger one ran the second line into the weight and the next slot in the picture; I tried 17 at 800 x 600 and drew it). So on the smaller
  windows the smallest name is 6.4 - 3.8 real px, not 7: that is the limit of a strip 10 real px tall, not of the rule. Names that fit on one line draw at their full size.
- The held item's name: smallest 8 real px, through the same fitter. (The Hotbar's own 11 / 14 constraint on that label is not what sizes it, GardenTextFit is, and its minimum was 8: that 8
  is the one held.) The Bag button's word and the traits row follow the same rule.
- The pity bars' words (`PityBars155`): smallest 8 real px (the HUD size that shows as 8, at most what one line of the bar holds: 19 HUD px). The bar is now measured at its real
  on-screen width, so where the full words do not fit at that size the short ones come ("next one's lucky!", "LUCKY! x1.5"): that happens under scale 0.5 (800 x 600). The bars' "readable"
  rule (`B.MinText`, 9) is real px too.
- Long names that cannot fit at their smallest real size are cut with "..." (as the fitter always did at its smallest size) instead of shrinking to 3 px.

What is drawn, in screen px (before -> after). "Names" = the slot names (smallest to biggest size), "held" = the held item's name for a short name, "bars" = the pity words:

| window | scale | names | held | bars |
|---|---|---|---|---|
| 1920 x 1080 | 1.00 | 7.0 - 13.0 -> 7.0 - 13.0 | 14.0 -> 14.0 | 15.0 -> 15.0 |
| 1366 x 768 | 0.71 | 5.0 - 9.2 -> 6.4 - 9.2 | 10.0 -> 10.0 | 10.7 -> 10.7 |
| 1280 x 720 | 0.67 | 4.7 - 8.7 -> 6.0 - 8.7 | 9.3 -> 9.3 | 10.0 -> 10.0 |
| 1024 x 768 | 0.53 | 3.7 - 6.9 -> 4.8 - 6.9 | 7.5 -> 8.0 | 8.0 -> 8.0 |
| 800 x 600 | 0.42 | 2.9 - 5.4 -> 3.8 - 5.4 | 5.8 -> 8.3 | 6.3 -> 7.9 (short words at 9/10 and in the pop) |

The smallest the old rules allowed, at 800 x 600, was 2.9 px (names), 3.3 px (held name) and 3.3 - 3.75 px (bars); now 3.8, 8.3 and 7.9. Sizes only grow where they were under their real minimum, so the bigger windows
look the same. The held item's name box and the Bag button's word are a bit bigger at 1024 x 768 and 800 x 600 (the Bag word 14 -> 15 and 14 -> 20 HUD px: 8 real px).

**2. BONUS ROLL drifted away from the pity bars on small windows.** TreadmillBonusRules (frozen) counts the held item's name rows as a fixed 44 px over the slots. On a scaled HUD the rows are
77 x scale px tall, so under scale 0.61 the lift that `PityBars155.ButtonSpot` worked out was negative and was cut off at 0: the button floated 13.8 px over the bars at 1024 x 768 and
22.8 px at 800 x 600. `ButtonSpot` no longer cuts the lift off on a scaled computer HUD (a phone and a window of 1920 x 720 or more keep the cut-off: unchanged). The fallback in
`TreadmillBonusClient` (no PityBars155) asks the rules through the new `HudLayout.RulesView(m)`, which lowers the hotbar's bottom by 44 x (1 - scale) so the rules' 44 px end where the scaled
rows end. Gap from the button to the bars (px, the button sits on whole pixels so it is 7.0 - 7.8): 1920 x 1080 7.0 -> 7.0, 1366 x 768 7.3 -> 7.3, 1280 x 720 7.0 -> 7.0, 1024 x 768 13.8 -> 7.8,
960 x 540 15.5 -> 7.5, 800 x 600 22.8 -> 7.8, 640 x 360 11.0 -> 7.0, 1280 x 400 12.0 -> 7.0, 420 x 420 37.6 -> 7.6. Without the bars the button sits 10 px over the name rows at every size.

**3. Menus sat too close to the hotbar.** `Hotbar.client` publishes `ChestHotbarReserve` in screen px (scaled) but `GardenMenuStyle` took an unscaled 54 px off it (the name rows' share). The
Hotbar now also publishes the HUD scale as `ChestHudScale` (nothing at scale 1: no new attribute on a phone) and the 54 is times it. The gap between a menu's bottom and the slots is
8 + 12 x scale px where the reserve rules (20 at scale 1, as it was) and the old 64 px floor takes over under scale 0.6 (never under 15 px anywhere). Gap now (before): 1920 x 1080 20.0 (20.0),
1366 x 768 16.7 (5.1), 1280 x 720 16.3 (9.3), 1024 x 768 21.9 (21.9), 960 x 540 25.0 (25.0), 800 x 600 32.8 (32.8). Test: at least 12 real px on all 14 windows.

**4. The SKIP corner's 80 px minimum was 80 HUD px.** `B.SkipZone` was asked in HUD px, so on a short window its 80 px minimum was 80 x scale on the screen (48 px at 1920 x 300). The scaled
HUD now asks it of the real window and draws the answer back in HUD px: the minimum is 80 real px. Test: the bars, placed with the hotbar pushed into the corner, stay clear of the real zone.

**5. `HudLayout.pcLayout` read `L.PcScales`, which is not in the cache key.** Replacing it would have left a stale layout in `L.Read`'s cache. The scales are now a local function
(`pcScales`); `L.PcScales` is still there for callers but nothing in the layout looks it up. The key comment says exactly what is read. A cache hit still allocates nothing
(`run_hudlayout_cache157.sh`). Test: replacing `L.PcScales` and asking a new size gives the right scale.

**6. `B.Extent` had a `k` nobody passed.** Removed: `B.Extent(rect, barW, barH)` works in the units it is given (HUD px for a scaled answer's `Hud`); the two tests that passed `k` now scale
the answer themselves. `B.Words` / `B.TextSize` got an optional `k` (the HUD scale: nothing at scale 1, so phones and 1920 x 720 and bigger take the old code path).

Tests changed on purpose: R155 `test_pity_bars155` (the SKIP corner is real px; the words are chosen and sized for the HUD scale) and `run_pity.sh` (one mutation's pattern), R157 `test_hud157`
(`B.Extent` has no `k`), R158 `test_pc_hud158` (section 7; the fingerprints of the hotbar and status trees at 1366 / 1280 / 1024 / 800 and the bars at 800 x 600 changed: text sizes, the status
UIScale's name, the short words; 1920 x 1080 is unchanged).
