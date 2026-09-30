# R113: BASE / TRACK teleport buttons + performance and bug sweep

Base: R112 as exported under `src/`. Nothing here was run in Roblox Studio. Everything was checked offline
with the Luau CLI, the Roblox mock in `tools/tests/roblox.luau`, the HUD harnesses and luau-lsp.

## 1. BASE / TRACK buttons

### Design
- Two square HUD buttons next to the MENU hub: **BASE** (house icon, green) and **TRACK** (start-flag icon, orange).
  Styled with `BrightUI.Button` like the hub; caption uses the hub's caption scale. Icons are new `Home` / `Track`
  kinds in `VectorIcons91` (Frame-drawn, no asset IDs).
- Size 56 px on PC, 52 px on touch (the layout can fall back to 48 / 44; none of the 26 test screens needed it).
- Placement comes from `HudLayout.Read(...).Travel` (new field): the first spot that clears every HUD box by 6 px:
  1. a row directly **below the hub** (never under the wheel), else
  2. a column below the hub, else
  3. a row **right of the hub** (`UnderWheel=true`: the pair hides while the wheel is open, since the wheel
     options open there), else a column right of the hub.
  Boxes checked: hub, 3 wheel options, hotbar + details strip, 3 wallet rows, status panel, phone thumb zones
  (real touch controls when present), PC owner-tools tile. New helper `HudLayout.HudBoxes(m,w,h,wheel)`.
- The pair also hides while a modal is open (`SeedMenu`), on the title screen (`TitleActive`), and while the
  tutorial card reaches down to it (`TutorialCardBottom + 6 > Travel.Y`, only happens on small phones).
  ScreenGui `DisplayOrder=24`, below the tutorial (25) and the hub (33), `CoreUISafeInsets`.
- Cooldown: server sets player attributes `FastTravelReadyAt` (server time) and `FastTravelCooldown`; the buttons
  show a draining shade. The shade is full while carrying / on the treadmill / ragdolled. The RenderStepped
  connection exists only while a cooldown drains.

### Server rules (`FastTravelService`, all server state; the client can fire the remotes directly)
Remotes: existing `RequestBaseTeleport` (BASE), new `RequestTrackTeleport` (TRACK). Both go through
`SecurityGate.Allow(player,'FastTravel')` (default 6/s, burst 10) before any work. Refused (with a short notice) when:
- carrying a pack: `Chase:IsPlayerBusy`, `ChestChaseSeedCarrying`, `ChestChaseRunActive`, `ChestChaseQueued`
  (this is also the tutorial "run home" step, which only exists while carrying, so TRACK/BASE cannot skip the chase);
- ragdolled / flung / `PlatformStand`;
- training on the treadmill (`Bases.TrainingSessions`) or root anchored;
- opening a pack (`ChestService:IsOpening`);
- seated; dead / no character (silent);
- TRACK only: while biomes refresh (`Map.Refreshing`, the entrance wall is up). BASE still works then;
- cooldown `Config.FastTravelCooldown` (4 s, unchanged), shared by BASE and TRACK.
Other tutorial steps (steal, open, plant, tips) are not affected by a teleport: BASE/TRACK only move the player,
and the tutorial arrow re-targets from wherever the player is.

Targets:
- BASE: `record.Spawn.CFrame * CFrame.new(0,4,0)` (same as the old BASE [V] path and respawn).
- TRACK: `X = BaseBoundaryLine.X`, `Z = max(line.Z + line.Size.Z/2, Config.BiomeTrackStartZ) + 12`, Y = ground
  (short ray from line.Y+8 down 40, map only, so arches/banners cannot catch it) + 4, facing +Z (down the track).
  From the saved map: line at Z -99.28 (thickness 1), `BiomeTrackStartZ = -100`, Forest ground top Y 4, so the
  player lands at (0, 8, -86.78), 12 studs inside the Forest start, in the middle of the 180-wide track.

MovementGuard: after `PivotTo` the service calls `MovementGuard.Reset(player, 0.6)` (new optional grace argument,
default stays 0.25 for every other caller). The longer grace keeps in-flight client positions from before the jump
from becoming the baseline and then being "corrected" back to.

## 2. Performance / bug sweep

### luau-lsp over all 427 R112 scripts (`analyze`)
162 TypeErrors + lints, all triaged as noise, none fixed:
- `Key 'X' not found in table` (110): fields assigned after construction (e.g. `MovementGuard` `M.Config`,
  `HudLayout` nav `state.Metrics`, viewport job tables). Runtime-safe.
- `number?` / literal-union comparisons (`KeeperSleep`, `ChaseService:1447`), `Unknown require ServerStorage/ApprovedPlantMeshIndex`
  (not exported), `SpecialPackArt89:80` extra arg to a 0-arg local (ignored), `GardenViewState:9` nil table init.
- Duplicate-function lints (`ChaseService.Start`, `Config.Validate`, `SeedPackRules.SeedOdds/Roll`) are deliberate wrappers.
- `OwnerUpdateCommands82:165,171` `a[1]=='off' and nil or tonumber(a[1])` works only because `tonumber('off')` is nil (harmless).
Changed files: **no new findings** (diffed against the R112 tree, line numbers ignored).

