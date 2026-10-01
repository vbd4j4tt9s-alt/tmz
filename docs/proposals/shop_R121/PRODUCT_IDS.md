# R121 product ids to fill in

> **R122 update (owner request): nothing on this page needs to be filled in any more.**
> The shop no longer shows gift buttons or the "DOUBLE Your SPEED" 10-minute boost banner, so
> `SpeedBoost10ProductId` and all 14 `Gift...ProductId` attributes below are **optional / unused**.
> Leave them empty. The server code for them stays in place but has no way to be bought from the shop.
> The ids that still matter are the existing ones: the bundle ids on `PremiumPricing`
> (`CashSmallProductId` ... `SpeedMegaProductId`), the Mech pack ids on `MechCatalog`
> (`MechPackProductId`, `MechPack5ProductId`, `MechPack10ProductId`), the pass ids on `GamePassCatalog`,
> and the pass gift ids on `PassGiftCatalog` (also no longer reachable from the shop).
>
> The rest of this page is kept for reference (R121).

Every id is an **attribute on a ModuleScript in ReplicatedStorage**. In Studio, select the ModuleScript,
go to Properties > Attributes, press **+**, type the attribute name exactly as written below, pick type
**Number** and paste the developer product id. A missing attribute or `0` means "not set": its button
shows **SOON** (gift buttons) or **SOON / Unavailable** (buy buttons) and does nothing. Nothing else
needs to change in code.

The Robux price in the shop always comes from the live price you set on the Creator Dashboard. The
"price shown" column below is the price the shop was designed for.

## 1. (R122: unused) the 10-minute x2 Speed boost

| Product | Price shown (suggested) | Attribute | ModuleScript |
|---|---|---|---|
| x2 Speed boost, 10 minutes | 49 R$ (your choice) | `SpeedBoost10ProductId` | `ReplicatedStorage.PremiumPricing` |

What the buyer gets: training speed gain x2 for 10 minutes. Buying again adds 10 more minutes (up to
60 minutes for self-purchases). It multiplies with the permanent x2 Speed game pass (pass + boost = x4).
The timer keeps running in real time and survives leaving and rejoining. The permanent x2 Speed
**game pass** in PASSES is unchanged.

## 2. (R122: unused) gift versions (attributes on `ReplicatedStorage.GiftProducts`)

| Product | Price shown | Gift attribute (on `GiftProducts`) | Normal product attribute (already used) |
|---|---|---|---|
| +30B CASH | 49 | `GiftCashSmallProductId` | `CashSmallProductId` (PremiumPricing) |
| +100B CASH | 149 | `GiftCashMediumProductId` | `CashMediumProductId` (PremiumPricing) |
| +300B CASH | 350 | `GiftCashProductId` | `CashProductId` (PremiumPricing) |
| +650B CASH | 699 | `GiftCashValueProductId` | `CashValueProductId` (PremiumPricing) |
| +1.4T CASH | 1499 | `GiftCashMegaProductId` | `CashMegaProductId` (PremiumPricing) |
| +250K SPEED | 49 | `GiftSpeedSmallProductId` | `SpeedSmallProductId` (PremiumPricing) |
| +1M SPEED | 149 | `GiftSpeedMediumProductId` | `SpeedMediumProductId` (PremiumPricing) |
| +3M SPEED | 350 | `GiftSpeedProductId` | `SpeedProductId` (PremiumPricing) |
| +8M SPEED | 699 | `GiftSpeedValueProductId` | `SpeedValueProductId` (PremiumPricing) |
| +25M SPEED | 1499 | `GiftSpeedMegaProductId` | `SpeedMegaProductId` (PremiumPricing) |
| Limited Mech Pack x1 | 80 | `GiftMechPackProductId` | `MechPackProductId` (MechCatalog) |
| Limited Mech Pack x5 | 375 | `GiftMechPack5ProductId` | `MechPack5ProductId` (MechCatalog) |
| Limited Mech Pack x10 | 700 | `GiftMechPack10ProductId` | `MechPack10ProductId` (MechCatalog) |
| x2 Speed boost, 10 min | same as the boost | `GiftSpeedBoost10ProductId` | `SpeedBoost10ProductId` (PremiumPricing) |

Total to fill in: **15 attributes** (1 boost + 14 gift products). The pass gifts (x2 Growth / x2 Speed)
already exist and keep their R79 attributes `GrowthGiftProductId` / `SpeedGiftProductId` on
`ReplicatedStorage.PassGiftCatalog`.

## 3. Creating the products on the Creator Dashboard

1. Open https://create.roblox.com/dashboard/creations, pick this experience, then
   **Monetization > Developer Products > Create a Developer Product**.
2. Create **one product per row** above. A gift is a **separate developer product** with the **same
   reward** as the normal one; the game decides the reward from the id, not from the name or price.
   Suggested names: `+30B CASH (Gift)`, `Limited Mech Pack x5 (Gift)`, `x2 Speed 10 min (Gift)`, ...
3. Set the price (normally the same as the non-gift version) and save.
4. Copy the product id (the number on the product page / in the product list "Copy Asset ID") and paste it
   into the attribute from the table.
5. Every id must be different. If the same id is pasted into two attributes, the game refuses both
   (no purchase opens and receipts wait) instead of guessing which reward to give.

## How a gift worked in game (R121 only; removed from the shop in R122)

- Every bundle card, the Mech pack banner and the SPEED boost banner have a purple gift button left of
  the prices. It opens the same "Gift" player list as pass gifts (players in this server).
- After choosing a player, the Robux button opens the **gift** product prompt. When Roblox confirms the
  purchase, the server saves the gift and sends it to that player: cash / speed / packs / boost time are
  given to them, and both players get a message.
- If the chosen player left before the purchase finished, the gift is kept for the buyer (shown as
  "Send gift - 1 ready" in the gift list) and can be sent to anyone later. Nothing paid is lost.
- If the recipient's bag is full or they hit the cash limit, the gift waits for them (also across rejoins)
  and is delivered when there is room.
- Limited Mech Pack gifts follow the same paid-random-item rules as buying packs: both players must be
  allowed to buy them.
