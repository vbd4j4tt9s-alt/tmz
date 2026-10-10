# R150 review: bonus roll UI, mystery pedestal, SFX fix round

Reviewer pass, findings only. No game code is changed. Scope: `git diff 3ae5bb4..HEAD -- src tools` (HEAD = `036f634`, 59 files, +1,871 / -314). It has three parts:

- **Bonus roll polish** (`14b48cd`): the `TreadmillBonusClient` rewrite, plus the new `TreadmillBonusStyle` and `BonusGiftArt`.
- **Mystery pedestal polish** (`dcb5d8d`):
  - new `MysteryPedestalArt` (server) and `MysteryPedestalFx` (client);
  - the `MysteryPackClient` rewrite;
  - changes to `MysteryPackService` and `MysteryPackRules`.
- **SFX fix round** (`036f634`, 49 files). The intent is in `sfx_audit.md`.

The owner has R149 (`3ae5bb4`) installed.

**How each finding was checked**

I read every changed file in full. I also read the callers they touch:

| Area | Callers read |
|---|---|
| Notices | SimpleGameText, NoticeFeed83 |
| Index | ChestIndex alerts, PremiumProgress seed rewards, `PlayerDataService:OpenSeedPack` |
| Treadmill and bonus | BaseService training, TreadmillBonusService |
| Keepers | BeastAnimation slam timing |
| Bat | BatSwingPose |
| Harvest | HarvestArrival |
| Feedback | ButtonHighlights, InteractionFeedback |
| Prompts and travel | GardenUpgradeService press, FastTravelService, TravelButtons layout |
| Packs | SeedPackVisuals.Bag (tags and collision of the cloned pack) |

**Labels**

- **CONFIRMED**: shown by the code, by arithmetic, or by running the mock.
- **PLAUSIBLE**: depends on engine behaviour the mock cannot prove. Each one says what to look at in Studio.
- **Live gap**: *yes* when the mock passes but live Roblox can behave differently.

## Ranked list

| # | Finding | Kind | Status | Severity | Live gap |
|---|---|---|---|---|---|
| 1 | New Index badge chime (GemClaim) plays when a pack is **opened**, before the reveal shows the seed. It happens on most openings (any seed with no reward waiting) | UX / audio | CONFIRMED (code path) | **should-fix (high)** | no |
| 2 | Reveal confetti flies over the ribbon header ("TRLA.JMILL") | UX | CONFIRMED (stills + mock) | should-fix | no |
| 3 | The reveal word pops from its **top-left corner**: for Legendary and up it slides about 250 px from the left while it grows | UX | CONFIRMED (mock layout model) / PLAUSIBLE (engine pivot) | should-fix | no* |
| 4 | Follow-up E1: bonus-roll refusals make no Denied sound | audio | CONFIRMED | should-fix (requested) | no |
| 5 | Follow-up E2: the mystery "Make room in your Bag first." notice has no Denied sound | audio | CONFIRMED | should-fix (requested) | no |
| 6 | `test_fast_travel` "phone: centred and fits" is a **stale test** (since R140), not a layout bug | test | CONFIRMED (mock numbers) | should-fix (test only) | no |
| 7 | The HUD button's ready pop and pulse also scale about its top-left corner (the centre drifts about 30 px) | UX | CONFIRMED (mock model) / PLAUSIBLE | nice (low should-fix) | no* |
| 8 | Opening a roll builds about 600 instances in one frame (R149: about 370). The reveal frame adds 41 to 160 (R149: 4 or 5) | perf (phones) | CONFIRMED (counts) / PLAUSIBLE (ms) | nice (low should-fix) | yes |
| 9 | Four panel twinkles now sit on the odds fine print (the "43.5%." dot in the phone stills) | UX | CONFIRMED (layout arithmetic + stills) | nice | no |
| 10 | Shine sweep: on live, Rotation pivots at the centre, so the winner-card stripe pops in and out mid-card. The mock rotates about the AnchorPoint | UX | PLAUSIBLE | nice | **yes** |
| 11 | Gift timer: the separate `Lip` frame does not follow the pill's pop and shake | UX | CONFIRMED (code + still) | nice | no |
| 12 | Smaller items: a new marker line crosses the winner's label (old issue); the bonus client is at about 160 of 200 top-level locals; the take flight grazes the TAKEN sign; a dead `TearSoundStart`; the audio attributes go stale after a change; the Verity 0.5 s cap; Denied / MenuClose are by-ear choices | mixed | CONFIRMED / PLAUSIBLE | nice | mixed |

