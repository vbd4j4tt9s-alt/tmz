# Preview: DAILY and INVITE in the menu wheel

PREVIEW for the owner's approval, not a release. `src/` is untouched; the proposal lives in patched copies made at render time (`preview/make_variant156.py`).
Picture: `menu_wheel_daily.png` (current HUD next to the proposal on a PC 1920 x 1080, a landscape phone 844 x 390, a portrait phone 390 x 844 and a short landscape phone 750 x 311).
Rebuild: `sh docs/proposals/R156/preview/run_menu_wheel156.sh <scratch dir>`.

Owner: "daily and invite can also be put into the menu wheel meaning that we can readjust the menu wheel further up to make space for them this also means we can put the daily notifier at the correct position without anything obstructing it"

## How the 5-option arc is laid out

- Slots 1-3 stay where they are (SETTINGS up, INDEX up-right, SHOP right, 102 px from the MENU button's centre, 64 px buttons). The two new ones continue the arc round the right half: **4 = DAILY** down-right, **5 = INVITE** straight down. `HudLayout.Navigation` accepts slots 1..5; later slots draw over earlier ones (`ZIndex = 2 + slot`).
- `wheelArc(...)` in HudLayout picks, in this order: the usual radius; a smaller one that fits the free band of the screen; a flatter fan (the diagonals pulled in towards the MENU button, arc up to 178 px wide); smaller buttons (56, 52, 48, 44); last resort DAILY / INVITE in a row beyond SHOP (a second ring). Every pair of boxes keeps 8 px apart (the 2 px outlines never touch) and clears the MENU button and the balances, timers, hotbar and jump zone.
- The lower pair sits a little lower than the mirror image (111 px, not 102) so the DAILY badge, which hangs 10 px over its option's top-right corner, has 14 px of clear air under SHOP. On the tight fan the same room comes sideways.
- Nothing is above the badge any more. R155's `Badge.Sizes.Daily`, `Overhang.Daily` and `OverhangTop.Daily` (the "4 px under the screen top" workaround) go; DAILY uses the INDEX badge's `Sizes.Count` / `Overhang.Count`, and the wheel's CanvasGroup already keeps `NotifyBadge151.Margin` (16 px) round every option.

## What moves (MenuShiftY is the MENU button's centre minus h/2; offsets are option centre minus MENU centre, px)

| Screen (HUD area) | MENU centre y (R155 -> proposed) | Radius up / down, arc width | Offsets 1..5 |
|---|---|---|---|
| PC 1920 x 1080 | 540 -> 540 (no move) | 102 / 111, 102 | (0,-102) (72,-72) (102,0) (72,78) (0,111) |
| Landscape 844 x 390 | 195 -> 142 (`MenuShiftY` -53) | 102 / 111, 102 | same |
| Portrait 390 x 844 | 422 -> 399 (-23) | 102 / 111, 102 | same |
| Short landscape 750 x 311 (844 x 390 minus 47/58/47/21 safe-area insets) | 155 -> 114 (-42) | 74 / 75, 174: **tighter radius and flatter fan**, 64 px buttons kept | (0,-74) (96,-41) (174,0) (96,41) (0,75) |

- Computers keep the MENU button centred (as today); the arc only shrinks on small windows. On phones the MENU button moves up until the last option (INVITE) clears the balances (landscape: top of the speed row minus 8 px) or the pity bars and the held item's name row (portrait: hotbar top minus 78 px). The first option never goes above the top of the HUD area (8 px), so Roblox's top bar buttons are never touched.
- Where five buttons do not fit: below about 280 px of HUD height the buttons shrink (see the 640 x 280 row); below about 230 px (600 x 250, 560 x 220) the second-ring fallback is used. A 640 x 360 PC window still has option 1 on the tools tile (as R155 already does). Sweep of 20 sizes (`preview/sweep_wheel156.luau`, the proposed HudLayout, overlaps tested against every HudBoxes box and the real pity bars):

| Screen (HUD area) | MENU centre y (MenuShiftY) | Option px | Radius up / down | Arc width | Shape | Arc top / bottom y | Overlaps |
|---|---|---|---|---|---|---|---|
| PC 1920x1080 | 540 (+0) | 64 | 102 / 111 | 102 | circle | 406 / 683 | - |
| PC 1366x768 | 384 (+0) | 64 | 102 / 111 | 102 | circle | 250 / 527 | - |
| PC 1280x720 | 360 (+0) | 64 | 102 / 111 | 102 | circle | 226 / 503 | - |
| PC 1024x768 | 384 (+0) | 64 | 102 / 111 | 102 | circle | 250 / 527 | - |
| PC 800x600 | 300 (+0) | 64 | 102 / 111 | 102 | circle | 166 / 443 | - |
| PC 640x360 | 180 (+0) | 64 | 102 / - | 102 | second ring (DAILY / INVITE in a row beyond SHOP) | 46 / 212 | option 1 over the tools tile |
| Landscape 932x430 | 173 (-42) | 64 | 102 / 111 | 102 | circle | 39 / 316 | - |
| Landscape 844x390 | 142 (-53) | 64 | 102 / 111 | 102 | circle | 8 / 285 | - |
| Landscape 740x360 | 134 (-46) | 64 | 94 / 95 | 174 | fan | 8 / 261 | - |
| Landscape 667x375 | 140 (-48) | 64 | 100 / 101 | 174 | fan | 8 / 273 | - |
| Landscape 750x311 (safe-area insets) | 114 (-42) | 64 | 74 / 75 | 174 | fan | 8 / 221 | - |
| Landscape 568x320 | 119 (-41) | 64 | 79 / 79 | 175 | fan | 8 / 230 | - |
| Landscape 640x280 | 99 (-41) | 48 | 67 / 67 | 165 | fan | 8 / 190 | - |
| Landscape 600x250 | 125 (+0) | 52 | 86 / - | 86 | second ring | 13 / 151 | - |
| Landscape 560x220 | 104 (-6) | 52 | 70 / - | 178 | second ring | 8 / 130 | - |
| Portrait 430x932 | 466 (+0) | 64 | 102 / 111 | 102 | circle | 332 / 609 | - |
| Portrait 390x844 | 399 (-23) | 64 | 102 / 111 | 102 | circle | 265 / 542 | - |
| Portrait 375x667 | 224 (-110) | 64 | 102 / 111 | 102 | circle | 90 / 367 | - |
| Portrait 360x640 | 199 (-121) | 64 | 102 / 111 | 102 | circle | 65 / 342 | - |
| Portrait 320x568 | 160 (-124) | 48 | 94 / 94 | 94 | circle | 42 / 278 | - |

The second-ring rows are a plain fallback, not drawn in the picture. The shorter portrait phones (375 x 667 and below) get a big move up, because the wheel must stay above the pity bars and the item name row.

## What else must follow if this is approved

- **TravelButtons**: delete the `TopIcons` frame and the R140 block that places it (about 12 lines); BASE / TRACK keep the screen centre. **DailyRewardsClient**: `mount()` becomes `Navigation(dailyButton, 4)` and `Navigation(inviteButton, 5)` (the buttons are parented to the script's ScreenGui first; `styleOption` sizes them).
- **DailyRewardsClient details**: the INVITE "can't invite here" hint (230 x 26, a child of the button) would be clipped by the option's CanvasGroup (16 px margin), so it must move to the script's own ScreenGui. The friend "+N%" chip fits the margin but is only visible while the wheel is open (today it is always in the top row): worth a copy on MENU or a notice. INVITE's click sound changes from `Bubble04` to the wheel's `MenuClick`.
- **HudBoxes users**: `HudBoxes(m, w, h, true)` lists all five options by itself, so the treadmill BONUS ROLL button (TreadmillBonusClient / TreadmillBonusRules.Place, which also reads `MenuShiftY`) keeps clear of them. The SKIP pill (RarePullCard.SkipRect, bottom right) and the pity bars (PityBars155, `HudBoxes(..., false)`, hub only) need no change: the hub box follows `MenuShiftY`, and the arc already keeps the last option above the bars (checked with the real PityBars155 on all four screens). Delete `HudLayout.travel` / `m.Travel` (the BASE / TRACK spot beside MENU from R113; the real buttons are in the top bar row): PityBars155.Place and Hotbar.hudBoxes still reserve it, and with five options it would sit on SHOP.
- **Tutorial**: no step names DAILY or INVITE; the BASE / TRACK pointers use `TravelPair`, which stays. `BeginnerGuide.Obstacles` reads `MenuShiftY` and `MenuSize`, so the card keeps clear of the moved MENU button by itself, and it hides while the wheel is open (`GardenMenuExpanded`). Optional: a one-time "DAILY is in MENU" hint.
- **Gamepad**: the wheel has no explicit selection links today (Roblox picks by direction). With five options set them: MENU up -> 1, right -> 3, down -> 5; the options chain clockwise 1 -> 2 -> 3 -> 4 -> 5 on down / right (reverse on up / left), `SelectionOrder` 1..5, and select option 1 when the wheel opens from the pad.
- **Tests to update**: `R140/tests/test_daily_client.luau`, `R151/tests/test_indexbadge_daily.luau` (both read `TravelButtons.TopIcons` and the old badge numbers), `R129/tests/test_phone_hud.luau` and `inventory_R113/tests/test_tabs.luau` / `layout_dump.luau` (re-run: they rebuild the hub and wheel boxes from `MenuShiftY` / `MenuOffsets`, and the hub is no longer in the middle of a phone's left edge), plus a new check that all five options clear every HudBoxes box on a screen sweep (the sweep script here is the start).

## The closed-wheel badge (suggestion)

With the wheel closed DAILY is hidden inside it, so the MENU button carries the red "!" while a daily reward waits. ChestIndex and DailyRewardsClient each publish how many rewards wait as a PlayerGui attribute (`MenuAlertIndex`, `MenuAlertDaily`); HudLayout's MENU button owns the one badge (the same `IndexRewardAlert` "!", Alert size, overhang 10) and shows it while the sum is above 0, popping when it grows. It stays while the wheel is open (as the Index "!" does today); every option also shows its own count. Instead of the "!" it could show the sum as a number; the "!" was chosen because INDEX and DAILY counts together read as one meaningless figure.

## Approximate preview, not a Studio screenshot

The wheel, its five buttons, the badges, BASE / TRACK and the pity bars are the real GUI trees (the R156 release's scripts, whose HUD is R155's, for "current"; patched copies for "proposed") built under the Roblox mock and drawn by headless Chromium. The hotbar, balances, status card, jump / stick and Roblox's own top bar buttons are stand-ins placed from HudLayout's metrics; the top bar row is 52 px (PC) or 44 px (phones) above the HUD area. Fonts, the sky and shadows differ from Studio, and Reduced Motion is on (no pop or pulse). A wiring smoke test in the scene taps DAILY and INVITE in the open wheel: the wheel closes and the DAILY window opens.
