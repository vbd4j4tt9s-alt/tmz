# R152 – Seed opening: sound in sync, smooth motion, better beams and stages, reliable reveals

Owner asks (in order): "polish more on the animations for seed opening … audio syncing issues and animation issues"; the planets "have to
look good by texturing"; the beam "should actually feel like a well made beam from the sky"; "sometimes the animation not playing"; "the
animation must be smooth … whoosh for the flying … don't make the audio so loud"; "improve look on the beam and assets used in the
animations too".

Same story, beats, sounds and durations as R151 – this is polish, not a redesign. Four commits on `worktree-agent-adeb29c5ff5ea67ed`:
part 1 (sync, starts, motion), part 2 (loudness), part 3 (beams, images, reliability, tests), part 4 (look polish, previews).

## Previews

All made with the real client scripts on the Roblox mock, drawn with three.js (beams as textured ribbons, particles as sprites, the
client-drawn images from the real pattern code), the GUI with R150's renderer. Approximate: plain materials, stand-in pack art and avatar,
stand-in particle textures, no Future lighting, the game's mild bloom imitated.

| File | What |
| --- | --- |
| `seed_opening.png` | Every tier: suspense → burst → "1 in N" → seed (Common, Rare, Legendary, Mythic; Secret, Cosmic, King desktop; King phone; a Secret seen by others) |
| `seed_opening_king.gif` | The King scene every 0.1 s (smoothness) |
| `seed_opening_planets.png` | The Cosmic stage and its three textured planets close up |
| `seed_opening_beam.png` | The sky beam for Secret / Cosmic / King as others see it: coming down, landing, impact, rings + dust, holding, thinning (wide and close); the King's gold beams; a Mythic flourish |
| `seed_opening_assets.png` | Before (R151) / after, same moment: Secret vault, deep space, throne room, sky beam, seed card, Cosmic title |

Regenerate: `sh docs/proposals/R152/preview/run_seed_opening_preview.sh <scratch> [node_modules]`.

## 1. Sound in sync

One clock drives picture and sound (`RarePullAudio`). Each cue starts on the frame that shows its beat. The files are measured, so the
audible hit lands on that frame.

| Issue (file:line) | Player heard | Fix |
| --- | --- | --- |
| R151 started every file at its lead-in, but in several files the hit comes later (`RarePullSounds.lua:12`) | Hits after the picture: GroundImpact **+0.25 s**, CosmicBoom **+0.38 s**, SecretVault **+0.23 s**, PackShake **+0.17 s**, KingFanfare **+0.10 s**, TitleSlam +0.04 s | Measured `Hit` per file (`tools/measure_reveal_sounds.py`). A one-shot starts 8 ms of attack before its hit (`RarePullAudio.lua:139`). Worst case now: **0.010 s** at 30/60/144 fps |
| The frame's lateness was skipped into the file (`RarePullAudio.lua:139`) | Clipped attacks ("thuds" without their front) | The attack is never skipped. A late one-shot is dropped after 0.25 s, never played late |
| Sounds loaded when the reveal began (`RarePullCinematic.lua:566`) | First pull of a session: late or missing hits | Every slot preloads when the client starts. A file still loading joins on the clock (`RarePullAudio.lua:173`) |
| One voice per slot | A repeat cut the previous one off mid-ring | Two voices per layer; at most 10 voices; the oldest one-shot gives way |
| Voices rang past the end | Tails after the card was gone | Every voice fades out by the presentation's end (`EndFade`) |
| R136 impact + chime still played under the director (`PackOpeningFeedback.client.lua:177`, `RarityRevealAudio.lua:74`) | Legendary / Mythic: a double hit | The director's hit only |
| Old chord at the world burst for one's own Secret+ (`SeedPackClient.client.lua:51`) | A second chord under the story scene | Skipped while the director runs |
| Low-tier 2nd / 3rd note on `task.delay` (`RarityRevealAudio.lua:30`) | Notes after a skip or close | Played by the reveal's clock (`A.Tick`) |
| Heartbeat throb on a free-running sine (`RarePullRules.lua:154`, `RarePullCard.lua:313`) | Thump did not match the throb | Edges throb on the heartbeats you hear (25 ms attack) |
| Crown 99.8 % down 0.17 s before its fanfare (`RarePullRules.lua:404`) | The crown "landed" before the sound | It touches on `CrownOn` and presses in with the bell + fanfare |
| Cosmic star whoosh cut before its swell; star chime 0.1 s early (`RarePullRules.lua:565`, `:567`) | No whoosh peak; early chime | Swell on the star's fastest moment; chime on the frame it resolves |
| Secret third lock turn had no click (`RarePullRules.lua:550`) | Silent turn | One click per turn |
| King bell rang on the fade to black (`RarePullRules.lua:573`) | Bell over black | Bell as the throne room opens; land, crown and settle sounds on their beats |
| Music not ducked | Music fought the reveal | Music / Chase groups ducked up to 10 dB on the presentation's clock (`RarePullRules.lua:234`, `RarePullAudio.lua:216`) |
| No sound for flights | Silent flights | Soft whoosh on every flight, its swell on the fastest frame (`RarePullRules.lua:481`, `RarePullSounds.lua:38`): card float, Cosmic drift + planets, King carry, seed rise / float, seed to hand (`SeedPackClient.client.lua:287`), sky beam (3D). Existing whoosh file, pitch varied per flight, no uploads |
| Chat line could come before the puller saw the seed (`PullAnnouncerClient.client.lua:48`) | "X pulled …" spoiler | Held until `RarePullSeedShownAt` (title, seed, "1 in N" slammed) plus a margin (`RarePullCinematic.lua:17`) |

