# Chest Chase (sap_F.rbxl) - project handoff

Written 2026-09-29 from a claude.ai chat session. Read "Status" and "How to work with me" first.

> **Checked against the uploaded place file on 2026-09-29 (Claude Code session):**
> `Config` has `Config.Version='V149 R107'`, `ProfileVersion=20`; `BiomeExpansionConfig` no longer contains the
> R45 block and has the R109 comment; `ServerStorage/ChestChase_R109_PackFix_Backup` exists. So the R109 pack fix
> is installed and saved. `ChestChase_R108_TutorialMovementRarity_Backup` exists; R108 changes are not in the live
> `Config`. Nothing was run in Studio.

## How to work with me (the owner's preferences)

- Delivery style that has worked: one paste-into-Command-Bar script (Edit mode, Play stopped) with a **backup and an undo**. After installing: save, then start a NEW Play session.
- Never ship code silently untested. Say plainly what was run, what was only reasoned about, and what could not be checked.
- Keep explanations short and plain. The owner types casually and wants results, not theory.
- Roblox Studio is the only place the game runs. Nothing here has been run in Studio by the assistant.

## Status (as of this note)

| Item | State |
|---|---|
| Live scripts | **R107** (`Config.Version = 'V149 R107'`, `ProfileVersion = 20`) |
| R108 (tutorial / mobile HUD / movement / rarity) | Backup exists in `ServerStorage/ChestChase_R108_TutorialMovementRarity_Backup`, state `Undone`. Not currently applied. |
| Packs spawning outside the map (Forest biome) | **Fixed** (owner reported it fixed after applying the R109 pack-fix paste script below). Root cause verified by running the real code in Lua 5.4. The paste script itself was not run by the assistant. |
| R109 safety-net clamp in `ChestService` | Drafted, **untested, not shipped** (see "Optional / untested") |
| `R109_polish_snippets.lua` | Untested snippets from a code review of R108; not an installer |

## Game in one paragraph

Players steal "packs" (seed packets) from biome camps guarded by keepers, run them back to their base, open them from the hotbar, plant the seeds in a garden, harvest, and sell at a market. A treadmill trains speed. Boots add pack luck. There are 7 biomes; the proximity prompt on packs says STEAL.

## Repo layout (inside the .rbxl)

- `ServerScriptService/ChestChaseServerMain` (Script) plus `ServerScriptService/ChestChaseServer/*` (~58 ModuleScripts): `Config` (~188 KB), `ChestService`, `ChaseService`, `MapService`, `PlayerDataService`, `BiomeExpansionConfig`, `TrackExpansion83`, `ForestLayout87`, `FloorSafety86`, `VeiledEvent81`, `OwnerUpdateCommands82`, `MovementGuard`, etc.
- `ReplicatedStorage` (~316 children): shared modules such as `RouteBalance83`, `BalanceValues81`, `PackOdds81`, `HudLayout`, `KeeperMotion`, `BeginnerGuide`, `SeedPack*` art.
- `StarterPlayer/StarterPlayerScripts`: `BeginnerTutorial`, `RunnerController`, `SeedPackClient`, `ChestIndex`, etc.
- `Workspace/ChestChaseMap`: folders `Obby`, `Seeds` (35 pack slots), `GuardianEncounters` (7 keeper camps), `Bases`, `Lobby`, `InvisibleMapBarriersV071`, ...
- `ServerStorage` holds a huge archive of old backups (~115,000 instances, mostly `SeedHeistScriptBackups`). Do not diff against it blindly.
- Script sources use LF line endings and contain non-ASCII bytes (biome emoji in `Config`). Patch by **bytes**, not characters.

## Map geometry and startup order (matters for any position bug)

- Biome stage IDs are stable; physical order is `BiomeOrder = {1,6,2,3,4,5,7}` = Forest, Jungle, Desert, Snow, Lava, Crystal, Storm Peaks.
- **The saved file holds the old geometry** (biome lengths 225 / 270 / 292.5 / 315 / 360 / 405 / 450, `BiomeTrackEndZ = 2217.5`). At every server start `TrackExpansion83` stretches it to lengths `{1:180, 6:450, 2:650, 3:850, 4:1050, 5:1300, 7:1600}` (track ends at Z = 5980). It asserts the saved end is 2217.5, so **do not save the map after a runtime expansion.**
- Biome ground is 180 wide (X +/-90). Solid walls span |X| 89 to 94; invisible barriers are at 92.5.
- Startup order: `Config.lua` runs `BiomeExpansionConfig` (line ~700), then at the very end `RouteBalance83.ApplyConfig(Config)` (line ~741). `MapService.new` applies `TrackExpansion83`, `ForestLayout87`, `RouteDress84`, `FloorSafety86`. Then `ChestService:Start` calls `PrepareMythicBiomes`, which sets each slot's `PackHome` from `Config.MythicEncounters[stage].Seeds` and pivots the models there. `RefreshWorldPack` then places packs at `PackHome` X/Z with Y snapped to `BiomeGround_N`. X/Z are never range-checked.

