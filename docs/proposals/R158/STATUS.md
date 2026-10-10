# R158 status (final changes round), in progress

## Owner rules from now on (10 Oct)
- **The PC HUD in the owner's screenshot is THE layout for every non-phone device** (all PC window sizes, consoles): same pieces in the same
  places; small windows scale it rather than rearrange it.
- **Mobile (phones, tablets): the current layout is OK and frozen.** Nothing moves there.
- **Portrait: no more work** ("its a waste of time").
- "menu can also be higher" (PC): owner picked **A** (MENU centre at 1/3 of the height; balances full size; the PC layout scales down on small windows,
  as in `hud_lock/pc_scale.png`). Owner: MENU must not get too small: shrinking is ok, but it has to stay close to its
  original size so it doesn't look off (so MENU / the wheel get a size floor, e.g. never under ~85% of the 1920 x 1080 size).
  **Built (10 Oct, `hud_lock/hud_lock.md` "Built", pictures `hud_lock/built_menu.png` and `built_scale.png`):** the PC HUD is the 1920 x 1080 arrangement drawn at
  min(1, w / 1920, h / 720); MENU a third of the way down, never under 85% of its size (54.4 px of 64); balances, hotbar, bars and status stay in their
  places and shrink together; phones and tablets are byte-for-byte as before (`R158/tests/run_hud158.sh`).
  **Review follow-ups (10 Oct, `hud_lock/hud_lock.md` "Review follow-ups"):** small-text minimums are real px under the scale (names, held name, pity words), BONUS ROLL sits 7 px
  over the bars at every window, menus end 15+ px over the slots, the SKIP corner's 80 px is real px, `pcLayout` no longer reads `L.PcScales`, `B.Extent` lost its unused `k`.

## Hotfix R157b (bugs, being built)
- Title screen loaded InteractionAudio before the game had loaded; AudioMixer was missing -> the module crashed and took the HUD with it.
- Desert: track music switched to base music.
- Title tips too jittery.
- Remove the "THE TRACK" sign on the gatehouse.
- Mech packs with a full Bag: buttons say Bag full, a press says BAG FULL! MAKE ROOM FIRST.
- Quieter Output: tree models that can't load (not the owner's assets), the item-picture loading note.
- DAILY: no white tile behind the mystery pack (quests and login days).
- DAILY: the "TODAY" tag in white letters with a black outline (owner: barely visible).

## Previews for the owner (not built)
- Track walls per biome, outer track designs, base wall tops (`docs/proposals/R158/design/`): **BUILT, see below.**
- PC HUD lock + MENU higher (`docs/proposals/R158/hud_lock/`).

## Next, after this round (owner)
- **Bats as a whole:** polish the swing animations and the hit effects (the owner sends a reference video), and make the hitbox consistent,
  especially against fast-moving players. Code: `BatService.lua`, `BatHitbox.lua`, `BatSwingPose.lua`, `BatConfig.lua`, `BatArt.lua`, `BatClient.client.lua`.

## Answered, no change
- Void / Verity packs not moving the event pity: the owner's Darkened was started with a test command and the boots were /test boots, so those
  were TEST opens, which R155 leaves out of the pity on purpose. Owner: "its fine no worries its ok no fixes are needed". Real packs already count.

## Stopped by an interrupt (10 Oct), work saved as WIP commits on their branches (unfinished, untested)
- worktree-agent-a8a50c2056188b487 (title / audio crash), -af021d48f7218dd80 (Desert music), -a4e5c7a2dc7c33ff6 (sign, Mech BAG FULL, Output,
  DAILY tile), -a9273fb3e3cd05eb1 (track / base wall design), -a5bed8e4860653d0b (HUD lock + MENU previews), -a0a3fa0f33470f2b1 (Mech skip tests).

## HUD lock: built (merged b8c13c1), review follow-ups in progress
- Review (read-only): no bug in the scaling. Follow-ups being fixed: text minimums in real px under the HUD scale, BONUS ROLL gap, menu gap
  above the hotbar, SKIP zone minimum, PcScales in the cache key.
- For the owner to check in Studio (the mock can't): (1) with chat open, does the open MENU wheel sit under Roblox's chat window (top-left)?
  The wheel top is now ~207 px below the top bar at 1920 x 1080; (2) UIStroke outlines and text size limits on a small window (e.g. 1280 x 720);
  (3) touchscreen PCs (TouchEnabled) still get the phone layout, as before (the "mobile" rule is decided by TouchEnabled).

## Owner decisions (10 Oct, morning)
- **Bats:** build the plan in `bats/` (instant swing, client sweep + server lag-compensated check, the flat hip-height swing, trail on the strike, hit
  burst + sparks + short hit-stop). Choices: **no camera shake for the hitter, no "SMACK!" word**, trail **white** (default).
- **Walls:** **base walls A** (stone caps), **and** the per-biome track walls **and** the outer track backdrops as in `design/`.
- These go in R158 (after R157b).

## Walls, outer track and Lava: BUILT (10 Oct, in the R158 build; details in `design/design.md` "Built" and `design/outer_track_assets.md`)
- **Track walls** per biome: 1,481 parts (design 1,747 at most), full version everywhere, details from a fixed seed per wall (owner: no repeated look). **Base walls A** (stone caps, five close shades): 261 parts.
  **Ground** outside the walls: 15 slabs. Built by `TrackWalls158` (data `TrackWallSpecs158`), called from `MapService.new` after `HubDecor151`. The wall parts over the refresh cover (502) are hidden while the track refreshes.
- **Outer track = models, not parts** (owner: "just place the stuff"): `OuterTrackAssets158` (keys, ids, spots), `OuterTrackLoader158`, `OuterTrackModels158` (the owner's pyramid 9981304 as data, his dark mountain cut from 1,532 to 280 blocks a copy, the snow hills' layout).
  Sources in order: a model dragged into `ServerStorage.OuterTrackAssets158` (named by the key), the owner's files built in (pyramid, dark mountain; the volcano and snow hills by mesh id through `CreateMeshPartAsync`), the game's own models (oaks, jungle trees, ice trees, crystals), an id. Waiting for models: the Jungle temple and cliff, the Desert dunes and obelisks, the Crystal mountains, the Storm tower / lightning / end mountain.
- **Lava** (owner: "remove the streams entirely", "and the lava pool"): the river, the two side pools, the three channels, the molten crater and the pond's "Pool shore" are gone (762 parts; none was a hazard), the owner's volcano replaces the old cone at its footprint (`LavaVolcano158`),
  `LavaFlow.client.lua` is idle with no streams. The keyboard fills the floor where the lava was.
- Tests: `R158/tests/run_walls158.sh` (line 6 of `run_all_suites.sh`); changed on purpose: `R149/tests/keyboard_place.luau`, `R156/tests/pyramid_map156.luau`.
- For the owner to check in Studio: phone frame rate (Forest, Storm Peaks), night / cloudy glow, the volcano (size, texture, mouth), the snow hills, the refresh cover, the keyboard in the Lava biome.
