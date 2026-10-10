# R156 preview: the pity bars, closer to the hotbar, with the clover, in clover green and gold

Picture: **`pity_bars_v2.png`** (PC 1920 x 1080, a landscape phone 844 x 390 and a portrait phone 390 x 844; R155 as it is on the left of every pair). Remake it with
`sh docs/proposals/R156/preview/run_pity_v2_preview156.sh <scratch dir>`. **A preview, approximate, not a Studio screenshot, and not a release**: the bars are the real GUI
tree (`PityBars155` with `preview/pity_bars_v2.patch` applied to a scratch copy; `src/` is untouched on this branch) on the Roblox mock, drawn by headless Chromium; the hotbar
slots, the held item's name rows, the item tooltip, balances, status, MENU, the touch controls and the BONUS ROLL button are stand-ins placed by `HudLayout`'s metrics and the
bars' own answers. The owner picks first; the real change (src, tests, docs) comes after.

Owner, in order: "the pity bar is too high up and should be closer to the hot bar like really close but with a small gap. the icon for the pity bars should also the clover and make
them a colour that pairs well with the clover" -> then picked the colours: **NORMAL = clover GREEN, EVENT = GOLD AND GREEN.**

## 1. Why the bars sat high

`PityBars155.Place` put the bars `Lift` (6 px) above the held item's **name and traits rows**, and those two rows are 44 px tall and always reserved, even with nothing held
(`Hotbar.client`: `SelectedName` 26 px at -44, `SelectedTraits` 16 px at -18 above the slots; `HudLayout.HudBoxes` / `TreadmillBonusRules` use the same 44). So the gap from the bars'
bottom to the slots' top is **50 px** in the layout (the owner reads about 60 off a screenshot: the same stack, give or take the screenshot's scale). Everything else stacks above
that: the item tooltip, the BONUS ROLL button (above the bars' extent) and the SKIP pill (kept clear of it).

## 2. The proposal

**Gap** (bars' bottom edge to the slots' top): **PC 8 px** (1920 x 1080, and the owner's 1405 px window: the layout is in px, the bars are 230 x 24 on both), **phones 6 px**
(5 px on a thin 16 px bar), tablets / touch PC 6 px. On all 36 screens R155's test uses it is 6-8 px and a clear spot is found on every one (R155: 50 px; 6 px only on the 320 x 568
phone, which has no name rows). The held bar's 2 px rim and the selected slot's 2 px ring both fit in it. Gaps are `B.Gap(phone, barH)`.

**What must move** (shown in the picture):
1. **The held item's name and traits rows go ABOVE the bars** (`Hotbar.client`: their offsets become -(row + 42) / -(row + 16), `row` = `PityBars155.NameRow` = the bars' top + 3 px,
   35 px on a PC, 29 px on a phone; the bars write it as a PlayerGui attribute `PityBarsRow`, like `ChestHotbarReserve`, and the hotbar lays out again when it changes). With
   nothing held the rows are empty. Polish shown in the picture: with no traits line (a pack: the usual case) the name drops into the traits row so it sits right over the bars.
2. `Reserved` (the box the **SKIP pill** and the **BONUS ROLL button** keep clear of) now includes those rows: both stay clear of bars, rows and slots on all three screens (the
   preview prints a CHECK line each). The BONUS ROLL button is 3-5 px lower than in R155 (same stack height, other order); the SKIP pill is 4 px lower on phones, and on a PC it moves
   from beside the hotbar to the corner above the status stack.
3. **The item tooltip** (`ItemTooltip155`) needs no change: it already sits above the highest of the bars and the name rows, so it is above the name now (67 px above the slots; R155
   88 px), over nothing.
4. **Two small phones lose the name rows**: on 360 x 640 and 360 x 740 portrait the taller stack would reach the MENU hub / BASE-TRACK, so `HudLayout`'s own "details" test (44 px
   today, it must learn the extra row) hides the held item's name there, as it already does on 320 x 568. The bars stay 6 px above the slots. The 7 PC windows where the rows' box
   (as wide as the hotbar) touches the balances / status already did in R155; the text is centred and short, so nothing is covered. (`preview/screens156.luau`, 36 screens.)
