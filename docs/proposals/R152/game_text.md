# R152: every player-facing text, in the owner's voice

Owner: "for any text in the game just type it like how I talk".

How the owner talks (from their messages): casual, short, direct, everyday words, chatty, no formal or fancy wording. "grab a pack", "bring it back to ur base",
"u got this", "not enough cash", "make room in ur bag first", "the darkened is here!!", "nice pull!". A light "u" / "ur", a couple of "!!" now and then.

Rules this pass followed:

- Words only. No number, price, odds (`1/N`), timing, key, remote, attribute or rule changed, `Config.Version` is untouched, and no logic: only string literals and copy tables.
- Spelling stays correct. "u" / "ur" are used lightly (about one line in three), never in names, titles or numbers.
- Every line still says what to do (or what happened). Lines are about as long as before or shorter; the few that grew by a word or two are in boxes that fit them
  (see "Fit on phones").
- Kid friendly. Item, seed, pack, biome and keeper names are proper names and stay ("Fire Pepper Seed", "Storm Peaks", "The Darkened", "Void Pack").
- Titles, buttons and refusals keep the caps style they had ("GIVE VOID PACK" is still caps); sentences stay in sentence case.
- "Steal" stays where it is the game's own verb (the STEAL prompt, the "Steal 3 packs" quest, Verity asking you to steal a Void Pack: the game is called Steal A Pack).
  Where a line just says to pick something up it says "grab".

Picture of the screens and notices people see most, with the new words: [`game_text.png`](game_text.png). `preview/game_text.html` draws it with the real FredokaOne;
`preview/build_game_text_sheet.py` looks every text on the sheet up in the source first, so the sheet cannot drift from the code.
Verity's window in its states: [`verity_text.png`](verity_text.png) (redrawn with the new words).

## Where texts come from (so the table below is easy to follow)

- Short red / green / yellow notices at the top of the screen come from the server's long messages through `SimpleGameText` (the server keeps its own sentences as keys
  and never shows them): the table lists the short text and, in "Where it lives", the sentence that makes it appear. Because those keys are checked by older suites and by
  frozen gameplay files (`EconomyService`, `ConcurrentKeeperService`, `TreadmillBonusService`), the new wording is in the copy table, not in those files.
- Sentence notices (rare pack spawned, The Darkened, weather, a gift) are built in `NoticeCopy83`.
- Everything else is a literal in the window or sign that shows it.

## Old -> new

252 strings changed in 21 areas (every row is one old -> new; a row that shows only a piece of a sentence, like ` got `, says what the whole line looks like).

| Area | Strings |
|------|---------|
| 1. HUD notices and refusals (top of the screen) | 43 |
| 2. Shovel, holes and removing a plant | 8 |
| 3. Robux shop, gem shop, game passes and gifting a pass | 68 |
| 4. Boost shop, market and selling | 4 |
| 5. Treadmill and fence upgrade signs | 8 |
| 6. Bag (hotbar and inventory) | 2 |
| 7. Plant Index | 1 |
| 8. Daily rewards and quests | 17 |
| 9. Mystery pack pedestal | 9 |
| 10. Verity | 12 |
| 11. Free Void Pack giveaway pedestal | 12 |
| 12. Gifting a fruit, seed or pack | 26 |
| 13. Pack, plant and harvest refusals | 10 |
| 14. Save problems (the screen when the game sends u out) | 8 |
| 15. Chat announcements | 3 |
| 16. Treadmill bonus roll | 2 |
| 17. Settings | 1 |
| 18. Leaderboards | 2 |
| 19. Title screen | 1 |
| 20. Hub plaques, status HUD and station prompts | 4 |
| 21. Picking fruit, plant lifts, tooltips and the treadmill menu | 11 |

