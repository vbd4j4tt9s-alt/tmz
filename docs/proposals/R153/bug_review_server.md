# R153 bug review: server, data and economy

Scope: the server half of the R153 release review (the client half covers UI, effects, input and physics feel). Base: the release branch at `12d4694`, compared with the R152 release head `e36b71b`.

Method: I read every server module R153 touched, plus the save / load / economy paths they call. Suspected bugs were run on the Roblox mock (`tools/tests/roblox.luau` + `docs/proposals/treadmill_bonus_R123/tests/world.luau` + `docs/proposals/R153/tests/clover_env.luau`, with the real modules bundled by `mkbundle_clover.py`). Nothing in `src/` was changed. The scratch probes were deleted.

No Blocker or High findings. There are 3 Medium and 4 Low findings, ranked by severity.

---

## Medium

### M1. Owner `daily` commands put real (non-TEST) packs into the bag, and the one TEST arm goes to the wrong pack

- **Where:**
  - `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:66`: every daily pack, login or quest, calls `OwnerTestPacks.Claim(player,'Daily',added)`.
  - `src/ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua:217-221`: `daily done` finishes the quests without arming anything; `next` / `week` / `reset` arm one `Daily`.
  - `src/ServerScriptService/ChestChaseServer/StudioTestCommands.lua:101`: `daily` is not in `GrantsItems`, so the hub board is not tainted either.
- **Scenario:**
  - R153 made each quest pay a pack. The owner's `daily done` marks all three quests finished, and claiming them gives 3 packs with `TestGrant = nil`. Running `daily next` then `daily done` again repeats this as often as wanted. These packs announce in chat (Legendary+, and to every server for Secret+), and they count for BEST PULL because the player is not tainted.
  - `daily week` arms one `Daily` test pack, meant for the day-7 Void Pack. If a quest pack is claimed first, it uses up the arm, and the Void Pack that the command made claimable is saved as a real pack.
- **Confidence:** proven on the mock.
  - Case 1, `daily done` then 3 claims: `2001_1/Pack01 Test=nil | 2001_2/Pack01 Test=nil | 2001_3/Pack03 Test=nil`.
  - Case 2, `daily next`, `week`, `done`, then one quest claim and the login claim: the quest pack has `TestGrant=true`; the day-7 `EclipseReliquary` has `TestGrant=nil`.
- **Fix:**
  - Give the login and the quests separate arm sources, for example `Claim(player, login and 'Daily' or 'DailyQuest', added)`. `GrantDailyPack` needs to know which caller it serves.
  - Make `daily done` arm `DailyQuest` for the number of unclaimed quests.
  - Add `daily` to `GrantsItems`, or call `hub:NoteOwnerGrant(p)` for `done` / `next` / `week` / `reset`.

### M2. A free giveaway Void Pack's lock (`GiftLocked`) is lost as soon as it is opened, so the seed can be gifted

- **Where:**
  - `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:454-462`: the `reward` record that `OpenSeedPack` makes has no `GiftLocked`.
  - `src/ServerScriptService/ChestChaseServer/FruitGiftService.lua:189` and `:202`: the gift checks only look at `record.GiftLocked`.
  - `SerializeSeedRecord` / `_decodeSavedSeedRecord` keep `GiftLocked` only for `Kind == "Pack"`.
  - The Verity conversion (`PlayerDataService.lua:516`) keeps the lock on the Verity Pack, but its seed loses it the same way.
- **Scenario:** R152 locked the giveaway pack because alts were claiming it for a main account. An alt claims the free Void Pack, opens it (5 clicks), and gifts the seed (Secret / Cosmic / King / Mech) to the main. Nothing refuses it, so the lock does not stop the abuse it was added for.
- **Confidence:** proven on the mock: a `GiftLocked=true` Void Pack opens into a Seed with `GiftLocked=nil`, its saved row has `GiftLocked=nil`, and `DecodeGiftedSeed` accepts it.
- **Fix:**
  - Carry the lock onto the seed: in `OpenSeedPack`, set `GiftLocked = pack.GiftLocked == true or nil` on `reward`.
  - Save and load it for Seed records as well. It is an optional field like `TestGrant`, so ProfileVersion does not change.
  - Keep the two gift checks as they are.

