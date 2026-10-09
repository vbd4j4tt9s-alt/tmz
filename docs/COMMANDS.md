# Test commands and tools (R147)

## Who can use them
- **You (the game owner)** can use them everywhere: Studio, and live public servers.
- **Other people**: add their user IDs to the `AdminUserIds` attribute on
  `ServerScriptService.ChestChaseServer.OwnerCommandAccess`. Separate several IDs with commas, e.g. `12345,67890`. Publish after.
- `/test admins` shows who has access and who in the current server can use them.
- Everyone else is refused by the server. The client can't fake access.

## How to type them
- In chat: `/test <command>`. `/cctest` also works.
- Or press **F4**, or use the TOOLS button, to open the command box. Type the command without `/test`. The full list is in there.
- **Run it on someone else** by putting their name at the end:
  - `@username` for one player;
  - `@me` for yourself;
  - `@all` for everyone in the server.
  - Example: `/test cash add 1000000 @Bob`.
- Commands marked **server** below change the whole server once. They take no `@name`.
- If a player is in a chase or opening a pack, the command skips them and tells you why.
- **What stays and what doesn't:** cash, gems, speed, treadmill, boots, trails, fence and inventory changes are **saved**. Fly, noclip, movespeed and animrate are temporary.

## Player
| Command | What it does |
|---|---|
| `stats @name` | Seeds, packs, plants, fruit, cash, speed |
| `cash set 1000000 @name` / `cash add …` | Set or add cash |
| `gems add 100 @name` / `gems set …` | Gems |
| `speed 100000000000 @name` | Saved speed points |
| `treadmill 7 @name` | Treadmill tier 1–7 (Forest … Storm) |
| `boots 5 @name`, `trail 6 @name`, `fence 7 @name` | Unlock and equip upgrades (boots 1-5 give luck x25, x250, x10K, x500K, x25M since R155; they were twice that) |
| `bundle SpeedSmall @name` | Give a shop bundle with no purchase |
| `training @name` | Treadmill gain per second (machine x friends) and physical speed |
| `gardenbonus @name`, `cashoffers @name` | Garden bonuses; cash bundle amounts |

## Movement
| Command | What it does |
|---|---|
| `fly 100 @name` / `unfly` | Fly (WASD, Space/E up, Ctrl/Q down) |
| `noclip @name` / `clip` | Walk through walls |
| `movespeed 300 @name` / `movespeed off` | Temporary walk speed 24–500 |
| `animrate 2.5 @name` / `animrate off` | Run animation speed |
| `base @name`, `tp storm @name` | Teleport home or to a biome |
| `heal @name`, `respawn @name` | Heal or respawn |