### 1. HUD notices and refusals (top of the screen)

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ReplicatedStorage/SimpleGameText.lua`:12 (when the game says: LEAVE MORE ROOM BETWEEN PLANTS) | `TOO CLOSE!` | `TOO CLOSE! MOVE A BIT` |
| 2 | `ReplicatedStorage/SimpleGameText.lua`:13 (when the game says: PLANT A LITTLE FARTHER FROM THE EDGE) | `TOO NEAR EDGE!` | `TOO NEAR THE EDGE!` |
| 3 | `ReplicatedStorage/SimpleGameText.lua`:14 (when the game says: MOVE CLOSER TO THIS PLANTING SPOT) | `MOVE CLOSER!` | `GET CLOSER!` |
| 4 | `ReplicatedStorage/SimpleGameText.lua`:15 (when the game says: PLANT ON SOIL IN YOUR OWN GARDEN / RETURN TO YOUR OWN GARDEN / RETURN TO YOUR GARDEN FIRST) | `YOUR GARDEN ONLY!` | `ONLY IN UR GARDEN!` |
| 5 | `ReplicatedStorage/SimpleGameText.lua`:16 (when the game says: AIM AT SOIL IN YOUR GARDEN / AIM AT THE TOP OF THE SOIL / KEEP A CLEAR VIEW OF THE SOIL) | `AIM AT SOIL!` | `AIM AT THE SOIL!` |
| 6 | `ReplicatedStorage/SimpleGameText.lua`:17 (when the game says: EQUIP A SEED AND AIM AT YOUR SOIL / EQUIP THAT SEED BEFORE PLANTING) | `EQUIP A SEED!` | `HOLD A SEED FIRST!` |
| 7 | `ReplicatedStorage/SimpleGameText.lua`:18 (when the game says: STEP BACK AND AIM AT THE SOIL) | `STEP BACK!` | `STEP BACK A BIT!` |
| 8 | `ReplicatedStorage/SimpleGameText.lua`:20 (when the game says: FINISH YOUR CURRENT ACTION FIRST) | `FINISH FIRST!` | `FINISH THAT FIRST!` |
| 9 | `ReplicatedStorage/SimpleGameText.lua`:21 (when the game says: YOUR PLANT IS STILL GROWING) | `GROWING... 🌱` | `STILL GROWING... 🌱` |
| 10 | `ReplicatedStorage/SimpleGameText.lua`:22 (when the game says: SEED INVENTORY FULL / BAG FULL - MAKE ROOM IN UR BAG FIRST) | `SEED BAG FULL!` | `MAKE ROOM IN UR BAG FIRST!` |
| 11 | `ReplicatedStorage/SimpleGameText.lua`:23 (when the game says: HARVEST BAG FULL — SELL SOME HARVESTS FIRST) | `BAG FULL! SELL CROPS!` | `BAG FULL! SELL SOME CROPS!` |
| 12 | `ReplicatedStorage/SimpleGameText.lua`:24 (when the game says: THAT SEED IS NO LONGER IN YOUR INVENTORY) | `SEED GONE!` | `THAT SEED IS GONE!` |
| 13 | `ReplicatedStorage/SimpleGameText.lua`:27 (when the game says: THAT HARVEST WAS ALREADY SOLD OR IS NOT YOURS) | `CROP GONE!` | `THAT CROP IS GONE!` |
| 14 | `ReplicatedStorage/SimpleGameText.lua`:28 (when the game says: CASH LIMIT REACHED) | `CASH LIMIT!` | `CASH IS MAXED OUT!` |
| 15 | `ReplicatedStorage/SimpleGameText.lua`:31 (when the game says: FINISH YOUR CHASE FIRST / FINISH YOUR RUN FIRST / FAST TRAVEL IS DISABLED WHILE CARRYING A SEED / STATION TRAVEL IS DISABLED DURING A CHASE) | `ESCAPE FIRST!` | `GET TO UR BASE FIRST!` |
| 16 | `ReplicatedStorage/SimpleGameText.lua`:32 (when the game says: NO EMPTY BASE IS AVAILABLE / YOU DO NOT HAVE AN ASSIGNED BASE) | `NO FREE GARDEN!` | `NO FREE BASE YET!` |
| 17 | `ReplicatedStorage/SimpleGameText.lua`:33 (when the game says: SEED COULD NOT BE STORED) | `SEED NOT STORED!` | `COULDN'T SAVE THE SEED!` |
| 18 | `ReplicatedStorage/SimpleGameText.lua`:35 (when the game says: VISIT THE BUY STATION FIRST) | `GO TO SHOP! 🛒` | `GO TO THE SHOP FIRST! 🛒` |
| 19 | `ReplicatedStorage/SimpleGameText.lua`:36 (when the game says: VISIT THE SELL STATION FIRST) | `GO TO SELL! 💰` | `GO TO SELL FIRST! 💰` |
| 20 | `ReplicatedStorage/SimpleGameText.lua`:38 (when the game says: YOU ALREADY OWN THIS) | `ALREADY OWNED! ✅` | `U ALREADY HAVE THIS! ✅` |
| 21 | `ReplicatedStorage/SimpleGameText.lua`:39 (when the game says: NOT ENOUGH CASH) | `NEED MORE CASH!` | `NOT ENOUGH CASH!` |
| 22 | `ReplicatedStorage/SimpleGameText.lua`:47 (when the game says: SAVING IS OFF - PUBLISH THE GAME AND ENABLE STUDIO API SERVICES) | `SAVING OFF!` | `SAVING IS OFF!` |
| 23 | `ReplicatedStorage/SimpleGameText.lua`:48 (when the game says: PLAYER DATA COULD NOT LOAD - SAVING IS DISABLED THIS SESSION) | `DATA ERROR! SAVING OFF!` | `DATA ERROR! NOT SAVING` |
| 24 | `ReplicatedStorage/SimpleGameText.lua`:75 | `HARVESTED! 🌾` | `PICKED! 🌾` |
| 25 | `ReplicatedStorage/NoticeCopy83.lua`:16 (in: "A Rare Pack just spawned in Jungle!") | ` spawned in ` | ` just spawned in ` |
| 26 | `ReplicatedStorage/NoticeCopy83.lua`:21 | `Eek! The Darkened is here...` | `The Darkened is here!!` |
| 27 | `ReplicatedStorage/NoticeCopy83.lua`:21 (in: "The Darkened is here!!  Two Void Packs are up in Storm Peaks. Verity wants one!") | ` await in ` | ` are up in ` |
| 28 | `ReplicatedStorage/NoticeCopy83.lua`:23 | `The void shifts...` | `The void shifted!` |
| 29 | `ReplicatedStorage/NoticeCopy83.lua`:63 (in: "Your Apple plant got Frosted!") | ` became ` | ` got ` |
| 30 | `ReplicatedStorage/SimpleGameText.lua`:22 (when the game says: SEED INVENTORY FULL / BAG FULL - MAKE ROOM IN UR BAG FIRST) | `SEED INVENTORY FULL — MAKE ROOM BEFORE STEALING` | `BAG FULL - MAKE ROOM IN UR BAG FIRST` |
| 31 | `ServerScriptService/ChestChaseServer/FastTravelService.lua`:67 | `WAIT UNTIL YOU CAN MOVE!` | `WAIT TILL U CAN MOVE!` |
| 32 | `ServerScriptService/ChestChaseServer/FastTravelService.lua`:70 | `STEP OFF THE TREADMILL FIRST!` | `GET OFF THE TREADMILL FIRST!` |
| 33 | `ServerScriptService/ChestChaseServer/FastTravelService.lua`:77 | `FINISH OPENING YOUR PACK FIRST!` | `FINISH OPENING UR PACK FIRST!` |
| 34 | `ServerScriptService/ChestChaseServer/FruitOfHourService.lua`:10 (in: "🌟 Fruit of the Hour: Apple! Sells ×2.0 for the next hour!") | `🌟 Fruit of the Hour: %s sells ×%.1f %s!` | `🌟 Fruit of the Hour: %s! Sells ×%.1f %s!` |
| 35 | `ServerScriptService/ChestChaseServer/PurchaseAnnouncer.lua`:49 (in: "✅ Bought: 10 Mech Packs!") | `✅ Purchased: ` | `✅ Bought: ` |
| 36 | `ReplicatedStorage/SimpleGameText.lua`:40 (when the game says: Your save is not ready.) | `Your save is not ready.` | `SAVE ISN'T READY YET!` |
| 37 | `ReplicatedStorage/SimpleGameText.lua`:41 (when the game says: Choose an item.) | `Choose an item.` | `PICK AN ITEM FIRST!` |
| 38 | `ReplicatedStorage/SimpleGameText.lua`:42 (when the game says: VISIT THE SHOP OR SELL STATION) | `VISIT THE SHOP OR SELL STATION` | `GO TO THE SHOP OR SELL SPOT!` |
| 39 | `ReplicatedStorage/SimpleGameText.lua`:43 (when the game says: Buy this item first.) | `Buy this item first.` | `BUY IT FIRST!` |
| 40 | `ReplicatedStorage/SimpleGameText.lua`:44 (when the game says: TRAINING PAUSED) | `TRAINING PAUSED` | `TRAINING IS PAUSED!` |
| 41 | `ReplicatedStorage/SimpleGameText.lua`:45 (when the game says: 🎁 Treadmill bonus roll ready!) | `🎁 Treadmill bonus roll ready!` | `🎁 BONUS ROLL READY! TAP IT` |
| 42 | `ReplicatedStorage/SimpleGameText.lua`:19 (when the game says: PLEASE WAIT A MOMENT / GARDEN IS NOT READY / Please wait.) | `Please wait.` | `WAIT A SEC!` |
| 43 | `ReplicatedStorage/SimpleGameText.lua`:34 (when the game says: PACK COULD NOT BE STORED) | `PACK COULD NOT BE STORED` | `COULDN'T SAVE THE PACK!` |

