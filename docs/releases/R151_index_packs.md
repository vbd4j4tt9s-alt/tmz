# R151 Index PACKS tab and a polished notification badge

Owner, live: "add a pack index in the index and state rate of spawn and drop rates shapes for visual representation in the index can just use the default pack shape . The notification for index
like red the red circle and + .. has to be polished at it looks really low quality and cut out wrongly". Picture: `docs/proposals/R151/index_packs.png` (the PACKS tab on a desktop and a phone,
the badge before | after, zoomed; an approximation drawn from the real ChestIndex tree under the Roblox mock, not a Studio screenshot).
Tests: `docs/proposals/R151/tests/run_index_packs.sh` (`--existing` also runs the older Index / daily / pack-shape suites, `--mutations` breaks the new code 19 ways and expects a failure each time).

**Installer:** three new ModuleScripts (in `src/MANIFEST.tsv`, ReplicatedStorage): `NotifyBadge151`, `IndexPackData151`, `IndexPacksView151`. Changed scripts: `ChestIndex.client`,
`DailyRewardsClient.client`, `HudLayout`, `ItemPictures`, `SeedPackVisuals`, `SeedPackRenderer`, `VerityPackArt`, `VerityPouch151`. Installers (`docs/releases/*install*`) are NOT rebuilt here.
No server change, no saved-data change, no remote, no odds / rules / config change (`frozen.sha256` still holds for every odds, rules and config file).

## 1. The PACKS tab
A new first tab in the Index, orange, same tab row and same look as the biome tabs. It lists 47 cards in 8 sections: the 42 designs (7 biomes x 6 tiers), then the Void Pack (The Darkened),
the Limited Mech Pack, the Verity Pack, the mystery pack and the starter pack. The legacy sacks are not listed (they cannot be obtained any more); no test pack (`TestGrant`) is listed.
Each card: the picture, the name, the biome and tier chips, `SPAWN 1/N of packs on its track`, where else it comes from (bonus roll / daily reward / mystery pedestal), and `DROPS`: one chip per seed
rarity with its chance as `1/N`. Tap a card for `EVERY SEED`: each seed of the pack with its own `1/N`. The tab's top line lists the pack sizes (0.5x ... 25x) and how often a pack comes bigger.
Packs that do not spawn on the track (Void, Mech, Verity, mystery, starter) say how you get them instead of a spawn rate.

Where every number comes from (all of it computed when the tab opens, from the same tables the server rolls with; nothing is typed in):
- spawn rate: each variant's `SeedPackRules.Variants[...].SpawnWeight` over the sum of all of them (what `RollVariant` does for every world slot);
- drop rates: `SeedPackRules.SeedOdds` on the client copy of the server's own Config (`SeedPackRules.BuildSeedCatalog()`), luck 1, no boost, so the chips sum to 100 % (`PackOdds137` inside it for the
  ordinary packs, `VoidPackOdds85` for the Void Pack, `VerityPackOdds` for Verity, `MechCatalog` for the Mech Pack), in the order of `SeedPackRules.OddsRows`; the starter pack shows the plain Forest Pack
  odds (the first-pack 2x is not shown, the hidden pity is not shown);
- pack sizes: `SeedPackRules.PackSizes` (the 1x row is left out); bonus roll: `TreadmillBonusRules.VariantOdds`; mystery pedestal and the mystery card: `MysteryPackRules.Odds`; daily reward packs:
  `DailyRewards`; shop: `MechCatalog.Offers`; The Darkened: `PackSchedule81.Event` and `SeedPackRules.RefreshInterval`;
- text: `OddsText85.Format` (1/N, whole numbers; `1/1,110`, `1/10K`, `1/201M`).
`docs/proposals/R151/tests/test_indexpacks_data.luau` cross-checks every displayed number against the server's roll code (`Rules.Roll`, `RollVariant`, the bonus roll, the mystery pedestal; a Monte Carlo on the
real code) and checks the 1/N form, the how-to text of the non-track packs and that nothing hidden (pity, 2x, test packs) leaks into the tab.

