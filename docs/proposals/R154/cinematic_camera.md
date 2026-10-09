# R154 proposal: cinematic camera for the Secret, Cosmic and King reveals

Owner: "i like the pack animations that we currently have rn but could we improve it if possible by having dynamic camera movement like a
cinema scene in a way show me the previews of the animations for only secret to king. legendary and mythic no work has to be done for those".

**This is a proposal. Nothing in `src/` changes.** It covers the three story scenes only: Secret, Cosmic and King. The R151 scenes stay as they
are, with the R152 sync and polish and the R153 "full every time" and skip. That means the same stages, pack, seed, beams, planets, crown,
titles, sounds, beats and clock. Only the camera is new. Common to Mythic are not touched.

## Previews

| File | What |
| --- | --- |
| `cinematic_secret.mp4` / `.gif` | Secret, the whole 6.4 s scene through the proposed camera, from opening the pack to the hand-back |
| `cinematic_cosmic.mp4` / `.gif` | Cosmic, 8.0 s |
| `cinematic_king.mp4` / `.gif` | King, 10.2 s |
| `cinematic_king_compare.mp4` | King, today's camera on the left and the proposed camera on the right, on the same clock |
| `cinematic_storyboard.png` | Labelled keyframes for each tier, plus phone and tablet framing, Reduced Motion and an onlooker |

The videos are 640×360 at 25 fps (H.264, 0.7–1.3 MB each; the side-by-side is two 640×360 pictures, 2.4 MB). The GIFs are the same
films at 20 fps with 128 colours (2.6 / 5.1 / 7.2 MB), so the MP4s are the sharper ones. Under each picture is a strip that shows:

- the shot's name and what the camera does;
- the scene clock;
- a beat ruler, with a tick for every sound hit and the hit itself marked in the tier colour. The camera's shots appear as bands, with a
  playhead.

**How the previews are made.** They play the real client scripts (`RarePullCinematic`, `RarePullScenes`, `RarePullCard`, `SeedPackClient`,
`PackOpeningFeedback`) on the Roblox mock. They are drawn with R152's three.js renderer and R150's GUI renderer. The camera is the proposed
rig, `preview/cinecam154.luau`. It is written in the shape a later `RarePullCamera` module would take.

The previews are approximate:

- plain materials;
- stand-in pack art, a blocky avatar and a stand-in garden;
- no Future lighting;
- depth of field drawn with a bokeh pass.

To regenerate them, run `sh docs/proposals/R154/preview/run_cinematic_preview.sh <scratch> [node_modules]`. The same run prints the
comfort, sync and framing numbers quoted below (`preview/check_camera154.luau`) to `<scratch>/check_camera.txt`.

## 1. Principles

1. **One clock.** The camera is a pure function of the scene clock `t` and its timeline (`RarePullRules.Timeline`). It has no springs and
   keeps no state. As a result:
   - it is the same picture at 30, 60 and 144 fps;
   - a skip, which moves the clock, lands on exactly the designed frame;
   - every camera beat is read from the same beat names the sound cues use (§5).
2. **Add, don't replace.** The stage, the pack and seed poses and the hero rule stay. From the hit, the seed is centred and grows from 33% to
   39% of the screen height (R151 §4a). Checked: Secret 34–39%, Cosmic 34–39%, King 33–39%, at most 0.026 of the frame off centre.
3. **Cinema grammar.**
   - **Cut on the sound.** The Secret glitches and lock click, and the King's carry whoosh, crown shimmer and second shake.
   - **Move inside a shot.** Dolly, orbit, crane, push-in.
   - **Speed ramp into the silence, then dead stop.** The camera speeds up toward the silence, holds perfectly still for the 0.1 s silence,
     then the hit throws it back.
4. **The player's own camera is only ever offset.** In the world (before the cut to black and during the hand-back), the camera never goes
   somewhere new. It does only three things to the player's live camera:
   - pushes along the camera-to-head line, which the Roblox camera already keeps clear of walls;
   - turns where it stands;
   - changes the lens.