### 2. Shovel, holes and removing a plant

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ReplicatedStorage/TrackHoleConfig.lua`:38 | `CAN'T DIG WHILE CARRYING A PACK` | `CAN'T DIG WITH A PACK!` |
| 2 | `ReplicatedStorage/TrackHoleConfig.lua`:40 | `DIG ON THE TRACK GROUND` | `ONLY DIG ON THE TRACK!` |
| 3 | `ReplicatedStorage/TrackHoleConfig.lua`:45 | `%d HOLES MAX - COVER ONE OR WAIT FOR A TRAP` | `%d HOLES MAX! COVER ONE OR WAIT` |
| 4 | `ReplicatedStorage/TrackHoleConfig.lua`:48 | `YOU FELL IN A HOLE! PACK DROPPED` | `U FELL IN A HOLE! PACK DROPPED` |
| 5 | `ReplicatedStorage/TrackHoleConfig.lua`:52 | `Dig holes on the ground to trap players!` | `Dig holes to trap other players!` |
| 6 | `StarterPlayer/StarterPlayerScripts/GardenShovel.client.lua`:68 | `?⏎This removes the plant and its unpicked fruit. The seed is not returned.` | `?⏎This removes the plant and any fruit still on it. U won't get the seed back.` |
| 7 | `StarterPlayer/StarterPlayerScripts/GardenShovel.client.lua`:78 | `Could not remove the plant. Try again.` | `Couldn't remove the plant. Try again!` |
| 8 | `ServerScriptService/ChestChaseServer/HarvestToolService.lua`:22 | `Remove a plant • Dig a hole on the track` | `Remove a plant • Dig holes on the track to trap players` |

