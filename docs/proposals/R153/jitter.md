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

## Left for other agents' files (not changed here)

- Treadmill belt (treadmill agent): `TreadmillAnimation.client.lua` line 7 steps the belt at 30 Hz on Heartbeat; `TreadmillFx.lua` `Controller:Step`
  (`interval=... 1/30 or 1/20`); `SpeedGainPopup.client.lua` belt-arrows half (`if elapsed<(low and 1/20 or 1/30)then return end`, held to
  its base by the R151 treadmill suite). Same fix: every frame in RenderStepped while near, keep the distance gate.
- Hub avatar (hub display agent): `HubDisplayClient.client.lua` line 30 `POSE_HZ=30`: the static avatar's cheer pose is written at 30 Hz.
  Edited here: only line 184 (`itemHz=ITEM_HZ`, the showcase item).
- Pack opening (pack-opening agent): `RarePullFx.lua` `Beam:_alpha` quantises a layer's fade to 1/32 (cached NumberSequences): fine but visible
  on a slow fade; `RarePullWorld` steps before SeedPackClient's mouth update some frames (one frame behind the bag).
- Speed popups (popup agent; not changed here: the R151 treadmill suite holds `SpeedGainPopup.client.lua` to its base outside the agent's 2x
  edits): `takeField` hangs the field on the Head (`field.Gui.Adornee = head`), and the head bobs with the fast treadmill run, so the whole fan
  shakes. Fix: `local root = head.Parent and head.Parent:FindFirstChild("HumanoidRootPart")`, `field.Gui.Adornee = root or head`,
  `field.Gui.StudsOffsetWorldSpace = root and Vector3.new(0, head.Position.Y - root.Position.Y, 0) or Vector3.zero`; then R151
  `speed_popups_world.luau` `PW.fieldOf` and `test_speed_popups_client.luau` (the adornee checks, the reset check) look for the root.
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
