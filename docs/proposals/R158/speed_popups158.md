# R158: bigger speed popups

You said: "increase the size of the speed popups as they are too small right now".

Picture: `docs/proposals/R158/speed_popups158.png` (before and after, side by side). It is made from the real popup code of both builds running on the Roblox mock, and drawn with Pillow (a block runner, DejaVu instead of Fredoka). It is a good guide, not a Studio screenshot. Make it again with `sh docs/proposals/R158/preview/run_popups_preview158.sh <scratch folder> [out.png]`.

## What you get

On a computer every size of the popup is 1.5 times bigger (to whole pixels). The runner, the camera and the screen stay the same, so the popups simply read bigger.

| | before | now |
|---|---|---|
| text ("+60") | 35 px | **53 px** |
| bolt | 32 px | **48 px** |
| box the bolt and the number sit in | 240 x 58 | **360 x 86** |
| bolt box / gap | 38 / 3 | **58 / 5** |
| outline | 4 px | **6 px** |

(Sizes are for a 1080 p screen at the normal camera distance, 12.5 studs. The colours, font, bolt and tilts are the same.)

What you see on the screen at the normal camera distance, text height:

| your screen | before | now | times |
|---|---|---|---|
| computer 1920 x 1080 | 35.0 px | **53.0 px** | 1.51x |
| laptop 1366 x 768 or 1280 x 720 | 28.0 px | **42.4 px** | 1.51x |
| phone, landscape 932 x 430 | 28.0 px | 41.1 px | 1.47x |
| phone, landscape 896 x 414 | 28.0 px | 39.4 px | 1.41x |
| phone, landscape 844 x 390 | 28.0 px | 36.9 px | 1.32x |
| phone, landscape 812 x 375 | 28.0 px | 35.4 px | 1.26x |
| phone, landscape 667 x 375 / 740 x 360 | 28.0 px | 34.1 / 33.8 px | 1.22x / 1.21x |
| phone, landscape 568 x 320 | 28.0 px | 28.7 px | 1.03x |
| phone, portrait 430 x 932 | 30.2 px | 36.3 px | 1.20x |
| phone, portrait 390 x 844 | 28.0 px | 32.4 px | 1.16x |
| phone, portrait 375 x 667, 360 x 740, 320 x 568 | 28.0 px | 28.3 - 28.7 px | 1.0x |

## Why a phone gets a little less than 1.5x

The popups fly out of your head in a fan (up and to the sides), and the fan is also 1.5 times bigger, so the popups pile up on each other exactly as much as before (about 46% of a popup under others). A computer has the room for that. A phone has not: a landscape phone has only about 140 px above your head, and a portrait phone has the balances and status boxes at the top.

I tried the full 1.5x on every phone against the phone rule from R153 (every popup inside the screen, none over the menu, hotbar or controls, at most 5% touching the balances / status rows on a landscape phone, no more piling up than before). It breaks it: on a 844 x 390 phone the popups cover 61% of each other (before 46%, the rule allows 59%), and on a 320 x 568 phone 242 of 1200 popups leave the screen.

So a small screen shows the biggest size at which the fan still keeps 85% of its area (`SpeedPopupStyle.SizeScale`), and never less than today's size. Computers and tablets (800 x 600 and up) keep the full 1.5x. A phone gets between 1.0x and about 1.5x, as in the table above: the bigger your phone screen, the closer to 1.5x. The phones with no room (375 x 667, 360 x 740, 320 x 568, 568 x 320) stay as they were.

Phone rule, now against before (17 screens, `test_popups158.luau`):

* Every popup stays inside the screen, and none is over the menu, hotbar or controls: **0 problems on every screen**.
* Popups piling up on each other: at most 1.16x what it was (53% against 46% on a landscape phone; the rule allows 1.2x here and 1.25x of R151).
* Popups touching the balances / status rows: on a computer and a landscape phone at most 4.6% (before 4.2%, the rule is 5%). **On a portrait phone more popups now pass behind the balances stack**: 65% of them on 390 x 844 (before 43%) and 47% on 430 x 932 (before 18%); 320 x 568 and 375 x 667 are as before (100% and 90%). The popups are drawn under the HUD, so the boxes stay whole and readable, but the right end of the fan goes behind them. R153 already called this a known limit of portrait phones (it allows up to 100%). If you want it lower, make the portrait popups smaller with `S.Fan.Keep` (higher = smaller phone popups) or `S.Fan.MinSize`.

## Your face

I measured the popups against a head box 1.2 studs wide (an R15 head at the normal camera distance).

* **At rest** (after the 0.4 s fling) the share of popups that touch the head box is at most 0.4 points higher than before on any phone screen (for example 0.7% against 0.5% on 568 x 320; 7.2% against 6.8% on 320 x 568, where the fan is squeezed narrow). On a computer it is much lower now (1.2% against 8.8% at 1080 p) because the fan is 1.5x too.
* **While a popup is born** it starts at your head (the look you approved in R151), so for a moment it is over your head, as before. Averaged over a stream, a "+60" covers 24% of the head box on a computer (before 18%) and 38% on a big landscape phone (before 27 - 29%); the narrow phones, which did not grow, are unchanged. The test keeps this at 40% or less, and at most 14 points more than before.

## What did not change

