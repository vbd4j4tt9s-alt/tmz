# R151: pull reveals with impact (Sol's RNG-style), Common to King

Owner, verbatim:
1. "I also want you to take a look at sols rng for the pull animation, look at secret, cosmic or king. I like what we have for them but I feel it's not good enough and doesn't have that impactful feel to it"
2. "Apply sound effects and so on. King can have an animation of the person's Roblox character being bestowed a crown in a kingdom/palace setting and so on, have creatives and scenes like those for the animations."
3. "The seed should be the main focus in these scenes where it ends with the seed floating down and what not."
4. "Actually rework for the scenes, we can just have the seed pack and seed be animated differently for king, cosmic, secret. Don't need the avatar, as the seed pack and seed have to go hand in hand."
5. "We can also rework the legendary, uncommon and common and mythic short animations to the same quality so there isn't a gigantic quality gap in there, also for the pack animations add more suspense to opening the pack in general."
6. Sounds: the owner uploaded 15 sounds (8 shared, 3 King, 4 Cosmic); only the Secret tier slots wait for uploads.

What this does, in one line: **every pull is now one escalating reveal**: the pack builds suspense (it wobbles, glows, tears a bit at a time, a rarity hint flickers through the cracks), then the seed bursts out and ends **big, centred and floating down** with the rarity word, "1 in N" and its name. Common..Mythic do it in the world plus a seed card; Secret / Cosmic / King cut to a **short story scene** where the **pack and the seed** are the stars (a void vault, deep space, a throne room).

Preview: `docs/proposals/R151/rare_pull.png` (every tier: suspense → reveal → seed; Secret / Cosmic / King on desktop and phone) and `docs/proposals/R151/rare_pull_king.gif` (the King scene, every 0.2 s).

## 1. Sol's RNG: what makes its rare rolls hit

The fandom wiki and the guide sites were **blocked by the session's network proxy** (WebFetch: `EGRESS_BLOCKED` for sol-rng.fandom.com, allthings.how, itemlevel.net). Everything under "sourced" is from **search-result summaries** of those pages (titles and snippets), not from reading the pages; "inferred" is my reading of how it plays.

