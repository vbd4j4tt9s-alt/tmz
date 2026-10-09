# R155: the pack pity (every 10th pack is lucky) and its two bars

Owner, in order:
1. "for mech packs a 10 pity system can work but we have a 1.5x luck boost at the 10th pack" -> "Every 10th pack" (not "10 in a row without a Secret+").
2. "make the pity separate an event pity and a normal pity the event pity only counts for void, verity and mech all other packs have separate pity".
3. "upon holding a pack a bar would show on the players screen slightly above the hot bar 1/10 pity" -> "there can be 2 separate bars above the hot bar one coloured
   gold the other coloured purple" -> "make it so that they are always visible and they are polished properly".

Picture: **`pity_bars.png`** (PC, landscape and portrait phone; 3/10, 9/10, the held pack, the lucky pop frame by frame, the lucky pack's reveal on the real card,
Reduced Motion). Remake it with `sh docs/proposals/R155/preview/run_pity_preview155.sh <scratch dir>`. The bars, the lucky tag, the top notices and the reveal card are
the real GUI trees on the Roblox mock drawn by Chromium; the hotbar, balances, status, MENU, BASE / TRACK and the touch controls are stand-ins placed by HudLayout. Not a
Studio screenshot.

`Config.Version` and `ProfileVersion` (22) are unchanged; the new saved field is optional.

## 1. The rule

