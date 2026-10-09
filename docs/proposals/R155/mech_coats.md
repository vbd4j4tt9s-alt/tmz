# R155 – Mech pack coats (Gold / Diamond) and the end of the limited event

Owner: "We can implement 1C" (`docs/proposals/R153/mech_pack.md` section 2), and: the Mech card's "LIMITED TIME!" must get a real end, the same as the Verity event.
**Built, nothing pushed.** Config.Version and ProfileVersion (22) are untouched; product prices (80 / 375 / 700 gems or Robux) and the shown seed odds (48 / 26 / 16 / 7 / 2.5 / 0.5) did not change.

Picture: **`mech_coats.png`** (a plain / Gold / Diamond Mech pack: hero, hotbar size, held, a frame of the opening; a Gold and a Diamond Mech plant with their coated fruit; the seeds;
the shop card live and ended; the words). Blender renders of the parts the game really builds (`SeedPackVisuals.Bag`, `MechPackArt153`, `MechPackFx153`, `PlantVisuals`, dumped on the Roblox
mock with the owner's templates and the generated flat pouch, as the R153 Mech previews were). Approximate: no Future lighting, bloom imitated.
Remake it with `sh docs/proposals/R155/preview/run_mech_coats_preview.sh <scratch> <python with bpy 4.5>`.

## 1. What a player gets

| | |
| --- | --- |
| The roll | Every Mech pack you **buy** (gems or Robux; 1, 5 or 10; each pack on its own) rolls **plain 95% / Gold 4.5% / Diamond 0.5%** |
| The seed | The seed that comes out keeps the coat (a Gold Mech pack gives a Gold Plasma Pepper Seed ...) |
| The plant, the fruit | The plant is Gold / Diamond; each fruit has the usual **20%** chance to carry the coat, and a coated fruit pays **x3 (Gold) / x6 (Diamond)** |
| The look | A Gold / Diamond Mech pack is drawn in the same treatment a Gold / Diamond world pack gets, with the cyan traces, the core, the MECH letters, the red LED and the black hazard stripes kept |
| The words | "Gold 4.5% / Diamond 0.5% coat" next to the odds on the shop card, the hold tooltip and `/test mechshop`; the "Bought" notice names the coats; the tool is "Gold Limited Mech Pack" |
| The end | The card's "LIMITED TIME!" has a live countdown to `LimitedEvent.EndsAt` (1 Nov 2026 00:00 UTC) and the pack goes off sale there |

Value: a coated fruit pays x3 / x6 on 20% of the fruit of a coated plant, so a bought pack is worth 0.045 x 0.2 x 2 + 0.005 x 0.2 x 5 = **+2.3%** (the proposal's number); the odds table, the
prices and the sizes are as they were.

## 2. The roll (`PremiumProgress:GrantMechPacks`)

World packs roll their coat with `SeedPackRules.RollMutation` over `SeedPackRules.PackMutations` (None 95 / Gold 4.5 / Diamond .5; `BalanceRules.MutationWeights` holds the same numbers). Those are the
constants the Mech pack uses (nothing is different, so there is nothing to explain): `P.RollCoat()` is `RollMutation` on its own `Random`, drawn **once per pack**, after the size roll, in the record's
existing `PackMutation` field.

Which sources roll (the rule: "only where world packs of that source also roll coats"):

| Source | Mech pack | Why |
| --- | --- | --- |
| Gem purchase (`BuyMechPack`), Robux receipt (`ProcessReceipt`) | **rolls** (`paid == true`) | bought packs are the only way to get a Mech pack now |
| A daily / login grant (`GrantDailyPack(.., 'Mech')`; no reward gives one since R153) | plain | the daily, quest, bonus-roll, starter, giveaway and mystery packs are all `PackMutation='None'`; a world pack gets its coat when it spawns in the world (`ChestService:RefreshWorldPack`, `VeiledEvent81`), nowhere else |
| `/test rarepacks mech` | plain | a TEST pack of that command is plain, like `/test rarepacks` for every biome |
| `/test rarepacks mech gold` / `diamond` (new) | that coat, never rolled | so the owner can SEE a coated Mech pack without 20 purchases; `/test pack` already takes a coat word the same way. A bought pack still rolls its own |

Saved data: the record's existing `PackMutation` (saved, loaded, gifted like any pack's): the saved row of a coated Mech pack has exactly the keys of a plain one, `ProfileVersion` stays 22, an old
Mech pack (saved plain, or with no `PackMutation` at all) loads plain. `PackLabel` names a coated Mech pack "Gold Limited Mech Pack" (the Void, Verity and world packs do the same).
(`SeedPackRules.lua` is in R151's frozen-hash list: its hash is updated with an "R155 (on purpose)" line; only that one label line changed.)

## 3. Seed, plant, fruit: nothing new, all of it the world packs' code

`OpenSeedPack` copies the pack's `PackMutation` into the seed record -> `PlantRules.NewCrop` makes `crop.Mutation` -> `PlantRules.Fruit` keeps it at `MutationInheritance` (.20) -> `Weather.Price` pays
`BalanceRules.MutationMultipliers` (Gold 3, Diamond 6). The tests drive those real functions and read the result back: the plant of a coated seed is coated (all six Mech seeds), **19.3%** of the fruit of the Plasma Pepper and the Crowncore Tree carry the coat (6,000
crops per seed and coat; the roll is a saved identity, so the same crops give the same answer in both coats), a coated fruit pays exactly x3 / x6 of the same fruit uncoated, and every slot of the 4-fruit Holo Apple Tree rolls on its own.
The look of the seed (`MechArt.BuildNative`), of the planted Mech plant and of its coated fruit (`PlantVisuals.Build`) was already coat-aware: the art test checks it on all six seeds.

## 4. The look

`SeedPackVisuals.Bag` paints a coated pack the same way for every design: every part takes the coat's colour, Metal / Glass, reflectance (.38 / .28), a Diamond's transparency (.20 on the pouch mesh, .10
on parts), no texture; `PaperColor` becomes the coat's colour. Painted blindly that would make the Mech pack's traces gold on gold, so the Mech design flags **its lit parts and its stripes**
(`MechCoatKeep`, set in `MechPackArt153.Build`, honoured by one condition in `SeedPackVisuals.Bag`'s coat loop):

| Takes the coat (the world treatment, exactly) | Keeps its colour |
| --- | --- |
| the pouch (or the plain-parts body), the bottom seal, the 8 tear strips, the riveted frame and rivets, the 8 corner bolts, the reactor housing and its silver ring, the turbine blades, the counter-gears, the antenna base and mast | the 20 cyan traces, the 2 cores, the 2 facets, the 16 cyan ring edges, the teal insets, the 28 MECH letters and their dark plates, the red LED, the 16 black hazard stripes (60 parts) |

The cues of R153 only touch the kept parts (the trace pulse, the LED blink, the opening's scan / glow in the hint colour), so they work on a coated pack unchanged. A kept part is a clear colour from what
it sits on in both coats (CIE76 >= 25 in the test; the closest is the facet on the core, which is the plain design's own).

Contexts, all built by the same call (the tests build every one in both coats and compare each part with the plain pack): ground (1x, .5x, 25x), held R15 / R6 (the hum light and the antenna sparks
are as before), the hotbar / Bag / Index picture (default shape or not; `ItemPictures` keys "Pack|8|MechLimited|Gold" apart from a plain one, so it is its own picture), the shop's viewport, the
opening copy (the whole R153 opening suite runs on a Gold and on a Diamond pack and the revealed seed keeps the coat), and the plain-parts body (a server still baking).
The shop banner and the Index show the plain pack (the coat is not known before you buy).

## 5. The words

| Where | Text |
| --- | --- |
| Shop card (under the buy buttons, next to the countdown) | `Gold 4.5% / Diamond 0.5% coat` |
| Hold tooltip | the pack's name ("Gold Limited Mech Pack"), the six seed odds, then the same last line (drawn by `ItemTooltip155`, on a PC when the slot or Bag card is hovered, on a phone / gamepad for a picked or just-held pack: `inventory.md`, "The item tooltip") |
| `/test mechshop` | `Gold 4.5% / Diamond 0.5% coat on every pack u buy (each pack rolls its own; free packs stay plain).` and the event line |
| `/test odds` | does not cover Mech (it refuses stage 8): nothing to add |
| "Bought" notice (the existing R148 one: one line, one `PurchaseDone`) | `Bought: 10 Mech Packs! (sparkle) 1 GOLD + (gem) 1 DIAMOND!`; one coated single: `Bought: 1 Mech Pack! (sparkle) GOLD MECH PACK!`; nothing coated: the plain line as before |

The line is read from the world table (`MechCatalog.CoatLine`), so it can never disagree with the roll. The notice is the world coats' own marks (the sparkle and the gem `NoticeCopy83` already uses
for Gold and Diamond); no new system.

## 6. The limited event's end (owner's extra scope)

`MechCatalog.OnSale(now)` is now the owner's own switches (`SaleEnabled`, `SaleEndsAt`) **and** `LimitedEvent.Active(now)`; one function, so the State, the gem purchase and the Robux prompt agree.

| | After `EndsAt` |
| --- | --- |
| Card, title row | "LIMITED TIME!" -> **"EVENT OVER!"** |
| Card, countdown | `ENDS IN 27d 04h 12m 09s` (the Index LIMITED tab's format, `LimitedEvent.Text`, the server's clock, ticking every second while the shop is open) -> **"THANKS FOR PLAYING!"** |
| Buy buttons | both "Event over" and off (a click sends nothing); the SINGLE / 5 / 10 chips still work |
| Server, gem purchase | refused with "EVENT'S OVER! THANKS FOR PLAYING!" **before anything is charged** (the Verity wording) |
| Server, Robux prompt | refused with the same line, **no prompt opens** |
| Server, a receipt | **still granted** (`ProcessReceipt` never asks the sale or the event): a prompt opened before the end and paid after it gets its packs, coats and notice as usual. A full Bag keeps its old answer (NotProcessedYet, retried) |
| Packs already owned | open as before; gift rules untouched |

The owner's switches still work before the end. To extend the event change `LimitedEvent.EndsAt` (it moves the Index tab, Verity and this card together).

## 7. Tests (all on the Roblox mock with the real modules; `sh docs/proposals/R155/tests/run_mech_coats.sh <dir>`, in `run_all_suites.sh`)

`run_mech_coats.sh` (one command, 6 steps; every number below is from the final source):

| Step | What it proves | Result |
| --- | --- | --- |
| 0 static | every script compiles; the roll is in `GrantMechPacks` only (`paid == true`); no daily / bonus / mystery / starter / test path rolls; the world constants (95 / 4.5 / .5, 20%, x3 / x6), the Mech odds and prices, ProfileVersion 22 and `Config.Version` did not move; `ProcessReceipt` never asks the sale; the event check comes before the gems are charged; the coat line is read from the world table; the art skips the kept parts in one place | ok |
| 1 server (real `PlayerDataService`, `PremiumService`, `PurchaseAnnouncer`, `ChestService._holdPack`) | **purchase roll**: one draw per pack in order (1 / 5 / 10), 30,000 bought packs: **Gold 4.71%, Diamond 0.470%** (world 4.5 / 0.5; tolerance .45 / .15), the coated count in a 10-pack follows Binomial(10, .05) (0 / 1 / 2+ coated in 59.9 / 31.5 / 8.6% of batches, within 4 / 4 / 2.5 points), never a whole batch coated, the rate is the same for 1x and bigger packs; free and `/test` packs plain (and `/test rarepacks mech gold|diamond` coated); a roll that throws rolls the whole batch back. **Saved field** (same keys, ProfileVersion 22, old / missing / unknown coat loads plain, a gift keeps it). **Reveal** for all six seeds in both coats, the Bag names, a save and load. **Plant and fruit**: the crop is coated for all six seeds, 19.3% of fruit carry the coat, a coated fruit pays exactly x3 / x6 of the same plain fruit, the 4 fruit slots of the Holo Apple Tree roll on their own. **Notice** (gems and Robux, 1 / 5 / 10, one notice and one `PurchaseDone`, a repeated receipt announces nothing). **Event**: `OnSale` / `TimerText` at several times and the switch at `EndsAt`, the owner's own switches still work, State and every offer off after the end, a gem purchase refused with nothing charged / granted / announced, a Robux prompt refused with no prompt, a receipt for a prompt opened before the end **granted** after it (1 / 5 / 10, with its notice), a full Bag keeps NotProcessedYet, an owned pack still opens and keeps its coat. **Hold tooltip** ends with the coat line, a world pack's has none | 119 checks, 0 failures |
| 2 shop (real `GamePassClient`, `PremiumLayout`) | the coat line, the countdown text at 27d 04h 12m 09s, 3d, 1h, 1 min, 1 s; it ticks once a second and not while shut; a half-second sweep across `EndsAt` (running: LIMITED TIME! + both buttons on; ended within a tick: EVENT OVER!, THANKS FOR PLAYING!, both buttons off, "Event over", a click sends nothing, the chips still work; reopening after the end is ended at once); a refused purchase shows the server's message; the layout of the new row in 12 widths x 4 scales of all three modes | 49 checks, 0 failures |
| 3 art (real modules, the owner's templates, the generated flat pouch) | a Gold / Diamond Mech pack in ground (1x, .5x, 25x), held R15 / R6, picture (default shape or not), viewport, opening copy and the plain-parts body: every non-kept part is the world coat's colour / material / reflectance / transparency (compared with a real world pack's), the 60 kept parts keep the plain pack's colour and material, `PaperColor`, the same parts at the same places, each lit part a clear colour from what it sits on, the stripes black on the coated seal; `ItemPictures` keys; the rig (pulse, blink, reset, fx); a plain pack is as before; the seed, planted plant and coated fruit looks for all six seeds | 155 checks, 0 failures |
| 4 opening (the real `SeedPackClient`, `PackOpeningFeedback`, every reveal module) | the whole R153 opening suite run on a **Gold** and on a **Diamond** Mech pack (clicks, bolts, scan, steam, hiss, sound caps, calm, onlooker, skip, clean-up) **plus**: the seed the reveal shows is that coat (every visible part) in all 13 openings, a plain pack's seed is plain | 168 + 168 checks, 0 failures |
| 5 z-fighting (R152 sweep, Mech step) | the pack on the flat pouch in every context and size and in plain / Gold / Diamond, its **opening copy at 5 moments in all three coats**, its plain-parts body in all three coats | 53 scenes (15 opening frames, 9 with the scan line up, 18 on the plain-parts body), PASS |

The R153 z-sweep's opening frames were not really moving before: the mock's Sound could not play, so `MechPackFx153` stopped at its first tear group (by design: one bad frame stops only the Mech touch) and every "opening"
frame was an unmoved copy. The dump now has a Sound that can play and asserts the Mech touch did not fail; the bolts, turbine, stripes and scan line really move through the frames, and the sweep still finds nothing.

**The checks have teeth**: `python3 docs/proposals/R155/tests/mutate_mech_coats.py <dir>` breaks a private copy of the source 22 ways (no roll, free packs roll, one coat per batch, wrong rate, sale ignores the event, the event never ends,
a late receipt refused, gems charged after the end, a prompt after the end, no coat in the name / tooltip / notice, the reveal drops the coat, fruit inheritance 50%, the card never ticks / buttons stay on / no coat line, the keep flag
removed, the coat painting the lit parts, the plant not coated, the opening seed losing its coat, a layer too thin) and each one makes its step fail: **22 of 22 killed**.

Existing suites run on the final source (all PASS): R153 `run_mech_pack.sh` (162 + 167 checks; its static check now says bought packs roll), R152 `run_seed_opening.sh <dir> only` (R154 collect 733, R153 server 240, R152 look 608 ...),
R153 `run_seed_rarity.sh` (117 checks), R152 `run_zfight_sweep.sh` (with the owner's place: 8 maps variants + verity + opening + keepers + Mech), R152 `run_load_guard.sh` (4 checks), `check_compile_O0.sh` (507 scripts, busiest
function 178 of 180 registers, `TreadmillBonusClient`, unchanged), R120 shop (6,877 checks: the new row is checked on all 13 screens), R148 purchase (329 + 71 + 75), R153 clover (8 + 94 + 242), and the whole `tools/tests/run_all_suites.sh` (95 suites on the final source: 93 PASS and 2 FAIL on the first pass, both for the same deliberate reason: R147 `run_verity_ui` and R149 `run_verity_pack` compare every existing pack part by part with the R147 build, a Gold and a Diamond Mech pack included, and a coated Mech pack now keeps its lit parts. Both tests now leave exactly those parts (by name) out of a coated Mech pack's comparison and still compare everything else, a plain Mech pack whole; re-run: both PASS (339 and 673 + 1216 checks)).
Existing tests touched on purpose: R148's `test_purchase.luau` pins the coat roll to plain (its exact "Bought: ..." text is the point there); R151's `frozen.sha256` has the new `SeedPackRules.lua` hash with an "R155 (on purpose)" line; R147's `test_verity_ui.luau` and R149's `test_verity_pack.luau` leave the kept lit parts of a coated Mech pack out of their before / after comparison (see above); R120's `test_shop.luau`, R152's `check_zfight_sweep.py` and R153's `dump_mech_zscene.luau` / `run_mech_pack.sh` grew the new checks.

## 8. Files changed

Game (`src/`):

- `ReplicatedStorage/MechCatalog.lua`: `OnSale(now)` includes the event, `EventOver`, the card's words (`Event`), `TimerText`, `CoatLine`
- `ReplicatedStorage/SeedPackRules.lua`: `PackLabel` names a coated Mech pack (one line)
- `ReplicatedStorage/MechPackArt153.lua`: the lit parts and stripes are flagged `MechCoatKeep`
- `ReplicatedStorage/SeedPackVisuals.lua`: the coat loop skips a flagged part (one condition)
- `ReplicatedStorage/PremiumLayout.lua`: the card's coat line + countdown row (wide / medium side by side, narrow stacked)
- `ReplicatedStorage/StudioTestHelp.lua`: the `/test rarepacks` help text
- `ServerScriptService/ChestChaseServer/PremiumProgress.lua`: `RollCoat`, the roll in `GrantMechPacks`, the event check in `BuyMechPack` (which now also returns the new records)
- `.../PremiumService.lua`: a Robux prompt after the end is refused; the notice gets the records (gems and receipts); `ProcessReceipt` untouched
- `.../PurchaseAnnouncer.lua`: `CoatText`, the coat words in the "Bought" notice
- `.../ChestService.lua`: the coat line on the Mech hold tooltip (a bought pack's only: a free or TEST Mech pack never rolls a coat)
- `.../OwnerUpdateCommands82.lua`: `/test mechshop` shows the coat line and the event
- `.../RarePackTests.lua`, `.../StudioTestCommands.lua`: `/test rarepacks [rarity] [gold|diamond]`
- `StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua`: the coat line, the live countdown, the ended card

Tests and docs: new `docs/proposals/R155/` (`mech_coats.md`, `mech_coats.png`, `tests/` with `run_mech_coats.sh`, `test_mech_coats_server / shop / art.luau`, `make_opening_coat.py`, `mutate_mech_coats.py`, and `preview/` with the dump, the Blender renderer,
the composer and the two run scripts); changed on purpose: `R147/tests/test_verity_ui.luau`, `R148/tests/test_purchase.luau`, `R149/tests/test_verity_pack.luau`, `R151/tests/frozen.sha256`, `R152/tests/check_zfight_sweep.py` (Mech step), `R153/tests/dump_mech_zscene.luau`, `R153/tests/run_mech_pack.sh` (the static check),
`shop_R120/tests/test_shop.luau` (the new row), `tools/tests/run_all_suites.sh` (the new suite).

## 9. For the owner's eye

1. **Old Mech packs.** Packs bought before this release are plain and stay plain (no new field, as asked), but a hold tooltip cannot tell them from a new plain pack, so they show "Gold 4.5% / Diamond 0.5% coat" too. The coat odds apply at purchase, so
   the line is true on the card and on a new pack's tooltip; on an old pack it is only a description. If that bothers you: show the line only on the shop card, or add one optional record field (like `PackShape`) so the tooltip can tell.
2. **Free and test Mech packs.** A free Mech pack (no reward gives one now) is plain, like every free pack. `/test rarepacks mech` is plain; I added an optional word so you can SEE one: `/test rarepacks mech gold` / `diamond` (TEST packs, never announced). Not asked for; easy to drop.
3. **Diamond readability.** The cyan traces are the least visible on the ice pouch: CIE76 distance 34 from the Diamond pouch, against 70 on the gunmetal one and 103 on Gold (the LED stays 110 from it). The sheet shows them clearly and Neon glows in game, but it is the one to
   look at on a phone. The lit parts are kept on purpose; if you want Diamond to stand out more, the Mech pouch alone could take a slightly deeper ice tint behind them.
4. **The shop card and the Index show the plain pack** (the coat is not known before you buy). If you want it to sell the coats, the preview could cycle plain / Gold / Diamond (the parts exist; it is a client-only change).
5. **The end is real.** "LIMITED TIME!" now ends at `LimitedEvent.EndsAt` (1 Nov 2026 00:00 UTC): the card says EVENT OVER!, nothing new can be bought, owned packs and late receipts are fine. `SaleEnabled` / `SaleEndsAt` still end it earlier. To run longer, change `EndsAt` (it moves the
   Index LIMITED tab and Verity too).
6. **The "Bought" notice** gets longer when something is coated ("Bought: 10 Mech Packs! (sparkle) 1 GOLD + (gem) 1 DIAMOND!"); it is still one line from the same service.
7. **R153's z-sweep** was testing unmoved opening copies (section 7); fixed in the dump, nothing found.
8. **Not touched, noticed**: `HarvestItemInfo` and `PlayerDataService` carry a `MutationMultiplier` of 2 / 3 (Gold / Diamond) next to the real cash rule x3 / x6 (`BalanceRules`); I found nothing that shows the field, so it is a stale number, not a wrong payout.