## 2. Loudness

Measured from the owner's files (BS.1770, 400 ms, K-weighted), Volume × Effects group, voices added as energy. The game's own short
sounds are assumed at -16 LUFS. Caps: mix ≤ -18 LUFS, any voice ≤ -20, whooshes ≤ -30 and ≥ 8 dB under the hit, sample peak ≤ -3 dBFS,
≤ 10 voices. `tests/loudness_before_after.sh` prints both sides.

| Presentation | Mix, loudest (LUFS) before → after | Loudest voice | Whoosh | Peak (dBFS) | Voices |
| --- | --- | --- | --- | --- | --- |
| Common card | -24.8 → -28.6 | PackShake -26.5 → PackBurst -29.4 | – → -40.0 | -9.4 → -13.9 | 3 → 4 |
| Uncommon card | -22.9 → -24.9 | TitleSlam -25.6 → Heartbeat -28.0 | – → -40.0 | -4.6 → -8.9 | 4 → 5 |
| Rare card | -23.4 → -25.6 | TitleSlam -24.5 → PackBurst -27.5 | – → -40.0 | -4.8 → -10.0 | 3 → 5 |
| Legendary card | -21.0 → -22.2 | GroundImpact -22.1 → -25.9 | – → -40.0 | -3.8 → -5.9 | 4 → 5 |
| Mythic card | -19.7 → -21.2 | Riser -20.0 → PackBurst -26.0 | – → -40.0 | -1.0 → -3.7 | 5 → 6 |
| Secret story | -13.7 → -20.7 | SecretGlitch -14.7 → Impact -23.0 | – → -34.0 | +1.9 → -3.2 | 7 → 8 |
| Cosmic story | -14.8 → -21.3 | CosmicBoom -16.6 → -23.0 | -19.1 → -31.5 | -1.0 → -6.1 | 7 → 7 |
| King story | -15.1 → -20.0 | Riser -17.5 → Impact -23.0 | – → -32.6 | +0.8 → -3.3 | 8 → 9 |

Every presentation is quieter than R151; the hit is now its loudest moment, and the ladder still grows with the tier. Volume changes
(`RarePullSounds.lua`): Riser .45→.21, Impact .55→.36, GroundImpact .45→.29, TitleSlam .35→.23, Sparkle 3→2.6, PackShake .7→.42,
PackBurst .3→.25, KingChoir .18→.08, KingFanfare .45→.26, KingBell .8→.55, CosmicWhoosh .4→.09, CosmicBoom .5→.24, CosmicStar 2.5→1.0,
SecretGlitch 1.3→.45, SecretVault .3→.28; new Flight .12. Unchanged: SuckIn, Heartbeat, AuraHum, CosmicPad, drone / whisper.

## 3. Motion

All motion is a function of the presentation's clock, so the picture is the same at 30, 60 and 144 fps (tested to 0.002 studs).

