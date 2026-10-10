# R156 preview: pack-opening reveal fixes (not a release)

Owner: "this skip is not placed at the correct spot it should be at the bottom right side of the screen and additionally the click to collect should be the below the
fruit name and also reduce the size of the seed display so it fits perfectly between the base buttons and the hotbar while also making it so that the skip button only
appears for secret and above".

**This is a preview for approval.** `reveal_fixes.png` shows BEFORE (R155 as it is today) and AFTER (proposed) for every item on a PC (1920 x 1080), a landscape phone
(844 x 390), a portrait phone (390 x 844) and your two Studio windows (1891 x 733, 530 x 593). `src/` is **unchanged**: the proposed change is
`preview/reveal_fixes.patch` (four files: `RarePullRules`, `RarePullCard`, `HudLayout`, a comment in `RarePullCinematic`), applied in a scratch copy to draw the AFTER pictures.
The real change, with its tests, comes after you approve.

## The cause of the SKIP position
`RarePullCard:_placeSkip` calls `Card.SkipRect(w, h, touch, Card.SkipBoxes(...))`. `SkipBoxes` is `HudLayout.HudBoxes(HudLayout.Read(screen size))` (the status / timers stack in the
bottom-right corner, the hotbar and its item line, the balances, MENU, the tools tile, a phone's thumb zones) plus `PityBars155.Reserved`. `SkipRect` starts in the corner, then
walks left (never past the middle) and up (never above 45 % of the height) to the first spot 8 px clear of every box. Those boxes depend on the screen's size alone: nothing asks
whether the HUD is on screen. A story scene hides every ScreenGui (`RarePullCinematic.hideHud`), but the pill is still kept clear of the boxes, so it is pushed left and up by things
that are not drawn. On the mock it lands 360 px from the right and 148 px up at 1920 x 1080 (your window showed about 450 / 220: the same mechanism at its size). Portrait phone:
308 px up.

## The new rule for where SKIP goes
- **Story scene** (Secret / Cosmic / King, HUD hidden): the corner of the device's safe area, **14 px** from the right and the bottom edge (was 12). It keeps clear only of a thumb
  control that is really on screen (`HudLayout.Controls` ignores hidden ones; `Card.ControlBoxes`). On a phone the director holds the controls (`ControlModule:Disable` hides the
  stick and the jump button), so the corner is free. If a build leaves the jump button visible, the pill steps left of the real button (sheet, section 1). To check in Studio.
- **A card that leaves the HUD up** (Secret / Cosmic / King opening in place, "Skip pack animations" on): today's rule, clear of the visible HUD (2 px different: the margin).

## SKIP only for Secret, Cosmic and King
`RarePullRules.CardTimeline` (Common..Mythic) loses its `SkipFrom`: no pill is built, and `RarePullCinematic.Skip` answers false before the hit. **"Skip pack animations" is
untouched**: it still gives Common..Mythic the Quick timing (0.35 to 0.75 s suspense, a shorter card) and still turns a story into the in-place card. **Keyboard / gamepad:** Enter,
B and R2 no longer have anything to skip on Common..Mythic; like a click or tap they still **collect** the result once it is shown (`M.Skip` collects after `ShownAt`, `M.Tap`
after `CollectAfter`). So Common..Mythic are simply not skippable mid-animation; the collect click works as before. Secret / Cosmic / King keep their pill, B / R2 / Enter.

## The card size rule (Common..Mythic; Secret+ in place uses it with its own sizes)
Which code sizes what: `RarePullCard.Create` takes `RarePullRules.Layout`. **Common..Mythic** are always the `'Ladder'` card, wherever the player is (also on the track: "in place"
in your words); only Secret / Cosmic / King switch between the story scene and the compact `'InPlace'` card (a keeper near, on the track, "Skip pack animations" ...). The **story
result** uses the full `Layout` for its words; its seed is the 3D hero (`RarePullRules.HeroDiameter`, `RarePullCamera155`, unchanged).
New: `RarePullCard.FitBand` gives a band of the screen and `RarePullRules.FitLayout` fits five rows in it (rarity word, seed, "1 in N", name, hint), on the screen the card is on
and again when the window changes size (`Card:_refit`):
- **Top** = the bottom edge of BASE / TRACK + a margin. `HudLayout.TravelBottom(GuiService.TopbarInset)` = top bar row's centre + half of `clamp(row - 8, 30, 44)` + 3 px shadow:
  the arithmetic `TravelButtons.layout` draws them by (51 px with its 52 px fallback row). Margin = 1.2 % of the height (at least 8 px). Mythic also stays under its letterbox bar.
- **Bottom** = the highest of the hotbar's top (`HudLayout`: slots + the held item's name line) and the pity bars' top (`PityBars155.Reserved`, glow and held scale included), and,
  in a narrow window where `HudLayout` lifts the balances / status stack beside the hotbar, their top where they reach the middle column the words fill; less the margin.
