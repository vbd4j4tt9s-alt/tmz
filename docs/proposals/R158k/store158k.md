# R158k - "can't buy it, but I have enough money"

Owner's report: *"there are some bugs in the game where players can't purchase things in the store when their money is
sufficient enough, check up on this"*, then: *"if clicking on something and players don't have enough money, it just tells
the player not enough cash"*, then: *"make sure store prices are always the same"*.

No Robux purchase changed. No model names, ProfileVersion stays 22, `Config.Version` is not touched here.

## What was checked

Every purchase paid with in-game money, client side (what makes a button look buyable) against server side (what refuses):

| Purchase | Paid with | Screen | Server check |
|---|---|---|---|
| Trails / boots (the market's Buy page) | Cash | `EconomyClient` + `ShopMenu` | `EconomyService._purchase` -> `PlayerDataService.SpendCash` |
| Treadmill upgrade pad | Cash | the pad itself (server-drawn) | `GardenUpgradeService` -> `BuyTreadmill` -> `SpendCash` |
| Fence upgrade pad | Cash | the pad itself | `GardenUpgradeService` -> `BuyFence` -> `SpendCash` |
| Cash to Gems (SHOP, GEMS) | Cash | `GamePassClient` | `PremiumProgress.ConvertGems` |
| Limited Mech pack (1 / 5 / 10) | Gems | `GamePassClient` | `PremiumProgress.BuyMechPack` |
| Speed / Cash bundles | Gems | `GamePassClient` | `PremiumProgress.BuyPremiumBundle` |
| Passes (Growth, Speed, Clover) | Gems | `GamePassClient` | `PremiumProgress.BuyGemPerk` |
| Pass gifts | Gems | (no button in the game since R122) | `PassGiftService.Send` |

There is no "buy seeds" store, no cash option in the Mech shop, no DAILY / LIMITED / Verity purchase with money (those are claims
and hand-ins).

**What was already right on the server:** equal money pays everywhere (`>=`); no price or balance gets near 2^53 (the top price is
204T, the cash cap 900T, so plain numbers are exact); Cash is a whole number (an `IntValue`), not a text; each product is checked
against its own currency (no gems / cash mix-up); nothing yields between the check and the payment, so a double click can never pay
twice (the pass purchase checks again after its one wait); no purchase depends on speed, the tutorial, the starter gift or creative
mode (R158c-R158i).

## What was wrong

1. **The money counter showed more cash than the player had.** The HUD (and the market's own "Cash $" line) rounded to the
   nearest tenth: **$10,350,000 read "$10.4M"** right next to the **$10.4M** Arc Trail. The player sees "I have 10.4M, it costs
   10.4M" and the purchase is refused. Up to half a step short reads as the price: $1.75T read "$1.8T" beside the $1.8T Crystal
   Boots (that is 50 billion short), $999.96B read "$1T" beside the $1T price of one Gem. The same happened on the treadmill /
   fence pads (their price is exact, the HUD was not). This is the most likely thing the owner saw.
2. **A button you could not afford was dead.** The market's button turned into a greyed "Need $50000" that did nothing when
   pressed: no sound, no message.
3. **The market could trust an old number.** It decided "can you afford it" (and wrote its Cash line) from the Cash inside the
   last reply from the server. A reply can carry a balance from just before a sale coin landed, so the button could say "Need $X"
   while the HUD already showed enough, until the next coin. (Whether Roblox delivers them in that order was not checked in Studio;
   the fix removes the possibility.)
4. **"Not enough" said five different ways in four places**: "NOT ENOUGH CASH!" in the market's status line, "NOT ENOUGH GEMS" /
   "NOT ENOUGH CASH" in the shop's dark strip, "Not enough cash!" only on the pad's small text, "Not enough Gems!" for gifts.
5. **Wrong reasons.** While the save was still loading the market showed "Need $10.4M" (it read the cash as 0). In Cash to Gems,
   MAX with less than $1T put **0**, and CONVERT then said "Type a whole number of Gems." instead of "not enough cash".
6. **A press could vanish.** If the market was still waiting for its own refresh (it asks the server again when it opens, after a
   sale, and so on), a Buy press in that moment was dropped without a word.

## What is fixed

* **One rule, one pair of words** (`ReplicatedStorage/StoreMoney158k`): `CanAfford(balance, price)` (equal money pays; exact at
  any size, also for digit strings and "1e+20"; something that is not an amount is "not known") and the words
  **"Not enough cash!"** / **"Not enough gems!"**. The server uses it (`SpendCash`, every gem check, the pads, the market, Cash to
  Gems, gifts) and so does every store screen, so they cannot disagree.
* **The money on screen never shows more than you have, a price is never rounded.** `CashNumbers.Balance` rounds down
  (HUD Cash / Gems, the market's Cash line), `CashNumbers.Price` is exact (the Buy buttons, the Cash to Gems cost). $10,350,000
  now reads "$10.3M". When the number before the point is one digit a second decimal is kept ($5.48B, $1.75T), so every price in
  the game is written exactly and holding exactly a price reads the same as its button (the Lava Boots' button read "Buy $5.5B";
  now "Buy $5.48B"). Every other price looks as before. Under a million everything is still exact.
* **Every Buy button can be pressed.** The market's button always reads its price ("Buy $10.4M"). A press the money cannot pay
  gets the Denied click and the plain red notice **"Not enough cash!"** (gems: **"Not enough gems!"**), nothing else: no greyed
  button, no other wording, no purchase prompt, nothing sent to the server. Same for the shop's gem buttons (Mech pack, bundles,
  passes) and CONVERT. The treadmill / fence pads were already pressable; a press now also shows the same notice on screen.
* **The server is still the judge.** The screen only says "not enough" when it knows the balance (the same number the HUD shows,
  after the save has loaded). If the server refuses for money anyway (the balance changed meanwhile), the screen shows the same
  notice. While the save loads the screen does not guess; the server answers ("LOADING...").
* **Other reasons keep their own words**: Bag full (told first, as R157), already owned, max level ("Fully upgraded!"), "Visit
  shop", "TRY AGAIN IN A SEC!". A money refusal also clears an old "BOUGHT!" line so the two never sit together.
* The market reads the live Cash stat, never a reply's older copy. A press made while the market is still refreshing waits for
  the refresh and then goes through (the button reads "Wait a sec" meanwhile). MAX in Cash to Gems puts at least 1.

## Store prices are always the same

**What was checked.** Every in-game-money price is a fixed number in the game's tables (`Config.ShopCatalog` from
`BalanceValues81` / `EconomyBalance90`, `Config.TreadmillTiers`, `GardenFenceRules`, `MechCatalog`, `PremiumPricing`). Nothing changes
them while a server runs, nothing scales them per player (no discount, no size or level factor, no random), and the client and
the server read the same tables. So a price cannot drift between opening the store and pressing Buy, and every player sees the
same price on every device. What could differ was only the **words** on the button:

* A short price like "5.5B" was the **$5.48B** Lava Boots rounded (20M more than the real price); "1.6T" was the $1.56T fence.
  Now a price is never rounded: it is written short only when the short form is exact ("$5.48B", "$10.4M"), otherwise in full
  ("$10,350,001"). The treadmill sign does the same (its pad already wrote the full number). Same words on any screen size: the
  text only depends on the price (the window may only make the letters smaller).
* The shop's Mech pack and pass buttons took their number from the client's copy of the catalog; now every gem caption, the
  CONVERT cost and the price a press sends come from one function that prefers the server's own numbers in its last reply.

**The safety net.** Every press now sends the price its button showed. The market (`EconomyService`) and the shop
(`PremiumService`: Mech packs, passes, Cash to Gems, bundles; bundles already checked their quote) compare it with their own
price; if it differs the purchase is refused with **"The price changed! Check the new price."** (the plain notice), **nothing is
charged**, and the reply carries the server's prices so the button shows the right one at once. An older client that sends no
price still buys at the server's price. Robux prices are Roblox's and are not touched.

**Prices that change on purpose** (not touched, listed so the owner can decide):

| What | How it changes |
|---|---|
| Treadmill upgrade pad | each level has its own price ($250K, $11.9M, $562M, $26.7B, $6.1T, $180T for levels 2-7) |
| Fence upgrade pad | each level has its own price ($500K, $18M, $646M, $23.2B, $1.56T, $72T for levels 2-7) |
| Limited Mech pack (gems) | 1 / 5 / 10 packs cost 80 / 375 / 700 gems (a bulk price); it is only on sale until the limited event ends (2026-11-01 UTC) or the owner's `SaleEnabled` / `SaleEndsAt` switch turns it off (the price itself never changes) |
| Cash to Gems | $1T per Gem, so the cost is the number of Gems x $1T |
| Robux buttons | the price Roblox reports for the product / pass (set on the Roblox website) |

Fruit of the Hour changes what a crop **sells** for, not a store price. No timed sales or discounts exist.

## Files

`ReplicatedStorage`: `StoreMoney158k` (new), `CashNumbers` (+ `Balance`, `Price`, `Reads`), `GardenWallet`, `ShopMenu`.
`ServerScriptService/ChestChaseServer`: `PlayerDataService` (`SpendCash`, `BuyTreadmill`'s words), `PremiumProgress`,
`PremiumService` (the shown price, the pass prices in its State), `EconomyService` (frozen: its hash line is updated with an
R158k comment), `GardenFenceData`, `GardenUpgradeService`, `PassGiftService`. `StarterPlayerScripts`: `EconomyClient`, `GamePassClient` (line 1 load guards untouched). `MANIFEST.tsv`.
The R148 purchase suite now expects the new words (on purpose).

## Tests

`sh docs/proposals/R158k/tests/run_store158k.sh` (registered in `tools/tests/run_all_suites.sh`):

* `test_store_client158k` (160 checks): the shared rule; the HUD against every real price (never shows enough when it is not);
  the REAL market (`EconomyClient` + `ShopMenu`) and the REAL shop (`GamePassClient`) on the mock: one short = the notice and
  nothing sent, equal money = sent, the server's money refusal = the same notice, an older reply never wins, loading = the server
  decides, other refusals keep their words, a double click sends one purchase, a press during a refresh is not lost, Robux
  untouched; every button shows exactly its price and its press sends that number, a narrow and a wide window show the same
  words, a different server price = "The price changed!" and the buttons show the server's prices at once.
* `test_store_server158k` (54 checks): the REAL `PlayerDataService` / `PremiumProgress` / `EconomyService` /
  `GardenUpgradeService` / `PremiumService`: the server takes the money exactly when the screens' rule says so (every price, one
  under / equal / one over) and only once; one short = the words and nothing charged; equal money buys; replays charged once;
  the pads' notice; the pad and the sign show exactly the cost; a press showing another price is refused with nothing charged
  (market, Mech pack, pass, CONVERT, bundle) and the reply carries the server's prices; an older client without a price still buys.
* 26 mutants put each old line back; every one is caught. `BEFORE=20d6e07` runs both tests on the old scripts: they fail
  (client 50 of 135 checks; the server test 11 failures before it stops), each failure one of the problems above.

**Not checked in Studio**: the look of the notice on a real screen, and the exact order Roblox delivers a reply and a Cash change.