| | |
|---|---|
| Two counts per player, both saved | **NORMAL** = every pack that is not a Void, Verity or Mech pack: world / stolen / banked packs (any odds version), bonus roll packs, daily quest / login / mystery pedestal packs, the free starter pack ... **EVENT** = the Void, Verity and Limited Mech packs, one count between the three |
| Which count | decided by the pack's own bag variant when it is opened (`PackPity155.Group`): a bonus roll / login day 7 / pedestal **Void** pack counts as EVENT, like any Void pack |
| Counting | opening a pack adds 1 to its group: opens 1-9 are normal, the **10th is LUCKY**, then the count goes back to 0 (1..9, lucky, 1..9, lucky ...) |
| The lucky pack | its roll takes **x1.5 on top of everything it already takes**: boots x clover for the normal packs; the clover alone for the Void / Verity / Mech packs (boots never reach them). Without boots or clover it is still x1.5 (luck 1 -> 1.5) |
| The cap | for that roll only, every luck cap is x1.5 too, so the x1.5 always counts: `BalanceValues81.LuckyPackBoost = 1.5`, `LuckyLuckCeiling` = `LuckCeiling` (x50M) x1.5 = **x75M**; the clover-only packs x2 -> x3. No other roll can reach these |
| Unchanged | the per-tier ceilings inside a pack (King 1%, Cosmic 5%, Secret 25%, Mythic 45%, Legendary 50% unless the pack's own chance is higher), the 80% rule, every shown fixed number (Index, reveal card, chat, plaque: `RawSeedOdds` at luck 1), prices, sizes and coats |
| TEST opens | an owner / Studio TEST open neither counts nor is lucky: a `TestGrant` pack (`/test pack`, `packset`, `void`, `verity`, the armed mystery / daily / bonus packs, forced events), a `/test rarepacks` reveal, and an open made with owner-given boots (`/test boots`), the same three the hub's BEST PULL already treats as TEST |

What a lucky pack does (real `SeedPackRules.SeedOdds`, OddsVersion 149):

| Player | Pack | Normal open | **Lucky (10th) open** |
|---|---|---|---|
| no boots | Desert Common | King 1/726B, Secret 1/7,260, Mythic 1/435 | King 1/486B, Secret 1/6,500, Mythic 1/410 |
| Sand Boots x25 | Desert Common | King 1/30B, Secret 1/3,040 | King 1/20.1B, Secret 1/2,730 |
| Thunder x25M | Desert Common | King 1/40K, Cosmic 1/1,100, Secret 1/85 | King 1/27K, Cosmic 1/934, Secret 1/76 |
| Thunder + clover x50M | Desert Common | King 1/20K, Cosmic 1/833, Secret 1/70 | King 1/13K, Cosmic 1/708, Secret 1/62 (x75M) |
| Thunder x25M | Desert Mythic (Pack06) | King 1/200 | King 1/133 |
| Thunder + clover x50M | Desert Mythic (Pack06) | King 1/100 (the 1% ceiling) | King 1/100 (the ceiling holds) |
| no clover | Limited Mech | Crowncore 1/200, Nebula 1/40, Holo Apple 1/14 | Crowncore 1/133, Nebula 1/34, Holo Apple 1/13 |
| clover | Limited Mech | Crowncore 1/100, Nebula 1/30 | Crowncore 1/67, Nebula 1/26 |
| no clover / clover | Verity | the Verity seed 1/100 / 1/50 | 1/67 / 1/33 |

**Owner call (as built, as asked):** the per-tier ceilings are unchanged, so where a pack is already at every ceiling a lucky roll cannot move it. Forest and Jungle top
out at Mythic (45%), so their best packs reach it early: with Frost Boots (x250) their Pack06 is there, with Lava Boots (x10K) Pack05-06, from Crystal Boots (x500K) Pack04-06.
At the very top (Thunder + clover, x50M -> x75M) the five other Mythic packs (Pack06: King at its 1%) join them: 11 of the 42 world packs don't move, the other 31 do.
Without boots, with Sand Boots or with the clover alone every pack moves. Raising the ceilings for the lucky roll would be a separate change.

One more exception, older than this: a **Void pack banked before R112** (OddsVersion 81 / none) has a fixed, luck-free table (the clover never reached it either), so its
lucky open counts and resets but cannot change its odds. Every other banked pack takes the x1.5: an R112 / R137 pack through its clamp, a pre-R112 world pack through
its old boots mapping (x1.15 ... x2 -> the same old boot, then x1.5 once).

## 2. Server authority

- The counts live on the server (`PackPityData155`, installed into `PlayerDataService`), saved as the optional profile field `PackPity = {Normal, Event}` (absent = 0 / 0:
  every profile saved before R155; an R154 server drops it). They go to the client as player attributes `PackPityNormal` / `PackPityEvent` (0-9) and
  `PackPityLuckyNormal` / `PackPityLuckyEvent` (+1 for each lucky pack this visit: the bars' pop).
- `PlayerDataService:OpenSeedPack` (the one place every seed is rolled) asks `PlanPackPity` **before** its roll (is this the 10th of its group, and is it a TEST open?),
  hands the roll the x1.5 luck / pass luck with the lucky cap on (`PackPityRoll` = `PackPity155.Scoped`), and calls `CommitPackPity` only **after** the open went through
  (the pack record is now the seed). So a refused or failed open (data still loading, a pack no longer in the bag, an already opened pack, a paid pack this account may not
  open, a roll that fails, a reward refused e.g. a full bag) neither moves nor uses up the count: the lucky 10th stays lucky. An open is one non-yielding transaction,
  so spamming the 5th click cannot open twice or skip a count (the test opens the same pack 20 times: 1 open, 19 refusals).
- The lucky ceiling is scoped: `PackPity155.Scoped(true, fn, ...)` turns it on only while that roll (or those odds) is worked out and off again after, even after an error
  (the odds code is pure and never yields). `PackOdds112` / `PackOdds137` (`O.Luck`, `O.LegacyLuck`) and `PackLuck154.PassLuck` read it; every other roll clamps
  exactly as before (their frozen hashes carry an R155 note). `SeedPackRules` is not changed.
- The BEST PULL hook is told the luck the roll took and that it was lucky, and reads the pull's odds the same way.

## 3. What the player sees

**Two bars, always on the HUD** (`PityBars155`, started by its own client script `PityBarsClient155`; `Hotbar.client.lua` is not touched):
- **NORMAL pity in GOLD** on the left ("3/10 pity"), **EVENT pity in PURPLE** on the right ("3/10 event pity"); a small diamond in the group's colour, a dark pill track,
  a glossy fill in ten steps with nine ticks, white text with a dark outline (Fredoka One). The fill eases to a new count.
- **9/10:** "9/10 next one's lucky!" (on a small bar: "next one's lucky!"), the edge lights up and the bar glows with a soft pulse.
- **The held pack's group** (any pack tool in the character): that bar is brighter (lighter fill, thicker light edge, solid track) and 1.06x; the other one stays, a
  little dimmer. Nothing in hand: both plain.
- **A lucky pack:** the bar pops: it fills, x1.2 with a white flash and a ring, a shine sweeps across, it says "LUCKY PACK! x1.5 luck", then drains back to "0/10".
- **The reveal:** with the reveal card (Common..Mythic, the usual case) a **"🍀 LUCKY PACK! x1.5 luck"** tag (💜 "LUCKY EVENT PACK!" for the event group) pops onto the card,
  in the free band between the seed and its "1 in N" line, and stays while the result waits to be collected. It is its own layer just above the card
  (DisplayOrder 97; `RarePullCinematic` / `RarePullCard` are not touched; it reads `RarePullRules.Layout`). The card's seed name and "1 in N" sit exactly where the bars
  are, so the bars step aside (fade out) while that card is up and come back with the collect, the lucky one popping. The compact card (in place / "skip pack animations")
  gets the tag just under it and the bars pop at once. A Secret+ story scene hides the whole HUD: then the top notice **"🍀 LUCKY PACK! x1.5 luck on this one!"**
  (the game's notice stack, `NoticeFeed83`) and the pop come when it ends; with no reveal on screen at all, the notice and the pop come at once.
- **The HUD luck row** (the clover icon, "x25M") shows the lucky roll's luck in gold while you hold a normal pack whose open is the lucky one (x1.5, up to x75M:
  `WorldStatusHud.Boosts(player, lucky)`), and goes back when you put it away. (The Void / Verity / Mech packs take the clover alone, which this row does not show.)
- **Reduced Motion:** no shine sweep, no pop / highlight scaling, no ring, no pulse; counts change at once; the tag appears without a pop; the lucky moment is the words,
  a light flash and a steady glow.
- **Hidden** while a menu covers the HUD (`SeedMenu`: shop, Index ..., and the Bag sheet), like the status HUD, and when the hotbar is hidden; **dimmed** while the tutorial
  card is up. Never interactive (clicks and touches go through).

**Placement:** its own ScreenGui, DisplayOrder 23 (under the hotbar / Bag 25, the tutorial 25 / 26, BASE / TRACK and the plant indicators 24, the reveal cards 96 and the
notices 100). Centred on the hotbar's frame (`ChestToolHotbar.Dock`, looked up by name at every layout change and followed when it moves; HudLayout's own hotbar metrics when
it is not there or mid-layout), 6 px above the held item's name. It keeps clear of every HUD box (`HudLayout.HudBoxes`: MENU, balances, status, the jump / thumb zones, owner
tools, BASE / TRACK) and of the bottom-right corner where the SKIP button sits during an opening, counting its glow and the held bar's 1.06x. When something is in the way it
slides sideways a little, then tries narrower bars, a thinner pair (phones), the two bars one above the other, and only then a little higher. Checked on 36 screens (the table
covers the first 30; 1280 x 540, 960 x 480, 700 x 400, 812 x 375, 430 x 932 and 360 x 740 were added by the review, section 3a):