* The motion and timing: the pop (starts at 45%, back to full size in 0.28 s), the fling (0.4 s, 44 to 104 px, 7 slots), hold and fade (0.5 s + 0.15 s), Reduced Motion.
* The rate: 2 popups per server tick = 10 a second, at most 12 for one award event. Your own popups hold 8 at a time, other players' 3 / 2 / 1. The pooling, the one updater and the 8 Instances of the pool are as before. The client script changed in **one line**.
* The zoom rule from R155: the popups follow the camera distance (half at 25 studs), they are capped at 1.3x when you zoom in, they start to fade at 31.25 studs and are gone at 36.46 studs. The BillboardGui keeps `MaxDistance` 100. Only the way these two distances are written changed: R155 wrote them as text sizes (14 px and 12 px of a 35 px text); with a 53 px text that would have moved them out to 47 and 55 studs, so they are scales now (0.4 and 12/35). The distances are the same.
* The pooled field is 1500 x 1188 (1.5x of 1000 x 792), so the biggest fan still fits at the 1.3x close-up cap on every screen, 4K included.

Zoomed in (the 1.3x cap) the biggest popup box is 11.1% of the screen height on a 1080 p computer (before 7.5%), 16.0% on an 800 x 600 window (before 10.8%) and 21.7% on a big phone (before 20.3%). The text is 68.9 px at 1080 p (before 45.5). Zoomed out to 25 studs it is 26.5 px (before 17.5).

## No work added every frame

* The size of a popup on your screen is worked out **once, when the popup is born** (`SpeedPopupStyle.Layout`: the unit and the fan in one call, numbers in, numbers out). It costs about 8 microseconds, 10 times a second. Nothing in the per-frame code changed. `check_layout_site158.py` fails if the client ever calls it anywhere else.
* The style functions allocate nothing in 20,000 calls (heap growth under 8 KB), and the real client's heap growth over a 15 s stream is the same as before this round (1286 KB against 1284 KB on a computer, 1326 against 1323 on a phone, 1380 against 1379 on a portrait phone).

## Tests

`sh docs/proposals/R158/tests/run_popups158.sh <scratch> [mutate]` (new, registered in `tools/tests/run_all_suites.sh`) runs:

1. `test_popups158.luau`, 142 checks: the new numbers are 1.5x R154's (and everything else R154's), the size share of a small screen, the phone rule on 17 screens now against R154, the head box, the zoom and the field at the 1.3x cap, no allocation, and the real client on 7 screens (also with Reduced Motion).
2. The allocation comparison with the build this round started from (commit 93ce597).
3. The older popup suites, which I changed **on purpose** for the new size: R154 `test_popups154.luau` (235 checks), R153 `test_popups153.luau` (107), R151 `test_speed_popups_style.luau` (190) and `test_speed_popups_client.luau` (345), and the R151 `run_treadmills.sh` check that the popup files changed only in the allowed places.

The numbers I changed in the old suites: text 35 -> 53, bolt 32 -> 48, box 240 x 58 -> 360 x 86, bolt box 38 -> 58, gap 3 -> 5, outline 4 -> 6 (R153 reference: 1.6x -> 2.4x R151, with "1.5x R154 within 3%" as well); fan Base 1.6 -> 2.4 (Max 2.4 -> 3.6, Min 0.6 -> 0.9); field 1000 x 792 -> 1500 x 1188 (4K fan check at the cap); the zoom check "text 14 / 12 px of 35" -> "scale 0.4 / 12/35" (the same 31.25 / 36.46 studs; the text there is 21.2 / 18.2 px); the per-frame size step in a zoom ramp allowed 0.45 -> 0.675 px (53/35); and the unit of a popup is now the screen's unit times the size share. Where a suite looked at a phone it now really uses the phone's size (the R154 test also checks the 844 x 390 size, and sizes on 640 x 360).

Mutation checks (a breakage of a copy of the code must make a suite fail): 29 new ones (`mutate_popups158.py`: R154 sizes back, bolt not bigger, box not bigger, a 2x text, the outline, the fan, the half popup, the field, no size share, no floor, a lax or strict share, one bisection step, a reversed bisection, the fan or the unit ignoring the share, a table allocated in Layout / SizeScale, the zoom cutoffs back in text px, a 2x cap, MaxDistance 30, a slower fling, a tiny pop, 15 a second, a white amount, the client ignoring the share, the client asking for the layout every frame): all 29 killed. The older ones: R154 `mutate154.py` 36 of 36 killed, R153 popup mutants 7 of 7 killed, R151 `mutation_speed_popups.py` 34 of 34 killed. The targets of the R153 and R154 ones were updated to the new numbers.

## Not measurable here

* How the engine draws a 1500 x 1188 pixel BillboardGui with a UIScale inside (R155's field was 1000 x 792; it is bigger than a phone screen in both cases, and only the popups inside it draw).
* A real head: the head box is 1.2 studs at the default camera distance and a 70 degree view; the popups' size is a width of text I estimated with 0.55 em per character.
* If you want them even bigger or smaller: it is one line, `S.Size` in `SpeedPopupStyle` (and the `Fan` and `Field` numbers next to it, which are 1.5x R154's too). The size share of a phone is `S.Fan.Keep` (0.85) and `S.Fan.MinSize` (2/3, today's size).

## Files

`src/ReplicatedStorage/SpeedPopupStyle.lua` (sizes, outline, fan, field, zoom cutoffs as scales, `SizeScale`, `Layout`), `src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua` (one line). Tests and tools: `docs/proposals/R158/tests/` (`run_popups158.sh`, `test_popups158.luau`, `alloc_stream158.luau`, `check_layout_site158.py`, `mutate_popups158.py`), `docs/proposals/R158/preview/`. Changed on purpose: R151 `test_speed_popups_style` / `_client`, `run_treadmills.sh`; R153 `test_popups153.luau`, `mutate153.py`, `run_fixes.sh` (a label); R154 `test_popups154.luau`, `mutate154.py`, `run_fixes.sh` (a comment); `tools/tests/run_all_suites.sh`. `Config.Version` and every frozen file are untouched.
