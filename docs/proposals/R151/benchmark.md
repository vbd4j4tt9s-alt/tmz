# R151 research: the top Roblox games vs Steal A Pack (look, feel, map, build) and what to add

Research only. No game code, installer or map changed. Written 5 Oct 2026 for the owner's question:
*"review the most popular games on Roblox and compare their general aesthetic and game feel and map design and build to our game
what do u think we can add or incorporate into our game or what is missing"*.

**How to read the tags**
- **[S]** = a fact from a source (links in section 9).
- **[O]** = something I saw myself: our place file, our code, our preview renders, or your reference clip and screenshot.
- **[I]** = my opinion or guess. Treat these as advice, not fact.

**Limits**
- The research tools could not open any web page directly. Wikipedia, Roblox's newsroom, rowatcher, levelupplay and everythingedinburgh were all refused.
- So every [S] number comes from search-engine summaries of the linked pages. Player counts are snapshots, and the trackers disagree with each other. Check a number before you repeat it in public.
- I can't play Roblox here. For other games I relied on articles, plus your 2.9 s reference clip and your phone screenshot.
- For our game I used the place file you uploaded (`sapkeyver.rbxl`, 4 Oct), the code, and our three.js previews.
- **The previews can't show our real look.** They have no Roblox lighting, materials, bloom, shadows, motion or sound. A 30-second phone recording of our game would make the next comparison much fairer.

| Picture | What it shows |
|---|---|
| `map_topdown.png` | Our saved map from above, made from the place file: the hub with its 6 bases, and the whole track at small scale. Things built while the game runs (keys, market, Verity) are not drawn. |
| `ref_keyboard_escape.jpg` | One frame of your reference clip (+1 Speed Keyboard Escape), with 14 numbered things it does that we don't. |

---

## 0. One-screen summary

**What's on top right now [S]**
- **Steal An Egg is the #1 game on Roblox**: about 1.6M players at once on 30 Sep 2026, about 5× the next game.
- Its loop is almost exactly ours:
  - steal eggs from biome guardians;
  - you need enough speed for each biome;
  - train on treadmills at your base;
  - hatch the eggs in a pen for income.
- **+1 Speed Keyboard Escape**, the game our keyboard track was modelled on (R147), held about 360–370K players in Jul–Aug.
- **Grow a Garden 2** (launched 12 Jun 2026) runs at about 430–505K.

**Our strongest points**
1. **Big moments land.** Pack reveals, bonus rolls and the pedestal unlock build up with sound and light, and get bigger with rarity. The Darkened's arrival turns the lights out for everyone.
2. **Lots of reasons to come back.** Daily login week, daily quests, the daily mystery pedestal, offline growth with a "your plant is ready" phone alert, Fruit of the Hour, and the Verity limited event. That matches what Roblox's 2026 recommendations reward: players coming back on day 1 and in weeks 1–4 [S].
3. **Risk you can read at a glance.** "SPEED NEEDED ⚡ 2.5M" turns green over each keeper. Steal An Egg has speed gates per biome too [S]. Guides list them; I couldn't check whether its world shows them.
4. **The garden already moved the way Grow a Garden 2 moved**: from blocks to round, animated growth (R149).
5. **A clean, fair shop** and real care for phones.

**What we're missing (biggest first)**
1. **Live events on a schedule.** The leaders in our genre all run "admin abuse" hours with weekly updates (Steal a Brainrot, Grow a Garden, Steal An Egg) [S], or timed boosts like Keyboard Escape's "Admin Wins x3" and its Friday x200 treadmill [S][O]. We have the owner commands, but nothing players can plan around.
2. **The hub is an empty walled field.**
   - 6 bases sit against 48-stud plain walls, with a large empty grass plaza in the middle.
   - You can't see the track, the runners or the keepers from the hub.
   - Grow a Garden 2 and Steal a Brainrot put every base around one busy shared centre.
