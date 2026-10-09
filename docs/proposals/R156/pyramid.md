# R156: the Desert pyramid with the secret Mythic pack

Owner: "a pyramid can have the mythic pack of that biome its a one time thing so players collect it once and its gone. the snake will still chase them tho and its same and mutations are all fixed"; "it will just be in the pyramid model no secret passage and no pedestal just a floating pack in the pyramid model which i will send u and we can replace the current pyramid in the game"; "hollow the inside and make sure that players can hold e when looking inside the pyramid".

Preview: [`pyramid.png`](pyramid.png) (built by the real game code on ur place, drawn with three.js, so it's **approximate**: no Roblox lighting, materials or bloom).

This is a branch for u to look at first. Nothing is installed yet.

## What's built

- **Ur pyramid replaces the Sunscar Pyramid**, same spot in the Desert (base centre X -62.07, Z 1005 when the game runs, on the same ground). It's ur Classic Pyramid (asset 113814131474028) slab for slab: 18 Limestone slabs, colour 248, 217, 109, same sizes and steps as ur model, just scaled (see below).
- **Hollow inside.** The bottom slab is a solid floor, the top 3 slabs are solid caps, and the 14 slabs between are rings of 4 walls, each one step thick. From outside it looks exactly like ur model. Inside there's a stepped room 15.7 studs high. No door, no passage, no pedestal. 60 parts, all anchored.
- **The secret pack** floats in the middle of the room, 3.5 studs over the floor, slowly turning and bobbing. It's the Desert's Mythic pack (Pack06), the same as a Desert Mythic pack on the track: same look, same odds, size 1. Its coat is plain. "mutations are all fixed" is one setting, `PyramidRules156.Mutation` (`'None'`, or `'Gold'` / `'Diamond'` if u ever want).
- **Hold E from outside.** The prompt is the normal steal prompt ("STEAL", hold E for 1 second, like every pack). It works through the walls, from anywhere next to the base (corners too), on the steps, or inside.
- **One per player, ever.** Each player has their own pack. Once they bank it, it's gone from the pyramid for them only. Other players still see theirs.

## The scale (0.6834) and why

Ur model is 65.56 studs wide. The old pyramid was 44.8 wide (the Config says 40, but the place has it at 1.12x). At full size, centred on the old spot, ur pyramid would reach X -94.8, right through the Desert's left wall (its inside face is at X -89). Moving it toward the track to make room would push it 21 studs into the running area.

So it's scaled down evenly to **0.6834**, which makes the base exactly the old one: **44.80 x 44.80**. That keeps the 4.5-stud walkway along the wall and the old edge toward the track, and it touches nothing but the ground (no wall, keeper camp, pack spot, spawn or prop; the test checks ur real place). It's **20.16 studs tall** (18 steps of 1.12), lower than the old one (about 38), because ur model's steps are wider than they are tall.

One knock-on: a resting keyboard key is 1.2 tall, taller than the 1.12 first step, so keys would poke through the bottom step. Every key the pyramid stands on is now left out (42 keys), so it stands on plain sand.

## Hold E distance

The prompt reaches **37.7 studs** from the pack: the base's half-diagonal (31.7) + 6. On top of that each player's game only turns the prompt on inside a box around the pyramid (the base + 6 studs, from the ground to 6 over the top). So no prompt from across the track or from another building, and nothing else stands in that box on ur map. The server checks the same box again (+2 studs for lag), plus everything a normal steal checks.

## The rules

- The pack counts as **claimed only when it's banked** at ur base, the same as a normal steal.
- **Caught by the Sand Snake** (or hit by a bat or lightning, or fell in a hole): the hit happens like normal, but the pack doesn't drop on the track. It goes straight back into the pyramid for that player and they can try again. **Lost** (fell off, died, left the game): same.
- The carry is a normal steal. The **Sand Snake** chases exactly like it does for a stolen Desert pack (it takes turns with other carriers, as now). It counts for the hidden pack-size pity and the pack pity like any world pack. The 200 limit applies: a full bag stops the pickup with the normal "BAG FULL" message.
- The server checks every trigger. Claimed, already carrying a pack, too far, outside the box, spamming, or the biomes refreshing: nothing happens.
- Players see: "YOU TOOK THE SECRET PACK! RUN TO YOUR BASE!", "🔺 YOU GOT THE SECRET PYRAMID PACK!", and "CAUGHT! THE PACK WENT BACK IN THE PYRAMID" (SMACK! / ZAP! for a bat / lightning; "THE PACK WENT BACK IN THE PYRAMID. TRY AGAIN!" for a hole, a fall or a death).

## Saved

`Premium.Secrets156 = {Pyramid = true}`, set in the same step the pack lands in the Bag. It's an optional field, so old saves load fine and the profile version stays 22. It sits inside `Premium` because an older server keeps unknown Premium fields as they are, so a claim can't get lost if an old server saves the player. Each player's state is shown to their game as the attribute `SecretPyramid156` (`Open` / `Out` / `Claimed`).

## Test command

- `/test pyramid @name`: does the player have it (saved), are they carrying it now, the pyramid's spot, size and reach.
- `/test pyramid @name reset`: clears the claim (saved), so the pack is back in the pyramid for them. Packs they already have stay in their Bag. (`/test pyramid reset @name` works too.)

## Things I decided for u (say if u want them different)

1. **Walk-through, like every landmark.** All props are walk-through (R95), and the old pyramid was too. Players can walk inside and see the pack. If it were solid, a carrier could stand on top where the snake can't reach and keep the snake busy for everyone.
2. **Caught = straight back into the pyramid.** No 5-second drop on the track, so nobody else can grab someone's secret pack.
3. **Size 1, plain.** "same ... mutations are all fixed" read as: always a normal-size, plain Desert Mythic pack. It still goes through the hidden size pity at the bank, like any stolen pack.
4. **Scale 0.6834** to fit the old spot (above), and the keys under it left out.

## Files

- New: `src/ReplicatedStorage/PyramidRules156.lua` (ur model's numbers, the rules), `src/ServerScriptService/ChestChaseServer/SecretPyramid156.lua` (builds it, runs the pack), `src/StarterPlayer/StarterPlayerScripts/SecretPyramidClient156.client.lua` (the floating pack and the prompt for each player).
- Small hooks: `MapService` (builds the pyramid with the other map passes), `ChestService:Bank` (the claim), `ChestChaseServerMain` (starts it), `KeyboardSkip152` (keys under it), `OwnerUpdateCommands82` + `OwnerCommandTargets82` + `StudioTestHelp` (`/test pyramid`), `MANIFEST.tsv`. Config is not touched, and neither is the keeper code (`ConcurrentKeeperService`, frozen since R149): "caught / lost goes back" is two small wrappers that `SecretPyramid156` puts on the running chase service, and they only touch the secret pack. R151's list of files that make packs now has `SecretPyramid156` on it (a real source, so a pull from it gets announced like any other), and so does its pack-shape list (the secret pack keeps the default chip-bag shape for good, so it looks the same floating, carried and in the Bag).
- Tests: `docs/proposals/R156/tests/run_pyramid156.sh` (in `tools/tests/run_all_suites.sh`). Preview: `docs/proposals/R156/preview/run_pyramid_preview156.sh`.

## Checked

- `sh docs/proposals/R156/tests/run_pyramid156.sh <scratch dir> <ur place .rbxl>`: server 70 checks, client 28, ur place 23 (all 0 failures), z-fighting PASS (nothing touches the pyramid, no two pyramid faces share a plane). Add `mutate` as a 3rd argument and 11 broken copies of the code all get caught.
- Every other suite in `tools/tests/run_all_suites.sh` passes too, including the whole-map z-fighting sweep, the keyboard, the keepers, the inventory, the pack pity and the -O0 compile check.

Performance: 60 static anchored parts. The floating pack is built only on players' screens within 220 studs, and only if they haven't claimed it. Its turn and bob are 4 tweens made once, so no script runs every frame for them. The prompt check runs 5 times a second, only while the pyramid is streamed in.
