# R153: the hotbar (one press = one equip, drag to reorder)

Owner, after installing R152: "players also cant seem to customise their hot bar so they cant drag seeds and reorganise their hotbar fix that, and hotbar also still has issues where i need to put in inputs twice to equip something in the hotbar".

R152 fixed the click logic against a mock that fired a slot's events by hand, in the orders the code expected, with no server. That mock could not show what goes wrong in a real game, so R153 traced the whole path again (press, then `Hotbar.client.lua`, then `Humanoid:EquipTool`, then the server's `Tool.Equipped`, then what is shown in the hand) for every kind of item, and tested it on a closer model of the engine and the server (`tests/engine153.luau`).

## Why a press seemed lost

| # | Cause | Items | Confidence | Fix |
|---|---|---|---|---|
| 1 | The server puts a pack in the hand only after its chip-bag shape is baked: `_holdPack` waits up to 2.5 s (R151 `PackShapes.Await`). This happens often: after joining, and whenever the shape cache has let the pack's shape go. The hand stays empty, so the player presses again. That second press **unequipped** the pack, and only a third press held it. | packs | high | Until its bag is in the hand (or 4 s pass), the pack is "on its way": its slot shows a pulsing green ring, and another press on it is ignored (it is logged). |
| 2 | A pack pressed while another pack's reveal is playing (including a skipped rare cinematic), or while knocked down, was sent back to the Backpack by the server with no sign. | packs (knock-down: everything) | high | The press waits and holds the item as soon as that is over. If the server refuses for that reason first, it says so (`HoldRefused`) and the press waits too. |
| 3 | After a reveal the server equips the reward seed itself. It did that even when the player had picked something else during the reveal, so their item went back to the Backpack. | anything picked during a reveal | high | `_finishOpening` hands the seed over only into an empty hand. |
| 4 | While carrying a stolen pack or in a chase, a pack is refused by the server. It flickered into the hand and back, with no message. | packs | high (as designed, but silent) | Nothing is sent. **FINISH THAT FIRST!** shows instead. |
| 5 | A held fruit is drawn on the client (HeldHarvests): a scan every 0.25 s, then 16 parts a frame. It showed up to about a second late, so a second press put it away. | fruit | medium | Your own new fruit is scanned at once and built 4x faster. On the mock it is now 0.03 s, down from 0.27 s. |
| 6 | Drag never started if the engine keeps a button's primary press to itself (no `InputBegan` on a TextButton for the mouse button or a touch). Then R112 to R152 never saw a press at all, so they never saw a drag. Clicks still worked, through `Activated`. This fits "drag doesn't work at all" exactly. A touch whose InputObject is not the one `UserInputService` reports, or a mouse release that reports the press point again, breaks drag the same way. | drag | medium (cannot run Roblox here; every such engine behaviour is now handled) | A press starts on `InputBegan` **or** `MouseButton1Down`. It follows its own pointer (the touch by identity, else the touch at its point). It ends on `InputEnded` **or** the `MouseButton1Up` of the button it is let go over. Positions work out from the button pressed whether the top inset is included. |
| 7 | A Bag card can move under the pointer between press and release: an item before it is used up and the grid re-sorts. The release was then over another card, and R152 equipped the **wrong** item through that card's `Activated`. | Bag | medium | The grid holds still under a press and redraws after it. A click equips the item that was pressed. |
| 8 | Custom order was lost on every respawn: the Backpack is replaced and the tools come back in the server's order. The bat got a new key each time (`tool-<n>`). A held pack that gains a weather got a new key and moved slots. | order | high | See "The order" below. |

Checked and not a cause here: the CoreGui backpack (line 1 hides it, and nothing turns it back on); ContextActionService (nothing binds the number keys); `GuiService.SelectedObject` (only the title screen sets it, and it restores it); other ScreenGuis over the hotbar (no Active frame or button covers it outside menus). `RequiresHandle` and `ManualActivationOnly` are fine: every tool that needs a Handle has one before it reaches the Backpack.

## How reordering works

- **PC:** press a slot and move more than 12 px. The item lifts: a copy follows the mouse, its slot dims, and the slot under it lights green. Let go on another slot to move it there (the two swap). Let go on the Bag button or the open Bag to take it off the hotbar. Let go anywhere else and nothing happens. A click that wobbles but ends on its own slot is still a click.
- **Phone:** the same with a finger. A 0.4 s hold picks the item up at once. Inside the Bag the hold also stops the grid scrolling under the finger. Dragging a card straight out of the grid works without the hold. A quick tap still equips.
- **Bag to hotbar:** drag any Bag card onto a slot. Whatever was on that slot moves to a free slot, or into the Bag if none is free.
- The shovel keeps slot 1. It cannot be dragged, and nothing can be dropped on slot 1.
- Equipping from the Bag still puts the item on the hotbar (as before). An item taken off the hotbar stays off until it is dragged back or held again.

## The order

The custom order holds for the **whole session**: refreshes, new items, items used up, respawns (each item goes back to its own slot when the server hands it back, even with a refresh in between), a held pack whose key changes, and the bat (now keyed by its name). It is **not saved between sessions**. The hotbar has no saved slot state (`GardenInventoryState` lives only on the client), and saving it would need a PlayerData field and a remote. That is a follow-up if wanted.

## Debug aid: /test hotbar

`/test hotbar` (owner command, F4 box or chat) turns the hotbar log on or off for that player.
- A box top-left shows the last lines. Select the text to copy it. Every new line is also printed in the F9 console as `[Hotbar] ...`.
- The first line describes the device: touch or mouse, screen size, top inset, the learned shifts and how many slots show. Then the slots.
- Each press: `press slot 3: Forest Seed Pack (touch)`, then what it did: `click (release): equip Forest Seed Pack (was Shovel)`, `... is already on its way, press ignored`, `moved to slot 6`, `put in the Bag`, `let go away from it: nothing`. Then what happened: `Forest Seed Pack in the hand 1.84 s after the press`, or `Forest Seed Pack -> Backpack, not by the hotbar (server: opening), 0.21 s after the last press`.
- The command's reply also prints what the **server** sees in the hand, the pack it holds, and its last late holds or refusals, with why: `Forest Seed Pack waited 1.92 s for its shape | Desert Seed Pack refused: busy`.
- The last 60 lines are kept even while the log is off. So turning it on right after a missed press still shows that press.

## Tests (`tests/run.sh [dir] [mutate]`)

- `test_hotbar_real.luau` runs the real Hotbar and the real HeldHarvests through `engine153.luau`, in 6 engine variants x 2 event orders. Variants: InputBegan reaches the button or not; a stale mouse release; Activated wherever it is let go; inset in InputObjects or not. It covers:
  - one press = one equip for pack, seed, fruit, shovel and bat, with mouse, touch and keys, by a player who presses again if nothing shows after 0.5 s;
  - drag to reorder, Bag to hotbar and back, and the order across refreshes, respawn and key changes;
  - presses during a reveal, a knock-down and a carry;
  - a grid that re-sorts under the press, and ScreenGui stacking (an Active backdrop takes the press, a label lets it through);
  - the log, and a seeded random run.
- `test_hold_server153.luau` runs the real ChestService: the hand-off goes into an empty hand only, plus the refusal reasons and the server's log.
- R152's `test_hotbar_click` / `test_hotbar_stress` / `test_hold_race` still pass unchanged. The load-guard lines 1 and 2 of Hotbar are unchanged.
- `mutate`: with the R152 Hotbar, GardenInventoryState, HeldHarvests and ChestService, all 12 client runs fail (14 to 33 checks each) and the server test fails (3 checks).