5. **Comfort limits (Full).** These are measured at 240 Hz on what can be seen (not under the black fades):

   | Limit | Proposed | Today (R151 / R152 Hermite camera) |
   | --- | --- | --- |
   | Fastest view turn | ≤ 60°/s. Secret 44, Cosmic 38, King 60 | Secret 37, Cosmic 14, King **217** (the Land → CrownStart key) |
   | Orbit around a subject | ≤ 32°/s. Secret's glitch drifts 32, Cosmic's vortex 25, King 16–18 | – |
   | Dutch tilt | ≤ 10°. Secret glitches only, 9.3° max; Cosmic 5°; King 2.3° | – |
   | Lens ramps | ≤ 60°/s | – |

   Further limits:
   - Lens snaps are 2.5–3° in 60 ms, only on a click or the crown.
   - No 360° spins.
   - No shake except R152's own hit shake (35% on phones) and a small shudder that follows the pack's own shake.
   - **Reduced Motion** turns all of this off (§6).

## 2. SECRET: "the Sealed Pack". Mysterious and dark (6.4 s)

The camera stays low, slow and hesitant. It creeps up on the pack out of the dark, and the focus finds the pack late. The glitches are jump
cuts with a dutch tilt. The lock ratchets the lens in on every click, and the camera is pulled into the cracks of light. Then it stops dead.

| Shot | Time (s) | Beat / sound | Framing (start → end) | Move | Ease | Length |
| --- | --- | --- | --- | --- | --- | --- |
| OPEN | 0.00–0.65 | drone fades in; SecretGlitch .25 | the player's own camera, over the shoulder → 35% closer, aim 4° down | push-in along the camera → head line; dutch creeps to 3°; lens −6° (today's push); a 0.12 s glitch jolt at .25 (0.12 stud, 2°) | cubic ease-in, into the black (fade .45–.65) | .65 |
| S1 Out of the dark | 0.65–1.30 | the void opens, fading in .70–1.00; whisper | low wide: 3 studs above the black glass, 13.5 back; the pack in the upper third, the glowing rune circle along the bottom → 10.6 back | creeping dolly-in 3.1 studs, crane up 0.4; lens 38→36; roll 0→−2°; **rack focus** from the near runes (6.5 studs) to the pack (11.4 studs), 0.85–1.25 | near-linear (still moving at the cut) | .65 |
| S2 Glitch | 1.30–1.90 | **cut on SecretGlitch 1.30** (skip allowed from 1.50) | medium, high right three-quarter (36°, 10° above) | **dutch +8°** with jitter for the glitch's 0.22 s, then a slow 6° drift left as the tilt eases to +2° | quadratic in | .60 |
| S3 Glitch | 1.90–2.40 | **cut on SecretGlitch 1.90** | medium, low left three-quarter (−42°, 12° below), looking up | **dutch −8.5°** with jitter, then a 4° drift right, the tilt easing to −3° | quadratic in | .50 |
| S4 The lock | 2.40–2.90 | **cut on the 1st click 2.40**; clicks 2.62, 2.84; Riser | frontal medium close-up, 7.4 studs | locked off; a **ratchet**: the lens snaps in 2.5° in 60 ms on each click (44 → 41.5 → 39 → 36.5) with a ±0.8° roll tick | snap (ease-out, 60 ms) | .50 |
| S5 Cracks of light | 2.90–3.45 | SecretVault 2.90, SuckIn 3.05, Shudder 3.25 | → **extreme close-up**, 5.2 studs, lens 33°, a little low | push-in 2.2 studs; the camera shudders with the pack (60% of its shake); shallow focus | cubic ease-in (fastest into the silence) | .55 |
| Silence | 3.45–3.55 | everything stops; the screen dips | the same | **dead stop**: no move, no shake | – | .10 |
| S6 The hit | 3.55 | Impact + GroundImpact + PackBurst + glitch | → medium | lens 33→44 in 0.2 s (expo). The hero rig takes over, so the camera is thrown back about 1.5 studs. Roll kick 2.5° (0.4 s); R152's hit shake (0.5 s) | expo, then it hangs | .20 |
| S7 The seed rises | 3.55–5.10 | Rise 3.95, TitleSlam 4.15, Sparkle ×3 | seed hero, centred, 33% → 39% | **crane up** with the rising seed (level at Rise + .3), then a slow 11° orbit as it floats down to the camera; focus on the seed | one Hermite curve through the keys | 1.55 |
| Out | 5.10–5.60 | fade to black | – | the orbit drifts on 3°; the seed eases 39 → 37% | – | .50 |
| HAND-BACK | 5.60–6.30 | the world fades in (.35 s), letterbox out (.4 s), purple wisps aura | the player's camera, 45% closer, 3° down, roll −2°, lens −6 | **pull back** into exactly the player's own live camera | smooth | .70 |