| Issue (file:line) | Player saw | Fix |
| --- | --- | --- |
| Wobble kick jumped up to 7° in one frame (`RarePullRules.lua:137`) | Pack snapping on each pulse | 40 ms swell, settles 0.3 s after the burst |
| Click shake started at full offset (`PackOpeningFeedback.client.lua:161`); camera kick too (`:268`) | Pack / camera jump on each click | Spring starting from rest; kick eased in over 40 ms |
| Hit shake started at full strength (`RarePullCinematic.lua:411`) | Camera jump on the hit frame | 30 ms swell |
| Pack shakes started / stopped at full strength (`RarePullRules.lua:343`) | Small jumps at unlock / spin-up / crown and at the silence | Swell in (0.1 s; King 0.08 s) and settle over 0.06 s |
| Camera eased to a stop at every key (`RarePullRules.lua:287`) | Stop-and-go camera | One Hermite path through the keys; still eases at the ends and before a cut |
| King set-down began at full speed (`RarePullRules.lua:366`) | Pack lurched onto the cushion | Smooth set-down |
| Cosmic seed arc ended moving (`RarePullRules.lua:383`) | Small hitch as the star became the seed | sin² arc, arrives at rest |
| Replaced card vanished, FOV snapped (`RarePullCinematic.lua:218`) | Fast second pack: pop + zoom jump | Old card fades (0.18 s) under the new one; FOV handed over |
| Letterbox cut at a fifth of its height (`RarePullCard.lua:321`); "1 in N" jumped to 1.45× (`:247`) | Pops on the way out / on the slam | Eased out to the end; 25 ms slam |
| Texts faded where they stood (`RarePullCard.lua:234`) | Abrupt exit | Lift a little as they fade |
| Skip hint under the notch (`RarePullCard.lua:182`) | Cut off on phones | Placed inside the device safe area |
| Nebulae turned a fixed step per frame (`RarePullScenes.lua:548`) | 4× faster at 240 fps | Turned by the clock |
| Emptied wrapper sank at full speed (`SeedPackClient.client.lua:227`) | Wrapper jumped on the burst | Starts from rest |
| Tier colour shown too early: click ring (`PackOpeningFeedback.client.lua:184`), in-place edges (`RarePullCard.lua:369`), world motes (`RarePullWorld.lua:10`), flourish glow (`RevealFlourish.lua:10`) | Rarity given away before the suspense; double glow flicker | Neutral ring; the walking hint everywhere; one glow |
| Flourish rings grew at a constant speed (`RevealFlourish.lua:102`) | Mechanical rings | Ease out |

## 4. The look

* **Sky beam** (`RarePullFx.lua`, new; the old neon cylinders in `RarePullWorld`, `RevealFlourish` and the King's carry / crown beams
  are gone). Layered Beams between attachments:
  - a white-hot core;
  - a glow in the tier colour (flare texture, streaming);
  - a smoky haze;
  - 1–3 sparkle streaks twisting round it on orbiting attachments.

  It slams down accelerating, lands on the burst, holds with embers, then thins and fades. Landing: flash light, two smooth shockwave rings
  (the halo image on a flat part; segments without it), dust, sparks, debris, glowing cracks. The King's beams are gold and dimmer so the
  crown stays the star. Budgets per ClientFxBudget tier (`Fx.Budget`): low quality drops the haze, debris and two streaks. Beam textures
  are Roblox's own particle textures (always there; a client-drawn beam texture was not needed).
* **Images drawn on the client** (`RarePullArt.lua`, new): EditableImage, real pattern code, drawn a row at a time from 15 s after start;
  about 1.4 MB in total. They are:
  - a banded gas giant, a cratered world and a ringed ice world, each with an atmosphere rim;
  - two nebulae and a tiling star map;
  - the Secret rune circle;
  - carpet, banner, stained glass and damask;
  - a seed glow and a halo.

  Every user keeps a dressed fallback: material planets with an atmosphere shell, R151 seams and discs, plain walls.
* **Stages** (`RarePullScenes.lua`):
  - Secret: a 34-stud rune circle under the pack that brightens as the lock opens; lit inlays on the lock plates (SurfaceGui, no extra parts).
  - Cosmic: a star map on walls, ceiling and (dim) floor; nebulae painted on the far wall (as billboards they were cut by the floor); textured planets.
  - King: carpet, banners, glass, tone-on-tone damask, crimson brocade on the throne and cushion, gold beams.
  - Every scene: a layered burst on the hit, a halo just behind the seed (1.1 studs, never over it), a rim light on the pack.
  - Parts with / without images (desktop, phone): Secret 70/77, 49/52; Cosmic 83/92, 45/52; King 187/187, 120/120. R151 caps 80 / 95 / 190 kept.
* **Card** (`RarePullCard.lua`): soft glow image behind every seed; a turning halo from Legendary up; textured planets on the Cosmic title.

## 5. "Sometimes the animation not playing" – causes found

The `game.Loaded` / InteractionAudio race is the coordinator's fix and is not in this change. Every other cause found:

