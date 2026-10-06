# R152 performance patch

Owner: "do a performance patch after everything is done make sure performance patch doesn't change look and feel or unexpectedly revert the change
that u did" / "Things not only have to look good we also need a performance patch after that doesn't undermine or affect quality of these features".

Base: the R152 candidate `1e7dced` (the release branch's later server fixes for R151's known issues, `52b6672`, are merged in; they change no
visuals, and the fingerprints are still taken against `1e7dced`). Nothing the player sees or hears changed; `Config.Version` is unchanged; the load guard
is still line 1 of every client script.

## How it was checked

`docs/proposals/R152/tests/run_perf152.sh` (in `tools/tests/run_all_suites.sh`) builds the candidate (`git archive 1e7dced`) and this checkout side by
side on the Roblox mock with the real scripts, and fingerprints both: every instance that is drawn, with every property the scripts gave it (class, name,
CFrame / Size to 1e-4, colour, material, transparency, reflectance, mesh / texture ids, emitter / beam / light values, GUI text / size / position / ZIndex,
sounds with ids, volumes and their play schedule). `perf152_canon.py` compares the two exactly (siblings in any order). Both sides run on the same mock
(which, for these runs, compares CFrames by value as Roblox does). Covered:

- hub on the owner's place, tiers 1 / 2 / 3, displays empty and with champions: the whole world once, then the moving parts every 4 frames from 7 camera
  poses (looking at the displays, away and back, up, far, back again)
