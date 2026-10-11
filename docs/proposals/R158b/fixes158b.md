# R158b: dropped packs you can see, a silent bat swing, a dirt sound for holes

Three small changes. Nothing here touches the server, `Config.lua` or any file in the R151 frozen list.
Picture: `docs/proposals/R158/dropped_pack158.png` (before and after on all seven track floors, 15 and 165 studs away, and Fast Mode). It is an **approximate** picture (three.js and Pillow, not Roblox: no Roblox lighting or haze, another font, and the pack's own faint rarity sparkle is left out on both sides).

## 1. Dropped packs have a highlight and can be seen

When a player carrying a stolen pack is caught, hit or zapped, the pack drops for 5 seconds. Every player now sees on it:

- **An outline** that pulses between **white and gold** about once a second, with a soft pale-gold fill. It shows through walls.
- **A marker** just above it: a gold diamond with **DROPPED PACK** and how many studs away it is. It is the same size on your screen near or far, and it shows through walls. This is what you see from far down the track.
- **A beam of light**: slim, gold at the foot and fading at the top, 90 studs tall, so it sticks up over the track walls.

Near (15 studs) you see the outlined pack with the marker above it. Far (165 studs) the pack is only about 12 pixels wide; the gold outline makes it a clear box, and the diamond and the beam show where it is.

**Colour.** One colour for every floor. The rarity colours would vanish on the matching floors (white on snow, green on forest and jungle, purple on crystal). White and gold do not both fade into any one floor; the picture shows all seven.

**The 31-Highlight limit.** Roblox draws only 31 Highlights at once, and the game already uses them (weather glows, mutation outlines, plant auras, track packs).
- Only the **nearest 4** dropped packs get the outline (**3** in Fast Mode), and never more than what is left of the 31. Each one is handed to `ClientFxBudget.TrackHighlight`, so the track packs give way and nothing else is pushed out. If the other Highlights already add up to more than 31, ours give theirs back first.
- Every dropped pack keeps its marker (nearest 16). Beams: the nearest 6 (3 on phones, none in Fast Mode).

**Fast Mode / low graphics:** the outline **stays** (nearest 3, one steady colour) and so does the marker; the beam, the pulse and the bob are off. **Reduced Motion:** no pulse, no bob.

**Gone means gone.** Everything for one drop is under one small local part; when the pack is taken, goes home, is destroyed or streams out, that part is destroyed. The frame loop stops with the last drop. **StreamingEnabled:** a dropped pack is a Persistent model; if its Body is late the effects use the pack's own position and move onto the Body when it arrives; a pack with no parts yet is not drawn.

**Where.** `DroppedPackHighlight158b.client.lua` (client only, reads the `DroppedChest` model attribute and the pack tag the server already sets), `DroppedPackLook158b.lua` (colours, sizes, budget: change them there), and one added function in `ClientFxBudget.lua`, `HighlightsUsed()` (the same count as `HighlightRoom()` before it is cut at zero; `HighlightRoom()` is unchanged). Both new files are in `src/MANIFEST.tsv`.

**To check in Studio:** outline thickness and the diamond size from 15, 50 and 150+ studs; the fill (`FillTransparency` .7) tints the pack a little; with several drops and the weather glows on, the outlines stay at 4 and nothing else disappears. SeedPackRender still gives a dropped pack its own faint outline as a normal world pack; if the two look muddy together, say so and it can be hidden for dropped packs.

## 2. A bat swing makes no sound

Only a hit has a sound now, exactly as before (the slap). The whoosh is gone for every swing, yours and everyone else's, and it is not preloaded. `SwingSound*` is removed from `BatConfig.lua`; `TrailRange` (150 studs, same number) now says how close a swing must be to draw its white trail. `LocalSfx.WhooshId` stays: fast travel and "go to top" use it. R158's and R150's tests now require silence; the R158 suite has mutants that put the whoosh back. The R158 bat docs say the swing is silent.

## 3. Digging a hole plays the planting Dig sound

Digging a hole plays your planting **Dig** sound (read from `PlantingEffects.Sounds`, so swapping it there carries over; `118769294546013`, volume .5, random pitch .96 to 1.04) at the hole, through `LocalSfx`, preloaded at start. Covering a hole and the trap thud are as before. `holes_R122/tests/test_holes_client.luau` checks it.

## Tests

`docs/proposals/R158b/tests/run_dropped158b.sh` (line 6 of `tools/tests/run_all_suites.sh`, before the pyramid suite): static checks, the dropped-pack test on the Roblox mock (look, gone when taken or returned or destroyed, the Highlight budget with other Highlights around, Fast Mode, StreamingEnabled, no leaks over 400 drops), the holes test (also with the Dig id swapped) and mutants. The picture is rebuilt with `docs/proposals/R158b/preview/run_dropped_preview158b.sh <scratch dir>`.
