# R158 bats: swing animation and effects (preview)

**BUILT (R158, 10 Oct): see `bats.md` section 6; the owner chose no camera shake for the hitter, no "SMACK!" word, a white trail. The text below is the plan as approved.
After the code review (`hitbox.md` section 7) your own hit's server packet is recognised by the hitter it names (`AttackerUserId`), not by a swing
number: only your own hits are skipped on your screen; someone else's hit on the same player is shown. No "SMACK" notice at all any more.**

PREVIEW, nothing in `src/` changes until the owner approves. Owner: "polish up the animations ... a reference video will be sent for the
animation polish and effect work". Pictures: **`swing_preview.png`** (reference vs today vs proposed, R15 and R6, timing chart, top views,
effects) and **`swing_preview.gif`** (reference / today / proposed side by side, half speed). The renders are **approximate** (see section 6).

## 1. The reference video, measured

`Roblox-2026-10-09T23_40_57.826Z.mp4`, 6.6 s, 2560 x 1344. The file is variable frame rate (frame n is at about n / 30 - 0.02 s), so every time
below is the frame's own timestamp (+-1 frame, 0.033 s). Read frame by frame at full rate, cropped on the player (one camera, mostly in front
of the player).

| swing | starts (s) | load (bat goes back) | coil / hold (bat behind the head) | strike (2 frames) | contact after start | follow-through | recovery (back upright) | total |
|---|---|---|---|---|---|---|---|---|
| 1 (standing, camera still) | 0.39 | 0.06 | 0.20 | 0.646 -> 0.712 | 0.29 | 0.27 | 0.30 | 0.89 |
| 2 (camera turning) | 1.64 | 0.07 | 0.20 | 1.913 -> 1.947 | 0.29 | 0.33 | 0.13 | 0.77 |
| 3 (walking, seen from behind) | 2.93 | 0.05 | 0.20 | 3.180 -> 3.247 | 0.28 | 0.27 | 0.27 | 0.85 |
| 4 (walking) | 4.20 | 0.08 | 0.17 | 4.446 -> 4.514 | 0.28 | (video ends) | | |

- **Rhythm:** a new swing every 1.25-1.29 s (that game's cooldown or the player's clicking). Ours: `Cooldown` 1.0 s.
- **Contact 0.28-0.29 s after the start**, the same as our server's `Windup` 0.30 s. The proposal keeps 0.30, so hit timing does not move.
- **What it looks like:** idle = bat upright in front of the right shoulder, hand at the chest (the same as our tool hold). Load = the right hand
  jumps up beside the head and the bat drops **behind the head, pointing to the player's left** (0.05-0.08 s). Coil = held there ~0.2 s while
  the shoulders turn a little to the right (it never looks frozen). Strike = in two frames the bat comes **round the right side and sweeps
  flat across the front at hip height**, ending straight out to the **left**. Follow-through = the upper body keeps turning left (seen from the
  front you nearly see the back), the bat **wraps low to the left / behind** and stays there ~0.25 s (the weight). Recovery = the body turns
  back and the bat **rises in front** to upright. The legs keep walking (swings 3 and 4): upper body only. The body seems to spin a lot; the
  shoes stay facing the camera in swing 1, so it reads as a strong torso twist, not the whole character turning (one camera, so not certain).
- No target is hit in the clip: there is no impact effect to copy.

## 2. Today's swing (`BatSwingPose.lua`, R112)

| phase | time (s) | what it does |
|---|---|---|
| wind back | 0 - 0.135 | smooth blend to the bat cocked behind the head |
| hold | 0.135 - 0.165 | frozen |
| whip | 0.165 - 0.30 | over the top (the bat goes **up and over**), ease-in |
| contact | 0.30 | bat tip 6.7 studs ahead at **shoulder height (5.5)**, the server's hit time |
| follow-through | 0.30 - 0.432 | **chops down** in front, tip near the ground (1.4) |
| settle | 0.432 - 0.74 | blends back to the tool hold |