3. **Nothing to show off.** Your best pulls live in the Bag, so other players never see them. Steal a Brainrot's whole base is a trophy display, and Grow a Garden 2 has decorations.
4. **Missing standard features**: codes, Roblox badges, a group reward, a server-wide shout for Secret/Cosmic/King pulls, and seasonal dressing (it's October).
5. **Bigger systems the leaders all have**: trading, rebirth, and player-vs-player base stealing. All three are big decisions for you, not quick adds.

**Top 5 for the next releases** (details in section 7)
1. **Event Hours**: server-wide timed boosts on a fixed schedule, themed "Spooky Hour" for October, with a countdown.
2. **Halloween kit**: hub and track dressing, keeper hats, one limited seed, and a seasonal tag in the game title. Before about 20 Oct.
3. **Codes + badges + group reward + rare-pull shout.**
4. **Hub makeover**:
   - a track gate with a live "who's on the track" board;
   - an event clock;
   - weekly leaderboards;
   - a "best pull today" hall of fame.
5. **Base trophy shelf + decorations** that you buy with gems.

---

## 1. What's popular right now (Sep–Oct 2026)

| Game | Players at once (date) | What it is | Why it matters to us |
|---|---|---|---|
| **Steal An Egg** | **1.6M (30 Sep)**, #1. Peak ~2.2M in Aug. Launched 25 Jul 2026 [S] | Steal eggs past biome guardians, run to the safe zone, hatch them in a pen, earn per second, upgrade treadmills and pen slots [S] | **The same genre as ours**, and the fastest-growing game on Roblox |
| Brookhaven RP | 329.6K (30 Sep), #2 [S] | Role-play town | A social hub, not our genre |
| Murder Mystery 2 | 545.9K (Jul). All-time record 1.35M in Aug [S] | Murder rounds; knife and gun trading (general knowledge, not re-checked) | Trading economy |
| **Grow a Garden 2** | 505K (Jul), ~430K later. Peak 976K [S] | Plant, harvest, sell. **Night raids on other players' gardens** [S] | Our garden half's main rival |
| **+1 Speed Keyboard Escape** | 370K (Jul), 358K (Aug). 3.12B visits, ~97% likes [S] | Every step gives +1 speed, on giant candy keyboard keys [S] | **Our keyboard track's reference** |
| Animal Hospital (Anomaly) | 347–358K (Jul–Aug) [S] | — (not researched) | — |
| 99 Nights in the Forest | 343.6K (Jul) [S] | Survival horror around a campfire | Lighting and mood |
| Blox Fruits, RIVALS, Anime Expeditions, Adopt Me! | 180–280K (Jul) [S] | — | — |
| **Steal a Brainrot** | Record **25.4M** at once, the biggest any game has had. Still top tier in 2026 [S] | Bases around a centre; buy or **steal from other players' bases**; rebirths [S] | Base and stealing design |
| Kick a Lucky Block | Peak 1.7M (May 2026) [S] | Kick blocks, collect, place on your plot, train [S] | Same kind of loop |

**How Roblox picks games to recommend (2026) [S]**
- It looks at the last **28 days**, split into day 1, days 2–7 and days 8–28.
- It rewards players who **come back within 24–48 hours** for a second, shorter visit.
- A like ratio above ~70% matters.
- [I] That favours exactly what we have been building: plant timers, daily resets, the pedestal and limited events. Scheduled events are the next step on the same path.

---

## 2. Our game today, in plain facts

### Hub (from the place file) [O]
- **Shape**: a flat grass rectangle, **680 × 524 studs**, closed by **48-stud-high plain walls** with wood caps.
- **Bases**: 6 plots, 244 parts each.
  - Bases 1–4 stand along the side walls; 5 and 6 sit at the back.
  - The outer bases are about 250 studs from the middle.
- **Middle column**: the market (built while the game runs) and Verity.
- **Empty space**: a large empty grass area behind them, around (0, −440).
- **Spawn**: each player spawns in their own base. The hub spawn by the safe line is only a fallback.
- **The track**: leaves through a 180-stud gap in the front wall. From inside the hub you can't see down the track.

### Track [O]
- **Shape**: one straight corridor, **180 studs wide**, about **6,080 studs long** in play (Forest 180, Jungle 450, Desert 650, Snow 850, Lava 1,050, Crystal 1,300, Storm 1,600). There are walls on both sides.
- **Floor**: candy keyboard keys in each biome's colours (R148/R149), and a cream spacebar with the biome's name at each start.
- **Pickups and keepers**: 35 pack pads and 7 keeper camps.
- **Landmarks** in the saved map exist in only 3 of the 7 biomes:
  - Desert: 16 parts;
  - Lava: 629 parts, plus the lava river;
  - Crystal: 187 parts.
- **The rest**: Forest, Jungle, Snow and Storm get only the "sparse" scenery added when the game runs (about two wall features per biome).

### How it's built [O]
- **Saved map** (`ChestChaseMap`): 4,927 parts. 154 of them are MeshParts (about 3 %); the rest are blocks and wedges. The other 288 MeshParts in the file were GPT's toolbox keyboard, which R147 retired.
- **Everything else** (keys, market dressing, pedestals, fruit and plants, keepers' extras) is built by scripts from parts while the game runs.
- **Meshes**: the true meshes are the keepers' bodies, the keyboard keycap, the baked fruit (R149) and the original plant meshes. Everything else is blocks, wedges and balls.
- **Text**: the interface uses Fredoka One (the usual cartoon simulator font).
- **Lighting**: "ShadowMap" quality, the sun fixed at mid-afternoon (14:12), a light colour grade, and a mood per biome. Weather darkens the base only.

### Sound [O]
- Calm classical music (Morning Mood, Clair de Lune), and a chase track while you carry a pack.
- Every input has a sound since R150.

### Systems
- Done or live [O]:
  - treadmills and bonus rolls;
  - shovel holes and bats (the only player-vs-player play, and only on the track);
  - The Darkened and Void packs; Verity until 1 Nov;
  - daily login, daily quests, the daily pedestal;
  - Index with LIMITED tab;
  - gifting;
  - weather mutations; Fruit of the Hour;
  - friend boost and invite;
  - global top-100 speed board.
- Not in the code [O]: codes, badges, a group reward, trading, rebirth, scheduled server events, a day/night cycle.

### What I can't judge [O]
How it really looks in Roblox: lighting, material shine and how busy the hub feels with 6 players. The previews are approximations.

---

## 3. Side-by-side comparison

Tags apply per cell. "—" means I couldn't check it.

| | **Steal A Pack (us)** | **Steal An Egg** | **Steal a Brainrot** | **Grow a Garden 2** | **+1 Speed Keyboard Escape** |
|---|---|---|---|---|---|
| **Look** | Bright cartoon, Fredoka UI, a candy keyboard per biome, mood light per biome, fixed afternoon sun. New fruit is round; keepers and some plants are still boxy [O] | Eggs and pets; mutated eggs change shell colour (silver, gold, rainbow) before you grab them [S]. The rest of its look: — | Meme characters in a colourful, blocky world [S] | **Dropped the blocky look** for smooth, round shapes; detailed crops; redrawn icons and menus [S] | Pink, purple and chocolate candy keys; dense props; **Halloween pumpkins and cobwebs now** [O clip] |
| **Feel** | Strong reveals (sound, light pillar, shockwaves by rarity), a click per key, keeper fling and ragdoll, harvest flight [O]. [I] The run itself gives little between pickup and the safe line | Grab with E, the guardian wakes, run to the safe zone, hatch, watch cash per second [S] | Carry a character home, put it on a pedestal, the income ticks; your base can be raided [S] | Plants **animate as they grow**; night raids add tension [S] | **"+10.5K" floats up at every step**, rainbow trails, numbers always rising [O clip][S] |
| **Map** | Walled square hub, bases on the edges, a big empty middle. One straight ~6,000-stud track; landmarks in 3/7 biomes [O] | 10–11 biomes in a row, each with a speed gate (Lake 900 … Cosmic 700M); bases by the safe zone [S] | **8 bases evenly around a central conveyor** where characters spawn and walk [S] | **Circular map, gardens around one shared centre** with one shop hub [S] | Lobby with treadmills (x1 → x100), Wins pads between stages, a WORLDS portal with its requirement written on it [S][O clip] |
| **Build** | 4.9K saved map parts (~3 % meshes) plus script-built art; z-fighting cleaned up (R149); keyboard drawn in detail only near you [O] | — | Bases have extra floors to unlock; laser barriers and locks [S] | **Build mode**: benches, lights, arches, bridges, traps on a grid, cosmetic only [S] | Mesh keycaps, a busy hub [O clip] |
| **Return hooks** | Login week, 3 quests, daily pedestal, offline growth + phone alert, Fruit of the Hour, The Darkened, Verity limited event, Index rewards, friend boost [O] | Saturday updates so far, with **admin abuse windows** (speed and luck boosts, exclusive eggs), limited events, Index gives permanent speed [S] | Weekly update + **Saturday admin abuse at 18:00 UTC**, rebirth tiers (19 by Aug), **trading** [S] | 10-min day/night cycle with **2-min night raids**, a shop that restocks, offline growth, **guilds** [S]. Grow a Garden also runs a "Ghoul Garden" Halloween event (limited pets and seeds, codes); the summary didn't say which year [S] | Wins, trails, rebirth, **codes**, a **x200 treadmill every Friday for 1 h**, event timers on screen, music system (Jul) [S][O clip] |
| **Money** | Clean shop: Robux bundles, Mech packs, passes, gem perks, purchase celebration; no buy buttons on the main screen (your choice) [O] | x2 Money 399 R$, x2 Growth 467 R$ [S] | — | — | **One-tap Robux speed buttons** on screen, a "2x Speed" offer, chat shouting other players' purchases [O clip] |

**99 Nights in the Forest** in one line [I]: darkness is the danger and the campfire's light is safety. This is general knowledge; the search result I found described a mobile copy, not the Roblox game. It is the same idea as The Darkened's lights-out, used as the whole game's mood.

---

## 4. What we already do well (honest)

1. **The reveal ladder.**
   - Common pops are short. Legendary and Mythic build up and burst. Secret, Cosmic and King get loud ones (R136–R138, R150).
   - The bonus roll (R150) and the pedestal unlock (R150) follow the same grammar.
   - [I] This is on par with the genre, and better than most clones.
2. **Readable danger.**
   - Speed signs over each keeper turn green ✓ when you're fast enough (R147/R148).
   - Steal An Egg's speed gates are what guides are written about [S]. We show ours in the world, at the keeper.
3. **The garden is heading where Grow a Garden 2 went.**
   - What we have: round fruit, baked melon and pumpkin meshes, the sprout pop, the ripe bounce, fruit floating to you, plants swaying while they grow (R149).
   - Grow a Garden 2's headline visual change was exactly this [S].
4. **Return hooks are already rich, and timed right for Roblox's 2026 rules.**
   - Plant timers with a phone alert (R140), the daily reset (login, quests, pedestal), the hourly Fruit of the Hour, and a dated limited event (Verity, ends 1 Nov).
5. **Spectacle event.** The Darkened's arrival dims the lights for everyone, and it guards two Void packs. [I] It's our "admin abuse" moment, but it only happens on its own timer.
6. **Weather you can see.** Mutation outlines, real rain and snow in the base, snow patches (R127–R149).
7. **Respect for players.**
   - No pushy banners or gift buttons; purchase feedback (R148).
   - Reduced motion, Fast mode, a full phone layout (R129), and performance passes (R130, R149).
8. **Sound is complete and on the beat** (R150).
9. **Social basics.** Friend boost, invite, gifting with durable inboxes, a global top-100 board.

---

## 5. What's missing or weaker, ranked

Effort: **S** = part of one release; **M** = 1–3 releases; **L** = several releases plus your design decisions.

Constraints that apply to every item:
- We only ship scripts. Map changes must be built by scripts while the game runs.
- No new uploaded assets unless you upload them. Roblox library sounds and our existing meshes are fine.
- Keep each paste under ~300 KB.
- Respect your past decisions: no 2x banners, no gift buttons, no timed Robux boosts (R121), and some fruit looks are deliberately kept.

### Quick wins (≤ 1 release each)

**Q1. Event Hours: scheduled server-wide boosts (the "admin abuse" pattern, without needing you online)**
- **What players see**:
  - "⚡ SPOOKY HOUR in 1:12:40" on the HUD and on a big clock in the hub.
  - When it starts: a horn, the sky tint changes, and a banner reads "2× speed gain, lucky packs, The Darkened is here!".
  - It runs for 15–30 minutes, for example daily at 18:00 UTC, plus a longer Saturday one.
- **Why it works**:
  - Steal a Brainrot, Grow a Garden and Steal An Egg all run Saturday admin-abuse windows tied to updates [S].
  - Keyboard Escape keeps event timers on screen and opens a x200 treadmill every Friday for 1 h [S][O].
  - These are appointments, and appointments make people come back on a given day.
- **How it fits us**:
  - It works out the schedule from the clock, like `FruitOfHour` and `DailyRewards` already do. So every server agrees without any cross-server messages.
  - New code: a rules module and a server service that publishes attributes, like `FruitOfHourService`.
  - Boosts plug into what exists:
    - speed gain: the friend-boost path in `BaseService`;
    - pack luck: `ChestService` spawn odds and `PackSizePity`;
    - forced weather: `WeatherService.ForceAll`;
    - The Darkened: spawned at the start (`VeiledEvent81`);
    - a stronger Fruit of the Hour.
  - The HUD card goes in `WorldStatusHud`. Owner command: `liveevent now | next | off`.
- **Effort**: S.
- **Risks**:
  - Economy inflation: cap the boost, never let it stack with itself, and keep it on the server.
  - Events at a time when your players are asleep: pick times from your analytics.

**Q2. Codes button**
- **What players see**: a CODES button in the menu. Type `SPOOKY` and get 💎25 or a seed pack, once per account.
- **Why it works**:
  - Every reference game has one [S][O]. Keyboard Escape puts it in the top bar.
  - Codes give YouTubers and TikTokers a reason to mention the game.
- **How it fits us**:
  - The list of codes lives on the server: a module, or an attribute you edit in Studio and publish.
  - Claims are saved in the Premium data. It keeps unknown keys, so no save-format bump is needed.
  - The remote goes through `SecurityGate`. The button goes in the MENU hub.
- **Effort**: S.
- **Risks**:
  - Spam guessing: rate-limit attempts and don't say whether a code exists.
  - Never give anything that can be traded for Robux.

**Q3. Halloween kit (time-critical: October)**
- **What players see**:
  - Jack-o'-lanterns at the hub and the track gate, made from our baked Ember Pumpkin mesh with a carved face of glowing parts.
  - Cobwebs on the hub walls and orange string lights. The hub's colour mood turns a little toward dusk.
  - Keepers wear a small hat or pumpkin (on players' screens only, like the tiger armour).
  - One limited "Jack-o'-Lantern" seed in the LIMITED tab.
- **Why it works**: Grow a Garden's "Ghoul Garden" Halloween event came in two phases, with limited pets, seeds and codes [S] (the summary didn't make the year clear). Keyboard Escape is already dressed up right now [O clip]. Players expect the season.
- **How it fits us**:
  - Dressing: a new script that builds the props on players' screens, with a level of detail like the keyboard. It is switched on and off by date in `LimitedEvent`.
  - The hub mood is a seasonal palette entry in `BiomeMood` / `EnvironmentLighting`.
  - Keeper hats: on the client, like `KeeperAccents`.
  - The seed goes through the roster, `PlantCatalog` and the Index LIMITED tab (R148).
- **Effort**: S for the dressing. +S/M for the seed: a new seed id may need a profile-version bump, as R148 did.
- **Risks**:
  - Phones: cap the props near the camera and the lights.
  - Verity's event ends 1 Nov at the same time; decide whether they share the LIMITED tab.

**Q4. Roblox badges + group reward**
- **What players see**:
  - Badges such as "First King seed" and "Reached Storm", which show on their Roblox profile.
  - "Join the group: +10% pack luck".
- **Why it works** [I]: badges show up on profiles and give goals. A group link builds a channel for your update news.
- **How it fits us**:
  - `BadgeService` calls from existing hooks (`ChestService` reveal, biome entry, Index).
  - The group check runs on join (`SocialService`).
- **Effort**: S.
- **Risk**: you create the badges and the group in the Creator Dashboard. Badges beyond the free daily quota cost Robux.

**Q5. Server shout for big pulls**
- **What players see**: "👑 Ben pulled a KING Prism Monarch!" for everyone in the server, with the existing onlooker sound (R150).
- **Why it works**: Keyboard Escape even shouts purchases in chat [O clip]. [I] Seeing someone else win is the best ad for packs.
- **How it fits us**: the server decides the reveal (`SeedPackRules`), and the notice goes out through `NotificationService` / `NoticeFeed83`.
- **Effort**: S.
- **Risk**: spam. Shout only Secret, Cosmic and King, at most one per player per minute.

**Q6. Game page tags and thumbnails** (no code)
- **What it is**: a seasonal tag in the title ("[🎃] Steal A Pack"), as top games do with "[2X]" and "[🍭]" prefixes [S].
- **Thumbnails**: show the keyboard track, a keeper and a Secret reveal.
- **Effort**: you, 15 minutes.

**Q7. Music per mood** (smaller)
- **Idea**: the hub keeps the calm classical tracks. Each biome or event gets one track from Roblox's free music library; the game already uses library tracks. A spooky track goes with the event.
- **Why**: Keyboard Escape added a music system in July [S].
- **Where**: `BackgroundMusic` and `BiomeAmbience`.
- **Effort**: S.
- **Risk**: taste; you pick the tracks.

### Medium (1–3 releases)

**M1. Hub makeover** (section 6 has the layout)
- **What players see**:
  - A track gate arch with the 7 biome icons and each keeper's speed number.
  - A big "LIVE TRACK" board showing a dot for every runner and how far each has got.
  - An event clock.
  - Weekly leaderboards (most steals, biggest pull) next to the all-time speed board.
  - A "best pull today" pedestal that shows the actual seed model.
  - Paths and benches that join the bases, market, gate and Verity.
- **Why it works** [S]: Grow a Garden 2 and Steal a Brainrot put every base around one busy centre where you see everyone else's wins.
- [I] Our hub is the biggest place players stand around, and right now it's empty grass with plain walls.
- **How it fits us**:
  - Build it with a script, like `MarketLayout` (built at runtime, everything settled and anchored).
  - The board reads player positions on each screen, so it costs the server nothing.
  - Weekly boards add a week number to the store names in `SpeedBoardService`.
  - The hall of fame is a server record of the day's best reveal, shown with `PlantVisuals` and `SeedPackVisuals` (the market showcase does this).
- **Effort**: M (2 releases).
- **Risks**:
  - Part count on phones: keep it under ~600 parts and use level of detail.
  - Streaming: hub props should stay loaded near the spawn.

**M2. Base trophy shelf + decorations**
- **What players see**:
  - A lit shelf at your base entrance showing your 3–5 rarest seeds or fruit, with name and rarity plates. Anyone walking past sees them.
  - Gem-bought decorations (lamps, arches, benches, a statue of your best keeper escape) on fixed spots in your base.
- **Why it works** [S]:
  - Steal a Brainrot's base is a display of your best characters.
  - Grow a Garden 2 has a whole props shop and a build mode.
  - [I] Bragging is a top reason players grind, and gems need more things to spend on.
- **How it fits us**:
  - `GardenBaseLayout` / `GardenFenceArt` (fixed sockets, not free building).
  - A new prop-ownership list in the Premium data.
  - The shelf uses `HarvestPresentation.Build` / `SeedPackVisuals`.
- **Effort**: M.
- **Risks**: performance with 6 bases full of models (only build the shelf for bases near you); gem pricing.

**M3. Landmarks in the 4 empty biomes + a track feel pass**
- **Landmarks**: one tall silhouette per biome, visible from far down the track:
  - a giant hollow tree (Forest);
  - a vine temple (Jungle);
  - an ice spire (Snow);
  - a lightning tower (Storm).
- **Track feel**:
  - speed lines and a slight widening of the view at high speed;
  - a "CLOSE CALL!" pop when a keeper swing just misses;
  - a carry bar showing the distance to the safe line;
  - a streak counter for steals in a row.
- **Why it works**:
  - Steal An Egg's biomes are separate places with their own identity [S]. Keyboard Escape celebrates every step [O].
  - [I] On a 6,000-stud straight corridor, landmarks are how a player feels "I made it to the ice spire". The run needs a reward between pickup and safe line.
- **How it fits us**:
  - Landmarks are built by scripts beside `WorldDesign` / `RouteDress84`, with no collision or query and stretched with `TrackExpansion83`.
  - Feel effects go in client scripts (`RunnerController`, `KeeperHitEffects`). Server timing stays frozen.
- **Effort**: M.
- **Risks**: never block the track; keep each landmark under ~150 parts; FastMode respected.

**M4. A gentle day/night cycle in the hub only**
- **What players see**: a 20-minute cycle; at night the lanterns, glowing fruit and pedestals shine. The track keeps each biome's fixed mood.
- **Why it works** [S]: Grow a Garden 2's 10-minute cycle with a night window is its signature. 99 Nights is all about light versus dark.
- **How it fits us**: `EnvironmentLighting` / `BiomeMood` already own the time of day and colours; add a clock to the hub palette. A possible later hook: a small night bonus to mutation chances.
- **Effort**: S/M.
- **Risks**: readability on phones at night (keep it to dusk-dark, not black); weather and The Darkened already change lighting, so test that they still mix properly.

**M5. Visual consistency pass** (your call)
- **The gap**: some of our models still read as boxes next to the new round fruit:
  - the Ash Tomato (cubes);
  - the Lantern Fern and Amethyst Grape (kept on purpose);
  - the bushes;
  - the keepers' boxy bodies (`tiger_gear.png`).
- **Why**: Grow a Garden 2 publicly moved away from blocks [S].
- **How it fits us**: the same tools as R149 (`FruitMeshes149`-style baked shapes built from code, no uploads).
- **Effort**: M per batch.
- **Risk**: you deliberately kept some looks; this is only an offer.

**M6. Lighting check in Studio** (10 minutes for you)
- **What to try**: switch `Lighting.Technology` from ShadowMap to **Future** and compare the hub at the market and the pedestal glow.
- **Why** [I]: our new lights (market lanterns, pedestal, Verity) would cast real light. Roblox lowers the quality on weak phones by itself.
- **Risk**: frame time. Check with the device emulator, and keep it only if it holds.

### Big bets (several releases; your decision first)

**B1. Trading**
- **What it is**: a two-player trade window (both lock in, both confirm).
- **Why** [S]: Steal a Brainrot moved trading into its interface (13 Jun 2026); MM2 and Keyboard Escape trade. [I] Trading makes rare items worth more and keeps collectors around.
- **How it fits us**: builds on `FruitGiftService` (the durable inboxes) and the existing `PaidTradingAllowed` check (Roblox's rule for paid random items).
- **Risks**: scams, duplication bugs, value inflation, and moderation work. Needs a full design and a lot of tests.

**B2. Rebirth**
- **What it is**: reset speed and cash for a permanent multiplier, a badge colour and a cosmetic.
- **Why** [S]: Steal a Brainrot is at rebirth tier 19; Keyboard Escape is built around rebirth. It extends the ~200-hour end game.
- **Risks**: rebalancing the whole economy; touches the treadmill tiers.

**B3. Player-vs-player base stealing**
- **What it is**: for example a short nightly "raid window" in which one displayed pack can be stolen, with a base lock while you're home.
- **Why** [S]: it is the core of Steal a Brainrot and Steal An Egg, and Grow a Garden 2 made night raids its headline.
- **Risks**: [I] it changes what the game is, it makes small or new players feel bad, and it needs base locks, timers and protection for new players. Today our player-vs-player play is on the track only (bats, holes), which is friendlier. Only do this if you want more competition.

**B4. A world after Storm**
- **What it is**: a second "world" (new biomes and keepers) behind a portal with its requirement written on it.
- **Why** [S][O]: Steal An Egg added an 11th biome (Titan Temple) as an update; Keyboard Escape has a WORLDS portal.
- **Risks**: the map grows; content cost.

---

## 6. Map, hub and base suggestions (specific)

Coordinates are from the saved map (`map_topdown.png`): the track runs toward +Z, and the hub floor is about z −623 to −99.

1. **Track gate at the safe line (z ≈ −100)**
   - A tall arch with "THE TRACK" and the 7 biome icons in order.
   - Under each icon, that keeper's speed number (the same numbers as the keeper signs).
   - Players see where they stand before they run. It is also the obvious meeting point.
2. **Live track board on the inside of the front wall**, either side of the gap
   - A long strip map of the 7 biomes with a moving dot for every player on the track, coloured by player.
   - A carried pack shows as a glowing dot; a keeper chase shows as a red pulse.
   - [I] This solves "nothing to look at in the hub" and creates crowd moments ("he's at Storm with a pack!").
3. **Fill the empty plaza** (around (0, −440), between Bases 5 and 6 and Verity)
   - One central landmark that everyone can see from their base, for example a giant spinning Void pack on a plinth.
   - Beside it, the event stage: re-use Verity's stage style for event hosts and seasonal NPCs.
   - Put the hall of fame ("best pull today", 3 slots) and the weekly boards here.
   - The two back corners behind Bases 3 and 4 (about 200 × 185 studs each) are empty too. They could hold a future event arena or a second-world portal (B4).
4. **Paths**
   - Paved paths from each base gate to the market, the plaza and the track gate.
   - [I] Right now everything is the same grass, so routes aren't readable.
5. **Walls**
   - The 48-stud plain walls block the horizon. Option A: dress them with biome murals made from parts (cheap). Option B: lower the visual wall with hedges and lamps in front.
   - [I] A taller backdrop seen behind the wall (distant biome mountains) would make the hub feel part of the world.
6. **Bases**
   - Keep the owner badge (R131) and the home marker (R132).
   - Add a fence glow that grows with your treadmill tier, so strong players stand out from the plaza.
   - Add the trophy shelf at the gate, facing the plaza (M2).
7. **Sightlines** [I]
   - Put the most exciting things (the event clock, the live board, the hall of fame) on the routes from the base gates to the track gate.
   - Every player walks those routes many times per session.
8. **Phones**
   - Every hub addition is built on players' screens with level of detail, and switched off past ~200 studs.
   - Lights stay few (Future lighting makes each light cost more).

---

## 7. Top 5 for the next releases, in order

| # | Release idea | What players get | Main code areas | Effort | Why this order |
|---|---|---|---|---|---|
| 1 | **Event Hours** (themed "Spooky Hour" in October) | Daily and Saturday boost windows with a countdown, The Darkened guaranteed, lucky packs, 2× speed gain | new rules + service like `FruitOfHour`; `BaseService`, `ChestService`, `WeatherService`, `VeiledEvent81`, `WorldStatusHud`, owner command | S | Biggest lever for coming back on a given day; re-uses systems we already have |
| 2 | **Halloween kit** | Pumpkins and cobwebs at the hub and gate, keeper hats, a dusk tint, one limited seed, a title tag | new seasonal dressing script, `LimitedEvent`, `BiomeMood`, `KeeperAccents`-style hats, roster / `PlantCatalog` / Index LIMITED | S–M | Only worth it in October; Verity ends 1 Nov, so this follows it |
| 3 | **Codes + badges + group reward + rare-pull shout** | A CODES button, profile badges, +luck for group members, server shouts for Secret/Cosmic/King | new codes service via `SecurityGate`, `BadgeService` hooks, `SocialService`, `NotificationService` | S | Standard in every top game; gives creators something to talk about |
| 4 | **Hub makeover** | Track gate, live track board, event clock, weekly boards, hall of fame, paths, a plaza landmark | `MarketLayout`-style builder, `SpeedBoardService`, `LeaderboardClient`, new board client | M | Makes the hub the social space; pairs with Event Hours (the clock lives here) |
| 5 | **Base trophy shelf + gem decorations** | Show off your best pulls; decorate your base | `GardenBaseLayout`, `GardenFenceArt`, Premium data, `HarvestPresentation` / `SeedPackVisuals` | M | Bragging and a gem sink; makes walking past bases interesting |

**Next after that**: biome landmarks + the track feel pass (M3), the hub day/night cycle (M4), then decide on the big bets: trading, rebirth, raids, a second world.

---

## 8. Things I deliberately did not recommend [I]

- **On-screen Robux buy buttons, "2x Speed ONLY x" offers, chat shouts of purchases** (Keyboard Escape does all three [O]).
  - You removed banners and timed boosts in R121.
  - The shop already celebrates purchases.
  - A "server luck" product others benefit from is the softest version, if you ever want one.
- **Floating "+N" on every step of the track.**
  - In our game, speed comes from the treadmill, not from steps. Numbers on the track would mislead.
  - Keep the "+N" for the treadmill (it already exists: `SpeedGainPopup`). Put the track's reward in the carry bar and the escape moment instead (M3).
- **Pets.** Big in Steal An Egg and Grow a Garden 2, but our "creature" role is the keepers, and the collection role is the seeds. Adding pets would split focus.

---

## 9. Sources

Web pages (seen through search-engine summaries only; fetching was blocked):
- Top charts:
  - StudioKrew, Jul 2026: https://studiokrew.com/blog/?p=1910
  - StudioKrew, Aug 2026: https://studiokrew.com/blog/top-roblox-games-august-2026/
  - StudioKrew, Sep 2026: https://studiokrew.com/blog/?p=2016
  - player.one on Steal An Egg: https://www.player.one/robloxs-steal-egg-beating-some-platforms-biggest-games-164086
- Steal An Egg:
  - https://www.sportskeeda.com/roblox-news/steal-an-egg-a-beginner-s-guide
  - https://games.gg/roblox/guides/steal-an-egg-mutations-guide/
  - https://www.lolga.com/news/steal-an-egg-guide-2026-eggs-pets-speed-best-strategies
  - https://allthings.how/every-steal-an-egg-biome-and-its-speed-requirement/
  - https://bloxodes.com/wiki/steal-an-egg/biomes
  - https://allthings.how/steal-an-egg-admin-abuse-start-time-and-schedule/
  - https://progameguides.com/roblox/steal-an-egg-admin-abuse/
  - https://allthings.how/steal-an-egg-how-to-get-gamepasses-in-roblox/
  - https://vpesports.com/guides/steal-an-egg-complete-pet-list-by-zone-with-income-and-index-rewards
  - https://axeetech.com/steal-an-egg-income-calculator/
  - One source (https://profitable.app/roblox/games/steal-an-egg) claims a 9.9M peak, which conflicts with the 2.2M above. Treat it as unreliable.
- Grow a Garden 2 / Grow a Garden:
  - https://www.gosugamers.net/entertainment/news/78614-grow-a-garden-2-has-launched-on-roblox-here-s-everything-new-added-in-this-sequel
  - https://allthings.how/grow-a-garden-2-launches-june-12-with-night-stealing-on-roblox/
  - https://allthings.how/grow-a-garden-2-every-major-change-in-the-roblox-sequel/
  - https://techwiser.com/grow-a-garden-2-changes/
  - https://rblxguide.com/games/grow-a-garden-2/updates/grow-a-garden-2-vs-grow-a-garden-june-2026
  - https://allthings.how/grow-a-garden-2-day-and-night-cycle-length-and-stealing-rules/
  - https://allthings.how/stealing-in-grow-a-garden-2-how-night-raids-and-garden-defense-work/
  - https://techwiser.com/grow-a-garden-2-props-guide/
  - https://roonby.com/2026/06/15/all-props-in-grow-a-garden-2-guide-where-to-get-it/
  - https://nerdschalk.com/roblox-grow-a-garden-expands-halloween-fun-with-ghoul-garden-2/
  - https://deltiasgaming.com/?p=376483
  - https://deltiasgaming.com/?p=374779
  - https://deltiasgaming.com/?p=207402
  - https://www.digitalcitizen.life/grow-a-garden-admin-abuse-schedule/
  - https://www.sportskeeda.com/roblox-news/when-next-grow-garden-update
  - https://www.sportskeeda.com/roblox-news/all-merchants-in-grow-a-garden
- +1 Speed Keyboard Escape:
  - https://rowatcher.com/games/9584852943/1-speed-keyboard-escape-candy-chocolate
  - https://techwiser.com/1-speed-keyboard-escape-beginners-guide/
  - https://earnaldo.com/blog/speed-keyboard-escape
  - https://www.pcgamer.com/roblox/1-speed-keyboard-escape-codes/
  - https://www.iggm.com/news/speed-keyboard-escape-beginner-tips-how-to-build-speed-and-farm-wins-efficiently
- Steal a Brainrot:
  - https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players
  - https://allthings.how/steal-a-brainrot-next-update/
  - https://allthings.how/steal-a-brainrot-trading-plaza-and-update-53-trading-changes-explained/
  - https://www.u7buy.com/blog/steal-a-brainrot-game-mechanics/
  - https://www.u7buy.com/blog/steal-a-brainrot-base-guide/
  - https://www.playnews.gg/en/guides/steal-a-brainrot-roblox-the-complete-strategy-rebirth-and-tier-list-guide-for-july-2026
  - https://rblxguide.com/games/steal-a-brainrot/updates/steal-a-brainrot-best-base-layouts-2026
  - https://kotaku.com/steal-a-brainrot-roblox-empire-review-popular-memes-1851787027
- Kick a Lucky Block and title tags:
  - https://rotrends.com/game/10004244222/Kick-a-Lucky-Block
  - https://rowatcher.com/games/10004244222/2x-kick-a-lucky-block
- How Roblox recommends games (2026):
  - https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
  - https://rowatcher.com/news/what-the-roblox-algorithm-actually-rewards-in-2026-not-ccu
  - https://create.roblox.com/docs/en-us/discovery.md
- Genre trends (secondary, use loosely): https://www.creation.dev/learn/what-roblox-game-mechanics-are-trending-2026

Our own material [O]:
- The place file `sapkeyver.rbxl` (4 Oct), read with `tools/rbxl.py` and `docs/proposals/R149/tools/rbxl_geom.py`.
- Your reference clip (2.9 s, 4 Oct; +1 Speed Keyboard Escape) and the phone reference screenshot (R129).
- `src/` at the R150 release (`9a6c757`).
- Our renders in `docs/proposals/R147`–`R150`.
