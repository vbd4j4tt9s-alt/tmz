# R150 SFX audit: sync and missing sounds (findings only)

Owner request: "check for all sfx in the game make sure they are synced and also make sure that there are no inputs that when
player click or do anything are missing sfx".

- **Baseline:** `claude/compassionate-brown-lohfok` = R149 release (`3ae5bb4`). Game code was read only. Nothing in `src/` is changed.
- **R150 work in progress elsewhere:** `TreadmillBonusClient` (bonus roll UI polish) and `MysteryPack*` (pedestal polish). The findings
  below that touch those files (S9, the bonus-roll parts of M3 and M4, and M14) must be merged with that work, not applied on top of R149.
- **Marks:** **CONFIRMED** means read in code, and where it says *mock*, reproduced on the Roblox mock (`/opt/luau/luau` +
  `tools/tests/roblox.luau`, real R149 modules). **PLAUSIBLE** means the code path is certain, but how it sounds needs Studio ears
  (asset lead-in, loudness, choice of cue).
- **Place file checked:** `sapkeyver.rbxl` (4 Oct, latest upload). It has no placed `Sound` outside ServerStorage (every sound is made
  by a script) and no placed GUI buttons (every button is made by a script). Its only audio attribute is `InteractionAudio.GemClaimAssetId`,
  which equals the default. **No `TrackHoleConfig.DigSegments` and no `SoundTiming.Start_<id>` attributes** are saved (see S5 and S13).

## Summary

| | Count |
|---|---|
| Sound asset ids in code | **50** `rbxassetid` + 1 built-in (`rbxasset://sounds/electronicpingshort.wav`). 47 are used. Unused but available: 88838553648526, 96591611478915 (spare keyboard clicks), 9113512609 (`StormConfig.ImpactId`) |
| Scripts that make or play sounds | 34 files. There are no server-side `Sound` instances; every sound is client-local |
| Inputs enumerated | 76 `Activated` handlers in 24 client files (Studio test panel excluded), 13 ProximityPrompt kinds, 1 ClickDetector, 14 keybinds or world-click routes, plus tool activations (Appendix A) |
| **Out-of-sync findings** | **13** (S1-S13). 10 fully CONFIRMED, 7 of them reproduced on the mock. S5 and S6 are CONFIRMED in code, but how audible they are is PLAUSIBLE. S13 is PLAUSIBLE |
| **Missing or inconsistent SFX** | **19** (16 CONFIRMED, 3 PLAUSIBLE or optional) |
| Mixer, volume and routing findings | 4. R1 CONFIRMED on the mock (how often the race happens is PLAUSIBLE). R2 and R4 CONFIRMED. R3 is a by-design note |
| Existing suites on R149 | audio_R123 sync 37/0, R149 keyboard 383/0, R149 Verity all pass, holes_R122 106/0 + 79/0 |

The top items, in order of how often players hit them:

1. **Hotbar equip has no sound.** Keys 1-0 and L1/R1 are silent. A slot click plays only the generic Bubble04. The `Equip` cue is never used.
2. **Harvest "pickup" plays 0.44-0.70 s early.** It plays at the server reply, when the fruit lifts off. The R149 fruit flight lands later, and the hotbar slot flashes then in silence.
3. **Pack-opening clicks lose 2 of 5 sounds at full tapping speed.** The bag shakes but the sound is muted by the 0.09 s de-dupe.
4. **Refusals are silent.** This covers red notices, teleport cooldown, dig refusals, "AIM AT SOIL", "NEED MORE CASH" and similar.
5. **Opening and closing menus is inconsistent.** The X button plays Bubble04, the shade, Esc and B play nothing, the nav wheel plays MenuClick, and the gift veil plays Bubble04.
6. The Common and Uncommon reveal pop is 82-93 ms late. The Darkened's arrival sound restarts from 0 on a late packet. Dig variants are uncut.

---

## 1. How audio works today (verified)

- **`InteractionAudio`** is the UI cue set. It holds 3 voices per key in SoundService (2D), on the **Interface** group, which is the
  "Button sounds" slider. It preloads at require time. A **cold voice is dropped**, never played late. There is a **0.09 s per-key gap**.
  `MenuClick` stops the previous MenuClick.
- **`ButtonHighlights`** (started by `ButtonFeedback.client.lua`) binds **every GuiButton under PlayerGui**. On `Activated` it plays
  `ButtonSound` (default `Bubble04`) unless `ButtonSound=false`. Buttons named `Shade` or `Backdrop`, and buttons with `ButtonHighlight=false`
  **at bind time**, are not bound, so they play no sound.
- **`SoundTiming.Play`** skips the measured lead-in silence. Only 5 ids are measured. A sound that is still loading plays when it loads,
  but is dropped if that is more than 0.5 s after the call.
- **`LocalSfx`** handles world one-shots: 3D, at most 12 alive, the same id within 35 ms and 6 studs plays once. It routes through SoundTiming,
  so it uses the **Effects** group.
- **`AudioMixer`** has five groups: Music, Chase, Ambience, Effects and Interface. `Start()` is called by `SettingsClient`. It routes every
  sound in SoundService and every sound added later under SoundService or workspace. It does **not** scan workspace sounds that existed before
  `Start()` (see R1).
- **No sound is created on the server.** The server only publishes ids and volumes (`ChestRunAlert` attributes). Nothing can replicate by mistake.

## 2. Sound inventory

Notes for the columns:

- **Lead-in** is the SoundTiming `Starts` value, or the module's own `Start`. "unmeasured" means the file plays from 0 and nobody has measured its front silence.
- **Pos**: 2D means parented to SoundService or a Folder; 3D means parented to a part or attachment.
- **C/S**: every row is client-only (C).

### 2a. UI cues (`InteractionAudio`, Interface group, 2D, client-local)