### 3. Robux shop, gem shop, game passes and gifting a pass

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:64 | `REWARDS ARE UNAVAILABLE UNTIL YOUR DATA CAN SAVE` | `NO REWARDS UNTIL UR DATA CAN SAVE` |
| 2 | `StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua`:156 | `COMPLETE YOUR PLANT INDEX` | `FILL UR PLANT INDEX` |
| 3 | `StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua`:157 | `Collect Gems from your plant index.` | `Grab Gems from ur plant index!` |
| 4 | `StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua`:151 | `Whole number` | `Type a number` |
| 5 | `StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua`:201 | `Please try again.` | `Try again in a sec!` |
| 6 | `StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua`:221 | `Enter 1–9,000 Gems.` | `Pick 1–9,000 Gems.` |
| 7 | `StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua`:223 | `Enter a whole number of Gems.` | `Type a whole number of Gems.` |
| 8 | `ReplicatedStorage/GamePassCatalog.lua`:4 | `Plants and new fruit grow twice as fast.` | `Plants and new fruit grow 2x faster!` |
| 9 | `ReplicatedStorage/GamePassCatalog.lua`:5 | `Earn twice as much speed while training.` | `Get 2x speed when u train!` |
| 10 | `ReplicatedStorage/PremiumBoostCard.lua`:7 | `Plants grow x2 faster!` | `Plants grow 2x faster!` |
| 11 | `ReplicatedStorage/PremiumBoostCard.lua`:7 | `Train x2 speed!` | `Train with 2x speed!` |
| 12 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:102 | `INVALID REWARD` | `TRY AGAIN!` |
| 13 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:102 | `INVALID CURRENCY` | `TRY AGAIN!` |
| 14 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:104 | `YOUR GARDEN IS LOADING` | `UR GARDEN IS LOADING...` |
| 15 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:107 | `COLLECT YOUR FLOATING REWARDS FIRST` | `UR LAST REWARDS ARE STILL ARRIVING` |
| 16 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:108 | `CURRENCY LIMIT REACHED` | `U'RE MAXED OUT! SPEND SOME FIRST` |
| 17 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:117 | `ENTER A WHOLE NUMBER OF GEMS` | `TYPE A WHOLE NUMBER OF GEMS` |
| 18 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:123 | `Collect your Gems.` | `Ur Gems are on the way!` |
| 19 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:201 | `Collect your Cash.` | `Ur Cash is on the way!` |
| 20 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:127 | `YOUR DATA IS LOADING` | `HOLD ON, UR DATA IS LOADING!` |
| 21 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:128 | `end` | `end` |
| 22 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:148 | `PACKS COULD NOT BE ADDED; PLEASE RETRY` | `COULDN'T ADD THE PACKS! TRY AGAIN` |
| 23 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:102 | `INVALID QUANTITY` | `TRY AGAIN!` |
| 24 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:158 | `THIS PACK IS UNAVAILABLE` | `CAN'T BUY THIS PACK RIGHT NOW` |
| 25 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:169 | `UNAVAILABLE` | `NOT AVAILABLE RIGHT NOW` |
| 26 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:164 | `Mech pack added to your bag.` | `Mech pack is in ur bag!` |
| 27 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:164 (after buying 2+ Mech packs with Gems) | ` Mech packs added to your bag.` | ` Mech packs are in ur bag!` |
| 28 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:194 | `Offer updated. Check the new amount.` | `The offer changed! Check the new amount.` |
| 29 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:201 | `Speed added.` | `Speed added!` |
| 30 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:102 | `UNKNOWN PASS` | `TRY AGAIN!` |
| 31 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:208 | `ALREADY OWNED` | `U ALREADY HAVE THIS!` |
| 32 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:210 | `OWNERSHIP IS STILL LOADING` | `STILL CHECKING WHAT U OWN...` |
| 33 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:218 (after buying a pass with Gems: "Double Speed unlocked!") | ` unlocked.` | ` unlocked!` |
| 34 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:283 | `CLAIM YOUR INDEX REWARDS FIRST` | `CLAIM UR INDEX REWARDS FIRST!` |
| 35 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:102 | `INVALID SEED` | `TRY AGAIN!` |
| 36 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:293 | `NO REWARD TO CLAIM` | `NOTHING TO CLAIM YET` |
| 37 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:102 | `INVALID BIOME` | `TRY AGAIN!` |
| 38 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:302 | `ALREADY CLAIMED` | `U ALREADY CLAIMED THIS!` |
| 39 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:303 | `REACH HALF OF THIS INDEX` | `FILL HALF OF THIS INDEX FIRST!` |
| 40 | `ServerScriptService/ChestChaseServer/PremiumProgress.lua`:314 | `COLLECT EACH SEED AND GROW EACH PLANT` | `FIND EVERY SEED AND GROW EVERY PLANT!` |
| 41 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:42 | `Please wait.` | `Wait a sec!` |
| 42 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:43 | `YOUR DATA IS LOADING` | `HOLD ON, UR DATA IS LOADING!` |
| 43 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:62 | `TRY AGAIN IN A MOMENT` | `TRY AGAIN IN A SEC!` |
| 44 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:76 | `Invalid setting.` | `That setting didn't work.` |
| 45 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:78 | `Please try again.` | `Try again in a sec!` |
| 46 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:70 | `UNKNOWN ACTION` | `TRY AGAIN!` |
| 47 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:93 | `PURCHASES ARE UNAVAILABLE UNTIL YOUR DATA CAN SAVE` | `NO PURCHASES UNTIL UR DATA CAN SAVE` |
| 48 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:95 | `ROBUX PURCHASES ARE UNAVAILABLE FOR THIS SAVE` | `ROBUX PURCHASES AREN'T ON FOR THIS SAVE` |
| 49 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:108 | `Purchase could not open.` | `Couldn't open the purchase. Try again!` |
| 50 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:109 | `THIS PURCHASE IS UNAVAILABLE` | `CAN'T BUY THIS RIGHT NOW` |
| 51 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:111 | `Choose a gift.` | `Pick a gift first!` |
| 52 | `ServerScriptService/ChestChaseServer/PremiumService.lua`:117 | `THIS GIFT PURCHASE IS UNAVAILABLE` | `CAN'T GIFT THIS RIGHT NOW` |
| 53 | `ReplicatedStorage/PassGiftDialog.lua`:26 | `Please try again.` | `Try again in a sec!` |
| 54 | `ReplicatedStorage/PassGiftDialog.lua`:62 | `No other players here` | `No one else is here` |
| 55 | `ReplicatedStorage/PassGiftDialog.lua`:75 | `Finish the purchase; the gift is sent automatically.` | `Finish buying it and the gift goes out by itself!` |
| 56 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:28 | `Gift pricing is unavailable. Try again shortly.` | `Can't get the gift price right now. Try again soon!` |
| 57 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:39 | `Regional pricing does not allow this gift.` | `This gift isn't allowed in their country.` |
| 58 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:43 | `Choose a player.` | `Pick a player first!` |
| 59 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:45 | `Player unavailable.` | `That player isn't here.` |
| 60 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:46 | `Choose Gems or Robux.` | `Pick Gems or Robux!` |
| 61 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:28 | `Try again shortly.` | `Try again soon!` |
| 62 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:54 | `They already own this pass.` | `They already have this pass!` |
| 63 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:57 | `Pending gifts are still saving.` | `Ur other gifts are still saving.` |
| 64 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:58 | `This gift is already pending.` | `This gift is already on its way!` |
| 65 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:60 | `Not enough Gems.` | `Not enough Gems!` |
| 66 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:61 | `No purchased gift ready.` | `No gift is ready to send.` |
| 67 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:66 | `Gift pending. Delivery retries automatically.` | `Gift on its way! It retries by itself.` |
| 68 | `ServerScriptService/ChestChaseServer/PassGiftService.lua`:78 | `Gift pending. Please try again shortly.` | `Gift on its way! Try again soon.` |

### 4. Boost shop, market and selling

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua`:429 | `Visit the market to sell your crops.` | `Go to the market to sell ur crops!` |
| 2 | `ReplicatedStorage/ShopMenu.lua`:18 | `Please wait` | `Wait a sec` |
| 3 | `ReplicatedStorage/ShopMenu.lua`:76 | `No items yet.` | `Nothing here yet!` |
| 4 | `ReplicatedStorage/HarvestSellMenu.lua`:26 | `No crops` | `No crops yet!` |

### 5. Treadmill and fence upgrade signs

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1833 | `Your save is not ready.` | `Ur save isn't ready yet!` |
| 2 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1835 | `The upgrade changed. Try again.` | `The upgrade changed! Try again.` |
| 3 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1838 | `Not enough coins.` | `Not enough cash!` |
| 4 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1847 | `That style is locked.` | `That style is still locked!` |
| 5 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1849 | `Style changed; your training power stays the same.` | `Style changed! Ur training power stays the same.` |
| 6 | `ServerScriptService/ChestChaseServer/GardenFenceData.lua`:17 | `Your save is not ready.` | `Ur save isn't ready yet!` |
| 7 | `ServerScriptService/ChestChaseServer/GardenFenceData.lua`:19 | `The upgrade changed. Try again.` | `The upgrade changed! Try again.` |
| 8 | `ServerScriptService/ChestChaseServer/GardenFenceData.lua`:21 | `Not enough cash.` | `Not enough cash!` |

### 6. Bag (hotbar and inventory)

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `StarterPlayer/StarterPlayerScripts/Hotbar.client.lua`:61 | `Inventory` | `Ur Bag` |
| 2 | `StarterPlayer/StarterPlayerScripts/Hotbar.client.lua`:68 | `Click to equip • Drag a slot or item onto the hotbar` | `Click to hold it • Drag it onto the hotbar` |

