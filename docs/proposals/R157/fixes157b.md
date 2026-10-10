# R157: five small owner requests

## 1. The "THE TRACK" sign is gone

Owner: "remove the track sign from the game".

**You see:** the castle gatehouse over the track gate has no sign, no gold frame and no "THE TRACK" words any more. The raised keep and its five merlons stay, so the gate keeps its shape.

* `HubDecor151.lua`: the `Gate sign`, `Gate sign frame` and their label are not built.
* Nothing else used those parts. Tests: `docs/proposals/R151/tests/test_base_area.luau` now checks that the sign, its frame and the "THE TRACK" label are gone and that the keep and its 5 merlons are still there (it used to check that the sign was there). The z-fighting sweeps needed no change (a part that is not built cannot fight with anything).

## 2. A full Bag says BAG FULL on the Mech packs

Owner: "if bag is full and player tries to buy a pack or get a pack via the rolls it says bag full".

**You see (shop):** with 200 items in your Bag, both Mech pack buttons (Gems and Robux) read **Bag full** in the same dim look as "Unavailable". You can still press them: a red notice says **BAG FULL! MAKE ROOM FIRST**, you hear the Denied click, and nothing is bought and no Robux window opens. With room in your Bag nothing changes. "Event over" and "Off sale" still win over "Bag full".

* Server (`PremiumService.lua` `State`): each `PackOffers[count]` gets `BagFull = true` when the Bag is the only thing in the way (sale on, data ready, paid random items allowed, and the server's own "the packs would not fit" answer). `GemAvailable` / `RobuxAvailable` stay false, so no purchase can start. The flag is left out otherwise.
* Server: a gem purchase (`BuyPack`) and a Robux press (`RobuxPack`) with a full Bag both answer the same words, `BAG FULL! MAKE ROOM FIRST` (before: "MAKE ROOM FOR N PACKS FIRST!" for gems and "CAN'T BUY THIS RIGHT NOW" for Robux). The full-Bag check now comes before "not enough gems".
* The words live in one place, `MechCatalog.BagFull` (`Button = 'Bag full'`, `Notice = 'BAG FULL! MAKE ROOM FIRST'`); `SimpleGameText.lua` shows that text in the shared red.
* Client (`GamePassClient.client.lua`): the two buttons read "Bag full" and a press shows the notice (the game's red notice stack) and plays Denied. It never sends a purchase.
* **Bonus rolls** already say it, and are left as they are: the server says "SEED BAG FULL! Make room - your roll stays ready." and the roll button reads **BAG FULL!**.
* Tests: `R155/tests/test_mech_coats_server.luau` (section 8), `test_mech_coats_shop.luau` (section 5), and `test_cap155.luau` (the new words).

## 3. Quieter Studio Output

Owner: these lines in Studio Output were called bugs.

* **Hub trees** (`HubTreeLoader151.lua`): the two tree models are other people's assets the game cannot load, and the hub uses its built-in trees. The yellow warning is now one plain line per tree: `[R151 trees] 16637971059 can't be loaded (not your asset); using the built-in trees`. Any other load failure is also one plain line (with its reason).
* **Item pictures** (`ItemPictures.lua`): `[R112] 42 item pictures waiting for pack shapes` is a normal loading note, so it is a plain print now (same text). A real picture failure still warns once.
* **Plant notifications** (`SocialService.lua`): `[R140] "Your plant is ready" notifications are OFF ...` is left as it is. It is a plain print, shown once at start, only in Studio, and it tells you a setup step. (A set-up-but-broken setup warns once at start.)
* Tests: `R151/tests/test_hub_trees.luau` (the print, no warn, the plain words) and `R154/tests/test_item_log154.luau` (the summary is a print, a real failure still warns).

## 4. No white tile behind the mystery pack in DAILY

Owner: "i just need you to remove the white background ... the same for dailies too".

**You see:** on the QUESTS rows ("+1 PACK") and on the LOGIN day cards, the mystery pack is the black pack shape straight on the dark card. No white square.

* `DailyRewardsClient.client.lua`: the quest holder is see-through and the login card has no tile. The "?" shown when the picture cannot be built is a light colour now (it was near-black for the white tile).
* **Readability.** The silhouette colour is near-black (10, 9, 16). On the dark cards (48, 54, 106) and (67, 52, 110) that is only about 1.8 to 1 (the white tile gave about 19 to 1), so the pack would be easy to miss. I kept it a plain black silhouette (nothing says which pack it is) and gave it a **thin light edge**: `ItemPictures.lua` (the silhouette look only) adds a pale lilac copy (228, 222, 255) of every pack part, 14% bigger and pushed straight back behind the dark pack, so only a rim around the outline shows. It cannot cover the dark pack. If the edge cannot be built, the plain black silhouette stays.
* Picture: `docs/proposals/R157/daily_tile157.png` (before and after of one quest row and one login day card, TODAY tag showing; made by `preview/daily_tile157.sh`). It is approximate: the mock cannot draw the 3D pack, so a stand-in pouch shape in the real colours is drawn in its place.
* Test: `R140/tests/test_daily_client.luau` now checks that no holder has a white tile, that the pictures are still near-black, and that each has the light edge, one rim part per body part, bigger and behind it.

## 5. The TODAY tag is easy to read

Owner: "the TODAY is barely visible, colour the letters white and give it a black outline".

**You see:** on the LOGIN window, the card for today has the same yellow tag in the same place and size, but the word **TODAY** is now white with a thick black outline. (It was dark letters on yellow with a thin dark edge, so it nearly vanished.)

* `DailyRewardsClient.client.lua`: the tag's letters are `#FFFFFF`; a black `UIStroke` (2 thick, solid, Contextual so it follows the letters) is added; the old thin text edge is turned off so the two do not stack. The tag's yellow fill, size, text size and position are not touched.
* Picture: the login card in `docs/proposals/R157/daily_tile157.png` shows the tag before (dark letters) and after (white with the outline).
* Test: `R140/tests/test_daily_client.luau` checks white letters, one black Contextual UIStroke 2 thick and opaque, no text edge, the gold fill, and the tag's size and place.