| Key | Asset | Vol | Lead-in | Played from | Moment |
|---|---|---|---|---|---|
| Bubble04 | 96764044228884 | .20 | .100 | `ButtonHighlights.lua:20` (default for every GuiButton), `PackOpeningFeedback:86`, `EconomyClient:481`, `GardenWallet:11`, `MysteryPackClient:65`, `BeginnerTutorial:397` | button release, pack click, market open, wallet gems, mystery take, tutorial welcome |
| Bubble06 | 131731955363530 | .22 | .100 | `InteractionFeedback:8`, `EconomyClient:600`, `BeginnerTutorial:491` | pack taken (carry model appears), harvest server reply, tutorial step pop |
| MenuClick | 116737765668953 | .28 | unmeasured | `HudLayout:365` (MENU hub), `HudLayout:397` (nav options) | menu wheel open or close, nav option |
| UpgradeClick | 87218932219010 | .28 | .015 | `InteractionFeedback:21` (`UpgradePressSerial`) | upgrade cap pressed (success or refused) |
| Equip | 99675704394731 | .26 | unmeasured | `EconomyClient:399` (shop Equip/Unequip success) only | shop gear equip |
| KaChing | 86218459564041 | .32 | unmeasured | `EconomyClient:396/546`, `ChestIndex:176`, `GamePassClient:198`, `TreadmillBonusClient:279` | buy, sell, Index cash claim, gem purchase, normal roll result |
| GemClaim | 82559527540705 | .32 | unmeasured | `ChestIndex:180`, `DailyRewardsClient:267`, `PurchaseCelebration:98`, `MysteryPackClient:65`, `VerityClient:558`, `TreadmillBonusClient:279`, `BeginnerTutorial:540`; also the NoticeFeed `Gift` cue | gem claim, daily, purchase done, unlock, Verity done, special roll, tutorial done, gift received |
| (bonus tick) | MenuClick id | .22 | 0 | `TreadmillBonusClient:36-48` (own 4-voice pool, named `Interaction_` so it uses Interface) | strip card passes the marker (at most 30/s, pitch rises) |
| Notice RarePack / WeatherAdopted | 118818986767152 / 133449446616894 | .34 | unmeasured | `NoticeFeed83:6,30` | notice line appears; one cue at a time, the next cued line waits |

### 2b. Reveal and pack (Effects group)

| Sound | Asset | Vol | Lead-in | Where | Moment | Pos |
|---|---|---|---|---|---|---|
| Whoosh | 9120768742 | .09 (Secret+ .22-.26) | .44 | `RarityRevealAudio:4,46,48` | rank 4+ charge-up, joins late by `elapsed` | 2D, opener |
| Impact | 9120769331 | .12 (.30-.36) | .04 | `RarityRevealAudio:74,77` | seed burst, rank 4+ | 2D, opener |
| Royal | 12222253 | .10 (.32) | 0 | `RarityRevealAudio:75` | King burst | 2D |
| Chime / Note / Note2 | electronicpingshort | .04-.16 | 0 | `RarityRevealAudio:59,69,74,78` | charge beats, low-tier notes | 2D |
| Pop | 96764044228884 (Bubble04 file) | .18 | **0, explicit** | `RarityRevealAudio:6,69` | Common/Uncommon burst | 2D |
| Spark | 9120769331 | .06 | .04 | `RarityRevealAudio:7` | Rare / King burst | 2D |
| Paper tear | 9125725227 | .45 envelope | .10 (+lag) | `SeedPackRules:15`, `SeedPackClient:130-136` | bag tears (late join up to +0.25 s) | 3D at bag, everyone |
| Heavenly chord | electronicpingshort ×3-4 | .055 | 0 | `SeedPackClient:215-233` | rank 4+ seed appears, opener, 2.4 s cooldown | 3D at seed |
| Onlooker burst | 9120769331 | .22 | **0** | `RevealFlourish:20,77-78` | Legendary/Mythic burst for onlookers | 3D at bag |
| Pack click | Bubble04 | .20 | .100 | `PackOpeningFeedback:86` | local bag shake on each accepted click | 2D |
| Frostbell jingle | electronicpingshort | .08 | 0 | `FrostbellMotion:45-49`, `HeldHarvestRig:49-51` | bell swing cycle | 3D |

### 2c. World, garden and track (Effects group unless noted)

| Sound | Asset | Vol | Lead-in | Where | Moment | Pos / guard |
|---|---|---|---|---|---|---|
| Dig / cover variants | 93793180254708 (one long recording) | .5 | variant start (**fallback split**, see S5) | `TrackHoleConfig:62`, `DigSoundVariants:118-143`, `TrackHoleClient:108,110` | hole opens + dirt burst (everyone, server `FireAllClients`) | 3D 12-150; 0.5 s load guard |
| Trap thud | 137853494539894 | .5, pitch .9 | 0 | `TrackHoleClient:112` | thief falls + burst | 3D LocalSfx |
| Planting Dig / Land / Settle | 118769294546013 / 137853494539894 / 97631814076710 | .5/.45/.4 (others ×.75) | 0 | `PlantingEffects:29-31,365,467` | pile pops / last chunk lands / pile sinks | 3D 12-130; 0.25 s load guard; 3-emitter pool |
| Keyboard key click | 113108830240353 (88838553648526, 96591611478915 unused) | .8 | **0, hard-coded** | `KeyboardTrack:43`, `KeyboardTrack.client:578-602` | key press (0.07 s), you, other players, keepers | 3D 16-90; 12 voices; ≤12/s per presser; skipped at Effects 0 |
| Keeper alert voices | 9113980319, 9119302862, 9120040597, 9113987603, 9113980512 | .23-.32 | unmeasured | `KeeperVoices:4-10`, `BeastAnimation:55-57,139` | ALERTED/CHASING (and the wake) | 3D 12-110 |
| Knight alert | 100834376603587 | .34 | .225 | `KeeperAudio:5` | Knight alert / catch | 3D |
| Keeper hit snap | 138131702183716 | .48 | .040 | `KeeperHitEffects:85` | `KeeperHit` packet (≤0.75 s stale guard) | 3D LocalSfx |
| Bat slap | 81700629330286 | .48 | unmeasured | `BatConfig:3`, `KeeperHitEffects:85` | bat hit | 3D |
| Ground slam | 73468358342062 | .5 | unmeasured | `KeeperFx:11,319` | ground-smash keepers at the client impact frame | 3D |
| Darkened catch | 119010321306307 | .5 | unmeasured | `KeeperHitEffects:14,83` | The Darkened's catch | 3D |
| Catch voice | keeper voice ×1.35 | ≤.42 | as voice | `KeeperHitEffects:87` | with snap | 3D |
| Snore | 9113862735 | .16 looped | n/a | `KeeperSleep:6,58,92` | sleeping keeper within 65 studs | 3D, **not routed** (R1) |
| Keeper close ping | electronicpingshort + EQ | .045-.07 | 0 | `KeeperNearAlarm:8-29` | chase proximity, every 0.8-1.25 s | 2D |
| Chase alarm | 135684635714618 (fallback 3992992190) | .16 | unmeasured | `Config:24,26`, `ChestRunAlert:28,336` | "RUN!!" label frame | 2D, Timing |
| Heartbeat | 6724333590 | 0-.16 looped | n/a | `Config:30`, `ChestRunAlert:40,371` | danger vignette | 2D |
| Deposit success | 82180364878410 | .18 | unmeasured, direct `:Play()` | `Config:35`, `ChestRunAlert:50,266` | green wash | 2D |
| Storm thunder / rumble | 9120016037 / 9120018695 | .36 / .10 | 0 | `StormConfig:10`, `StormWeather:129,197` | bolt + impact / warning ring | 3D LocalSfx |
| Storm impact | 9113512609 | .40 | n/a | `StormConfig:11` | **never played** | |
| Distant thunder | 9120016037 | .22, pitch .9 | 0 | `WorldEvents:64,144` | ambient bolt flash | 2D |
| Start horn | 9120386436 | .82, pitch .68 + reverb/echo | `StartTime` attribute | `RefreshHorn:4,14`, `TrackRefreshSky:50` | track reopens | 2D |
| Countdown 3-2-1 | electronicpingshort | .45 | 0 | `TrackRefreshSky:7,20` | wall number changes (same frame) | 2D |
| Darkened arrival | 113339179211972 | .8 | unmeasured | `VeiledArrivalFx:13,49,55-58,109` | lights-out | 2D |
| Verity greeting | 123997993114202 | .8 | PlaybackRegion 0-1.9 ("GUESSES", `VerityConfig:20`) | `VerityConfig:56`, `VerityClient:88-165` | Talk / near / owner test; lip sync from PlaybackLoudness | 3D 30-140; skipped at Effects 0 |
| Default character sounds | Roblox `RbxCharacterSounds` | engine | | Running/Walking/Footsteps muted by `QuietFootsteps87`; Jump/Land/etc. kept | jump, land | 3D |