### M3. The 4 Leaf Clover is sold as "2x luck on every pack", but Void, Verity and Limited Mech packs ignore luck

- **Where:**
  - `src/ReplicatedStorage/GamePassCatalog.lua:9`: `Description='2x luck on every pack u open! 🍀'`. The HUD luck row and the shop card show x2.
  - `src/ReplicatedStorage/SeedPackRules.lua:441`: the Void roll passes luck `1`.
  - `src/ReplicatedStorage/SeedPackRules.lua:540`: the Verity roll has no luck argument.
  - `src/ReplicatedStorage/SeedPackRules.lua:388`: stage 8 goes to the old odds, where Mech `Chance` values are fixed.
  - `src/ServerScriptService/ChestChaseServer/PlayerDataService.lua:765`: the luck cap.
- **Scenario:**
  - A player pays 999 Robux or 999 Gems. Every Void Pack still rolls exactly as without the pass: the day-7 login pack, the giveaway pack, and a bonus-roll Secret. So do Verity Packs and Gem-bought Limited Mech packs.
  - A player with Thunder Boots is already at `MaxLuck` (50M), so the clover adds nothing to any pack. The shop still sells it to them with no warning.
- **Confidence:** proven on the mock.
  - 20,000 Void rolls give identical counts at luck 1 and luck 50,000,000: `Cosmic=979 Legendary=68 Mythic=80 Secret=18873`.
  - Verity rolls are identical at luck 1 and 2.
  - Mech odds are identical at luck 1 and 2: `Crowncore 0.5 / HoloApple 7 / HoloMelon 26 / Nebula 2.5 / Plasma 48 / Prism 16`.
  - Biome packs do change: Storm Pack01 King goes from 1e-10 to 2e-10.
- **Fix:** this is the owner's call. Either:
  - change the description to "biome packs" and have the shop card say "no effect at max luck" when `ChestLuckMultiplier` is already at `MaxLuck`; or
  - pass luck into the Void, Verity and Mech rolls. That is an odds change, so it needs owner approval and new odds tables.

---

## Low

### L1. During the rollout, a quest claimed on R153 blocks the remaining quests on an R152 server, and the day's all-done bonus is lost

- **Where:**
  - `src/ReplicatedStorage/DailyRewards.lua:12`: `RewardVersion=153`.
  - `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:78`: R153 writes `RewardVersion=153` and `Bonus`.
  - In R152's `DailyRewards.ReadQuests`, any version other than 141 counts each claim as 5 gems. R152's `DailyData` also writes the quest state back without `Bonus`.
- **Scenario:**
  - A player finishes all three quests and claims quest 1 on an R153 server (they get a pack). The same UTC day they land on an R152 server. R152 reads `GemsGranted = 5`, so `QuestBlocked` is true and `QuestsReady` is 0: quests 2 and 3 are refused there ("DAILY QUEST GEM LIMIT HIT").
  - Back on R153, the stored `RewardVersion` is now 141 and `GemsGranted` is 5. `BonusBlocked` is true, so the +2 gem bonus can never be claimed that day.
  - No gems or packs are paid twice; the player just loses that day's 2-gem bonus, and the remaining quests are blocked while on R152.
- **Confidence:** proven on the mock, with the R152 module from `e36b71b` and the R153 module side by side.
  - R152 reads: `GemsGranted 5, QuestBlocked true, QuestsReady 0`.
  - Back on R153: `RV 141, GemsGranted 5, BonusBlocked true, BonusReady false`.
  - The same day entirely on R153: `BonusReady true`.
- **Fix:** none needed after the rollout ends, since it only affects the mixed-version window. To soften it, keep migration windows short. Alternatively, R153 could keep writing `RewardVersion=141` with a separate `Packs153=true` marker, which R152 would read as old claims worth 2 gems, not 5.

### L2. During the rollout, "Skip pack animations" turns itself off after a visit to an R152 server