| Screen | Bars | Where |
|---|---|---|
| PC 1920 x 1080, 1440p, 1366 x 768, 1280 x 720, MacBook, 5:4 | 230 x 24, text 15 px | centred, 6 px above the item name |
| small window 1024 x 768 / tiny 800 x 600 | 150 x 24 / 127 x 24, text 10 px | centred / 12 px left (the balances and status sit beside the hotbar there) |
| landscape phones 844 x 390, 932 x 430, 896 x 414, 740 / 800 x 360 | 162 x 18-20, text 11 px | centred over the hotbar, clear of the stick, the jump button and the status stack |
| small landscape 667 x 375 / 568 x 320 | 143 x 18 / 130 x 18 | centred |
| portrait phones 390 x 844, 414 x 896, 375 x 667, 360 x 800, 320 x 568 | 130-152 x 20, text 10-12 px | centred, above the raised hotbar |
| portrait 360 x 640 (MENU and BASE / TRACK sit just above the item name) | 113 x 16, text 10 px | 24 px right of centre |
| tablets / touch PC | 162 x 20 | centred |

### 3a. Review fixes (R155 review of the bars, the SKIP pill and the BONUS ROLL button)

1. **The bars no longer die when the player joins mid-tutorial or with a pack in hand (HIGH).** `Start` woke the bars (`character()`, `dim()`) before `Hud.Watch` had laid
   them out, so `paint` read `s.Placement.Bar` on nil and the client script died for the whole session. `Hud.Watch` (which lays out at once) now runs first, and
   `frame` / `step` / `paint` all return when there is no placement yet (the layout that follows draws everything with what changed meanwhile). Tests set those states before
   `Start`: the tutorial card up, a Mech / world pack in hand, a reveal card, a story scene, a menu, counts of 9 saved, all at once; and a step / wake / frames with no
   placement.