1. The director was given 10 s at start-up. If `RarePullCinematic` arrived later, every pull that session used the old reveal. Now fetched again per pack (`PackOpeningFeedback.client.lua:20`).
2. A start that threw left a half-built presentation (camera, HUD) and no reveal. Now `M.Start` cleans up and the old reveal plays (`RarePullCinematic.lua` `M.Start`, `PackOpeningFeedback.client.lua:118`).
3. A seed the client's rules did not know errored every frame. Now it is revealed as Common (`PackOpeningFeedback.client.lua:108`).
4. One error in the per-frame presentation stopped it for the session. Now each frame is protected and logged once (`PackOpeningFeedback.client.lua:275`).
5. `SeedPackClient` gave up after 20 s waiting for the art / catalog: no world reveal all session. Now it waits (`SeedPackClient.client.lua:13`). `RarePullWorld` is loaded late rather than never (`:44`).
6. One failing reveal stopped the loop for every pack. Now it is cleaned up, logged, and its pack shown again (`SeedPackClient.client.lua:450`).
7. A seed missing from the published art or catalog (late, left out, a new kind) got no world reveal and an empty card. Now it is built on the client with the same art code (`SeedPackClient.client.lua:77`, `RarePullCinematic.lua:64`). The art library is looked up per reveal, since a rebuilt one left a dead folder.
8. Tool put away on the frame of the last click: the reveal was dropped before it started. Now kept (`PackOpeningFeedback.client.lua:150`).
9. Re-equipping mid-reveal restarted it as a "quick" reveal. Now the same reveal keeps playing (`RarePullCinematic.lua:299`).
10. Director and world pack decided "quick" separately: mismatched timing. Now one decision per bag (`RarePullRules.lua:100`, `SeedPackClient.client.lua:104`).
11. One bad frame switched a piece off for good, or cut the story scene. Now it skips that frame; three in a row and the piece is dropped or the scene cuts to the result card (`RarePullCinematic.lua:395`, `:499`).
12. Sounds were left playing when the first audio frame failed. Now always stopped by their run (`RarePullCinematic.lua:344`).
13. An error in one puller's world effect stopped every effect that frame. Now each is protected; the beam is freed after its fade and the hum / whoosh stop with the effect (`RarePullWorld.lua:131`).
14. A stale render-step binding survived a restart. Now unbound before binding (part 1). Low-tier notes on `task.delay` played after a close; now on the clock (`RarityRevealAudio.lua:30`).

## 6. Timelines (seconds; "+" = same frame)

| Tier | Beat → time → sound |
| --- | --- |
| Common | pulse 0.37 PackShake · Burst 0.60 PackBurst + float whoosh (swell 0.90) · Odds 0.93 TitleSlam · end 1.40 |
| Uncommon | 0.30 / 0.55 PackShake, 0.40 Heartbeat · Burst 0.70 PackBurst + whoosh (1.10) · Odds 1.11 TitleSlam · 1.23 Sparkle · end 1.70 |
| Rare | 0.37 / 0.67 PackShake, 0.49 Heartbeat · Burst 0.85 PackBurst + whoosh (1.43) · Odds 1.34 TitleSlam · 1.46 Sparkle · end 2.20 |
| Legendary | 0.28 Riser · 0.36 / 0.68 / 0.94 PackShake, 0.46 / 0.80 Heartbeat · Burst 1.10 GroundImpact + PackBurst + whoosh (2.30) · Odds 1.67 TitleSlam · 1.79 Sparkle · end 3.70 |
| Mythic | 0.33 Riser · 0.35–1.16 four PackShakes, three Heartbeats · 0.88 SuckIn · Burst 1.30 Impact + GroundImpact + PackBurst + whoosh (2.90) · Odds 1.90 TitleSlam · 2.02 Sparkle · end 4.70 |
| Secret | 0 drone, 0.25 glitch · SceneIn 0.70 whisper · Glitch 1.30 / 1.90 SecretGlitch · Lock 2.40 Riser + clicks 2.40 / 2.62 / 2.84 · Unlock 2.90 SecretVault · 3.05 SuckIn · Shudder 3.25 · Silence 3.45 · Climax 3.55 Impact + GroundImpact + PackBurst + glitch + rise whoosh (3.75) · Rise 3.95 float whoosh (4.53) · Odds 4.15 TitleSlam · FloatEnd 5.10 Sparkle · end 6.40 |
| Cosmic | 0 CosmicPad · SceneIn 0.80 drift whoosh (0.83) · planet whooshes (1.30 / 1.80 / 2.30), Align 1.60 / 2.10 / 2.60 CosmicStar · SpinUp 2.60 Riser + CosmicWhoosh · 2.95 PackShake · 3.95 SuckIn · Silence 4.35 · Climax 4.45 CosmicBoom + GroundImpact + PackBurst + star whoosh · Odds 5.05 TitleSlam · StarIn 5.30 CosmicStar + float whoosh (5.95) · FloatEnd 6.60 CosmicStar · end 8.00 |
| King | 0 KingChoir · SceneIn 0.85 KingBell + carry whoosh (1.93) · Land 3.20 PackShake · CrownStart 3.40 Sparkle · 4.00 Riser · CrownOn 4.55 KingBell + KingFanfare (crown touches) · 4.60 / 4.80 PackShake · 5.05 SuckIn · Silence 5.45 · Climax 5.55 Impact + KingFanfare + PackBurst + GroundImpact + rise whoosh (5.78) · 5.75 KingChoir · Rise 6.00 float whoosh (7.35) · Odds 6.15 TitleSlam · FloatEnd 8.70 KingBell · end 10.20 |