## 3. COSMIC: "Supernova". Vast; a space pull-out (8.0 s)

One continuous take in space, with no cuts inside the stage. The scale is the point. The scene opens tight on the tumbling pack and pulls
out until the pack is a speck before the nebulae, settling on the line of planets. Then a vortex push-in follows, and a crash into the
collapsing core. The supernova blows the camera back, and the falling star leads it home.

| Shot | Time (s) | Beat / sound | Framing (start → end) | Move | Ease | Length |
| --- | --- | --- | --- | --- | --- | --- |
| OPEN | 0.00–0.75 | CosmicPad fades in; stars gather | the player's camera → **tilted up 18° to the sky**, lens +6 | a turn where the camera stands (no move), the lens widens: "the sky opens" | smooth | .75 |
| C1 Cosmic zoom-out | 0.75–2.60 | drift whoosh (swell .83); planet whooshes; **Align 1.60 / 2.10 / 2.60** CosmicStar | 3.2 studs from the tumbling pack (it fills the frame) → 19 studs, the pack small before the nebula wall, the 3 planets lined up behind it | **pull out** 16 studs, tracking the drifting pack; aim rises to the planets' line; lens 42→54; a **breath** (lens −1.6° and back, 0.6 s) on each planet locking in | ease-out (the fast start is under the fade-in) | 1.85 |
| C2 Vortex | 2.60–3.90 | SpinUp 2.60: Riser, CosmicWhoosh; PackShake 2.95 | 19 → 8.5 studs | push-in with a slow **counter-orbit** 21.5° (peak 25°/s) against the galaxy's spin; dutch 0→5°; lens 54→46 | smooth | 1.30 |
| C3 Collapse | 3.90–4.35 | Implode 3.90, SuckIn 3.95 | 8.5 → 3.4 studs on the core | **crash push-in**, tilt back to 0, lens 46→36 | quadratic in | .45 |
| Silence | 4.35–4.45 | – | – | **dead stop** | – | .10 |
| C4 Supernova | 4.45–5.00 | **CosmicBoom** + GroundImpact + PackBurst | 3.4 → 13 studs; the shell and two rings fill the frame | the blast **throws the camera back** (dolly out 9.6 studs + lens 36→58 in 0.45 s); roll kick 1.5°; R152 shake | expo | .55 |
| C5 The falling star | 4.85–6.60 | star whoosh (swell), **StarIn 5.30** CosmicStar, TitleSlam 5.05, Sparkle | the hero rig from 0.4 s after the hit (0.5 s blend): it follows the star home, then seed hero 33% → 39% on the wide lens | a slow 15° orbit as the seed floats down, the nebula drifting behind (parallax) | Hermite | 1.75 |
| Out | 6.60–7.20 | fade; FloatEnd CosmicStar | – | drifts on 4° | – | .60 |
| HAND-BACK | 7.20–7.90 | the world; two little planets around the player | the player's camera tilted 16° up, lens +5 → the player's own camera | **tilts down** from the sky onto the player (the opening, mirrored) | smooth | .70 |

**Owner decision.** Because of the blast-back, the Cosmic seed reaches its hero size when the star arrives (StarIn, 0.85 s after the hit)
instead of 0.3 s after it. Between the two the star is the seed in flight, centred. If the seed should be big sooner, the blast shortens to
0.3 s.

## 4. KING: "the Coronation". Regal, epic (10.2 s)

Big, slow and symmetrical:

- a crane down the great hall;
- a low tracking shot that walks with the procession past the pillars;
- an orbit and crane up that meets the descending crown on the pack, at the moment of the fanfare;
- a low-angle "long live the king" push-in;
- the hit;
- a crane up with the crowned seed and a slow royal orbit.

