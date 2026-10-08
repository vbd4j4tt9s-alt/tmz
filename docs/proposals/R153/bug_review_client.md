# R153 bug review: client side

Scope: UI, input, effects, sounds, camera, physics feel and phone support. The release head is R153 in progress (`claude/compassionate-brown-lohfok`). The R152 head is `e36b71b`: 89 commits and 99 changed client-side files since then. A second review covers the server, data and economy.

Method: I read every R153 client change against the notes in `docs/proposals/R153/*.md`. I proved four findings on the Luau mock by adding a probe block to a scratch copy of an existing suite. The probes used `R149/tests/test_keyboard.luau` (672 checks, unchanged) and `R153/tests/test_hub_gardens.luau` with the owner's place. Nothing under `src/` was changed. The scratch files have been deleted.

No Blocker or High findings. Nothing errors, no script stops, no modal gets stuck. All 99 changed files compile. The most visible problem is the owner's old one, floating dirt, which comes back on the keyboard track in two new ways (findings 1 and 2).

## Findings, ranked

### 1. Medium: a hole dug near a pack platform floats 1.2 studs over a pressed key

- **Where:** `src/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua:1283` (the platform keys are pressed with `touch(s,0,...)`, which skips the `holeCell` guard that `pressCell` has at `:987`). Also `:1148-1149`, where `holeCell` and `platCell` are built independently and a key can be in both. `src/ReplicatedStorage/TrackHoleConfig.lua:33` (`PackClearance=10`).
- **Scenario:**
  1. Dig a hole 10 to about 14 studs from a small pack on the keyboard track. The server allows anything from `PackClearance` = 10 studs up.
  2. The hole keeps the keys under its 6 x 6 stud box up (`HoleReach` 3). The platform holds the keys under its box down (radius + 0.3).
  3. Keys are 8.18 studs wide, so one key often lies under both boxes.
  4. **Wrong result:** the platform presses that key down 1.15 studs. The pit and rim are lifted to the resting key top, so the dark hole hovers over the dip for as long as the pack and the hole exist.
- **Confidence:** proven on the mock. Setup: a pack of platform radius 1.0, and a hole exactly 10.00 studs away. Result: key column 14 lies under the pit and is held at 4.050 (rest 5.200). The pit bottom is at 5.260, so **the pit floats 1.21 studs** over that key.
- **Fix:**
  - Client: let the hole win. Skip `holeCell` keys in the platform loop (`if s and not holeCell[key] then touch(...)`), or drop them from `platList` in `rebuildClearances`.
  - Server: refuse a dig spot whose hole box shares a key with a platform. Or raise the pack clearance to at least `HoleReach + platform radius + 0.3 + one key pitch` (about 13 to 16).

### 2. Low: hole crumbs outside `HoleReach` float whenever someone steps on the key under them

- **Where:** `src/ServerScriptService/ChestChaseServer/TrackHoleService.lua:171` (crumbs at `rimD/2 + 0.1..1.1` = 3.1 to 4.1 studs from the centre). `src/ReplicatedStorage/KeyboardTrack.lua:59` (`HoleReach=3` covers only the rim). `KeyboardTrack.client.lua:1172-1175` (the reach box, ±3) and `:1113-1121` (every hole part is lifted to the resting key top).
- **Scenario:**
  1. A hole is dug on the keyboard.
  2. Some crumbs land past the ±3 box, mostly near the hole's axes, over a neighbouring key that can still be pressed.
  3. **Wrong result:** a runner steps on that key, and the lifted crumb hangs in the air until the key comes back up.
  4. A Monte Carlo run of the server's crumb placement on the 8.18 grid puts about 28% of keyboard holes with at least one such crumb (0.47 per hole).
- **Confidence:** proven on the mock. Setup: a hole 1 stud off its key's centre, and a crumb at the server's largest radius. The crumb lies over the next key (column 5). That key goes from 5.200 to 4.050 when stepped on; the crumb's bottom stays at 5.210, a **1.16-stud gap**.
- **Fix:** either grow `HoleReach` to cover the crumb ring (`rimD/2 + 1.1 + 0.25` ≈ 4.4), or keep crumbs inside the reach. For example, draw crumbs within `HoleReach - size/2`, or draw them on the rim. Either way, add a crumb at the largest server radius to the R149 hole check. Today that check uses `rimD/2 + .3` only.

### 3. Low: the trampoline mat sinks for good if the client looks at the folder again mid-squash

