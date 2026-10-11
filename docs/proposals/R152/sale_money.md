# R152: sale money flies to the balance by itself

Owner: "change the money animations where u sell something u no longer need to hover over it to collect it just auto flies towards the players balance ... that goes the same
for gems and every other feature that has the money animations."

Preview: `sale_money.png` (a time strip on desktop, phone landscape, phone portrait), `sale_money_desktop.gif`, `sale_money_phone.gif`. They are the real
`SaleMoneyEffects` + `GardenWallet` + `HudLayout` played on the Roblox mock and drawn with headless Chromium (`preview/run_sale_money_preview.sh`); the coins are drawn with
CSS shapes, so the art is an approximation, the positions, sizes, timing, counters and balances are the code's.

## What happens now

One helper, `ReplicatedStorage/SaleMoneyEffects.lua`, is behind every cash / gem animation in the game (see the table below), so all of them changed together.

| time after the sale | what you see | what the code does |
|---|---|---|
| 0 - 0.40 s | the coins pop out of the sale and spread (unchanged since R53) | nothing claimed |
| 0.40 s + 0.25 .. 0.50 s | each coin rests a beat; the beats are spread over the burst (a random order) so the coins stream away instead of leaving as a lump | nothing claimed |
| 0.55 s flight | eased (smoothstep), a slight sideways arc (26-44 px, kept inside the safe area), shrinking to 38 % towards the end, turning level | the coin follows the counter live (a rotated phone, a moved HUD) |
| landing | the counter bumps (`GardenWallet:Pulse`), one `Bubble06` click per coin (the R150 collect cue, spaced by InteractionAudio) | **the share is claimed now**, same remote, same `(receiptId, index)` |
| ~0.1 s later | the balance ticks up (the server's value replicates; the wallet's own number-jump bumps the digits) | |

Cash coins go to the Cash row, gem coins to the Gem row. While the Sell window is open the HUD rows are hidden, so cash coins fly to the window's own "Cash $..." line
and that line flashes (`opts.Anchor`, wired in `EconomyClient`). Targets come from the live icon positions, so phone layouts (`HudLayout`: the thumbstick-corner stack on
landscape phones, the top-right stack on portrait) are followed; the target and the whole flight are clamped to the layer (the safe area), 12 px / 8 px inside.

Gone: the `CollectCashHint` label, the `TextButton` coins (a plain, input-less `Frame` now: nothing to hover or tap, and a coin can no longer swallow a click meant for the
world), `MouseEnter / MouseLeave / Activated`, and the texts that told the player to collect.

## Every share is always claimed

`_due` / `_drain` / `By` in the helper. A share is *due* when its coin lands, when it has no coin, or when its deadline `By = seen + 0.40 + 0.50 + 0.55 + 1.5 = 2.95 s` passes
(a `task.delay` watchdog every 0.25 s, not RenderStepped).

| case | what happens | test |
|---|---|---|
| many sales at once | at most 13 coins per currency, 26 in all (`MAX_PER_CURRENCY`, `MAX_ICONS`); every other share is claimed directly at once. 64 receipts x 13 shares = 832 all claimed once | 5 |
| reduced motion / FastMode / StudioPlantEffects off | no coins: all shares claimed at once, the "+total" label and the counter's bump + click are the whole effect; switched on mid-flight = the rest claimed on the next frame | 4 |
| window minimised (RenderStepped stops) | the watchdog claims everything by 2.95 s; the coins that land after the window returns claim nothing a second time | 7 |
| UI hidden / zero-size layer / disabled ScreenGui / a burst that throws | zero-size: claimed at once; the others still claim (a throwing burst marks its shares due) | 7 |
| UI destroyed while coins are up | `Destroy` and the layer's `Destroying` send one claim for every share still owed (idempotent on the server) | 7 |
| the claim fails (refused, error, nil, malformed answer) | retried after 0.5 s, 1 s, 2 s ... capped at 8 s, **forever** until the server accepts; one coin landing never depends on it; never more than 8 claims in flight; a claim with no answer after 15 s is given up on (its slot freed) and sent again, and its late answer is not counted twice; never a second claim for a share already accepted | 6 |
| the answer is lost but the server did apply it | the next `Sync` (every 5 s and on every garden / premium revision) shows the claim mask: the share stops being retried; if the receipt is gone the server answers `Success, Amount 0` | 6, 8 |
| rejoin | `GetPendingSales` on join lists the receipts again: they pop from the screen centre and fly | (unchanged path) |

## Server

No server file needed a change for the mechanism. Checked, and tested (`test_sale_claim_server.luau` runs the real `PlayerDataService:CollectSaleCash`, cut out of the source):

* **No wait-for-claim timeout exists.** A receipt lives in `garden.PendingSales` (saved with the garden) until its shares are claimed; `CollectSaleCash` has no clock, nothing
  expires it, nothing credits it by waiting (a month of mock time credits nothing and drops nothing). So there is nothing for the auto-claim to race, and **the server does
  not grant money without a claim**; no server-side grant is needed for correctness. The 2.95 s deadline is only the client's promise that a stuck drawing cannot delay a claim.
* The one limit that can refuse a claim is the balance cap (`balance + share > MaxCash / MaxGems` answers `Success=false` with no change); the client keeps retrying every 8 s
  until there is room. The other refusal that existed, `COLLECT YOUR FLOATING REWARDS FIRST` (64 receipts pending), cannot be reached by hand any more; its text is now
  `YOUR LAST REWARDS ARE STILL ARRIVING`.