| Shot | Time (s) | Beat / sound | Framing (start → end) | Move | Ease | Length |
| --- | --- | --- | --- | --- | --- | --- |
| OPEN | 0.00–0.80 | KingChoir; gold motes rise | the player's camera → 30% closer, 8° up, lens −6 | push-in along the camera → head line and a tilt up | smooth | .80 |
| K1 The grand hall | 0.80–1.93 | the throne room opens with **KingBell** .85 | from the rafters by the doors (21.5 studs up), the whole hall symmetric (carpet, pillars, banners, chandelier, throne far away) → 9.6 studs up behind the procession | **crane down** 12 studs, sweeping slightly right; aim from mid-hall to the carried pack; lens 60→52 | smooth | 1.13 |
| K2 The procession | 1.93–3.40 | **cut on the carry whoosh's swell 1.925**; Land 3.20 PackShake | low (2.6 studs), 5.6 right and 5.5 behind the pack: the pack in its gold beam, the pillars and banners passing → a low three-quarter view of the pack on the cushion | **tracking shot** that walks with the pack and comes to rest with it as it lands; lens 50→46; focus on the pack | follows the pack's own glide | 1.47 |
| K3 The crown descends | 3.40–4.80 | **cut on the crown's shimmer 3.40** (Sparkle); Riser 4.00; **CrownOn 4.55 KingBell + KingFanfare** | low, looking up the gold beam to where the crown appears → eye level with the crowned pack | **orbit** 12° (28°→16°) and **crane up** 3.4 → 6.0 studs while the crown comes down: they meet on the pack. A 3° lens snap on the fanfare, then a 0.25 s hold | smooth (ends on CrownOn) | 1.40 |
| K4 Long live the king | 4.80–5.45 | **cut on the 2nd shake 4.80**; SuckIn 5.05 | **low angle** on the crowned pack, 7.6 → 5.2 studs | push-in, lens 44→38; the camera shudders a little with the pack (30%) | cubic ease-in | .65 |
| Silence | 5.45–5.55 | – | – | **dead stop** | – | .10 |
| K5 The hit | 5.55 | Impact + KingFanfare + PackBurst + GroundImpact | gold rays, confetti | lens 38→48 in 0.22 s; the hero rig takes over (snap back); roll kick 2.5°; R152 shake | expo | .22 |
| K6 The crowned seed | 5.55–8.70 | Rise 6.00, TitleSlam 6.15, KingChoir, Sparkle ×2, **KingBell (high) 8.70** | seed hero 33% → 39%, the throne and banners behind | **crane up** with the rising seed (from 14° below to level by Rise + .3), then a slow **royal orbit** 28° over 2.4 s (about 12°/s) as it floats down the beam; it settles on the high bell | Hermite | 3.15 |
| Out | 8.70–9.40 | fade | – | drifts on 3° | – | .70 |
| HAND-BACK | 9.40–10.10 | the world; gold halo and sparkles at the feet | the player's camera, 40% closer, 6° up, lens −5 → the player's own camera | **pull back** and settle | smooth | .70 |

## 5. Sync with the sound (R152: one clock, hits within 0.01 s)

- The camera reads `run.Clock()`, the same clock as `RarePullAudio`, and keys every cut, snap and stop on the same beat names the cue sheets
  use (`RarePullRules.SceneCues`). A cut therefore appears on the first frame at or after its beat. R152 already puts each sound's audible
  hit on that frame (worst 0.010 s at 30, 60 and 144 fps). The camera adds no delay of its own.
- Checked (`check_camera154.luau`, cut times found to the microsecond):

  | Tier | Cut time | Lands on |
  | --- | --- | --- |
  | Secret | 1.300 | SecretGlitch, +0 ms |
  | Secret | 1.900 | SecretGlitch, +0 ms |
  | Secret | 2.400 | the lock click, +0 ms |
  | King | 1.930 | the carry whoosh's swell (1.925), +5 ms |
  | King | 3.400 | the crown's shimmer, +0 ms |
  | King | 4.800 | PackShake, +0 ms |

  The cuts into and out of the stage happen under the black fades.
- Other moves are also keyed to beats:
  - the ratchet snaps are on the three clicks;
  - the crown snap is on CrownOn (fanfare and bell);
  - the Cosmic breaths are on the three CosmicStar twinkles;
  - the dead stop runs from Silence to Climax;
  - the snap-back is on Climax.
- **The hit is not slowed down.** A real slow-motion would stretch the picture against the sound. Instead the camera does the "slow-mo
  hold": it speeds up into the silence, stops dead for 0.1 s, then the snap-back decelerates exponentially. The camera seems to hang while
  the burst expands, and the clock stays one clock.

## 6. Hand-back, skip, Reduced Motion

**Hand-back.** At `Back` the screen is black, as today. The camera type, CFrame, focus, lens and subject are restored exactly as today
(`restoreCamera`), and the controls come back as today. For the next 0.7 s an **offset** eases from the "return shot" to nothing on top of
the **live** player camera. If the player moves or turns the camera, the offset simply rides on their camera and fades out, so nothing
fights them.