## The pack-outside-map bug (fixed)

**Symptom:** packs sitting beyond the map edge; a STEAL prompt showing at a wall (prompts have `RequiresLineOfSight=false` and 24 stud range).

**Cause:** the Forest camp was mirrored to the +X side twice.
1. `BiomeExpansionConfig` had an "R45" block that moved the Forest camp to home `{70,8,66}` and mirrored its 5 packs.
2. `RouteBalance83.ApplyConfig` (runs later) mirrors again with `p[1] = 64 - (p[1] - e.Home[1])`, assuming `Home[1]` is still -70.
3. Result: Forest pack X = 79.2, 94.4, 100, 94.4, 79.2. Three of five are past the wall.

**Fix:** delete the R45 block (final camp home stays `(64,8,0)` yaw 90 either way; only the pack X values change).

**Verification done (Lua 5.4 via ctypes, real script sources from the .rbxl, mock `Config`):**
- Before: Forest X = 79.2 / 94.4 / 100 / 94.4 / 79.2.
- After: Forest X = 48.8 / 33.6 / 28 / 33.6 / 48.8, Z = 32.6 / 19.3 / 0 / -19.3 / -32.6.
- Independent cross-check: `ForestLayout87`'s rigid transform applied to the saved Forest slot models gives the same numbers to 0.1 stud.
- Stages 2 to 7 were already inside their biomes.

**Runtime check to run in Play (server view):**
```lua
for _, m in ipairs(workspace.ChestChaseMap.Seeds:GetChildren()) do
	if m:GetAttribute("Stage") == 1 then print(m.Name, m.Body.Position) end
end
```
Expect X between about 28 and 49.

**Install script (backs up first; refuses if the exact block is not found):**
```lua
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first.")
local BACKUP = "ChestChase_R109_PackFix_Backup"
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild(BACKUP), "Already installed. Run UNDO first.")
local folder = game:GetService("ServerScriptService"):FindFirstChild("ChestChaseServer")
local module = folder and folder:FindFirstChild("BiomeExpansionConfig")
assert(module and module:IsA("ModuleScript"), "BiomeExpansionConfig not found.")
local src = module.Source
local startAt = src:find("-- R45: cursor-side Forest camp", 1, true)
local _, endAt = src:find("camp.Home=home;camp.KeeperYaw=90\nend", 1, true)
assert(startAt and endAt and endAt > startAt, "R45 block not found. Nothing changed.")
local fixed = src:sub(1, startAt - 1)
	.. "-- R109: Forest camp is placed by RouteBalance83.ApplyConfig; the old R45 mirror put packs past the walls."
	.. src:sub(endAt + 1)
local backup = Instance.new("Folder"); backup.Name = BACKUP
local before = Instance.new("StringValue"); before.Name = "Before"; before.Value = src; before.Parent = backup
local target = Instance.new("ObjectValue"); target.Name = "Target"; target.Value = module; target.Parent = backup
backup.Parent = storage
module.Source = fixed
assert(module.Source == fixed, "Write failed")
print("[R109] Fixed. Save, then start a NEW Play session.")
```

**Undo script:**
```lua
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first.")
local backup = game:GetService("ServerStorage"):FindFirstChild("ChestChase_R109_PackFix_Backup")
assert(backup, "No R109 backup found.")
backup.Target.Value.Source = backup.Before.Value
backup:Destroy()
print("[R109] Undone. Save, then start a NEW Play session.")
```

## R108 (currently undone) - what it does

Installed with a hash-guarded installer; 12 scripts patched. Redo / undo:
```lua
require(game:GetService("ServerStorage").ChestChase_R108_TutorialMovementRarity_Backup.Installer)("install")  -- or "undo"
```
- **Tutorial:** "STEP n/8" label, gold-outlined card, "Getting your first pack ready..." loading state, a local arrow under the avatar pointing at the target, 8 rewritten steps (`BeginnerTutorial`, `BeginnerGuide`).
- **Mobile HUD (`HudLayout`):** 54 px buttons on short screens, wheel overlap avoidance, compact row on landscape screens under 300 px tall, wallet width formula.
- **Movement:** recover from `FallingDown` after a high-speed wall hit (`RunnerController` client, `MovementGuard` server).
- **Keepers (`KeeperMotion`):** exponential smoothing (rate 18), snap at gap > 60, `MaxPositionError = 2.5`.
- **Rarity (`BalanceValues81`):** new `SeedWeights` for all six packs (each sums to exactly 100, checked); `BootLuck` `{1.15,1.3,1.5,1.75,2}` -> `{1.25,1.75,2.5,3.5,5}`; luck clamped 1 to 5 in `PackOdds81`, `PlayerDataService`, `WorldStatusHud`, `OwnerUpdateCommands82`; `Config.Version = 'V149 R108'`.

