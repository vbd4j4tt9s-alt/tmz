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
