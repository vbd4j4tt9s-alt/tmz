# R152: sound tidy-up, hotbar double-click, fruit-of-the-hour tube, secret keeper chase music

Owner after R151: "remove this hollow cylinder at the fruit of the hour place ... i have to click twice ... for the hot bar movements there doesn't need to be a sound effect, same for the treadmill ... remove that whirring sound effect for all of them ... remove redundant sound effects, tidy up".

The "whirring" is the **Equip cue** (`InteractionAudio` key `Equip`, asset 99675704394731). R150 played it on every hotbar equip and again when you stepped onto a treadmill. Nothing else in the treadmill code ever made a sound (no belt loop, no step or tick sound; checked by grep and by a test).

## 1. Removed sounds

| Action | Script | Was |
|---|---|---|
| Equip / unequip: keys 1-0, L1 / R1, slot click, Bag card click | `Hotbar.client.lua` (`equip`) | Equip |
| Click on an empty slot | `Hotbar.client.lua` | Bubble04 |
| Moving an item to another slot (drag) | `Hotbar.client.lua` | Bubble04 |
| Stepping onto a treadmill | `InteractionFeedback.client.lua` | Equip |
| A prompt's hold beginning (take pack, harvest, mystery pack...) | `InteractionFeedback.client.lua` | Bubble04 (the finish already has its own cue, so it was two sounds for one action) |
| Selecting a plant (click, tap, L3) | `PlantInspection.client.lua` | Bubble04 |

- There were **no hover sounds** on the hotbar or the Bag; a test now hovers and focuses every slot and hears nothing.
- Slots and Bag cards keep `ButtonSound=false`, so `ButtonHighlights` adds no click either. Equipping from the Bag still mutes the Bag's own close click, so that is silent too.
- The shop's equip still plays Equip (`EconomyClient` line 401), the only place left that uses it (see candidates).

## 2. Kept, candidates the owner may want removed

Nothing here is changed. Tell me which to drop.

- **Shop equip** (`EconomyClient:401`): the same Equip cue as the removed one, on Boots / Trails equip.
- **Generic button click** (`ButtonHighlights`, Bubble04 on every button). This includes the Bag's filter cards, rarity filter and options; the Bag's open / close (MenuClick / MenuClose); and the Settings slider previews (`SettingsClient:60`).
- **Treadmill bonus roll** (`TreadmillBonusClient`): the strip tick (up to 30 a second, rising pitch, MenuClick file), the "ready" pops, and the KaChing / GemClaim at the result. This is the reward roll, not the treadmill; the tick may sound like a whirr.
- **Coin ticks** (`SaleMoneyEffects:102`): Bubble06 for each coin that reaches the wallet, on top of the sale's KaChing.
- **Upgrade press** (`InteractionFeedback`): UpgradeClick, then KaChing or Denied, two sounds per press.
- **Pickup cues**: Bubble06 for a pack taken (`InteractionFeedback`), the mystery pack (`MysteryPackClient`) and a harvest landing in the bag (`Hotbar`).
- **Tutorial**: welcome click and one pop per step (`BeginnerTutorial`).
- **Ambient beds**: `BiomeAmbience` (birds, leaves, wind, crystal hum, low rumble; Ambience slider) and the three layers near the gardens in `HubLife151.client.lua` (volumes .006-.014).
- **Chase layers**: chase alarm, heartbeat loop and deposit chime (`ChestRunAlert`), the close-keeper ping every 0.8-1.25 s, keeper voices, hit snaps, sleeping snore loop, the chase music.
- **Track reopening**: the 3-2-1 ping per second (`TrackRefreshSky`) plus the horn (`RefreshHorn`).
- **Frostbell jingle** (`FrostbellMotion`, `HeldHarvestRig`): a 3D bell chime on each swing cycle.
- **Roblox's own Jump / Land sounds**: `QuietFootsteps87` mutes only Running / Walking / Footsteps.
- **In files I was told not to touch**: the pack-click Bubble04 per accepted click (`PackOpeningFeedback:93`), the hub display chime (`HubDisplayClient:203`), the keeper pings and voices (`KeeperNearAlarm`, `Keeper*`).
- Kept on purpose: purchases, steals / catches, keeper hits, rewards and claims, notifications, weather, music, the keyboard clicks, and the pack opening / pull reveal.

## 3. Hotbar: "i have to click twice"