Measured on the render rig: the tip peaks at **343 studs/s just before contact, then drops to 74** (a dead stop at the hit). Versus the reference:
a **vertical chop** instead of a **flat sweep**, a short 0.03 s frozen hold instead of a living 0.2 s coil, a 0.13 s follow-through instead of a
0.27 s one, and on your own screen it **starts one ping late** (it waits for the server, `hitbox.md` RC3).

## 3. The proposed swing (`preview/BatSwingPose158.luau`, same API as `BatSwingPose`)

`BatClient` would only swap the module (and start your own swing at the click, see `hitbox.md` 4.1). Total **0.85 s** (reference 0.77-0.89; the
1.0 s cooldown still leaves 0.15 s at rest).

| key | time (s) | bat | body | easing into this key |
|---|---|---|---|---|
| rest | 0 | upright in front of the right shoulder (the tool hold) | | |
| A load | 0.07 | hand beside the right ear, bat behind the head pointing left-back | shoulders turn 25 degrees right | ease-out (fast start), from the Animator's pose |
| A2 coil | 0.22 | the same, a little deeper | 35 degrees right, slight lean | smoothstep: a slow drift, never frozen |
| B | 0.26 | swung round behind to the right side, pointing back-right | 15 degrees right, leaning in | ease-in (accelerating) ... |
| **C contact** | **0.30** | **straight ahead, flat, at hip height** | square, 12 degrees forward lean | ... fastest here |
| D through | 0.335 | straight out to the left | 38 degrees left | linear (keeps its speed) |
| E follow-through | 0.52 (held to 0.60) | wrapped low to the left / behind | 55 degrees left, leaning | ease-out cubic (slows down: the weight) |
| F recovery | 0.72 | rising in front | 22 degrees left | smoothstep |
| rest | 0.85 | upright | | smoothstep blend back to the Animator's pose |