2. **The treadmill BONUS ROLL button no longer sits on the bars (MEDIUM).** Both wanted "just above the hotbar, centred". `PityBars155.ButtonSpot(Rules, m, w, h, boxes,
   extra)` is what `TreadmillBonusClient.layoutButton` now asks: the bars' extent (`B.Reserved`: the bars plus their 5 px glow and the held bar's 1.06x) is one more box for
   `TreadmillBonusRules.Place`, and its preferred spot is lifted above the bars (`Rules.Place` measures it from `m.HotbarBottom`, so it gets a copy of `m` with the bars' height
   added; `TreadmillBonusRules` itself is byte for byte as before, its R150 frozen hash stands). The button ends 7 px above the bars' glow (13 px above the bars): about 30 px
   higher than before, still the first thing above the hotbar. Where the old place was already far from the hotbar (short windows and landscape phones, where the notice
   rows sit in the way) it is where it was; on a 360-px-wide portrait phone the menu wheel's third option is over the lifted spot, so the button takes its next clear
   place (the right edge). The bars never move for the button (they are always there and do not look at it), and the answer depends on the screen alone, so nothing flickers
   when the button appears or goes. The client lays the button out again whenever HudLayout says the HUD changed (`Layout.Watch`: the screen, the touch setting, the thumb
   controls), as the bars do, so the two always agree; no module = the place `Rules.Place` gives (a pcall fallback). `TreadmillBonusClient`'s main chunk is still 178 of 180
   registers (no new top-level local).
