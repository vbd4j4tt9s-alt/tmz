# R156 preview: tips on the title screen (Style B, the owner's pick)

Owner: "add tips in the starting screen too somewhat like minecraft with tips like rarer packs give higher loot or mythic packs give a higher chance of a king seed and so on".
The owner chose **Style B**, the rotating "tip:" line above "Click to play!". Style A (the tilted Minecraft-style splash) was dropped.

This is a **preview, not a release**, and an **approximate preview, not a Studio screenshot** (see "How the preview is made" for what is real and what is a stand-in).
Nothing under `src/` is changed; the change is described below and the preview runs it on scratch copies.

![title tips](title_tips.png)

`title_tips.png` shows Style B on a PC (1920 x 1080), a landscape phone (844 x 390) and a portrait phone (390 x 844). Each size shows 3 different tips (a how-to, a lore line and the easter egg)
and a 4th frame in the middle of a fade. The frame colour is the tip's kind. The whole list is printed on the sheet too.

## Style B: how it behaves

| What | Value |
| --- | --- |
| Where | a single `TextLabel` ("TipLine") inside the title's `CanvasGroup`, 8 px above the button; the green "tip:" then the tip, white with the title's dark outline, Fredoka One |
| Change | a new tip every **5 s**: fades in over **0.35 s**, holds, fades out over the last **0.35 s**; the text changes while it is invisible |
| Order | the first tip of a visit is random, then a shuffled order (every tip shows once before any repeats), so a new random tip each time the title shows |
| Reduced Motion | **no fade**: the text just changes every 5 s (checked on the mock: the "mid-fade" frame is fully opaque with Reduced Motion on) |
| Size | one line on a PC / landscape phone, up to two lines on a portrait phone; the text shrinks to fit (`TextScaled`, 11 to 32 px; every one of the 24 tips fits every screen: checked) |
| Clicks | the label is not active: it never takes the click meant for the button; it fades in with the title and out when the player clicks |
| Never covers | the logo, the pack art or the button: `TitleScreen104.Layout` reserves a band for it (below) |

Layout (what `T.Layout` returns, from the real code on the mock):

| Screen | Logo | Tip line | Button |
| --- | --- | --- | --- |
| PC 1920 x 1080 | 1160 x 653, **unchanged** | up to 32 px, one line, 41 px band, 8 px above the button | y 1005 |
| Landscape phone 844 x 390 | **422 x 238 (was 477 x 268, about 11% smaller)** to make room | 16 px, one line, 23 px band | y 343 |
| Portrait phone 390 x 844 | 355 x 200, **unchanged** | up to 25 px, two lines, 62 px band | y 769 |

Only the landscape phone loses logo size; everywhere else the room was already there.

The code change (all in `src/ReplicatedStorage/TitleScreen104.lua`, not applied here): `T.Layout` gets a tip band (`tipSize`, `tipHeight`, `tipBand`, plus `TipY / TipWidth / TipHeight / TipSize` in its result),
`T.Start` builds the label in a `task.spawn` (so a missing list can never block the title) and resizes it with the layout, and the frame step moves the clock and the fade.
`preview/patch_title156.py` writes that scratch copy and prints the exact diff.

## The tips (24)

