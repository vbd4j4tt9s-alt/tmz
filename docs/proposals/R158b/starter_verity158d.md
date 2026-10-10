# R158d: the new-player gift

Owner: "new players receive a pack, every new player, and it's notified to them; the pack is guaranteed Mythic or above"; then "it is a Verity Pack", "2 bonus rolls at the start", "this will only last till the Verity event ends", and the notice "Thanks for playing! Here's a gift".

## What a new player gets
- ONE real Verity Pack, guaranteed Mythic or better when opened.
- 2 treadmill bonus rolls (normal odds, the BONUS ROLL button shows them ready).
- ONE notice: `Thanks for playing! Here's a gift`.

## Who, and when
- Only a brand-new profile (nothing was saved before the join). Existing players get nothing.
- Only while the Verity event runs (the server clock, the same check Verity uses). When it ends, new players get nothing: no pack, no rolls, no notice, and no flag is written. A gift that was waiting when the event ended is also not given ("only while the event is active").
- R158e (owner: "the verity gift is given instantly to all new players"): at the player's FIRST SPAWN, at once, while the tutorial runs (R158d waited for the end of the tutorial). If the profile loads before the character, it comes with the first CharacterAdded. The notice comes 4 s later, so it is read after the title screen (a new player's title closes about 1.2 s after it shows).
- The gift does not skip the tutorial's steal step: only a pack STOLEN on the track and banked ticks it (`AddChest` with `Banked`, from `ChestService:Bank`); a gift, a bonus roll or any other grant never does. After the steal, opening ANY pack counts for the "open it" step (owner: "the player can open ANY pack and it will count"), the gift pack too. The tutorial's own free Forest pack still comes at the end.
- Once per player, ever. Saved as `Premium.StarterVerity158d`: not set (old saves) / `Owed` (a new profile while the event runs, saved at once) / `Given`. The grant is one step: the pack, `Given`, the 2 rolls, the save. If it is interrupted (a crash, a full Bag, data that cannot save) the player is still `Owed` and gets it on the next try, spawn or join, never twice.
- The 2 rolls are session-only in the bonus system, so the unused ones are also kept in `Premium.StarterRolls158d` (0 to 2) and come back after a rejoin. Each roll the player uses takes one off. ProfileVersion stays 22; both fields are optional.

## The guarantee
- The pack's record has `Floor = 'Mythic'` (an optional field, next to `GiftLocked`). Only the server sets it (the gift service, through AddChest), and only a Verity pack keeps it. It is saved and loaded.
- On open, the server takes the Verity pack's OWN odds for that open (same table, the clover, the pity's lucky roll, the 80% rule), keeps the seeds of Mythic and above (Mythic, Secret, Cosmic, King) and rolls again over what is left. Luck can only move chance between those seeds. Nothing is invented: the pool is what the Verity pack can already give. An owner test reveal still wins.
- Inside the floor (luck x1): Mythic 0.21%, Secret 93.84%, Cosmic 4.95%, King (the Verity seed) 1.00%. Only Plasma Pepper (Legendary, 0.24% of an ordinary Verity pack) is dropped.
- It counts toward the pack pity like any Verity pack.

## Exploits
- The pack is `GiftLocked`: it cannot be gifted (message: "Free Verity Packs can't be gifted"); the seed opened from it, the plant and the fruit stay locked too. So an alt cannot pass a guaranteed Mythic to a main account. Discarding only deletes.
- The gift pack's tool is named `Gift Verity Pack`, so it never shares a hotbar slot or a Bag stack with ordinary Verity Packs (the stack key holds the name). Records are separate anyway: nothing merges.
- Test grants never make a floored pack. `/test starterverity @name` shows the state; `/test starterverity @name reset` is Studio only.

## Files
`StarterVerityRules158d` (rules, words, the floored roll), `StarterVerity158d` (the service), `PlayerDataService` (save / load / open / fresh-profile mark), `ChestService` (name, tooltip), `TreadmillBonusService` (the rolls come back, spending), `FruitGiftService` (message), main script (one guarded line), `OwnerUpdateCommands82`, `OwnerCommandTargets82`, `StudioTestHelp`, `docs/COMMANDS.md`, `src/MANIFEST.tsv`. Test: `docs/proposals/R158b/tests/run_starter158d.sh`.

## Notes for the owner
- The gift pack is a real pack, so its open is announced like any real pull (a Secret is announced in the server). If that is too noisy with many new players, tell us and we make its open silent.
- The bonus-roll timer pauses while 2 rolls are ready (the existing rule), so a new player starts earning the next roll after using one.
- The 2 rolls make ordinary packs, and those can be gifted (only the Verity gift pack is locked).