\* No live gap in the sense that the mock's own layout model (UIScale applied about the AnchorPoint, as Roblox does) predicts the same thing. No test or still samples the frames in the middle of the pop.

There is no blocker:

- **Saved data:** untouched. `Config.ProfileVersion=22`, and `Config.Version` is still `'V150 R149'` (bump it at release).
- **Gameplay files:** byte-identical to R149 (`frozen.sha256`).
- **New remotes:** none.
- **Sound instances on the server:** none.

Section F lists everything checked and found fine.

---

## A. Correctness

### 1. The Index "new reward" chime plays at pack-open time and spoils the reveal: CONFIRMED, should-fix (high)

**Where:** `ChestIndex.client.lua:157`, new in R150:

```lua
if total>alertTotal and os.clock()>=alertsFrom then Audio.Play('GemClaim')end
```

**Why it fires on most pack openings:**

1. `PlayerDataService:OpenSeedPack` (`PlayerDataService.lua:410-411`) calls `MarkSeedDiscovered` and `CommitSeedReward` the moment the server opens the pack. That is the frame the reveal starts, before the tear and before the seed rises at `SeedAt(rank)`.
2. `CommitSeedReward` (`PremiumProgress.lua:286-288`) adds the seed's cash to `SeedRewards[id]` for every opening, first or repeat. `PublishPremium` then sets the `RewardCash` attribute.
3. ChestIndex watches `DiscoveredSeeds` children and `RewardCash` (`:451-453`). It recounts `waiting()`, which is +1 for each seed with `RewardCash>0`.

**Result:** whenever the opened seed had no reward waiting, `total` rises and the GemClaim celebration plays at the tear. That covers:

- every new discovery, which is nearly every pack early in the game;
- every repeat of a seed whose reward was already claimed.

The chime is 0.5 to 3 s before the seed is shown. It tells the player "something new" before the reveal does, and it lands on the rank 4+ whoosh charge-up. The badge pop was already silent in R149; only the sound is new. The audit marked this cue as "optional" (M19).

**Fix (minimal):** delete `ChestIndex.client.lua:157`. `alertsFrom` (`:146`) is then unused and can go too. The badge still pops, silently, as in R149. No R150 or R138 check depends on this line.

If the owner wants a chime here, play it only when the Index window is open, or delay it past the reveal. Do not play it on the badge change itself.

### 4. Follow-up E1: Denied on bonus-roll refusals: CONFIRMED, should-fix (requested)

`flashMessage` (`TreadmillBonusClient.client.lua:292-296`) is called only on refusal paths:

- the charging tap "NEXT IN m:ss" (`:654`);
- no reply or an error (`:660`);
- a server refusal (`:661`);
- a malformed reply (`:662`).

A roll that starts (`startRoll`) never calls it. One line covers every refusal and no success:

```lua
local function flashMessage(message)
 if Audio then pcall(Audio.Play,'Denied')end -- R150: every flash is a refusal (charging tap, server refusal, no / bad reply); a roll that starts never flashes
 messageUntil=os.clock()+2.5;...
```

**Checks:**

- `TreadmillBonusService` sends no refusal notice of its own (only "roll ready", `:84`), so there is no second Denied from NoticeFeed.
- The press click (Bubble04 from ButtonHighlights) still plays first. This matches the Market, Index and shovel refusals.
- Verified on a patched scratch copy: `test_bonus_ui` 313/313, `test_bonus_audio` 31/31 and `test_bonus_layout` 5248/5248 still pass.