### Fixes made (small, no gameplay numbers touched)
| File | Before | After |
|---|---|---|
| `StarterPlayerScripts/EconomyClient.client.lua:704` | `workspace.DescendantAdded` scheduled a `task.defer(bindGardenPrompt, item)` for **every** instance added anywhere in workspace (pack art, plant parts, effects, characters), and the deferred call then discarded everything that is not a ProximityPrompt. | Class check first; only ProximityPrompts are deferred. Same bindings, no scheduler churn when effects/plants spawn hundreds of parts. |
| `StarterPlayerScripts/GiantVisualSafety.client.lua:22` | Every 0.06 s, up to 320 tagged giant parts each got `LocalTransparencyModifier=` and `SetAttribute('GiantSafetyFade',…)` even when nothing changed: up to ~640 property/attribute writes per pass, ~10k/s. | Writes only when the fade value changed or the part's modifier differs from it. Far-away parts (the normal case) cost two reads. Same visible result. |
| `ChestChaseServer/BaseService.lua:475` | While training, the server set `TreadmillGainPerSecond` every Heartbeat for every training player. | Set only when the value changes (matches the pattern used for `PhysicalWalkSpeed` in the same file). |

### Findings not fixed (proposal only)
1. `StarterPlayerScripts/StudioTestClient.client.lua:156` - noclip runs `character:GetDescendants()` every
   `Stepped` while enabled (owner/Studio only). Proposal: cache the parts on enable and track `DescendantAdded`.
2. Teleport race on other paths: `EconomyService.lua:301` (station), `BaseService.lua:250` (respawn),
   `ChaseService.lua:1492`, `ConcurrentKeeperService.lua:549/643`, `OwnerUpdateCommands82.lua:125` still use the
   0.25 s grace. If Studio shows rubber-banding after those teleports under latency, pass `Reset(player, 0.6)` too.
3. `EconomyService` station travel keeps its own cooldown table, so BASE -> station within 4 s is possible.
   Proposal: share `FastTravelService.LastTravelTime` (not changed: station travel is not part of this task).
4. `EconomyClient.client.lua:216` polls `GetPendingSales` every 5 s per client (server rate-limited to 2/s).
   Proposal: push a `PendingSalesRevision` attribute and only invoke when it changes.
5. `BaseService.lua:512` training/stabilizer Heartbeat is O(players) per frame by design (velocity clamp must be
   per frame); fine at the server's player cap, noted for scaling.
6. Keeper/Beast code (`ConcurrentKeeperService`, `KeeperSleep`, `ChaseService` guardian loops) was not reviewed (other agents).
Everything else checked was already throttled (0.05-0.25 s accumulators), bounded (queues/caps), and cleaned up on
`PlayerRemoving` / `Destroying`; every RemoteEvent/RemoteFunction handler goes through `SecurityGate` or its own cooldown.

## 3. Files
Changed: `ServerScriptService/ChestChaseServer/FastTravelService.lua`, `.../MovementGuard.lua` (optional grace arg),
`.../BaseService.lua` (attribute guard), `ReplicatedStorage/HudLayout.lua` (`Travel` field, `HudBoxes`),
`ReplicatedStorage/VectorIcons91.lua` (`Home`, `Track`), `StarterPlayerScripts/EconomyClient.client.lua`,
`StarterPlayerScripts/GiantVisualSafety.client.lua`, `src/MANIFEST.tsv` (+1 row), `tools/tests/hud_overlap_harness.luau`.
New: **LocalScript `TravelButtons`** in `StarterPlayer/StarterPlayerScripts` (`TravelButtons.client.lua`);
new remote `ChestChaseRemotes/RequestTrackTeleport` (RemoteEvent, created by the server at start);
test `tools/tests/test_fast_travel.luau`.

## 4. Tests (offline)
- `test_fast_travel.luau`: **52 checks, all pass**. Real `FastTravelService`, `MovementGuard`, `SecurityGate`,
  `HudLayout`, `VectorIcons91`, `TravelButtons` on the mock. Button click -> remote -> server -> teleport; TRACK
  lands at (0, 8, -86.78) facing +Z; BASE lands at spawn +4; cooldown refusal + notice + shade; refusals for
  carrying (both signals), ragdoll, fling, treadmill, pack opening, refresh (TRACK only), dead, seated; BASE allowed
  during refresh; SecurityGate rejects spam; no MovementGuard correction after either teleport, while an
  unexplained jump of the same size *is* corrected (control); visibility rules (wheel, modal, title, tutorial card).
- `hud_overlap_harness.luau` (now includes the two buttons, owner tools, >=44 px check): **0 overlaps** on all
  26 screen sizes, touch with and without controls. A deliberately shifted pair produces 75 overlaps (harness is live).
- `test_guide_layout.luau`: ALL PASS (tutorial card placement unchanged). `test_tutorial.luau`: 498 checks, 0 failures.
- `luau-compile` on every changed file: OK. luau-lsp: no new findings.

Run: bundle as described in the header of `test_fast_travel.luau`, then `/opt/luau/luau test_fast_travel.luau`.

## 5. Studio checks
1. PC 1280x720 and 1920x1080, phone emulators (iPhone SE landscape/portrait, iPad): pair beside/below MENU, never
   over wallet/hotbar/status/thumbstick; hides while the wheel is open when it sits right of the hub.
2. TRACK from the base: land centred just past the line in the Forest, facing down the track, no rubber-band.
   Repeat with Network > Incoming Replication Lag 0.3 s.
3. BASE from deep in a biome: land on own spawn. Try both during cooldown, while carrying, on the treadmill,
   ragdolled, and while opening a pack: refused with a notice.
4. TRACK while biomes refresh: refused; BASE works.
5. New player tutorial: step 1 TRACK works; while carrying (run home) both are refused; the card stays readable
   on a small phone (pair steps aside).
6. Output: no `[Artwork]`/script errors; MovementGuard `Corrections` stays flat after teleports.