## 2. The pictures use the DEFAULT pack shape
R151's pack shape variations (`PackShapes151`, six pouch designs baked as an EditableMesh) are never used in the Index. The picture proxy carries `DefaultPackShape`, `ItemPictures.Key` adds `|Plain` to the
cache key (so a plain picture and a shaped one of the same pack never share a cache entry), `SeedPackVisuals.Bag` passes the flag to `SeedPackRenderer`, which skips `PackShapes151.ForBuild`. The Verity pack,
whose pouch is baked by the server, gets a plain neutral pouch baked on the client (`VerityPouch151.RequestPlain / PlainTemplate`, falls back to the server pouch while it loads). Pictures are built
lazily (cards on screen first, then a margin, 3 per pass) and reuse the existing `ItemPictures` cache, so opening the tab does not build 47 pictures at once.

## 3. The notification badge
Root cause of the cut-out badge, measured on the R150 code (`test_indexbadge.luau`, mode `before`): the INDEX button sits in a `CanvasGroup` (`HudLayout.Navigation`) that is only 4 px bigger than the button
on each side, and the old badge hung 8 px out of the button's corner (its white ring included), so the group sliced 4 px off the top and the right of the circle: the flat edges. The tab dots hung 3 px out of
their tab into the tab row's `ScrollingFrame`, which clips: 3 px cut. The DAILY badge hung over the top edge of the screen on phones.
Fix: `NotifyBadge151` is ONE component for every badge: a perfect circle (`UICorner(1,0)` + `UIAspectRatioConstraint`), red gradient, white ring (`UIStroke`, inside the holder), soft shadow and glow, the
count centred in bold `TextScaled` text (`""`, the count, `9+`, `!`), a pop-in when it appears or grows and a slow pulse while it is up. Reduced Motion (`GuiService.ReducedMotionEnabled`) turns both off. The
wheel's `CanvasGroup` margin is `NotifyBadge151.Margin` (12 px, was 4) and the button keeps its screen position; the dots are fully inside their tab; the DAILY badge is screen-safe. It is used by
the INDEX button, the hub's alert, the tab dots and the DAILY button / tabs (the identical badges in `DailyRewardsClient`); nothing else is restyled.
Measured (`before` on the R150 code: INDEX cut 4.0 px, dot cut 3.0 px on all 8 screens; `after`: 0 px cut by any ancestor on all 8 screens plus 9 daily screens).

## 4. Tests
`sh docs/proposals/R151/tests/run_index_packs.sh <scratch> --existing --mutations`: data 298 checks, UI 106, shape 53, badge 78 (after) and 6 (before = the root cause), daily badge 43, 19 mutants all noticed;
`--existing`: the R137, R138, R148 `index_limited` (216), R140 daily, R151 pack shapes and Verity pouch suites stay green. `R148/tests/test_index_limited.luau` got three small edits: the new PACKS tab is
excluded from the biome tab lists, the source-order check no longer pins the end of the tab list, and the tab dot is compared by name and visibility (its size and position changed on purpose).

## 5. Studio checklist
1. Open the Index on a phone (portrait, landscape) and a computer: the orange PACKS tab is first; tap it; the key line and the PACK SIZES block show; scroll: every card shows a picture (a short
   delay for the ones scrolled in is fine), name, chips, spawn and drops; tap a card: EVERY SEED opens and a second tap closes it; switch to a biome tab and back.
2. The pictures are the plain pouch, not a shape variation, whatever the Pack Shape setting says; the Verity card shows a pouch (a beat later at most).
3. INDEX button with a reward waiting: the badge is a whole circle, no flat edge, white ring, shadow, centred number; it pops in when the count grows and pulses; with Reduced Motion on it neither
   pops nor pulses. Same for the "!" on the MENU button, the red dots on the tab, and the DAILY button badge (not touching the top of the screen on a phone with a notch).
4. Nothing else in the wheel moved: the MENU wheel buttons are where they were.