**Add a check to `test_bonus_ui`:**
- after a refusal, `C.Played` contains `'Denied'`;
- after a successful roll it does not.

### 5. Follow-up E2: the mystery "Make room" refusal: CONFIRMED, should-fix (requested)

**Where:** `MysteryPackService.lua:128`. Add the kind as the 5th argument:

```lua
if self.Notes and not carried then pcall(function()self.Notes:Show(player,'🎒 '..tostring(why or'Make room in your Bag first.'),RGB(255,190,90),4,'Denied')end)end
```

**Why the kind is needed:**

- The colour is orange.
- With the "🎒 " prefix the text is not one of SimpleGameText's exact red keys.
- So `IsRefusal` misses it today.

**Scope:**

- `:148` ("Make room: N mystery packs waiting") is a once-per-session reminder, not a refusal. Leave it silent.
- The R147 notes stub ignores extra arguments.
- The pickup on success is unchanged: Bubble06 when the pack lands, never on a refusal.

### 6. `test_fast_travel` "phone: centred and fits" is stale, not a phone layout bug: CONFIRMED, test-only fix

**What the test checks:** `tools/tests/test_fast_travel.luau:116` expects `pair.Position.X.Offset==195`. That is the R114 rule: the pair is centred on the screen.

**What changed since:**

- R140 (`74d235a`) added the DAILY / INVITE squares right of TRACK.
- It also added the rule "narrow the pair (not below 72), then slide the whole row left" (`TravelButtons.client.lua:79-88`).
- That commit did not touch the test. The failure has existed since R140, on R149 too.

**Layout on the mock** (390 x 844, free row `TopbarInset` 60..330; probe run against the real TravelButtons):

| Element | Position |
|---|---|
| Pair | centre 151, width 79 per button, spanning 68..234 |
| Squares | 242..322, y 4 (in the row) |
| Whole group | 68..322, so its centre is **195** |

Everything sits inside the free row with the 8 px margins. The behaviour is the documented R140 behaviour. Only the assertion is out of date.

**Fix (replace line 116):**

```lua
do -- R140: the DAILY / INVITE squares share the row: the pair narrows, then the row slides left, so the GROUP is centred and fits
 local icons=gui.TopIcons;local left=pair.Position.X.Offset-pair.Size.X.Offset/2;local right=icons.Position.X.Offset+icons.Size.X.Offset
 check(inside()and baseButton.Size.Y.Offset>=30 and baseButton.Size.X.Offset>=72 and icons.Position.Y.Offset<44 and left>=60+8 and right<=330-8
  and math.abs((left+right)/2-195)<=1,'phone: the pair + DAILY / INVITE row is centred and fits')
end
```

---

## B. Performance (phones)

### 8. The roll screen builds about 600 instances in the opening frame: CONFIRMED (counts), PLAUSIBLE (ms), low should-fix

Mock probe with the real client and the R149 client (`preview/TreadmillBonusClient_R149.lua`), `Instance.new` counted:

| | R149 | R150 |
|---|---|---|
| Roll opens (46 cards, all in one frame, after `overlay.Enabled=true`) | 368-395 | **598-625** |
| Instances per card | 7 | 12 |
| Reveal frame, Common / Legendary / Mythic / Secret | 5 / 4 / 4 / 4 | **41 / 120 / 142 / 160** |

**What the R150 card adds:** a Plaque and its UICorner, and a Gloss with its UICorner and UIGradient. That is +230 per roll; the Gloss alone is 138.

**Reveal pieces:** a sparkle is 5 instances (Frame + 2 bars + 2 UICorner); a confetti bit is 1. The Secret reveal's 160 new instances are created on the exact frame the player is watching.

**Not a leak:** 24 repeated rolls do not grow the tree (R150 suite), and the per-frame work afterwards is bounded:
- the bursts write 3 properties per piece for at most 1.3 s;
- ambient motion writes about 30 properties per frame while the window is open.

