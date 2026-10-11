# R156 preview: the Bag without green, and without the hint line

Owner: "dont make this green and remove that text saying click to hold and so on". The owner picked **Option 2: no green at all**.
**This is a PREVIEW, not a release.** `src/` is unchanged; the picture is `bag_look.png` (CURRENT on the left, OPTION 2 on the right; PC 1280x720 and landscape phone 844x390; at rest, an item dragged over the Bag, the Discard bin targeted, search + rarity dropdown, the discard popup, and a picked item on the phone).

## What is green today, and why

* **The flood (the screenshot).** Dragging a hotbar item over the open Bag makes the whole sheet the drop target ("out of the hotbar, into the Bag"). `Hotbar.client.lua` `light(b)` puts `cover(b,'DropTarget',C.Green,.55)` over it: a lime frame at 55% plus a 3 px lime rim, over the whole panel. `C.Green` is `Theme.Colors.Mint` (#93FF45), the one colour every "lit" thing uses.
* **The sheet at rest.** R112 made it a dark green sheet (`C.Sheet` #142E23). Everything on it is a green too: cards / tabs `C.Tile` #254C39, selected tab `C.TileOn` #41784C, search box and count `C.Well` #0E2119, plus `GardenMenuStyle.Panel`'s lime trim, header band (#41634D) and header rule. Slots the item can go to get lime outlines (`DropHint`), a picked item a lime ring and a lime "Moving ..." line (`InventoryPanel155`), and the discard popup (`DiscardDialog155`) is the same green.
* The hotbar slots and the Bag button are not green: `C.Slot` = `Theme.Colors.Card` #30366A (navy). The sheet was the odd one out.

## Option 2: what changes (every colour, old -> new)

| What | Where | Old | New |
|---|---|---|---|
| Sheet; rarity dropdown panel | `Hotbar` `C.Sheet` | #142E23 | **#1F2246** (the game's menu panel navy, `Theme.Colors.Panel`; stays 10% see-through) |
| Bag cards, category tabs, rarity button, "To Bag" and x buttons | `C.Tile` | #254C39 | **#30366A** (= `C.Slot`, the hotbar slot / Bag button colour) |
| Selected tab, "Hold" button, drag ghost | `C.TileOn` | #41784C | **#4A5599** |
| Search box, count | `C.Well` | #0E2119 | **#192041** (`Theme.Colors.Inset`) |
| Sheet rim (`GardenTrim`, 48% see-through) | `Hotbar`, after `GardenMenuStyle.Panel` | #93FF45 | **#6A90E1** (`Theme.Colors.Line`) |
| Header rule (`HeaderRule`, 70% see-through) | same | #93FF45 | **#6A90E1** |
| Header band (`GardenHeader`, 32% see-through) | same | #41634D | **#424A80** |
| Lit colour: drop highlight, slot outlines while dragging / picking, picked ring fill, "Moving ..." text | `C.Green` | #93FF45 | **#EAF0FF** (a light neutral; rename it `C.Lit` in the real change) |
| Discard popup panel | `DiscardDialog155` | #142E23 | **#1F2246** |
| Popup rim | same | #93FF45 | **#6A90E1** |
| Popup picture box, the 1 / - / + / All buttons | same | #254C39 | **#30366A** |
| Popup count box | same | #0E2119 | **#192041** |
| "Keep it" button | same | #466E56 | **#424C8A** |

The drop highlight also changes shape (`cover` / `light`): before, fill #93FF45 at 55% opaque and a solid 3 px rim; after, fill #EAF0FF at 14% (a slot or the Bag button) or 8% (the sheet), and a 2 px #EAF0FF rim at 85% opaque. Slots and the sheet use the same style. The **Discard bin keeps its red** (its own `DropTarget`: #FF6060 at 45%, 3 px rim; button #7A2C34; popup Discard #C44048).

**Left alone on purpose:** rarity colours (the Common border line #92A68E on slots and cards is a grey with a hint of green, and the "Uncommon" name in the dropdown is green: both are the game-wide rarity look, `GardenCardMotion` / `GardenTheme`); white selection outlines; the amber / red count and FULL badge; the popup's amber warning text. Other menus keep `GardenMenuStyle.Panel`'s green trim: the Bag recolours its own after the call.

`make_option2_src.py` is these edits as exact replacements (it fails if a line moved), so the real change can follow it line for line.

## The hint text

Removed: the label `Hint` in the Bag's bottom row (made in `Hotbar.client.lua`, set by `InventoryPanel155.Layout`).

| Device | Text removed | Note |
|---|---|---|
| PC (mouse) | "Click to hold • hover for info • drag to move • right-click for more" | shown on any sheet 300 px tall or more |
| Phone | "Tap to hold • hold for info, to move or discard" | only ever shown on tall sheets (portrait); a **landscape phone sheet is shorter than 300 px and never showed it**, so nothing changes there |
| Gamepad | the PC text (the Bag treats a pad as non-touch) | it named click / hover / right-click, which a pad does not have; nothing is lost |

The line "Moving X - tap a slot, the Bag or the bin" with Hold / To Bag / x stays: it is the picked-item bar, not the hint. The bar keeps the **count and Discard only**; the hint shared their row, so the grid size does not change.

**Count position: keep it left of Discard.** They read as one pair ("143/200 [Discard]"), the pick bar and its buttons use the left of the row when an item is picked (and the count never jumps), and the code already places the count from the Discard width. Centring would make it jump when the pick bar appears. The empty left of the bar on PC looks fine in the picture.

## What else follows in the real change

* `Hotbar.client.lua`: delete the label (line 74) **and** `panel.Hint.Visible=not short;` (line 749, which would error); `InventoryPanel155.lua`: the `Hint` lines in `paintPick` and in `Layout` (both are guarded, so they could be left, but go with it). Update the header comment.
* **Tests: none reads the hint** (searched `tools/tests` and every `docs/proposals/*/tests`; only the `DropHint` slot outlines, whose names do not change). On the scratch copy with Option 2 applied: the R155 client suite passes (608 checks, 0 fails, in all 12 engine variants), the R155 tooltip suite passes (pc 84, phone 48, portrait 48) and `check_compile_O0.sh` passes.
* **Docs that quote the hint:** `docs/proposals/R152/game_text.md` (line 220, plus `preview/build_game_text_sheet.py` and `game_text.html`) and `docs/proposals/R155/inventory.md` ("the bottom bar has the hint", "the Bag's hint now says hold for info").
* **The tooltip's "hold for info" mention:** the only such text in the code is the hint itself (`InventoryPanel155` line 288); `ItemTooltip155` has no such text, so nothing else to change. With the tooltip being removed in another change, "hover / hold for info" would have been wrong anyway. (If a tooltip stayed, it would need its panel #0E2119 -> #192041; its rim follows `C.Green` by itself.)
* `C.Green` is also used by the slot "pending" ring and the `/test hotbar` log title; both become #EAF0FF with it.

## An approximate preview, not a Studio screenshot

The real Hotbar / Bag / discard popup GUI trees are built on the Roblox mock (the R155 inventory preview pipeline) and drawn by headless Chromium: Montserrat stands in for Gotham, item pictures are stand-in emoji (the game draws 3D pictures), a neutral blue-grey stands in for the 3D world behind the see-through sheet and slots (R155's green grass tinted them), and gradients / text strokes are approximated. Real colours will differ a little in Studio. In CURRENT the hint line is kept, as it is today. Rebuild: `sh docs/proposals/R156/preview/run_bag_look.sh <scratch dir> [out.png]` (the Option 2 tree is a scratch copy of `src/`, never `src/` itself).
