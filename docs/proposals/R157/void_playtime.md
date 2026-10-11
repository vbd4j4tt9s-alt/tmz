# R157: the free Void Pack needs 20 minutes of play

Owner: "make it so that the void pack is only claimable after playing for 20 minutes".

## What a player sees
- Under 20 minutes played: the prompt on the pedestal is off, and the small line under the "left" number reads
  **play 12 more min to claim** (whole minutes, rounded up; it changes once a minute).
- At 20 minutes the line goes (the old "LIMITED! 1 PER PLAYER" is back) and the prompt works as before.
- Players who already claimed see what they saw before ("CLAIMED ✓"). At 0 left nothing changes.
- A press that gets through anyway (a changed client) is refused by the server: **play 12 more min to get your free void pack!**

## How it works
| Piece | Where |
|---|---|
| The rule: `Rules.MinPlaySeconds = 20*60`, the field name, the cap (3 h), the two texts, the minute math | `ReplicatedStorage/VoidGiveawayRules152.lua` |
| The count, the refusal, the attribute, the owner tools | `ServerScriptService/ChestChaseServer/VoidGiveaway152.lua` |
| The line and the prompt | `StarterPlayer/StarterPlayerScripts/VoidGiveawayClient152.client.lua` (line 1, the load guard, is untouched) |
| `/test playtime` wiring and parsing | `OwnerUpdateCommands82.lua`, `OwnerCommandTargets82.lua`, `StudioTestHelp.lua`, `docs/COMMANDS.md` |

- **Saved field:** `Premium.PlaySeconds157`, whole seconds of TOTAL play across visits, counted up to 3 hours. It is an optional field
  of the saved Premium table: `ProfileVersion` stays 22, an old save has no field and reads as 0, and an older server copies the field back
  unchanged. `Config.lua` is not touched; `PlayerDataService` and `PremiumProgress` are not touched either.
- **Counting:** the giveaway's existing 2 s loop (`Step`) adds the time since its last look (at most 5 s, so a hitch or a paused Studio is not
  play) for a player whose data is loaded. No new loop, nothing per frame. `MarkDirty` every 30 s (every 5 min after the 20), and
  `MarkDirty` + `QueueGardenSave` the moment the 20 minutes are reached. The final save on leaving writes the rest.
- **Attribute:** `VoidPlayLeft157` on the player = seconds still to play, rounded up to a whole minute (0 = open). No attribute = the counter is
  not loaded yet: the client shows and blocks nothing.
- **The refusal** is in `Claim`, right after the account-age check and before the busy flag and any reservation: no store request, no state
  change, no cooldown. A player the giveaway already reserved a pack for (**owed**) is never held up by it. A counter that is not ready
  gives the soft "your play time is still loading" (the same kind of answer as data that is still loading), never a number of minutes.
- **Studio without DataStore access:** the counter lives in memory with the profile; nothing is written and nothing warns.

## Owner tools
- `/test voidgift` also prints the play time (played, needed, left, and a note when the profile cannot save).
- `/test playtime @name` shows a player's time. `/test playtime @name 12` (or `playtime 12 @name`) sets it to 12 minutes (0 to 180): **Studio only**,
  a live server refuses. Use 19 to see the last minute run out.

## Tests
`docs/proposals/R152/tests/run_void_giveaway.sh` (server 15, real data 7, client 4b and 6, wiring, and 32 mutations: `ONLY=R157 ... mutate`).
Test players have already played 20 minutes unless a test says `Played = seconds` (or `false` for an old save).