This uses the pattern the game already has for camera shake (`KeeperFx`): undo the offset before the Roblox camera updates (render priority
Camera − 4), apply it after (Camera + 4). The Roblox camera module never sees the offset, so it cannot drift. `Length` is `Back` + 0.8 s,
so the offset is gone before the presentation ends. `finish()` also removes it on every exit path.

**Skip (R153).**

- **Before the hit**, the clock jumps to `Climax − 0.02`. Because the camera is a function of the clock, it cuts to the frozen silence frame.
  Checked: 0.000 studs and 0.00° from the frame it holds anyway. The cut lands inside the silence dip, and then the hit and its snap-back
  play normally. The sound seeks on the same clock (`Audio.Seek`).
- **After the result**, the clock jumps to `FloatEnd`: the fade to black, then the normal hand-back.
- The focus distance and the lens are part of the same function, so they jump cleanly with it.

**Reduced Motion (`GuiService.ReducedMotionEnabled`) and VR.** The Calm timelines stay as they are (R151). The camera uses still shots only,
cut on Calm beats:

- Secret: a low still, then a frontal still on the lock;
- Cosmic: the planets' line, then a medium on the core;
- King: one low still that the crown comes down into (the Calm King is short).

The seed gets R151's still hero shot at 37%.

Calm has none of the following:

- moves, tilts or roll;
- lens snaps or breaths;
- focus pulls or depth of field;
- shake (as today);
- world offsets: the player's camera is untouched before the cut and after `Back`, and the hand-back is today's cut under the black.

VR players should get the Calm camera too.

## 7. Phones and screens

- Roblox's field of view is **vertical**, so the seed, the crown and the pack take the same share of the height on every screen. Phones in
  landscape (19.5:9) are wider than 16:9 and only show more at the sides. Every subject is composed inside the centre 4:3, so a 4:3 tablet
  loses nothing. The storyboard shows the crown and the seed on 844×390 and on 4:3. The check gives the seed the same 33–39% and at most
  0.026 off centre on 16:9, 19.5:9 and 4:3.
- **If portrait is ever allowed**, the rig widens the vertical field of view so the 4:3 centre still fits ("Vert+"):
  `fov = max(fov, 2·atan(tan(fov/2)·(4/3)/aspect))`. The hero distance is computed from that field of view, so the seed keeps its share.