## Packs and seeds
| Command | What it does |
|---|---|
| `packset storm @name` | One pack of each tier from a biome |
| `pack storm 6 @name` | One pack. Optional extras in order: size, `none`/`gold`/`diamond`, count |
| `void 1 @name` | Void Pack(s), 1–20 |
| `verity 1 @name` | R147 Verity Pack(s), 1–20 (Verity seed 1/100, then the Void pack's odds without the King seeds) |
| `rarepacks @name` | 5 TEST packs that reveal Legendary, Mythic, Secret, Cosmic and King (R154: each a random seed of that rarity from any biome, in that biome's pack; `rarepacks mythic` is not always Elderbloom any more) |
| `rarepacks mech @name` / `rarepacks king @name` / `rarepacks verity @name` | TEST packs: the six Mech designs, one King, or a Verity Pack that reveals the Verity seed. R155: add `gold` or `diamond` (`rarepacks mech gold`) for that coat (a bought Mech pack rolls its own: Gold 4.5% / Diamond 0.5%) |
| `rarepacks roster @name` | R148 four TEST packs that reveal Fire Pepper (Mythic), Moon Melon (Legendary), Aloe (Rare) and Sand Fruit (Legendary) |
| `seeds snow @name`, `seeds all @name`, `seeds verity @name` | Every seed of a biome, every seed in the game, or the Verity seed |
| `give big diamond apple seed to @name` | One seed by plant name. `big`/`giant` and `gold`/`diamond` are optional |
| `take apple seeds from @name` | Remove seeds |
| `catalog storm`, `odds storm mythic 1`, `odds event`, `odds verity` | Seed list and real odds (`odds verity` = the Verity Pack). R154: no seed over 80%; luck up to 50M (R155 halved the boots: Thunder Boots x25M, x50M with the 4 Leaf Clover's x2; it was 100M); `odds event clover` / `odds verity clover` = with the clover's x2 (without the word: the target's own clover). R155: add `lucky` at the end (`odds storm mythic 50000000 lucky`, `odds event clover lucky`) for the pack pity's lucky 10th: x1.5 luck and the x1.5 cap (up to x75M); the last line is the pity rule |
| `indexinfo storm @name` / `claimindex storm @name` | Index rewards (`verity` = the R147 VERITY tab) |
| `pity @name`, `pity set 9 9 @name` | R155 pack pity: the target's NORMAL and EVENT counts (event = Void, Verity and Mech packs) and which next pack is lucky; `pity set <normal> <event>` sets them (0–9, saved; 9 = the next pack of that group is the lucky one: x1.5 luck). TEST packs never count. `pity 30` (a number alone) is still the track reset preview below |
| `mystery @name`, `mystery ready`, `mystery next`, `mystery reset` | R147 base mystery pack: show the state (and packs owed to a full Bag); unlock in 3 s; pretend a new day; start over (owed packs are kept) |

## Garden
| Command | What it does |
|---|---|
| `plants all @name` | Mature examples of every crop |
| `growall @name`, `growth 50 @name`, `growtime 30 @name`, `regrow @name` | Growth states |
| `harvestall @name`, `sellall @name` | Pick and sell |
| `fruithour ember pumpkin 3` (server) | Make a fruit the Fruit of the Hour for 10 minutes, bonus 1.5–3 (default 3). `fruithour` alone picks one at random; `fruithour off` goes back to the clock |
| `clear inventory @name` | Also `seeds`, `packs`, `plants`, `harvests`, `all` |
| `clearinventory all`, `cleargarden all` (server) | Clear everyone |

## Track, keepers and The Darkened
| Command | What it does |
|---|---|
| `refreshpacks` (server) | Refresh the track now |
| `refreshcycle 30` (server) | Refresh into reset 30. Legendary every 5 resets, Mythic every 10, The Darkened every 3 |
| `pity 30`, `spawnodds`, `routes` | Look at guarantees, spawn chances and keeper speeds (R155: `pity` with no number is the player's pack pity, see Packs and seeds) |
| `daily`, `daily next`, `daily done`, `daily week`, `daily reset` (`@name`) | R140 login week + daily quests: show the state; pretend a new day (login claim back, quests from 0); finish today's quests; make the next claim day 7 (R153: a Void pack, gift-locked unless `DailyRewards.LockDay7Void` is false); start over. R153: every pack they make claimable is a TEST pack |
| `plantnotify`, `plantnotify send`, `plantnotify reset` | R151 offline "your plant is ready" notifier: what is missing from the setup (MessageId, HTTP, secret), the shared queue, your entry and cooldown, this server's counts; send you a notification now (Roblox delivers 1 a day, only if you opted in and are 13+); clear your cooldown |
| `packluck`, `packluck 29 @name` | R137 hidden big-pack luck (players never see it): packs since a 5x+ / 10x+ and the track's refreshes; a number sets the 5x count (29 = next earned pack is 5x+) |
| `fling storm @name` | Fling them like that biome's keeper (forest … storm, or `darkened`). Tests the air time; nothing drops |
| `ragdoll 4 @name` | Knock them down for 0.5–10 s |
| `weather thunder` (server) | `clear`, `cloudy`, `rain`, `thunder` or `blizzard`. Add `all` (e.g. `weather rain all`) to make every exposed pack, plant and fruit change: tests the R127 highlights |
| `weather cloudy` / `weather clear` (server) | R151 default sky: hold it Cloudy (dim, cool light, thicker grey clouds, warm lamps and lanterns) or Clear for 5 minutes (it arrives over 6 s; any event weather is cleared first), then the cycle goes on |
| `weather cycle` (server) | Shows the default Clear / Cloudy cycle: the sky now and its fade, when it switches, whether a test holds it, and the event weather |
| `weather cycle skip` (server) | Ends the current phase now: the other sky starts with its real 20 - 40 s fade (to watch the fade), then the cycle goes on from there |
| `weather cycle auto` (server) | Releases any hold or skip: the real schedule again |
| `event spawn` / `event clear` (server) | Spawn or remove The Darkened and its 2 Void Packs |
| `event status` (server) | Packs left, unstolen refreshes (the packs reroll after 3) |
| `event go @name` | Teleport next to a Void Pack |
| `eventpack 7.5 diamond` (server) | Change the waiting Void Pack |
| `keepersmack` (server) | Preview The Darkened's hit (hits nobody) |
| `notice event @name` | Preview a notice (`event`, `legendary`, `mythic`, `giant`) |

## Hub displays (R151)
The two giant displays in the hub's back corners: **BEST PULL** (the +X corner, below Base_4) and **BIGGEST FRUIT TODAY** (the -X corner, below Base_3). Each is the market's Fruit of the Hour pedestal built 3.2 times bigger, the winning seed / fruit turning over it (its light and sparkles on it) under one big label (title, winner, seed or weight, rarity and chance or the fruit of the day, a countdown), and the champion's avatar, 25 studs tall and dancing, standing beside it. They count real pack openings and hand-picked fruit; `rarepacks` TEST packs, any pack an owner command made (`TestGrant`), anything an owner command just gave that player (this server session) and the test commands below are never counted.
- **BEST PULL is this server only and lasts 10 minutes (R153).** It only counts pulls made in THIS server, nothing about it is stored or sent (no MemoryStore, no save, no MessagingService), and the board empties at every wall-clock :00, :10, :20 ... (`os.time()` / 600, so a countdown is the same on every server): the champion's avatar is replaced by the black silhouette, the item by the mystery seed, the label goes back to "Nobody yet", and the next pull in the new window is the new record, however small. The label reads **BEST PULL** over the winner, the seed, the rarity and chance, and **"new board in 7:42"** (minutes and seconds to the next mark; the display counts it once a second when you are near). A leftover best pull saved by an older version is simply ignored.
- **BIGGEST FRUIT TODAY is as it was:** shared across all servers (MemoryStore), one fruit type a day, resets at midnight UTC ("New fruit in 5h 12m").
When someone takes a top spot in this server the news is ONE amber chat line through the pull announcer (see Pull announcements below: after the puller's own reveal, in the scope the announcement rules give; the hub has no banner of its own any more) and the display's chime plays with it.
| Command | What it does |
|---|---|
| `bestpull FirePepperSeed @name` | A test BEST PULL for that player: a seed id or a plant name (`fire pepper`), ranked at its odds in its biome's Pack03 (the label says the seed's one fixed 1/N, as everywhere: R153). **This server only, and only until the next 10-minute mark** (the board empties then, the test with it). R153: there is no `share` for it any more (BEST PULL is never shared; `bestpull ... share` is refused). The record line ("🏆 Name took BEST PULL!") and the chime go to that player ALONE: a test never talks to the server or to other servers (`announce record` shows the line to everyone, on purpose) |
| `bigfruit 12.4 @name` | A test BIGGEST FRUIT TODAY: a fruit of **today's** type weighing that many kg. `gold` / `diamond` add a coat, `share` writes the shared board. This server only unless shared; its line and chime are private to that player like `bestpull`'s |
| `hubdisplays` (server) | Print the state: the day, the fruit of the day and its countdown ("new fruit in ..."), the champions and where they came from (`Remote` = another server or the store, `Local` = this server, `Test` = injected; R153: a best pull is only ever `Local` or `Test`), BEST PULL's own clock ("this server only \| new board in 7:42"), the fruit's shared board health (failures, last error, retry time) and the part counts; R153: per display its avatar's `AvatarMode` (`dance` = every client dances it, `pose` = posed, `static` = stand-in / silhouette) and dance id, what YOUR screen did (`dance: track loaded, Length 8.43 s, playing` / `loading: try 2 of 4` / `pose: the dance did not load (4 tries ...)`) and how many other screens report what |
| `hubdisplays reset` (server) | Empty both boards on this server (BEST PULL is this server's own, so that is all there is to it) and delete today's shared fruit document. Other servers keep their own best fruit and write it back at their next step: reset them too, or restart them |
| `hubdisplays day +1` (server) | Preview tomorrow's fruit (`+2`, `+7`, `-1` too) on this server only; nothing is read or written to the shared board while previewing. `hubdisplays day 0` comes back. BEST PULL does not change (its clock is the real one) |

## Shovel holes
| Command | What it does |
|---|---|
| `holes` (server) | Holes on the track per player |
| `holes clear` (server) | Remove all holes |
| `dig @name` | Dig at their feet without the wait. They must hold the shovel on the track; the 4-hole limit still applies |

## Treadmill bonus rolls
| Command | What it does |
|---|---|
| `bonus @name` | Ready rolls (0–2), saved progress, their roll pool |
| `bonus ready 2 @name` | Make rolls ready; the button appears |
| `bonus progress 5:50 @name` | Saved treadmill time (max 6:00). 5:50 means a roll after 10 more seconds on the treadmill |
| `bonus roll @name` | Use a ready roll for them now, with no animation |

## R151 reveals, pack shapes, hub trees
| Command | What it does |
|---|---|
| `rarepull king @name` (`cosmic`, `secret`, `common`..`mythic`) | Play a pull reveal with a demo seed; nothing is granted |
| `raresound KingFanfare @name` | Play one reveal sound slot alone (RarePullSounds), to audition an id |
| `packshape` / `packshape 3` / `packshape off` / `packshape auto` | Chip-bag shapes: status / every NEW pack rolls shape 3 / every pack shown in the default shape / normal random rolls |
| `hubtrees` (server) | How each studded tree model loaded (by id or placed by hand), scripts and fruit removed, part counts, which device tiers use it |
| `trampoline` (server) | R153: which look the three nook trampolines (the two garden nooks and the back lane's) have: **the asset** (Creator Store 12088629887, loaded by `InsertService:LoadAsset`), **the hand-placed template** (a model you dropped into `ReplicatedStorage.HubTrampolineTemplates153`, preferred) or **the built trampoline** (the fallback), with the parts per trampoline, the scripts and other non-geometry removed, whether a mat for the squash was found, and why each route that was not used failed (the real error). The gameplay is the same for all three looks |
| `trampoline reload` (server) | Forget the loaded look and try again now (template first, then the asset); run `trampoline` a few seconds later to read the result |

**"User is not authorized to access Asset"** (the trampoline asset, like the R152 tree assets, is not owned by the game's owner, so `InsertService` refuses it): open the asset's Creator Store page logged in as the game's owner, press **Get Model**, then in Studio open the Toolbox → Inventory → Models, insert it, and drop that model into `ReplicatedStorage.HubTrampolineTemplates153` (create the Folder if it is not there; any Model or part inside is taken). The template is preferred over the asset, so the server stops trying the asset. Everything is stripped of scripts, sounds, prompts, welds and humanoids before it is used, and it is scaled so its farthest point lies on the nook's trampoline circle (12.6 studs in a garden nook, 9.6 in the lane's): a round look (cylinders, balls, round meshes) is measured by its circle, so its rim reaches the edge; a look that is not round is fitted inside the circle by its corners. Publish, restart the server (or `/test trampoline reload`). Also works with "Allow Loading Third Party Assets" switched on: `AssetService:LoadAssetAsync` is the second route.

## Pull announcements (R151, chat only)
Pull announcements are chat lines only: no banner, no sound, no picture. In this server a Legendary or better pull is a line in the pull's rarity colour (`🌟 Name pulled a MYTHIC Fire Pepper! (1/800)`); a Secret or better pull is also sent to the other servers, where it is a gold line (`🌐 Name pulled a SECRET Void Seed (1/1,000)!`). A record is an amber line (`🏆 Name took BEST PULL!`). The line comes after the PULLER's reveal has shown the seed, for everybody (the puller included): about 2.2 s after the open for a Legendary, 2.4 s Mythic, 4.7 s Secret, 5.8 s Cosmic, 6.7 s King (the climax / seed landing of their cinematic plus half a second, read from the same tables the client plays; a skipped reveal still gets the line at that time; a puller who leaves releases it at once). A Secret or better pull reaches the other servers at that same moment, never earlier. **Hub records** (a new BEST PULL / BIGGEST FRUIT TODAY) are announced the same way and are the hub's ONLY message (its old notice is gone): R153: a BEST PULL of a Legendary or better seed (Secret, Cosmic and King too) is told in THIS server only, never to another one (the board is this server's own and starts again every 10 minutes, so the first Legendary or better pull of a window is announced again), anything lower only changes the display; BIGGEST FRUIT stays in this server; a record from a pack open follows the pull line by 0.4 s. Owner test packs (`TestGrant`, `/test rarepacks`) and the owner's `bestpull` / `bigfruit` tests never announce to other players, and nothing is announced while `hubdisplays day +1` previews another day.

**Packs an owner command made never announce** (`TestGrant` on the pack record): `pack`, `packset`, `void` / `eclipse`, `verity`, `rarepacks` (all kinds), a Void pack from `event spawn`, and the packs that a `mystery ready` / `mystery next`, `daily next` / `done` / `week` / `reset` (the login pack AND the quest packs: each has its own arm, so one claim can't use up the other's; a test day lasts until UTC midnight, and the target counts as owner-granted for the hub boards for the session) or `bonus ready` / `progress` / `roll` command makes claimable. A Void pack turned into a Verity pack by the NPC stays a test pack. Real Robux Mech / Verity purchases, packs from the track, the mystery pedestal, the daily login and quest packs and treadmill rolls (when no owner command was used) still announce.

**Owner-given boots and seeds are TEST too (R152).** `boots 1-5` (when it unlocks a pair the player did not own) saves a `TestBoosts` mark with the profile: while the luck in use comes from such boots (no bought pair reaches it), every pack that player opens is a TEST pull: never announced, never counted by the hub boards, and the seed it makes is a TEST seed. `seed` / `seeds` / `give ... seed` / `plant` mark the seed (or plant), and the plant and fruit grown from it keep the mark for good (no longer just for the session): its fruit never counts for BIGGEST FRUIT. Bought boots and normal seeds are unaffected.

| Command | What it does |
|---|---|
| `announce firepepper @name` | The chat line for everyone in this server, as if `@name` had just pulled that seed. Any rarity works (a real pull needs Legendary or above). Seed = an id (`FirePepperSeed`) or the plant name. This command IS an announcement on purpose (it is how you look at the lines) |
| `announce global firepepper @name` | Publish it to the OTHER servers (they show the gold 🌐 chat line). It goes out within 5 s. This server is the origin and shows nothing |
| `announce global firepepper here @name` | Same, and this server also shows the other-server line (the only way to see it with a single server, e.g. in Studio) |
| `announce record @name` | The record chat line ("took BEST PULL!") for the hub displays. `announce record fruit` = BIGGEST FRUIT TODAY; add a seed (`announce record bestpull moonmelon`) to name it on the line |

## Gifts
| Command | What it does |
|---|---|
| `gifts @name` | Gifts they sent that are still finishing |
| `gifts recover @name` | Finish stuck gifts now (normally automatic within a minute) |

## Free Void Pack pedestal
| Command | What it does |
|---|---|
| `voidgift` (server) | R152: the giveaway pedestal in the middle of the plaza: how many of the 500 are claimed and left, whether YOU have claimed (profile flag, the shared list, your state), which store this server uses (`DataStore` live, the Studio test store, or the in-memory counter when Studio has no API access), messages sent / received, and the pedestal (state, prompt). No @name |
| `voidgift reset me` (server, **Studio only**) | Clears YOUR claim and your profile flag (the shared list loses you, the count goes down by one) so you can claim again. The pack you already got stays in your Bag (`clear packs` removes it). A live server refuses: it never changes the shared count |
| `voidgift left 3` (server, **Studio only**) | Sets how many the pedestal shows as left (0 = ALL CLAIMED, 487 = a fresh start). Players already in the list keep their places, so the number cannot go above 500 minus them. Studio only; a live server refuses |
| `playtime @name` | R157: how long that player has played in total (saved with the profile as `Premium.PlaySeconds157`, counted up to 3 hours) and how long is left until the free Void Pack can be claimed (20 minutes). `voidgift` shows yours too |
| `playtime @name 12` (**Studio only** to set) | Sets that player's play time to 12 minutes (0 to 180), saved the usual way; `playtime 12 @name` works too. Use `playtime @name 19` to test the 20-minute rule: the pack opens a minute later. A live server refuses |

## Keepers (R152)
| Command | What it does |
|---|---|
| `keepermodels` (server) | R152: the new keeper models the game builds at server start: bake status (needs Game Settings → Security → "Allow Mesh / Image APIs"), which model each keeper shows (`R152` or `Legacy`), parts and triangles |
| `keepermodels off` / `keepermodels auto` (server) | `off` = every keeper goes back to today's (R151) model, each at its next idle moment; `auto` = the new models again |

## Hotbar (R153)
| Command | What it does |
|---|---|
| `hotbar` | R153: the hotbar log on / off for you: every press (PC, phone, gamepad), what it did (equip, unequip, moved, stowed, ignored) and anything the server moved back, with times, in a copyable box top-left and as `[Hotbar]` lines in F9. The last 60 lines are kept even while it is off. The reply also prints the server's view: what is in your hand, the pack it holds, recent late holds or refusals and why. Paste it to me if a press ever goes missing R155: also prints the items held (of 200) and every discard. |

## Verity's voice
| Command | What it does |
|---|---|
| `verityvoice 2.1`, `verityvoice 2.1 0.3` (server) | R149: find where "Hello, my name is Verity" ends by ear. `verityvoice <end> [start]` (seconds into the audio) sets the cut for this server and plays it for you at once, from anywhere (no @name). Run it again with a new end until it stops right after "Verity". `verityvoice` alone plays it again and prints the numbers in force; `verityvoice reset` goes back to the config. Nothing is saved: write the final numbers into `ReplicatedStorage.VerityConfig` (`GreetingStart`, `GreetingEnd`) and publish |

## Checks
`economy`, `mechshop` (R155: also the Mech coat line and the event end), `voidcheck`, `collisions` (server), `perf`, `effects low|normal|off`.

## Old shortcuts that still work
English phrases like `give me money`, `go home`, `grow my garden` and `clear my inventory` still work. They aren't
listed separately any more because each one is the same as a command above.

## Removed
- `balance84`: its numbers were out of date. Use `training`.
- Duplicate help rows: `eclipse` (same as `void`) and the three `rarepacks` rows. The `eclipse` command itself still works.

## Studio-only tools (Command Bar)
- **Dig sound cutter:** press Play, then run `require(game.ReplicatedStorage.DigSoundAnalyzer).Run()`.
  It finds the separate dig sounds in 93793180254708. Details are in `docs/proposals/holes_R122/DIG_SOUND.md`.
- **Find an asset:** paste `installers/find_asset.lua` into the Command Bar. It shows where an asset id is used
  (e.g. the animation 114302219876492).
- **Undo a release:** `require(game.ServerStorage.ChestChase_R123_Backup.Installer)("undo")`.

## Test plan by feature (two accounts help: a main and an alt)
1. **Treadmill bonus:**
   - `bonus progress 5:50 @me`, then get on the treadmill. The bar counts down and the button appears (a roll every 6 min).
   - Roll and check the strip, the clicks, the odds line (Secret 0.1% = Void Pack) and the border light-up on Legendary / Mythic / Secret.
   - `bonus ready 2 @me` to see the stacked badge.
   - Leave and rejoin: the rolls are gone, but the saved progress stays.
   - `treadmill 1` versus `treadmill 7`: the pool changes from Forest only to all biomes.
   - `bonus ready 2 @me`, roll, and check CLOSE / ROLL AGAIN sit centred under the result text.
2. **The Darkened:**
   - `event spawn`, then `event go @me`. Steal one Void Pack, then the other; it leaves after the second.
   - `refreshpacks` three times without stealing: the packs reroll (`event status`).
   - Check the arrival sound, the lights-out and the "ARRIVES IN" timer on the bottom card.
3. **Holes:**
   - The alt steals a pack on the track (holes only catch players carrying a pack). Dig a hole in their path, or `dig @you` right where they will run; they fall for 4 s and the pack drops.
   - Dig 4 holes, then try a 5th (refused). Cover one with the shovel, or wait 3 min for it to expire.
   - R124: the tip fades when the shovel comes out on the track; clicking again within 3 s shows just the time ("2s").
4. **Keepers:**
   - `fling forest @me` … `fling storm @me`: each tier goes higher and you land inside the walls.
   - `keepersmack`, and steal a pack in each biome to see each keeper's own hit animation.
   - R124: the Forest hammer and Jungle slam play the ground-slam sound on the impact frame; The Darkened's catch plays its own sound with a purple impact.
5. **Gifts:** hold fruit, a seed and a pack and click the alt (R130: they light up, then a popup asks "Are you sure you want to give … to …?"; press Give). The alt gets a notice naming you and the item. `gifts @me` should show 0 within a minute.
6. **Rarity borders:**
   - `rarepacks @me` and `seeds all @me`, then open the inventory: every rarity has its own border and there are no emblems.
7. **Shop:** prices read "49 Robux", there are no gift buttons and no 2x speed banner.
8. **Sounds:**
   - Planting.
   - Keeper hits.
   - The refresh countdown beeps line up with the numbers.
   - The chase alarm.
   - Pack opening.
9. **R124 extras:**
   - Bushes: walk into a Forest or Jungle bush; it turns see-through for you, and your alt sees a solid bush and no name.
   - Biome title: run from Forest into Jungle; the name fades in, then fades away.
   - Refresh wall: `refreshpacks`; the moon and count are centred and "REFRESHING" has looping dots.
   - King border: `seeds all @me`; the King cards have ruby corner gems.
10. **R125:**
   - Stealing needs a 1 s hold of E (a dropped pack 0.5 s).
   - Biome titles show their logo in the medallion and fade away.
   - Rare-and-up plants outside Forest grow 15 min to 4 h and are worth more per harvest.
   - Tutorial: the TRACK ring in step 1, plus BASE / TRACK tips.
   - Esc menu: the "plants grow offline" card.
   - Shop: the Featured star logo.
11. **R126:**
   - `bonus ready 2 @me`, roll, and check the bag: pack sizes vary (mostly 1x).
   - Buy Mech packs with Gems: each pack has its own size, and a bigger pack opens a bigger seed.
12. **R127:**
   - `weather blizzard all` near your garden: packs glow, your plant gets a rainbow outline + label, the message names it.
   - `event spawn`: the lights flicker out, far things go black, a glow around you, lights back after ~10 s.
   - Hotbar and Bag are bigger; `spawnodds` shows Legendary 3% / Mythic 1%.
13. **R128:**
   - `event spawn`: lights-out is about 7 s now.
   - Walk and run through Forest / Jungle: pollen and fireflies stay put instead of sliding with the camera.
   - Hold a pack or seed with a ring/orbit (`weather rain all`) and run: the effect stays on the item.
   - Steal a pack and let the keeper catch up: it lands its swing instead of repeating it.
14. **R129:**
   - Device emulator, landscape phone: balances bottom-left, boosts/The Darkened/timers bottom-right above jump, MENU left, BASE/TRACK top, hotbar centred.
   - `weather rain` in the base: turn the camera, the rain keeps falling and the sky darkens; on the track there is no weather.
15. **R130:**
   - Hold a fruit, seed or pack and point at the alt: they light up gold when close enough. Click: the popup names the item and the alt. Cancel does nothing; Give sends it and the alt sees "🎁 <you> gave you <item>!".
   - Click the alt from far away: "Get closer to <name> to give."
   - `refreshpacks`: the sky goes dark during the refresh (black sky, or a midnight sky with dark air on clients without the image API), and comes back after. With `weather rain` on, no grey cloud layer appears during the refresh.
   - Keepers still stand at home and chase normally (their idle upkeep is lighter now).
16. **R131:**
   - Gifts in Studio (Clients and Servers, 2 players): Player1 gives to Player2; Player2 gets "🎁 Player1 gave you …!" with a chime. With Studio API access off, Player1 is told to turn it on.
   - Look across the base: the garden name bubbles are smaller from far away and don't cover gardens.
   - `weather rain`: mutations are rare (0.2% per minute); `weather rain all` still forces them.
17. **R132:**
   - Go to the market: string lights, warm lamps, flower boxes, produce stands, and the game's own fruit and plants on the counter, stands and planters. No chalkboard.
   - The pedestal to the right of the arrival spot: the Fruit of the Hour turns slowly over it with its name, "SELLS ×2.3" and the time left.
   - `fruithour apple 3`, then harvest/hold an apple and open the sell menu: the apple shows "🌟 Fruit of the Hour ×3.0" and sells for 3×. Everyone gets the gold notice. `fruithour off` puts the hour's fruit back.
   - Go home: a 🏠 floats over the middle of your base. Your alt sees it over their own base only.
18. **R133:**
   - Market: fruit sits on the crates and steps (no floating), all 4 shelves are full of mixed packs, soil in the planters and flower boxes, a wall behind the front sign, no MARKET text from inside, lamps hang from a ceiling beam, pots and a barrel at the back.
   - Fruit of the Hour: big fruit, small two-line label above it. `fruithour apple 3` to switch it.
   - Tutorial: Settings > replay the tutorial: casual lines with emojis.
19. **R134:**
   - `seeds all`, open the Bag: every seed looks different, no side wings. Hold Diamond Vine, Prism Pepper, Ash Tomato, Iceberry, Venom Vine, Prism Monarch.
   - Hold a Legendary+ seed: flames/crystals/glows animate; `give prism monarch seed`: crown and golden rays.
20. **R135:**
   - Market: counter crates hold prickly pears, pineapples and glowing lanterns; stands hold watermelons, apples, grape bunches / pumpkins, tomatoes, snow melons. No berries, nothing hovering; inside shelves full of mixed packs.
21. **R136:**
   - `rarepacks @you`, open the Legendary and Mythic ones: charge-up with sparkles swirling in, whoosh + chimes, then a light beam, ring(s) and sparkle burst with a hit. Mythic is bigger and pink (two rings, a spiral up the beam). A second player nearby sees it and hears a sparkle sound.
   - Index: every chance reads `1/…`. Market: three lantern fruits glow on the ceiling cords.
22. **R137:**
   - `packluck 29`, steal and bank a pack: it comes out 5x+. `packluck` shows the counters (nothing is shown to players).
   - `odds forest common`: Legendary 1/60, Mythic 1/400; Desert Mythic 1/600.
   - Leaderboard: ▲ / ▼, mouse wheel while pointing at it (no camera zoom), drag. Rank 100 reachable.
   - Graphics Low: hotbar, Bag and the bonus reel still show real 3D pictures (no flat icons).
   - Index: rarity + 1/N chips, SEED/GROWN chips, CLAIM pill, Common → King order, ringed tab, FOUND total.
23. **R138:**
   - Settings > replay the tutorial: picture welcome, icon + 2-3 word cards with key chips, step icon row, clicking indicator while opening (pips fill), 3 picture slides, YOU'RE READY! + confetti.
   - Finishing it (first time on the account) gives a free Forest pack with 2x rates (R139: kept secret, see 24).
   - Open packs: Common pop, Uncommon pop + note, Rare sparkle + two notes, small ring/sparkles; `rarepacks @you`: Secret/Cosmic/King louder.
   - Index: a waiting reward puts a count on INDEX, ! on MENU and a dot on its biome tab; claiming plays ka-ching / gem sound; no gray box above names.
24. **R139:**
   - Steal and bank a pack: its hotbar slot (and Bag card) gets a spinning rainbow border, ~4 s, then it fades. Packs you joined with stay plain, also after a reset.
   - Hotbar full: a new pack's Bag card glows when you open the Bag.
   - Free tutorial pack: the finish card says 🎁 FREE PACK!, the notice FREE Forest Seed Pack; its tooltip matches a normal Forest pack (no luck row). Replay: no second one. Gift it: the alt gets a normal Forest pack.
25. **R140:**
   - 🎁 DAILY and 👥 INVITE sit right of TRACK in the top bar (phone too). DAILY's red number = login reward + finished quests.
   - After the tutorial the week opens by itself: claim day 1 (Gems float in). `daily next` → claim day 2; `daily week` → claim day 7 = a Void pack in the Bag (R153; it was a Mech pack).
   - Steal and bank 3 packs: ✅ QUEST DONE notice, CLAIM in QUESTS gives one random pack (R153; it was Gems); claim all three and the ALL DONE row gives 💎2 once. `daily done` finishes all three.
   - Live server with a friend: both get a "Friend boost" notice, INVITE shows +10% / +20%, and treadmill training gives you that much more speed per second (R149: your running speed itself is not boosted; bought speed and bonus rolls are not either). `training` shows the "friends x1.2" part. INVITE opens Roblox's invite screen.
   - "Your plant is ready" needs the one-time setup in `docs/releases/R140.md` (notification string id on SocialService.MessageId, API key secret `PlantReadyKey`, HTTP on).
26. **R151 pull announcements (chat only):**
   - `announce moonmelon @me`: one coloured line appears in chat, "🌟 Name pulled a LEGENDARY Moon Melon! (1/...)" (no banner, no sound). Try `announce firepepper`, a Secret, a Cosmic and `verity`: the line is always in the rarity's colour with the rarity word in bold. A Common one (`announce sunflower`) still shows because it is a test. A name or seed with special characters (`<`, `&`) is shown as plain text, never as formatting.
   - A real pack open: a Legendary or better seed writes its line only AFTER the puller's own reveal has shown the seed (never before: about 2.2 s for a Legendary, 4.7 s Secret, 6.7 s King; skip the scene and it still comes at that time), also for the other players in the server, once on each screen. Leave right after opening and the line comes at once. If the pull takes the BEST PULL the amber record line follows 0.4 s later and there is no hub banner (R153: the record line stays in this server, a Secret's included; only the 🌐 pull line of a Secret or better goes to the other servers). `rarepacks @me`, `pack`, `packset`, `void`, `verity` TEST packs never announce, and neither do gifted / granted seeds; open one of each to check. `mystery ready @me` then take the pack, `daily week @me` then claim day 7, `bonus roll @me`: also silent. A normal mystery / login / treadmill pack afterwards announces again.
   - Two live servers (or Studio + a live server): `announce global obsidianmaw` (any Secret+ seed) from one: the other shows a gold 🌐 chat line; the sender's own server does not. SETTINGS has "Announcements from other servers": switch it off and the next 🌐 line is not shown to you (pulls in your own server still are). It is saved with your settings.
   - `announce record` shows the record line to everyone in this server at once (it never goes to other servers). The hub displays call `require(...PullAnnouncer).Announce({Kind='Record', Player=player, Record='BestPull', SeedId=..., AfterReveal=true})`; `bestpull` / `bigfruit` tests show their line to their target only.
   - Tunables (Studio, attributes on `PullAnnounceRules`): `RevealMargin` (0.5 s after the seed is shown) and `RecordLag` (0.4 s) join the ones below.
   - Tunables (Studio): set an attribute on `ReplicatedStorage.PullAnnounceRules`: `InServerMinRarity` (default Legendary), `GlobalMinRarity` (Secret), `ChatBurst` / `ChatWindow` (8 lines per 10 s per player), `PublishGapSeconds` (5), `ReceiveMaxPerMinute` (10).
27. **R151 Cloudy sky (the default weather alternates Clear and Cloudy):**
   - Stand in the base. Wait for the cycle (about 8 minutes Clear, then about 6 minutes Cloudy) or type `weather cycle skip`: over 20 - 40 seconds the light dims, turns cooler and a little hazier, the clouds thicken and grey, the sun rays fade. No rain, no particles, no sound. Keepers, packs, the keyboard letters and the UI stay easy to read.
   - As it dims the lamps and lanterns warm up and glow: every lamp head and wall lantern in the festival square turns amber, the lamps along the side streets (and the avenue and the market square on a desktop) cast a soft warm light on the ground, and the market's lanterns get a bit stronger and warmer. Phones light 4 lamps (the street ones), FastMode none (the heads still glow). `weather cycle skip` again fades it all back to Clear: the lights go off and every colour returns exactly.
   - `weather cloudy` / `weather clear` hold the sky for 5 minutes (it arrives in 6 seconds; any rain / thunder / blizzard is cleared first). `weather cycle` prints the sky now, its fade, when it switches, whether a test holds it and the event weather. `weather cycle auto` goes back to the real schedule.
   - `weather rain` (or `thunder`, `blizzard`) while it is cloudy: the storm looks exactly as before (it takes priority, Cloudy is not added); rain, thunder and (R154) the blizzard, which also dims the world, light all 8 lamps. When it ends the sky goes back to wherever the cycle is.
   - Walk onto the track while it is cloudy: each biome keeps its own mood (Cloudy dims the base only; the owner can raise `Track` in `ReplicatedStorage.WeatherCycle151.Config` to dim the track too).
   - `event spawn` while it is cloudy: the lights flicker out as before and come back to the Cloudy look. Open a Secret / Cosmic / King pull (`rarepacks @me`) while it is cloudy: the story scene is lit as it always was.
   - Cloudy is not a mutation weather: it does not change packs, plants or fruit (`weather rain` is still the only 0.2%-per-minute roll), and the weather HUD only reads "Cloudy skies" in its accessibility label.
   - Tunables (Studio): `ReplicatedStorage.WeatherCycle151` has `Config` (phase lengths, spread, fade range, test hold, `Track`), `Lamps` (when lamps start to glow, real lights per device tier, warm colour) and `Market`; the look itself is `BiomeMood.CloudyLook`.
