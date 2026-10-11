# R158e: a tutorial with no words (R158g: only arrows)

Owner: "shorten it even more ... a red arrow that points players towards the pack when they spawn, after that it tells players to click on the track tp button, then after that they steal, then it tells them to click via the visual mouse indicator. then tp back to base using the tp button and then after that it tells them to plant and after that make sure that the first fruit is always 10 seconds growth time after that it tells them to harvest and sell, and it ends with letting them know the treadmill makes them run faster and every 6 mins gives them a bonus roll for more packs. EVERYTHING that i have described must be visual so no words all just arrows and pointing".

Picture: `tutorial158e.png` (one frame per step on a PC, four on a phone; the real script on the test mock, block scenery: only arrows and hands on the screen). Redo it with `sh docs/proposals/R158e/preview/run_preview158e.sh <scratch dir>`.

## What the player sees (R158g: only arrows)

Owner (R158g): "remove the box at the top from the tutorial entirely, and the big red arrow should only be used when necessary: in that image there are 2 arrows so it's kind of redundant to have 2 arrows. The tutorial should really just be arrows and that's all." Then: "it's not that we can't have 2 arrows at a moment, but each arrow has to fulfil 1 purpose, not 2 fulfilling the same purpose." And: "there will be no skip tutorial button".

There is no card, no avatar, no icon, no picture row, no step dots, no pop or sound, no confetti, no trophy, no skip button, no ground chevrons, no beam, no ring, no key bubble. Nothing on the screen takes a click or tap. What is left:

* **One arrow per goal in the world** (the pack, home, your dirt, the fruit, the market, your treadmill), the one that fits:
  * **hovering over the goal** (a red arrow pointing down at it) when it is on screen and closer than 30 studs;
  * **the big red 3D arrow floating ahead of you**, pointing the way, ONLY when the goal is far (or off to the side) and that arrow is itself in sight: it is the way, and it goes the moment the hovering arrow shows;
  * **a red arrow at the screen edge** ONLY when the floating arrow would be out of sight (the goal is behind you).
  The two that are not needed are not drawn, so two arrows never say the same thing for one goal (the tests check every frame). The choice has a small margin, so an arrow on the border never flickers between two.
* **On a screen button** (TRACK, BASE, a pack's or seed's hotbar slot, the market's Sell crops / Sell all, BONUS ROLL): a red arrow at the button and the pressing hand on it (BONUS ROLL: the arrow alone). Nothing else: no ring.
* **The pressing 👇 on your dirt** (plant step, near it), **the R138 clicking hand** by the pack in your hand (with its pips; the gamepad's R2 key cap), and **a small ring timer** over the first plant (12 dots round the seconds left; it marks the plant, so no arrow hovers there while you are by it; an arrow shows only if the plant is off screen).

| Step | What shows | Moves on when |
| --- | --- | --- |
| 1 | The big red arrow floats ahead and points at the pack (close to it, it hovers over it; behind you, it is at the screen edge). | after 4 seconds |
| 2 | Only the TRACK button: a red arrow and the pressing hand. | you are on the track |
| 3 | The one arrow to the pack. Carrying it: the one arrow to home. | the pack is home (banked) |
| 4 | A red arrow + hand on a pack's hotbar slot; once a pack is in your hand, the clicking hand. Any pack counts. | a pack is opened |
| 5 | Away from home: only the BASE button, arrow + hand (after the pack opens it waits 2.5 s so the reveal plays). | you are at your base |
| 6 | The one arrow to your dirt and the pressing 👇 on it (a seed not in your hand: its hotbar slot first). | a seed is planted |
| 7 | The ring timer over the plant, counting down from 10. | the fruit is ripe |
| 8 | The one arrow to the ripe fruit. | you picked it |
| 9 | The one arrow to the market; in the market window an arrow + hand on "Sell crops", then on "Sell all". | you sold it |
| 10 | The one arrow to your treadmill (you run faster); when you step on it (or after 10 s) the arrow at BONUS ROLL (a bonus roll every 6 minutes) for 5 s. No 6:00 or icons. | after the BONUS ROLL arrow's 5 s |

The owner's `/test tutorial reset / step / done` and `newplayer` set the saved state directly and still work (the client starts again from the first look). There is no way to skip: the 'Skip' request is refused by the server like 'Replay' (plain failure, nothing changes, no free pack). Reduced Motion: nothing bounces, pulses or flows. The top HUD notices and the pity bars no longer have a card to keep clear of (they still honour the `TutorialCardBottom` attribute, which the tutorial no longer sets).

## The 10-second first fruit

When the tutorial is on its plant step, the plant you plant gets its first fruit in exactly 10 seconds. This is done on the server (TutorialProgress), only during the tutorial's plant step, and only once per player: a saved flag (`Fast`) says it was given and the plant's id is kept (`FastCrop`). Only the first fruit is quick; a plant with more fruit grows the others in their normal time, and every later harvest and regrow is normal. A skipped or finished tutorial never gives it.

## The new-player Verity gift

It now comes at the player's first spawn (it was the end of the tutorial). It cannot skip the tutorial: only a pack stolen on the track and brought home ticks the steal step; a gift, a bonus roll or any other grant never does. After the steal, opening any pack counts (the gift too). The notice comes 4 seconds after the gift, after the title screen.

## Saves

Same save as before (`{Version=1, Mask, Done}`, the same bits), plus two optional fields (`Fast`, `FastCrop`); ProfileVersion stays 22. Players who were in the middle of the old tutorial continue on the matching new step (stolen -> open, opened -> plant, planted -> grow / harvest, harvested -> sell, sold -> treadmill). Finished players stay finished. Replay is still refused (R158c), and so is Skip (R158g).

## Files

`BeginnerGuide` (steps, looks, rules), `BeginnerTutorial.client` (the arrows, the hands, the timer: R158g no card), `TutorialProgress` and `TutorialTargets` (server), `PlayerDataService` (only a banked pack ticks the steal step; the quick fruit hook), `PlantGrowth` (the quick plant's other fruit grow smoothly), `FruitGiftService` (gifting waits until the plant step is done), `StarterVerity158d` + rules (gift at first spawn), `StudioTestHelp`, `docs/COMMANDS.md`.

Tests: `docs/proposals/R158e/tests/run_tutorial158e.sh` (the ten steps on the client and on the real player data, no word on screen, the 10-second fruit once, old saves, and mutants that must be caught). Updated on purpose: `tools/tests/test_tutorial.luau`, `test_guide_flow.luau` (R158g: `test_guide_layout.luau` is gone with the card), the R138 / R139 starter tests and the R152 Void giveaway test (the treadmill is step 10 now), the R158d gift test (gift at first spawn).