**Estimate:** about 10 to 15 µs per created and parented GUI instance on a low-end phone. That gives roughly 6 to 9 ms for the open (R149: 4 to 6 ms) and 1 to 2 ms on the reveal frame, plus the first layout pass. The open also coincides with the 0.28 s panel pop.

**Check in Studio:** MicroProfiler on a low-end phone, the frame where the roll opens.

**Cheapest fixes, in order:**
1. Build the per-card `Gloss` (`:503-504`) only for `Rules.Special` tiers. That is -138 instances per roll, and the plain cards barely show it under the gradient.
2. Draw a sparkle as one rotated Frame instead of a Frame with two pill bars (`BonusGiftArt.lua:212-220`). That is -64 instances on a Secret reveal.
3. Bigger change: pool the 46 card frames across rolls and repaint them instead of rebuilding.

### Checked and fine (B)

- **Bonus client:**
  - Idle: no per-frame listener and no scheduled work (suite).
  - The READY attention effect runs 1.2 s in every 4.2 s; R149 pulsed every frame while the button was visible.
  - The 4 Hz timer runs only on the treadmill.
- **Pedestal fx:**
  - The loop runs only while a Locked or Ready pedestal is within 75 studs of the camera.
  - About 10 CFrame writes per frame for each pedestal that is near and on screen: 8 runes, the pack pivot and the shaft.
  - About 40 live particles per pedestal.
  - Nothing for pedestals that are far, hidden, Taken or Empty, or when the quality tier is 1.
- **AudioMixer:**
  - Purely event driven.
  - `SoundTiming.Play` now calls `Route` on every play: a few string comparisons and an early return.
  - `Start` walks the existing characters once.
- **WorldStatusHud:** repaints every frame only during the last 3 s of the closed countdown.
- **Keyboard clicks:** `Timing.Play` costs one extra `Route` per click.
- **No new O(n) per-frame loops.**

---

## C. UX nits visible in the previews

### 2. Reveal confetti crosses the ribbon header: CONFIRMED, should-fix

**Where:**

- The confetti layer is `overlay.Fx` (`TreadmillBonusClient.client.lua:378`, ZIndex 30, a sibling of the Panel). It draws above everything in the panel, including the ribbon and its title.
- Pieces start at the strip window's centre with an upward speed of up to 620 px/s. Gravity is 820 and there is no vertical drag (`BonusGiftArt.lua:232`), so they peak about 234 px up.
- The ribbon is only 84 px (desktop) or 66 px (phone) above the start point.

**Mock probe** (`UW.rects`, confetti boxes against the Ribbon box):

| Screen | Reveal | Frames with confetti on the ribbon | Pieces at once |
|---|---|---|---|
| Desktop | Legendary | 56 of 80 | up to 12 |
| Phone 844 x 390 | Secret | 58 of 80 | up to 17 |

This matches the "TRLA.JMILL" / "TREA?MILL" stills.

**Fix (verified on a scratch copy):** put the confetti layer behind the ribbon, inside the panel. Confetti still flies over the strip, the word and out past the panel. The header and the bow stay on top.

```lua
-- :326  the ribbon above the effect layer
local ribbon=make('Frame',{Name='Ribbon',AnchorPoint=Vector2.new(.5,0),BackgroundColor3=WHITE,ZIndex=5},panel)
-- :378  the reveal layer moves INTO the panel: over the strip window (3), under the ribbon (5), the pointers (9) and the bow (10)
local revealFx=make('Frame',{Name='Fx',BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Active=false,ZIndex=4},panel)
-- :551-554  panel-local origin
local function fxOrigin()return panelW/2,windowY+windowH/2 end
-- :571 :575 :619 :648  overlay.Fx -> revealFx
```

**Why this works:**

- Under `ZIndexBehavior.Sibling`, the ribbon's children (the title and the tails) draw with the ribbon, above the layer.
- The panel does not clip, so pieces still leave it.

