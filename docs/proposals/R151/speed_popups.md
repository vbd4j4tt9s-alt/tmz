# R151 proposal: speed-gain popups that move like the reference (PREVIEW, nothing in `src/` changed)

Owner: "speed gain should be touch up on regarding the speed popups we don't have to colour it black as seen in the video, keep ours white but the
physics and feel of it should feel the same as the video". Then: "show previews before implementation".

**Preview:** `speed_popups.png` (sheet: now / proposed / proposed with split awards / Reduced Motion at five moments, the measured curves, the numbers
side by side) and `speed_popups.gif` (now next to the proposal, 1.5 s, 470 KB). **Prototype:** `speed_popups/SpeedPopupStyle.lua` (every tunable number and the
pure curves) run by `sim_popups.luau`; `check_curves.luau` checks it (74 checks); `run_speed_popups_preview.sh <scratch>` rebuilds everything.

## What the game does today

The popups are in `src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua` (the first block; the second block, the V134 belt arrows, is not
a popup). The server (`BaseService`) fires `SpeedGainPopup` to ALL clients once per training tick (`Config.TrainingInterval = 1/6 s`, so 6 a second) with
the real award. Each client draws one `BillboardGui` per popup (`Instance.new` each time, destroyed at the end, one `TweenService` rise tween + two fade
tweens + a `task.delay`), 178x48 px, 26 px text, anchored to the HumanoidRootPart:

- rises 3.0 to 3.8 studs (Quad-out over `Config.TreadmillPopupLifetime` = 1.35 s) inside a +-15 degree cone, starts 1.25 studs above the head at full size;
- fades from 0.35 s over 1.0 s; at most 4 per player: **the 5th spawn destroys the oldest.** At 6 a second that happens after 0.67 s, so a popup is
  removed while still 90% opaque and only 60% of the way up. The 1.35 s lifetime is never seen.
- other players' popups are shown too (every client receives every award) when the head is within 100 studs of the camera, same 4-per-player cap.
- colours (kept): the amount is pale cyan `(125,248,255)` with a navy outline `(17,26,42)` thickness 2.5, the lightning glyph is `(255,222,66)`; font FredokaOne.
  **Note: the amount is pale cyan, not pure white.** The proposal keeps every colour exactly as it is (the owner's "keep ours"); making it pure white is
  one value, `Colors.Text`, if that is what was meant.
- the offset is in studs, so the distance it flies on screen follows the camera zoom (about 1.7 times as far at the default 12.5 stud zoom as in the preview).

## What was measured in the reference clip

Clip: 2560x1344, 30 fps (33.3 ms between frames), 113 frames, a player running on a treadmill with "+3.5K" popups and a blue shoe icon. The first ~25 frames
have a moving camera; frames 30 to 57 (0.98 to 1.9 s) have a nearly still one, and all tracking below comes from that window (spawn cadence also from the
early frames). The player's head is 55 px wide there. Every popup was followed frame by frame (icon colour segmentation plus looking at 2x crops); the
samples are in `reference_fit.py`, the results in `reference_numbers.json`. Nothing from the clip is kept in the repo, only these numbers.

| What | Measured | Based on |
|---|---|---|
| Spawn cadence | one new popup **every 0.100 s** (3 frames), regular to within a frame, so **10 a second**. Always the same "+3.5K". The legs' step cycle is faster than 30 fps can show (the red shoe's position alternates every frame), so "one per step" cannot be confirmed: it behaves like a 10 Hz timer | 15 births, frames 6 to 48 |
| Alive at once | **6 to 8** (about 6 solid, 1 to 2 fading, 2 just born); 10/s x 0.65 s = 6.5 | counts over the window |
| Spawn point | the **head centre**, within about 8 px (a few px above), already **0.4 to 0.6** of full size | 4 births |
| Pop | scale 0.5, 0.7, 0.9, 1.0, 1.06 over the first 5 frames; peak about **1.06** (single popups up to 1.13) around 0.13 s; 1.0 by about 0.25 s | 3 popups |
| Direction | a loose **fan above the head**: -48 to +72 degrees from straight up (mean 2, sd 43), both sides, more sideways than straight up | 7 resting spots |
| Distance (head to resting spot) | 50 to 134 px of 1344, **mean 97 px = 1.8 head widths = 78 px on a 1080 p screen**; up 33 to 97 px (mean 71), sideways up to 105 px | 7 resting spots |
| Easing | **cubic ease-out, 0.40 s**: squared error 50 (Quad-out 123 at 0.31 s, Quart-out 46 at 0.48 s, Linear 580). Initial speed about 700 px/s, 50% of the trip in 0.08 s, 90% in 0.21 s, then it rests with no drift or gravity | 4 tracks, 12 to 15 frames each |
| Hold and fade | opaque about **0.45 to 0.50 s**, then fades in **0.09 to 0.17 s** (mean 0.145), roughly linear, icon and number together; gone at about **0.65 s** | 3 fades |
| Size | icon about 25 px, "+3.5K" about 80 x 24 px (1.8% of the screen height), the same while the camera moved about 15% | weak evidence for "fixed on screen" |
| Look | black number with a light outline, blue shoe: **not copied** (ours stays) | |