- **Where:** `src/StarterPlayer/StarterPlayerScripts/HubTrampoline153.client.lua:29-30`. `collect()` runs `table.clear(spots);table.clear(active)` without putting a squashing mat back, then records `MatCF = mat.CFrame` again. The trigger is at `:41-45`: `refresh()` twice a second when the folder's child count, `Looks`, or a mat's presence changes.
- **Scenario:**
  1. Someone bounces, so the mat dips for 0.6 s.
  2. During the dip, the folder changes. The other nook's trampoline streams in or out (StreamOutBehavior is Opportunistic), a mat streams in late, or the server finishes dressing the look.
  3. **Wrong result:** the mat stays at its dipped height, and that height becomes its new "rest". Every later squash dips from there. Repeats compound, and the mat can sink below the "mat top stays over the dark gap" limit the rules promise.
- **Confidence:** proven on the mock. Setup: real client and owner's place; the folder gained a child 2 frames after a bounce. Result: rest y 4.740; the mat was at 4.599 when the folder changed; 1 s later it still rests at 4.599 and the client calls 4.599 its rest pose (**sunk 0.141 studs**).
- **Fix:** in `collect()`, first put every active squash back (`s.Mat.CFrame=s.MatCF; if s.Badge then s.Badge.CFrame=s.BadgeCF end`), then clear. Or keep each part's rest frame in a weak table keyed by the part, the way `KeyboardTrack`'s `liftBase` does.

### 4. Low: other players' landings on the keyboard no longer click

- **Where:** `src/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua:1030-1039`. `runnerKind` returns 4, a silent press, for a remote runner whose feet are 1.2 to 3 studs over the floor. Then `:978` (`if not downPos[idx]then pressKey`) never presses the already-down key again, and `:965` only remembers a silent press for the same frame (`mutedAt`).
- **Scenario:**
  1. Another player hops along the keyboard track.
  2. On the way down, the 30 Hz sample usually catches their feet in the 1.2 to 3 stud band. The key under them goes down silently.
  3. **Wrong result:** they land on a key that is already down, so the landing makes no click. Yours still clicks, because your own presses need `FloorMaterial` ≠ Air. R152 clicked on the landing.
- **Confidence:** proven on the mock. Setup: another player falls from feet 6 studs up at 50 studs/s onto a fresh key. Result: **0 clicks** (twice), key down. The same hop by you: 1 click.
- **Fix:**
  - Treat a falling, non-thrown remote runner above `StepReach` as off the keys (return nil, not 4).
  - Or remember who pressed a key silently, and play the click once when that same runner reaches the key grounded (kind 2) while it is still down.

### 5. Low: `KeeperFollow153` anchors are still built and moved every frame, and nothing reads them

- **Where:** `src/StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua:91,148`, `src/StarterPlayer/StarterPlayerScripts/VeiledEventClient81.client.lua:58`, `src/ReplicatedStorage/KeeperFollow153.lua`.
- **Scenario:**
  1. The keeper-sign merge (`98bf7fb`) pinned the signs at spawn, so `KeeperSpeedLabels` no longer uses the follow anchor. A repo-wide grep finds no `Follow.Get` or `Follow.Listen` caller.
  2. **Wrong result:** BeastAnimation still makes one part per keeper in `workspace._KeeperFollow153`. It pushes that part into the BulkMoveTo batch every frame the keeper moves, even when the keeper's own pose is skipped (asleep, off screen). VeiledEventClient81 does the same for The Darkened.
  3. The cost is a BulkMoveTo (FireCFrameChanged) per frame for nothing.
- **Confidence:** read in code.
- **Fix:** remove the `Follow.Drive`, `Push` and `Release` calls (and the module), or only drive anchors while `F.Listen` has a listener.

### 6. Low: a trampoline launch can be pulled back by MovementGuard after a short network hitch

- **Where:** `src/ServerScriptService/ChestChaseServer/MovementGuard.lua:93-94`. `riseAllowance = 18 + max(jump,48,…)*elapsed*1.5`, about 25.5 studs per 0.1 s check for a new player. Then `src/StarterPlayer/StarterPlayerScripts/HubTrampoline153.client.lua:89` and `src/ReplicatedStorage/HubTrampolineRules153.lua:8-9`.
- **Scenario:**
  1. The bounce sets 108.5 studs/s upward (30 studs). The rise over a window τ is `108.5τ − 98.1τ²`: 9.9 studs at 0.1 s (fine), 23.7 at 0.30 s, 26.0 at 0.35 s.
  2. When a phone's position updates bunch up (no update for about 0.35 s at the launch), the server checks a still frame, then sees the whole rise in one 0.1 s check.
  3. **Wrong result:** the player is put back to the mat with zero velocity, and the bounce stutters.
  4. With the Studio attribute at its allowed `MaxHeight` 40 (125 studs/s), a 0.25 s hitch is enough.
