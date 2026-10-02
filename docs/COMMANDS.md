# Test commands and tools (R131)

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
| `boots 5 @name`, `trail 6 @name`, `fence 7 @name` | Unlock and equip upgrades |
| `bundle SpeedSmall @name` | Give a shop bundle with no purchase |
| `training @name` | Treadmill gain per second and physical speed |
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
| `rarepacks @name` | 5 TEST packs that reveal Legendary, Mythic, Secret, Cosmic and King |
| `rarepacks mech @name` / `rarepacks king @name` | TEST packs: the six Mech designs, or one King |
| `seeds snow @name`, `seeds all @name` | Every seed of a biome, or every seed in the game |
| `give big diamond apple seed to @name` | One seed by plant name. `big`/`giant` and `gold`/`diamond` are optional |
| `take apple seeds from @name` | Remove seeds |
| `catalog storm`, `odds storm mythic 1`, `odds event` | Seed list and real odds |
| `indexinfo storm @name` / `claimindex storm @name` | Index rewards |

## Garden
| Command | What it does |
|---|---|
| `plants all @name` | Mature examples of every crop |
| `growall @name`, `growth 50 @name`, `growtime 30 @name`, `regrow @name` | Growth states |
| `harvestall @name`, `sellall @name` | Pick and sell |
| `clear inventory @name` | Also `seeds`, `packs`, `plants`, `harvests`, `all` |
| `clearinventory all`, `cleargarden all` (server) | Clear everyone |

## Track, keepers and The Darkened
| Command | What it does |
|---|---|
| `refreshpacks` (server) | Refresh the track now |
| `refreshcycle 30` (server) | Refresh into reset 30. Legendary every 5 resets, Mythic every 10, The Darkened every 3 |
| `pity 30`, `spawnodds`, `routes` | Look at guarantees, spawn chances and keeper speeds |
| `fling storm @name` | Fling them like that biome's keeper (forest … storm, or `darkened`). Tests the air time; nothing drops |
| `ragdoll 4 @name` | Knock them down for 0.5–10 s |
| `weather thunder` (server) | `clear`, `rain`, `thunder` or `blizzard`. Add `all` (e.g. `weather rain all`) to make every exposed pack, plant and fruit change: tests the R127 highlights |
| `event spawn` / `event clear` (server) | Spawn or remove The Darkened and its 2 Void Packs |
| `event status` (server) | Packs left, unstolen refreshes (the packs reroll after 3) |
| `event go @name` | Teleport next to a Void Pack |
| `eventpack 7.5 diamond` (server) | Change the waiting Void Pack |
| `keepersmack` (server) | Preview The Darkened's hit (hits nobody) |
| `notice event @name` | Preview a notice (`event`, `legendary`, `mythic`, `giant`) |

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

## Gifts
| Command | What it does |
|---|---|
| `gifts @name` | Gifts they sent that are still finishing |
| `gifts recover @name` | Finish stuck gifts now (normally automatic within a minute) |

## Checks
`economy`, `mechshop`, `voidcheck`, `collisions` (server), `perf`, `effects low|normal|off`.

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