### 7. Plant Index

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua`:168 | `Please try again.` | `Try again in a sec!` |

### 8. Daily rewards and quests

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:123 (in: "✅ QUEST DONE: Steal 3 packs! Grab ur 💎5 in 🎁 DAILY") | `! Claim 💎` | `! Grab ur 💎` |
| 2 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:78 | `REWARDS ARE UNAVAILABLE UNTIL YOUR DATA CAN SAVE` | `NO REWARDS UNTIL UR DATA CAN SAVE` |
| 3 | `StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua`:266 | `Please try again.` | `Try again in a sec!` |
| 4 | `StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua`:328 | `Invites are not available here` | `Can't invite here right now` |
| 5 | `StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua`:329 | `Friends here boost your speed gain! 👥` | `Friends here boost ur speed gain! 👥` |
| 6 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:85 | `🤖 FREE MECH PACK! Check your Bag!` | `🤖 FREE MECH PACK! Check ur bag!` |
| 7 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:85 | `🎒 RANDOM SEED PACK! Check your Bag!` | `🎒 RANDOM SEED PACK! Check ur bag!` |
| 8 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:16 | `YOUR GARDEN IS LOADING` | `UR GARDEN IS LOADING...` |
| 9 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:23 | `GEMS COULD NOT BE ADDED; PLEASE RETRY` | `COULDN'T ADD THE GEMS! TRY AGAIN` |
| 10 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:28 | `MAKE ROOM FOR 1 PACK` | `MAKE ROOM FOR 1 PACK FIRST!` |
| 11 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:33 | `DAILY PACK POOL IS UNAVAILABLE` | `DAILY PACKS AREN'T READY YET` |
| 12 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:48 | `PACK COULD NOT BE ADDED; PLEASE RETRY` | `COULDN'T ADD THE PACK! TRY AGAIN` |
| 13 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:69 | `YOUR DATA IS LOADING` | `HOLD ON, UR DATA IS LOADING!` |
| 14 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:88 | `Collect your Gems.` | `Ur Gems are on the way!` |
| 15 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:98 | `INVALID QUEST` | `TRY AGAIN!` |
| 16 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:99 | `ALREADY CLAIMED` | `U ALREADY CLAIMED THIS!` |
| 17 | `ServerScriptService/ChestChaseServer/DailyProgress.lua`:101 | `DAILY QUEST GEM LIMIT REACHED; TRY AFTER THE UTC RESET` | `DAILY QUEST GEM LIMIT HIT! COME BACK AFTER THE UTC RESET` |

### 9. Mystery pack pedestal

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ServerScriptService/ChestChaseServer/MysteryPackService.lua`:143 (followed by the pack name) | `🎁 A waiting Mystery Pack went into your Bag: ` | `🎁 Ur waiting Mystery Pack is in ur bag: ` |
| 2 | `ServerScriptService/ChestChaseServer/MysteryPackService.lua`:144 (followed by the pack name) | `🎁 Yesterday's Mystery Pack went into your Bag: ` | `🎁 Yesterday's Mystery Pack is in ur bag: ` |
| 3 | `ServerScriptService/ChestChaseServer/MysteryPackService.lua`:151 | `Make room in your Bag first.` | `Make room in ur bag first!` |
| 4 | `ServerScriptService/ChestChaseServer/MysteryPackService.lua`:171 (in: "🎁 Make room in ur bag! 1 mystery pack waiting") | `🎁 Make room: ` | `🎁 Make room in ur bag! ` |
| 5 | `ServerScriptService/ChestChaseServer/MysteryPackService.lua`:198 | `🔓 Your Mystery Pack is unlocked! Go home and take it 🎁` | `🔓 Ur Mystery Pack is unlocked! Go to ur base and grab it 🎁` |
| 6 | `ServerScriptService/ChestChaseServer/MysteryPackService.lua`:45 | `Take` | `Grab` |
| 7 | `StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua`:274 | `YOUR` | `UR` |
| 8 | `StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua`:284 | `UNLOCKED! TAKE IT 🎁` | `UNLOCKED! GRAB IT 🎁` |
| 9 | `StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua`:288 | `✓ TAKEN TODAY` | `✓ GRABBED TODAY` |

### 10. Verity

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ReplicatedStorage/VerityConfig.lua`:105 | `I dare you to steal a Void Pack from the scary Darkened One at the end of Storm Peaks! Bring it to me and I'll give you a ` | `I dare u to steal a Void Pack from the scary Darkened One at the end of Storm Peaks! Bring it to me and I'll give u a ` |
| 2 | `ReplicatedStorage/VerityConfig.lua`:107 | `Yay, thanks! Here's your ` | `Yay, thanks! Here's ur ` |
| 3 | `ReplicatedStorage/VerityConfig.lua`:108 | `🌟 Yippee! Verity gave you a ` | `🌟 Yippee! Verity gave u a ` |
| 4 | `ReplicatedStorage/VerityConfig.lua`:113 | `YOUR VOID PACKS` | `UR VOID PACKS` |
| 5 | `ReplicatedStorage/VerityConfig.lua`:115 | `🌑 EEK! THE DARKENED IS HERE NOW!` | `🌑 THE DARKENED IS HERE!!` |
| 6 | `ReplicatedStorage/VerityConfig.lua`:119 | `Thanks for playing, you were great!` | `Thanks for playing, u were great!` |
| 7 | `ReplicatedStorage/VerityConfig.lua`:121 | `HOLD ON, YOUR DATA IS LOADING!` | `HOLD ON, UR DATA IS LOADING!` |
| 8 | `ReplicatedStorage/VerityConfig.lua`:122 | `OOPS! YOUR DATA CAN'T SAVE NOW` | `OOPS! UR DATA CAN'T SAVE NOW` |
| 9 | `ReplicatedStorage/VerityConfig.lua`:124 | `WHOA, FINISH YOUR RUN FIRST!` | `WHOA, FINISH UR RUN FIRST!` |
| 10 | `ReplicatedStorage/VerityConfig.lua`:125 | `ONE MOMENT, THEN TRY AGAIN!` | `WAIT A SEC, THEN TRY AGAIN!` |
| 11 | `ReplicatedStorage/VerityConfig.lua`:126 | `PLEASE FINISH OPENING THAT PACK!` | `FINISH OPENING THAT PACK FIRST!` |
| 12 | `ReplicatedStorage/VerityConfig.lua`:134 | `THAT PACK LEFT YOUR BAG! TRY AGAIN` | `THAT PACK LEFT UR BAG! TRY AGAIN` |