- **Where:** `src/ReplicatedStorage/SettingsConfig.lua:1`. R153 adds `SkipCutscenes` to `Defaults`, but R152's `SettingsConfig.Read` keeps only the keys it knows, and R152's `PremiumProgress.Decode` (line 70 at `e36b71b`) runs `result.Settings = SettingsConfig.Read(result.Settings)` on load.
- **Scenario:** a player turns the setting on (R153), then joins an R152 server. The setting is dropped at load, and the next save on that server (any progress marks the profile dirty) writes Settings without it. Back on R153 it is off again.
- **Confidence:** read in code: the R152 `Read` loops over its own `Defaults` only, and R152's Decode applies it on load.
- **Fix:** accept it as rollout noise, or mirror the toggle into an optional `Premium.Settings153` field that R152 leaves alone (the same idea as `Later153`).

### L3. During the rollout, R153's BIGGEST FRUIT writes delete R152's shared BEST PULL TODAY record

- **Where:** `src/ServerScriptService/ChestChaseServer/HubDisplayStore.lua:89`. The transform rebuilds the document with `Rules.StoreDoc(Rules.CleanDoc(old))`, and `CleanDoc` drops `pull` (`HubDisplayRules.lua`, CleanDoc).
- **Scenario:** while R152 servers still share a `pull` in the day's MemoryStore key, every better fruit written by an R153 server deletes it. Each R152 server then shows only its own pull until it rewrites the record (it is `Unsynced` again), which adds extra MemoryStore writes. The R153 owner command `hubdisplays reset` deletes the whole key, R152's pull included.
- **Confidence:** read in code.
- **Fix:** for the rollout, have `Merge` copy `old.pull` through untouched: `local out = Rules.StoreDoc(doc); if type(old) == 'table' and old.pull ~= nil then out.pull = old.pull end`. Remove that once no R152 server remains.

### L4. The day-7 login Void Pack is free and giftable, against R152's rule against alt farming

- **Where:** `src/ServerScriptService/ChestChaseServer/DailyProgress.lua:47-49`. The comment says "a normal giftable pack (no GiftLocked: that is only the free giveaway's)".
- **Scenario:** an alt logs in on 7 different UTC days (missed days only pause the week), claims a free Void Pack, and gifts it, unopened, to the main account. That is one Void per alt per week. R152 already had a free giftable pack on day 7, but it was a Mech pack, and R152 locked the giveaway Void for exactly this alt pattern.
- **Confidence:** proven on the mock: the day-7 claim gives `EclipseReliquary` stage 7 with `GiftLocked=nil`.
- **Fix:** an owner decision. If free Void Packs should not travel between accounts, set `pack.GiftLocked = true` in the `void` branch, together with the M2 fix so the seed keeps the lock too.

---

## Areas checked and found clean (18)

1. **Profile v22 and R152 compatibility for the clover**
   - `PremiumProgress.Pack` runs on a deep copy (`gardenClonePremium`), never on live data.
   - `Unpack` puts the known late keys back and keeps unknown ones in `Later153`, so a newer server's data survives.
   - No other save path skips `Pack`; the only save is `_buildSaveData`.
   - R152 rejects unknown `Entitlements` keys but keeps the unknown `Later153` field, so nothing is kicked or lost.
2. **Save and load mechanics**
   - `UpdateAsync` with the head compare and the commit-id retry guard.
   - The `FinalizePlayer` loop until clean, and the `Shutdown` deadline.
   - A grant that lands after a player's final BindToClose save is unsaved on both sides (pack and claim, gems and entitlement), so it is consistent.
   - The seed-gift inbox is written only after the sender's save.
3. **Daily quests**
   - The 2-gem cap holds through R140, R141 and R153 claims, and through the R152 round trip: never paid twice.
   - `ClaimBonus` queues the gems before setting its marker.
   - Every claim is non-yielding: no double grants.
   - A full Bag refuses the claim and the quest stays claimable.
   - The `{Quest=n}` index check rejects NaN, inf and non-integers.
4. **The daily pack pool**
   - `PickPack` re-rolls the Void; `PoolStages` covers stages 1-7 only, so Mech and Verity never come up.
   - The pool is clamped to the treadmill tier.
   - The pack in the inventory is checked after `AddChest`, which avoids double grants when a hook throws.
   - The day-7 Void rolls its size with the size pity.
