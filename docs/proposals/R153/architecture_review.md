# R153 architecture review: is the code in good shape, and what to improve (review only, no code changed)

Owner: *"evaluate game/code architecture what can we do to improve if its already good its ok"*. Also, earlier: *"the whole game in general is quite laggy"*.

Base: branch `claude/compassionate-brown-lohfok` at `12d4694` (R153 in progress; `Config.Version` still reads `'V150 R152'`). Nothing in `src/` was
changed. The lag audit (`docs/proposals/R153/lag_audit.md`) is used as a source and is not repeated here. Where this review touches lag, it explains
the structural cause and points to the audit's fix.

## In one minute

**The architecture is OK for now.** The parts that protect players are better than usual for a Roblox game of this size: the server decides
everything, every remote goes through one rate and shape gate, saves can't overwrite a newer save, Robux purchases are saved before they are granted,
and every release can be undone. Keep all of that.

What hurts is **150 releases of layers**. New work was added beside old work instead of replacing it, because files were frozen, hand-edited or
risky to touch. The result:

1. **About 75 scripts are dead, and about 700 lines of live files are shadowed.** 73 modules are never required by anything (4.5 MB, 44% of
   ReplicatedStorage's bytes, sent to every player at join). Another 563 lines of `ChaseService` and 131 of `ChestService` are replaced at load time
   by other modules. Shadowed code misleads people and agents. The R153 lag audit was misled by it once (see section 3, item 1).
2. **Owner test commands sit on the server's start-up path.** If the most-edited file in the repo (`OwnerUpdateCommands82`, 33 commits) fails to load,
   the whole server fails to start. Players then wait on a half-loaded game with no message.
3. **The server builds most of the world's visuals**: hub, market, treadmills, fences, gardens and pack art. A phone's quality tier can't shrink
   anything the server builds. This is the structural reason behind the lag audit's top cost (7,200 parts at the hub on every tier).
4. **Values are patched on top of patches.** The pack roll is defined 6 times in one file, each wrapping the last. Config sets its version 5 times. The
   map gets 9+ run-time passes. Frozen-hash tests keep it that way, because editing in place trips them.

None of this needs a rewrite. The plan in section 4 starts with cleanup that changes nothing on screen.

---

## How this was measured

- Scratch Python scripts over `src/` (deleted afterwards):
  - a file census;
  - a require graph (every `require(...)` plus module names used as strings, plus the one computed loader, `'PlantArt'..biome`);
  - reachability from the 77 Scripts / LocalScripts;
  - grep counts of frame hooks, remotes, attributes, `pcall` and `WaitForChild`;
  - method-override detection (the same `function X:Name` defined twice, or replaced by an `Install` / mixin module);
  - `git log` churn per file.
- Every "never required" family was then checked by hand (for example `SeedPackRenderer.lua:1-10` shows what replaced the old pack art).
- Nothing was run in Studio. The full test runner was not run. `sha256sum -c` was run on the frozen lists (all OK).
- Limits:
  - a module loaded through a computed name other than the one found would show as unreachable; the hand check covers the families listed;
  - a script outside the export (ServerStorage) could still require something. The installer's `--retire` parks objects with undo, so this is
    recoverable.

---

## 1. Map: the architecture as it is

### 1.1 Size

| Area | Scripts | Lines | Bytes |
|---|---|---|---|
| ServerScriptService (`ChestChaseServerMain`, `ApprovedPlantsBootstrap`) | 2 Scripts | 296 | 17 KB |
| ServerScriptService / ChestChaseServer | 96 modules | 21,967 | 1.5 MB |
| ReplicatedStorage | 401 modules | 38,722 | 10.3 MB (147 art-data modules = 8.3 MB) |
| StarterPlayerScripts + ReplicatedFirst | 75 LocalScripts | 16,552 | 1.08 MB |
| **Total** | **574** (2 Script, 75 LocalScript, 497 ModuleScript) | **77,537** | **12.9 MB** |

- About 452 files are code: 76k lines, 5.7 MB. The style is dense: 4,022 lines are over 200 characters and 704 over 400. About 122 files are data
  (7.2 MB on about 1,500 lines).
- Other counts:
  - require graph: 1,255 require edges; 1 real cycle (the pack renderers), and it is lazy (required inside functions, so safe);
  - 34 gameplay remotes plus 2 owner-test remotes;
  - 22 client → server handlers;
  - 868 server `SetAttribute` sites. Attributes are the main way state reaches clients.
- Per-frame hooks:
  - client: 76 sites in 54 LocalScripts, plus 27 in 25 shared modules. The lag audit counted **67 alive at the hub**;
  - server: 14 sites in 13 modules (lag audit Appendix B lists them, plus about a dozen timed loops).
- Hygiene:
  - 867 `pcall`, 288 of them with the result thrown away;
  - 0 legacy `wait` / `spawn` / `delay`;
  - 0 `--!strict` files.
- 91 code modules carry the release number they were added in (`NoticeFeed83`, `HubDecor151`, `KeeperFx152`...): 40 from R81–R99, 7 from
  R100–R139 and 44 from R140+, including 11 new ones in R153.

### 1.2 Server boot order (`ChestChaseServerMain.server.lua`)

1. **Guard** (`:19-30`): refuses a second enabled main script and sets `ReplicatedStorage.ChestChaseStartupState = "Starting"`.
2. **Load and check** (`:36-72`): `loadModule` requires each core module and asserts its exported functions. `Config.Validate()` runs.
   - Core modules: Config, NotificationService, MapService, PlayerDataService, LootToolService, BaseService, ChestService, ChaseService, StormService,
     FastTravelService, EconomyService, SpeedBoardService.
   - `ChaseService` is wrapped at load by `ConcurrentKeeperService` (`ChaseService.lua:1668`).
   - `ChestService` is patched at load by `GardenPlantRuntime` and `HarvestToolService` (`ChestService.lua:1165-1166`).
3. **Construct** (`:85-118`), in dependency order: notifications → map (MapService runs the map passes, `MapService.lua:82-134`) → player data → loot
   tools → bases → chests → chase → storm → speed board → fast travel → economy.
4. **Extras** (`:120-135`):
   - not guarded: FruitGiftService, GamePassService, PremiumService, SocialService, MysteryPackService;
   - guarded by `pcall`, so a failure never stops the server: VerityService, PullAnnouncer, HubDisplayService, VoidGiveaway152.
   - Then MovementGuard.
5. **Start** (`:137-173`):
   - busy checkers; `chestService:Start`, WeatherService, FruitOfHourService, GardenTypography;
   - `chaseService:Start`, which **also starts the owner test commands** (`ChaseService.lua:1669-1673`);
   - storm, TrackHoleService, fast travel, economy, speed board, treadmill training, TreadmillBonusService;
   - the services are handed to `chaseService` for the owner commands (`:170`); then autosave and `ResetCourse`.
6. **Players** (`:185-256`): `PlayerAdded` (prepare → assign base → character hooks → `PlayerData:Load` → per-service setup) and `PlayerRemoving`.
   Then two `BindToClose` handlers (`:258-265`), and the state becomes **"Ready"** (`:267`).
7. **In parallel:** `ApprovedPlantsBootstrap.server.lua` runs the EditableMesh bakes: fruit meshes, the Verity pouch, pack shapes, the R152 keeper
   models and the approved plant meshes. Each is in its own `pcall` and falls back to part-built art if it fails.

### 1.3 Client landscape (75 LocalScripts, each started on its own)

| Group | Scripts |
|---|---|
| HUD / menus (27) | Hotbar, EconomyClient, ChestIndex, GamePassClient, DailyRewardsClient, SettingsClient, LeaderboardClient, TravelButtons, BeginnerTutorial, TreadmillBonusClient, MysteryPackClient, VerityClient, FruitGiftClient, PlantInspection, StudioTestClient; notices: NotificationClient83, HudNotices, BiomeEntryNotifier, OfflineGrowthNotice, PurchaseCelebration, SpeedGainPopup, ChestRunAlert, PullAnnouncerClient, InteractionFeedback, ButtonFeedback; no-ops: SpeedMilestones87, ColourfulText81 |
| World / biomes / hub (18) | KeyboardTrack, WeatherWorld149, SnowBiome149, StormWeather, BiomeWeather, LavaFlow, BiomeAmbience, BiomePresentation, BiomeEffectGovernor, WorldEvents, TrackRefreshSky, HubLife151, HubDisplayClient, HubTrampoline153, VoidGiveawayClient152, FruitOfHourDisplay, HideBushClient, HomeMarker |
| Keepers / chase (10) | BeastAnimation, KeeperHitEffects, KeeperSpeedLabels, VeiledEventClient81, RagdollClient, BatClient, TrackHoleClient, CarryNameplate84, FlingSwoosh153, ChaseMusicTrim152 |
| Packs / garden (10) | SeedPackClient, SeedPackRender, PackOpeningFeedback, GardenVisuals, DistantGardens, GardenLiftPrompts, GardenShovel, HeldHarvests, GardenBonusSign84, MutationHighlights |
| Character (8) | RunnerController, RunnerTrailClient, RunnerTrailAura, ItemCosmetics, GiantVisualSafety, QuietFootsteps87, DefaultAvatarAnimations, TreadmillAnimation |
| Audio / title (2) | BackgroundMusic (hand-edited by the owner, never patched), TitleScreen (ReplicatedFirst) |

- 73 of the 74 StarterPlayerScripts start with the same **R152 load guard** line, which waits for `game.Loaded` (`Hotbar.client.lua:2`). The
  exception is the hand-edited BackgroundMusic.
- **24 scripts make their own ScreenGui**, with hand-picked `DisplayOrder` values from 23 to 10001.
- Shared client services:
  - `ClientFxBudget`: one quality tier, a singleton with 45 users;
  - `NoticeFeed83`: the single notice stack since R83;
  - `AudioMixer` and `SoundTiming` for audio;
  - `PropCache152` and `ViewCull152` for performance;
  - `CosmeticBudget` (keepers), `PlantDetailPlanner` (gardens).

### 1.4 Shared modules (ReplicatedStorage, 401)

| Kind | Modules | Size | Examples |
|---|---|---|---|
| Art data (tables of parts, vertices, pixels) | ~147 | 8.3 MB | `SeedPackArt*`, `ApprovedPlantArt1-21`, `PlantArt<Biome>`, `*SeedArt45`, `TreeReworkData1-12`, `MechPlantData`, `KeeperRigConfig`, `ArtworkFallbackData89` |
| World / visual builders | ~73 | 0.7 MB | `PlantVisuals`, `SeedPackVisuals`, `HarvestPresentation`, `KeyboardTrack`, `WeatherWorld149` |
| Rules / numbers / catalogs | ~57 | 0.4 MB | `SeedPackRules` (43 users), `PlantCatalog` (32), `BalanceRules`, `PackOdds81/112/137`, `DailyRewards`, `MechCatalog` |
| Effects / animation | ~45 | 0.45 MB | `KeeperFx` + `KeeperFx152`, `RarePullCinematic`, `RevealFlourish` |
| UI / HUD | ~45 | 0.35 MB | `HudLayout`, `GardenTextFit`, `BrightUI`, `ShopMenu` |
| Audio | 11 | 0.06 MB | `AudioMixer`, `InteractionAudio`, `LocalSfx`, `SoundTiming`, `RarePullAudio` |

### 1.5 Data and persistence

| Store | Kind | Written by | How |
|---|---|---|---|
| `ChestChasePlayerData_v1` (`_Studio_v1` in Studio), key `Player_<id>` | DataStore | PlayerDataService | load `GetAsync` (`:901-903`); save `UpdateAsync` with a commit-ID check (`:1321-1374`); autosave every 30 s if dirty (`:1408-1425`); final save on leave and at `BindToClose` with a 25 s deadline (`:1386-1446`). `ProfileVersion` 22 |
| `ChestChase_FruitInbox_v1`, `ChestChase_SeedInbox_v1`, `ChestChase_PassInbox_v1` | DataStore | FruitGiftService, PassGiftService | outbox in the sender's profile → recipient inbox via `UpdateAsync` → receipts / acks. Recovery every 60 s, on join and after a send |
| `ChestChase_Global_<Stat>_v1/v2`, `ChestChase_Global_Speed_Exact_v2` | Ordered DataStore + DataStore | SpeedBoardService | `SetAsync` on leave and periodically |
| `VoidGiveaway152`, key `Claims` | DataStore | VoidGiveaway152 | atomic `UpdateAsync` reservation (`VoidGiveawayStore152.lua:2`) |
| `PlantReady140`, `PlantReadySent140` | MemoryStore sorted maps | SocialService | "your plant is ready" queue and cooldowns |
| `HubDisplays151` | MemoryStore hash map | HubDisplayStore | BIGGEST FRUIT of the day (BEST PULL is per server since R153) |
| Topics `PullAnnounce151`, `VoidGiveaway152` | MessagingService | PullAnnouncer, VoidGiveaway152 | global pull lines (at most 1 per 5 s per server); claim-count sync |

### 1.6 Remotes (all in `ReplicatedStorage.ChestChaseRemotes`)

- **12 RemoteFunctions:** ManageTreadmill, GetShopState, PurchaseShopItem, EquipShopItem, SellLootItem, ManagePedestalItem, CollectSaleCash,
  GetPendingSales, SellHarvest, GardenInteract, PremiumRequest, TreadmillBonusRoll.
- **22 RemoteEvents:** RequestBaseTeleport, RequestTrackTeleport, RequestStationTeleport, OpenEconomyUI, OpenTreadmillMenu, StopTreadmillTraining,
  SpeedGainPopup, ChestRunAlert, BatSwing, RarePackSpawn, VeiledArrival81, TrackHole, Notice83, KeeperHit, PackTaken, WeatherAdopted, VerityQuest,
  PurchaseDone, FruitGift, PullAnnounce151, HubDisplayCelebrate, HubDisplayAvatarReport.
- **Owner-only:** `ChestChaseStudioTests.Execute` / `Feedback`, plus the `/test` TextChatCommand.
- The same folder holds replicated state: the `StormState` folder and the `SeedArt` loose-seed library.
- About 17 services each create their own remotes, each with its own "get or create" helper. No `UnreliableRemoteEvent` is used.
- Client side: 7 `FireServer` and 11 `InvokeServer` call sites. Server side: 41 `FireClient`, 8 `FireAllClients`, and **no `InvokeClient`**.

### 1.7 Asset and bake pipelines

- **Part-built art from data modules** (the oldest path): plants, seeds, trees and the market showcase are built from the art-data tables, mostly on
  the server.
- **Uploaded meshes:** `ReplicatedStorage.SeedPackMeshAssets` for packs (V123, `SeedPackRenderer.lua:1-10`), `R142Keycap` for the keyboard, sound
  ids. `SoundTiming` holds every cue's lead-in.
- **Run-time EditableMesh on the server:** `ApprovedPlantMeshes`, `FruitMeshes149`, `VerityPouch151`, `PackShapes151` and `KeeperMeshes152` (from
  the `KeeperMeshData152*` modules, which stay server-only). The EditableMesh is destroyed after each bake; the MeshPart stays.
- **Run-time EditableImage on the client:** `ArtworkRuntime87` (icons, with the fallback strips in lag audit #3), `RarePullArt`, `RefreshSky`,
  `TreadmillBeltArt151`, `EmbeddedImage153`.
- Both need **Game Settings → Security → "Allow Mesh / Image APIs"**. Without it, every bake falls back to the older art.

### 1.8 Delivery and tests

- **Delivery:**
  - `tools/build_installer.py` turns the git diff from a base commit into byte patches, guarded by each script's length and SHA-256;
  - `tools/installer_engine.lua` / `installer_paste.lua` back up into `ServerStorage/ChestChase_R1xx_Backup`, roll back on any failure, and
    support undo / redo and `--retire`;
  - big releases are split into parts. R152 was 3 pastes of 300–339 KB patching 181 scripts. R153 already touches 123 scripts (11 new) against
    the R152 release `e36b71b`.
- **Tests:**
  - 150 `run*.sh` scripts, 383 `.luau` files and 221 `.py` files under `docs/proposals/<release>/tests` and `tools/tests`;
  - a Roblox mock (`tools/tests/roblox.luau`);
  - `tools/tests/run_all_suites.sh` ran 72 suites in about 31 minutes for R152 (`docs/releases/R152_suites.txt`);
  - 20 `src` files are frozen by sha256 lists (`docs/proposals/R150/tests/frozen.sha256`, `R151/tests/frozen.sha256`), plus one block of
    `SpeedGainPopup`. 34 suites read files from git history (`git show` / `git diff` against a base commit).

---

## 2. Health: what is good (keep it)

1. **Start-up checks itself and fails loudly.**
   - `loadModule` asserts every core module's exports before anything is built (`ChestChaseServerMain.server.lua:36-50`), and
     `Config.Validate()` runs first (`:57`).
   - A second main script is refused (`:19-27`), and the start-up phase is published (`:29`, `:267`, `:276`).
   - Optional features are isolated: Verity, pull announcements, hub displays and the Void giveaway each start in `pcall` (`:125-134`), and
     `MapService` isolates its newer passes the same way (`MapService.lua:82`, `:134`).
2. **The server decides, and one gate guards every input.**
   - 22 routes go through `SecurityGate.Allow`: a token bucket per player and route, at most 16 arguments, and payload shape checks (depth 4,
     64 nodes, strings of 512 characters / 2 KB, finite numbers) (`SecurityGate.lua:3-33`).
   - Movement has a sustained speed budget with swept barriers and no auto-kicks (`MovementGuard.lua:1`).
   - A forged or far dig aim digs at the player's feet instead (`TrackHoleService.lua:215-217`).
   - Owner commands are checked on the server for the caller (`StudioTestCommands.lua:347`), and the server never waits on a client (0
     `InvokeClient`).
3. **Saves cannot overwrite newer data, and failures are handled on purpose.**
   - `UpdateAsync` checks a commit ID and cancels rather than overwrite another server's newer save (`PlayerDataService.lua:318-332`,
     `:1337-1351`).
   - The save merges into the stored table, so fields written by a newer server survive an older one (`:1347-1348`, forward compatible).
   - A profile from a newer version is refused (`:937-943`), and a failed load kicks in live games instead of playing on an empty profile
     (`:910-921`).
   - Requests retry with backoff (`:799-813`). Leaving and shutdown share one finalisation, with a deadline (`:1386-1446`).
4. **Money and items are handled like money.**
   - Robux receipts are recorded in the profile and saved before `PurchaseGranted`, and refused while the data can't save
     (`PremiumService.lua:202`, `:218-227`).
   - Gifts are debited and saved before delivery, with receipts that make retries harmless (`FruitGiftService.lua:1-2`, `:125-126`).
   - The 500-pack giveaway reserves atomically (`VoidGiveawayStore152.lua:2`).
   - Banked packs keep the odds they were made with (`OddsVersion`, `SeedPackRules.lua:410-480`), so a balance change never rewrites a saved
     item.
5. **Network use is light.**
   - 34 remotes, mostly event-driven. Only active keepers' root parts replicate every frame (lag audit Appendix B). State sync uses attributes,
     which Roblox batches.
6. **Run-time bakes degrade gracefully.** Every EditableMesh bake is in `pcall` with a part-built fallback (`ApprovedPlantsBootstrap.server.lua:4-15`).
   A keeper keeps its old model until its new one is ready.
7. **No load-time require cycles.** The one real cycle is lazy: the pack renderers require each other inside functions (`SeedPackRenderer.lua:16-31`
   ↔ `EclipsePackArt` / `PackShapes151` / `VerityPouch151`). Three more reported cycles are false positives (a LocalScript and a module that share
   a name, such as `WeatherWorld149`).
8. **Modern APIs only.** No `wait()` / `spawn()` / `delay()`; everything uses `task.*`.
9. **The notice path was already consolidated.** Since R83 the server's `NotificationService` (17 lines) sends one remote to one client stack
   (`NoticeFeed83`). It has 40 call sites.
10. **Every release is reversible and checked offline.**
    - Hash-guarded byte patches, backup, all-or-nothing rollback, undo / redo, and a `--retire` that parks objects instead of deleting them.
    - A mock install test per installer; a manifest that matches the files exactly (checked: 574 = 574).
    - Release notes that separate what was run from what was only reasoned.

---

## 3. Problems, ranked

Ranked by impact on players and on making future changes safely. **Effort:** S = under half a day, M = 1–2 days, L = 3 days or more (the same scale
as the lag audit).

### 1. Dead and shadowed code: about 75 dead scripts, about 700 shadowed lines (impact: HIGH for safe changes; MED for join time)

**Evidence**
- **73 modules are never required by anything.** 4.53 MB of them sit in ReplicatedStorage: 44% of its bytes, sent to every client at join.
  - 51 `SeedPackArt*`, 7 `SeedPackLOD*` and 7 `SeedPackShapes*` (4.43 MB, the V120–V122 pack art). The V123 renderer clones uploaded
    `SeedPackMeshAssets` instead and never reads them (`SeedPackRenderer.lua:1-10`). No test reads them either.
  - Also `NavigationArtwork` (44 KB), `AncientWorldrootSeedArt45`, `ElderbloomSeedArt45` (both missing from `RarityPlantArt.lua:3`'s index),
    `PassGiftDialog`, `TopNavigationLayout`, `VectorIcons91`, plus server-only `WorldDesign` and `BatAssetImport`.
  - `DigSoundAnalyzer` is also never required, but it is an owner tool run from the Command Bar. Keep it.
- **Stubs that do nothing:**
  - `ActiveTraining81` (`function M.Step(...)end`);
  - `PackTierEmblem` (returns `{}` / `0`, still called from `SeedPackRenderer.lua:66`);
  - `RouteDress84` (deletes a folder and sets an attribute);
  - client scripts `SpeedMilestones87` and `ColourfulText81`, which wait for the game to load and then do nothing.
- **Shadowed methods:**
  - `ChaseService` is wrapped at load by `ConcurrentKeeperService` (`ChaseService.lua:1668`). The wrapper reuses only `Legacy.new` and redefines 12
    methods (`Begin`, `Finish`, `Start`, `_updateActiveRun`, `_maintainGuardians`, the three drop-chest methods...). So **563 of `ChaseService`'s
    1,676 lines never run** (`:215-219`, `:932-954`, `:1089-1275`, `:1280-1391`, `:1434-1669`).
  - `GardenPlantRuntime.Install` (`ChestService.lua:1165`) replaces `RenderGarden`, `BuildArtLibrary`, `BuildGrowthModel` and `BuildPlantAt`: 131
    dead lines in `ChestService.lua:324-403` and `:853-903`.
- **This has already misled a review.**
  - The lag audit (#15, Appendix B, fix D9) says the garden loop "renders a whole base each call because `slot` is ignored", citing
    `ChestService.lua:937`. That is true of the dead `ChestService.lua:853`.
  - The live `RenderGarden` is `GardenPlantRuntime.lua:134`, and it honours `onlySlot` (`:141`). **The garden part of D9 is already how the game
    works**, so don't spend R153 time on it.

**Risk.** Every reader (owner, agent or reviewer) can edit or reason about the wrong function. The dead ReplicatedStorage data is on every player's
join path: since R152 every client script waits for `game.Loaded`, which includes ReplicatedStorage. Clients receive compiled bytecode, and
large table constants stay large. The exact join-time saving has to be measured (Developer Console → Memory → Script before and after).

**Fix**
- **(S)** One installer with `--retire` for the 73 unreachable modules (keep `DigSoundAnalyzer`), `ActiveTraining81` and the two no-op client
  scripts. Retire parks them in the backup with undo, and nothing on screen changes. Check it with a mock install against the owner's place plus
  one Play.
- **(S)** Replace the shadowed method bodies in `ChaseService` / `ChestService` with one line each that names the live implementation. Add a test
  that the live methods are the wrapper's (function identity), so the next agent can't edit the dead copy by mistake.
- **(S)** Add a correction note to `lag_audit.md` D9.

### 2. Owner test tooling on the critical start-up path, and no "server failed" message (impact: HIGH if it happens; probability low per release)

**Evidence**
- `ChaseService:Start` is redefined to also start the owner commands, without `pcall` (`ChaseService.lua:1669-1673`).
  `StudioTestCommands` requires `OwnerUpdateCommands82` at load (`StudioTestCommands.lua:8`).
- `OwnerUpdateCommands82` is the most-changed file in the repo (33 commits; `StudioTestHelp` 32, `Config` 32). It holds 46 `require` calls into
  36 modules (VoidGiveaway152, SocialService, PullAnnouncer, HubTreeLoader151...).
- A load error anywhere in that chain fails `chaseService:Start()` (`ChestChaseServerMain.server.lua:152`). The start-up `xpcall` then marks the
  state `"Failed"` (`:272-279`), and that server runs no game.
- Test hooks also sit inside gameplay paths:
  - the walk speed asks `OwnerTestState82` (`Config.lua:302`);
  - pack opening asks `RarePackTests.Expected` (`PlayerDataService.lua:448`, `ChestService.lua:1138`).
- **No client reads `ChestChaseStartupState`**: 0 reads in StarterPlayer / ReplicatedFirst / ReplicatedStorage. Client scripts use 374
  `WaitForChild` calls, 323 of them without a timeout. On a failed server, players wait forever on a partly built game.

**Risk.** A typo in a test command (the kind of change made almost every release) can take down every server that starts with it. Players see
nothing useful, and the owner sees one Output line only if they look.

**Fix**
- **(S)** Start the owner commands from the main script inside `pcall`, after `chaseService:Start()`, like Verity, and drop the `Start` override in
  `ChaseService`.
- **(S)** Wrap the two gameplay test hooks so that a failure means "no test override".
- **(S)** `TitleScreen` (or a 10-line client script) shows "This server didn't start. Rejoin!" when the attribute reads `"Failed"`, or stays
  `"Starting"` past about 60 s.

### 3. The server builds most visuals, so phone quality tiers can't reduce them (impact: HIGH for players; it is the cause of lag audit #1 and #12)

**Evidence**
- `MapService` runs 9+ build passes on the saved map at start (`MapService.lua:82-134`): `GardenBaseLayout`, `TrackExpansion83`, `ForestLayout87`,
  `FloorSafety86`, `HideBushes124`, `MarketLayout`, `HubDecor151`, `ZFightFix149`, and treadmills from `BiomeVisuals`.
- Gardens are built on the server, one growth model per stage (`GardenPlantRuntime.lua:70-93`, `:134-238`).
- 17 server modules require shared visual builders (`PlantVisuals`, `SeedPackVisuals`, `HarvestPresentation`, `GardenFenceArt`...).
- The lag audit measured the result: about 7,200 drawn parts within 400 studs of the plaza, on **every** tier.
- The counter-examples already work: `HubLife151`, the keyboard and the keeper effects are built on the client with distance and tier budgets. The
  garden even publishes compact descriptors for clients (`GardenViewDescriptions`, `GardenPlantRuntime.lua:39-53`).

**Risk.** Every new decoration added on the server costs every phone, forever. The client tier system can't help, and server start time and join
replication grow with it.

**Fix**
- **(rule, S)** New world dressing is built on the client from server state (attributes or small descriptor folders), with a distance and tier
  budget.
- **(M)** First migration: the market showcase (2,186 parts), as lag audit fix 1 / B2 describes.
- **(L, only if the game keeps growing)** Gardens and treadmill dressing the same way.

### 4. Patches on patches: odds, config and map are layered instead of edited (impact: MED for safe changes)

**Evidence**
- `SeedPackRules.lua` defines `Rules.Roll` 6 times (`:252`, `:395`, `:431`, `:467`, `:512`, `:537`) and `Rules.SeedOdds` 6 times (`:246` ...
  `:532`), each capturing the previous one. `RewardPool` and `ObtainablePool` are defined twice.
- `Config.lua` assigns:
  - `Version` 5 times (`:5`, `:684`, `:694`, `:712`, `:750`);
  - `ProfileVersion` 3 times;
  - `Validate` twice (`:353`, `:728`).
- After those, `RouteBalance83.ApplyConfig` (`:759`) and `BiomeExpansionConfig` (15 fields) rewrite values.
- More of the same:
  - `PlantCatalog` → `GrowthPace125.Apply`, `BalanceValues81` → `EconomyBalance90.Apply`;
  - `HarvestToolService` wraps `Chests:SyncTools` / `CleanupPlayer` (`HarvestToolService.lua:39-53`);
  - `ChaseMusicTrim152` corrects the hand-edited BackgroundMusic's `TimePosition` from outside, every frame (`ChaseMusicTrim152.client.lua:2-7`).
- The frozen lists lock 20 gameplay files byte for byte, including `Config.lua`, `SeedPackRules.lua` and `EconomyService.lua`
  (`docs/proposals/R150/tests/frozen.sha256`, `R151/tests/frozen.sha256`). So the cheapest legal change is another layer.

**Risk.** To know what a version-149 pack rolls, you must read six wrappers in order. To know a config value, you must know which of three places set
it last. The `OddsVersion` design itself is right; the problem is the stacking.

**Fix**
- **(M)** Flatten `SeedPackRules` into an explicit table `Rollers[OddsVersion]`. Prove it byte-identical first with a golden dump of every
  (stage, variant, luck, version) → odds / roll before and after; R153 already has `tests/dump_odds.luau` to build on.
- **(M)** The same for `Config`: snapshot the effective table, fold the overrides in, and the snapshot must match.
- **(S)** Replace "file is frozen" sha256 checks with these behaviour goldens, so a harmless edit (a comment, a renamed local) no longer forces a new
  layer.

### 5. Data: no session lease, so a fast server hop gets kicked (impact: MED for players; the data itself stays safe)

**Evidence**
- Load is a plain `GetAsync` (`PlayerDataService.lua:901-903`).
- The commit-ID check only runs at the first save (`:1343-1346`). On a mismatch the player is kicked with "Ur garden was updated in another server"
  (`:1366-1368`), and the session can no longer save.
- This happens when a player leaves server A and joins server B before A's final save lands. A's save can take several seconds when DataStores are
  slow: 3 tries with 1 s and 2 s waits (`:799-813`).
- `PlayerRemoving` yields on that final save (`ChestChaseServerMain.server.lua:247`) before it frees the chase run, holes, base and fast-travel
  state (`:248-253`). A leaving thief's keeper lock and base stay held for the length of the save.
- `UpdateAsync` passes through existing `UserIds` but never adds the player's (`:1340`, `:1350`), which Roblox's data-erasure tooling uses. LOW.
- No offline suite drives the real `Load` / `Save` / `FinalizePlayer` / conflict path. The purchase and daily tests replace PlayerDataService with
  a mock table (for example `docs/proposals/R148/tests/test_purchase.luau:86`).

**Risk.** Rare but bad: a player who rejoins quickly, for example after a crash or a server hop, is kicked a minute later and loses that minute. The
most valuable file (1,906 lines, 89 functions, 28 commits) has no direct test of its failure paths.

**Fix**
- **(M)** At load, `UpdateAsync` a small lease `{Job=game.JobId, At=os.time()}` into the profile. If another server's lease is fresher than about
  60 s, wait and retry for up to about 10 s before loading. The final save clears the lease.
  - Keep the commit-ID check as the backstop.
  - It is an optional field: the save already keeps unknown fields (`:1347-1348`), so `ProfileVersion` stays 22.
- **(M)** A PlayerDataService suite on a DataStore mock covering: load failure, newer profile, conflict, retries, autosave racing a receipt, and
  shutdown with 30 players.
- **(S)** In `PlayerRemoving`, free the world state (chase, holes, fast travel) before the yielding final save. Check first that none of it writes
  to the profile.
- **(S)** Add `{player.UserId}` on the first save.

### 6. Release tooling: very safe, but heavy (impact: MED for safe changes)

**Evidence**
- Release size: R152 = 181 script patches in 3 pastes; R153 already touches 123 scripts.
- The part split comes from a "scratchpad `build_parts.sh` recipe" (`docs/releases/R152_parts.txt:3`) that is not in the repo.
  `build_installer.py` has no size check. R123 showed that a paste can be cut off; it fails safe, but costs a round trip with the owner.
- Backups are never pruned: every release leaves a full `ServerStorage/ChestChase_R1xx_Backup` with every patched script's before and after
  source. ServerStorage already holds about 115,000 instances of older backups (lag audit Appendix B), which cost server memory and publish / load
  time.
- A hand edit forks the base forever: BackgroundMusic can't be patched, hence the extra script in problem 4.
- The tests are tied to one machine:
  - `run_all_suites.sh:3` defaults to `REPO=/home/user/tmz`, and the place file path is a session upload (`:9`);
  - 28 test files hard-code `/home/user/tmz`, and 10 hard-code the upload path;
  - suites live by release (`docs/proposals/R1xx/tests`), not by system, and 34 read files from older commits.
- There is no lint or type check: 0 `--!strict`, although `luau-analyze` is installed at `/opt/luau`.

**Risk.** Each release is a big, all-or-nothing paste series. Another agent or machine can't run the suites without editing paths. The frozen and
pinned checks push work into new layers (problem 4).

**Fix**
- **(S)** Check the part splitter into `tools/` with a hard size limit (for example 300 KB per part) and an automatic split.
- **(S)** Add an installer option that prunes `ChestChase_R1xx_Backup` folders older than the last 3. **Owner Studio action:** paste it once, and
  read the printed list before confirming.
- **(S)** Make the runner path-independent: `REPO` from `git rev-parse --show-toplevel`, and `PLACE` a required argument with a clear skip
  message.
- **(M)** Move suites into `tests/<system>/` as they are touched, and replace "same as commit X" checks with goldens (problem 4).
- **(M, only if growing)** `luau-analyze` in the runner on new modules, and `--!strict` on rules and data modules first.

### 7. Many independent client loops and two quality governors (impact: MED for players on weak phones and for safe changes)

**Evidence**
- 54 LocalScripts and 25 shared modules connect per-frame hooks; 67 are alive at the hub.
- Each script implements its own "step at N Hz within D studs on tier T". For example, there are 12 copies of `local function reduced()`
  (plus 2 named `reducedMotion`), and they don't agree: one also counts FastMode as reduced motion (`SaleMoneyEffects.lua:22-25`).
- There are **two FPS governors** with different thresholds:
  - `ClientFxBudget` drops a tier under 42 fps (`ClientFxBudget.lua:4-12`);
  - `SettingsClient` turns on FastMode under 38 fps, sampled over 3 s windows (`SettingsClient.client.lua:124-131`);
  - Bloom and SunRays only follow FastMode (lag audit #10).
- `AudioMixer` routes sounds into volume groups by **name** (`AudioMixer.lua:40-46`), and 27 files create `Sound` instances directly.
- The two keeper effect layers are both stepped for every keeper on every frame: `KFx.Step` and `Fx152.Step` (`BeastAnimation.client.lua:181`,
  `:184`).

**Would one scheduler help?** Not much by itself. The cost of calling 67 connections is well under 0.1 ms. The lag audit shows the cost is inside a
few handlers (the giveaway 5.2 ms of 7.3 ms on the mock). A rewrite into one scheduler would touch every client script for little gain.

**Fix**
- **(S)** One quality source: SettingsClient's "Auto" reads `ClientFxBudget`'s tier instead of measuring again, and the post effects follow the
  tier. A slow phone then drops effects at one consistent point. It is a behaviour change on slow phones only.
- **(M)** A small opt-in helper, `FrameTick.every(hz, {range=, onScreen=})`, on `ClientFxBudget`. Use it in new effects and in the lag audit's
  heavy scripts as they are fixed (giveaway D3, keepers D6).
- **(S)** One shared `reduced()` in `ClientFxBudget`.
- **(L, only if growing)** One client bootstrap that requires feature modules in a known order, instead of 75 independent LocalScripts with copied
  guards.

### 8. Silent errors (impact: MED for safe changes: bugs hide)

**Evidence.** 288 `pcall`s throw their result away, against 160 `warn` sites in total. For example, the hub display report remote's connection and
handler are both wrapped with nothing logged (`HubDisplayService.lua:416`).

**Risk.** When something breaks, the owner (who is not a programmer) sees "it doesn't work" and no Output line to send.

**Fix (S).** A tiny `Safe.call(tag, fn, ...)`: it warns once per tag per minute and counts failures in a ReplicatedStorage attribute that
`/test status` prints. Use it in new code and convert the boot and data paths first. No player-visible change.

### 9. Remotes and network: fine, with small gaps (impact: LOW–MED)

**Evidence**
- 34 remotes created by about 18 services, each with its own helper. Remote names are spread across `Config.lua:9-19` and several Rules modules.
- No `UnreliableRemoteEvent`, although these are cosmetic and frequent:
  - `SpeedGainPopup:FireAllClients`, 5 per second per trainer (`BaseService.lua:505`);
  - the chase proximity ping, 10 Hz (`ChaseService.lua:121`);
  - KeeperHit and BatSwing effects.
- `CollectSaleCash` allows a burst of 832 (`SecurityGate.lua:3`; every other route bursts 18 or fewer). The server validates ids, so this is a
  flood risk rather than an exploit.
- `SecurityGate.Valid` accepts any Instance (`:14`). That is correct only as long as every endpoint checks ownership itself.

**Fix**
- **(S)** Make the three cosmetic streams unreliable (a lost popup is fine).
- **(S)** Lower the `CollectSaleCash` burst to what the coin flight actually needs.
- **(M, only if growing)** One `Remotes` module that lists name, kind and gate policy in one table, and creates them all.

### 10. Names and style (impact: LOW)

**Evidence**
- 91 code modules carry the release they were added in. The suffix says *when*, not *which one is current*: `NoticeFeed83` is the only notice feed.
- The real parallel sets are:
  - `KeeperFx` + `KeeperFx152`;
  - `KeeperRigConfig` (133 KB, the old rigs, kept as the bake fallback) + `KeeperRigConfig152`;
  - `PackOdds81/112/137` (intentional, one per odds version);
  - `TitleScreen` + `TitleScreen104`.
- 704 code lines are over 400 characters (for example `ChestChaseServerMain.server.lua:125`).

**Fix**
- **(S)** Don't mass-rename or reformat: it would change every require path and bloat the byte-patch installers.
- **(S)** Stop adding release numbers to new names.
- **(S)** Keep a one-page `docs/SYSTEMS.md` saying which module is the live owner of each system and which ones are fallbacks.

---

## 4. Plan

**Owner** marks what needs the owner in Studio. Every step ships as the usual hash-guarded installer with undo.

### Tier 1: quick safe wins (next release, nothing changes on screen)

| # | Step | What it buys | Effort |
|---|---|---|---|
| 1 | Retire the 73 unreachable modules, `ActiveTraining81` and the 2 no-op client scripts (`--retire`; keep `DigSoundAnalyzer`) | About 4.5 MB less to every client at join; 13% fewer scripts to read; nobody edits dead art. **Owner:** paste, then one Play | S |
| 2 | Replace the 563 + 131 shadowed lines with pointers, add a "live method" test, add the D9 correction to the lag audit | Nobody (agent or reviewer) works on code that never runs | S |
| 3 | Start owner commands from the main script inside `pcall`; guard the 2 test hooks in gameplay | A broken test command can no longer stop a server | S |
| 4 | Clients show "This server didn't start, rejoin" on `ChestChaseStartupState = Failed` (or stuck in Starting) | Players aren't left on a half-loaded game | S |
| 5 | `Safe.call` helper on the boot and data paths, with failure counts in `/test status` | The owner gets an Output line to send when something breaks | S |
| 6 | Tooling: splitter in `tools/` with a size guard; path-independent runner; backup prune option | Fewer install surprises; any machine can run the suites. **Owner:** confirm the prune once | S |
| 7 | Free chase / holes / base state before the final save in `PlayerRemoving`; add `UserIds` to the first save | No keeper or base held by a player who already left | S |

Do these alongside the lag audit's R153 "do now" set (D1–D10, minus the garden half of D9).

### Tier 2: medium refactors (one or two per release, each proven identical first)

| # | Step | What it buys | Effort |
|---|---|---|---|
| 8 | Session lease at profile load, plus a PlayerDataService suite on a DataStore mock | No "updated in another server" kicks after a fast rejoin; the most valuable file gets real tests. **Owner:** one 2-server Studio test with API access on | M |
| 9 | Flatten the odds chain into `Rollers[OddsVersion]` behind a golden odds dump; the same for Config; goldens replace frozen hashes | Odds and economy edits become one readable change instead of a seventh layer | M |
| 10 | Market showcase built per client with distance LOD (lag audit B2), as the pilot of "server owns state, client draws" | Up to about 2,186 fewer parts away from the market; proves the pattern for later | M |
| 11 | One quality source (SettingsClient Auto and post effects follow `ClientFxBudget`), plus a `FrameTick` helper used by the heavy scripts as the lag fixes touch them | Weak phones drop effects at one consistent point; new effects are budgeted by default | S–M |
| 12 | Unreliable remotes for popups / proximity / hit effects; a tighter `CollectSaleCash` burst | Less reliable-channel traffic in busy servers | S |
| 13 | Move suites to `tests/<system>/` as they are touched; swap "same as commit X" checks for goldens | Tests describe systems, not history | M |

### Tier 3: only if the game keeps growing

| # | Step | What it buys | Effort |
|---|---|---|---|
| 14 | Gardens and treadmill dressing built on the client from the existing descriptors | The rest of the server-built geometry becomes tier-aware | L |
| 15 | One client bootstrap instead of 75 LocalScripts; one `Remotes` registry | A known start order; one place for every remote's name and limits | L |
| 16 | Split PlayerDataService (1,906 lines) into a profile store plus domain modules (garden, premium, packs, daily) | Smaller, testable pieces of the most important file | L |
| 17 | `luau-analyze` in the runner; `--!strict` on rules and data modules | Type errors caught before the owner pastes | M |

**Not recommended:**
- a big-bang rewrite or one global scheduler (small gain, touches everything);
- mass renaming of numbered modules, or reformatting dense files (installer churn, no player gain);
- swapping in a third-party profile library now. The current data layer is sound; item 8 adds the one thing it lacks.

---

## 5. Verdict

**Plain words for the owner:** the game's code is OK for now. You don't need a rewrite. The important parts are solid: the server decides who gets
what, saves can't overwrite each other, Robux purchases are safe, and every update can be undone. What's wrong is clutter from 150 updates: old
files nobody uses that still get sent to every player, old copies of code that no longer runs (they already fooled one review), and test tools that
can stop a server from starting. The lag mostly comes from the server building the decorations, which phones can't scale down.

**Top 3:**
1. **Clean out the dead code** (about 75 unused scripts, about 700 never-run lines). Nothing changes on screen, joins get lighter, and every later
   change gets safer.
2. **Take the test commands off the start-up path and tell players when a server fails**, so a typo can't take a server down silently.
3. **Do the lag audit's "do now" list**, and from now on have the players' devices build decorations (starting with the market) instead of the
   server.
