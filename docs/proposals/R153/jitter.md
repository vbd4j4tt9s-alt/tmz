# R153: every jittery effect, made smooth

Owner: "fix all jittery type effects that are in the game like mutation and what not".

Base: R152 as installed (`d73905e`). `Config.Version` is unchanged, the load guard is still line 1 of every client script, no gameplay-frozen
file changed (R151 `frozen.sha256`, the keeper-frozen lists).

What made things jitter, in this game:

- **Stepped updates.** A lot of client motion was written at 10 / 12 / 15 / 20 / 30 Hz (a cost saving). On a 60 or 144 Hz screen the thing
  then holds still for a few frames and jumps: it reads as stutter. Now visible motion is written every drawn frame; the saving is kept where
  nothing is seen (off screen, far, over a count budget) instead of in the update rate.
- **The wrong half of the frame.** Followers written in Heartbeat (after physics) are drawn a frame later than the camera's picture of what they
  follow. Now every follower is drawn in RenderStepped, or rides an attachment / a smoothed frame.
- **Raw network positions.** A keeper's root is moved by the server and arrives in packet steps (no engine interpolation). The keeper's body was
  already drawn from a smoothed frame (KeeperMotion); things hung on the raw root (the speed sign, The Darkened's whole body) stepped with
  the packets.
- **Snapping values.** A colour cycle that blended a colour with itself, colours / fades quantised to a few levels, a size written every other frame.

## The effects

| Effect | Why it jittered | Fix |
|---|---|---|
| Mutation / weather effects on items (drips, frost, arcs, Mech scanner) (`ItemCosmetics`) | items in the world stepped at 20 Hz (10 Hz low), on Heartbeat | every frame in RenderStepped; the selection (on screen, 180 studs, 96 / 240 parts) is the budget |
| Pack mutation glow / plant + fruit rainbow (`MutationHighlights`) | (checked: already RenderStepped and clock-driven) | none needed |
| Track packs: hover, Gold / Diamond mutation halo, rarity rings, rays, orbits, glints, storm arcs (`SeedPackRender`) | hover 30 Hz (20 low) within 240 studs; details 30 Hz (20 low) | hover every frame on screen within 240 studs, details every frame for the detailed packs (8 / 3 low) |
| Held / loose seed auras and the pack reveal in the world, incl. the onlookers' charge motes at the bag's mouth (`SeedPackClient`) | its RenderStepped ran only at `SeedMotion.UpdateInterval` (30 Hz) | every frame (12 auras, 6 detailed, as before) |
| Held fruit: jaw / bells / idle sway (`HeldHarvests`) | joint transforms changed at 20 Hz, Heartbeat | stepped every frame in RenderStepped (6 fruits / 900 parts) |
| Runner ground ribbons, idle aura shards, prints' fades (`RunnerTrailClient` / `RunnerTrailEffects`) | 20 Hz on Heartbeat (far runners every other tick on low); fade tolerance .04 | every frame in RenderStepped; ground raycast cached for `Rules.Interval` (same casts / s), the ribbon slides on that plane; tolerance .01 |
| Volt boot coils (`RunnerBootFx`) | four brightness steps at 20 Hz | continuous glow, written when it moves 1/250 |
| Trail aura head pieces, veil palette, ribbon sheen (`RunnerTrailAura` / `RunnerTrailAuraFx`) | shimmer 12.5 Hz, palette / sheen 10 Hz, Heartbeat | every frame in RenderStepped for full-detail runners |
| Aurora halo colour flow (`RunnerTrailArt.Cycle`) | the cycle blended each colour with itself: held a colour, snapped to the next every 2.2 s | blends into the next colour |
| Carry nameplate (`CarryNameplate84`) | (checked: a BillboardGui on the root, world offset: attached) | none needed |
| Keeper speed signs (`KeeperSpeedLabels`) | hung on the server root (packet steps) while the body glided | hang on `KeeperFollow153`'s anchor, moved with the smoothed body in the animator's batch |
| Keepers 160-350 studs (`CosmeticBudget.KeeperDue`) | awake, on screen: posed at 30 Hz (20 low) | every frame; asleep / off screen keep the slow rates |
| The Darkened (`VeiledEventClient81` + `VeiledKeeper81.ClientFrames`) | its body was posed on the raw root (packet steps) | posed on a KeeperMotion-smoothed root; drives its sign anchor too |
| Void packs in the world and their effects (`VeiledEventClient81` + `VoidPackFx`) | 30 Hz (15 Hz low), carried ones' fx only every frame | the packs wearing effects (nearest 1 / 2 / 4 by tier, 160 studs) every frame; farther ones keep the tick |
| Hub showcase spin (`HubDisplayClient`, one line) | 30 Hz on tier 2 (R152 fix B6) | every frame on every tier; out of view only the core moves (ViewCull152, as before) |
| Void giveaway pack (`VoidGiveawayClient152`) | 30 Hz on tier 2 and below (R152 fix B5) | every frame while in view on every tier; out of view tier 2 keeps 30 Hz with the skipped time |
| Mystery pedestal sign (`MysteryPackClient`) | (checked: hung on the static PackAnchor, offset measured in the pack's own frame, the spin is per frame) | none needed |
| Verity's bounce (`VerityVoice` / `VerityClient`) | the hop followed a noisy PlaybackLoudness that changes every few frames: it jumped with each reading and turned sharply at each peak | the hop follows `Bounce`, a critically damped follower of the level (120 / s up, 200 / s down): smooth speed, about a frame behind |
| Reveal beams for onlookers (`RarePullWorld`) | (already per frame; its mouth point came from SeedPackClient at 30 Hz) | fixed with SeedPackClient |
| Garden: Frostbell bells, rarity effects (fireflies, sparks, glints, fruit effects, glows) (`GardenVisuals` / `PlantEffects`) | the 20 Hz (10 Hz low) animation tick | a RenderStepped pass for plants within 75 studs (45 low) on screen; slow motions (growth, sway, tree drift, jaw, petals, holograms) keep the tick |
| Harvest flights (`PlantGrowthFx`) | on Heartbeat; the shrink was written every other frame | in RenderStepped; the size every frame |
| Lava glows (`LavaFlow`) | 20 Hz | glows of routes within 160 studs every frame; pools and far routes keep 20 Hz |
| Home marker bob (`HomeMarker`) | Heartbeat, and written when far | RenderStepped; nothing past its MaxDistance |
| Tutorial chevrons (`BeginnerTutorial`) | alpha quantised to 1/10: ten visible steps | 1/100 |
| Button shine sweep (`GuiShine`) | 20 Hz | every frame (16 visible buttons) |
| Rarity card borders (`GardenCardMotion`) | 12 Hz: the radiant gradient turned in ~8 degree jumps | every frame (24 visible cards; static in FastMode / reduced motion) |
| Offline-growth notice rainbow (`OfflineGrowthNotice`) | 30 Hz | every frame |
| Shop product previews (`ShopViewport`) | 30 Hz (15 FastMode) | every frame for 12 visible (4 on tier 2, none on tier 1: a viewport redraws when it moves) |
| Index / harvest / pack previews (`CollectionViewport`, `HarvestPresentation`, `HarvestViewport`, `PackViewport89`) | 20 / 20 / Heartbeat / 30 Hz; the index cards' weather mutation effects too | every frame in RenderStepped; budgets kept (index 6 on tier 2, harvest 4 models on tier 2) |
| Garden upgrade button press (`GardenUpgradeService` -> `InteractionFeedback`) | a server tween, replicated in network-rate steps | the server stamps `PressedAt153`; every client draws the press per frame |

## Looked at and left as they are (nothing moves in steps you can see)

- Already smooth: mutation highlights, the carry nameplate, the mystery pedestal sign and spin, the hub butterflies, the Fruit of the Hour, the
  sale money, the reveal world beams' own loop, keeper effects / Zzz / accents (KeeperMotion's frame), the keyboard track.
- Slow or not motion: lighting fades between biomes (BiomePresentation, 20 Hz writes of a slow fade), weather clouds' cover (WorldEvents),
  rain / snow tiles (WeatherWorld149: emitters placed on a grid; particles move by themselves), snow patches, biome emitter drift (BiomeWeather:
  acceleration only), the cosmic lettering's stars (12 Hz, well under a pixel a tick), the garden's growth / wind sway / tree drift / jaw /
  petals / holograms (20 Hz, under a pixel a tick near, kept), distant gardens, the gift hover highlight (FruitGiftClient picks a target at 12 Hz),
  text that counts down (HUD notices, world status, signs), track packs past 240 studs (they only turn to face the camera).

## Cost

Everything above is gated by visibility, distance and the existing count budgets; nothing new runs for what is off screen or far. The added
per-frame work, bounded: track packs within 240 studs (a few parts each, one BulkMoveTo), the Void packs wearing effects (1 / 2 / 4 by tier),
keepers 160-350 studs while awake and on screen (7 at most), the runner step for 8 runners (raycasts unchanged), the garden's near plants'
bells and effects, the UI previews within their caps (fewer on tier 2). On tier 2 (phones) the hub item and the giveaway pack now move every
frame while in view (one BulkMoveTo each: 150 / 190 parts). R152's savings that touch nothing visible are kept: ViewCull152 holds, write-on-change
caches, off-screen keeper rates.

## Round 2 (owner, again: "reduce jitter in effects")

Merged first: the release branch at `baf5eea` (treadmill / popups / belt, the hub avatar's client dance, pack-opening skip, hotbar). Round 1's
leftovers in those files, and a fresh pass over what was merged since:

| Effect | Why it jittered | Fix |
|---|---|---|
| Speed popup fan (`SpeedGainPopup` `takeField`) | hung on the Head, which bobs with the treadmill run: the whole fan shook | hangs on the HumanoidRootPart at the head's height (`StudsOffsetWorldSpace`) |
| Treadmill belt arrows (`SpeedGainPopup`, the V134 block) | moved on a 1/30 s tick (1/20 FastMode) | every frame on a near belt in view (TreadmillFx's generous cone); out of view the old tick, with the time each belt is owed; emitters on the tick |
| Belt pattern, spinners, pulses, hue, lights (`TreadmillFx` `Controller:Step` -> `Scroll` / `Animate`) | a 1/30 s tick (1/20 below tier 3) | every frame for the belts the cull passed (Scrolling: near and on screen; Animated: quality 2+, 90 studs, on screen); offsets still written only when they change |
| Hub avatar cheer (`HubDisplayClient`, a rig whose dance did not load) | joints written at `POSE_HZ` 30 | every frame while the rig is in view (ViewCull152 on its bounding ball); out of view 30 Hz |
| Sky beam fade (`RarePullFx` `Beam:_alpha`) | transparency in 1/32 steps (~.03 a jump on a slow fade) | 1/256 (under one 8-bit level); a sequence is still built only when the step changes |
| Charge motes at the bag's mouth (`RarePullWorld`) | used the mouth SeedPackClient set last: when RarePullWorld's RenderStepped ran first, a frame behind the moving bag | `SetMouth` also takes the bag's part; the mouth is read off it when the motes are drawn |

Looked at and left (no visible stepping):

- `TreadmillAnimation.client.lua` line 7: it steps the run clip's playback CONTROLLER at 30 Hz (`AdjustSpeed` easing, play / stop), not the belt
  (round 1's note was wrong). The engine animates the pose every frame; a speed eased in steps of under 1% keeps the pose continuous. Left as
  it is (the R151 treadmill suite holds the file to `19d05d4`).
- Trampoline mat squash (`HubTrampoline153`): RenderStepped, clock-driven, only while a mat moves. The bounce itself is client physics.
- Bonus roll button (`TreadmillBonusClient`): its effects run on one on-demand RenderStepped, the glow is client tweens; the charging bar fills
  on a 4 Hz tick, 360 s for a full bar: about 0.1 px a tick.
- Hotbar drag ghost: follows `InputChanged` (every pointer move, before the frame is drawn).
- Biome notifier: fade and settle per frame in RenderStepped (the settle snaps to whole pixels by design; the .12 s poll only decides when).
- Gate refresh barrier: static; its caption dots step `. .. ...` by design and the count is text.
- R153 badges: the pop and the halo pulse are client tweens.
- Keeper speed signs: now pinned over each keeper's spawn by the keeper-sign agent (merged at `98bf7fb`; this supersedes round 1's sign row: a
  pinned sign cannot step). `KeeperFollow153` stays;
  `BeastAnimation` and `VeiledEventClient81` still drive its anchors.
- Server: per-frame connections only in the 13 gameplay services (the same list), no tween but MapService's legacy course fade; the merged
  server code moves parts only when it builds or teleports.

Round 2 cost: only what is near and in view, every frame: a belt's arrows (one BulkMoveTo) and pattern layers (one write each), its spinners
(one BulkMoveTo); a posed hub avatar's ~10 joints (only when its dance failed to load); a sky beam's layers build a new sequence when the 1/256
step changes (a few a frame during a fade). Out of view: as before.

- Gameplay-frozen: none needed. The legacy escape course's stage fade (`MapService` `_playCourseTween`, a server Transparency tween tied to a
  collision change) is left on the server.

## Tests

`docs/proposals/R153/tests/run_jitter.sh` (in `tools/tests/run_all_suites.sh`): the real scripts on the mock; what is drawn (read right after
RenderStepped) advances on every frame at 30 / 60 / 144 fps while visible; followers do not move in the physics half of a frame; the server
connects per-frame signals only in its gameplay services and tweens nothing. `JITTER_BASE=d73905e` runs the same checks on R152: every check set
fails there (the stepping is measured, e.g. a Drippy item repeats 59 of 90 frames at 60 fps, the keeper sign 64 of 90; 21 / 42 / 20 / 29
failed checks in keepers / misc / runners / world).
Updated suites: R128 follow, boots_R117 (RenderStepped connection), trails_R117 (frame driver), R149 growth fx (shrink every frame),
R151 hub client (tier 2 every frame, 30 / 144 fps), R152 giveaway client (tier 2 in / out of view, 30 / 144
fps, two mutations), R152 keepers (R153's two keeper files on its list), R149 Verity lip sync (one pause window starts 20 ms later: the hop
trails the level by a frame), boots_R117 (the coil glow's write bound), tools/tests/test_tutorial (chevron fade steps).
Round 2: `test_jitter_round2.luau` (28 checks; `JITTER_BASE=baf5eea`: 20 fail). R151 `run_speed_popups.sh` / `run_treadmills.sh` compare
SpeedGainPopup with the two R153 jitter edits put back (`undo_jitter153.py`: each must be found exactly once), so the belt block's sha and the
popup's base check still hold everything else; R151 `speed_popups_world.luau` `PW.fieldOf` and `test_speed_popups_client.luau` look for the root;
R153 `test_belt153.luau`: one write a frame per layer (was one a tick), the biggest step of a frame <= .06 (was .16); R151 `test_hub_client.luau`:
the posed avatar's cheer moves on every frame in view at 60 / 144 fps.
