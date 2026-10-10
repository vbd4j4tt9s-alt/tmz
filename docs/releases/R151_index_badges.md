# R151 polished Index notification badge (and the default-pack-shape plumbing)

Owner, live: "The notification for index like red the red circle and + .. has to be polished at it looks really low quality and cut out wrongly". Picture: `docs/proposals/R151/index_badges.png`
(before | after, zoomed; an approximation drawn from the real ChestIndex tree under the Roblox mock, not a Studio screenshot).
Tests: `docs/proposals/R151/tests/run_badges.sh` (`--existing` also runs the older Index / daily / pack-shape suites, `--mutations` breaks the code 13 ways and expects a failure each time).

A PACKS tab for the Index was built for this change as well and then scrapped by the owner ("scrap the pack index"): the Index opens on the same tab as before, with the same tabs in the same
order and the same layout. Nothing of it is left (no tab, no `IndexPackData151` / `IndexPacksView151`).

**Installer:** one new ModuleScript (in `src/MANIFEST.tsv`, ReplicatedStorage): `NotifyBadge151`. Changed scripts: `ChestIndex.client`, `DailyRewardsClient.client`, `HudLayout`, and for the
default pack shape (below) `ItemPictures`, `SeedPackVisuals`, `SeedPackRenderer`, `VerityPackArt`, `VerityPouch151`. Installers (`docs/releases/*install*`) are NOT rebuilt here. No server change,
no saved-data change, no remote, no odds / rules / config change.

## 1. The badge
Root cause of the cut-out badge, measured on the R150 code (`test_indexbadge.luau`, mode `before`): the INDEX button sits in a `CanvasGroup` (`HudLayout.Navigation`) that is only 4 px bigger than
the button on each side, and the old badge hung 8 px out of the button's corner (its white ring included), so the group sliced 4 px off the top and the right of the circle: the flat edges. The tab
dots hung 3 px out of their tab into the tab row's `ScrollingFrame`, which clips: 3 px cut. The DAILY badge hung over the top edge of the screen on phones.
Fix: `NotifyBadge151` is ONE component for every badge: a perfect circle (`UICorner(1,0)` + `UIAspectRatioConstraint`), red gradient, white ring (`UIStroke`, inside the holder), soft shadow and glow,
the count centred in bold `TextScaled` text (`""`, the count, `9+`, `!`), a pop-in when it appears or grows and a slow pulse while it is up. Reduced Motion (`GuiService.ReducedMotionEnabled`) turns
both off. The wheel's `CanvasGroup` margin is `NotifyBadge151.Margin` (12 px, was 4) and the buttons are re-offset by the difference, so every button keeps its screen position; the tab dots are
fully inside their tab; the DAILY badge is screen-safe. It is used by the INDEX button, the hub's MENU "!", the tab dots and the DAILY button / tabs (the identical badges in `DailyRewardsClient`);
nothing else is restyled.
Measured (`before` on the R150 code: INDEX cut 4.0 px, dot cut 3.0 px on all 8 screens; `after`: 0 px cut by any ancestor on all 8 screens, and on the 9 DAILY screens).

## 2. Default pack shape (plumbing, no caller yet)
R151's pack shape variations (`PackShapes151`) are skipped for a picture whose proxy carries the attribute `DefaultPackShape`: `ItemPictures.Key` adds `|Plain` to the cache key (a plain picture and a
shaped one of the same pack never share an entry), `SeedPackVisuals.Bag(..., defaultShape)` marks the bag and `SeedPackRenderer` skips `PackShapes151.ForBuild` for it. The Verity pack, whose pouch
is baked by the server, gets a plain neutral pouch baked on the client (`VerityPouch151.RequestPlain / PlainTemplate`, falling back to the server's pouch while it loads). Nothing in the game sets the
flag yet; a catalogue or shop picture that must show the plain pouch sets it on its picture proxy. `test_defaultshape.luau` covers it (42 designs, the modes of `/test packshape`, Void / Mech,
Verity, the build path).

## 3. Tests
`sh docs/proposals/R151/tests/run_badges.sh <scratch> --existing --mutations`: badge 78 checks (after) and 6 (before = the root cause), daily badge 43, default shape 51, 13 mutants all noticed;
`--existing`: the R137, R138, R148 `index_limited` (216), R140 daily, R151 pack shapes and Verity pouch suites and the R151 static checks stay green. `R148/tests/test_index_limited.luau` has one small
edit: the tab's red dot is compared by name and visibility (its size and position changed on purpose; `test_indexbadge.luau` holds its geometry).

## 4. Studio checklist
1. Open the Index on a phone (portrait, landscape) and a computer: it opens on the FOREST tab, with the same tabs in the same order and layout as before.
2. INDEX button with a reward waiting: the badge is a whole circle, no flat edge, white ring, shadow, centred number ("9+" past 9); it pops in when the count grows and pulses; with Reduced Motion on it
   neither pops nor pulses. Same for the "!" on the MENU button, the red dots on the tabs (fully inside the tab) and the DAILY button badge (clear of the top of the screen on a phone with a notch).
3. The MENU wheel buttons are where they were (the `CanvasGroup` margin grew from 4 to 12 px and the buttons were re-offset to match).