- **Rows** keep the sizes they had (title .07-.12 of the height, seed .26-.38, "1 in N" .08, name .045, hint .034). If they do not fit, all shrink by one factor k, the words down to
  24 / 20 / 15 / 13 px, the seed down to 44 px (and at most 62 % of the width), so the seed gives the rest. Spare room goes into the gaps (up to .04 of the height); the stack is
  centred. The seed is an exact square on every screen (`Seed.W`), and it rests where the floating one comes to rest, also with Reduced Motion.

| screen (AFTER, mock) | band, px | Common seed | Mythic seed |
|---|---|---|---|
| 1920 x 1080 | 64 .. 893 | 280 px, k 1.00 | 410 px, k 1.00 (band from 104) |
| 1891 x 733 | 60 .. 550 | 190 px, k 1.00 | 256 px, k 0.92 |
| 530 x 593 | 59 .. 328 (the lifted balances) | 129 px, k 0.84 | 144 px, k 0.64 |
| 844 x 390 phone | 59 .. 236 | 83 px, k 0.82 | 88 px, k 0.60 |
| 390 x 844 phone | 61 .. 534 | 219 px, k 1.00 | 241 px, k 0.80 |

`preview/check_fit156.luau` checks it on 19 screen sizes x every rank: rows in order, none outside the band, the title under BASE / TRACK, the hint above the pity bars.

## Where "click to collect!" goes
Directly **under the seed's name**, centred, in every card: `Layout.Hint` row. Common..Mythic and the in-place card: from `FitLayout`. The story result: "1 in N" and the name move up
a little (.78 to .775, .85 to .842) so the hint (.8855) stays above the bottom letterbox bar. The story result has a name ("Mirage Fig Seed"), so it gets the hint under it too. The
corner it used is free for the SKIP pill, which is gone by the hit anyway. "tap to collect!" on a phone.

## What else the real change touches / to decide
- Tests that expect a pill on Common..Mythic change: R151 `test_rare_cinematic`, R152 `test_seed_choice` / `test_seed_collect` / `test_seed_press`, R155 `test_rare_camera155` /
  `test_pity_bars155` / `perf155_opts`. New tests: the corner, the fit (`check_fit156.luau`), no pill on a card.
- **Lucky pack tag** (`PityBars155.TagPlace`) is placed from the OLD layout (between the seed and "1 in N"; under the name on the compact card, where the hint now is). It must follow
  the new rows (the card can publish them). Not in this preview.
- The pity bars are dimmed under a Common..Mythic card in R155; the card now stops above their place anyway (they could stay visible: your call).
- On a portrait phone the balances (top right) are beside the card's title; the card does not avoid them (it did not before).
- Compact Secret+ card: fitted too (title was on BASE / TRACK on a phone); say if you would rather leave it as it was.
- `TravelButtons` should call `HudLayout.TravelBottom` for its row so the two cannot drift (three lines).

## Approximate
This is a **preview, not a Studio screenshot**. The reveal card, the SKIP pill, the hotbar, the pity bars and BASE / TRACK are the real GUI trees, run by the real `RarePullCinematic` on
the Roblox mock and drawn by headless Chromium. The balances, status stack, MENU, tools tile and touch controls are stand-ins placed by `HudLayout`'s metrics; the world, fonts and the
avatar are stand-ins; BASE / TRACK use the 52 px top bar row fallback (the game reads `GuiService.TopbarInset`). `UIAspectRatioConstraint` is drawn as FitWithinMaxSize. Draw it again:
`sh preview/run_reveal_fixes_preview.sh <scratch dir>`.
