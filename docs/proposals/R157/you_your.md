# R157: u / ur written out as you / your (owner)

The owner asked: "u and ur change to their you and your ... this goes for all u and urs in the game". Until now every player-visible text in the game used "u" / "ur". This change writes them out. Text only: no code, number, key, asset id or layout changed.

## The rule

| Written | Becomes |
| --- | --- |
| `u` | `you` |
| `U` at the start of a sentence | `You` |
| `U` inside an ALL-CAPS text | `YOU` |
| `ur` meaning possession ("ur bag") | `your` (`Ur` -> `Your`, `UR` -> `YOUR`) |
| `ur` meaning "you are" | `you're` (`UR` -> `YOU'RE`) |
| `u'll`, `u're`, `u've`, `u'd`, `urs`, `urself` | `you'll`, `you're`, `you've`, `you'd`, `yours`, `yourself` |

Everything else of the owner's voice is as it was: the lowercase style ("you sure? it's gone forever"), the slang, the emoji and the punctuation. Only u / ur changed. No other word was shortened.

How it was found: a small Luau lexer read every file under `src/` (including `src/ReplicatedFirst`; there is no `src/StarterGui`), took only the string literals (single, double, backtick and `[[ ]]` long strings, never comments), and matched `u` / `ur` / `urs` / `urself` as whole words (`\b[Uu][Rr]?\b`, also before `'`, so `U'RE` is found). Base64 picture data and `\u{...}` escapes are skipped. Every hit (159) was read in context; one is not text and was left alone (see "Not changed").