### 11. Free Void Pack giveaway pedestal

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:157 | `REWARDS ARE UNAVAILABLE UNTIL YOUR DATA CAN SAVE` | `NO REWARDS UNTIL UR DATA CAN SAVE` |
| 2 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:115 | `🌑 FREE VOID PACK! Check your Bag!` | `🌑 FREE VOID PACK! Check ur bag!` |
| 3 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:135 (followed by the seconds) | `⚠ Could not reach the giveaway. Try again in ` | `⚠ Can't reach the giveaway. Try again in ` |
| 4 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:138 | (empty) | (empty) |
| 5 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:146 | `🎒 Your Void Pack is reserved! Make room in your Bag, then claim again.` | `🎒 Ur Void Pack is saved for u! Make room in ur bag, then claim again.` |
| 6 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:147 | `⚠ The pack could not be added. Try again in a moment.` | `⚠ Couldn't add the pack. Try again in a sec!` |
| 7 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:158 | `✅ You already claimed your free Void Pack.` | `✅ U already grabbed ur free Void Pack!` |
| 8 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:165 | `🎒 Your Void Pack is reserved! Make room in your Bag.` | `🎒 Ur Void Pack is saved for u! Make room in ur bag.` |
| 9 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:165 | `🎒 Make room in your Bag first (nothing was used).` | `🎒 Make room in ur bag first! (nothing got used)` |
| 10 | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua`:173 | `⚠ Could not claim. Try again in a moment.` | `⚠ Couldn't claim it. Try again in a sec!` |
| 11 | `ReplicatedStorage/VoidGiveawayRules152.lua`:30 | `LIMITED · ONE PER PLAYER` | `LIMITED! 1 PER PLAYER` |
| 12 | `ReplicatedStorage/VoidGiveawayRules152.lua`:31 | `Claim FREE Void Pack` | `Grab ur FREE Void Pack` |

### 12. Gifting a fruit, seed or pack

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `StarterPlayer/StarterPlayerScripts/FruitGiftClient.client.lua`:96 | `Are you sure you want to give <font color="#FFE547">%s</font> to <font color="#93FF45">%s</font>?` | `Give <font color="#FFE547">%s</font> to <font color="#93FF45">%s</font>?` |
| 2 | `StarterPlayer/StarterPlayerScripts/FruitGiftClient.client.lua`:106 (in: "Get closer to Sunny first!") | ` to give.` | ` first!` |
| 3 | `StarterPlayer/StarterPlayerScripts/FruitGiftClient.client.lua`:113 | `Hold the item you want to give.` | `Hold the item u want to give.` |
| 4 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:48 | `Your data is still loading.` | `Ur data is still loading.` |
| 5 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:51 | `Your save is not ready, so gifts are off. Rejoin to fix it.` | `Ur save isn't ready, so gifts are off. Rejoin to fix it!` |
| 6 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:53 | `Still saving your last gift. Try again in a moment.` | `Still saving ur last gift. Try again in a sec!` |
| 7 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:53 | ` is receiving another gift. Try again in a moment.` | ` is getting another gift. Try again in a sec!` |
| 8 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:54 | `Finish your run first.` | `Finish ur run first!` |
| 9 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:53 | `Try again in a moment.` | `Try again in a sec!` |
| 10 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:86 (in: "Something is blocking Sunny. Move so u can see them!") | `Something is between you and ` | `Something is blocking ` |
| 11 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:86 (in: "Something is blocking Sunny. Move so u can see them!") | `. Move to where you can see them.` | `. Move so u can see them!` |
| 12 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:54 (in: "Get closer to Sunny first!") | ` to give.` | ` first!` |
| 13 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:95 | `Hold the item you want to give.` | `Hold the item u want to give.` |
| 14 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:98 | `This purchased crop cannot be gifted between these accounts.` | `U can't gift a bought crop to that account.` |
| 15 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:99 | `Their seed inventory is full.` | `Their bag is full.` |
| 16 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:110 | `Gift expired. Ask them to offer again.` | `Gift timed out. Ask them to offer it again!` |
| 17 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:112 | `Finish pending gifts or clear bag space first.` | `Finish ur pending gifts or make room in ur bag first.` |
| 18 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:112 | `Finish pending gifts or make inventory room first.` | `Finish ur pending gifts or make room in ur bag first.` |
| 19 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:120 | `Saving your gift…` | `Saving ur gift…` |
| 20 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:141 | `Gift is pending a safe save. It will retry automatically.` | `Gift is waiting for a safe save. It tries again by itself!` |
| 21 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:164 | `Bank your pack and finish the run first.` | `Bring ur pack back to ur base first!` |
| 22 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:169 | `Wait for your pack to finish opening.` | `Wait for ur pack to finish opening!` |
| 23 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:190 (in: "This bought seed pack can't be gifted to that account.") | `This purchased ` | `This bought ` |
| 24 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:190 (in: "This bought seed pack can't be gifted to that account.") | ` cannot be gifted between these accounts.` | ` can't be gifted to that account.` |
| 25 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:208 | `This item cannot be gifted.` | `U can't gift this item.` |
| 26 | `ServerScriptService/ChestChaseServer/FruitGiftService.lua`:99 | `Their crop bag is full.` | `Their bag is full.` |

### 13. Pack, plant and harvest refusals

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:242 | `SEED INVENTORY FULL — MAKE ROOM BEFORE STEALING` | `BAG FULL - MAKE ROOM IN UR BAG FIRST` |
| 2 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:404 | `INVALID PACK` | `TRY AGAIN!` |
| 3 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:408 | `THIS PACK WAS ALREADY OPENED` | `U ALREADY OPENED THIS PACK!` |
| 4 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:409 | `THIS PURCHASED PACK IS UNAVAILABLE FOR THIS ACCOUNT` | `THIS BOUGHT PACK DOESN'T WORK ON THIS ACCOUNT` |
| 5 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:414 | `THIS PACK NEEDS AN UPDATE` | `REJOIN TO OPEN THIS PACK!` |
| 6 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:442 | `THIS PACK IS NO LONGER IN YOUR INVENTORY` | `THAT PACK IS GONE FROM UR BAG!` |
| 7 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:593 | `YOUR PEDESTAL IS EMPTY` | `THE PEDESTAL IS EMPTY!` |
| 8 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1579 | `OPEN THE PACK BEFORE PLANTING` | `OPEN THE PACK FIRST!` |
| 9 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1619 | `THAT FRUIT WAS ALREADY PICKED` | `THAT FRUIT IS ALREADY PICKED!` |
| 10 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1716 | `NO CROPS TO SELL` | `NO CROPS TO SELL YET!` |