Limits: small samples (7 resting spots, 4 flight tracks, 3 fades), 30 fps, and the camera zoom only changed about 15%, so "constant on screen" is
a good fit rather than proven. The numbers describe the feel; they are not exact constants of that game.

## What would change (proposal, in `SpeedPopupStyle.lua`)

All values are "design px at a 1080 p screen" times `Unit(viewport height)` (0.8 on phones, up to 1.35), so they read the same at any camera distance.

| | now | proposed |
|---|---|---|
| spawn | 6/s, 1 per award, 1.25 studs above the head | 6/s, 1 per award (the number stays the real award), **at the head** (5 px up, +-6 px) |
| pop | none | scale 0.45 to 1.0 in 0.28 s, back-out (7% overshoot, peak 1.07 at 0.16 s) |
| direction | +-15 degree cone | **fan of +-75 degrees**, 7 slots shuffled per player (+-9 degrees), so two in a row never share a spot |
| distance | 3.0 to 3.8 studs | **44 to 104 px**, from the head, at any zoom |
| easing | Quad-out 1.35 s | **cubic-out 0.40 s**, then it rests |
| fade | from 0.35 s over 1.0 s | opaque to 0.50 s, **linear 0.15 s**; gone at **0.65 s** |
| size | text 26, icon 24, box 178x48 (icon far from the number) | text 22, icon 20, icon and number together |
| cap | 4 per player, the oldest is destroyed on the spot | by tier: **own 8 / 6 / 4, others 3 / 2 / 1** (tier 3 / 2 / 1; phones start at 2; FastMode is 1); a popup over the cap fades in 0.08 s instead of vanishing |
| Reduced Motion | same as normal | no fling, no pop: appears at the head, rises 72 px in 0.7 s, fades; sides alternate; own 4, others 1 |
| colours, font, icon | pale cyan number, navy outline, yellow bolt, FredokaOne | **unchanged** |

Optional (off by default, `Cadence.SplitTo`): the clip's 10 a second needs more popups than the server's 6 awards a second. Each award can be shown as 2 popups of
equal share (sum kept exactly, never below 1 point each), 12 a second, 7.8 alive at once like the clip's 6 to 8. It costs nothing on the server and the
HUD total is the same; the numbers on the popups get smaller. The preview shows both. Owner's call.

How it would be built (not done yet): `SpeedGainPopup.client.lua` (first block only) keeps the remote and its checks; per visible player ONE
`BillboardGui` ("field", fixed pixel size, AlwaysOnTop, MaxDistance 100 as now) holds a small pool of reusable popups (a Frame with the icon, the number and a UIScale),
moved by pixel offsets; ONE updater (RenderStepped, connected only while a popup is alive) moves all of them; no `TweenService`, no `task.delay`, no
Instance created or destroyed after the pool exists (so nothing to leak). Other players' fields are created only for players within 100 studs and use the smaller caps.

## Decisions needed before implementing

1. Colours: keep exactly as they are (pale cyan number), or make the number pure white?
2. Density: keep one popup per award (6 a second), or split awards to about 12 a second like the clip?
3. Where the numbers live: no existing module holds them today (they are inline in the script). Proposal: a new small `ReplicatedStorage/SpeedPopupStyle.lua` (pure data
   and curves, like `TreadmillBonusStyle`). `TreadmillFx` (the tier effects) is a file other work on the treadmills touches, so it is avoided. OK?
4. `Config.TreadmillPopupLifetime` (1.35) would no longer drive the popups (the lifetime becomes 0.65 s in the style module); it stays in `Config` untouched so nothing breaks.