Measured on the render rig: the tip sweeps from **120 degrees right (0.258 s) through straight ahead (0.30) to 81 degrees left (0.358)**, 200
degrees in 0.1 s; at contact it is **7.8 studs ahead at 3.1 studs high** (hip height on the game's 1.25-scale bodies); tip speed ~470 studs/s
just before contact and ~285 just after (today: 343 -> 74), so the bat carries through the hit. The hit window of the new hit check (0.24-0.36 s,
`hitbox.md`) is exactly this sweep.

**How the keys were made:** each key is designed as "where the hand holds the bat, where the bat points, how the waist turns"
(`preview/solve_keys158.py`), and the arm angles are fitted to that on an approximate blocky rig (hand within 0.35 studs, bat direction within
2.2 degrees on R15). `preview/make_pose158.py` writes the module. The angles are `CFrame.Angles` degrees in parent space like today's module.

**R15 and R6** (the game supports both, `BatSwingPose` / `BatClient` check `RigType`):
- R15 joints written: RightShoulder, RightElbow, RightWrist, LeftShoulder, LeftElbow, Waist (as today).
- R6 gets **its own keys** for the one-piece right arm (today R6 reuses the R15 hand angles composed): fitted so the bat points the same way
  (within 3.1 degrees), the hand lands up to ~1.9 studs from the R15 hand (a straight arm cannot bend). R6's `RootJoint` turns the **whole**
  body (legs too), so R6 gets 60 % of the twist and no lean.

**Running, jumping, carrying:**
- Upper body only: the legs (and on R15 the lower torso) stay with the Animator, so you keep running / jumping under the swing, as in the
  reference (swings 3 and 4). On R15 the waist twist rides on the running hips. Nothing is written to the legs, so no crouch: a 12-degree lean
  gives the "into it" feel without fighting the run animation (a real crouch would need the hips and knees).
- Swinging while carrying a stolen pack: the Hotbar only blocks pack tools while carrying, so the bat can be swung. Today `SeedPackClient`
  (the carry pose, both arms forward) and `BatClient` both write the arm joints in the same `PreSimulation` step; which one wins depends on
  script order. Proposal: while a swing plays, the carry pose leaves the right arm and the waist alone (0.85 s). Check in Studio.

**Other clients** see your swing exactly as today (they join late by your ping and skip ahead with `Lead`).

## 4. Proposed effects (all cheap: made once and reused, nothing new per frame)

| effect | today | proposed |
|---|---|---|
| **swing trail** | none | One `Trail` per visible bat, made once by `BatClient` when it first sees the bat, between two Attachments on the barrel (mid and tip). On only from 0.21 to 0.40 s of the swing (`Trail:Clear()` first), `Lifetime` 0.12, transparency 0.2 -> 1, width tapering, `LightEmission` 0.6. Off in Fast Mode / low graphics and beyond 150 studs (`SwingSoundRange`). Colour: **owner's choice** (white, or the swinger's runner trail colour; there is only one bat, so "by rarity" does not apply). The white ribbon in the pictures. |
| **impact** | `KeeperHitEffects`: slap sound + an 8-ray star (a new Part + BillboardGui + 8 Frames per hit, Debris) + camera kick | The same star from a **pool of 4** made once, plus **one shared spark emitter** (`ParticleEmitter:Emit(10)`, 0.25 s) at the contact point; a **0.05 s hit-stop** of the swinger's own pose (its pose clock pauses for 3 frames; server timing unchanged). Shown in the effects panel of `swing_preview.png`. |
| **your hit, instantly** | you hear / see your hit when the server's packet arrives (a ping later) | your client plays the slap + spark the moment its sweep finds the victim (it is the claim it just sent); the server's packet for that swing is then skipped on your client (by swing `Serial`; LocalSfx's 35 ms de-dupe is too short for a ping). Everyone else: on the server's packet, as today. |
| **camera shake** | the victim 1.0 (+ flash, red edges); anyone within 38 studs 0.18 x (1 - distance / 38), so the hitter at ~8 studs gets ~0.14 | the hitter gets a fixed small kick (0.35) on its own hit; victim and bystanders as today; Reduced Motion still turns it off. **Owner's choice: yes / no.** |
| **whiff (miss)** | the whoosh (9120768742, pitch 1.4, volume .25) plays on every swing, timed to peak at contact (R150) | the same sound is the whiff; for the swinger it now starts with the click instead of a ping later. No new sound. |
| **"SMACK!" word** | only in the notices ("SMACK! PACK DROPPED") | optional: a small "SMACK!" pop (white, black outline) at the hit for players within 60 studs, 0.45 s, from the same pool. **Owner's choice: yes / no.** |

## 5. What would change (after approval)
`BatSwingPose.lua` (the new keys and timing), `BatClient.client.lua` (start at the click, trail, instant hit feedback, hit-stop, the hit sweep),
`BatConfig.lua` (timing and effect numbers), `KeeperHitEffects.client.lua` (pooled star + sparks, hitter kick), `SeedPackClient.client.lua`
(leave the right arm to the bat during a swing). The server's hit time (`Windup` 0.30) and the cooldown stay.

## 6. How the pictures were made (approximate)
`sh preview/run_swing_preview158.sh <scratch> [node_modules with three]`: solves the keys, writes the module, samples the **real**
`src/ReplicatedStorage/BatSwingPose.lua` (today) and `BatSwingPose158.luau` (proposed) through BatClient's overlay math on an exact CFrame
(`preview/dump_poses158.luau`), and draws them with three.js in headless Chromium (`swing_render158.html`, `render_swing158.mjs`), then cuts
the reference frames from the owner's video and composes the sheet and the GIF (`make_swing_preview158.py`).
Approximations: a blocky R15 / R6 rig with classic proportions at the game's 1.25 scale (not the owner's avatars); the game's **fallback** bat
(`BatArt.Fallback` x 1.5, 6.6 studs; the imported bat is 6.9 studs and its grip point comes from the asset); the Animator's pose under the swing is the default tool hold with the legs
standing (in the game the legs run); no Roblox lighting or materials; `CFrame:Lerp` assumed to take the shortest turn.

## 7. To check in Studio
- The look on real avatars: R15 with AnimationConstraints, Rthro / scaled bodies (the hand may clip the head in the load on wide heads), R6.
- The swing while running, jumping and carrying a pack (the carry pose conflict above).
- The trail Attachments on the imported bat mesh (its barrel position comes from the asset).
- Volumes: the slap at the instant (predicted) hit and the whoosh together.