**Sourced (search summaries):**
- Rolls above a rarity get an **opening cutscene**, and the cutscene style **escalates by rarity class**: EPIC, UNIQUE, LEGENDARY, MYTHIC, EXALTED, GLORIOUS, each "with different backgrounds, dramatic effects, and unique cutscene endings" ([Opening Cutscenes](https://sol-rng.fandom.com/wiki/Opening_Cutscenes)).
- EPIC (1 in 1,000+): "the screen turns black with an ominous noise", then "its edges glow the same color as the aura". UNIQUE (10,000+): black screen, "a dropbeat noise, accompanied by a star of the same color as the aura", edges glow, reveal. LEGENDARY (99,999+): like UNIQUE plus "a white screen cracking sequence at the end before revealing" (same page, via search).
- MYTHIC (1,000,000-9,999,999): "the screen will turn black with light fog corresponding to the obtained aura's color, and the star now has 8 points instead of 4. A jingling noise will play at the beginning ... before a wind noise extends the entirety of the cutscene, the edges glow ... before revealing" (same page). EXALTED: coloured background instead of grey; GLORIOUS: extra effects with the 8-pointed star.
- **Star pull**: "Auras that are of 10k+ rarity all get a star pull animation", and "the colors of the stars may just tell you what you're about to get" ([itemlevel: all star pull animations](https://itemlevel.net/sols-rng-all-star-pull-animation/)) - the colour is a **hint** before the reveal.
- **Chat / server messages**: "[@username] HAS FOUND [aura], CHANCE OF 1 IN [N]!" for EPIC and up; LEGENDARY adds "cyan arches ... around the map" (world effect others see); auras above ~1 in 99,999,998 are **globals**, "announced globally and all have custom cutscenes to match their theme" (Opening Cutscenes, via search).
- Some rolls make **everyone in the server** look at a sky effect ("every player in the server has their camera fixed on visual effects in the sky", search summary of the wiki).
- **Skip settings**: "Cutscene Skip Rarity hides the opening animation for auras below the chosen rarity"; "Play New Aura Cutscene always plays the cutscene for an aura that is not yet in your Collection" ([allthings.how settings guide](https://allthings.how/sol-s-rng-how-to-change-settings-and-redeem-codes-in-roblox/)).
- The rolled aura then **sits on the character** for everyone to see ([allthings.how how to play](https://allthings.how/sol-s-rng-on-roblox-how-to-play-full-guide/)); the lobby sees the result announced while the roller "waits in suspense" (itemlevel).
- A royal aura's cutscene (SOVEREIGN): black screen, "an unsheathing effect ... a hoarse wind noise that continues throughout", teal / yellow fog, "a golden crown fades in and out with a sound before a blue and yellow eight-pointed star appears, revolving while expanding slowly"; the aura itself has a throne and a crown ([SOVEREIGN](https://sol-rng.fandom.com/wiki/Sovereign), via search). Atlas: "your screen will go dark ... You'll hear the sound of winds and stars will start to rise and move around the planet as a fog covers the screen and then lifts" ([twinfinite: Atlas](https://twinfinite.net/guides/how-to-get-atlas-aura-in-sols-rng/)).

**Inferred (the principles used here):**
1. **Contrast first.** The world goes dark / drained before anything happens; the reveal is the brightest, loudest moment by far.
2. **Anticipation that tells you something.** The colour hint ("it could be...") makes the wait the fun part; higher rarities wait longer.
3. **A drop-out before the hit.** A wind / drone bed that stops dead, then the impact.
4. **One hero on screen.** Black background, one star, then the aura - not a busy scene. For us: the pack, then the seed.
5. **Typography and the number.** The rarity name and "1 IN N" are the payoff and are shown big.
6. **Escalating classes, not one effect scaled.** Each class adds a new element (star → 8-point star → coloured background → custom scene).
7. **Bragging in the world.** Others see world effects and the aura on the player; announcements follow.
8. **Skippable**, and short enough to repeat many times.

## 2. The ladder (what each tier does)

| Tier | Suspense (pack in the world, everyone sees it) | The opener's screen | Others nearby | Length (5th click → done) |
|---|---|---|---|---|
| Common | .60 s: 1 wobble, seam glow neutral → pale | seed card .22 of the height, COMMON, "1 in N", name | small ring (R138) | ~1.2 s (quick 0.8 s) |
| Uncommon | .70 s: 2 wobbles, a heartbeat, hint → green | card .24, sparkle | ring + sparkles (R138) | ~1.5 s (0.9) |
| Rare | .85 s: 2 wobbles, heartbeat, hint walks white → green → blue | card .27, faint ring | ring, sparkles, light (R138) | ~2.0 s (1.1) |
| Legendary | 1.10 s: 3 wobbles, 2 heartbeats, riser, screen edges pulse gold, motes gather, camera push (FOV −5°) | card .31, light rays, ground impact | pillar, ring, sparkles (R136) | ~3.5 s (1.5) |
| Mythic | 1.30 s: 4 wobbles, 3 heartbeats, riser + suck-in, brief letterbox, push −7° | card .34, coloured shockwave, rays, big impact | pillar ×2 rings, helix (R136) | ~4.5 s (1.9) |
| Secret | world charge 1.35 s | **story scene: the Sealed Pack** (6.4 s; skip from 1.5 s) | light pillar + 15 s purple wisps aura | 6.4 s |
| Cosmic | world charge 2.45 s | **story scene: Supernova** (8.0 s; skip from 1.8 s) | pillar + 20 s planets / star aura | 8.0 s |
| King | world charge 3.35 s | **story scene: the Coronation** (10.2 s; skip from 2.0 s) | pillar + 25 s gold halo / sparkles | 10.2 s |

- **The server timeline is not changed** (`RarityRevealSequence.SeedAt` and so `RevealDuration` are as before; no server file changed for this). The new suspense of Common..Mythic happens inside the same window: the seed comes out at the end of the suspense and hovers shorter (`RarePullRules.Hover`), so its slide into the hand still ends with `RevealDuration` and opening a pack takes **exactly as long as before** (Common 1.9 s, Mythic 2.8 s). The opener's seed card simply stays a little longer on screen for Legendary / Mythic.
- **Quick reveals**: a pack opened within 3 s of the previous reveal ending is "quick" (shorter suspense and card, fewer sound layers). Secret+ story scenes are never shortened (they are skippable).
- **No jump between Mythic and Secret**: Mythic's suspense (1.30 s) leads straight into Secret's world charge (1.35 s); Secret in-place (when unsafe) is 3.9 s vs Mythic's 4.7 s card.
- **The suspense** (every tier, every viewer, `PackSuspense` + `SeedPackClient`): the 8 tear strips peel in three goes (2, 3, 3) instead of all at once, each with a short paper rip; the pack wobbles with rising sway and a kick on every pulse; the seam glows, pulses faster as it builds and flares on every pulse; **the hint colour starts neutral and walks up the ladder through every lower tier's colour, flickering between neighbours, and settles on the real colour for the last quarter** (a King pack flickers through all eight). It never shows a higher tier than the real one.

## 3. Beat sheets (seconds)

Story scenes run on the opener's clock from the reveal (`RarePullRules.Scenes`); the world dims at 0, fades to black at Cut, the hidden stage fades in at SceneIn, **Silence** = everything drops out, **Climax** = the hit, **Back** = the world and the HUD are back, **Length** = the colour grade has eased back.

### SECRET: the Sealed Pack (dark void), Full 6.4 s / ReducedMotion 4.35 s
| t | Picture | Sound |
|---|---|---|
| 0.00 | world desaturates to violet-grey, letterbox slides in, motes gather, RGB glitch bars | SecretDrone (loop) |
| 0.25 | glitch | SecretGlitch |
| 0.45 → 0.70 | glitch tear, fade to black → the void (black glass floor, violet seams, fog); the pack hangs in the dark, rim-lit | SecretWhisper (loop) |
| 1.30 / 1.90 | the pack glitches (jitter, glitch bars) | SecretGlitch ×2 (the 2nd lower, louder) |
| 1.50 | skip allowed | |
| 2.40 | a ring of 8 dark lock plates with violet bolts closes round the pack and turns: click, click, click | PackShake ×2; Riser starts |
| 2.90 | the bolts pull back, cracks of light grow over the pack, light spills from its edges | SecretVault |
| 3.05 → 3.45 | the pack shudders, the cracks blaze | SuckIn, PackShake |
| **3.45** | **silence** (the screen dips) | everything stops |
| **3.55** | **the pack bursts in violet light**: flash, shards, shockwave ring; SECRET slams in (RGB split, scanlines) | Impact + GroundImpact + PackBurst + SecretGlitch |
| 3.55 → 3.95 | the seed rises out of the dark, big and centred, with its eclipse ring and purple wisps | Sparkle |
| 3.85 → 4.15 | "1 in N" counts up and slams | TitleSlam |
| 4.15 → 5.10 | the seed floats down toward the camera, turning; name under "1 in N" | Sparkle |
| 5.10 → 5.60 | fade to black, back to the world; HUD back; purple wisps around the player (15 s) | |

### COSMIC: Supernova (deep space), Full 8.0 s / ReducedMotion 4.95 s
| t | Picture | Sound |
|---|---|---|
| 0.00 | world tints deep blue, letterbox, stars gather | CosmicPad (owner's music bed, a ~5.7 s slice, fading in) |
| 0.50 → 0.80 | fade → space: starfield, nebulae, a galaxy far off; the pack drifts in like a planet, tumbling (until 2.40) | |
| 1.60 / 2.10 / 2.60 | three planets swing into line behind the pack, each locking with a twinkle | CosmicStar ×3 (rising) |
| 1.80 | skip allowed | |
| 2.60 → 3.90 | the pack spins up, a galaxy spiral forms round it and accelerates | CosmicWhoosh (a 3 s slice), Riser, PackShake |
| 3.90 → 4.35 | implosion: the pack collapses into a bright core, the spiral is sucked in | SuckIn; the bed fades out into the silence |
| **4.35** | **silence** | |
| **4.45** | **SUPERNOVA**: flash, expanding shell, two shockwave rings; COSMIC (nebula gradient, stars, two orbiting planets) | **CosmicBoom** (the owner's underwater explosion: the big hit here instead of Impact; its tail rings under the seed) + GroundImpact + PackBurst |
| 4.45 → 5.30 | the seed flies out of the core as a **falling star** toward the camera and resolves into the seed | CosmicWhoosh; CosmicStar (the shine rings under the seed); the bed returns, softer |
| 4.75 → 5.05 | "1 in N" counts up and slams | TitleSlam |
| 5.30 → 6.60 | the seed, big and centred with its orbit rings, floats down | Sparkle |
| 6.60 → 7.20 | fade, back to the world; two little planets and star motes around the player (20 s) | |

### KING: the Coronation (throne room), Full 10.2 s / ReducedMotion 5.9 s
| t | Picture | Sound |
|---|---|---|
| 0.00 | the world warms to gold and dims, letterbox, gold motes rise | KingChoir (owner's angel choir, a 6 s slice of the swell) |
| 0.55 → 0.85 | fade → the throne room from the doors: red carpet, pillars with banners, windows with light shafts, chandelier, candelabras, a golden throne with a royal cushion, heralds' trumpets | KingBell (low toll) |
| 0.85 → 3.20 | the pack is carried down the carpet in a beam of light and set on the cushion | |
| 2.00 | skip allowed | |
| 3.40 → 4.55 | a crown descends in a beam of light onto the PACK (low angle) | Riser from 4.00 |
| **4.55** | the crown settles; the trumpets rise | **KingFanfare** (cut by the silence) + **KingBell** |
| 4.55 → 5.45 | the crowned pack shakes harder and harder, gold light at its seams | PackShake ×2, SuckIn |
| **5.45** | **silence** | |
| **5.55** | **the pack bursts in gold rays and confetti**, a golden shockwave across the floor; KING (gold gothic letters, a crown, turning rays) | Impact + GroundImpact + PackBurst + KingFanfare (rings under the seed until 9.4) |
| 5.55 → 6.00 | the seed rises crowned out of the light (the crown lifts with it and fades into its own coronation ring) | Sparkle; KingChoir again, softer |
| 5.85 → 6.15 | "1 in N" counts up and slams | TitleSlam |
| 6.00 → 8.70 | the seed floats down the beam to the camera, big and centred | Sparkle |
| 8.70 → 9.40 | fade, back to the world; gold halo at the feet and rising sparkles (25 s) | |

### In place (Secret+ when the full scene is not safe), on the reveal's server clock
The hit is on the world seed's burst (SeedAt: Secret 1.35, Cosmic 2.45, King 3.35 s). The screen edges dim and pulse in the tier colour, motes gather, a soft flash, a **compact card in the upper third** (title, the seed, "1 in N", name), the tier's riser / suck-in / hit / slam. No camera, no hidden stage, HUD and controls untouched. Lengths 3.85 / 4.95 / 5.85 s.

### Common..Mythic (reveal clock, normal / quick)
| Tier | Wobbles at | Burst | "1 in N" slam | Card out | Sound |
|---|---|---|---|---|---|
| Common | .37 | .60 (.35) | .93 (.58) | 1.20 (.80) | PackShake, PackBurst, TitleSlam (+ the R138 pop on the burst) |
| Uncommon | .30 .55 | .70 (.40) | 1.11 | 1.50 | + Heartbeat, Sparkle (+ R138 pop + note) |
| Rare | .37 .67 | .85 (.50) | 1.34 | 2.00 | + Heartbeat, Sparkle (+ R138 sparkle + notes) |
| Legendary | .36 .68 .94 | 1.10 (.62) | 1.67 | 3.50 | + Riser .28→1.02, 2 heartbeats, GroundImpact |
| Mythic | .35 .66 .94 1.16 | 1.30 (.75) | 1.90 | 4.50 | + SuckIn .88→1.22, 3 heartbeats, Impact over GroundImpact |

## 4. Safety, restore, variants

- **Full story scene only when safe** (`RarePullRules.Decide`): not on the track, no keeper within 60 studs or chasing the player, no ragdoll / fling, no run / queue / carried pack, no open menu (`SeedMenu`, title screen), the player's own camera (Custom / Follow), standing on the ground. Otherwise the in-place version.
- **While the scene runs**: the camera is Scriptable only between the fade to black and Back; HUD ScreenGuis that were on are turned off (only those; `TouchGui` is never touched; new ones are caught too) and Core GUI (player list, chat, emotes, health; the Backpack only if it was on); movement held with the PlayerModule controls; Space / Enter / A / B and a tap anywhere skip (silently).
- **Every exit path restores exactly**: the normal end, skip, death, the character being removed, being moved 8+ studs (teleport, fling), a keeper turning up (45 studs or chasing), someone replacing the camera, an error in a frame (the frame is pcall'd), the script being destroyed. Camera type, CFrame, Focus, FieldOfView and subject; the HUD guis it turned off; Core GUI it turned off; controls; its colour grade / blur live **on the Camera** and are destroyed (**Lighting is never written**); the stage is destroyed; every voice stopped; the announcement attributes cleared; no render step or binding left. A scene stopped before its hit (danger / moved / camera / error) still shows a **compact result card** so the player knows what they got.
- **ReducedMotion**: the Calm scenes (cuts only - the camera never moves within a shot; shorter; no shake, no blur, no jitter, no swinging motes, a short seed float), no wobble on the pack (colour pulse only), no FOV push, softer flashes.
- **Phones / low quality / FastMode** (`ClientFxBudget.Low` or a touch-only device): lighter stages (King backdrop 122 parts instead of 189), fewer particles and ring pieces, no blur, gentler shake on phones (35%); on low quality / FastMode also no Highlight on the opening pack.
- **No per-frame work after the end**: the director unbinds its render step; the world module disconnects its RenderStepped when its last aura ends.

## 5. Sound slots (`ReplicatedStorage/RarePullSounds`)

Each slot is `{Id, Volume, Pitch, Start, [Length, AlignEnd], [Region], [Loop]}`. `Id=nil` plays the slot's layered design of sounds the game already has (`RarePullAudio.Fallback`); the beat is the same either way. An id can also be set in Studio with a number attribute `<Slot>Id` on the module. `Start` = the measured lead-in silence. `AlignEnd` enters a riser / reverse whoosh late so it **ends on** the silence however long that tier's build is. `Region` plays a slice of a long file. Cue pitch / volume multipliers (small tier escalation) apply on top. Everything plays on the **Effects** group (Effects 0 mutes).

| Slot | Id (owner upload) | Volume / Start | When (per tier) | Ideal length |
|---|---|---|---|---|
| Riser | 126242461105018 "riser metallic" (2.80 s) | .45 / .128, AlignEnd | Legendary/Mythic suspense; Secret Lock→Silence, Cosmic SpinUp→Silence, King 4.00→Silence; in place | 1-3 s, peaks at the end |
| SuckIn | 115669680103388 "backwards whoosh" (.71 s) | .85 / .100, AlignEnd | Mythic (−.42 s before the burst), every story scene into the silence | .4-.7 s |
| Impact | 133616032782359 "cinematic impact hit" (3.05 s) | .55 / .106 | the hit: Mythic, Secret, King (Cosmic hits with CosmicBoom) | 1-3 s tail |
| GroundImpact | 130581466623902 "ground impact" (1.44 s) | .45 / .082 | Legendary's hit; under Impact for Mythic+ | ~1.5 s |
| TitleSlam | 100663216159686 "punch impact hit" (1.59 s) | .35 / .049 | "1 in N" slams in (every tier) | <.5 s punch |
| Sparkle | 103090716252123 "shimmering object" (42.6 s) | 3 / .048, Region .048-1.548 | the seed floating down (Uncommon+; twice in scenes) | ~1.5 s slice |
| PackShake | 104885054288395 "pill shake" (1.06 s) | .7 / .189 | every wobble pulse; lock clicks; the crowned pack | <.5 s |
| PackBurst | 120422004598250 "splat / thud" (.86 s) | .3 / .044 | the pack bursting open (every tier) | <.6 s |
| AuraHum | 103090716252123 (same shimmer, looped) | 1.2 / .048 | the afterglow aura, 3D at the puller (Secret+) | loop |
| Heartbeat | fallback (the game's heartbeat, .55 s of it) | | suspense beats (Uncommon+) | one beat |
| KingChoir | 71607900050825 "angel choir" (18.3 s, loud) | .18 / .023, Region .023-6.0 | King 0→silence; again softer after the hit until Back | 5-6 s swell |
| KingFanfare | 77199097157197 "medieval fanfare" (7.8 s) | .45 / .056, Region .056-5.0 | the crown lands (cut by the silence); the hit (rings until Back) | 3-5 s |
| KingBell | 110440649150958 "church bell" (3.6 s) | .8 / .088 | the throne room opens (pitch .7); the crown settles | 2-3 s tail |
| CosmicPad | 120548831466483 "leap motiv" music bed (27.5 s) | .3 / .332, Region .332-6.0 | Cosmic 0→silence (fade in .6, out .3 into the silence); after the hit, softer, until Back | ~5.7 s slice |
| CosmicWhoosh | 119158277815268 "deep strange whoosh" (5.9 s) | .4 / .201, Region .201-3.2 | the spin-up (faded at the implosion); the falling star (pitch 1.15) | 1-3 s |
| CosmicBoom | 75435110351652 "large underwater explosion" (6.6 s) | .5 / .088 | the supernova (Cosmic's big hit, instead of Impact; also in place), fades out on the way back | 3-6 s tail |
| CosmicStar | 100732233406279 "shine" (4.1 s, very quiet) | 2.5 / .064 | three short twinkles as the planets lock into line; the star resolving into the seed (rings under it) | .6 s / 1-3 s |
| SecretDrone | fallback (heartbeat + low rumble) | | Secret 0→silence | loop |
| SecretGlitch | fallback (high ping stutter + click) | | glitches; the hit; the bonus roll's Secret result | <.4 s |
| SecretVault | fallback (keeper slam + rumble) | | the lock opens | 1-1.5 s |
| SecretWhisper | fallback (wind) | | under the void | loop |

To audition in Studio: `/test raresound KingFanfare` (one slot), `/test rarepull king|cosmic|secret` (a whole scene with a demo seed; also `common`..`mythic`). Nothing is granted.

## 6. For the R151 pull announcements (the other agent's PullAnnouncer)

The puller's client sets `LocalPlayer` attributes while a reveal runs: `RarePullCinematic` = `Ladder` / `Scene` / `InPlace` / `Result`, and `RarePullClimaxAt` = the server time of the hit (updated on a skip), cleared when it ends. **The banner for the puller's own pull should wait until `workspace:GetServerTimeNow() >= RarePullClimaxAt`** (a Scene hides every ScreenGui added while it runs anyway and shows them at Back); **other players can be told at once**. The all-server shout for Secret+ is unaffected.

## 7. What changed

New (ReplicatedStorage): `RarePullRules` (all timelines, poses, shots, safety, odds, layout, cue sheets), `RarePullCinematic` (the director and every restore path), `RarePullScenes` (the three hidden stages), `RarePullCard` (the screen layer for every tier), `RarePullAudio` + `RarePullSounds` (sound slots), `RarePullWorld` (pillar + aura for everyone), `PackSuspense` (the pack's glowing hint). New (server): `RarePullTestCommands` (the two owner previews). Changed: `PackOpeningFeedback` (starts the director; small pops and burst sound move to the end of the suspense; a camera kick per wobble; the old Legendary / Mythic 2D stays only as a fallback), `SeedPackClient` (the suspense on the opening pack for everyone; the seed's new timing; Secret+ world effects; no giant-pack camera while a scene owns the camera), `TreadmillBonusClient` (the Secret sting), `OwnerUpdateCommands82` + `StudioTestHelp` (the commands), `src/MANIFEST.tsv` (9 rows). Unchanged: every server timeline, odds and grant; `RarityRevealSequence`, `RarityRevealAudio`, `RevealFlourish`, `RarityRevealScreen` (now only the fallback); the shop / mystery / bonus / Verity paths (they all reveal through the pack opening).

## 8. Checked outside Studio

`sh docs/proposals/R151/tests/run_rare_pull.sh <scratch> [only|all]` (the R151 test environment `rare_env.luau` extends the R113 mock with Lighting, the Camera, Core GUI, PlayerModule controls, keepers, and Roblox-faithful `Clone` (attributes, PrimaryPart), `PivotTo` / `ScaleTo` that move every part):
- **static**: every script in `src/` compiles; the 9 new scripts are in the manifest (sorted); the fallback designs only reuse sound ids the game already uses; the slots carry exactly the owner's 15 uploads; no reveal module touches Lighting.
- **test_rare_rules: 439 checks** - every tier's timeline (Full / Calm / InPlace, the ladder normal / quick), the server timeline unchanged and the slide still ending with RevealDuration, escalation, the silence before every hit, skip windows, the hint (neutral → every lower tier → the real one, never higher), wobble / glow / tear, **framing**: from the hit to the end the seed stays near the centre, big, and never under the title or "1 in N" (desktop 16:9, phone 844x390, tablet 4:3), the camera stays inside the stage, the pack until the hit, the King crown on the pack, safety, odds, layout, cue sheets.
- **test_rare_cinematic: 439 checks** - each scene played through frame by frame (HUD / Core GUI / movement held, the colour grade on the Camera with Lighting never written, the camera cut while the screen is black and back at Back, part budgets, the title on the hit, "1 in N", the skip hint, every voice on Effects, the hit / slam on the beat, no voice over itself) and then restored exactly; skip (tap, keys) before and after the hit; every exit path (error in a frame, death, character removed, moved, a keeper chasing / walking up, the camera replaced, the script destroyed) restores and, where it should, shows the result card; ReducedMotion (cuts only, no blur, shorter), phone (lighter, no blur), in place (keeper near, on the track, menu open, in the air: no camera / stage / HUD change); the Common..Mythic card (title waits for the burst, the seed, "1 in N", the push and its restore, the hint colour) and quick reveals; `/test rarepull`, `/test raresound`; the owner's uploads from their measured lead-in, AlignEnd risers ending on the silence, PlaybackRegion slices, the King fanfare / bell / choir on their beats and out of the silence, Cosmic's boom as the hit (no Impact over it, still ringing under the seed), its bed slice clear of the silence and its shine on the alignments, an id set later dropping in; Effects 0; the bonus-roll sting.
- **test_rare_world: 89 checks** - the real SeedPackClient + PackOpeningFeedback: for every tier the seam glows, the hint ends on the tier colour, the seed comes out at the end of the suspense and not before, the pack wobbles and tears bit by bit, the R138 pops / sounds move to the burst, PackBurst on the burst, everything released; the opener's King scene keeps the camera even with a giant pack; onlookers' pillar on the burst (not before), shockwave, the aura and its hum on Effects after the reveal, ending after 15 / 20 / 25 s with no per-frame work left, hidden far away, lighter on low quality; onlookers never get the hidden stage; Mythic keeps R136's flourish (at the new burst); the R150 onlooker impact still once.
- **existing suites, all green**: R136 24; R137 43 + 22 + 11 + 14; R138 18 + 16 + 18, guide flow OK, layout ALL PASS, tutorial 436; R148 purchase 329 + 71 + 75; R147 Verity UI 339; R149 Verity pack 673; audio_R123 37; borders_R123 2341 (it checks every ReplicatedStorage module, so it grows with the new ones); R150 SFX 105 + 38 + 14 + 129 + 25 + fast travel 70; R150 bonus UI 188 + 372 + 37 + 5467 (gameplay files frozen).

Preview: `sh docs/proposals/R151/preview/run_rare_pull_preview.sh <scratch> [node_modules]` plays the real reveals on the mock (`preview_frames.luau`), renders the world / stages with three.js (`rare_pull.html`, `render_frames.mjs`), the GUI with R150's `render_gui.mjs` (patched in the scratch copy only, for the tier fonts and text gradients) and composes with Pillow (`compose.py`). **Approximate**: plain materials (no Roblox textures / Future lighting), stand-in pack art (a pouch in its paper colour) and a blocky stand-in avatar on a grass plane for the world frames, SpecialMesh seeds as spheres / blocks, particles as dots, no trails, the post grade / blur approximated in Pillow, the world camera placed in front of the player.

## 9. Only in Studio
- How it feels: the owner's sounds against the beats (Volumes are set from the measured loudness; tune in `RarePullSounds`), the **Sparkle slice** (`Region`: move it onto the shimmer's brightest 1.5 s), the choir slice.
- Real art: the pack's native meshes and the seeds' meshes in the stages (the preview uses stand-ins), Future lighting in the hidden stages (the void and space are lit by neon and point lights; the throne room also by the global light - check at night time of day), the throne room's look.
- Real fonts (Sarpanch, Michroma, Grenze Gotisch, Luckiest Guy, Fredoka One) and text gradients.
- Phone frame time while a King scene runs (≈190 parts + the seed's aura; phones 122).
- The Roblox camera module after Scriptable → Custom (zoom / shift-lock kept), first person, gamepad skip.
- The opener's view during Common..Mythic (the world camera is the player's; the preview uses a front view).
