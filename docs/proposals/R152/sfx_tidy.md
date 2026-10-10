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

## 3. Hotbar reliability: one press, one equip

Owner: "players have to click on something multiple times to equip it". I could not play-test in Studio, so this is from tracing the whole path (click / tap / key -> `Hotbar.client.lua` -> `Humanoid:EquipTool` or `UnequipTools` -> server `Tool.Equipped` -> `ChestService:_holdPack` -> character) and from the mock. Each cause below fails a new test on the R151 code and passes now. Not mine, done by the coordinator: the load failure (InteractionAudio requiring SoundTiming before it replicates) and moving the CoreGui Backpack disable.

**Client (`Hotbar.client.lua`)**

| # | Cause | Fix |
|---|---|---|
| 1 | Any press that moved over 12 px was a **drag**: it ignored `Activated` for 0.2 s, then dropped the item on the slot under the pointer. A press that stayed on its own slot (a phone tap that rolls, a trackpad click that slides, a Bag-card tap) moved nothing, so the click did nothing. It only worked when the engine delivered `Activated` before the release. | A press is a drop only when it **ends on another slot**. Ending on the pressed button is a click however far it wandered. |
| 2 | `Activated` can be missing (a wobbly tap in the Bag's scroll frame) or late. | The click runs **once per press**: `Activated` and the release both ask, the first wins (tested in all three orders, mouse and touch). A Bag card the grid scrolled under the finger is a scroll, not a click. |
| 3 | A drop in the 6 px gap, at the bar's edge, or after a fast flick (the engine reported only press and release) landed nowhere. | The nearest slot within 4 px takes the drop; the release position counts when no move was reported. |
| 4 | After every drag the next click was ignored for 0.2 s. | The lock-out is gone. |
| 5 | A slot pointing at a tool that no longer exists (picked up, replaced, destroyed with the Backpack on respawn, the frame before the refresh) sent `EquipTool` to a dead tool: nothing happened. | `equip` resolves against what exists now (refresh first) and never calls a dead tool. |
| 6 | A touch the system cancelled never ends. A later mouse release was taken for its end and clicked the old slot. | A press ends only with its own release (touch with that touch, mouse with the mouse button); the click fallback is limited to 6 s. |
| 7 | Number keys did nothing while the Bag was open. | They equip (and close the Bag); other menus still block them. |
| 8 | One odd item or picture that raised inside `refresh` left every later slot, the Bag and new items stale, so clicks hit things that no longer matched. | Each item, each slot, the Bag grid and the picture cache are guarded: the failure is skipped and warned once (`[R152] Hotbar: ... skipped`). |

**Server (`ChestService:_holdPack`)** threw a held pack back into the Backpack although nothing was wrong:

| # | Cause | Fix |
|---|---|---|
| 9 | A quick unequip + re-equip while the pack's chip-bag shape was loading (R151 known issue, up to 2.5 s) started a second hold of the same pack. The first finished and held it; the second saw that opening and bounced the pack out of the hand. | A hold for the pack that is already held does nothing. |
| 10 | Equipping pack B while pack A is in hand: if B's `Equipped` is handled before A's `Unequipped` has finished A's opening, B saw A's opening and bounced. | A's stale opening (not committed, pack no longer in hand) is finished, then B is held. A committed opening (reveal playing) still wins. |

**Left as it is (by design or out of scope), so the owner knows:**
- A pack cannot be held while carrying a stolen pack, running a chase, or while another pack's reveal is playing; it goes back to the Backpack with no message. A short notice there would make it clear.
- The first equip of a pack whose shape is not baked yet shows nothing in the hand for up to 2.5 s (R151 design), so a second click unequips it. Building the default shape at once and swapping when baked would fix it.
- Clicking the held item unequips it (toggle), as in Roblox's own hotbar.
- Planting consumes the held seed; the next seed of the stack needs a click.
- After a respawn the hotbar is empty for about 0.3 s until the server hands the tools back, and the slot order restarts in arrival order.

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
- `test_hotbar_click`: one press is one action (equip, unequip, move) for mouse and touch, in all three event orders; rolled clicks; first-try drops (empty, swap, gap, edges, shovel slot); the Bag; number keys; silence; one failing item or picture does not freeze the hotbar.
- `test_hotbar_stress`: a seeded random run (600 steps, about 2300 checks): clicks and taps (clean, rolled, flicked), keys, L1 / R1, slot moves, Bag opens, card clicks and drops, items added and removed (also the frame before a click), the held item destroyed, cancelled presses and respawns. Every action must take effect exactly once, never on a dead tool, and the hotbar must equal a model of what the player did; a probe click every 20 steps proves nothing is stuck. I also ran 12 other seeds of 900-1500 steps: all pass. An optional `stress_cfg.luau` returning `{Seed=,N=}` next to the test runs other seeds.
- `test_hold_race`: the server half on R151's pack harness (causes 9 and 10, plus what must not change: a committed opening, R139's fake, carrying).
- `test_silence`: treadmills silent; the treadmill client scripts make no Sound; InteractionFeedback keeps its real cues.
- `test_chase_trim`: the special track gets 22 s .. end regions (also when created later, id set later, length arriving later); other music untouched; with the real `BackgroundMusic` running a secret keeper chase the position never drops below 0:22.
- `sh run.sh <dir> mutate` runs the click test, the stress test and the hold-race test on the R151 code and expects each to fail (24, 25 and 5 failed checks).
- Updated expectations: R150 `test_hotbar` / `test_inputs` now assert silence; R135 `test_market` asserts no tube and keeps the plate and prongs.