### 2d. Music and ambience (own groups)

| Track | Asset | Group | Where |
|---|---|---|---|
| Morning Mood / Clair de Lune (playlist) | 1846088038 / 1844513698 | Music | `BackgroundMusic:18,22` |
| Playful Chase | 1839530854 | Chase | `BackgroundMusic:30` |
| Chaser (special) | 9042664292 | Chase | `BackgroundMusic:34` |
| Nature Inspiration (scenic) | 96110001912212 | Music | `BackgroundMusic:36` |
| Birds / Leaves / Wind / Crystal hum / Low rumble beds | 9116971475 / 9116258282 / 3308152153 / 9125719267 / 9120018695 | Ambience | `BiomeMood:58-62`, `BiomeAmbience:13` |

---

## 3. Out-of-sync findings (ranked)

### S1. Harvest pickup cue plays when the fruit lifts off, not when it lands in the bag. CONFIRMED (code + mock numbers)

- **Evidence.** `EconomyClient.client.lua:600` plays `Bubble06` when `GardenInteract:InvokeServer('Harvest')` returns. That is about the
  moment the harvest replicates and GardenVisuals starts the R149 fruit flight (`PlantGrowthFx.lua:243-253`).
- The flight lasts `FlightSeconds = clamp(.40 + .012 × distance, .40, .70)`. On the mock that is 3 studs **0.436 s**, 10 studs **0.52 s**,
  20 studs **0.64 s** and 30 studs **0.70 s**.
- Only when the flight ends does `HarvestArrival.Land` release the hold. The Hotbar then shows the item and **flashes the slot**
  (`Hotbar.client.lua:332-337`), and that moment is silent.
- Under Reduced Motion or low quality no fruit flies, so cue and flash still coincide. The desync exists only for the default player.
- **Fix.** Delete the `Bubble06` at `EconomyClient:600`. Add `require(RS.InteractionAudio).Play('Bubble06')` once inside `if arrived then`
  at `Hotbar.client.lua:332`. A failed request has `cue=false` and never flashes, so it stays silent. The 1.5 s `Expect` deadline still
  rings when no flight starts.

### S2. Pack-opening clicks: 2 of 5 click sounds are dropped at full speed. CONFIRMED (mock)

- **Evidence.** `PackOpeningFeedback:99-102` accepts a click every `SeedPackRules.ClickInterval` = **0.065 s**. Each accepted click shakes
  the bag and calls `Audio.Play('Bubble04')` (`:86`).
- `InteractionAudio.Play` refuses the same key within **0.09 s** (`InteractionAudio:41`).
- Mock: 5 clicks at 0.065 s produce **3 sounds**. Every pack takes 5 clicks (`OpenClicks`), so fast tappers see 2 silent shakes per pack.
- **Fix.** Give `InteractionAudio.Play(key, minGap)` an optional gap (default .09). Call `Audio.Play('Bubble04', Rules.ClickInterval*.8)`
  from `pulse()`. The 3-voice pool is enough.

### S3. Common and Uncommon reveal pop starts inside Bubble04's lead-in silence. CONFIRMED (mock)

- **Evidence.** `RarityRevealAudio:6` defines `Pop` on the Bubble04 file with `Start=0`. `A.Play` passes it as an explicit override to
  `SoundTiming.Play`, and an explicit 0 beats the measured `.100`.
- Mock: `SoundTiming.Offset(Bubble04)` = 0.1, but `Offset(Bubble04, 0)` = 0. A button click starts at 0.1, while the Common pop starts at 0.
- So the pop is heard **0.093 s** (pitch 1.08) / **0.082 s** (pitch 1.22) after the seed burst and its sparkles (`PackOpeningFeedback:187-201`).
- For Uncommon, the "pop, then a rising note 0.08 s later" (`RarityRevealAudio:35`) collapses: the pop lands at 0.082 s and the note at 0.08 s.
- **Fix.** `RarityRevealAudio.lua:6`: `Pop={Id='rbxassetid://96764044228884',Volume=.18,Start=.10}`.

### S4. The Darkened arrival sound restarts from 0 while the darkness joins late. CONFIRMED (mock)

- **Evidence.** `VeiledArrivalFx.Arrive` (`:103-112`) starts the lights-out at `offset=age`. That skips the 0.45 s flicker when the packet
  is late. But `F.PlaySound()` (`:55-58`) always plays from the start, for any `age ≤ SoundMaxAge (1.5 s)`.
- Mock: with a packet 0.8 s late, the darkness is already at level 1 and the sound's `TimePosition` is 0.
- **Fix.** Use `F.PlaySound(age)` with
  `local T=require(script.Parent.SoundTiming); T.Play(s, T.Offset(s)+math.max(0,age or 0))`, called from `:109`.

### S5. Dig and cover sounds are cut from the fallback 6-way split, not at the digs. CONFIRMED (code + place file), PLAUSIBLE (audible size)

- **Evidence.** `TrackHoleConfig.DigSound.Segments={}` (`:69`), and the latest place file has **no `DigSegments` attribute**.
- So `DigSoundVariants.Resolve` uses the fallback, which splits `TimeLength` into 6 equal windows (`DigSoundVariants:47-50`).
- A window can start mid-dig or before a quiet gap. The dirt burst starts with the call (`TrackHoleClient:108`), and its toss is 0.16 s up
  and 0.2 s down, so a transient 0.1-0.3 s into the window is heard after the burst.
- **Fix (Studio, about a minute, no code change).** In a client session run `require(game.ReplicatedStorage.DigSoundAnalyzer).Run()`. Paste the
  printed `Segments={...}` into `TrackHoleConfig.DigSound.Segments`. The procedure is in `holes_R122/DIG_SOUND.md`.