From `tools/print_timelines.luau`. Calm (ReducedMotion) and in-place versions use the same sheets on their own timelines.

## 7. Tests

`sh docs/proposals/R152/tests/run_seed_opening.sh <scratch> [all]`:

| Suite | Checks |
| --- | --- |
| `test_seed_sync` | 4269 checks, 0 fails. Preload; every hit within 1/60 s of its beat frame at 30 / 60 / 144 fps (753 plays, worst 0.010 s); whoosh swells on the fastest frame (93 flights); risers end on the silence; nothing outlives its presentation; skip / abort / death / script destroyed clean up; fast second pack hands over (no FOV snap); duck; cold files; chat line after the seed |
| `test_seed_loudness` | 97 checks, 0 fails. The caps above, ladder growth, quieter than R151 |
| `test_seed_fx` | 571 checks, 0 fails. Images (size, deterministic, see-through, seamless tiles, sliced, none on low quality); stages with and without images (budgets, fallbacks); every beam / emitter / light / image anchored to its subject (halo behind the seed, burst at the pack, carry beam on the pack, crown beam on the throne, sky beam at a walking puller's feet); beam slam, landing frame, impact, tiers, Destroy; clean-up on skip / close / second pack; smoothness at 30 and 60 fps (no pop, no kink, same picture); particle and layer budgets |
| `test_seed_stress` | 3617 checks, 0 fails. The real `SeedPackClient` + `PackOpeningFeedback`. Slow join: the reveal starts before the scripts and still plays. Then 240 random openings: every tier; all 54 + Mech + Verity seeds (184 not in the published art); every pack variant, shape and giant size; desktop / phone / low quality; ReducedMotion; onlookers; 37 fast second packs; 17 deaths + respawns; 19 tools put away; 32 injected errors (card, stage, beam, suspense, flourish, sound engine). Every opening produced its reveal and ended clean; nothing leaked |

Also run green: R151 `run_rare_pull.sh` (its world test now checks the beam), R136 (its reveal test now checks the Legendary / Mythic beam), R150 `run_sfx.sh` (incl. pack tests), R138, R151
`run_announce.sh`, R147 Verity UI, R149 Verity pack, and the full runner `tools/tests/run_all_suites.sh` (64 suites: 63 passed on the first pass; R136 still checked the old 7-stud pillar part, its test now checks the beam, 24 checks, 0 fails).

## 8. Check in Studio (needs eyes / ears)

* **EditableImage live.** Images draw ~15 s after joining. Planets should be textured; Output should have no `[RarePullArt]` failure.
  If EditableImage is unavailable for the experience, everything falls back to the dressed parts.
* **Beams in daylight and at night.** Widths (world beam 3.2 / 3.4 / 3.6 studs), the King's beam `Strength` (.8 / .6), rings on sloped
  terrain (the ring part sits 0.05 above the ground at the feet).
* **Volumes by ear.** The table assumes the game's own short sounds at -16 LUFS. Check that the Sparkle slice (`Region`) is its bright
  part, and that whooshes are audible but soft on phone speakers.
* **Phone frame time.** Check during a King scene with a world beam, and while images are drawing (sliced at 4 ms per frame).
* **Throne room under Future lighting.** Damask tile size (3.4 studs) and carpet scale.
* **Hermite camera.** Check that the moves feel right.
* **Seed halo** behind very tall or giant seeds.