**Review findings (not yet acted on):**
1. `RunnerController`: `AssemblyAngularVelocity = Vector3.zero` runs *before* the guardian-ragdoll/fling checks, contradicting its own comment; may cancel ragdoll spin.
2. Tutorial can stay on "Getting your first pack ready..." forever if the server never sets `TutorialStep`/`TutorialDone`. Needs a timeout.
3. Tutorial arrow is computed in camera space, so it drifts at steep camera pitch. Use a bearing difference instead.
4. `HudLayout` compact wheel: offsets look like they put the row at the top edge (Y = 0), not beside the hub as the comment says. Verify on a short landscape emulator.
5. Luck cap 5 is hard-coded in 5 places; make `BalanceValues81.MaxLuck` the single source.
6. `WorldStatusHud` clamps luck without a nil/NaN guard (`PackOdds81` has one).
7. `bestLuckMultiplier` is persisted in player data and boot values changed; check that existing saves migrate (`ProfileVersion` 20 was already the value in R107).
8. Server-side `Humanoid:ChangeState` on a client-owned character may have no effect (unverified; the client copy is the one that matters).
9. The rarity/boot changes shift real gameplay odds. Simulate effective post-luck odds before shipping.

`R109_polish_snippets.lua` (in the earlier chat outputs) has drop-in fixes for items 1, 2, 3, 5, 6 and a per-pack "weights sum to 100" assert. All untested.

## Optional / untested: safety-net clamp in `ChestService.PrepareMythicBiomes`

Idea: after `local position = artVector(encounter.Seeds[seed.SeedIndex])`, clamp X to +/-(FieldWidth/2 - 24) and Z to `[BiomeStartZ_n + 8, BiomeEndZ_n - 8]` (map attributes set at runtime by `TrackExpansion83`), `warn()` if it moves anything, so a future config mistake cannot put a pack outside its biome. The patch applied cleanly to the source, but the Lua test failed only because the mock lacked `artVector`, so it is unproven. Test it before shipping. Note `FindPackPlacement` also has a quirk: `self.Drops` is never assigned, so dropped packs take the "own slot" branch (Y from the origin stage's ground, X/Z unchecked).

## Hash-guarded installer format (R107/R108 style)

- Outer script: base64 patches `{offset(1-based), bytesReplaced, base64}` per script (applied in descending offset order), plus SHA-256 and byte length of every script before/after, plus the engine ModuleScript source (base64) and its SHA-256.
- It refuses to run unless every script matches the expected "before" hash, applies patches in memory, checks the "after" hash, creates `ServerStorage/<name>_Backup` (folder `Sources/NN` with `Before`, `After`, `Target`, plus a `ModuleScript` `Installer`), then writes through `ScriptEditorService:UpdateSourceAsync` with verification and rollback. `Installer("install"|"undo")` is re-runnable and idempotent.
- **Any change to a patch changes the after-hash**, so a new revision needs the real source scripts to recompute hashes. The exact R107 sources are inside `sap_F.rbxl`.
- Known nits: the "[Mobile HUD]" message prefix is stale; the `IsRunning` assert could run before the heavy hashing; pure-Luau SHA of the 188 KB `Config` takes a few seconds.

## Tooling notes (what worked for reading the .rbxl)

- `sap_F.rbxl` is the **binary** format. Chunks (`INST`, `PROP`, `PRNT`, ...) are **zstd**-compressed (magic `28 b5 2f fd`), not LZ4. Python had no zstd module; system `libzstd.so.1` via `ctypes` worked. Values are byte-interleaved; int32s are zigzag encoded, referents are also delta encoded. (Now in `tools/rbxl.py`.)
- Lua 5.4 (`liblua5.4.so.0`) via `ctypes` was used to run real script sources. Shims needed: rewrite `+=`, define `table.clone`, `math.clamp`, `math.sign`, mock `game` / `require`. Luau-only syntax such as `continue` is not covered.
- A better long-term setup is keeping scripts as `.lua` files in a folder with a sync tool such as Rojo, which would remove the paste-into-Command-Bar step. That is general knowledge, not verified in this session.

## Open questions for the owner

1. Why was R108 undone the first time? If something broke or felt wrong, fix that first.
2. Reinstall R108 exactly as it was, or ship a polished version with the review fixes above?
3. Add the `ChestService` safety-net clamp (after testing)?
4. Was the screenshot taken in the Forest biome? (Unconfirmed; it is consistent with the bug.)