### 14. Save problems (the screen when the game sends u out)

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:873 | `Your progress could not be loaded. Please rejoin to retry. Your saved data has not been changed.` | `Couldn't load ur progress. Rejoin to try again! Ur saved data is safe.` |
| 2 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:895 | `Your saved garden requires a newer server. Please rejoin; your data has not been changed.` | `Ur saved garden needs a newer server. Rejoin and u'll be good! Ur data is safe.` |
| 3 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:899 | `Your progress needs a newer server. Your save is unchanged.` | `Ur progress needs a newer server. Rejoin! Ur save is safe.` |
| 4 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:913 | `Your garden could not be read safely. Your save was left unchanged. Please contact the developer.` | `Couldn't read ur garden safely. Ur save is safe. Please tell the developer!` |
| 5 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:922 | `Your previous display item could not be recovered safely. Your save is unchanged.` | `Couldn't get back ur old display item safely. Ur save is safe.` |
| 6 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:929 | `Your previous display item needs a safe migration. Your save is unchanged.` | `Ur old display item needs a safe update. Ur save is safe.` |
| 7 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:956 | `Your Speed data needs a newer server. Your save is unchanged.` | `Ur Speed data needs a newer server. Ur save is safe.` |
| 8 | `ServerScriptService/ChestChaseServer/PlayerDataService.lua`:1319 | `Your garden was updated in another server. Please rejoin to load the latest save.` | `Ur garden was updated in another server. Rejoin to load the newest save!` |

### 15. Chat announcements

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ReplicatedStorage/PullAnnounceRules.lua`:180 (in: "🏆 Ann just took BEST PULL TODAY!") | ` took ` | ` just took ` |
| 2 | `ReplicatedStorage/PullAnnounceRules.lua`:187 (in: "🌟 Ann just pulled a MYTHIC Fire Pepper! (1/800) Nice pull!", other servers: "🌐 Ann just pulled a SECRET Obsidian Maw (1/1,000)!") | ` pulled ` | ` just pulled ` |
| 3 | `ReplicatedStorage/PullAnnounceRules.lua`:189 | `return '🌟 '..who..' pulled '..R.Article(word)..' '..shown..' '..seed..'!'..(odds and' ('..odds..')'or'')` | `return '🌟 '..who..' just pulled '..R.Article(word)..' '..shown..' '..seed..'!'..(odds and' ('..odds..')'or'')..' Nice pull!'` |

### 16. Treadmill bonus roll

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ReplicatedStorage/TreadmillBonusStyle.lua`:79 | `Unwrapping your gift...` | `Unwrapping ur gift...` |
| 2 | `ReplicatedStorage/TreadmillBonusStyle.lua`:81 | `Your pack is already in your bag!` | `Ur pack is already in ur bag!` |

### 17. Settings

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `StarterPlayer/StarterPlayerScripts/SettingsClient.client.lua`:53 | `Could not save yet. Retrying…` | `Can't save yet. Retrying…` |

### 18. Leaderboards

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `StarterPlayer/StarterPlayerScripts/LeaderboardClient.client.lua`:134 | `Global rankings unavailable. Retrying…` | `Can't load the rankings. Trying again…` |
| 2 | `ServerScriptService/ChestChaseServer/SpeedBoardService.lua`:83 | `Global rankings unavailable. Retrying…` | `Can't load the rankings. Trying again…` |

### 19. Title screen

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ReplicatedStorage/TitleScreen104.lua`:142 | `Click to Start` | `Click to play!` |

### 20. Hub plaques, status HUD and station prompts

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `ReplicatedStorage/WorldStatusHud.lua`:110 (in: "THE DARKENED / COMING IN 12m") | `ARRIVES IN ` | `COMING IN ` |
| 2 | `ReplicatedStorage/HubDisplayRules.lua`:291 | `Open a pack to claim it!` | `Open a pack to grab it!` |
| 3 | `ReplicatedStorage/HubDisplayRules.lua`:302 | `Harvest one to claim it!` | `Pick one to grab it!` |
| 4 | `ServerScriptService/ChestChaseServer/MapService.lua`:142 | `PICK A BOOST!` | `GET A BOOST!` |

### 21. Picking fruit, plant lifts, tooltips and the treadmill menu

| # | Where it lives | Old | New |
|---|----------------|-----|-----|
| 1 | `StarterPlayer/StarterPlayerScripts/PlantInspection.client.lua`:204 (in: "Press E to pick") | ` to harvest` | ` to pick` |
| 2 | `ServerScriptService/ChestChaseServer/GardenPlantRuntime.lua`:13 | `Harvest` | `Pick` |
| 3 | `ServerScriptService/ChestChaseServer/GardenPlantRuntime.lua`:105 | `THIS PLANT DOES NOT NEED A LIFT` | `THIS PLANT DOESN'T NEED A LIFT` |
| 4 | `ServerScriptService/ChestChaseServer/GardenPlantRuntime.lua`:109 | `WAIT A MOMENT BEFORE GOING UP AGAIN` | `WAIT A SEC BEFORE GOING UP AGAIN` |
| 5 | `ServerScriptService/ChestChaseServer/GardenPlantRuntime.lua`:113 | `MOVE NEXT TO THE STEM` | `GET NEXT TO THE STEM` |
| 6 | `ServerScriptService/ChestChaseServer/GardenPlantRuntime.lua`:114 | `PLANT TOP IS NOT READY` | `THE TOP ISN'T READY YET` |
| 7 | `ServerScriptService/ChestChaseServer/BaseService.lua`:591 | `Go to your own treadmill.` | `Go to ur own treadmill!` |
| 8 | `ServerScriptService/ChestChaseServer/BaseService.lua`:593 | `Please wait a moment.` | `Wait a sec!` |
| 9 | `ServerScriptService/ChestChaseServer/BaseService.lua`:598 | `Unknown request.` | `Try again!` |
| 10 | `ServerScriptService/ChestChaseServer/ChestService.lua`:103 | `Click or tap soil to plant. Controller: RT` | `Click or tap the soil to plant! Controller: RT` |
| 11 | `ServerScriptService/ChestChaseServer/ChestService.lua`:103 | `Collectible seed. Planting coming later.` | `A seed to collect. Planting is coming soon!` |

## Texts outside the code

