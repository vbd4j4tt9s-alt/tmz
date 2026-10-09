# R155: the cinematic camera for the Secret, Cosmic and King reveals (built)

Owner: "i like the pack animations that we currently have rn but could we improve it if possible by having dynamic camera movement like a
cinema scene ... only secret to king. legendary and mythic no work has to be done".

This is the approved design, `docs/proposals/R154/cinematic_camera.md`, built into the game. It includes the owner's four answers and works
with R154's seed collect. Only the camera inside the Secret, Cosmic and King story stages is new. The stages, the pack, the seed, the beams,
the planets, the crown, the titles, the sounds, the beats and the clock are all unchanged. Common to Mythic keep their R154 look.

It also includes a second owner request that came in during the work: "for some cutscenes u can skip it by spam clicking disable this feature
and u can only skip at the bottom right of the screen". This applies to every pack opening, Common to King. See
[The skip: only the SKIP button](#the-skip-only-the-skip-button).

## Previews

| File | What |
| --- | --- |
| `cinematic_secret.mp4` | Secret, 11.3 s: the whole scene, 3 s of the result waiting on the hero shot, the click, the fade, the world and the seed's flight to its hotbar slot |
| `cinematic_cosmic.mp4` | Cosmic, 12.8 s, the same |
| `cinematic_king.mp4` | King, 14.9 s, the same |
| `cinematic_storyboard.png` | Labelled keyframes for each tier, the SKIP button (desktop, phone, gamepad), phone and low quality (with the depth of field), Reduced Motion, and an onlooker |

In each video the SKIP button shows at the bottom right from SkipFrom until the hit. The preview never presses it: it plays the whole scene.

**The previews come from the real implementation.** Each frame shows what the game set on the Camera: the CFrame (dutch tilt included), the
FieldOfView and the `RarePullDof` depth of field. Nothing is computed by the preview itself. They run the real scripts on the Roblox mock:

- the director, `RarePullCinematic`, which drives `RarePullCamera155`;
- `RarePullScenes`, `RarePullCard`, `SeedPackClient` and `PackOpeningFeedback`;
- `SeedCollect154` and the real `Hotbar`.

They are drawn with R154's three.js page and R150's GUI renderer at 1280×720, and the videos are 960×540 at 25 fps. As in R154 they are
approximate: plain materials, stand-in pack art and avatar, no Future lighting, and the depth of field is drawn as a bokeh pass.

Under each picture is a strip that shows:

- the shot's name (the camera's own name for it) and its move;
- the clock;
- a ruler with a tick for every hit sound;
- a white notch for each cut;
- the hit in the tier colour;
- the wait (striped) and the click.

To regenerate: `sh docs/proposals/R155/preview/run_cinematic155.sh <scratch> [node_modules]`.

## The owner's four answers, applied

1. **Cuts inside the scenes: as designed.**
   - Secret has 3 cuts: the two glitches and the 1st lock click.
   - King has 3 cuts: the carry whoosh's swell, the crown's shimmer and the 2nd shake.
   - Cosmic is one continuous take.

   Each cut shows on the first frame at or after its beat. That is the frame its sound is heard on, within 0.01 s at 30, 60 and 144 fps.
2. **The Cosmic seed reaches its hero size with the star (StarIn, 0.85 s after the hit).** The supernova throws the camera back. The hero
   framing takes over 0.4 s after the hit and blends in over 0.5 s. From the star on, the seed is 34–39% of the screen height.
3. **No world opening move and no hand-back offset.**
   - Before the cut to black, the camera is the player's own with today's lens-only push.
   - At the end, the cut back to the world is today's. The camera is restored exactly, by `restoreCamera`.
   - The cinematic camera lives only in the stage: from today's scene entry, under the black, to today's exit.
   - The tests compare the camera frame by frame against today's camera before and after the stage, and against the R154 release.
4. **Background blur on all devices.** `RarePullDof`, a `DepthOfFieldEffect`, sits on the Camera, like the grade and the blur; Lighting is
   never written.
   - It is made on the first stage frame and updated with the shot. It is written only when a value changes (`PropCache152`).
   - It goes with the stage on every way out, and `finish()` destroys it too.
   - It is on every device and quality, phones and Lite included, and in Reduced Motion (there as a still focus).
   - Its settings are modest: far blur at most 0.5 and near blur at most 0.35. The in-focus radius is 1.2–4 studs around the subject.
   - The focus changes only on cuts and on the hit. Inside a shot it blends.

