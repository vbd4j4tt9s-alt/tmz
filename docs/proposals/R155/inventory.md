# R155: the hotbar and the Bag work like Roblox's own inventory, 200 items max, discarding

Owner: "hot bar and inventory management is still not fixed just make it function like the normal inventory (not look like) it should feel responsive and i have a lot of options to manage my inventory i can have a blank hot bar if i put everything in my bag additionally make the max amount of items a person can hold 200". Then: "allow people to discard items".

Preview: `inventory.png` (the real Hotbar / Bag / discard popup of this checkout on the mock, PC 1280x720 with a mouse and a landscape phone 844x390 with touch; item pictures are stand-in emoji because the game's pictures are 3D). Rebuild it with `sh preview/run_inventory_preview.sh <scratch dir>`.

## What was still broken (found on the mock, R154 Hotbar)

| # | What the player saw | Why |
|---|---|---|
| 1 | Slots refill by themselves; items jump onto the hotbar | Every refresh put any Bag item that was not "stowed" on the first free slot. An item used up, sold, planted or gifted freed its slot and the next Bag item jumped onto it. |
| 2 | A blank hotbar was impossible | Dragging an item into the Bag freed its slot, and the same refresh filled it again from the Bag (R153's own test asserted this). |
| 3 | The Bag and the hotbar disagree | The Bag listed **everything**, hotbar items too, so the same item showed in two places, and dragging a Bag card that was already on the hotbar did odd swaps. On a phone (5 slots shown) items on slots 6-10 were invisible on the bar but still "on the hotbar". |
| 4 | Bag item onto a taken slot pushed things around | The item that was there was moved to another free slot (or vanished into the Bag when none was free) instead of a clean swap. Equipping from the Bag also forced the item onto the last slot when the bar was full, pushing that item off. |
| 5 | The shovel's slot was special | Slot 1 refused every drop and the shovel could not move, so the bar could never be blank. |
| 6 | The layout was lost every session | Nothing was saved; each join started again in arrival order. |
| 7 | A press did two full redraws | The press redrew everything at once (to show the held item), then again a moment later when the hand changed. With 200 items that is two full passes per press. |

## How it works now

**Hotbar.** Same 10 slots and look, same place on screen (the pity bars above it keep their room). Number keys 1-9 / 0 equip or put away that slot; a click or tap equips, again puts away. The held slot lights up on the very frame of the press. The server confirms afterwards, as before (a pack still shows its "on its way" ring until its bag is in the hand). Every slot takes any item, the shovel's too.

**Bag.** The Bag shows only what is **not** on the hotbar (on a phone that also means items on slots 6-10). Open it with the Bag button, the backtick key (like Roblox) or B; a gamepad uses DPad-Up. It keeps the search box, the All / Seeds / Fruit / Tools cards, the rarity filter and the scrolling grid. Search also dims the hotbar slots that don't match. The new bottom bar has the hint, the count **143/200** (amber from 180, red with **FULL** at 200, and FULL on the Bag button too) and the **🗑 Discard** Trash.

**Moving items (every way).**
- **Drag (mouse; on a phone hold 0.4 s first).** You can drag:
  - slot to slot: moves, or swaps if the slot is taken;
  - slot to the Bag (the open sheet or the Bag button): the slot stays **blank**;
  - Bag to a slot: placed there, and if the slot was taken that item goes to the Bag;
  - Bag to Bag: nothing happens;
  - anything onto the Trash: discard;
  - let go anywhere else (the world): the drag is cancelled, nothing moves and nothing is equipped.

  While dragging, the item follows the pointer, every slot it can go to is outlined (so on a phone the drop targets are clear before the finger gets there), and the target under it lights up (red on the Trash).
- **Tap-tap (phones, and everyone).** Hold an item and let go without moving it, or right-click it, or press **Y** on a gamepad. It is **picked**: it gets a ring, every slot it can go to is outlined, and the Bag opens with a bar that says what to do (Hold / To Bag / ✕). Then:
  - tap a slot, or press its number key, or press A on it: the item goes there (swaps if the slot is taken);
  - tap a Bag card, "To Bag" or the Bag button: it goes in the Bag;
  - tap the Trash: discard;
  - "Hold": hold it;
  - tap it again, the ✕, Esc, or anywhere in the world: put it down.
- **Equipping from the Bag** holds the item and leaves it in the Bag; nothing is pushed off the hotbar.

**Where new items go (the rule I chose).**
1. Same kind as a stack you have: it joins that stack, wherever it is (hotbar or Bag).
2. Otherwise the first **free** shown slot (1, 2, 3 ...).
3. Otherwise the Bag. A new item never pushes anything off the hotbar.

Why is a slot blank or free?
- **Blank:** you emptied it by putting its item in the Bag. It stays empty until you put something there, and new items skip it. Putting the **last** item of the hotbar in the Bag makes every slot blank, so "everything in my bag" gives a blank hotbar that **stays** blank, and new items go to the Bag.
- **Free:** it emptied any other way (the item was used up, sold, gifted, planted, or moved to another slot). The next new item may take it. Nothing ever jumps from the Bag onto a slot by itself.

I picked this over Roblox's exact rule (a new tool fills any empty slot) because the owner asked for a blank hotbar that holds. It is the rule the brief recommended: only slots you never deliberately emptied get filled.

**Saved layout.** Which item is on which slot, and which slots are blank, is kept:
- **Across respawns:** each item goes back to its slot or to the Bag, even when the server hands them back in another order.
- **Across sessions:** it is saved as the optional field `Premium.Hotbar155`. That is about 100 characters: an 8-character hash of each slot's stack key plus a blank mask, so long names never bloat the save. The client sends it about 2 s after a change, never in the middle of a respawn. An older server keeps an unknown Premium field as it is, so playing on an R154 server does not lose it. ProfileVersion is unchanged.
- **At join:** the server hands the layout over as the attribute `HotbarLayout155`. While your items arrive, each goes back to its saved slot and everything else to the Bag. When the server says every item is there (`InventorySynced155`, set after the first full tool sync), new items follow the normal rule. A saved slot whose item is gone (used, sold, gifted, planted, stolen while away) becomes free. A broken or old value is dropped quietly; it is never a reason to refuse a save.
- **First session:** a new player, or anyone's first R155 session, fills the bar in arrival order with the shovel first, exactly like R154.

**Kept working.** Gifting (hold, then click a player), selling, planting with a held seed, the shovel and the bat, mutation highlights, the R139 rainbow on new packs, R149 / R151 fruit arrival flashes, the R153 debug log (`/test hotbar` now also prints items held of 200 and every discard), the queued / "on its way" ring, and the tutorial (it still points at the item's slot, or at the Bag button).

R154's seed collect still flies the seed to "the slot it will take, else the Bag button". The answer now comes from the same rule the item follows when it lands (`GardenInventoryState:Target`): its stack's slot, else the first free slot that is not blank (the opened pack's own slot counts when it was the last of its stack), else the Bag button. When every free slot is blank it flies to the Bag button.

## 200 items max (server)

**What counts:** packs, seeds, fruit (the harvest bag) and legacy loot items. **A stack of N counts N.** In this game a stack is only how the Hotbar *draws* identical items. The save holds N separate records, each with its own id, size, weight and traits, and each one is opened, planted, gifted or sold on its own. **Not counted:** plants in the garden, and gear (boots, trails, the shovel, the bat).

The cap is `InventoryStacks155.Cap = 200`, shared by the server (`PlayerDataService:HeldItemCap()`, InventoryCap155) and the Bag's count. Config.lua is left byte-identical because older suites freeze it; a `Config.MaxHeldItems` would override the cap if the owner ever adds one. Every grant path checks `RoomFor` and keeps its old message:

| Path | At 200 |
|---|---|
| Stealing / picking up a world pack, a dropped pack (`CanReceiveSeed`) | doesn't start: "BAG FULL - MAKE ROOM IN UR BAG FIRST" |
| Banking the pack you carried | always lands: while you carry it, its place is kept, so every *other* grant counts it (a full bag never eats a stolen pack) |
| Bonus roll | "SEED BAG FULL! Make room - your roll stays ready." (the roll is kept) |
| Daily login / quest pack | "MAKE ROOM FOR 1 PACK FIRST!" (the claim stays open) |
| Mystery pedestal | not given, owed as before |
| Free Void Pack pedestal | "room", nothing reserved |
| Verity | allowed: it swaps a Void Pack for a Verity Pack, the count does not change |
| Mech pack for Gems | "MAKE ROOM FOR n PACKS FIRST!", no gems taken; the shop does not even offer packs that don't fit (Gems or Robux) |
| Mech pack **Robux receipt** | **never refused for the cap**: the purchase is only offered when it fits, and if an item arrived between the prompt and the receipt the packs are still granted (201) and saved. Only the old storage ceiling (1000 records) makes a receipt wait (NotProcessedYet: Roblox asks again), exactly as before. |
| Gifts received (seed / pack / fruit) | stay waiting in the inbox until there is room (as for a full bag before) |
| Gifts given | the giver is told "Their bag is full." |
| Harvesting fruit | "BAG FULL - SELL OR PLANT SOMETHING FIRST", the fruit stays on the plant |
| Tutorial starter pack | not given, tried again next time |
| Owner test grants | "Inventory full (200 items max) ..." |

**Old saves above 200 keep everything.** Nothing is deleted or cut; such a player simply receives nothing until under 200. The save validators keep their old ceilings (1000 packs / seeds, 500 fruit), so every existing save still loads; this is tested with 350 packs / seeds plus 300 fruit. `HeldItemCount` / `HeldItemCap` are published on the Player for the Bag's count.

## Discarding

**Ways in:**
- drop an item or stack on the Trash in the open Bag (hotbar items too);
- tap-tap: pick it, then tap the Trash;
- right-click to pick, then the Trash;
- gamepad: Y to pick, then the Trash.

**The popup:** "throw it away?" shows the item's picture and name, then "u sure? it's gone forever". For a stack you choose 1, a number (- / + or type it) or All. The buttons are **Keep it** and **Discard**.

**Rare items need a 1 s hold:**
- Secret / Cosmic / King;
- a Mech, Verity or Void pack;
- a Mech or Verity seed or fruit;
- anything mutated (Gold, Diamond ...).

The button fills while you hold it; letting go early starts it again, and a tap does nothing.

**The server decides** (`ChestChaseRemotes.DiscardItems`, InventoryService155). The client sends one item's id and how many. The server finds that item among the player's own Tools, takes its stack (the same key the client drew, `InventoryStacks155`), puts the held one last, and deletes exactly that many records. It frees room under the cap, and nothing comes back (no money, no item). It refuses, saying why, when:
- the data is loading, or can't save;
- it is the shovel, the bat or any other non-item;
- the item is already gone, or the player asks for more than there is;
- the player is carrying a stolen pack or in a chase;
- a gift is being saved;
- that pack is being opened;
- that seed is still flying in after a reveal (R154, first 10 s).

Requests are rate limited. Every discard prints an Output line `[R155 Discard] name (id): threw away 3x Apple Seed (...)` and is listed by `/test hotbar`, so a "my seed vanished" report can be checked.

## Responsiveness (200 items, `tests/perf_inventory155.luau`)

The numbers are CPU time on this machine with the mock's table-based Instances, so the real game spends less. Only the comparison between R154 and R155 matters.

| | R154 | R155 |
|---|---|---|
| a number key until the slot shows as held | 5.5 ms (a full redraw) | **0.12 ms** |
| the redraw that follows | 5.5 ms | 5.3 ms (one, not two) |
| one item changes (full refresh, 190 stacks) | 2.8 ms | 2.9 ms |
| Bag opening (only the rows on screen, ~49 cards) | 41-50 ms | 38-61 ms |
| one scroll step (cards recycled) | 1.7 ms | 1.6 ms |
| an idle frame | 0.42 ms, 0 Instances | 0.43 ms, **0 Instances in 120 frames** |

Nothing runs per frame while idle: the pick ring and outlines are static, the hold bar runs only while held, and the Bag rebuilds only the rows on screen.

## Files

- `src/ReplicatedStorage/GardenInventoryState.lua`: the layout model, rewritten with the rules above (Reconcile, Place, Stow, Target, Remember, Serialize / Parse / Restore, GoLive).
- `src/ReplicatedStorage/InventoryStacks155.lua` (new): stack key, kind, id, the rare test and the hash, shared with the server.
- `src/ReplicatedStorage/InventoryPanel155.lua` (new): the Bag bar (count, Trash, pick bar), tap-tap, search dimming, discarding, saving the layout, join / live.
- `src/ReplicatedStorage/DiscardDialog155.lua` (new): the confirm popup.
- `src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua`: the Bag lists Bag items only; any slot takes anything; drop on the Trash; a hold let go picks; right-click picks; equipping from the Bag stays in the Bag; the instant held paint; the collect target. Lines 1 and 2 are untouched, the main chunk is at 174 registers (as R154), and it still plays no cue but the harvest landing.
- `src/ServerScriptService/ChestChaseServer/InventoryCap155.lua` (new): HeldItemCount, RoomFor, PublishHeld, the saved layout and DiscardRecords, attached to PlayerDataService.
- `src/ServerScriptService/ChestChaseServer/InventoryService155.lua` (new): the DiscardItems and HotbarLayout155 remotes.
- The cap is wired into PlayerDataService (CanReceiveSeed, AddChest options, HarvestPlant, publishing, layout at load), ChestService (reward-landing times), HarvestToolService (InventorySynced155), DailyProgress, VoidGiveaway152, PremiumProgress and PremiumService (receipts), FruitGiftService, RarePackTests, StudioSeedCommands, StudioTestCommands (+ `/test hotbar`), OwnerPlayerCommands, OwnerUpdateCommands82, SecurityGate (rate limits), ChestChaseServerMain (starts the service) and MANIFEST. Config.lua is unchanged.

## Tests: `tests/run_inventory.sh [dir] [all|static|layout|client|server|perf]`

- `test_layout155.luau`: the model alone, with 62 checks and 3000 random operations (never one key on two slots, never a slot pointing at a missing item, blank slots never fill by themselves).
- `test_inventory155.luau`: the real Hotbar through R153's engine model in 6 engine variants x 2 event orders, 117 checks each. It covers every drag path (and the drop-target outlines while dragging), the blank hotbar, tap-tap (touch hold, right-click + number key, gamepad Y / A), instant highlight, search, keys, the count, discarding (amounts, the rare hold, a refusal, the shovel), respawn and rejoin, and the seed collect target.
- `test_cap155.luau`: the real server, 88 checks. It covers the cap on every grant path above, the carried pack, the receipt, the 650-item old save, every discard refusal, stacks, the count, persistence after a rejoin, the remotes and their rate limit, and the saved layout including a broken one.
- `perf_inventory155.luau`: 200 items, R154 against R155.
- R153 `run_hotbar.sh` now ends by running `run_inventory.sh all`, so the whole-game `tools/tests/run_all_suites.sh` runs the R155 suites with the other hotbar tests.
- Older tests updated where the owner's new rules change what is right (each change is commented "R155" in the test):
  - R153 `test_hotbar_real`: the shovel's slot swaps; nothing refills from the Bag; fillers put cards in the Bag for the re-sort check.
  - R152 `test_hotbar_click`: the shovel's slot swaps and the shovel moves; the plum and the clover go in the Bag before the Bag checks.
  - R152 `test_hotbar_stress`: its model follows the R155 rules (any slot takes anything, a Bag card takes the slot, items come back where they were after a respawn).
  - R150 `test_hotbar` and borders_R123: extra fruit so the Bag has cards (it lists Bag items only).
  - R140 `test_daily`, R147 `test_verity_pack`, R152 `test_giveaway_real`: "full" is now 200 items.
  - R148 `test_roster`: its 603 test opens drop their seeds again (a bag holds 200).
  - R151 `check_shape_plumbing.py`: the stack key that must name PackShape now lives in InventoryStacks155.

## For the owner to decide

1. **New items and blank slots.** Now: a slot you emptied into the Bag stays blank, and emptying the whole bar keeps it blank. If you want the strict Roblox behaviour (any empty slot takes the next new item), it is one line in `GardenInventoryState.FirstFree`.
2. **Paid receipts may go over 200.** A Mech pack bought with Robux is never lost: if something arrived between the purchase prompt and the receipt, the packs are added even past 200. The shop never offers packs that don't fit.
3. **Discarding while carrying a stolen pack or in a chase is refused.** The brief asked to refuse "being stolen"; a stolen pack is not in the Bag yet, so the whole Bag waits until the run ends.
4. **The rare hold list** is Secret / Cosmic / King, Mech / Verity / Void, and any mutation. Weather-only items have no hold.