"ur" meaning "you are": exactly one case, the all-caps `U'RE` (u're) in `PremiumProgress.lua:151`, now `YOU'RE MAXED OUT! SPEND SOME FIRST`. Every other "ur" is possession ("ur bag", "ur data", "Ur Gems are on the way").

Where a text is also the key of another text (`SimpleGameText.lua` maps a server message to the short text the player sees), the key and the server message were changed together: `BAG FULL - MAKE ROOM IN YOUR BAG FIRST` in `InventoryCap155.lua`, `PlayerDataService.lua:274` and `SimpleGameText.lua:22`.

## Count

138 strings changed (158 u / ur words, on 127 source lines) in 32 files under `src/`. A "string" is one string literal that held at least one u / ur.

| File | Strings | Words |
| --- | ---: | ---: |
| `src/ReplicatedStorage/BeginnerGuide.lua` | 5 | 5 |
| `src/ReplicatedStorage/DiscardDialog155.lua` | 3 | 3 |
| `src/ReplicatedStorage/GamePassCatalog.lua` | 2 | 2 |
| `src/ReplicatedStorage/InventoryPanel155.lua` | 1 | 1 |
| `src/ReplicatedStorage/PackPity155.lua` | 2 | 2 |
| `src/ReplicatedStorage/PremiumBoostCard.lua` | 1 | 1 |
| `src/ReplicatedStorage/SimpleGameText.lua` | 5 | 5 |
| `src/ReplicatedStorage/TrackHoleConfig.lua` | 2 | 2 |
| `src/ReplicatedStorage/TreadmillBonusStyle.lua` | 1 | 1 |
| `src/ReplicatedStorage/VerityConfig.lua` | 9 | 10 |
| `src/ReplicatedStorage/VoidGiveawayRules152.lua` | 1 | 1 |
| `src/ServerScriptService/ChestChaseServer/BaseService.lua` | 1 | 1 |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua` | 19 | 20 |
| `src/ServerScriptService/ChestChaseServer/FastTravelService.lua` | 2 | 2 |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua` | 14 | 17 |
| `src/ServerScriptService/ChestChaseServer/GardenFenceData.lua` | 1 | 1 |
| `src/ServerScriptService/ChestChaseServer/InventoryCap155.lua` | 1 | 1 |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua` | 8 | 8 |
| `src/ServerScriptService/ChestChaseServer/MysteryPackService.lua` | 5 | 7 |
| `src/ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua` | 1 | 1 |
| `src/ServerScriptService/ChestChaseServer/PassGiftService.lua` | 1 | 1 |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua` | 14 | 22 |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua` | 21 | 21 |
| `src/ServerScriptService/ChestChaseServer/PremiumService.lua` | 3 | 3 |
| `src/ServerScriptService/ChestChaseServer/VoidGiveaway152.lua` | 6 | 11 |
| `src/StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua` | 2 | 2 |
| `src/StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua` | 1 | 1 |
| `src/StarterPlayer/StarterPlayerScripts/FruitGiftClient.client.lua` | 1 | 1 |
| `src/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua` | 2 | 2 |
| `src/StarterPlayer/StarterPlayerScripts/GardenShovel.client.lua` | 1 | 1 |
| `src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua` | 1 | 1 |
| `src/StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua` | 1 | 1 |
| **Total** | **138** | **158** |

## Every changed line

`file:line`, the string before -> after (the string as written in the source, `\'` is an escaped quote). When one line holds several strings, each has its own row.

| file:line | before -> after |
| --- | --- |
| `src/ReplicatedStorage/BeginnerGuide.lua:15` | `'to ur base'` -> `'to your base'` |
| `src/ReplicatedStorage/BeginnerGuide.lua:16` | `'ur pack'` -> `'your pack'` |
| `src/ReplicatedStorage/BeginnerGuide.lua:28` | `'ur seed'` -> `'your seed'` |
| `src/ReplicatedStorage/BeginnerGuide.lua:33` | `'U GOT THIS!!'` -> `'YOU GOT THIS!!'` |
| `src/ReplicatedStorage/BeginnerGuide.lua:38` | `'🎁 FREE Forest pack!! check ur Bag'` -> `'🎁 FREE Forest pack!! check your Bag'` |
| `src/ReplicatedStorage/DiscardDialog155.lua:34` | `"u sure? it's gone forever"` -> `"you sure? it's gone forever"` |
| `src/ReplicatedStorage/DiscardDialog155.lua:55` | `"u sure? "` -> `"you sure? "` |
| `src/ReplicatedStorage/DiscardDialog155.lua:55` | `"u sure? it's gone forever"` -> `"you sure? it's gone forever"` |
| `src/ReplicatedStorage/GamePassCatalog.lua:8` | `'Get 2x speed when u train!'` -> `'Get 2x speed when you train!'` |
| `src/ReplicatedStorage/GamePassCatalog.lua:9` | `'x2 luck on EVERY pack u open! 🍀'` -> `'x2 luck on EVERY pack you open! 🍀'` |
| `src/ReplicatedStorage/InventoryPanel155.lua:174` | `'u can\'t throw that away'` -> `'you can\'t throw that away'` |
| `src/ReplicatedStorage/PackPity155.lua:75` | `'every 10th pack u open is lucky: x1.5 luck (event packs count separately)'` -> `'every 10th pack you open is lucky: x1.5 luck (event packs count separately)'` |
| `src/ReplicatedStorage/PackPity155.lua:76` | `'every 10th event pack u open (Void, Verity, Mech) is lucky: x1.5 luck'` -> `'every 10th event pack you open (Void, Verity, Mech) is lucky: x1.5 luck'` |
| `src/ReplicatedStorage/PremiumBoostCard.lua:9` | `'x2 luck on EVERY pack u open!'` -> `'x2 luck on EVERY pack you open!'` |
| `src/ReplicatedStorage/SimpleGameText.lua:15` | `"ONLY IN UR GARDEN!"` -> `"ONLY IN YOUR GARDEN!"` |
| `src/ReplicatedStorage/SimpleGameText.lua:22` | `"MAKE ROOM IN UR BAG FIRST!"` -> `"MAKE ROOM IN YOUR BAG FIRST!"` |
| `src/ReplicatedStorage/SimpleGameText.lua:22` | `"BAG FULL - MAKE ROOM IN UR BAG FIRST"` -> `"BAG FULL - MAKE ROOM IN YOUR BAG FIRST"` |
| `src/ReplicatedStorage/SimpleGameText.lua:31` | `"GET TO UR BASE FIRST!"` -> `"GET TO YOUR BASE FIRST!"` |
| `src/ReplicatedStorage/SimpleGameText.lua:38` | `"U ALREADY HAVE THIS! ✅"` -> `"YOU ALREADY HAVE THIS! ✅"` |
| `src/ReplicatedStorage/TrackHoleConfig.lua:54` | `'U FELL IN A HOLE! PACK DROPPED'` -> `'YOU FELL IN A HOLE! PACK DROPPED'` |
| `src/ReplicatedStorage/TrackHoleConfig.lua:59` | `'🕳️ dig holes on the track to trap players • tap a plant in ur garden to remove it'` -> `'🕳️ dig holes on the track to trap players • tap a plant in your garden to remove it'` |
| `src/ReplicatedStorage/TreadmillBonusStyle.lua:87` | `'Unwrapping ur gift...'` -> `'Unwrapping your gift...'` |
| `src/ReplicatedStorage/VerityConfig.lua:105` | `'I dare u to steal a Void Pack from the scary Darkened One at the end of Storm Peaks! Bring it to me and I\'ll give u a '` -> `'I dare you to steal a Void Pack from the scary Darkened One at the end of Storm Peaks! Bring it to me and I\'ll give you a '` |
| `src/ReplicatedStorage/VerityConfig.lua:107` | `'Yay, thanks! Here\'s ur '` -> `'Yay, thanks! Here\'s your '` |
| `src/ReplicatedStorage/VerityConfig.lua:108` | `'🌟 Yippee! Verity gave u a '` -> `'🌟 Yippee! Verity gave you a '` |
| `src/ReplicatedStorage/VerityConfig.lua:113` | `'UR VOID PACKS'` -> `'YOUR VOID PACKS'` |
| `src/ReplicatedStorage/VerityConfig.lua:119` | `'Thanks for playing, u were great!'` -> `'Thanks for playing, you were great!'` |
| `src/ReplicatedStorage/VerityConfig.lua:121` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ReplicatedStorage/VerityConfig.lua:122` | `'OOPS! UR DATA CAN\'T SAVE NOW'` -> `'OOPS! YOUR DATA CAN\'T SAVE NOW'` |
| `src/ReplicatedStorage/VerityConfig.lua:124` | `'WHOA, FINISH UR RUN FIRST!'` -> `'WHOA, FINISH YOUR RUN FIRST!'` |
| `src/ReplicatedStorage/VerityConfig.lua:134` | `'THAT PACK LEFT UR BAG! TRY AGAIN'` -> `'THAT PACK LEFT YOUR BAG! TRY AGAIN'` |
| `src/ReplicatedStorage/VoidGiveawayRules152.lua:31` | `'Grab ur FREE Void Pack'` -> `'Grab your FREE Void Pack'` |
| `src/ServerScriptService/ChestChaseServer/BaseService.lua:600` | `'Go to ur own treadmill!'` -> `'Go to your own treadmill!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:31` | `'UR GARDEN IS LOADING...'` -> `'YOUR GARDEN IS LOADING...'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:95` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:106` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:107` | `'NO REWARDS UNTIL UR DATA CAN SAVE'` -> `'NO REWARDS UNTIL YOUR DATA CAN SAVE'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:114` | `'🌑 FREE VOID PACK! Check ur bag!'` -> `'🌑 FREE VOID PACK! Check your bag!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:114` | `'🤖 FREE MECH PACK! Check ur bag!'` -> `'🤖 FREE MECH PACK! Check your bag!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:114` | `'🎒 RANDOM SEED PACK! Check ur bag!'` -> `'🎒 RANDOM SEED PACK! Check your bag!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:117` | `'Ur Gems are on the way!'` -> `'Your Gems are on the way!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:124` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:125` | `'NO REWARDS UNTIL UR DATA CAN SAVE'` -> `'NO REWARDS UNTIL YOUR DATA CAN SAVE'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:128` | `'U ALREADY CLAIMED THIS!'` -> `'YOU ALREADY CLAIMED THIS!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:134` | `'🎒 RANDOM SEED PACK! Now grab ur 💎'` -> `'🎒 RANDOM SEED PACK! Now grab your 💎'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:135` | `'🎒 RANDOM SEED PACK! Check ur bag!'` -> `'🎒 RANDOM SEED PACK! Check your bag!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:140` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:141` | `'NO REWARDS UNTIL UR DATA CAN SAVE'` -> `'NO REWARDS UNTIL YOUR DATA CAN SAVE'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:143` | `'U ALREADY CLAIMED THIS!'` -> `'YOU ALREADY CLAIMED THIS!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:145` | `'U ALREADY GOT UR DAILY 💎!'` -> `'YOU ALREADY GOT YOUR DAILY 💎!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:150` | `'🎉 ALL DONE! Ur Gems are on the way!'` -> `'🎉 ALL DONE! Your Gems are on the way!'` |
| `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:167` | `'! Grab ur 🎒 pack in 🎁 DAILY'` -> `'! Grab your 🎒 pack in 🎁 DAILY'` |
| `src/ServerScriptService/ChestChaseServer/FastTravelService.lua:67` | `"WAIT TILL U CAN MOVE!"` -> `"WAIT TILL YOU CAN MOVE!"` |
| `src/ServerScriptService/ChestChaseServer/FastTravelService.lua:77` | `"FINISH OPENING UR PACK FIRST!"` -> `"FINISH OPENING YOUR PACK FIRST!"` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:48` | `'Ur data is still loading.'` -> `'Your data is still loading.'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:51` | `'Ur save isn\'t ready, so gifts are off. Rejoin to fix it!'` -> `'Your save isn\'t ready, so gifts are off. Rejoin to fix it!'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:53` | `'Still saving ur last gift. Try again in a sec!'` -> `'Still saving your last gift. Try again in a sec!'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:54` | `'Finish ur run first!'` -> `'Finish your run first!'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:91` | `'. Move so u can see them!'` -> `'. Move so you can see them!'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:100` | `'Hold the item u want to give.'` -> `'Hold the item you want to give.'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:104` | `'U can\'t gift a bought crop to that account.'` -> `'You can\'t gift a bought crop to that account.'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:119` | `'Finish ur pending gifts or make room in ur bag first.'` -> `'Finish your pending gifts or make room in your bag first.'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:128` | `'Saving ur gift…'` -> `'Saving your gift…'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:172` | `'Bring ur pack back to ur base first!'` -> `'Bring your pack back to your base first!'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:177` | `'Wait for ur pack to finish opening!'` -> `'Wait for your pack to finish opening!'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:217` | `'Finish ur pending gifts or make room in ur bag first.'` -> `'Finish your pending gifts or make room in your bag first.'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:221` | `'U can\'t gift this item.'` -> `'You can\'t gift this item.'` |
| `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:233` | `'Saving ur gift…'` -> `'Saving your gift…'` |
| `src/ServerScriptService/ChestChaseServer/GardenFenceData.lua:17` | `'Ur save isn\'t ready yet!'` -> `'Your save isn\'t ready yet!'` |
| `src/ServerScriptService/ChestChaseServer/InventoryCap155.lua:22` | `'BAG FULL - MAKE ROOM IN UR BAG FIRST'` -> `'BAG FULL - MAKE ROOM IN YOUR BAG FIRST'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:18` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:18` | `'UR DATA CAN\'T SAVE RIGHT NOW, TRY AGAIN LATER'` -> `'YOUR DATA CAN\'T SAVE RIGHT NOW, TRY AGAIN LATER'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:18` | `'U CAN\'T THROW THAT AWAY'` -> `'YOU CAN\'T THROW THAT AWAY'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:19` | `'FINISH UR STEAL FIRST!'` -> `'FINISH YOUR STEAL FIRST!'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:19` | `'WAIT FOR UR GIFT TO SEND FIRST!'` -> `'WAIT FOR YOUR GIFT TO SEND FIRST!'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:19` | `'WAIT FOR UR PACK TO FINISH OPENING!'` -> `'WAIT FOR YOUR PACK TO FINISH OPENING!'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:19` | `'WAIT FOR UR SEED TO LAND FIRST!'` -> `'WAIT FOR YOUR SEED TO LAND FIRST!'` |
| `src/ServerScriptService/ChestChaseServer/InventoryService155.lua:20` | `'U DON\'T HAVE THAT MANY!'` -> `'YOU DON\'T HAVE THAT MANY!'` |
| `src/ServerScriptService/ChestChaseServer/MysteryPackService.lua:143` | `'🎁 Ur waiting Mystery Pack is in ur bag: '` -> `'🎁 Your waiting Mystery Pack is in your bag: '` |
| `src/ServerScriptService/ChestChaseServer/MysteryPackService.lua:144` | `'🎁 Yesterday\'s Mystery Pack is in ur bag: '` -> `'🎁 Yesterday\'s Mystery Pack is in your bag: '` |
| `src/ServerScriptService/ChestChaseServer/MysteryPackService.lua:151` | `'Make room in ur bag first!'` -> `'Make room in your bag first!'` |
| `src/ServerScriptService/ChestChaseServer/MysteryPackService.lua:171` | `'🎁 Make room in ur bag! '` -> `'🎁 Make room in your bag! '` |
| `src/ServerScriptService/ChestChaseServer/MysteryPackService.lua:198` | `'🔓 Ur Mystery Pack is unlocked! Go to ur base and grab it 🎁'` -> `'🔓 Your Mystery Pack is unlocked! Go to your base and grab it 🎁'` |
| `src/ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua:109` | `' on every pack u buy (each pack rolls its own; free packs stay plain).'` -> `' on every pack you buy (each pack rolls its own; free packs stay plain).'` |
| `src/ServerScriptService/ChestChaseServer/PassGiftService.lua:57` | `'Ur other gifts are still saving.'` -> `'Your other gifts are still saving.'` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:274` | `"BAG FULL - MAKE ROOM IN UR BAG FIRST"` -> `"BAG FULL - MAKE ROOM IN YOUR BAG FIRST"` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:450` | `"U ALREADY OPENED THIS PACK!"` -> `"YOU ALREADY OPENED THIS PACK!"` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:494` | `"THAT PACK IS GONE FROM UR BAG!"` -> `"THAT PACK IS GONE FROM YOUR BAG!"` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:940` | `"Couldn't load ur progress. Rejoin to try again! Ur saved data is safe."` -> `"Couldn't load your progress. Rejoin to try again! Your saved data is safe."` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:962` | `"Ur saved garden needs a newer server. Rejoin and u'll be good! Ur data is safe."` -> `"Your saved garden needs a newer server. Rejoin and you'll be good! Your data is safe."` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:966` | `'Ur progress needs a newer server. Rejoin! Ur save is safe.'` -> `'Your progress needs a newer server. Rejoin! Your save is safe.'` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:981` | `"Couldn't read ur garden safely. Ur save is safe. Please tell the developer!"` -> `"Couldn't read your garden safely. Your save is safe. Please tell the developer!"` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:990` | `"Couldn't get back ur old display item safely. Ur save is safe."` -> `"Couldn't get back your old display item safely. Your save is safe."` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:997` | `"Ur old display item needs a safe update. Ur save is safe."` -> `"Your old display item needs a safe update. Your save is safe."` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:1024` | `'Ur Speed data needs a newer server. Ur save is safe.'` -> `'Your Speed data needs a newer server. Your save is safe.'` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:1391` | `"Ur garden was updated in another server. Rejoin to load the newest save!"` -> `"Your garden was updated in another server. Rejoin to load the newest save!"` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:1907` | `'Ur save isn\'t ready yet!'` -> `'Your save isn\'t ready yet!'` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:1919` | `'Ur save isn\'t ready yet!'` -> `'Your save isn\'t ready yet!'` |
| `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:1923` | `'Style changed! Ur training power stays the same.'` -> `'Style changed! Your training power stays the same.'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:147` | `'UR GARDEN IS LOADING...'` -> `'YOUR GARDEN IS LOADING...'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:150` | `'UR LAST REWARDS ARE STILL ARRIVING'` -> `'YOUR LAST REWARDS ARE STILL ARRIVING'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:151` | `'U\'RE MAXED OUT! SPEND SOME FIRST'` -> `'YOU\'RE MAXED OUT! SPEND SOME FIRST'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:166` | `'Ur Gems are on the way!'` -> `'Your Gems are on the way!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:173` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:204` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:212` | `'Mech pack is in ur bag!'` -> `'Mech pack is in your bag!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:212` | `' Mech packs are in ur bag!'` -> `' Mech packs are in your bag!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:249` | `'Ur Cash is on the way!'` -> `'Your Cash is on the way!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:252` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:256` | `'U ALREADY HAVE THIS!'` -> `'YOU ALREADY HAVE THIS!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:258` | `'STILL CHECKING WHAT U OWN...'` -> `'STILL CHECKING WHAT YOU OWN...'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:260` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:262` | `'U ALREADY HAVE THIS!'` -> `'YOU ALREADY HAVE THIS!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:263` | `'STILL CHECKING WHAT U OWN...'` -> `'STILL CHECKING WHAT YOU OWN...'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:331` | `'CLAIM UR INDEX REWARDS FIRST!'` -> `'CLAIM YOUR INDEX REWARDS FIRST!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:345` | `'Ur Cash is on the way!'` -> `'Your Cash is on the way!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:350` | `'U ALREADY CLAIMED THIS!'` -> `'YOU ALREADY CLAIMED THIS!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:355` | `'Ur Gems are on the way!'` -> `'Your Gems are on the way!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:361` | `'U ALREADY CLAIMED THIS!'` -> `'YOU ALREADY CLAIMED THIS!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumProgress.lua:366` | `'Ur Gems are on the way!'` -> `'Your Gems are on the way!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumService.lua:43` | `'HOLD ON, UR DATA IS LOADING!'` -> `'HOLD ON, YOUR DATA IS LOADING!'` |
| `src/ServerScriptService/ChestChaseServer/PremiumService.lua:64` | `'NO REWARDS UNTIL UR DATA CAN SAVE'` -> `'NO REWARDS UNTIL YOUR DATA CAN SAVE'` |
| `src/ServerScriptService/ChestChaseServer/PremiumService.lua:96` | `'NO PURCHASES UNTIL UR DATA CAN SAVE'` -> `'NO PURCHASES UNTIL YOUR DATA CAN SAVE'` |
| `src/ServerScriptService/ChestChaseServer/VoidGiveaway152.lua:116` | `'🌑 FREE VOID PACK! Check ur bag!'` -> `'🌑 FREE VOID PACK! Check your bag!'` |
| `src/ServerScriptService/ChestChaseServer/VoidGiveaway152.lua:147` | `'🎒 Ur Void Pack is saved for u! Make room in ur bag, then claim again.'` -> `'🎒 Your Void Pack is saved for you! Make room in your bag, then claim again.'` |
| `src/ServerScriptService/ChestChaseServer/VoidGiveaway152.lua:158` | `'NO REWARDS UNTIL UR DATA CAN SAVE'` -> `'NO REWARDS UNTIL YOUR DATA CAN SAVE'` |
| `src/ServerScriptService/ChestChaseServer/VoidGiveaway152.lua:159` | `'✅ U already grabbed ur free Void Pack!'` -> `'✅ You already grabbed your free Void Pack!'` |
| `src/ServerScriptService/ChestChaseServer/VoidGiveaway152.lua:166` | `'🎒 Ur Void Pack is saved for u! Make room in ur bag.'` -> `'🎒 Your Void Pack is saved for you! Make room in your bag.'` |
| `src/ServerScriptService/ChestChaseServer/VoidGiveaway152.lua:166` | `'🎒 Make room in ur bag first! (nothing got used)'` -> `'🎒 Make room in your bag first! (nothing got used)'` |
| `src/StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua:248` | `'GOT UR 💎'` -> `'GOT YOUR 💎'` |
| `src/StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua:363` | `'Friends here boost ur speed gain! 👥'` -> `'Friends here boost your speed gain! 👥'` |
| `src/StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua:429` | `'Go to the market to sell ur crops!'` -> `'Go to the market to sell your crops!'` |
| `src/StarterPlayer/StarterPlayerScripts/FruitGiftClient.client.lua:114` | `'Hold the item u want to give.'` -> `'Hold the item you want to give.'` |
| `src/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua:164` | `'FILL UR PLANT INDEX'` -> `'FILL YOUR PLANT INDEX'` |
| `src/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua:165` | `'Grab Gems from ur plant index!'` -> `'Grab Gems from your plant index!'` |
| `src/StarterPlayer/StarterPlayerScripts/GardenShovel.client.lua:69` | `'?\nThis removes the plant and any fruit still on it. U won\'t get the seed back.'` -> `'?\nThis removes the plant and any fruit still on it. You won\'t get the seed back.'` |
| `src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua:67` | `'Ur Bag'` -> `'Your Bag'` |
| `src/StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua:274` | `'UR'` -> `'YOUR'` |

## Not changed (on purpose)

- `src/ReplicatedStorage/TreadmillFx.lua:210`: `axis=='U'or axis=='V'` is the belt texture axis, code, not text.
- Comments (for example the R125 comment after `TrackHoleConfig.Hint`) and all code identifiers (`local u`, `u*u`, ...).
- `docs/proposals/R156/` (the title tips are another change) and `docs/proposals/R152/game_text.md` / `preview/build_game_text_sheet.py` (a record of the earlier wording, not read by the game).
- `Config.lua`, `BackgroundMusic.client.lua`, line 1 of every client script and every file listed in `docs/proposals/R151/tests/frozen.sha256` are untouched, so no hash changed and `frozen.sha256` needed no new line.
- `installers/R156_install.lua` is the R156 release and was not rebuilt; the next release installer picks these texts up from `src/`.

## Lines that may now overflow

Each text grew by two letters per word (u -> you, ur -> your). Nearly every label that shows these texts already shrinks to fit (`GardenTextFit`, `TextScaled` with a `UITextSizeConstraint`, or the notice feed's 14 to 24 range), so nothing is cut off, but these are the tight ones. No other word was shortened.

| file:line | text | Why it is tight |
| --- | --- | --- |
| `src/ReplicatedStorage/DiscardDialog155.lua:55` (and `:34`) | `you sure? all N of them, gone forever` | A plain wrapped 14 px label, 246 px wide and 32 px high (room for two lines); the longest form of the line (a big stack) may now need the second line where it fitted on one before. No `TextScaled`. |
| `src/StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua:248` | `GOT YOUR 💎` | Sits in the CLAIM button's box (88 px wide at the narrowest, 120 px at the widest); its label shrinks to fit, so the type gets a little smaller on a narrow panel. |
| `src/ReplicatedStorage/PremiumBoostCard.lua:9` | `x2 luck on EVERY pack you open!` | The 4 Leaf Clover card's detail is a wrapped fit label (smallest 11 px) beside the picture; on the smallest card it may take a third line or a smaller size. The same words in `GamePassCatalog.lua:9`. |
| `src/ReplicatedStorage/VerityConfig.lua:113` | `YOUR VOID PACKS` | The caption of a half-width chip in Verity's window (fit label, 12 px, 10 px on short screens). |
| `src/StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua:274` | `YOUR MYSTERY PACK` | The pedestal sign is `TextScaled` in a fixed pill, so the letters get a little smaller (its other state, `NAME'S MYSTERY PACK`, is unchanged). |
| `src/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua:164` and `:165` | `FILL YOUR PLANT INDEX`, `Grab Gems from your plant index!` | Fit labels in the Gems card (down to 11 px and 10 px). |
| `src/ReplicatedStorage/BeginnerGuide.lua:15`, `:16`, `:28`, `:33` | `to your base`, `your pack`, `your seed`, `YOU GOT THIS!!` | The tutorial chip sizes itself to its text (measured with `TextService`) and the title is `TextScaled` (14 to 34 px); `test_guide_layout` checks the card on 26 screen sizes and passes. |
| `src/StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua:429` | `Go to the market to sell your crops!` | The market status line is one 18 px high fit label; the text can shrink a size. |
| `src/ReplicatedStorage/TrackHoleConfig.lua:59` | `... tap a plant in your garden to remove it` | One of the longest notices (it grew from 81 to 83 characters); the notice feed wraps and shrinks it (14 to 24 px), as it did before. |

Everything else sits in the notice feed (`TextScaled`, 14 to 24 px), in wrapped fit labels, or in a panel-wide label (the Bag title `Your Bag`), and has room.

## Tests

The tests that pin the old words now pin the new ones (same checks, only the expected string changed):

- `docs/proposals/R139/tests/test_starter.luau`: 2 strings
- `docs/proposals/R140/tests/test_daily_client.luau`: 6 strings
- `docs/proposals/R147/tests/test_mystery.luau`: 1 string
- `docs/proposals/R147/tests/test_r147_client.luau`: 4 strings
- `docs/proposals/R147/tests/test_verity.luau`: 3 strings
- `docs/proposals/R147/tests/test_verity_client.luau`: 4 strings
- `docs/proposals/R147/tests/test_verity_pack.luau`: 4 strings
- `docs/proposals/R148/tests/test_purchase.luau`: 8 strings
- `docs/proposals/R148/tests/test_purchase_shop.luau`: 4 strings
- `docs/proposals/R148/tests/test_roster.luau`: 7 strings
- `docs/proposals/R150/tests/test_pedestal_fx.luau`: 4 strings
- `docs/proposals/R152/tests/test_giveaway_art.luau`: 2 strings
- `docs/proposals/R152/tests/test_giveaway_server.luau`: 3 strings
- `docs/proposals/R153/tests/test_clover.luau`: 4 strings
- `docs/proposals/R153/tests/test_clover_shop.luau`: 1 string
- `docs/proposals/R153/tests/test_index_gems.luau`: 2 strings
- `docs/proposals/R155/tests/test_cap155.luau`: 10 strings
- `docs/proposals/R155/tests/test_inventory155.luau`: 4 strings
- `docs/proposals/R155/tests/test_pity155.luau`: 2 strings
- `tools/tests/test_fast_travel.luau`: 3 strings
- `tools/tests/test_tutorial.luau`: 5 strings
- `docs/proposals/R155/tests/run_pity.sh` (the grep for the pity rule's words), `docs/proposals/R152/tests/run_void_giveaway.sh` (two mutation targets: the "already grabbed" refusal and the prompt text)
- `tools/tests/test_guide_flow.luau`: the word list now has `to your base` / `nice you got this`. Its old check "the tutorial words never say `your`" was there to keep the owner's `ur`; it now checks the opposite way (no word `u` or `ur` on any tutorial card) and still bans `follow` and `arrow`.

`docs/proposals/R150/tests` (`test_bonus_style`, `test_bonus_ui`, `mutation_check.py`, `run_bonus_ui.sh`) mention "already in ur bag" only to say that line is gone; they check for the bag, not for the words, so they are unchanged (`run_bonus_ui.sh` already greps for both `ur` and `your`).