## With R154's seed collect

The result waits on the hero shot until it is collected. After the seed's float (FloatEnd), the orbit eases to rest over 0.9 s. This is the
"Settle" beat; in the proposal this moment was under a fade to black. After that only a slow idle drift is left:

- two incommensurate sways of the angle around the seed, with periods of 41 s and 17 s, ±1.2° and ±0.45°;
- an elevation sway of ±0.4°;
- it fades in over 6 s.

The seed stays centred at 39% of the height. Checked over 120 s:

- the view turns at most 0.36°/s;
- the camera stays within 1.7° and 0.16 stud of where it settled;
- the drift never comes back onto itself (at least 0.7° apart at every lag from 5 to 100 s).

The click, or any auto-collect, starts today's 0.35 s fade to black, then today's cut back to the world. A skip (now the SKIP button) jumps
the clock to the hit, and the camera lands exactly on the dead-stop frame of the silence. "Skip pack animations" still gives the in-place
card, with no camera and no depth of field.

## The skip: only the SKIP button

Owner: "for some cutscenes u can skip it by spam clicking disable this feature and u can only skip at the bottom right of the screen". This
covers every pack opening: the Common to Mythic cards, the Secret, Cosmic and King story scenes, the in-place cards and the result cards.

- **A click or tap anywhere no longer skips.** Spam does nothing in any phase: before SkipFrom, in the skip window, between the hit and the
  result, and in the result's first 0.25 s. Every press is still swallowed while a presentation runs, so it never plants, digs or swings.
  The tools' own routes ask `RarePullRules.ClaimPress` first, as in R153, and the bat stays manual.
