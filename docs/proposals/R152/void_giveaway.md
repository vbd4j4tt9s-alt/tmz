# R152: the free Void Pack pedestal (500 claims, every server)

Owner request: *"add a pedestal in the middle that gives a player 1 void pack. it will be a limited time for 500 players only and its in every server so basically once serverwide 500 claims have been done it will go to 0 and will not be claimable any more. there is a number above that shows how many is left"*.

Preview (approximate, the owner's real hub): `void_giveaway.png`. Regenerate with `sh preview/run_giveaway_preview.sh <scratch dir>`.

## What the player sees

- A pedestal in the middle of the plaza (X 0, Z -392, where the fountain stood), styled like the market's Fruit of the Hour pedestal (footing, plinth, column with lettering, capital, glowing cradle with four prongs, soft beam) in Void colours: obsidian and dark purple with violet glow. About 32 parts, nine of them solid.
- A real **Void Pack** floats over the cradle, hovering and turning slowly (one lap in about 14 s). It is built the way the game renders a Void Pack (`SeedPackVisuals.Bag` -> `EclipsePackArt`), and its glow and particles are `VoidPackFx`'s (haze, nebula swirl, starfall, debris, comets, pulsing light), moved together with the pack every frame: they are on the pack, there is no disc behind it. **Cost by quality tier** (review fix): tier 3 (desktop) is unchanged, every frame with its violet Highlight; tier 2 and below (phones) have **no Highlight** (an outline written every frame) and step the whole pack (pose, debris, comets, pulse: one BulkMoveTo) at **30 Hz** with the time it skipped, so the turn keeps its speed. Only within 190 studs of the camera, as before.
- A sign over it, built in studs (it shrinks with distance, and stops growing closer than 30 studs): small title `FREE VOID PACK`, then **`487 / 500 LEFT`**, then a quiet line (`LIMITED · ONE PER PLAYER`; `CLAIMED ✓` once you have claimed; `CLAIMING…` while the server works). The number pops every time it changes, so it ticks down live.
- Prompt `Claim FREE Void Pack` (short hold). It is off for you once you have claimed and off for everybody at 0.
- Claim moment: the game's own notice (`🌑 FREE VOID PACK! Check your Bag!`), the reward chime the game already has (`InteractionAudio` `GemClaim`, no new sound), the pack hops, a burst of sparks, the number pops.

## How it works

| Piece | File |
|---|---|
| The numbers, texts and the one reservation rule (`Rules.Reserve`) | `ReplicatedStorage/VoidGiveawayRules152` |
| The shared DataStore key and its retries | `ServerScriptService/ChestChaseServer/VoidGiveawayStore152` |
| The service: the claim, the count, messages, polling, owner tools | `.../VoidGiveaway152` |
| The pedestal's parts and prompt | `.../VoidGiveawayArt152` |
| The pack, the number, the prompt per player, the claim moment | `StarterPlayer/StarterPlayerScripts/VoidGiveawayClient152` |

Wiring is one guarded line in `ChestChaseServerMain` (a failure only means no pedestal), the owner command, and the manifest rows. `Config.Version` and `ProfileVersion` (22) are unchanged.

### The global count

One DataStore key, store `VoidGiveaway152`, key `Claims`, value `{Count = n, Users = {[tostring(userId)] = unixTime}}` (about 15 KB at 500). It is only changed by `UpdateAsync`, whose transform (`Rules.Reserve`) is:

- user already in `Users`: nothing to write, treated as already reserved (idempotent);
- `Count >= 500`: refused, nothing written;
- otherwise add the user and `Count + 1`.

`UpdateAsync` runs the transform again on the fresh value when another server wrote in between, so two servers racing at 499 can never both get the last pack, and a user is never counted twice. (The transform cancels instead of rewriting an unchanged value: same stored value, no write.)

### The claim (`VoidGiveaway152:Claim`)

1. Data loaded and able to save (a pack that cannot be saved would be lost; Studio without API access is let through to test).
2. Not flagged (`Premium.VoidGift152`).
3. Not at the cap, unless they already hold a reservation.
4. Standing at the pedestal.
5. Room in the Bag (`Config.MaxSavedChests`, the game's own limit). If full: "Make room in your Bag first", **nothing reserved**.
6. Reserve with `UpdateAsync`: four tries with waits of about 0.6, 1.4, 3 s; then "try again". **A pack is never given without a successful reservation.** While the store's backoff (`NextTryAt`: 5 s, doubling to 60 s after failures) runs, a claim is refused at once with "try again in N s" and **no request** (`Store:Reserve` and the service both check), and a player who just hit a store failure waits 10 s (`StoreCooldown`) before pressing again.
7. Give one real Void Pack (`AddChest`, stage 7, `EclipseReliquary`, size 1, no options: **not `TestGrant`**, so it announces when opened like any pack, and saved **`GiftLocked=true`**, see below), set the flag, `MarkDirty` + `QueueGardenSave` like the daily and mystery grants, sync the hotbar, notify. Step 7 never yields: the flag check, the pack and the flag are one step, so a profile gets at most one pack however many paths run.

**Interrupted grants.** A player who is in `Users` but has no flag (a crash, a Bag that filled while the store answered, a save that was lost) is *owed*. This server gives the pack when it sees them (every 2 s, and when they press the prompt), using the same reservation (no second count), even at 0 left (where the prompt is off). It cannot give twice: the flag is checked and set in the same step as the pack.

**Retries of an owed pack.** The loop passes `auto` into `_run`: when a pack cannot be added the player is told **once**, and the loop waits 5, 10, 20 .. 60 s before the next try (their own press always tries at once and always answers).

**Free packs can't be gifted (`GiftLocked`).** Alternate accounts claimed the pack and gave it to a main account. The giveaway pack's record carries the optional field `GiftLocked=true`, saved exactly like `PackShape` / `TestGrant` (`PlayerDataService`: `AddChest`, `SerializeSeedRecord`, `_decodeSavedSeedRecord`; only a Pack row, only exactly `true`). `FruitGiftService` refuses it in `OfferSeed` and `AcceptSeed` ("Free giveaway packs can't be gifted"), and `ConvertVoidPack` gives the Verity Pack the same lock. An opened pack is a Seed record (no lock). No profile version change: an **R151 server ignores the field** (it loads the pack as a normal Void Pack and, if it saves that profile, writes the row without it, so the lock is lost for that profile: keep R151 servers out of rotation once R152 is live).

**Account age (`Rules.MinAccountAgeDays`).** `0` = off (shipped off: the owner decides). Above 0, `Claim` refuses an account younger than that many days with a friendly line ("Come back in N day(s)!"), before anything is reserved; a player who already holds a reservation is still given their pack.

The flag is an optional field of the saved `Premium` table (`Premium.VoidGift152 = true`). `PremiumProgress.Decode` copies fields it does not know, so older servers keep it and no profile version change is needed.

### Keeping the number fresh across servers

- After a claim the server publishes `v1:<count>` on MessagingService topic `VoidGiveaway152` (at most one message per 1.5 s, always the latest count).
- Every server also reads the key every 45 - 60 s (jittered), backing off 5, 10, 20 ... 60 s after a failed read; a failed read leaves the number as it was.
- The **highest count seen wins**. It only goes up, so at 0 the pedestal stays `ALL CLAIMED` for ever in a running server (no reset path, a message or a hand-edited store cannot reopen it).
- Once a read has seen 500 the value cannot change, so polling stops.

Budgets: about 1.2 reads a minute per server, one `UpdateAsync` per claim, at most a message every 1.5 s per server. One hot key is the owner's design; at launch many claims hit the same key, which is why every claim retries with backoff and says "try again" instead of failing silently.

### At 0

`Left` = 0, `State` = `Empty`: the sign says `ALL CLAIMED` / `0 / 500 LEFT` (dimmed), the column lettering says `ALL CLAIMED`, the prompt is disabled for everyone, the pack keeps turning but its glow and sparks are off ("asleep"), further presses cost no DataStore request. Players who are still owed a pack still get it.

## Studio

- Studio uses its **own store** (`VoidGiveaway152_Studio`), exactly like the player data's `_Studio` store, so a test can never touch the live count.
- **Live or Studio is decided by `RunService:IsStudio()`, nothing else** (the store and the service both ask it when they start). A *published test place in the same universe is not Studio*: `IsStudio()` is false there, so it uses the **live key** (`VoidGiveaway152` / `Claims`) and every claim made in it counts against the real 500. Test in Studio itself, or give the test place its own universe.
- With **Game Settings -> Security -> "Enable Studio Access to API Services"** on, Studio reads and writes that Studio store (a real DataStore test, including `UpdateAsync`). The game must be published for it to work.
- With it **off**, the first read fails and the server switches to an in-memory counter with **one** warn line (`[R152] Void giveaway: no DataStore in Studio ... using an in-memory counter`). It resets when you stop playing. A live server never does this: if the live store fails it keeps trying and players are told to try again.
- Your own profile cannot save without API access either; the claim still works in Studio so you can see the whole flow.

## Test commands (owner)

| Command | What it does |
|---|---|
| `/test voidgift` | Server status: claimed / left, whether *you* claimed (profile flag, shared list, state), which store this server uses (`LIVE` DataStore, the Studio test store, or the in-memory counter), messages sent / received, the pedestal. Works live. No `@name`. |
| `/test voidgift reset me` | **Studio only.** Clears your claim: the shared list loses you, the count drops by one, your flag is removed so you can claim again (the pack you got stays in your Bag). |
| `/test voidgift left 3` | **Studio only.** Sets how many the pedestal shows as left (0 = ALL CLAIMED, 487 = a fresh start). Players already listed keep their places. |

**Live data is never reset by a command.** My call: only the two Studio-only commands exist, they refuse in a live server (both in the service and in the store), and in Studio they write the Studio store or memory, never the live key. A live reset (for example to run the giveaway again) should be done deliberately in the DataStore editor and servers restarted, not by a chat command.

## Tests

`sh docs/proposals/R152/tests/run_void_giveaway.sh [scratch dir] [mutate]` (also in `tools/tests/run_all_suites.sh`): wiring, the server (224 checks: claim, second claim, race at 499, cap, full Bag, interrupted grants, failures, messaging, polling, Studio fallback, commands, guards, the review fixes: GiftLocked, account age, backoff, retries), the real player data (59, with GiftLocked saved, loaded, kept by Verity, ignored by an R151 server), the pedestal (59), the client (92), and the R149 z-fighting detector on the pedestal, pack and effects. `mutate` breaks 90 things one at a time; each must make a suite fail.

R151's `static_checks.sh` was updated on purpose: MessagingService is now used by the announcer **and** the giveaway, and `VoidGiveaway152.lua` is a known pack source (a real one: it announces).

## Doubts

- One account can claim once; alternate accounts can each claim. The pack is now `GiftLocked` (it can't be handed to a main account) and `Rules.MinAccountAgeDays` (0 = off) is there if you want an age gate: your call. An alt can still **open** a locked pack; the seed that comes out is a normal item.
- The hotbar stacks identical packs whatever their lock, so a stack of a locked and an unlocked Void Pack says "can't be gifted" when the held one is the locked one.
- A single hot key means a flood of claims at launch is throttled by DataStore (per-key write limits); players get "try again" and the retry is safe, nobody is double-counted or loses a pack.
- The pack art (approved meshes) cannot be rendered offline: the preview shows stand-in meshes under the Void art's own parts. Check the look in Studio.
- The old Seed Fountain is removed by another change; the pedestal's footing (16 studs) leaves about 5 studs to the benches that stood round it.