* Exploits: validation is byte for byte what it was (id a string of 1..100, index an integer 1..13 and <= Count, the share is `SaleReceiptRules.Share`, a claimed bit is never
  paid twice, the receipt is looked up only in the caller's own garden, the rate limit `CollectSaleCash 120/s burst 832` is the one sized for 64 x 13 shares). The client
  only ever sends ids and indices the server listed, never an index whose bit is already claimed, never one share twice, and a stale or repeated poll adds nothing (`Seen`).
  Test 8 / the server test: shares add up to exactly the receipt's amount, a second claim credits 0, out-of-range / non-integer / NaN / over-long / foreign / invented ids credit 0.
* `EconomyService.lua:536`: the toast `SOLD FOR $n - HOVER OVER CASH TO COLLECT` is now `SOLD FOR $n CASH` (the shape `SimpleGameText` turns into `SOLD! +$n`).
  `docs/proposals/R151/tests/frozen.sha256` has the new hash for that file (the only line changed).

## Features that spawn money icons (all through the helper)

Every currency credit in the game is a receipt in `PendingSales` claimed through `CollectSaleCash`; there is no second path (`rg` for `GetOrCreateCashValue(...).Value +=` and
`Gems +=` finds only `PlayerDataService.lua:1675-1676`, the claim, plus a purchase rollback refund and an owner command). So these all fly and claim themselves now:

| feature | where the receipt is made |
|---|---|
| market sale, one crop / all crops (cash) | `PlayerDataService.lua:1692, 1722` (`_prepareSale` 1653) |
| cash to gems converter (gems) | `PremiumProgress.lua:116` |
| cash bundles bought with gems (cash) | `PremiumProgress.lua:176-179, 189-201` |
| Index: seed reward (cash), halfway and completion gems | `PremiumProgress.lua:289, 299, 309` |
| daily login gems, daily quest gems | `DailyProgress.lua:14` (called at 87 and 102) |
| any other `AddCash` / `QueueCurrency` caller | `PlayerDataService.lua:491`, `PremiumProgress.lua:111` |

Client: `EconomyClient.client.lua:215` builds the helper (claim callback unchanged, `Anchor` for the Sell window); `:556` feeds it on a sale (with the sale button's position as
the origin); `:222` and `:233` feed it from the 5 s poll and the garden / premium revision.

Found already automatic or with nothing to collect (no money icons, nothing changed): treadmill bonus roll (a pack; the reveal's `COLLECT` is the close button of the revealed
pack, `TreadmillBonusStyle.lua:64-67`), gifts (`FruitGiftClient`, `PassGiftDialog`: items / credits), mystery pack (`MysteryPackClient`: a take from the pedestal), Verity hand-in
(`VerityClient.client.lua:553`: thanks + chime), Void giveaway (`VoidGiveawayClient152.client.lua:253`: chime + sign), offline growth (`OfflineGrowthNotice`: a notice),
`PurchaseCelebration` (a ring, confetti and a chime, no pickup), speed / coin popups (`SpeedGainPopup`: floating text, no pickup).

The Index and Daily windows still have their own CLAIM buttons (you press them to receive a reward); only the floating coins that used to need a hover afterwards are gone.
That is a design choice for the owner: auto-claiming those buttons too would be a different change.

## Texts removed or changed

`CollectCashHint` (the label), `Collect your Gems.` / `Collect your Cash.` (now `Gems on the way.` / `Cash on the way.`: `PremiumProgress.lua:123, 201, 297, 307, 318`,
`DailyProgress.lua:88, 106`; `PremiumService.lua:128` comment), `COLLECT YOUR FLOATING REWARDS FIRST` (`PremiumProgress.lua:107`), the Studio command message
`Hover over the floating cash to collect.` (`StudioTestCommands.lua:254`). The tutorial files (`BeginnerTutorial`, `BeginnerGuide`, `TutorialProgress`, `TutorialTargets`) were not
touched; none of them says to hover or collect (the tutorial's `Cash` step still completes on the first claim, which now happens by itself).

## Tests (`tests/run_sale_money.sh`, in `tools/tests/run_all_suites.sh`)

* `test_sale_money.luau` (1145 checks): no input needed, pop / beat / flight timing and stagger, eased + arc + shrink + monotone approach, the right counter per currency, the claim
  with the coin AT the counter, reduced motion (3 switches + mid-flight), caps and overflow (52, 78, 832 shares), retries (refuse / throw / nil / `{}`, back-off, 50 s of refusals,
  a slow yielding remote with the 8-in-flight cap, claims that never answer, eight hung ones given up on after 15 s), stalled render loop, zero-size / disabled UI, a throwing burst, `Destroy`, exploits (claimed
  masks, repeated polls, hostile receipts), the real `GardenWallet` on desktop and three phone layouts (+ a notch inset, a counter off screen, a broken counter row, the Sell window's
  anchor), and the source checks (no hover handler, EconomyClient wiring, load guard on line 1).
* `test_sale_claim_server.luau` (77 checks): the real `CollectSaleCash` for cash and gems.
* Changed: `R150/tests/test_inputs.luau` section 7 (was hover / click, now arrival), `R148/tests/test_purchase*.luau` and `R140/tests/test_daily_client.luau` (the new hint text).
* The 20 mutations tried against the helper (claim at launch, no back-off, no retry, no watchdog, overflow dropped, drawing in reduced mode, no flush on destroy, no in-flight cap,
  no burst guard, no hang guard, a late answer counted twice, hidden layer not claimed, claimed masks ignored, no `Seen`, anchor ignored, no target clamp, no mid-flight reduced motion, wrong counter for gems, no landing
  click, a share claimed twice) are all caught (one more, removing the re-entrancy guard in `_drain`, is not: it is defensive).