- **The only skip is a small SKIP button at the bottom right.** It is a dark pill with a white rim and "SKIP ▸▸" in the cards' font, and it
  has no click sound (the hit is the sound of a skip).
  - It shows from SkipFrom (0.35 s on a card; 1.5, 1.8 or 2.0 s in a story scene), fading in over 0.25 s, and goes at the hit.
  - Pressing it does exactly what R153's skip did: it jumps to the hit, and the hit sound and the result still play.
  - It sits inside the device's safe area (`GuiService:GetInsetArea`, CoreUISafeInsets, kept within the screen itself), 12 px from the
    edge. It keeps at least 8 px from
    every HUD box (`HudLayout.HudBoxes`): the hotbar and its item details, the status / timers stack in the bottom-right corner, the
    balances, the menu hub and, on touch screens, the jump button and the thumbstick.
  - It starts in the corner. If that spot is taken it moves left (never past the middle), then up (never above 45% of the height).
  - It is 6.5% of the screen height: 34–48 px, and at least 40 px on a touch screen (a thumb's target).
  - Where it lands: 1280×720 at (1139, 661); 1920×1080 at (1428, 884), left of the status stack; an 844×390 phone at (570, 226), above
    the hotbar and left of the jump button. Every screen in the test list passes, including a notched phone. It is in the same place in
    a card and in a story scene (the scene hides the hotbar, but keeps the jump button).
  - In a story scene it sits on the reveal's screen, above the full-screen button that catches the clicks.
- **Gamepad: B and R2 press it, and so does Enter.** With a gamepad connected it shows a red "B" badge. In a story scene, Space and A
  only collect.
- **Collecting is still a click or tap anywhere** (or Enter, B, R2, Space, A), but only a press that STARTS at least 0.25 s
  (`CollectAfter`) after the result is shown. A press held down from before does nothing. So does a burst of clicks from the animation.
  The next fresh press collects.
- **Unchanged:** "Skip pack animations" (in-place card), Reduced Motion (its own Calm timeline; the button works there too), onlookers (no
  reveal on their screen), and the R154 auto-collects.
- **The hint:** the bottom-right corner no longer says "CLICK TO SKIP". Once the result waits, the same label says "click to collect!" or
  "tap to collect!", as in R154.
- **Other openings do not share this path.** The treadmill bonus roll reel already has its own SKIP and COLLECT buttons. The mystery
  pack, the daily rewards, the Void giveaway and Verity's packs have no skip. A pack any of them gives is opened in the hand like any other
  pack, through this path.

## What was built

- **`ReplicatedStorage/RarePullCamera155`** (new, listed in `MANIFEST.tsv`). It holds:
  - the three shot lists as data;
  - the hero rig: the seed centred, its size from `RarePullRules.HeroDiameter`, angle keys on beats through one Hermite curve, then the
    settle and the idle drift;
  - the Calm stills.

  `New(rank, variant, tl)` runs once per scene. After that, `Shot(rig, t, aspect)` returns the eye, the target (stage-local), the FieldOfView
  and the roll. The depth of field is left in `rig.Focus`, `rig.Radius`, `rig.Far` and `rig.Near`. It is a pure function of the scene's
  clock and its timeline, with no state between frames. It makes no table and no closure per frame; the suite checks this in the source.
- **`RarePullCinematic`** (a small change):
  - it loads the module (`M.Camera`) and makes the rig on entering the stage;
  - in the stage it uses `sceneCamera()`: the shot with its roll, then today's R152 hit shake on top, and the `RarePullDof` writes;
  - `leaveStage()` and `finish()` destroy the depth of field.

  If the module is missing, or fails three frames in a row, the stage falls back to today's camera (`RarePullRules.Shot`) and drops the depth
  of field. One bad frame shows today's framing for that frame only.

  There is one render binding, as before. Common to Mythic, the in-place / result cards and the world phases run the R154 code, apart from
  the skip input below.

  For the SKIP button, the director's input changes:
  - `M.Tap(began)` is a click or tap anywhere. It only collects, and only if the press began at least `CollectAfter` after the result
    was shown.
  - `M.Skip()` is the button's action, with Enter, B and R2.
  - The story scene's full-screen button records when its press began. Its keys split: Enter, B and R2 skip; Space and A collect.
  - `PressTaker` still claims every press while a reveal runs.
- **`RarePullCard`** builds the SKIP button (`_buildSkip`), places it (`SkipRect`, `_placeSkip`) and shows it from SkipFrom to the hit
  (`_skip`). The corner hint is now the collect hint only.
- Since 8aa15fd, nothing else in `src` changed: no client script, no other module, no server file, and Config.Version and BackgroundMusic are
  untouched.

## What differs from the proposal

- **No OPEN and no HAND-BACK** (answer 3). The proposal's world moves and the KeeperFx-style offset steps are not built.
- **The depth of field is everywhere** (answer 4), not desktop only. It is milder: the rack focus out of the dark has a near blur of 0.35
  instead of 0.8. Shots that join carry their focus values on smoothly; there is no jump at Unlock, SpinUp or Implode.
- **The hero holds instead of fading out.** The proposal's "Out" drift and the shrink from 39% to 37% happened under a fade that no longer
  comes. Now the orbit settles at 39% and the idle drift starts.
- **King K2, the procession, takes a different lane.** The proposal's path (x 5.6) ran through the windows' slanting light shafts and ended
  under a herald's trumpet. It now runs between the candelabra and the shafts (x 4.75–5.0), 0.3 stud higher, and stops 1.5 studs further back.
  The nearest part is now 0.74 stud from the lens; Roblox's near plane is 0.5.
- **King K3, the crane up to the crown, is a little gentler.** It cranes from 3.6 to 5.8 studs (was 3.4 to 6.0) and orbits from 28° to 18° (was
  28° to 16°). The fastest turn is 55.7°/s; the proposal's was 60, at the limit.
- **King K4 ends at x 0.9** (was 0.35). Its accelerating push-in no longer swings around the pack: the orbit is 14°/s, where it was 36.
- **The King's carry cut is exactly on the whoosh's swell**, at 1.925 s (the proposal had 1.930, +5 ms).
- **The Cosmic planets' lens breaths belong to the scene, not to the C1 shot.** In the proposal the 2nd breath was cut off where C1 ends, a
  0.4° lens jump at 2.60 s, and the 3rd breath never played.
- **Calm (Reduced Motion)** cuts exactly on the Calm beats; the proposal cut 0.05 s early. It keeps a still depth of field: "DOF still allowed".
- **Not built:** the Calm camera for VR players (§6 of the proposal). The game does not detect VR today; see below.
- **Built but never used:** Vert+ for portrait screens, because the game does not allow portrait.

## Measured (the suites print these)

| | Secret | Cosmic | King | Limit |
| --- | --- | --- | --- | --- |
| Fastest visible view turn | 44.4°/s | 23.2°/s | 55.7°/s | 60 |
| Fastest orbit around the subject | 27.4°/s | 22.4°/s | 14.4°/s | 32 |
| Biggest dutch tilt | 9.3° | 5.0° | 2.1° | 10 |
| Fastest lens ramp (snaps apart) | 18.9°/s | 44.2°/s | 27.5°/s | 60 |
| Lens snaps | 2.5° ×3 in 60 ms, on the clicks | none | 3.0° in 60 ms, on CrownOn | 3° |
| Nearest stage part to the lens | 2.95 stud | 1.37 stud | 0.74 stud | 0.7 |
| The seed from the hit (Cosmic: the star) through a 120 s wait | 34–39% | 34–39% | 33–39% | 32–40% |

The seed's off-centre is at most 0.026 of the screen, on 16:9, 19.5:9 and 4:3. The turn, orbit and lens figures leave out cuts, the black of
the fade in and the hit's first 0.5 s. The hit has R152's shake (35% on phones) plus a roll kick of 2.5° on Secret and King and 1.5° on Cosmic.

## Tests

- **New: `docs/proposals/R155/tests/run_camera155.sh`.** It runs `test_rare_camera155.luau` and two other steps:
  - **0. Static checks:** the manifest; exactly 4 src files changed since R154 (the new module, the director, the card, the manifest); -O0
    compile within 180 registers; no R155 line writes Lighting; no per-frame table or closure.
  - **1. `test_rare_camera155.luau`, the rig on its own:**
    - cuts on their beats and sounds;
    - every comfort limit;
    - the dead stop, which is also the skip frame;
    - the depth of field modest and continuous;
    - the seed's framing on 3 screens through a 120 s wait;
    - the wait steady and never repeating;
    - the Calm stills;
    - clearance from every part of the real stages: with and without the drawn images, desktop and lite.
  - **1. `test_rare_camera155.luau`, the real director frame by frame at 30, 60 and 144 fps:**
    - before the stage, the camera is today's;
    - in the stage, it is the rig;
    - after the stage, it is restored exactly;
    - each cut is on the first frame of its beat, with its sound heard within 0.01 s;
    - `RarePullDof` is on exactly the stage frames, on desktop, phone and low quality and in Reduced Motion;
    - there is one render binding;
    - a 120 s wait, then the collect;
    - every way out (collect, skip, abort, death, character removed, moved, keeper, replaced camera, stage error, camera error, script
      destroyed);
    - a skip at 11 phases;
    - "Skip pack animations";
    - Common to Mythic never call the camera module, and their camera is today's.
  - **1. `test_rare_camera155.luau`, the SKIP button:**
    - where it goes on 11 screens (desktop, laptop, small windows, phones, tablets, portrait): on screen, clear of every HUD box, at the
      bottom right, thumb-sized on touch;
    - the real button frame by frame on cards and story scenes (6 cases), on a desktop, on a notched phone, and on screens whose reported
      safe area is bigger than the screen, all with a gamepad: it shows from SkipFrom; one spam click per frame never skips; it stays
      inside the safe area; its B badge shows; it sits above the scene's full-screen button; pressing it goes to the hit; it is gone
      after the hit.
  - **2. Byte for byte against the R154 release.** R152's seed-opening fingerprints (`run_perf152.sh`, `PERF_BASE=8aa15fd`, `ONLY=seed`)
    cover every rarity on desktop, phone and low quality at 60 and 30 fps, plus an onlooker's Secret and King. With `perf155_opts.luau`, the
    only differences allowed are the Camera's CFrame, Focus and FieldOfView while a story stage is on screen, `RarePullDof`, and the
    skip's own UI: the SKIP button, and the corner hint while it is not the collect hint (R154 wrote "CLICK TO SKIP" there).
- **Extended:**
  - R151 `test_rare_rules` checks the cinematic camera's framing and the stage box.
  - R151 `test_rare_cinematic` checks that `RarePullDof` is on every stage frame and gone on every way out, and covers the phone and Reduced
    Motion.
  - R151 `test_rare_world` checks that an onlooker's camera is never written.
  - R152 `test_seed_sync` and `test_seed_stress` check that no `RarePullDof` is left.
  - R152 `run_zfight_sweep.sh`, opening step: the camera keeps at least 0.7 stud from every visible part, on every stage frame. The z-fighting
    rule itself does not depend on the camera, and there are no new findings.
  - `perf152_fp.luau` loads `perf155_opts.luau` when it is there.
  - **The skip (owner's request):**
    - R151 `test_rare_cinematic`: spam on the scene's full-screen button does not skip; the SKIP button shows at the bottom right above it
      and skips; B collects; the button hides after the hit. On the cards, a world click no longer skips but the button does.
    - R152 `test_seed_choice`: every tier and presentation spams clicks, taps or the full-screen button through SkipFrom without a skip,
      then skips with the SKIP button, B, R2 or Enter. A burst through the moment the result lands neither skips nor collects, a press held
      from before does not collect, and the next tap does.
    - R152 `test_seed_press`: planting, the shovel, digging and giving with the SKIP button.
    - R152 `test_seed_collect`: an early collect skips with the SKIP button. A new block covers Rare and Mythic cards, the Cosmic and King
      scenes and a Secret in-place card: spam in every phase does nothing; the SKIP button or gamepad B skips; a short tap that began
      before the collect delay ended does not collect; the next fresh tap does.
- **Results on this checkout.** Every suite passes. Each was run on its own, one after another:

  | Suite | Result |
  | --- | --- |
  | R155 `run_camera155.sh` | static ok; `test_rare_camera155` 745 checks, 0 fails; against R154, all 15 seed fingerprint runs identical apart from the allowed differences |
  | R151 `run_rare_pull.sh only` | rules 499, cinematic 719, world 101: 0 fails |
  | R152 `run_seed_opening.sh only` | sync 4642, loudness 274, fx 608, stress 4552, choice 929, press 98, collect 790, server 240: 0 fails |
  | R152 `run_perf152.sh` (with the place) | the look and the sound identical, the patch on and off |
  | R152 `run_zfight_sweep.sh` (with the place) | the map, the 7 keyboard variants, Verity, the opening scenes (1023) and the Mech pack: PASS. Camera clearance: Secret 2.96 / 3.01, Cosmic 1.76 / 1.41, King 0.735 / 0.735 stud (with / without images) |
  | R152 `run_load_guard.sh` | 4 checks, 0 failures |
  | R153 `run_jitter.sh`, `run_hotbar.sh`, `run_mech_pack.sh`, `run_seed_rarity.sh`, `run.sh` | PASS |
  | R135, R138, R147 `run_verity_ui`, R149 `run_verity_pack`, R150 `run_sfx`, borders_R123 | PASS (the other suites that bundle the reveal modules) |
  | `tools/tests/check_compile_O0.sh` | every script compiles at -O0 within 180 registers |

  Against R154, the hidden SKIP button inside the card's fade-out screen (`RarePullRevealOut`) is also left out, as anything never drawn
  is.

## For the owner's eye (Studio)

- **The depth of field under Future lighting, on a phone.** It is light, and it is on everywhere by your choice. Lower `RarePullCamera155`
  `Dof.MaxFar` / `MaxNear` if it feels heavy.
- **King K2.** A light shaft, a candelabra, a herald's trumpet and its banner pass close to the lens: cinematic foreground, but busy.
- **VR players** get the moving camera, as today's camera already moves. The proposal suggested the Calm stills for VR. Say if you want that.
- **The SKIP button on a real phone.** On an 844×390 phone the corner belongs to the jump button, so the SKIP button sits just left of it and
  above the hotbar, at 58% of the height. Check that it is easy to reach with the right thumb. On a desktop it is in the corner, below the
  status / timers stack; on a 1920×1080 screen it sits left of that stack.
- **"Pity bars".** No pity bar is drawn on screen in this build. The button keeps clear of every HUD box, including the bottom-right status /
  timers stack, which is what the request seems to mean. Say if another bar is meant.
- **Gamepad.** B and R2 press the SKIP button and the button shows a red "B". Check it on a console controller in Studio.