- keyboard per tier: 7 sample rows in every biome, looking along / back / across / down, then a run
- keepers: all 7 (R152 models and today's), per tier, asleep / waking / chasing / striking / off screen, every frame
- seed opening: every rarity on desktop (tier 3) / phone (tier 2, touch) / low (tier 1) at 60 and 30 fps and an onlooker's Secret / King, every frame,
  plus the sound schedule (which sound, when, file position, speed, volume) and what is heard each frame
- hotbar session, speed popups per tier, every pack (1574 fingerprints: the Verity pack, the Void pack, every design / size / coat / context)
- `perf152_units.luau`: the two new helpers on their own

The numbers below are from the same runs. "Writes" = property writes per frame by the scripts (each one is a call into the engine in the game);
"same" = writes that set the value already there. Lua ms is the mock's time per frame (rough: it moves with machine load; the writes are the measure).

## Result

**The look and the sound are identical.** Every shot of every run is identical, or identical in everything drawn; the sound schedules are identical.
Writes of an unchanged value that were dropped leave no trace at all. The only differences, all allowed (never drawn, or provably off screen):

- seed opening, Secret / Cosmic / King story scenes: fully transparent pieces (Transparency 1: crack, crown band / jewel / point / tip, floor
  shockwave, galaxy star, gold ray, implosion core, light leak, lock bolt, pack shard, shockwave, supernova) are no longer moved while they stay invisible.
  The frame one becomes visible it is placed first, as before.
- keepers: the Storm Colossus's "Electrical surge" arcs between flashes (Transparency 1) are not reshaped; each flash places them before it shows them.
- hub: the BEST PULL / BIGGEST FRUIT items and the Void giveaway pack hold still while provably out of view (outside the view with a margin of twice the
  camera's last turn and move + 3 degrees, never within 12 studs); their light / sparkles / effects keep moving, and the frame they come back into view
  they take that moment's pose and pulse (the comparison leaves those items out only in the shots where they are off screen).

## Before -> after

### Seed opening (60 fps; writes per frame, same in brackets)

| | desktop (tier 3) | phone (tier 2) | low (tier 1) |
|---|---|---|---|
| Common | 153.0 (85.1) -> 72.2 (4.2) | 153.0 (85.1) -> 72.2 (4.2) | 151.6 (84.0) -> 71.8 (4.2) |
| Mythic | 262.0 (153.5) -> 110.5 (1.9) | 230.7 (132.7) -> 99.9 (1.9) | 228.1 (131.5) -> 98.6 (1.9) |
| Secret | 399.6 (226.6) -> 147.6 (2.7) | 275.7 (149.9) -> 110.6 (2.4) | 271.5 (147.5) -> 108.8 (2.4) |
| Cosmic | 503.3 (314.5) -> 180.0 (2.9) | 326.3 (189.9) -> 133.7 (2.6) | 328.7 (190.6) -> 135.4 (2.6) |
| King | 612.8 (372.9) -> 223.1 (2.5) | 395.0 (238.4) -> 144.3 (2.2) | 384.2 (233.0) -> 138.9 (2.2) |
| onlooker King | 252.3 (159.0) -> 94.9 (1.6) | 230.8 (150.1) -> 82.1 (1.4) | 239.7 (156.6) -> 84.6 (1.5) |

Instances made per frame: unchanged (1.0 - 3.7). Lua ms (mock, King): desktop about 2.5 -> 2.2, phone 1.6 -> 1.3 (the mock's writes are cheap
Lua; in the game each skipped write is a skipped engine call).

### Hub (writes per frame; tier 3 / 2 / 1)

| pose | before | after |
|---|---|---|
| at the plaza (giveaway pack in view) | 313 / 295 / 295 | 306 / 289 / 290 |
| looking at a display (giveaway behind) | 244 / 239 / 197 | 48 / 46 / 4 |
| looking away from the moving pieces | 315 / 295 / 295 | 24 / 6 / 7 |
| far away | 7.3 / 0.2 / 3.6 | 4.1 / 0.2 / 3.6 |

Lua ms (mock) looking away: giveaway client about 3.4 -> 0.15 (tier 3), 4.6 -> 0.15 (tier 2). Instances (unchanged): HubLife151 701 / 615 / 360,
displays 279, giveaway pedestal 53, server decor 521 (8 SurfaceGuis, 22 labels).

### Keepers (all 7; writes per frame)

| | tier 3 | tier 2 | tier 1 |
|---|---|---|---|
| R152 models, asleep | 104.8 -> 87.1 | 104.8 -> 87.1 | 92.8 -> 75.1 |
| R152 models, chasing | 111.9 -> 98.8 | 111.9 -> 98.8 | 100.7 -> 94.5 |
| today's models, asleep | 257.6 -> 180.7 | 257.6 -> 180.7 | 219.6 -> 148.9 |
| today's models, chasing | 254.0 -> 240.9 | 254.0 -> 240.9 | 228.9 -> 222.7 |

Instances (unchanged): R152 models 359 / 359 / 356 (102 MeshParts, 36 / 36 / 35 emitters, 28 beams), today's 442 / 442 / 439. Lua ms on the mock
about the same (2 / 4 ms for all 7); the saving is the engine calls (and the emitter rates the mock cannot show: see below).

### Keyboard (unchanged)

| | tier 3 | tier 2 | tier 1 |
|---|---|---|---|
| instances (KeyboardTrack, at a row) | 6011 - 6115 | 4039 - 4138 | 2824 - 2903 |
| keycap MeshParts | 3575 - 3647 | 2216 - 2307 | 1471 - 1518 |
| SurfaceGuis / letter labels | 124 - 129 / about 2000 | 93 - 97 / about 1460 | 68 - 73 / about 1070 |
| writes per frame standing / running | 0 / 131.2 (2.0 same) | 0 / 112.3 (3.1 same) | 0 / 78.9 (3.1 same) |

Same before and after (see "Looked at and not done").

### Hotbar, speed popups, packs

Not changed (identical fingerprints: hotbar 119 frames, popups 300 frames per tier, 1574 packs).

## What changed

- `PropCache152` (new, ReplicatedStorage): a per-owner cache of the last value written to each property; a write of the same value is skipped (by value
  for Vector3 / Color3 / UDim2). Used by the pieces one owner animates: the card (`RarePullCard`), the story scenes (`RarePullScenes`), the sky beam
  (`RarePullFx`), the grade / blur (`RarePullCinematic`), the onlooker's beam (`RarePullWorld`), `RevealFlourish`, `PackSuspense`, the reveal in the
  world (`SeedPackClient`) and the seed's aura (`SeedPackVisuals.SeedMotion`, also the loose seeds in the world).
- Story scenes: a fully transparent piece that stays transparent is not moved (`Scene:Piece`); a still scene pack / reveal seed is not pivoted again.
- `RarePullAudio`: a held voice level and the music duck are written when they change (only that module sets them).
- `PackOpeningFeedback`, `RarityRevealScreen`: the reveal UI's cover / rings / sparkles / crown are shown and hidden only on a change (they were
  hidden again every frame after a small pull).
- `ViewCull152` (new): is a ball provably out of view. `HubDisplayClient` and `VoidGiveawayClient152` stop moving an item's pieces while it is
  (its core, light and effects keep moving; the pose is caught up the frame it is back, or when the pack stops being stepped). `VoidPackFx`: the
  effects' toggles / brightness / outline are written on change.
- Keepers: `BeastAnimation` does not move a rig part whose pose did not change (an asleep keeper's still limbs); `KeeperFx152` / `KeeperFx` compare
  emitter rates and light brightness with what they wrote, not with what they read back (Roblox keeps these as 32-bit floats, so a rate like .35 never
  read back equal and every emitter was written again every frame); `KeeperSleep` writes the Zzz fade on change; `KeeperSurge` leaves the arcs alone
  between flashes.
- `HubLife151`: the ambience sounds' held level is written on change (same 32-bit float reason); the butterflies reuse two lists instead of making two
  tables every frame.

## Looked at and not done (they would change the look, or could not be shown identical)

- Keyboard: it already pools keycaps, writes only on change, reuses its letter SurfaceGuis and fades far rows (R149 / R152); standing still it writes
  nothing, running about 79 / 112 / 131 writes a frame (tier 1 / 2 / 3) of which 2 - 3 repeat a value. Merging far rows into one EditableMesh was not
  done: it cannot be shown identical (per-key colours, materials and the press animation, letter strips), and EditableMesh memory is limited on phones.
  One SurfaceGui per several rows was not done: pixel grids and MaxDistance per gui change how the letters look.
- Pausing the giant avatars' dances off screen: the dance would be at another point when it comes back into view.
- Skipping keeper poses off screen within 160 studs: their shadows are on screen, and the pose smoothing (KeeperPolish) would jump.
- Culling the giveaway pack's debris, comets and core off screen: debris casts shadows, comet trails would break, the light moves with the core.
- Welding the Void pack's 190 pieces to move them as one: not shown identical (spinning pieces, physics state of welded parts).
- Fewer hub decor parts (the wall's 218 merlons as unions or one mesh): a union / mesh is shaded, smoothed and LOD-ed differently from its parts.
  The decor is static (no per-frame cost) and was already cut from 725 to 487 parts by R152's hub work.
- Server: its per-frame loops are the gameplay services (frozen files); the R152 keeper mesh decode is already sliced over frames.

## Run it

`sh docs/proposals/R152/tests/run_perf152.sh [scratch dir] [place.rbxl]` (about half an hour on 4 cores; `ONLY=hub,kb,keepers,seed,hotbar,popups,packs`
for a part; `PERF_BASE` for another base). `PERF_WHERE=true` in front of a seed / keeper driver lists which line wrote a repeated value.
