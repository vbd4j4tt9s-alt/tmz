# R158i - the free tutorial roll for real, and a 20,000 speed start that reads as 1

Two owner requests. No model names, ProfileVersion stays 22, `Config.Version` is not touched here.

## 1. The free bonus roll at the end of the tutorial

**Why players did not get it (R158h).** The roll was only given when the player's own screen *asked* for it
(a `BonusGift` request) as the BONUS ROLL arrow started. That fails in three ways:

1. The request goes through the Tutorial throttle (one request per 0.2 s) and the request gate. If the ask landed right
   after another Tutorial request it was refused, and the screen never asked again (it sent the ask once and forgot it).
2. A new player already holds **2 ready rolls** from the new-player gift (R158d). The game never holds more than 2, so the
   free roll was "given" as +0, and the once-only flag was spent. The player saw nothing new.
3. If the bonus service was not wired yet or threw, the flag was still spent.

**The fix (server only, no request).** The moment the tutorial's published step becomes 10 (right after the sale, or when a
player loads already on step 10), `PublishTutorial` calls `TutorialBonusGift`, which asks
`TreadmillBonusService:GrantGift`. Once per player (the saved `Bonus` flag). The flag is set only if the roll was really
given, so a not-ready service or an error is simply tried again on the next publish.

* Room for it (fewer than 2 ready): +1 **ready** roll at once, also kept as an unused gift roll so a rejoin does not lose it.
* Already 2 ready: the roll **waits** (picked the simple option: a waiting roll, not a higher cap). It is saved
  (`Premium.BonusGiftPending158i`, an optional field) and becomes ready the moment one roll is spent, so the player can
  use 3 rolls in all (2 + the free one), never a fourth. After a rejoin a waiting roll comes back as a ready roll.
  Nothing about the caps, the odds, the 6-minute timer or the client's "2 ready" display changed.
* The client no longer asks. The BONUS ROLL arrow still stays until a roll is used or 15 s pass. "Used" now also counts a
  new server counter (`TreadmillBonusRolled`), because with a waiting roll the ready number does not go down when one is used.
* The old `BonusGift` request still works on the server (harmless: step 10 only, once per player) for clients that have not updated.

## 2. New players start at 20,000 speed, shown as 1

* `Config.SpeedFloor = 20000`, `Config.DefaultSpeed = SpeedFloor`. A new profile starts at 20,000 speed **points**; an older
  profile below 20,000 is raised to 20,000 when it loads (and saved). The walk speed still comes from the real points
  (20,000 points walk at about 37.5). The speed curve itself (0 points = 24) is unchanged.
* **One shared rule: `ReplicatedStorage/SpeedDisplay`.** What a player reads is `points - 19,999`, never below 1
  (20,000 reads 1, 20,060 reads 61, 50,000 reads 30,001). Gains (+60 popups, "+N per step", the "+15K SPEED" bundles) are
  differences and stay as they are. Every comparison (keepers, walk speed, the save, the board's order) keeps using the real points.
* Screens that now use it: the HUD speed readout (`GardenWallet`), the player list cell (`PlayerDataService`), the hub's
  TOP SPEED board (`SpeedBoardService`), the keeper SPEED NEEDED signs (`KeeperSpeedLabels`) and the hub gate keys
  (`HubDecor151`, same number as the signs), and the owner / test commands (`/test stats`, `/test speed`, `training` show
  both numbers, "61 (20,060 points)"). A sign asking for up to 20,000 points reads **1** (the first two biomes' keepers used to read
  0, 510, 3,800 or 18K); a keeper that needs 91,501 points now reads 72K (was 92K); one that needs over a million reads almost the same.
* No treadmill upgrade sign, mystery pedestal or Index text shows a speed number, so none changed.

## Tests

`docs/proposals/R158e/tests/run_tutorial158e.sh` (server grants at step 10 with no ask, also when already holding 2, never
twice, a rejoin; client arrow; mutants), `docs/proposals/R158i/tests/run_speed158i.sh` (the shared rule, the HUD, a new and an
older profile, the player list; mutants), R147 `run.sh` (the sign numbers), plus the frozen-hash lists
(`R151/tests/frozen.sha256` Config line, `R150/tests/frozen.sha256` TreadmillBonusService line, both with an
"R158i (on purpose)" note).