**Test updates:**

- `test_bonus_ui` / `test_bonus_audio`: `overlay.Fx` becomes `overlay.Panel.Fx`.
- `test_bonus_layout:238-239`: the layer check becomes `b2['TreadmillBonusRoll.Panel.Fx']`.

With these, the scratch run passes 313/313, 5248/5248 and 31/31, and R123 client 129/129 and layout 718/718.

Limiting the launch speed so pieces "start below the header" is not enough on phones. With only 66 px of room, the speed would have to drop to about 330 px/s, which turns the burst into a small fountain.

### 3. The reveal word pops from its top-left corner: CONFIRMED (mock model), PLAUSIBLE (engine), should-fix

**Where:**

- `word` is a full-width label: `Position=(16,y)`, `Size=(1,-32,0,wordH)`, AnchorPoint (0,0) (`:411`).
- Its `UIScale` starts at `max(.2, 1-3*Pop)`: .7 for Common, .34 for Epic, .2 for Legendary and up. Epic and up use Elastic easing (`:568-569`).
- A UIScale scales about the object's **AnchorPoint**. `ui_world` models it this way, and so does the preview renderer.

**Probe** (desktop, Legendary): the word's centre starts at x 389 while the panel centre is 640. It slides 251 px right while it grows; with Elastic it overshoots and swings back. The preview stills are taken after the pop settles, so none of them shows this.

**Fix (verified):**

```lua
-- :411
word.AnchorPoint=Vector2.new(.5,.5);word.Position=UDim2.new(.5,0,0,y+wordH/2);word.Size=status.Size;y+=wordH
```

The probe then gives a centre of 640 on every frame. All bonus suites pass.

**Check in Studio:** one Legendary roll, watching the word.

### 7. The HUD button pops and pulses about its top-left corner: CONFIRMED (mock model), PLAUSIBLE, nice (low should-fix)

**Where:**

- `pulse` is a UIScale on `BonusRollButton`, which has AnchorPoint (0,0) and is placed at `Rules.Place`'s top-left (`:271`).
- The ready pop runs .72 to 1 (`:231`). Probe: the centre moves from (610,539) to (640,546).
- The attention pulse runs 1 to 1.05 every 4.2 s and nudges the button about 5 px right and down each time.

**Fix (verified):** the R150 bonus suites, R123 `test_client` 129/129 and R123 `test_layout` 718/718 all pass.

```lua
-- :271
button.AnchorPoint=Vector2.new(.5,.5);button.Position=UDim2.fromOffset(r.X+r.W/2,r.Y+r.H/2);button.Size=UDim2.fromOffset(r.W,r.H)
-- :224-226  (the sparkle origin)
local function buttonCenter()
 return button.Position.X.Offset-button.Size.X.Offset/2+26,button.Position.Y.Offset-button.Size.Y.Offset/2+(button.Size.Y.Offset-LIP)/2
end
```

### 9. Twinkles sit on the odds fine print: CONFIRMED, nice

**Where:**

- R150 moved the odds line to the bottom row. On phones it spans y 270..294 of a 300 px panel; on desktop, 336..368 of 380.
- The twinkles at `{.5,.95},{.2,.95},{.8,.95},{.62,.9}` (`:322`) now sit on that text.
- In R149 the bottom row was the centred CLOSE button.

In the phone stills this shows as a stray dot: "Common 43.5%.·".

**Fix:** delete those four entries from the list at `:322`.

### 10. Shine sweep: rotation pivot on live: PLAUSIBLE, nice, live gap yes

**The engine difference:** Roblox rotates a GuiObject about its **centre**, whatever its AnchorPoint. `ui_world.rects` and `render_gui.mjs` both rotate about the AnchorPoint.

Every rotated part in R150 has AnchorPoint (.5,.5), so the two models agree, except one:

- The `Sweep` stripe in `BonusGiftArt.Shine` (`:148`) has AnchorPoint (0,0) and Rotation 22.
- On live, on the 94 x 118 winner-card pane, the stripe's corner is already about 12 px inside the card at `u=0+`, and still inside it at `u=1-`. The soft stripe pops in and out mid-card.
- On the HUD button face (about 190 x 36) it stays off-pane at both ends.

**Fix:** `BonusGiftArt.lua:156` becomes `stripe.Position=UDim2.fromScale(-.6+u*2,-.45)`. That covers the card at both ends with margin.

**Test model:** worth fixing too, so that rotated, non-centred parts are modelled correctly in later rounds. In `ui_world.luau:89-97`, rotate about the centre `(x+w/2, y+h/2)`, not about `(ax, ay)`.

### 11. Gift timer: the lip does not follow the pop or the shake: CONFIRMED, nice

`backLip` (`:692`) is a sibling of `back`. `popBar` scales `back` (1.18 to 1) and shakes its `Rotation` (`:724-728`), but the shadow lip stays put. In the "a roll completes" still, the rotated pill sits on a misaligned dark lip.

**Fix:** in the shake effect, also set `backLip.Rotation=back.Rotation`. Add a `UIScale` on `backLip` and tween it with `backPop`.

### 12. Smaller items (nice)

| Item | Where | Status | Fix |
|---|---|---|---|
| The gold marker line crosses the winner's rarity text ("COMM\|ON", "LEGEND\|ARY"). Already in R149 | `:345-350` | CONFIRMED | Hide `Marker` and `MarkerGlow` in `celebrate` (the rays and the border already mark the winner). Show them again in `startRoll` |
| Top-level locals in `TreadmillBonusClient` are about 160 of the 200 limit (R149: about 105), plus 22 more inside the gift-timer `do` block. It compiles today; the margin is shrinking | whole file | CONFIRMED | Put new code in `do` blocks or modules |
| The take flight's arc peak grazes the bottom of the "TAKEN TODAY" sign (pedestal still at +0.35 s) | `MysteryPedestalFx.lua:28` `ArcHeight=2.2` | CONFIRMED (still) | `ArcHeight=1.4` |
| `Rules.TearSoundStart` is no longer read | `SeedPackRules.lua:17` | CONFIRMED | Remove it, or point its comment at SoundTiming |
| The `Audio*` player attributes are written only at data load. `SetSetting` does not update them, so they go stale after the player changes a slider. This is harmless: AudioMixer stops following them once the group is `decided` | `PremiumService.lua:79` | CONFIRMED | Optional: also set the attribute there |
| Verity's 0.5 s greeting cap: a first greeting asked before her clip finished loading is skipped. The clip is preloaded as soon as she builds, so this needs a slow first download | `VerityClient.client.lua:153-167` | PLAUSIBLE | None; check `/test verityvoice` on mobile data |
| `Denied` (built-in ping at .55) and `MenuClose` (MenuClick at .85) are by-ear choices. Denied is clearly lower than the keeper-near ping (.82-.94) | `InteractionAudio.lua:10-13` | PLAUSIBLE | Studio ears |
| `Enum.Material[theme.Material] or SmoothPlastic`: on live, an invalid Enum name throws instead of returning nil. All 8 current names are valid | `MysteryPedestalArt.lua:61` | CONFIRMED | None needed; keep names valid |

---

## D. The test_fast_travel failure

See item 6. It is a stale test, not a layout bug. Replace line 116 as shown there.

## E. Follow-ups to add to the fix list

Items 4 and 5 give the exact lines. Neither changes a success path.

---

## F. Checked and found fine

**Live GUI behaviour**

- **Interface properties** use valid shapes:
  - UIGradient: two-keypoint hard steps; Stripes uses 18 keypoints, under the limit of 20.
  - Gift fill: keypoints strictly increase inside 0..1.
  - UIStroke: always on Frames; a UIGradient under a UIStroke (Legendary / Secret) has been supported since R124.
  - UICorner pills.
  - `ZIndexBehavior.Sibling` on all three GUIs.
  - `BillboardGui.ClipsDescendants=false` and `ResetOnSpawn`, both LayerCollector properties.
  - Every animated rotation except the shine (item 10) uses AnchorPoint (.5,.5).