Groups, as the owner asked: **how-to** (a real game fact, checked in the code; source files below), **lore / ominous** (teasing, no mechanics invented) and **easter egg** (the owner's line, written as he gave it).
Voice: lowercase, "u" / "ur", short, an emoji only now and then.

### How-to (19, each checked against this checkout)

| # | Tip | Checked in |
| --- | --- | --- |
| 1 | rarer packs give higher loot | `PackOdds137.lua` (PackFloor, PackTopLuck, MidOneIn), `SeedPackRules.lua` (PackTiers, Variants Pack01..Pack06). Run on the real odds, in every biome: a better pack never has a worse floor, and a Mythic pack never gives less than Legendary (a Common pack can give a Common seed in Forest / Jungle); e.g. Forest Mythic seed share 0.25% in a Common pack, 26.7% in a Mythic pack |
| 2 | mythic packs give the best chance at a king seed 👑 | `PackOdds137.lua` (King 1 in 1T divided by PackTopLuck 1 / 2.5 / 6 / 20 / 60 / 200). Run on the real odds (with the 80% rule): the King chance rises with every pack tier in **all five biomes that have a King seed** (Desert, Snow, Lava, Crystal, Storm Peaks); the Mythic pack is the best in each. Forest and Jungle have no King seed. Desert: 1.4e-10% (Common) up to 2e-8% (Mythic) |
| 3 | every 10th pack u open is lucky: x1.5 luck 🍀 | `PackPity155.lua` (Every=10, "LUCKY PACK! x1.5 luck"), `BalanceValues81.lua` (LuckyPackBoost=1.5), `PackPityData155.lua` / `PlayerDataService.lua` (the server opens it). Void, Verity and Mech packs have their own separate count (`PackPity155.lua`, EventVariants) |
| 4 | boots make ur biome packs luckier | `BalanceValues81.lua` (BootLuck), `Config.lua` (Sand / Frost / Lava / Crystal / Thunder Boots; LuckMultiplier set from BootLuck). Void / Verity / Mech packs ignore boots (`SeedPackRules.lua`, R154 comment), hence "biome packs" |
| 5 | click or tap a pack 5 times to open it | `SeedPackRules.lua` (OpenClicks=5), `ChestService.lua` (pack tooltip "Click / tap / RT 5 times to open") |
| 6 | hold E (or tap and hold) to steal a pack | `Config.lua` (StealHoldSeconds=1), `MapService.lua` (prompt "STEAL", HoldDuration), `BeginnerGuide.lua` (E on keyboard, "hold it" on touch) |
| 7 | shovel holes on the track make pack carriers drop their pack | `TrackHoleConfig.lua` (only pack CARRIERS fall in; "U FELL IN A HOLE! PACK DROPPED"; 3 s between digs, 4 holes each, a hole lasts 3 min, the trapped carrier is down 4 s), `TrackHoleService.lua`, `HarvestToolService.lua` (shovel tooltip) |
| 8 | the shovel can remove a plant from ur garden too | `HarvestToolService.lua` (tooltip "Remove a plant"), `GardenShovel.client.lua` ("Remove <plant>? ... U won't get the seed back.") |
| 9 | swing the bat: it knocks players back and a carrier drops the pack | `BatConfig.lua` ("knockback, a short stun, and stolen-pack disarm"; 1 s between swings), `BatArt.lua` (tooltip "Swing to disarm"), `BatService.lua` into `ConcurrentKeeperService.lua` `HitByBat` (ragdoll knockback from `KnockbackConfig.lua` Bat; a runner is "caught" and drops the pack). Works on the biome track (BatConfig RequireBiome) |
| 10 | click the soil with a seed to plant it 🌱 | `ChestService.lua` (seed tooltip "Click or tap the soil to plant!"), `BeginnerGuide.lua` (step 4) |
| 11 | plants keep growing while ur offline | `OfflineGrowthNotice.client.lua` (the owner's "Plants grow offline" line), `PlantRules.lua` + `GardenPlantRuntime.lua` (growth is read from real timestamps: MatureAt, `Rules.Growth(crop, os.time())`) |
| 12 | weather can mutate ur plants for x2 / x3 / x5 fruit | `WeatherTraits.lua` (Rain = Drippy x2, Blizzard = Frosted x3, Thunderstorm = Charged x5), `WeatherService.lua` (plant roll), `BalanceRules.lua` (0.2% per minute) |
| 13 | gold fruit sells for x3, diamond fruit for x6 💎 | `BalanceRules.lua` (MutationMultipliers Gold 3, Diamond 6), `WeatherTraits.lua` `Price`, `PlantRules.lua` (a plant keeps its pack's coat; each fruit inherits it with a 20% chance) |
| 14 | sell ur crops at the market | `EconomyClient.client.lua` ("Go to the market to sell ur crops!"), `MarketLayout.lua` |
| 15 | the fruit of the hour sells for x1.5 to x3 at the market | `FruitOfHour.lua` (Min 1.5, Max 3.0, 3600 s), `PlayerDataService.lua` (the sale uses it), `MarketLayout.lua` (its pedestal) |
| 16 | hop on a treadmill to get faster ⚡ | `BeginnerGuide.lua` (step 5 "GET FASTER! hop on it"), `BaseService.lua` (training gain) |
| 17 | each friend in ur server adds +10% to ur treadmill gains (3 max) | `DailyRewards.lua` (FriendBoostPerFriend .10, max 3), `SocialService.lua`, `BaseService.lua` (GetFriendGainMultiplier) |
| 18 | the sign over each keeper shows the speed u need to outrun it | `KeeperSpeedLabels.client.lua` ("SPEED NEEDED", green with a tick once u are faster) |
| 19 | stay 15 minutes to unlock today's mystery pack at ur base | `MysteryPackRules.lua` (UnlockSeconds 15 x 60, a new one every day, the pedestal stands in each base), `MysteryPackService.lua` |

### Lore / ominous (4, no mechanics claimed)

| # | Tip | Grounding |
| --- | --- | --- |
| 20 | beware the darkened | The Darkened is the game's secret keeper (`KeeperRigConfig152.lua` stage 0, `VeiledEvent81.lua`, `VerityConfig.lua`) |
| 21 | when the lights go out... run | `BiomeMood.lua` (R127: The Darkened's arrival turns the lights off) |
| 22 | the darkened's sign says ∞. good luck | `KeeperSpeedLabels.client.lua` / `SpeedPoints.lua` (its speed needed is shown as "∞") |
| 23 | something waits at the end of storm peaks... | `VerityConfig.lua` (the quest places The Darkened "at the end of Storm Peaks") |

### Easter egg (1)

| # | Tip | Note |
| --- | --- | --- |
| 24 | dont look into the pyramid | the owner's line, exactly as given; no game fact is claimed (Desert has a "Sunscar Pyramid" landmark, `Config.lua`, if he wants to hook it up) |

## Ideas not used, and why

None of the candidates was flat-out false, but some were wrong as first worded or not safe to ship:

- "dig holes with the shovel to trap players": only players **carrying a pack** fall in (`TrackHoleConfig.lua`), so the tip says "pack carriers drop their pack".
- "gold / diamond packs grow gold / diamond plants and their fruit sells x3 / x6": the plant keeps the coat, but each fruit inherits it only 20% of the time (`BalanceRules.lua` MutationInheritance), so the tip is about gold / diamond **fruit**.
- "the faster u are, the further u get down the track": nothing in the code says that. Replaced by the keeper sign (#18), which is real.
- "boots boost ur luck": only biome packs; Void / Verity / Mech ignore boots, so the tip says "biome packs".
- "mythic packs give a higher chance of a king seed": true, but only where a King seed exists (five biomes); noted on #2.
- "the free void pack giveaway": real today, but it is capped at 500 claims for the whole game (`VoidGiveawayRules152.lua` Cap), so the tip would become false.
- "the 4 leaf clover doubles ur luck": true (`GamePassCatalog.lua`), but it is a paid pass; left out so the title never pushes anything paid.

Side finding, not changed: `HarvestItemInfo.lua` and `PlayerDataService.lua` fill a `MutationMultiplier` label field with Gold 2 / Diamond 3, while the price uses 3 / 6 (`BalanceRules.lua`). Nothing reads that field, so players see no wrong number; the tip uses the price.

## How the tips are stored

One list module, `ReplicatedStorage/TitleTips156` (the draft is `preview/TitleTips156.lua`), so the owner adds a tip by adding one line:

```lua
local T={Interval=5,Fade=.35,Prefix='tip:'}
T.Tips={
 {Kind='howto',Text='rarer packs give higher loot'},
 {Kind='lore',Text='beware the darkened'},
 {Kind='egg',Text='dont look into the pyramid'},
 -- one line per tip
}
function T.Order(random) ... end  -- a shuffled order, every tip once before any repeats
function T.Line(index) ... end    -- the RichText line: green "tip:" then the text
```

`Kind` is `howto`, `lore` or `egg` (only for the owner's bookkeeping; the game shows them alike). The title reads the list through `pcall(require, ...)`, so a broken or missing list leaves the line out and never blocks "Click to play!".
Keep how-to tips true: if a rule changes, change its tip (the table above says which file each one depends on). All tips must fit one line on a landscape phone at 16 px or two lines on a portrait phone; `preview/check_tip_fit156.mjs` checks that for the whole list.

## How the preview is made

`sh docs/proposals/R156/preview/run_title_tips156.sh <scratch dir>` (needs /opt/luau, python3 + Pillow, node + playwright; the font comes from npm `@fontsource/fredoka-one`).

- **Real:** the title tree. `TitleScreen104` (a scratch copy with the tip line, `patch_title156.py`) is started on the Roblox mock at each size and stepped through its own frame function; its letters, button, veil, layout numbers and the tip rotation are the game's code, and the GUI tree is dumped and drawn by headless Chromium.
- **Real:** the tip list is the draft module, and the checks (every tip fits each size; Reduced Motion; the King-odds table, `verify_king_odds.luau` on the real `SeedPackRules` / `PackOdds137` / `PackLuck154`) run on the same code.
- **Stand-ins:** the blurred hub behind (a blurred crop of an earlier three.js hub render, `docs/proposals/R151/snow_hub.png`; the game blurs the live hub with a BlurEffect of size 18) and the green seed pack (the game draws a 3D `ViewportFrame` of the Forest pack, which the mock cannot build).
- **Approximations:** Chromium's font drawing and its TextScaled fit stand in for Roblox's (the letter size of "STEAL A / PACK" is the renderer's best fit, not measured in Studio).
- The 5 s timing is shown by stepping the real frame function at 60 fps: frames at 2.5 s, 7.5 s and 12.5 s are settled tips 1, 2 and 3; the 4th frame is 4.825 s into a tip (the fade-out about half through).

Files: `title_tips.png`, `title_tips.md`, and under `preview/`: `run_title_tips156.sh`, `patch_title156.py`, `TitleTips156.lua`, `title_tips_scene156.luau`, `make_sheet156.py`, `render_gui156.mjs`, `check_tip_fit156.mjs`, `verify_king_odds.luau`.