5. **Clover Gem purchase**
   - The balance and ownership are checked again after the `UserOwnsGamePassAsync` yield.
   - A second or concurrent purchase is refused.
   - A gift arriving at the same moment becomes a credit.
   - Id 0 still sells for Gems.
   - The PassGift outbox and inbox stay correct across an R152 visit, since unknown pass keys are skipped there.
6. **Luck stacking**
   - The best boots × `PassLuck`, clamped to `MaxLuck` (50M).
   - Owner test boots still mark pulls as TEST.
   - The attribute listener refreshes only after load (`OwnedBoosts` guard), and there is no owner command that sets pass attributes.
7. **Index gem halving**
   - The backpay shown equals the backpay claimed (`HalveGems`, at least 1); the claim clears the backpay before it can repeat.
   - Verity is 50 and Mech is 50; the backpay validation range is unchanged.
8. **BEST PULL per-server windows**
   - No MemoryStore, MessagingService or DataStore traffic for pulls.
   - The window reset empties all three slots.
   - The old rig is destroyed when a silhouette or the next champion replaces it.
   - Stale build generations are discarded.
   - Test, tainted and owner-injected pulls are excluded.
   - Bookkeeping is bounded: weak keys, a 12-entry description cache.
   - Note: the `Step` loop is not wrapped in `pcall`; I found no input that makes it throw.
9. **HubDisplayAvatarReport**
   - Every field is type-checked, NaN and inf are clamped, the dance id must be on the whitelist.
   - At most 20 reports per player per 10 s.
   - The table has weak keys and the handler is wrapped in `pcall`.
10. **Hotbar server side**
    - `HoldLog` is bounded to 12 lines and weak-keyed.
    - `bounce` only moves a tool that is still in the hand.
    - The `_finishOpening` hand-off goes only into an empty hand.
    - No new remote.
11. **Training during a reveal**
    - The training busy check covers the chase only (`Runs` / `Starting` exist on the concurrent service).
    - Garden and upgrade checks are unchanged.
    - `TreadmillBonusService` is byte-identical to R152.
12. **Trampoline**
    - The client only sets the vertical speed (108.5 studs/s, about 10.8 studs per 0.1 s sample). MovementGuard allows at least 25 studs per sample, so a bounce never triggers a correction.
    - A body moving up faster than 20 studs/s cannot bounce again, and there is a 0.45 s cooldown: bounces cannot stack.
    - The horizontal speed is unchanged, and the map barriers are 1,024 studs tall.
    - The server: the asset is sanitised, there is a 400-part cap, a 15 s load timeout, one load per server, and the original model is never placed.
13. **Track holes with swept catch**
    - The path is checked exactly against the hole's circle and the height band; NaN and inf positions are ignored.
    - Every server teleport during a run resets the path (it bumps `MovementResetSerial`): fast travel, the economy teleport, the garden landing, the keeper refresh return, the obby start, and MovementGuard's own corrections.
    - `FloorSafety86` moves the player only in Y.
    - The per-player path record is weak-keyed and cleared each step.
14. **VoidGiveaway152 counts**
    - The reservation is one atomic `UpdateAsync` with a hard cap of 500.
    - An "owed" player's grant is idempotent; the grant does not yield.
    - The count only goes up.
15. **Seed rarity: shown odds against real rolls**
    - All 54 pullable seeds have a fixed chance.
    - It is display only: announcements still go by rarity tier, and the BEST PULL ranking still uses the real chance.
    - The announcement odds bound (1e15) fits 1/1T.
    - The Void display is luck-independent, like the Void roll.
16. **Garden bed ramps**
    - They lie under the soil, so planting's clear-view rays never cross them.
    - They are not in MovementGuard's barrier list, and `FloorSafety` does nothing on them.
17. **Startup and requires**
    - All 11 new files are in `MANIFEST.tsv`.
    - No server `require` names a missing module.
    - New services start inside `pcall`: a failure is logged and the server keeps running.
18. **Rate limits and type checks on the touched remotes**
    - `PremiumRequest`: SecurityGate plus the per-action gaps.
    - `TreadmillBonusRoll`: no arguments and a 1 s cooldown.
    - `TrackHole`: finite aim only.
    - `HubDisplayAvatarReport` is listed above.