- **No unknown globals:** `luau-analyze` finds none outside Roblox's own in any of the 57 changed files.
- **Compiles:** every script in `src/` compiles with `luau-compile`. The local, upvalue and register limits are enforced by that same compiler.

**Sounds**

- **Bonus ticks:**
  - The 4 voices are built and `PreloadAsync`ed at script start; S9 is fixed.
  - Cold voices are dropped, never played late.
  - The voices are named `Interaction_`, so they route to Interface.
- **Denied voice:**
  - It is a built-in `rbxasset://sounds/...` id, accepted by `Asset()`.
  - Its `PlaybackSpeed` is set when the pool is built; nothing else changes it.
  - Its `SoundTiming` offset is 0 for an `rbxasset` id.
  - `NotificationClient83` preloads it.
- **TimePosition** is in file seconds. `LocalSfx`'s late `skip` is scaled by `PlaybackSpeed`, and so is the Veiled age. A cold file re-seeks on `Loaded`, within `MaxAge`.
- **SoundGroups:**
  - Every new sound is routed.
  - The snore and existing characters are routed too (R1).
  - Explicit `Effects` routing (unlock chime, snore) is not overridden by the generic `Route`.

**Saved volumes**

- The server writes 5 validated integers (0..100) on the Player from `premium.Settings` (`SettingsConfig.Read`).
- The client can only change its own local copy, and only its own mix reads them.
- Other players can read them. That is harmless.
- `decided` stops attribute adoption once SettingsState or the player sets a group.

**Server-to-client signals**

- `UpgradeBoughtSerial` and `UpgradeRefusedSerial` are counters set in the same server step as the press and the tier change. They only play sounds, so a client spoofing them locally fools nobody but itself.
- A refused press with `not expected` ("Fully upgraded!") counts as refused.
- The 0.65 s rate-limit and `Busy` cases stay silent.

**Double-sound checks**

| Case | Result |
|---|---|
| Menu open / close | Button + SeedMenu hook give one sound (same key within the gap) |
| Bag-card equip | `Mute('MenuClose')`, so Equip is the only sound |
| Harvest pickup | Moved from the reply to the arrival flash; no longer at the reply |
| Mystery take | Whoosh at lift-off + Bubble06 on landing; InteractionFeedback is not involved (the pack goes into the Bag) |
| Keeper slam vs snap | No double and no silence. BeastAnimation's slam frame uses server time (`now=GetServerTimeNow()`), so it comes before the `KeeperHit` packet and `SlamHeard` is set first; a missed slam frame now falls back to the snap |
| Fast travel, Economy, Chest, TrackHole refusals | Server notice only; no local Denied as well |
| Bonus refusals | No server notice (E1 adds the only Denied) |

**Refusal and success are not mixed up anywhere:**

- GardenUpgrade, Economy (`setStatus`, `gardenToast`), ChestIndex claims, Daily, GamePass, Verity, the shovel and gifting all play Denied only on failure.
- Every SimpleGameText "Red" key is a refusal or an error.

**Streaming and pedestal**

- The pedestal model is `Persistent`.
- The fx Folder lives inside it and is rebuilt if it goes missing (the 0.5 s tick checks `Folder.Parent`).
- The anchor and the prompt are relinked when they arrive late.
- The cloned pack (template and flight) carries no CollectionService tag (the server removes `BiomeSeedPackVisual`).
- Its parts are `CanCollide`, `CanTouch` and `CanQuery` false.
- The burst, flash and pop parts are given to `Debris`.
- The mystery rules, data and prompt are unchanged.

**Teardown and leaks:** all R150 suites cover them. 24 rolls do not grow the overlay, HUD, timer or sound pool. No listeners or delays remain after `Destroying`.