5. Bars get a little more room: 360 x 640 goes from a thin 113 x 16 pair to 133 x 20, 360 x 740 from stacked to side by side; iPhone SE landscape goes 130 -> 110 px wide
   (text still fits).
6. For the real change also: tests that pin gold / purple, the diamond, "above the item name" and 44; `pity.md` section 3; the event notice / tag emoji is a gold star now (the purple
   heart no longer matches).

## 3. The icon

The **clover picture decoded from `CloverPassImage153`** (the game's drawn copy of the uploaded image 121815230112848, 128 x 128; `preview/decode_clover156.py` decodes the same
stream `EmbeddedImage153` does), not the `PremiumEmblems` shapes. In the game `CloverIcon153.Attach` shows the uploaded asset first and this copy while it loads. It replaces the diamond
on both bars at the left end, on a dark disc with a rim in the bar's colour so it still reads over the fill; the fill and its ten steps now start after the disc (the diamond used to
hide most of 1/10).

## 4. Colours: the owner's pick, in two shades (picture sections 3 and 4)

| | Shade 1 **"Fresh"** (the clover picture's own lime / leaf green) | Shade 2 **"Deep"** (an emerald) |
|---|---|---|
| NORMAL fill, top -> bottom | `#6ED746` -> `#0A7824` | `#50C878` -> `#066440` |
| NORMAL rim / held rim / glow | `#60CE3C` / `#D6FFA0` / `#AAFF6E` | `#28A060` / `#AAFFC8` / `#6EF0A0` |
| NORMAL empty track / text outline | `#082410` / `#063412` | `#061E16` / `#022816` |
| EVENT fill, top -> bottom (both shades) | `#FFF296` -> `#FFC02C` | same |
| EVENT clover-green rim / held rim | `#46C434` / `#96F450` | `#22AA64` / `#78F096` |
| EVENT empty track / glow / text outline | `#281E08` / `#FFD646` / `#422A02` | `#221A0A` / same / same |
| Clover disc | `#062E12` | `#04281A` |

Text stays white with a dark outline (2 px; white vs outline 13-16:1), "3/10 pity" / "3/10 event pity" as before. Both shades keep the 9/10 glow, the held-pack highlight (brighter
rim, 1.06x, the other bar a little dimmer) and the lucky pop.

**How the two bars still tell apart, both being green:** (1) the fill: green vs gold, 70-100 degrees of hue AND 27-33 L* apart (the gold is pale, the green leaf-dark), so greyscale
and colour-blind viewers still see two bars (distance between the fills, dE2000: shade 1 34 normal / 20 greyscale / 23 deuteranopia / 17 protanopia; shade 2 39 / 25 / 31 / 25; 10 is obvious
at a glance). I first had a lime green as light as the gold: protanopes saw the same colour (dE 1), so the green was darkened until the worst case was 17+. (2) the track tint, green-black vs
warm-black, so an empty bar has a colour too; (3) the rim: clover green on the event bar, pale mint on the normal bar; (4) the words and the order ("pity" left, "event pity" right); (5) the
bar not in hand dims .85 (was .75) and its track is more opaque (.12, was .22), so a gold fill over grass does not turn olive. Checked over grass (the hard case), sand, snow and night.

## 5. Recommendation

**Shade 1 "Fresh"** with the new position: it is the clover's own green, so the icon and the bar read as one thing, and its worst colour-blind distance (17) is enough. Take **Deep** if
the owner finds the lime too close to the grass or wants the bars calmer: it separates a little more from the gold and from the garden. Either way: 8 px / 6 px gap, the name rows above
the bars, the clover disc, the gold star in the event notice, and the event bar's gold with the clover-green rim.

Not checked: anything in real Studio (the exact look of Fredoka One, the uploaded clover image loading, a `CanvasGroup` dimming the icon, the real hotbar's selection ring), a real tooltip's
size, the other R156 agents' HUD changes. The patch is a sketch of the change, not a reviewed implementation: no suite was run on it.
