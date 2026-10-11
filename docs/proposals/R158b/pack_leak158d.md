# R158d: nothing of the seed shows before the pack opens

Owner: "the mech pack seeds, and also check for other seeds that have similar issues: their effects are already there even before the pack opens. This ruins the surprise of the pack opening."
Built on R158c. Client only: the server, `Config.lua`, the pack art and the reveal's timing are not touched.

## What the screenshots show

The cyan and yellow dashes round the closed Mech pack are the **Mech seed's scanner**: ten little teeth that circle the seed and two bars that sweep up and down it (every third piece is yellow, the rest cyan; `ItemVisualEffects`).
That scanner belongs to the seed that is hidden inside the pack. It was drawn from the moment of the fifth click, long before the seed bursts out. In the space picture (a Cosmic pull) it floats under the pack on the story stage; in the other it floats round the pack in the world.

## Why it happened

A seed's scanner and its weather effect are not part of the seed model. A script (`ItemCosmetics`) draws them **next to** any part carrying the `GardenItemFX` tag, whether the seed can be seen or not.
The opening hides the seed by making its parts see-through, so the pieces stayed. Two places hold a hidden seed:

1. the **world reveal** (`SeedPackClient`): the reward seed sits in the pack from the fifth click until the burst;
2. the **story scenes** (`RarePullScenes`, Secret / Cosmic / King): the hero seed sits hidden in the pack on the stage until the hit.

The stage seed had a second problem: its own sparkles (a small rarity-coloured sparkle, every seed has one) were never switched off while it was hidden. The world reveal already switched those off.

## What changed (4 files in `src`, 53 lines added, 2 lines rewritten in `ItemCosmetics`)

| File | Change |
| --- | --- |
| `ItemEffectAnchor.lua` | `Hold(model)` marks the seed so nothing is drawn for it (and, for the stage seed, switches off every effect built into it: sparkles, lights, outlines, beams, trails). `Release(model)` gives it all back. |
| `ItemCosmetics.client.lua` | Draws nothing for a held part, and looks again the frame it is released (so the scanner is there on the frame the seed shows, not up to .3 s later). |
| `SeedPackClient.client.lua` | World reveal: the reward seed is held when it is made, released on the frame it shows (the burst). One line each. |
| `RarePullScenes.lua` | Story scenes: the hero seed is held when the stage is built, released on its first visible frame (the hit). One line each. |

`SeedPackClient` and `RarePullScenes` only gained lines (comments included), so every older test that pins one of their lines still holds. The seed, its timing, its sounds and what everyone sees from the burst on are exactly as before. Only the moment the seed's own effects start has moved: from the fifth click to the moment the seed shows.

## Pack by pack

"Leaked" = something of the seed was drawn before it showed. The pack's **own** look (its tier rings and motes, its biome sparkles, the Gold / Diamond coat, the weather on it, its size and shape, the Mech pack's hum and antenna sparks) is the same for every pack of that kind and is **kept**.

| Pack | Before | Now |
| --- | --- | --- |
| **Mech** | Leaked: the Mech scanner round the pack on every opening, in the world and on the stage (the screenshots) | Fixed |
| **Void** | Leaked: the scanner when the 1 in 200 Mech seed was inside (it told you "Mech" at the first click); the stage seed's sparkles for every Secret / Cosmic / King | Fixed |
| **Verity** | Leaked: the scanner when the Mech seed was inside; the stage seed's sparkles | Fixed |
| **Biome packs** (Forest, Desert, Snow, Lava, Crystal, Jungle, Storm) | Leaked: the stage seed's sparkles for a Secret / Cosmic / King; the seed's copy of the pack's weather effect sat on the hidden seed | Fixed |
| **Mystery (daily) pack**, **event packs**, **bonus roll packs**, **gift / giveaway packs** | Same code as the packs above (they are a biome, Void, Verity or Mech pack) | Fixed with them |

Checked and clean, nothing to change:

- **Before the fifth click** nothing of the result exists on the client: the server sets the seed, its rarity, its weather and the reveal time together on the fifth click (`ChestService._activatePack`). A world pack has no seed rolled when it spawns. The hotbar, Bag and Index pictures, the held pack, the track pack and the dropped pack are built from the pack's kind, size, coat, weather and shape only. (Owner test packs from `/test rarepacks` are named after their rarity on purpose.)
- **The Mech pack's coat** is the pack's own Gold / Diamond roll (bought with the pack), not the seed's.
- **The pity bars** show "next one's lucky" for the pack count; they say nothing about the seed.

## Left as it is (it is the reveal itself)

From the fifth click the reveal builds suspense on purpose, and the owner asked for it to stay exactly: the pack wobble and the bit-by-bit tear (they get longer for rarer seeds), the seam glow that walks up the colour ladder, the Mech scan lines in that same colour, the Legendary / Mythic charge-up motes, the story scene for Secret / Cosmic / King, and the card. These show how rare the seed is **only as the suspense runs out**, by design. If the owner wants even these level until the burst, that is a new design choice: say so.

## Tests

`docs/proposals/R158b/tests/run_pack_leak158d.sh` (on line 6 of `tools/tests/run_all_suites.sh`):

- **static**: everything compiles at -O0, none over 180 registers; line 1 of the client scripts and Hotbar lines 1-2 as they were; `Config.lua` and the R151 frozen hashes hold; only these four files changed in `src`; the hooks are one line each.
- **`test_pack_leak158d.luau`** (the real client scripts on the Roblox mock, 109 checks): a Mech, Void, Verity and biome pack clicked four times has no seed, no scanner and no result attribute; for 14 openings (Mech Legendary / Secret / Cosmic / King, Void with a Mech and a Cosmic seed, Verity with a Mech and a King seed, Storm Secret, biome Mythic with Frosted, Forest Rare and Common, 60 fps, Reduced Motion) not one frame draws a scanner, a weather effect or a built-in effect while the seed is hidden (in the world and on the stage); they appear on the frame the seed shows; nothing is left.
- **the teeth**: the same test on the commit before the fix fails 12 checks (the scanner round the closed pack, the weather effect, the stage seed's sparkles).
- Older suites that pin these files, run again and passing: R153 `run_mech_pack.sh`, R153 `run_jitter.sh`, R152 `test_seed_fx` / `test_seed_collect`, R151 `run_rare_pull.sh`, R155 `run_camera155.sh`. R155's camera suite compares the reveal byte for byte with R154 (every frame of every rarity, desktop / phone / low quality). Three small updates keep it honest: its allow-list (`perf155_opts.luau`) now names this change (the `FxHeld` flag is left out, and a hero-seed effect that is switched off reads as on), `perf152_fp.luau` lets that list leave an attribute out of the frame streams as it already could of the shots (nothing changes without a list), and the suite's list of changed `RarePull*` modules now includes `RarePullScenes.lua`. With them the seed step compares 15 runs, 0 differences. (The effects really are back on once the seed shows: `test_pack_leak158d.luau` checks that.)

## To check in Studio

`/test rarepacks mech @me`, open each pack: no cyan / yellow dashes round the pack or on the stage until the seed shows, then the scanner circles the seed as before. Same with `/test rarepacks verity @me` and a Void pack.
