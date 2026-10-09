# R158 status (final changes round), in progress

## Owner rules from now on (10 Oct)
- **The PC HUD in the owner's screenshot is THE layout for every non-phone device** (all PC window sizes, consoles): same pieces in the same
  places; small windows scale it rather than rearrange it.
- **Mobile (phones, tablets): the current layout is OK and frozen.** Nothing moves there.
- **Portrait: no more work** ("its a waste of time").
- "menu can also be higher" (PC): preview in `hud_lock/` (A / B), not built yet.

## Hotfix R157b (bugs, being built)
- Title screen loaded InteractionAudio before the game had loaded; AudioMixer was missing -> the module crashed and took the HUD with it.
- Desert: track music switched to base music.
- Title tips too jittery.
- Remove the "THE TRACK" sign on the gatehouse.
- Mech packs with a full Bag: buttons say Bag full, a press says BAG FULL! MAKE ROOM FIRST.
- Quieter Output: tree models that can't load (not the owner's assets), the item-picture loading note.

## Previews for the owner (not built)
- Track walls per biome, outer track designs, base wall tops (`docs/proposals/R158/design/`).
- PC HUD lock + MENU higher (`docs/proposals/R158/hud_lock/`).