- The text layout is R151's phone layout, unchanged.
- Phone cost:
  - depth of field is off on phones and on low quality (`ClientFxBudget.Low` / a touch device; R151's `run.Lite`);
  - the hit shake is 35% on phones (R152);
  - the camera itself is a few vector operations a frame, with no parts, no raycasts in the stage and no new sounds.

## 8. Onlookers

Other players' cameras are **never** moved. The director (`RarePullCinematic`) runs only on the opener's client, for the opener's own pack.
Everyone else gets only `RarePullWorld`: the sky beam landing on the puller, then the aura. That is unchanged and has no camera code. The
storyboard shows an onlooker's own camera seeing the beam land.

## 9. Edge cases

| Case | What happens |
| --- | --- |
| **Opening while running / walking** | The Full scene is allowed when grounded, as today: `Decide` sends a stolen-pack run, a queue or a carried seed to the in-place card. Controls are held from the first frame (today), so the character stops within a few frames. The world move is an offset on the live camera, so it follows the stopping character smoothly. Sliding more than 8 studs still ends the scene with the result card (today). |
| **Near walls (collision / occlusion)** | In the world the camera only moves toward the player along the line the Roblox camera's occlusion (Popper) has already cleared, or turns where it stands. It cannot go into a wall. Backed against a wall, the Popper has the camera close, so the push (a share of that distance) is small by itself. The stages are client-only, 2600 studs above the map, with non-colliding parts. Checked: the camera stays inside each stage's walls in every frame (0 frames outside). |
| **In a garden** | Plants and props between the camera and the player are handled by the Popper as above. The hand-back eases into the live camera, which the Popper keeps clear. |
| **On a treadmill** | Treadmill training anchors the character and plays the run in place (`TreadmillPlayback`), and R153 lets packs be opened there. The character does not move, so there is no "moved" stop. The world offset rides on the live camera, and the hand-back returns to it with the treadmill still running. |
| **First person** | The camera-to-head distance is under 1.5 studs, so there is no push; the turn and lens offsets still apply. Cosmic still looks up to the sky. The stage is the same. At `Back` the camera returns to first person exactly as today. |
| **Shift lock / gamepad / zoomed out** | All part of the live camera, so the offsets ride on top. Zoomed far out, the push is a share, so it scales. |
| **Giant pack** | `SeedPackClient`'s giant-pack camera already stands aside while the director owns the camera (`OwnsCamera`). Unchanged. |
| **Danger, death, teleport, camera replaced, error** | R151's exit paths are unchanged. `finish()` also unbinds the offset steps, undoes any offset and destroys the depth-of-field effect. |
| **Slow device (30 fps)** | Same path, fewer frames (pure function of the clock). A 60 ms ratchet snap becomes 2 frames. |

## 10. Implementation sketch (later, when approved)

- **New module: `ReplicatedStorage/RarePullCamera`.** It holds:
  - the shot lists as data (beat + offset, eye / target or orbit / track, lens, roll, ease, focus);
  - the hero rig (seed-centred, `HeroDistance` from the current lens, Az / El keyed on beats through one Hermite curve);
  - the Calm stills and the world offsets.

  Its API is `Shot(rank, variant, t, tl, ctx) → {Eye, Target, Fov, Roll, Dof}`. `preview/cinecam154.luau` is that module in preview form.
- **`RarePullCinematic._stepScene`.** Today it does `Rules.Shot(...)` plus `shake`. Instead:

  ```lua
  cam.CFrame = origin * CFrame.lookAt(eye, target) * CFrame.Angles(0, 0, rad(roll)) * shake
  ```

  Plus the following:
  - the lens is written only on change, as now;
  - a `DepthOfFieldEffect` named `RarePullDof` lives **on the Camera**, like the grade and blur (Lighting is never written). It is created
    on entering the stage, updated with `run.Set`, destroyed in `finish()`, and not created on Lite (phones, low quality).
- **The world offset.** Two render steps, `ChestChaseRarePullCamUndo` at Camera − 4 and `ChestChaseRarePullCamApply` at Camera + 4. They
  are bound only from 0 to `SceneIn − 0.05` and from `Back` to `Back + 0.7`, using KeeperFx's reset / apply pattern. They replace the
  FieldOfView-only `push` for the story scenes. The ladder's push for Legendary and Mythic stays.
- **`RarePullRules`.** `Shot` delegates to `RarePullCamera`, so the existing framing tests read the new camera. The timelines and cue
  sheets are **unchanged**.
- **Unchanged:** `RarePullScenes`, `RarePullFx`, `RarePullWorld`, `RarePullAudio`, `RarePullSounds`, `RarePullCard`, `SeedPackClient`,
  `PackOpeningFeedback`, every server file and every timeline. `src/MANIFEST.tsv` gets one row.
- **Tests to add** (R151 `test_rare_rules` / `test_rare_cinematic`, R152 `test_seed_sync`):
  - the seed's share, 30–45% from the hit (Cosmic from StarIn), centred, on 16:9, 19.5:9 and 4:3;
  - the camera inside each stage;
  - the comfort limits of §1;
  - every cut on its beat's frame at 30, 60 and 144 fps;
  - the skip target equals the silence frame;
  - the hand-back ends exactly on the live camera;
  - offsets undone and the depth-of-field effect gone on every exit path;
  - Calm has no move;
  - an onlooker's camera is never written.
- **Cost.**
  - CPU: negligible (no parts, no raycasts in the stage, about 0.02 ms a frame).
  - GPU: depth of field on desktop only.
  - Memory: none.
  - Studio: check how depth of field looks under Future lighting, and that the crown shot's low angle reads at night.

## 11. Decisions for the owner

1. **Cuts inside the scenes.** Secret has 3 and King has 3, on the sound beats. Cosmic is one continuous take. Fewer cuts are possible:
   each can become a fast move instead, but the moves would then exceed the comfort limits.
2. **The Cosmic seed's hero size** arrives with the star (0.85 s after the hit), not 0.3 s after (§3).
3. **The world opening and hand-back** (about 0.7 s each, offsets only). Alternatively keep today's lens-only push and today's cut at
   `Back`.
4. **Depth of field** on desktop only, or nowhere (it costs GPU, and some players dislike blur).
