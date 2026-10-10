# R158e: a tutorial with no words

Owner: "shorten it even more ... a red arrow that points players towards the pack when they spawn, after that it tells players to click on the track tp button, then after that they steal, then it tells them to click via the visual mouse indicator. then tp back to base using the tp button and then after that it tells them to plant and after that make sure that the first fruit is always 10 seconds growth time after that it tells them to harvest and sell, and it ends with letting them know the treadmill makes them run faster and every 6 mins gives them a bonus roll for more packs. EVERYTHING that i have described must be visual so no words all just arrows and pointing".

Picture: `tutorial158e.png` (one frame per step on a PC, three on a phone; the real script on the test mock, block scenery). Redo it with `sh docs/proposals/R158e/preview/run_preview158e.sh <scratch dir>`.

## What the player sees

The card at the top has no words any more: a big icon, a small picture line (icons, a red ➜, a key cap, a timer's number) and a row of 10 step dots. The owner's face is still the guide (no name tag). Skip is the ⏭ button: tap it twice (the first tap shows ❓).

| Step | On the screen and in the world | Moves on when |
| --- | --- | --- |
| 1 | A big red 3D arrow floats ahead of you and points at the pack (far away it points the way; close to it, it hovers over it pointing down). Red chevrons on the ground, a light beam on the pack, a red arrow at the screen edge if the pack is behind you. | after 4 seconds |
| 2 | Same arrow, plus a red arrow, a pulsing ring and a pressing hand on the TRACK button. | you are on the track |
| 3 | The red arrow over the pack and your key in a bubble (E on a computer, a 👆 on a phone, X on a gamepad) with a ring that fills: hold it. Carrying it: the arrow points home. | the pack is home (banked) |
| 4 | A red arrow, ring and hand on a pack's hotbar slot; once a pack is in your hand, the R138 clicking mouse (👆 on a phone, the pad + R2 on a gamepad) and the 5 dots that light up. Any pack counts. | a pack is opened |
| 5 | Away from home: a red arrow, ring and hand on the BASE button. | you are at your base |
| 6 | The red arrow over your dirt and a 👇 that keeps pressing it (a seed not in your hand: its hotbar slot first). | a seed is planted |
| 7 | A ring timer over the plant: 12 dots light up, the seconds count down from 10. | the fruit is ripe |
| 8 | The red arrow over the fruit and your key (E / 👆 / X). | you picked it |
| 9 | The arrow leads to the market (E there); in the market window a red arrow, ring and hand on "Sell crops", then on "Sell all". | you sold it |
| 10 | The arrow on your treadmill. The card shows 🏃 ➜ ⚡ ⬆️ (faster) and 🕒 6:00 ➜ 🎁 (a bonus roll for more packs), and a red arrow + ring on the BONUS ROLL button. The 6:00 is read from the game (TreadmillBonusRules / the server), not written in the tutorial. | you step on it, or after 10 seconds |
| end | 🏆 + 🎁 (the free Forest pack) with confetti for 4 seconds. | |

Between steps a green ✓ pops (after the pack opens it waits 2.5 s so the reveal plays). Nothing in the tutorial takes a click or tap except ⏭. Reduced Motion: nothing bounces, pulses or flows.

## The 10-second first fruit

When the tutorial is on its plant step, the plant you plant gets its first fruit in exactly 10 seconds. This is done on the server (TutorialProgress), only during the tutorial's plant step, and only once per player: a saved flag (`Fast`) says it was given and the plant's id is kept (`FastCrop`). Only the first fruit is quick; a plant with more fruit grows the others in their normal time, and every later harvest and regrow is normal. A skipped or finished tutorial never gives it.

## The new-player Verity gift

It now comes at the player's first spawn (it was the end of the tutorial). It cannot skip the tutorial: only a pack stolen on the track and brought home ticks the steal step; a gift, a bonus roll or any other grant never does. After the steal, opening any pack counts (the gift too). The notice comes 4 seconds after the gift, after the title screen.

## Saves

Same save as before (`{Version=1, Mask, Done}`, the same bits), plus two optional fields (`Fast`, `FastCrop`); ProfileVersion stays 22. Players who were in the middle of the old tutorial continue on the matching new step (stolen -> open, opened -> plant, planted -> grow / harvest, harvested -> sell, sold -> treadmill). Finished players stay finished. Replay is still refused (R158c).

## Files

`BeginnerGuide` (steps, looks, rules), `BeginnerTutorial.client` (the card, the 3D arrow, pointers), `TutorialProgress` and `TutorialTargets` (server), `PlayerDataService` (only a banked pack ticks the steal step; the quick fruit hook), `PlantGrowth` (the quick plant's other fruit grow smoothly), `FruitGiftService` (gifting waits until the plant step is done), `StarterVerity158d` + rules (gift at first spawn), `StudioTestHelp`, `docs/COMMANDS.md`.

Tests: `docs/proposals/R158e/tests/run_tutorial158e.sh` (the ten steps on the client and on the real player data, no word on screen, the 10-second fruit once, old saves, and mutants that must be caught). Updated on purpose: `tools/tests/test_tutorial.luau`, `test_guide_flow.luau`, `test_guide_layout.luau`, the R138 / R139 starter tests and the R152 Void giveaway test (the treadmill is step 10 now), the R158d gift test (gift at first spawn).
