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

## Review follow-ups

A bug review of the R157b hotfix found six small things. Each is fixed minimally and has a test.

### 1. Test bookkeeping: the track music suite said FAILED though every behaviour check passed

`R157/tests/run_track_music157.sh` wanted `run_track_music157.sh` to sit right before `run_pyramid156.sh` on line 6 of `tools/tests/run_all_suites.sh`. A later merge put `run_early_audio157.sh` between them, so the suite printed FAILED. It now accepts the runner anywhere on line 6 (the same check the other R157 runners use: `sed -n 6p ... | grep -q " <runner>[; ]"`). `run_early_audio157.sh` already did that, and `run_hudlayout_cache157.sh` only looks for its name on line 6 (not position specific), so neither changed.

### 2. The Bag-full notice names the pack count that does not fit

The Bag is full per quantity: with 195 of 200 items the single pack and the 5-pack fit, the 10-pack does not. The old notice ("BAG FULL! MAKE ROOM FIRST" for every quantity) said the Bag was full while the single pack still worked.

**You see (shop):** the button still reads **Bag full** for any quantity that does not fit. The red notice is now exact: one pack says **BAG FULL! MAKE ROOM FIRST**, more says **BAG FULL! MAKE ROOM FOR 10 PACKS FIRST** (with the real count: 5 or 10).

* One function makes the words: `MechCatalog.BagFullNotice(count)` (`BagFull.Notice` for one pack, `BagFull.Many` with the count for more). The server (`PremiumProgress:CanReceiveMechPacks`, so a gem purchase, a Robux press and the shop's State flag) and the shop's own press (`GamePassClient`) all call it, so both say the same thing.
* `SimpleGameText` shows the new words in the shared red, as they are (a pattern, so any count works).
* Tests: `R155/tests/test_mech_coats_server.luau` (section 8: the words per count, the 195-item case where only the 10-pack is refused and the single pack still buys), `test_mech_coats_shop.luau` (the press names the count; the 195-item case), `test_cap155.luau` (195 items: the 10-pack is refused with the exact words, the single pack fits). `mutate_mech_coats.py` has new broken copies that must be caught.

### 3. Room made in the Bag while the shop is open

A "Bag full" press never asks the server, and the shop only read its State on open, when paid random items changed, or when the products changed. If the Bag gained room while the shop was open, the buttons stayed on "Bag full".

**You see:** sell, throw away or open something with the shop open, and the buttons come back by themselves (a Bag that fills up flips them to "Bag full" the same way).

* `GamePassClient.client.lua`: the 200 cap already publishes `HeldItemCount` / `HeldItemCap` on the player (`InventoryCap155.PublishHeld`, the Bag's "143/200"), and a pack carried home keeps its place (`ChestChaseSeedCarrying`). A change of any of the three, with the shop open, reads State again, at most once every 0.5 s (a change inside that time is read when it is over; a change in the middle of a request is read right after it; a shut shop reads nothing).
* Test: `test_mech_coats_shop.luau` (the buttons come back when room is made, flip to "Bag full" when it fills, the cap and the carried pack count, 20 changes in a second are 2 or 3 reads never closer than half a second, the last change is not lost, a shut shop reads nothing, a change during a request is read after it).

### 4. A broken AudioMixer never breaks a click sound

* `InteractionAudio.lua`: `Mixer()` fetches AudioMixer inside a pcall and remembers a failure (one warning; the voices are not routed, they play from SoundService at their own volume; it is not required again on every Play). Each voice's `Route` is in its own pcall, so an error costs that voice its routing only and the pool always has its 3 voices (before, a pool built part-way stayed in the table and `Index % 0` was NaN). The pool is only kept when it has 3 voices, and `Play` never throws: a pool it cannot build is `false` this time and is built again on the next Play.
* `Play` also calls `SoundTiming.Play` inside a pcall. `SoundTiming.Play` routes the sound through AudioMixer first (its own dot-indexed `require`, unchanged: `SoundTiming` is frozen by the R153 swoosh suite), so a mixer that errors on load would throw out of it before the sound started. That throw is caught; the fallback is the plain play (the lead-in offset, then Play), so the click still sounds and nothing reaches the caller.
* Tests: `R157/tests/test_early_audio157.luau` sections B4 (a warm-up that cannot make a Sound), E1 (AudioMixer errors on require: Play returns without throwing, 40 of 40 sounds play, one warning), E2 (a Route that errors for 5 of 30 voices: every pool has 3 voices, none threw), E3 (a Play that waited for the mixer, which arrives broken), E4 (a pool that cannot be built: `false`, then built whole). `run_early_audio157.sh` has new broken copies for each.

### 5. BackgroundMusic had the same early-load race

`BackgroundMusic.client.lua` fetched `require(game:GetService("ReplicatedStorage").AudioMixer)` when it started (to set the volume of its two sound groups). If AudioMixer had not replicated yet the script errored and there was no music for the session. That one line is now `require(game:GetService("ReplicatedStorage"):WaitForChild("AudioMixer"))`; everything else in the script is byte for byte the same.

* `docs/proposals/R151/tests/frozen.sha256`: the BackgroundMusic hash is updated, with a "# R157b review fix (on purpose)" note. `bgm_frozen.sh` and the older "BackgroundMusic untouched" checks read that hash, so they accept it as they did the R156 and R157b changes; `run_music156.sh` and `run_pyramid156.sh` needed no change.
* `run_track_music157.sh`: its "everything but trackIsActive is byte for byte the R156 script" check first turns this one line back (and says so), so the rest is still compared byte for byte.
* Test: `run_early_audio157.sh` checks that BackgroundMusic uses WaitForChild for AudioMixer, and `test_early_audio157.luau` section F runs the real script's start with AudioMixer not there (it waits, then goes on when it arrives).

### 6. A failed light edge leaves the plain silhouette

`ItemPictures.lua`: `pcall(lightEdge, model)` did not undo the rims already added if it failed part-way, so a picture could have a rim on some parts only. On failure every `SilhouetteRim` in the model is now removed, so the picture is the plain near-black silhouette, as its comment says. Test: `R140/tests/test_daily_client.luau` makes the 2nd rim fail and checks the four mystery pictures have no rim left (and have their edge again on the next build).