### S6. Keyboard key clicks bypass SoundTiming. CONFIRMED (code), PLAUSIBLE (audible)

- **Evidence.** `KeyboardTrack.client.lua:602` sets `TimePosition=0;Play()`. Any front silence in 113108830240353 delays every click against
  the 0.07 s key press (`KeyboardTrack:34`).
- Because SoundTiming is not used, a `Start_113108830240353` attribute could not fix it. This is the likely remaining cause of the owner's
  R148 note that the keyboard is "not consistent with its noise". The cadence itself is verified by the R149 suite.
- **Fix.** `v.Sound.TimePosition = Timing.Offset(v.Sound)`, with `Timing = optional('SoundTiming')` at the top of the file. Then measure the
  lead-in in Studio and set `Start_113108830240353` on SoundTiming.

### S7. Rank 4+ reveal burst has no stale guard. CONFIRMED (mock)

- **Evidence.** `RarityRevealAudio.Burst` drops a late low-tier cue (`t > SeedAt + .6`), but plays Impact and Chime for rank ≥ 4 at any `t`.
- Mock: a Mythic burst handled 2.0 s after its `SeedAt` still plays the impact. The screen has already finished its burst ring (0.75 s).
  This happens when the `RevealAt` attribute or a frame stall arrives late.
- **Fix.** `RarityRevealAudio.lua:63`: after stopping the whoosh, add
  `if tonumber(t) and t > RarityRevealSequence.SeedAt(rank)+.35 then return end` for rank ≥ 4.

### S8. Onlooker Legendary/Mythic burst plays Impact from 0. CONFIRMED (mock)

- **Evidence.** `RevealFlourish:77-78` creates the sound and calls `Play()` with `TimePosition` 0. The opener's copy of the same file trims
  0.04 s (`RarityRevealAudio:4`). The onlooker hears it ~32 ms (pitch 1.25) / ~38 ms (pitch 1.05) after the pillar and sparks.
- **Fix.** Add `['9120769331']=.04` to `SoundTiming.Starts` (`SoundTiming.lua:3`), and play with
  `require(script.Parent.SoundTiming).Play(sound)` in `RevealFlourish:78`. This also prepares M13.

### S9. Bonus roll: the first tick of the first roll is dropped. CONFIRMED (mock)

- **Evidence.** `TreadmillBonusClient:36-48` builds the 4 tick voices inside the first `tickSound` call. It then returns at once if the new
  voice `not s.IsLoaded`.
- Mock, with the real script and new Sounds that load 2 frames after creation: **35 ticks requested, 34 played**, and the first is lost.
  A slower load loses more of the fast first ticks (up to 30/s).
- **Fix.** Build the pool at script start and `ContentProvider:PreloadAsync(tickVoices)`. This file is R150 work in progress, so merge it there.

### S10. HUD "Reopens in N" row lags the 3-2-1 beep and the wall number. CONFIRMED (code)

- **Evidence.** The beep and the wall repaint share a frame, using `BiomeRefreshEndsAt` and `math.ceil` (`TrackRefreshSky:18-30`).
- The HUD row reads the server-written integer `BiomeRefreshSeconds` (`MapService:589`, `WorldStatusState:25-26`) and updates at
  **4 Hz** (`WorldStatusHud:176`). It shows each second one-way latency plus up to 0.25 s after the beep. This is the R123 recommendation 2,
  never done.
- **Fix.** In `WorldStatusState.Read`, while closed, use `left=math.max(0,math.ceil(map:GetAttribute('BiomeRefreshEndsAt')-now))` when it is a
  number. In `WorldStatusHud`, update on every frame while the track is closed and `left ≤ 3`.

### S11. Verity's greeting can start up to 3 s late. CONFIRMED (code)

- **Evidence.** When the clip is not loaded, `greet` waits for `Loaded` and drops the wait only after **3 s** (`VerityClient:150-162`).
  Every other cue in the game uses ≤ 0.5 s.
- For a `talk` greeting the window may already be closed when she starts. The lip sync follows `PlaybackLoudness`, so the mouth is always in
  sync with the sound itself.
- **Fix.** In the `Loaded` callback (`:155-160`), skip if `os.clock()-askedAt > .5`, or for `kind=='talk'` if the panel is no longer visible.
- **Also PLAUSIBLE:** the cut region 0-1.9 s is marked "GUESSES" in `VerityConfig:20`. Confirm "Hello, my name is Verity" by ear with
  `/test verityvoice`.

### S12. Ground-slam keepers: the slam and the snap use different distances. CONFIRMED (code, edge case)

- **Evidence.** `KeeperFx.Slam` plays the slam sound only if *camera → keeper* ≤ 120 (`KeeperFx:309`). `KeeperHitEffects:82` skips the snap
  if *camera → victim* < 120.
- Near 120 studs a hit can therefore play **both** sounds or **neither**.
- Separately, the punch, swipe and push snap plays when `KeeperHit` arrives, about one-way latency after the client's strike frame. That delay
  is inherent, and the 0.75 s guard is fine.
- **Fix.** Gate the slam *sound* on LocalSfx's 260-stud range instead of `DustDistance`. In `KeeperFx.Slam` (`:308-322`), compute the strike
  point first, play `GroundSound` when `c.Distance<=260`, then apply the `DustDistance` early return for the dust, accent and shake only.
  Make `slammed = move and move.Ground` at `KeeperHitEffects:82`.

### S13. Lead-in silence is unmeasured for most cues. PLAUSIBLE (needs Studio)

- Only 5 ids have offsets. The rest play from 0. Any front silence in them is lag against the visual:
  - UI cues: MenuClick, Equip, KaChing, GemClaim
  - Alarm 135684635714618, success 82180364878410
  - Slap 81700629330286, ground slam 73468358342062, Darkened catch 119010321306307, Darkened arrival 113339179211972
  - Notice cues
  - Keyboard click (after S6)
- Measure each and set `Start_<id>` on SoundTiming; no code change is needed. `DigSoundAnalyzer.Run({Id='rbxassetid://...'})` already accepts
  any id (`DigSoundAnalyzer:42`), and its first detected onset is the lead-in.
- For one-shot impacts, the SoundTiming cold-load window (0.5 s, `SoundTiming:26`) is generous. PlantingEffects uses 0.25 s. Consider 0.25 s
  for LocalSfx.

**Checked and in sync**, with the sound in the same call or frame as its visual:

- the pack tear with its late-shift
- the heavenly chord
- the Secret+ build, beats and burst, which join late
- the alarm on the RUN!! frame
- the deposit success wash
- the countdown pings with the wall
- the horn on reopen
- thunder and rumble
- the trap thud
- the planting pile beats
- the keeper voices and wake
- the KeeperNearAlarm ping
- the bonus result fanfare when the strip stops (Reduced Motion's short spin too)
- the mystery unlock burst
- the purchase confetti
- the tutorial pop and confetti
- the Index and daily claim bounces
- the keyboard press frame (including Reduced Motion)
- the upgrade cap press

The cap press sound and the cap tween are both server-driven, so they reach the client in the same replication.

---

## 4. Missing and inconsistent SFX (ranked by how often players hit it)

Hook points are R149 file:line. "Central menu hook" is the one-file change described in M4.

| # | Input or action | Today | Proposed sound | Hook (exact) | Mark |
|---|---|---|---|---|---|
| M1 | **Equip from the hotbar.** Keys 1-0 (`Hotbar:511`), gamepad L1/R1 (`:514-520`), slot click (`:192`), Bag card click (`:236`) | Keys and gamepad: **none**. Click: generic Bubble04. `Equip` is never heard here | **Equip** on equip and unequip | `Hotbar.client.lua:170-177` `equip()`: add `require(RS.InteractionAudio).Play('Equip')` after `EquipTool`/`UnequipTools`. Set `b:SetAttribute('ButtonSound',false)` on slots (`:190`) and cards (`:230`) so a click is one sound | CONFIRMED |
| M2 | Harvest landing in the bag (hold E) | Cue at lift-off (S1) | **Bubble06** at the arrival flash | see S1 | CONFIRMED |
| M3 | **Refusals and errors.** Red notices ("NEED MORE CASH!", "BAG FULL!", "ESCAPE FIRST!", "AIM AT SOIL!"...), teleport refusals (`FastTravelService:133-137,143-144`), dig refusals (`TrackHoleService:94-98`), market errors (`EconomyClient:341` `setStatus(..,true)`), garden toasts (`EconomyClient:556` `failed`), bonus roll errors (`TreadmillBonusClient:340-342`), Verity `Refused` (`VerityClient:561`), "Get closer" (`FruitGiftClient:99,108`), shovel failure (`GardenShovel:66`) | **none**; text only | New **Denied** key (§5), Interface group, 0.25 s gap | (a) `NotificationClient83:5`: play `Denied` when `color == SimpleText.Red` or a new 4th arg `kind=='Denied'`. (b) `NotificationService:Show(..., kind)` passes `kind` through, and FastTravel's refusal and TrackHole's refusal keys (Cooldown, Carrying, Refreshing, Ground, Pack, Camp, Entrance, Spacing, PlayerCap, ServerCap) send `'Denied'`. Colour alone is not enough: TrackHole uses the same orange for "HOLE COVERED" and "X FELL IN YOUR HOLE!". (c) Local refusals call `Play('Denied')` at the lines listed | CONFIRMED (missing), PLAUSIBLE (cue) |
| M4 | **Menu open and close.** X buttons, shade taps, Esc/B/\`, nav, wallet, DAILY, Bag, market prompt, Verity Talk, garden shovel dialog | X = Bubble04. **Shade = none** (Settings, Index, Daily, Verity, Robux shop, Market). Esc/B/\` = none. Nav = MenuClick. **GiftVeil = Bubble04** (mock). Wallet "+" = Bubble04. **Phone wallet tap = Bubble04 or none depending on script start order** (mock: `ButtonHighlight=false` is set after parenting, `GardenWallet:21-22`). Market = Bubble04 one round trip after E. Verity = voice only (silent if on cooldown or Effects 0). Shovel and gift dialogs = none | **MenuClick** on open, **MenuClose** on close | **Central menu hook:** in `ButtonFeedback.client.lua`, watch `PlayerGui` attribute `SeedMenu`. nil→X or X→Y plays `MenuClick`; X→nil plays `MenuClose`. That one hook covers Market, Settings, Index, Passes, Daily, Bag (Inventory), Verity and Shovel, from any path (button, shade, Esc/B, prompt, auto-open, walk-away). Then set `ButtonSound='MenuClose'` on the close buttons (`SettingsClient:26`, `ChestIndex:34`, `DailyRewardsClient:68`, `GamePassClient:34`, `EconomyClient:316`, `Hotbar:60`, `VerityClient:344,422`, GiftVeil and CloseGift `PassGiftDialog:8,15`, bonus CLOSE `TreadmillBonusClient:154`). The same key within 0.09 s de-dupes to one sound. Set `ButtonSound='MenuClick'` on DAILY (`DailyRewardsClient:40`) and Bag (`Hotbar:54`). Remove the explicit Bubble04 at `EconomyClient:481` and `GardenWallet:11`. Set `ButtonSound=false` on wallet "+" and CompactPurchase (`GardenWallet:18,21`). Give the gift dialog, which has no SeedMenu, `MenuClick` in `open()` (`FruitGiftClient:86`) and `MenuClose` in `close()` (`:82`) | CONFIRMED (mock for button cases) |
| M5 | Click or tap a plant to select it (`PlantInspection:105-136`, every harvest) | none | **Bubble04** when the selection changes | `PlantInspection.client.lua:126`, before `selected=target`: `if target~=selected then Audio.Play('Bubble04') end` | CONFIRMED |
| M6 | Collecting sale money icons (`SaleMoneyEffects:156` click, `:154` hover) | Click = Bubble04 even if the claim is refused; **hover-collect = none**; coins reaching the wallet (`wallet:Pulse()`) = none | **Bubble06** when a coin reaches the wallet | `SaleMoneyEffects.lua:102` before `wallet:Pulse()`: `Play('Bubble06')` (the 0.09 s gap keeps a burst to a ripple). `:149` CollectMoney gets `ButtonSound=false` | CONFIRMED |
| M7 | Teleport TRACK / BASE arrival; GO TO TOP prompt (`EconomyClient:687-688`) | Bubble04 on press; **arrival none** | **Whoosh** (`RarityRevealAudio.Play('Whoosh',1.6)`, Effects) | `TravelButtons.client.lua`: on `FastTravelReadyAt` increasing by more than 0.5 (set right after the teleport, `FastTravelService:156-157`), play it. For GO TO TOP, capture the result at `EconomyClient:688` (`local r=sendGarden('PlantTop',...)`) and play it on `r and r.Success` | CONFIRMED (missing), PLAUSIBLE (cue) |
| M8 | Treadmill and fence upgrade **succeeded** | UpgradeClick only (same as refused) | **KaChing** after the click | `InteractionFeedback.client.lua`: watch `TreadmillTier` and `FenceTier`; on an increase within 2 s of an `UpgradePressSerial` change, `Play('KaChing')` (this skips the join-time load) | CONFIRMED |
| M9 | Fruit gift: world click opens the dialog; Give sends | dialog none (see M4); sent none (the receiver gets GemClaim) | **Bubble06** on send | `FruitGiftClient.client.lua:112-113`, where it sends | CONFIRMED |
| M10 | Garden shovel: plant removed | none (the dialog is covered by M4) | Planting **Dig** layer, 3D | `GardenShovel.client.lua:65-66`: on `result.Success`, `LocalSfx.Play('rbxassetid://118769294546013', model:GetPivot().Position, .5)`; else `Denied` | CONFIRMED |
| M11 | Title "Click to Start" with Enter or gamepad A | button = Bubble04; **Enter/A = none** | **MenuClick** | `TitleScreen104.lua:85` `start()`: `Play('MenuClick')`. `:135` ClickToStart `ButtonSound=false` | CONFIRMED |
| M12 | Bat swing (`BatClient:47`) | swing = none (a miss is silent); hit = slap | **Whoosh**, high pitch, 3D at the swinger | `BatClient.client.lua:79-86` on the `Swing` echo: `LocalSfx.Play('rbxassetid://9120768742', root.Position, .25, 1.5, 2)`, tuned so the peak meets `At+Windup` | CONFIRMED (missing), PLAUSIBLE (cue) |
| M13 | Watching someone pull **Secret / Cosmic / King** | **none.** Legendary and Mythic have an onlooker burst (`RevealFlourish`), but `F.Styles` stops at 5 | Impact 9120769331, louder (.3) | `SeedPackClient.client.lua:215`, next to `HeavenlyStarted`: when `t>=revealStart`, `rank>=6` and the bag is not yours, play once: `LocalSfx.Play(id, seedPos, .3, rank==8 and .88 or 1, 3)` | CONFIRMED |
| M14 | Taking the mystery pack (hold E) | Bubble04, the generic click | **Bubble06** (pickup) | `MysteryPackClient.client.lua:65` `'Bubble04'` becomes `'Bubble06'` (R150 work in progress) | CONFIRMED |
| M15 | Settings volume rail tap (`SettingsClient:62,66`); −/+ | rail none; −/+ Bubble04 before the new level applies | Preview **at the new level**: Interface row → Bubble04; Effects row → `RarityRevealAudio.Play('Pop')` | `SettingsClient.client.lua:52-56` `change()`: after `apply`, preview for Effects or Interface. `ButtonSound=false` on those rows' −/+ | CONFIRMED |
| M16 | Index Half/End reward claims (`ChestIndex:241-242,434-435`) vs seed card claims | gem claims: no press click then GemClaim; seed card: Bubble04 then KaChing | Press = Bubble04 for both | drop `ButtonSound=false` at `ChestIndex:42,52,219` | CONFIRMED (minor) |
| M17 | Treadmill: step on or jump off; speed-gain popups | none | optional: Equip on start; none per gain (too frequent) | `InteractionFeedback`: `TreadmillTraining` false→true | PLAUSIBLE, optional |
| M18 | Hold-E prompts (steal, take, harvest): hold start | none (Roblox's default prompt has no sound) | optional soft Bubble04 on `PromptButtonHoldBegan` for your own prompts | one client listener on `ProximityPromptService.PromptButtonHoldBegan` | PLAUSIBLE, optional |
| M19 | Pop-ups with no input: offline-growth notice, Index reward badge pop (`ChestIndex:158-160`), bonus roll ready, Daily auto-open | none; Daily auto-open gets MenuClick from M4 | optional GemClaim on the Index badge pop only | `ChestIndex:158` | PLAUSIBLE, optional |

Already covered, with nothing missing:

- pack taken (Bubble06 + alarm), deposit (success), caught (snap + voice), trap (thud), dig and cover
- planting (pile beats), pack tear and reveal
- market buy, sell and equip (click + KaChing/Equip), Robux and gem purchases (KaChing / GemClaim + confetti)
- daily and quest claims, Index seed claims, gift received, Verity hand-in
- bonus roll (ticks + result), mystery unlock
- tutorial (welcome, steps, done), leaderboard arrows, all tabs and filters (Bubble04)
- upgrade press (UpgradeClick), keyboard (clicks), storm (rumble + thunder), The Darkened (arrival + catch)
- refresh (pings + horn), chase (alarm, heartbeat, near ping, music)

There is no codes or redeem UI in the game.

---

## 5. Sound language (existing assets only)

| Meaning | Key | Asset | Group | Rule |
|---|---|---|---|---|
| Press inside a panel (tab, filter, ±, card, arrow, select, Buy/Sell press) | `Bubble04` | 96764044228884 (lead-in .100) | Interface | default for every GuiButton (ButtonHighlights) |
| Open a panel or dialog | `MenuClick` | 116737765668953 | Interface | `SeedMenu` nil→X or X→Y; nav hub; dialogs without SeedMenu |
| Close a panel (X, shade, Esc/B, walk away) | `MenuClose` *(new key)* | MenuClick file at PlaybackSpeed .85 | Interface | `SeedMenu` X→nil; stops a MenuClick like MenuClick does |
| Something comes to you | `Bubble06` | 131731955363530 (.100) | Interface | pack taken, fruit lands (flash), coin reaches wallet, mystery pack taken, gift sent |
| Equip or unequip | `Equip` | 99675704394731 | Interface | hotbar (slot, keys, L1/R1), shop gear |
| Physical button in the world | `UpgradeClick` | 87218932219010 (.015) | Interface | upgrade caps |
| Cash transaction succeeded | `KaChing` | 86218459564041 | Interface | buy, sell, cash claims, upgrade bought, normal roll |
| Reward or celebration | `GemClaim` | 82559527540705 | Interface | gem claims, daily, purchase done, gift received, unlock, special roll, tutorial done |
| Refused or error | `Denied` *(new key)* | built-in `rbxasset://sounds/electronicpingshort.wav` at speed .55 (a low muted blip, like KeeperNearAlarm). Fallback: MenuClick file at .7 | Interface | red notices, `kind='Denied'`, local refusals; gap 0.25 s |
| Movement or teleport | `Whoosh` | 9120768742 (.44) | Effects | teleport arrival, bat swing |
| World impacts and reveals | LocalSfx / RarityRevealAudio ids | Effects, 3D | world events heard by others nearby |

`InteractionAudio` needs a small change for the two new keys:

- `Asset()` must accept an `rbxasset://sounds/...` string.
- Add `Speeds={MenuClose=.85,Denied=.55}` and apply it to each voice in `pool()`.
- Add `Gaps={Denied=.25}`, defaulting to .09, plus the optional `minGap` argument from S2.
- `MenuClose` uses the same stop-all-voices rule as `MenuClick`.

No upload is needed. Every id in this table is already in the game.

---

## 6. Mixer, volume, pools and replication

- **R1. Sounds made in workspace before `AudioMixer.Start()` are never routed. CONFIRMED (mock), PLAUSIBLE (timing).**
  - `Start()` (`AudioMixer:24-31`) scans only SoundService, then listens for new sounds. Mock: a sound already in workspace has
    `SoundGroup=nil`; one added after `Start` gets GardenEffects.
  - `SettingsClient` calls `Start()` only after `WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')` (`:3-5`). So the
    following ignore the **Effects** slider, including 0:
    - keeper **snores** made earlier by BeastAnimation. `KeeperSleep:58-62` never routes, and `Sound:Play()` at `:92` bypasses SoundTiming.
    - Roblox's default character sounds (jump, land) for characters present at join.
  - **Fix:** add `require(script.Parent.AudioMixer).Route(sound,'Effects')` in `KeeperSleep.new`. In `Start()`, also route the descendants of
    every current `player.Character`. Move `Mixer.Start()` to the first lines of SettingsClient, before the remote wait.
- **R2. Saved volumes apply only after `SettingsState` answers. CONFIRMED (code + mock).**
  - Groups start at the defaults (mock: Effects volume 1) and change when `loadSettings` returns (`SettingsClient:77-85`), which can retry
    every 3 s. A player who saved Music or Effects = 0 hears the first seconds of a session at 100%.
  - **Fix:** have the server put the saved mix on the Player as attributes at data load, and have `AudioMixer` read them at require. Or keep
    Music at 0 until settings arrive; it fades in anyway.
- **R3. Category check. CONFIRMED (by design).**
  - These are on **Interface** ("Button sounds"), not Effects: purchase and reward chimes (KaChing, GemClaim), pickup (Bubble06), notice cues
    and bonus ticks. Effects = 0 does not silence them.
  - Verity and the keyboard explicitly stop at Effects 0, and the group mutes the rest of the Effects sounds.
  - Keep as is, or rename the slider to "Interface sounds" so players know.
- **R4. GardenWallet sets `ButtonHighlight=false` after parenting. CONFIRMED (mock).**
  - `ButtonHighlights` reads that attribute only when it binds. The mock shows a CompactPurchase button set after parenting still plays
    Bubble04, while one set before parenting is silent.
  - So the phone wallet tap clicks or not depending on LocalScript start order.
  - **Fix:** M4 (`ButtonSound=false`, read at click time). Set attributes before `Parent` from then on.
- **Pools and rate limits (checked):**
  - InteractionAudio: 3 voices per key, 0.09 s gap.
  - LocalSfx: 12 alive, 35 ms / 6-stud de-dupe.
  - Keyboard: 12 voices, at most 12/s per presser.
  - PlantingEffects: 3 emitters, 0.09 s. The R123 note still stands: a 4th planting within ~2.9 s moves an emitter, so the earlier pile's
    *Settle* sounds at the new pile, a few studs away.
  - Bonus ticks: 4 voices, ≤ 30/s. Heavenly chord: 2.4 s cooldown. Purchase celebration: 0.25 s gap. Notice cues: one at a time.
  - Dig variants have no voice cap, but are bounded by the server hole rate.
  - Every proposal above reuses these pools. Rapid clicks cannot stack because the same key within the gap plays once.
- **Replication:** every Sound is created on the client, under SoundService (2D UI) or under client parts and attachments (3D). The server
  creates none, so nothing replicates. UI cues are SoundService-only and so local to the player.
- **Other players' views:**
  - These play for everyone nearby: digs, covers and traps (`FireAllClients`), plantings (others at ×.75), pack tears, keeper hits,
    keyboard presses, and the Legendary/Mythic burst.
  - Gaps: Secret+ pulls (M13) and the bat swing (M12).

## 7. Verification

- **Mock harness:** the R123 `world.luau`, the real R149 `ReplicatedStorage` modules, and the real `TreadmillBonusClient`.
  It reproduced the following findings:

  | Check | Mock result |
  |---|---|
  | SoundTiming offset | 0.1 vs explicit-0 override 0 (S3) |
  | Bubble04 click vs Common pop start | 0.1 vs 0 → pop late 0.093 s (S3) |
  | 5 pack clicks at 0.065 s | 3 sounds (S2) |
  | Mythic burst 2 s late | still plays (S7) |
  | Uncommon burst 0.9 s late | dropped (the guard works for low tiers) |
  | Onlooker burst TimePosition | 0 (S8) |
  | Darkened arrival 0.8 s late | sound at 0, darkness at 1 (S4) |
  | Workspace sound before `Mixer.Start` | `SoundGroup` nil (R1) |
  | Effects group before settings load | volume 1 (R2) |
  | ButtonHighlights | Close → Bubble04, Shade → none, GiftVeil → Bubble04, CompactPurchase → none or Bubble04 (attribute before vs after parenting), MenuButton → none (M4, R4) |
  | Harvest flight | 0.436 / 0.52 / 0.64 / 0.70 s at 3 / 10 / 20 / 30 studs (S1) |
  | Bonus ticks | 35 requested, 34 played (S9) |

- **Existing suites on R149, all green:** audio_R123 `run.sh` 37 checks, 0 fails; R149 `run_keyboard.sh` 383/0; R149 `run_verity.sh`
  (all Verity suites passed); holes_R122 `run.sh` 106/0 and 79/0.
- **Needs Studio ears (PLAUSIBLE):** S5 (dig cuts), S6 and S13 (lead-ins), the Verity cut region, and the choice of the new `Denied` and
  `MenuClose` sounds, the teleport and swing whoosh, and the Equip cue for frequent hotbar use.

## 8. Files a fix round will touch

- **Sync:**
  - `StarterPlayerScripts/EconomyClient.client.lua` (S1; M3; M4; M7)
  - `StarterPlayerScripts/Hotbar.client.lua` (S1, M1, M4)
  - `StarterPlayerScripts/PackOpeningFeedback.client.lua` (S2)
  - `ReplicatedStorage/InteractionAudio.lua` (S2 `minGap`; new MenuClose/Denied keys)
  - `ReplicatedStorage/RarityRevealAudio.lua` (S3, S7)
  - `ReplicatedStorage/VeiledArrivalFx.lua` (S4)
  - `ReplicatedStorage/TrackHoleConfig.lua` (S5, Studio data only)
  - `StarterPlayerScripts/KeyboardTrack.client.lua` (S6)
  - `ReplicatedStorage/SoundTiming.lua` (S8 Starts, S13 measured Starts)
  - `ReplicatedStorage/RevealFlourish.lua` (S8)
  - `StarterPlayerScripts/TreadmillBonusClient.client.lua` (S9, M3, M4; **R150 work in progress**)
  - `ReplicatedStorage/WorldStatusState.lua` and `WorldStatusHud.lua` (S10)
  - `StarterPlayerScripts/VerityClient.client.lua` (S11, M3, M4)
  - `ReplicatedStorage/KeeperFx.lua` and `StarterPlayerScripts/KeeperHitEffects.client.lua` (S12)
- **Missing or inconsistent:**
  - `StarterPlayerScripts/ButtonFeedback.client.lua` (central menu hook)
  - `StarterPlayerScripts/NotificationClient83.client.lua` and `ServerScriptService/ChestChaseServer/NotificationService.lua`, `FastTravelService.lua`, `TrackHoleService.lua` (Denied)
  - `ReplicatedStorage/GardenWallet.lua`, `ReplicatedStorage/PassGiftDialog.lua`, `ReplicatedStorage/SaleMoneyEffects.lua`
  - `StarterPlayerScripts/` `PlantInspection`, `TravelButtons`, `InteractionFeedback`, `FruitGiftClient`, `GardenShovel`, `BatClient`, `SeedPackClient`, `SettingsClient`, `DailyRewardsClient`, `ChestIndex`, `GamePassClient`
  - `ReplicatedStorage/TitleScreen104.lua`
  - `StarterPlayerScripts/MysteryPackClient.client.lua` (M14; **R150 work in progress**)
- **Mixer:**
  - `ReplicatedStorage/AudioMixer.lua` and `ReplicatedStorage/KeeperSleep.lua` (R1)
  - `StarterPlayerScripts/SettingsClient.client.lua` (R1 order, R2, M15); R2 also touches the server data load if attributes are used

---

## Appendix A. Input coverage matrix (R149)

| Area | Input (file:line) | Sound today | Status |
|---|---|---|---|
| HUD | MENU hub (`HudLayout:365`), nav options Settings/Index/Shop (`:397`) | MenuClick | OK |
| HUD | BASE / TRACK (`TravelButtons:44`) | Bubble04; arrival none; refusal none | M7, M3 |
| HUD | DAILY / INVITE (`DailyRewardsClient:40,301,322`) | Bubble04 | M4 (DAILY opens a menu) |
| HUD | Wallet Gems row / "+" / phone tap (`GardenWallet:11,18,21`) | Bubble04 / Bubble04 / order-dependent | M4, R4 |
| HUD | BONUS ROLL, SKIP, AGAIN, CLOSE (`TreadmillBonusClient:346-349`) | Bubble04; error none | M3, M4 |
| Hotbar | slot click (`:192`), keys 1-0 (`:511`), L1/R1 (`:514`), Bag card (`:236`), drag to slot (`:500-506`) | Bubble04 / none / none / Bubble04 / none | M1 |
| Hotbar | Bag button (`:522`), B or \` (`:510`), Esc (`:512`), × (`:522`) | Bubble04 / none / none / Bubble04 | M4 |
| Hotbar | category, rarity filter and options (`:200,284,288`) | Bubble04 | OK |
| Settings | −/+ (`:65`), rail (`:66`), Quality (`:75`), Replay tutorial (`:94`), X / shade (`:97`) | Bubble04 / none / Bubble04 / Bubble04 / Bubble04, none | M15, M4 |
| Index | tabs (`:292`), cards (`:396`), half/end/bonus claims (`:241-242,434-435`), X / shade (`:442`) | Bubble04 / Bubble04 + KaChing / GemClaim only / Bubble04, none | M16, M4 |
| Daily | tabs (`:300`), claim login and quest (`:275-276`), X / shade (`:302`), auto-open (`:307-313`) | Bubble04 / Bubble04 + GemClaim / Bubble04, none / none | M4 |
| Robux shop | jump tabs (`:361`), pack count (`:103`), gem buys (`:204-212`), Robux (`:205-213`), Max/Convert (`:220-221`), X / shade (`:391`) | Bubble04 (+ KaChing / GemClaim on success) / X Bubble04, shade none | M4 |
| Gift pass | recipient, gems, Robux, X (`PassGiftDialog:57,65-67`), veil | Bubble04 / veil Bubble04 | M4 |
| Market | open via station prompt (`EconomyClient:481`), Buy/Sell modes (`:390`), Trails/Boots (`ShopMenu:33`), Buy/Equip (`ShopMenu:58`), Sell/Sell ALL/filters (`HarvestSellMenu:24,35,60`), X / shade (`:474-478`), walk away (StationMenuGuard) | Bubble04 at round trip / Bubble04 (+ KaChing/Equip; failure text only) / X Bubble04, shade none, walk-away none | M3, M4 |
| Market | money icons click / hover (`SaleMoneyEffects:154-156`), coin arrival (`:102`) | Bubble04 / none / none | M6 |
| Verity | Talk prompt (`VerityService:90-92`), GIVE (`:570`), X/Close/shade (`:576`) | voice / Bubble04 + GemClaim, Refused none / Bubble04, none | M3, M4, S11 |
| Title | Click to Start (`TitleScreen104:180`), Enter/A (`:175-179`) | Bubble04 / none | M11 |
| Tutorial | Go/Next/Skip (`:400-401,509`), welcome, step, done | Bubble04 / Bubble04 / Bubble06 / GemClaim | OK |
| Leaderboard | arrows, jump (`LeaderboardClient:215-216`), wheel (`:232`) | Bubble04 / none | OK |
| Garden | plant select (`PlantInspection:139-150`), harvest key / hold E (`:57`, `GardenHoldHarvest`) | none / Bubble06 at reply | M5, S1 |
| Garden | seed planting click, tap or R2 (`EconomyClient:653-673`) | Dig/Land/Settle at the pile; a miss is text only | M3 |
| Garden | GO TO TOP prompt (`GardenPlantRuntime:84`, `EconomyClient:687-688`) | none | M7 |
| Garden | shovel click (`GardenShovel:69-78`), Remove/Keep (`:62-68`), Esc (`:72`) | none / Bubble04 / none; removed none | M4, M10 |
| Garden | upgrade caps E/R or click (`GardenUpgradeService:44-68`) | UpgradeClick; success none | M8 |
| Gifting | click a player with fruit (`FruitGiftClient:117-126`), Give/Cancel (`:115-116`), Esc/B (`:119`), received (`:146-150`) | none / Bubble04 / none / GemClaim cue | M4, M9 |
| Track | steal, hold E (ChaseService / ConcurrentKeeper / VeiledEvent81 / Latch ClaimPrompt) | hold none; taken Bubble06 + alarm | OK (M18 optional) |
| Track | seed pack clicks (`PackOpeningFeedback:99`) | Bubble04 (2 of 5 dropped at speed) | S2 |
| Track | shovel dig or cover, click/tap/R2 (`TrackHoleClient:117-126`) | dig variant; refusal none | S5, M3 |
| Track | bat swing (`BatClient:47`) | none (hit = slap) | M12 |
| Track | running on keys | clicks | S6 |
| Track | mystery Take, hold E (`MysteryPackService:52-54`) | Bubble04 + burst | M14 |
| World | treadmill on, jump off (`SpeedGainPopup:233-238`) | none | M17 (optional) |
| World | hide in bush, jump, ragdoll and get up | none / engine jump-land / none | OK |
