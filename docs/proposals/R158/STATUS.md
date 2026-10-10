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
- Track walls per biome, outer track designs, base wall tops (`docs/proposals/R158/design/`).
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