- **Confidence:** read in code, from the arithmetic. The existing test only checks the 0.1 s window.
- **Fix:** on the server, when the last accepted frame is over a trampoline (`HubTrampolineRules153.OnMat` on the server's own copy of the position), allow `T.Height()` plus a margin for the rise. Or give a short grace while the root is above a mat.

### 7. Low: the 1.5x reward dot covers the count on the Index biome tabs

- **Where:** `src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua:150` (dot `Badge.Sizes.Dot` 21 px, overhang −4) and `:324` (count label, centred), with `src/ReplicatedStorage/NotifyBadge151.lua:29-30`.
- **Scenario:**
  1. A biome tab has an unclaimed reward, so its dot shows.
  2. On PC (tab 122 x 58), the dot covers x 97–118 / y 4–25. The centred count ("18 / 40", 14 px) sits at about x 62–112 / y 17–31.
  3. On a phone's compact tab (106 x 40), the dot covers x 81–102 / y 4–25 and the text sits at about x 50–94 / y 12–24.
  4. **Wrong result:** the red dot (z 20) sits on the last digits, and the pop and halo spread further. The R151 14 px dot only touched the text's top edge.
- **Confidence:** read in code (layout arithmetic).
- **Fix:** while the dot shows, narrow the count label by the dot's size (`Size.X − Badge.Sizes.Dot − 4`). Or place the tab dot top-left over the logo, or keep the 14 px dot for these tabs.

### 8. Low: the pending ring ignores Reduced Motion

- **Where:** `src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua:266` (`r.Ring.Transparency=.1+.5*(.5+.5*math.sin(os.clock()*9))`).
- **Scenario:** with Reduced Motion on, press a pack. **Wrong result:** its slot's green ring pulses at about 1.4 Hz for up to 4 s (longer when queued). The new-pack rainbow in the same file holds still under Reduced Motion (`calm`), but this ring does not.
- **Confidence:** read in code.
- **Fix:** with `GuiService.ReducedMotionEnabled`, use a steady transparency (for example 0.25).

### 9. Low: a queued hotbar press cannot be cancelled and never times out

- **Where:** `src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua:220` (a second press on the pending key is ignored) and `:428-431`. A `Queued` wait has no time limit; the 4 s limit applies only to a press that was not queued.
- **Scenario:**
  1. Press pack A during a pack reveal (now always the full presentation) or while knocked down. A is queued.
  2. **Wrong result:** pressing A again to change your mind logs "already on its way, press ignored". The pack is held when the reveal ends anyway.
  3. If the carried seed's `RevealAt` never clears (a reveal the server fails to finish), slot A stays dead with a pulsing ring until respawn. Meanwhile the tick runs every frame.
- **Confidence:** read in code. The stuck case depends on the server.
- **Fix:** a second press on a queued item cancels it (`pending=nil` and a note). Cap queued waits too (for example 20 s), then drop the wait with a note.

### 10. Low: the "ALMOST THERE!" wiggle swallows the ready pop of the bonus roll button

- **Where:** `src/StarterPlayer/StarterPlayerScripts/TreadmillBonusClient.client.lua:248-257` (`playAlmost` writes `pulse.Scale` and the icon rotation every frame for 0.75 s) and `:268-273` (`applyPhase` only bumps a token; the effect in flight keeps running).
- **Scenario:**
  1. A roll completes during one of the 0.75 s almost-bursts. They run every 2.2 s, so this happens about one time in three.
  2. `readyMoment` starts `popButton` (scale 0.72 → 1 tween).
  3. **Wrong result:** the almost effect keeps overwriting `pulse.Scale` in RenderStepped until it ends, so the ready pop is not seen.
- **Confidence:** read in code.
- **Fix:** keep the function `addEffect` returns for the almost-burst. In `applyPhase`, on leaving 'almost', `cancelEffect` it and reset the scale and rotation before the pop.

## Areas checked and found clean (21)

1. **Hotbar rewrite:**
   - Press pairing (InputBegan / MouseButton1Down, either order).
   - Touch identity with two thumbs, and the stale mouse release.
   - Activated deduplication, 12 px drag, 0.4 s phone hold, ghost and lights.
   - Drop onto a slot, slot 1 and the Bag button / sheet; `State:Place` / `Stow` / `Ensure` on hidden slots.
   - Respawn order (`Remember` twice across CharacterRemoving and the new Backpack), key renames.
   - Number keys while typing, L1 / R1 cycling, Bag toggle, the CoreGui backpack, cleanup on Destroying.
2. **Pack-opening skip and `ClaimPress`:**
   - One answer per press across the planting, shovel, digging and giving routes plus the listener.
   - Presses on GUI ignored (hotbar, jump button). A camera drag is not a tap. A run of clicks never skips.
   - `ManualActivationOnly` put back on every exit path (equip swap, finish, replace, respawn).
   - R2 / B / Enter; the scene binds R2 above TrackHoleDig.
3. **"Skip pack animations":** the toggle is validated as a boolean and saved. The server publishes it at load, the client on change. Owner previews ignore it.
4. **Bonus roll button and `EmbeddedImage153`:**
   - Decode slices, the checksum, one shared EditableImage with a reference count, the fallback route, release on Destroying.
   - The 4 Hz ticker only while training; the almost-loop token; the "BONUS READY! / OPEN IT!" hold; the clipped CanvasGroup fill; the Secret tease never replaces the winning card.
5. **Clover icon:** pass icon, then the drawn picture, then shapes, switching by itself. The drawn picture is let go once the pass icon loads. The ROBUX SOON card layout. Purchase pop cleanup.
6. **Hub avatar client dance and watchdog:** one track only, retries then the fallback pose, paused only for Reduced Motion or Fast Mode, an R15 rig forced on the server, the pose writes only for a posed rig.
7. **Biome notifier B:** sizes per screen class (667x375 and 375x667 fit), HudNotices slotting, fade and dismiss, respawn reset, Reduced Motion.
8. **Badges 1.5x:** every badge's `Extent` fits in HudLayout's 16 px margin (INDEX 15, MENU 14). The DAILY badge stays inside the corner. The only problem is finding 7.
9. **Speed popups 2x:** the fan scaled to the screen (`FanScale` fields exist), the field on the root, reduced caps.
10. **Belt scrolling:** the scroll gate (near, on screen, not Reduced Motion, any tier), one clock per belt, offset written on change, the axis / sign override.
11. **Fling swoosh:** packet validation (`Cause` excludes bats), monotonic ids, a voice cap where your own swoosh always plays, Effects group via AudioMixer, Debris / Ended cleanup.
12. **Keyboard grounded-step rule for you:** `K.Steps` / `K.Thrown`, keepers silent, thrown bodies press silently. The only problem is the remote landing, finding 4.
13. **Jitter sweep:** every moved effect stays inside its visibility, distance or count gate.
    - World and items: ItemCosmetics, SeedPackRender, SeedPackClient, HeldHarvests, RunnerTrail*, the GardenVisuals fast pass, LavaFlow, HomeMarker, VoidGiveaway in / out of view.
    - Keepers and Verity: VeiledEventClient81 posing and spin distances; the Verity bounce spring (checked as an exact critically damped solution).
    - UI previews and pull effects: ShopViewport / CollectionViewport tier caps, GuiShine, GardenCardMotion, PackViewport89, RarePullFx 1/256 cache, RarePullWorld mouth part.
14. **Keeper signs pinned at spawn:** the anchor cannot be collided with, touched or ray-hit. `KeeperHome` is stamped after the home is known. Debounce / quiet / re-arm on the mesh swap. Cleanup on untag and on Destroying.
15. **Refresh barrier in the gate:** the opening fits between the tower shafts with a 0.4 stud gap (no way through). The sign scales with `Fit`, and `Center` re-centres on every count.
16. **Daily silhouettes, quest rows and the ALL DONE row:** the silhouette has its own picture-cache key (`|Dark`), so no real pack picture turns black. The rows fit short panels. Claim routing works for the bonus row.
17. **Trampoline bounce rules:** debounce, no stacking, guards for ragdoll / seat / anchored / dead, Reduced Motion, squash only while moving. The problems are findings 3 and 6.
18. **Track hole client:** the tip counter, `ClaimPress` before a dig, the dirt toss lifted onto the key tops.
19. **Static checks on all 99 changed client-side files:**
    - They all compile (`luau-compile`).
    - No unknown globals (`luau-analyze`), and every `WaitForChild` / require target exists.
    - `MANIFEST.tsv` matches the files both ways.
    - Line 1 of every client script is the R152 load guard, except the two documented exceptions (BackgroundMusic, the ReplicatedFirst title screen).
20. **PullAnnouncerClient:** a held chat line goes out sooner after a skip, and never later than its first wait.
21. **Settings panel:** the new row and its canvas (scrolls on short phones), and the Replay button moved below it.