3. **The SKIP pill no longer sits on the bars on phones (LOW).** The bars only avoided `SkipZone` (the bottom-right quarter), but `Card.SkipRect` moves left of it when the thumb
   controls take the corner (844 x 390: 570..680, 226..266 against the bars' 256..588, 250..270). The bars do not know the pill (so they never move for it); the pill takes the
   bars' extent as one more box (`Card.SkipBoxes` = `HudLayout.HudBoxes` + `PityBars155.Reserved`), exactly as it takes the hotbar. On the 14 phone sizes that were affected (every landscape phone but the 932 x 430 / 896 x 414, every portrait one) it moves up by 28-32 px (56 on a 360 x 740)
   (844 x 390: y 226 -> 194; 375 x 667: 348 -> 316, 47% of the height, still below the 45% line the button never goes above); on every PC / tablet screen it is where it was. Checked on 60 screen / thumb-control cases: never touching
   the bars, at the bottom right (right of the middle, below 45% of the height), 12 px inside the screen, 8 px clear of every HUD box.
4. **A bar at 9/10 costs the glow alone (LOW).** Every frame used to allocate a closure, a UDim2, the words and a geometry string per bar (the loop runs for ever at 9/10), even
   while hidden. Now: the closure is a module function; the geometry is compared as four numbers; the fill's UDim2 is made only when the fill moves; the words are cached by
   (group, count, size, pop); a frame with nothing changed since the last paint (a counter bumped by every wake) paints nothing or, at 9/10, writes only the glow's
   transparency (the very value a full paint gives); a bar nobody can see (the HUD dimmed out under a reveal card, hidden under a menu, Reduced Motion's steady glow) does
   nothing and the frame loop stops (the menu closing wakes it). Test: 60 frames at 9/10 = 60 writes, all on the glow, 60 property lookups, no UDim2 / ColorSequence / words;
   0 / 0 / 0 under a reveal card, under a menu and with Reduced Motion.

## 4. Listed with the odds

The rule, in the owner's voice: **"every 10th pack u open is lucky: x1.5 luck (event packs count separately)"**.
- **The hold tooltip** of every pack (shown on screen by `ItemTooltip155`: hover, a picked item, a just-held pack, a gamepad selection; see `inventory.md`, "The item tooltip"): its odds, then this line; when its open would be its group's lucky 10th, "LUCKY PACK: x1.5 luck on this one!" right under the name
  and the odds are the lucky roll's (a TEST pack is never lucky).
- **The Limited Mech pack's shop card** (the paid-random disclosure): a caption along the bottom of the pack preview, "every 10th event pack u open (Void, Verity, Mech) is
  lucky: x1.5 luck", wrapped and scaled to its box (never cut; checked in the R120 shop renders on PC and the 844 x 390 phone).
- **`/test odds`**: the last line, "pity: every 10th pack u open is lucky ...".

## 5. Owner test commands (`docs/COMMANDS.md`, the F4 help)

| Command | What it does |
|---|---|
| `/test pity @name` | "Bob: pity 3/10 (lucky in 7 packs) \| event pity 9/10 (the NEXT event pack is LUCKY)" |
| `/test pity set 9 9 @name` | sets the normal and event counts (0-9, saved; 9 = the next pack of that group is the lucky one) |
| `/test odds storm mythic 50000000 lucky`, `/test odds event clover lucky` | the lucky roll's odds (x1.5, cap x75M / the clover x3); the header says "LUCKY 10th: x1.5 luck (x50000000 -> x75000000, cap x75000000)" |
| `/test pity 30` | (a number alone) still the R81 track reset preview |

Remember that owner-made packs and packs opened with `/test boots` are TEST opens: to see a real lucky pack, `pity set 9 9`, take off the test boots and open a real pack.

## 6. Files

New: `ReplicatedStorage/PackPity155` (the rules, the words, the colours, the lucky scope), `ReplicatedStorage/PityBars155` (the bars, the tag), `ChestChaseServer/PackPityData155`
(counts, save / load, the open's plan / commit, the tooltip, `/test pity`), `StarterPlayerScripts/PityBarsClient155` (starts the bars; the load guard is line 1).
Changed: `PlayerDataService` (the open, load, save, install), `ChestService` (hold tooltip), `HubDisplayService` (BEST PULL reads a lucky pull's odds), `OwnerUpdateCommands82`
(`pity`, `odds ... lucky`, the rule line), `BalanceValues81` (`LuckyPackBoost`, `LuckyLuckCeiling`), `PackOdds112` / `PackOdds137` / `PackLuck154` (the lucky clamp; frozen
hashes updated with R155 notes), `WorldStatusHud` (the luck row for a lucky pack in hand), `GamePassClient` (the Mech card's line), `StudioTestHelp`, `docs/COMMANDS.md`,
`src/MANIFEST.tsv`, `tools/tests/run_all_suites.sh` (+ `run_pity.sh`). Older tests that count tooltip / odds lines now expect the rule line under the odds:
`R147/tests/test_verity_pack.luau` (`/test odds verity` and the Verity / Void hold tooltips), `R148/tests/test_roster.luau` (the tooltip row parser skips it),
`R139/tests/test_starter.luau` (the starter pack's "no luck row" ignores it: it is the same line on every pack and says nothing of the starter's secret 2x).
Not touched: `Config.lua`, `SeedPackRules`, `Hotbar.client.lua`, `RarePullCinematic`, `BackgroundMusic`. (The review fixes touch `RarePullCard` - the pill keeps clear of the bars, see
`cinematic_camera.md` - and `TreadmillBonusClient`: its button asks `PityBars155.ButtonSpot`; `TreadmillBonusRules` stays byte for byte.)

## 7. Tests

`sh docs/proposals/R155/tests/run_pity.sh <scratch>` (in `run_all_suites.sh`):
- **static:** the changed / new scripts compile at -O0; the manifest; the frozen hashes and their R155 notes; Config.lua, the hotbar, the cinematic, the card, the music and
  SeedPackRules untouched; the load guard; the open plans before its roll and commits after the record swap (and after every refusal); save / load / tooltip / `/test odds` /
  Mech card / BEST PULL / COMMANDS.md / F4 help wiring.
- **`test_pity155.luau`** (93 checks, the R153 clover world with the real server code): every bag variant's group; the 10th / 20th / 30th lucky and the reset; the lucky
  scope (on only inside, off after an error); PackOdds112 / 137 take x75M only on a lucky roll, the pre-R112 mapping gets x1.5 once, PackLuck154 x3 only on a lucky roll;
  the HUD row; the cap moves (Desert Common King x1.5 at x75M); per-tier ceilings and the 80% rule hold in all 42 packs at x75M; Void / Verity / Mech lucky tables; the shown
  numbers (54 seeds) the same inside a lucky roll; 30,000 lucky Mech rolls; 25 real normal opens of every kind (world, banked 137 / 112 / 81, the starter pack) and 12 event
  opens: lucky at 10 and 20 / 10, the roll got x1.5 luck and pass luck exactly once with the lucky cap, the BEST PULL hook told; interleaved groups; no boots / no clover;
  TEST packs, `/test rarepacks`, owner boots excluded; loading, unknown, failed roll, refused reward, paid pack, spam; save / load / rejoin / old profile / junk / the real
  DataStore save; `/test pity`, `pity set` (and bad input), `pity 30`, `/test odds ... lucky` and its rule line; the hold tooltip (also through the real `ChestService:_holdPack`).
- **`test_pity_bars155.luau`** (124 checks, the real client; sections 8-11 are the review's: the SKIP pill and the BONUS ROLL button over 60 screen / controls cases, starting in the middle
  of things, the per-frame cost): its own layer and order; both bars from the start; gold / purple; values and the easing; 9/10 glow and pulse;
  the held pack's highlight for each kind; the lucky pop (scale, flash, ring, shine, full, back to 0/10) whichever signal comes first; a count lowered by a command;
  the card: the bars step aside, the tag in the card's free band, the pop after the collect; the compact card; a story scene; Reduced Motion (no easing, steady glow,
  no pop / shine / ring, tag without pop); menus / Bag / hidden hotbar; the tutorial dim; 30 screens (inside, above the hotbar and its item name, over the hotbar,
  clear of every HUD box and the SKIP corner counting the glow and the 1.06x, every text fits); the real gui follows the screen; it finds the hotbar's frame by name and
  follows it, and ignores a frame that is not the hotbar's shape; the game's notice stack gets the lucky notice; Destroy.
- **28 teeth** (each must fail): Mech counted as normal, every 11th, no reset, x1.5 twice, no lucky cap, the lucky cap on every roll, TEST packs counted, counting before
  the open went through, not saved, not loaded, no rule in the tooltip, no rule in `/test odds`, the HUD's lucky row always on, no highlight, no 9/10 glow, a pop that
  scales with Reduced Motion, no card tag, bars over the HUD; and the review's ten: the start order and the guards put back, the guards alone, the SKIP pill that ignores the
  bars, the BONUS button that ignores them / is not lifted, a paint every frame, a paint while hidden, a pulse while dimmed out, the words made on every paint, a menu that does
  not wake the bars.

**Results** (private scratch dirs, one suite at a time): `run_pity.sh` ALL PASS (93 + 124 checks, 28 of 28 teeth after the review fixes; 93 + 69 and 18 of 18 before). The full runner (`run_all_suites.sh`) on this
branch: 85 suites PASS, 3 FAIL that were the tooltip / odds line counts above (fixed, then R139, R147 verity_pack and R148 roster PASS); the runner was terminated
during R153 perf153, so the rest was run one by one: R153 perf153, check_compile_O0 (511 scripts, busiest function 178 of 180, unchanged), R154 luck_odds (with its 13
teeth), R154 fixes, hub_zfight154, perf154, R155 pity, and again after the last changes R153 clover, shop_R120 and R129 phone HUD: all PASS. Among them the ones asked for:
R154 luck_odds, R153 clover, seed_rarity, mech_pack, R152 void_giveaway, seed_opening (only), load_guard, R149 verity and verity_pack, R147 verity_pack.

Not checked: anything in real Studio, including the bars on a real phone (the mock has no text measuring: Fredoka One is taken as .52 em a letter), the tag on a real
reveal card next to the 3D seed, the colour emoji in the tag and the notice, and how the other R155 agents' hotbar / Bag and SKIP button will finally sit (the bars find the
hotbar's frame by name and keep clear of the whole bottom-right corner, so a moved dock or a SKIP button there is covered). After the review fixes: the real look of the BONUS ROLL
button above the bars (`pity_bars.png` draws a stand-in at the rect `ButtonSpot` gives) and of the SKIP pill's Enter key (Fredoka / Montserrat stand in for Roblox's fonts).