- **"Your plant is ready" phone notification** (R140). Its words are a notification string in the Creator Dashboard (the game only sends the plant's name as `{plantName}`),
  so no file here can change it. To match the rest of the game, paste this into the dashboard string instead of the example in `docs/releases/R140.md`:
  `Ur {plantName} is ready to pick! 🌱`
- Game pass names and descriptions on the Roblox pass pages, the Robux purchase prompts, and the developer-product names are set on the Roblox website, not in the code.

## Left as they are, and why

- **The tutorial** (`BeginnerTutorial`, `BeginnerGuide`, `TutorialProgress`, `TutorialTargets` and every tutorial string, including the free-pack notice
  "🎁 FREE Forest pack!! check ur Bag"): rebuilt by another agent and already in the owner's voice (`docs/proposals/R152/tutorial.md`); not touched here.
- **Owner-only texts**: `StudioTestHelp`, `OwnerUpdateCommands82` and every other `/test` reply, `COMMANDS.md`, the Studio-only prints and `warn` lines.
- **Names**: seeds, plants, packs ("Void Pack", "Verity Pack", "Mech Pack"), biomes ("Storm Peaks"), keepers ("The Darkened"), rarities, mutations and weather
  traits ("Drippy", "Frosted", "Charged"), boots and trails. Numbers, prices, odds (`1/N`) and the K / M / B formats are untouched.
- **"Plants grow offline"** (the big rainbow line when Esc is pressed): these are the owner's own words, typed in R151 ("make it a simple big rainbow text that says
  'Plants grow offline'"), so there is nothing to rewrite.
- **Already in the owner's voice, kept**: WAIT A SEC!, TRY AGAIN!, LOADING..., NOT READY YET!, COMING SOON!, REJOIN TO UPDATE!, PLANTED!, BOUGHT!, SOLD!, SMACK! PACK DROPPED,
  the hole refusals ("TOO CLOSE TO A PACK", "HOLE COVERED", ...), "GET UP FIRST!", "THE TRACK IS REFRESHING!", "Gift sent to", "🎁 X gave you Y!", the quest names
  ("Steal 3 packs", "Pick 5 fruit"), the bonus roll words (NICE!, SWEET!, WOW!, MYTHIC!!, ...), TAP / CLICK TO SKIP, the pack-opening reveals, the buttons and tab names
  (SHOP, INDEX, CLAIM, DAY 3, BYE!, ...), "Not in the top 100 yet - keep going!", "Be the first to rank!", "Plants grow 2x faster!" and the like.
- **Short labels that are just names for things**: the top-bar and status HUD words (Next weather, Ends in, Track resets, Speed gain, Pack luck, ...), biome titles, the
  Index tabs, the leaderboard titles, "SPEED NEEDED" on the keepers' signs, "ENTERING", "THE TRACK", "FRUIT OF THE HOUR", the market sign.
- **Sentences that are only keys**: the server's long refusals ("LEAVE MORE ROOM BETWEEN PLANTS", "VISIT THE BUY STATION FIRST", " planted!", ...) are never shown; the
  game shows the short text `SimpleGameText` has for them (rows in area 1 above). They stay as they are because older suites and frozen gameplay files read them.
  Likewise the quiet list (notices the game hides on purpose), the raw errors `TreadmillBonusService` returns (the client turns them into BAG FULL!, ONE SEC..., NOT YET!, ...),
  and the shop products' `Description` in `Config.lua` and the packs' `OddsLabel` in `SeedPackRules.lua` (nothing shows them).
- **Two keeper-code lines**: the label over a dropped seed (`DROPPED SEED  •  LAST CHANCE` in `ChaseService`) and the sentence in `ConcurrentKeeperService` stay byte for byte
  (the keeper suites check those two files against the R151 base). The pack-store refusal gets its short text from `SimpleGameText` instead; the old seed-era label stays.
- **Screen reader labels** (`AccessibleLabel` attributes such as "Teleport to your base") are not drawn on the screen.

## Fit on phones

Nothing got a new box and no text size, `TextScaled` or fit setting was touched. The few short notices that grew by a word (the longest is `MAKE ROOM IN UR BAG FIRST!`, 26
characters, instead of `SEED BAG FULL!`) were measured with the real FredokaOne: the widest text in the red / green / yellow notices, `NO REWARDS UNTIL UR DATA CAN SAVE`
(the old sentence was 15 characters longer), is 278 px at the notice stack's smallest size (14 px); the stack is 351 px wide on a 375 px phone and 296 px on a 320 px one,
so every notice fits on one line at its smallest size on any phone, and the fit helper (`GardenTextFit`, 12 to 17 px) has even more room for the feedback line. The notice rows
are 56 px high on phones, so a line that does wrap still fits in two. The windows that have fixed boxes (Verity's, the Bag, the shop status line, the treadmill sign, the
hub plaques) use their own fit helpers and test suites: Verity's quest sentence was made one word shorter than first written because it needs to fit in 5 lines on a 360 x 640
phone (`test_verity_client.luau`, 13 screen sizes); the others did not change length by more than a few characters and their layout suites pass.

## Tests

Many older suites assert exact strings. They were moved to the new words (never loosened: every check still compares the same thing, only the expected text changed):
`R138`, `R140`, `R147` (mystery, Verity), `R148` (purchase, shop, roster), `R150` (pedestal, hotbar), `R151` (chat lines, hub plaque, settings), `R152` (Void giveaway),
`giving_R122`, `shop_R120` and `tools/tests/test_fast_travel.luau`; the mutation snippets in `run_void_giveaway.sh` follow the new source lines.
Frozen files: none needed a new hash from this pass (`Config.lua`, `DailyRewards.lua`, `EconomyService.lua`, `TreadmillBonusRules.lua`, `TreadmillBonusService.lua`, `HudNotices.client.lua`,
`ConcurrentKeeperService.lua` and `ChaseService.lua` hold the words they had on the release branch; the short texts for their sentences are in `SimpleGameText`).
The money auto-collect change that landed on the release branch meanwhile ("Gems on the way.", "Cash on the way.", "YOUR LAST REWARDS ARE STILL ARRIVING") is kept in meaning and
put in the owner's voice here: "Ur Gems are on the way!", "Ur Cash is on the way!", "UR LAST REWARDS ARE STILL ARRIVING".
`tools/tests/run_all_suites.sh` passes (all suites, including `run_perf152.sh`
and the R152 load guard).

## How the picture is made

```
python3 docs/proposals/R152/preview/build_game_text_sheet.py     # looks every text up in the source, writes preview/game_text.html
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node docs/proposals/R152/preview/render_game_text.mjs     # writes docs/proposals/R152/game_text.png
python3 docs/proposals/R152/preview/gen_verity_copy.py docs/proposals/R152/preview/copy.json && node docs/proposals/R152/preview/render_verity_text.mjs   # verity_text.png
```