I could not play-test in Studio. This is from reading the code and from the mock; each cause below fails the new test on the R151 `Hotbar` (24 failed checks) and passes now.

**Cause.** R112-R151 treated any press that moved more than 12 px as a **drag**. A drag ignored the button's `Activated` for 0.2 s, then dropped the item on the slot under the pointer. For a press that stayed on its own slot (a phone tap that rolls, a trackpad click that slides, a Bag-card tap the scroll frame half-takes) that drop moved nothing, so the click did nothing and you had to click again. Other ways a first try was lost:
- a drop that landed in the 6 px gap between slots, or a few px above or below the bar, landed nowhere;
- after any drag, the next click on a slot was ignored for 0.2 s;
- number keys did nothing while the Bag was open until you closed it.

Whether the click or the release arrives first is up to the engine; the old code only worked in one order.

**Fix** (`Hotbar.client.lua`):
- A press is a **drop only when it ends on another slot**. Ending on the pressed button is a click however far it wandered. A Bag card the grid scrolled under the finger is a scroll, not a click.
- The click runs **once per press**: `Activated` and the release both ask, the first wins (Activated first, release first, or no Activated at all).
- A drop lands on the **nearest slot within 4 px** of a slot, gap and edges included. The 0.2 s lock-out is gone. The shovel slot still refuses a drop, with no side effects.
- A number key equips while the Bag is open (other menus still block it).

## 4. Fruit of the Hour

`MarketLayout.Pedestal`: removed the **Projector beam**, the translucent neon cylinder (R133) that looked like a hollow glass tube around the fruit. Its flat bottom cap also sat exactly on the glow plate's top (z-fighting); that is gone with it.

Kept: the stone / teal / gold pedestal, the four gold cradle prongs (the slanted rods), the fruit and its light. The **white square** is the "Cradle glow" plate; it dates from R132 (before the tube) and is not for the tube, so it stays. If you also want it gone, it is one line.

## 5. Secret keeper (The Darkened) chase music

Owner, last word: skip to 0:22 and play to the end; every loop restarts at 0:22. New script `ChaseMusicTrim152.client.lua` (config `Skip=22` at the top); `BackgroundMusic.client.lua` is **not** edited, because the live copy was hand-edited. Add it to the place as a LocalScript in StarterPlayerScripts (it is in `src/MANIFEST.tsv`).

It finds every Sound in SoundService whose SoundId contains `127003062753525` (BackgroundMusic parents it there as `ChestChaseSpecialTrack84`), now and as sounds appear or change id, and sets `PlaybackRegionsEnabled`, `PlaybackRegion` and `LoopRegion` to 22 s .. the end of the file (an open end until the length loads, then the exact length). A file shorter than 23 s is left whole. No other music is touched.

What I found in `BackgroundMusic`:
- It starts a chase with `TimePosition=0; Play()` (and `Resume()` after a pause, which keeps the position). It fades `Volume` only, then pauses. Its once-a-second recovery only restarts a track that is **not playing**, and a looping region never ends, so nothing fights the region.
- Readiness uses `TimeLength > 2` (the whole file), which a region does not change.
- I could not confirm that the engine clamps `TimePosition=0` up to the region start. So the script also moves a playing track below 22 s up to 22 s on `Played` and every frame. If the engine does not clamp, there may be a one-frame blip of the song's first instant at the start of a chase; the owner should listen for it in Studio.
- Also check in Studio that an open-ended `PlaybackRegion` before the length loads is accepted (it is wrapped in `pcall` and re-applied when the length arrives).

## 6. Tests

`docs/proposals/R152/tests/run.sh` (picked up by `tools/tests/run_all_suites.sh`):
- `test_hotbar_click`: one press is one action (equip, unequip, move) for mouse and touch, in all three event orders; rolled clicks; first-try drops (empty, swap, gap, edges, shovel slot); the Bag; number keys; silence.
- `test_silence`: treadmills silent; the treadmill client scripts make no Sound; InteractionFeedback keeps its real cues.
- `test_chase_trim`: the special track gets 22 s .. end regions (also when created later, id set later, length arriving later); other music untouched; with the real `BackgroundMusic` running a secret keeper chase the position never drops below 0:22.
- `sh run.sh <dir> mutate` runs the click test on the R151 Hotbar and expects it to fail.
- Updated expectations: R150 `test_hotbar` / `test_inputs` now assert silence; R135 `test_market` asserts no tube and keeps the plate and prongs.