**Existing features**

- Hotbar keys, slots, cards and drag; the Bag; notices (`Push` / `Plain` signatures stay backward compatible).
- Fast travel, upgrades, Index, gifting, keepers, pack opening and Verity.
- All the older suites below pass.

---

## Verification (all on `036f634`)

| Suite | Result |
|---|---|
| `R150/tests/run_bonus_ui.sh` | frozen (2 gameplay files unchanged); style 167/167, ui 313/313, audio 31/31, layout 5248/5248 |
| `R150/tests/run_all.sh` | above + R123 (server 109, client 129, layout 718), R128 (8, 22, 21), R129 (119, 20), R137 (43, 22, 11, 14), R138 (18, 14, 18, flow OK, layout ALL PASS, tutorial 436): all pass |
| `R150/tests/run_pedestal.sh` | wiring OK; look 57/0, fx 155/0; z-fight 21 scenes, 0 counted findings |
| `R150/tests/run_sfx.sh all` | cues 105/0, hotbar 38/0, packs 14/0, inputs 129/0, server 25/0; `test_fast_travel` 70 checks, 1 failure (item 6, stale since R140). All of these pass: audio_R123 37, R136 24, R138, R140 129 + 68, R147 keyboard 385 and Verity 185 + 242, R148 purchase 71 + 75, R149 keyboard 385, R149 Verity, holes_R122 106 + 79, polish_R124, giving_R122 186 + 35, treadmill_bonus_R123, veiled_R122 128 + 73 + 46, wall_notifier 168, R129, borders_R123 2323 |
| `R147/tests/run.sh` (MysteryPackService / Client rewritten) | mystery 282/0, client 187/0 |
| `R149/tests/run_zfight.sh` on the owner's place, base `3ae5bb4` | PASS. Counted findings 163 → 163 (start) and 500 → 500 (snow); 0 left that are ours. Strict-rule-only (not counted) `pedestal` 24 → 66 and `bases+pedestal` 0 → 18 |

**Scratch probes** (not committed):

- **Instance counts:** the real R150 client against `preview/TreadmillBonusClient_R149.lua`.
- **Confetti against the ribbon:** `UW.rects`, every frame.
- **Pop centres:** the word and the button, every 3 frames.
- **TravelButtons phone numbers.**
- **Trial patches:**
  - the patches: the confetti layer in the panel, the word anchor, the button anchor and Denied in `flashMessage`;
  - with them, the R150 bonus suites (313/313, 5248/5248, 31/31, with the `Fx` path edits) and R123 client / layout (129/129, 718/718) pass;
  - the probes show the word centred (640) on every frame, the button centred (640,546), and the confetti drawn under the ribbon (Z4 under Z5).

## Fix list (in priority order)

1. **Index chime:** delete `ChestIndex.client.lua:157` (and `alertsFrom` at `:146`). This is item 1.
2. **Confetti behind the ribbon:** in `TreadmillBonusClient.client.lua`, change `:326`, `:378`, `:551-554`, and `:571 :575 :619 :648`, then update the 3 test paths. This is item 2.
3. **Reveal word anchor:** change `:411`. This is item 3.
4. **E1:** Denied in `flashMessage` (`:294`), plus a check in `test_bonus_ui`. This is item 4.
5. **E2:** pass `'Denied'` at `MysteryPackService.lua:128`. This is item 5.
6. **Stale test:** replace `tools/tests/test_fast_travel.luau:116`. This is item 6.
7. **HUD button anchor:** change `:271` and `:224-226`. This is item 7.
8. **Lighter roll build:** build the gloss only for special cards (`:503-504`), and draw a sparkle as one frame. This is item 8.
9. **Small polish:** the twinkles at `:322`, the shine travel at `BonusGiftArt.lua:156`, the lip following the pop, hiding the marker on reveal, and `ArcHeight` 1.4. These are items 9 to 12.
