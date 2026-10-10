# R154: the seed waits on screen, a click sends it to the inventory

Owner: "minor fix after i want to make it so that after obtaining the seed the seed stays on the player's screen until they click and the seed goes to their inventory".

Preview: `seed_collect.png` (a Legendary card and a King story scene: the result, still waiting 30 s later, the click, the flight, the landing, the hotbar).
Regenerate: `sh docs/proposals/R154/preview/run_seed_collect_preview.sh <scratch> [node_modules]` (R152's preview pipeline, unchanged, plus `collect_frames154.luau`).

## What the player sees (every rarity, cards and story scenes alike)

- **The result waits.** Once the seed, its rarity, "1 in N" and its name are shown, nothing closes them: no timer. A card stays where it is (the seed keeps turning). A Secret / Cosmic / King scene holds its hero shot in the stage. The hint in the bottom-right corner (where R153's skip hint is) says **"click to collect!"**, or **"tap to collect!"** on a phone. The reveal's sounds and the music duck still end on the presentation's own length, so the result waits in silence.
- **The click sends it home.** A click or tap anywhere, Enter, gamepad B or R2 (a story scene: its full-screen button and keys) collects the result:
  - the seed flies from the card in a small hop into **its hotbar slot**: the slot of a stack it joins, else the first free slot (the opened pack's own when that was its only one);
  - if no slot is free, it flies into the **Bag button**;
  - on arrival it pops, the slot (or the Bag button) flashes, and the bag's pickup cue plays (Bubble06, the existing arrival sound);
  - the flight has the soft R152 whoosh, swelling on its fastest frame;
  - the card's text fades as the seed leaves;
  - a story scene first goes back to the world (its fade to black, quicker: 0.35 s), then the seed flies from the middle of the screen.
- **Reduced Motion:** no flight. The seed fades where it is (0.25 s), then the same arrival.
- **Skip (R153) still works:** the first press jumps to the hit. A press in the moment the result lands (0.25 s) does nothing. The next press collects it (R153 closed the card).
- **The press is never a tool's.** The R153 rules apply (`RarePullRules.ClaimPress`, the tool guards, packs / bat manual-only). While a result waits, **every** press is the reveal's. The first one collects it, so a click never plants, digs, gives or swings. HUD buttons, hotbar slots, drags and long presses work as before and do not collect.

## The seed is already the player's: presentation only

The server is unchanged:

- the seed is committed on the 5th click (`PlayerDataService:OpenSeedPack`), and keeps the pack's inventory id;
- at `RevealDuration` the server ends the opening: the pack goes, `SyncTools` makes the seed's tool, and it is equipped if the hand is empty (R153).

So the tool reaches the Backpack and the hand on the server's time, which is usually before the player clicks. To make the visible arrival match the click, the opener's client holds back how it looks (`SeedCollect154`; no server change):

- **Hotbar:** a seed tool with the opened pack's id is not shown until the flight lands. This is the R149 mechanism used for harvested fruit.
- **Hand:** if the server put the seed in the hand, it is hidden on this screen until the flight lands: `LocalTransparencyModifier`, and its effects switched off. This includes the seed model the server builds a frame later. The R151 aura of a held seed is left out too (SeedPackClient). EconomyClient does not count it as "a seed in the hand" (no aim, no planting) until then.
- **Weather / Mech effects:** the drips, frost, arcs and Mech gears of that seed are drawn by `ItemCosmetics` outside the tool, so hiding the tool does not hide them. `ItemCosmetics` asks `SeedCollect154.Hidden` and draws nothing for a part inside a tool the hold hides; when the hold ends (`OnRelease`) it looks again on the next frame, so they come back as the seed lands, with no per-frame cost.
- **The world seed** of the opener's own pack no longer flies into their hand while the result waits. It fades where it hovers. Once collected, it fades out: it went home with the card.

Other players see exactly what they saw before.

A click before the server has ended the opening (a skipper's fast collect) works the same way. The seed flies to the slot it will take, pops there, and rests on that slot until its tool arrives. Then it gives way to the slot's own picture.

A hold always ends. It ends when the flight lands. A presentation that ends before its seed was revealed releases it quietly. An abort releases it. The director touches it every frame, and an untouched hold ends after 5 s (a touched one when its time is up: the watchdog looks again at the hold's own due time, not a whole 5 s later). A story scene cut short before its hit lets its hold go at once when the result card that should follow cannot start.

## A waiting result is never lost

Whatever takes the player away collects the result for them: the seed flies in. Each of these counts only when it starts while the result waits, so a result is never collected the moment it appears:

- death or a respawn;
- a ragdoll or a fling;
- a chase starting (a run, queued, carrying) or a keeper chasing;
- a teleport (a jump of more than 30 studs, or more than 3 times what the runner's speed covers in the time since the last frame: a fast runner on a slow frame, a hitch or a fall is not one; the base / track teleport buttons jump hundreds of studs);
- walking onto or off the track, or more than 90 studs away;
- a menu opening (the shop, the Bag, the Index, Daily ...);
- **the next pack opened**: the waiting seed flies in first, then the new opening plays.

A story scene keeps its R151 safety rule while it holds its hero shot: a keeper near, a fling, a chase or being moved cuts back to the world, and the seed flies in. Owner previews (`/test rarepull`) wait and fly too, into the Bag button (nothing is granted).

## Sound

The R152 / R153 rules are kept.

- A collect while the reveal still rings (skip, then collect at once) fades the reveal's tail and the music duck out over 0.2 s (`RarePullAudio.FadeOut`). The reveal is silent before the seed lands.
- The whoosh peaks on the flight's fastest frame (half way).
- The pickup cue plays on the landing frame, never on top of the reveal.
- The whoosh is the Flight slot at 0.35 x its volume and 1.15 x its pitch: under the -30 LUFS whoosh cap (checked).
- Bubble06 plays at its own 0.22.

## Files

| File | Change |
|---|---|
| `ReplicatedStorage/SeedCollect154.lua` (new) | Holds (hotbar / hand / world seed), the flight, the landing. In `MANIFEST.tsv`. |
| `ReplicatedStorage/RarePullCinematic.lua` | The result waits (`Beats`), the collect (press, `M.Collect`, the edge cases), the scene's way out from the collect, the hold. |
| `ReplicatedStorage/RarePullCard.lua` | The collect hint, `TakeSeed` (the seed's view leaves the card), nothing fades while the result waits. |
| `ReplicatedStorage/RarePullAudio.lua` | `FadeOut` (the tail of a collected reveal). |
| `Hotbar.client.lua` | Holds the seed back. Says where it lands. Flashes on arrival. One new top-level local: about 169 of 200. |
| `SeedPackClient.client.lua` | The opener's world seed stays out of the hand. No aura on a held-back seed. |
| `EconomyClient.client.lua` | A held-back seed is not the planting seed. |
| `ItemCosmetics.client.lua` | No weather / Mech effects for a seed the hold hides; looked at again as the hold ends. |

Line 1 of every client script is still the R152 load guard (Hotbar: line 2, as before). `BackgroundMusic` and `Config.Version` are not touched. Every changed script compiles at `-O0`.

## Tests

`docs/proposals/R152/tests` (`run_seed_opening.sh`):

- **New `test_seed_collect.luau`** runs the real SeedPackClient, PackOpeningFeedback and Hotbar, and checks:
  - every presentation waits 120 s;
  - the collect by every press, and the landing on the slot, the stack's slot or the Bag button;
  - the hotbar shows the seed from the landing frame only;
  - the hand and the late-built seed stay hidden;
  - the world seed never reaches the hand;
  - every edge case above, the early collect resting on its slot, Reduced Motion, mobile, skip then collect, an onlooker;
  - the sound rules;
  - the review fixes: a held-back seed's weather / Mech effects (the real `ItemCosmetics`) stay off until it lands and are back on the next frames; the watchdog ends a touched hold at its due time; a cut-short story scene whose result card cannot start lets its hold go at once; a fast runner on a slow frame, a hitch and a fall do not count as a teleport, 300 studs still does.
- **Updated:** `test_seed_choice`, `test_seed_press` (adds the 20 s wait, the bat during a 15 s wait, and EconomyClient's held seed), `test_seed_stress`, `test_seed_sync`, `test_seed_fx`.
- **Stress run:** every opening is collected at a random moment, and every revealed seed must fly in once. The R152 hand-whoosh check now uses a pack opened next to the player.

Where older suites played a reveal "to its end", they now see it wait and then collect it:

- R151 `test_rare_cinematic`, `test_rare_world`;
- R153 `test_mech_opening153`;
- the perf152 seed driver, which collects 0.3 s after the timeline on both sides, so its fingerprints compare the same way.
