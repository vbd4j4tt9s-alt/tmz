# CHEST CHASE / "Steal A Pack" — MASTER HANDOFF (R124)

Generated 2 Oct 2026 from the Claude Code session that built R114–R123, following MASTER HANDOFF GENERATION PROMPT V4.1.

Revision changelog
- R124 update (2 Oct): R123 is installed and checked in the owner's place; R124 is built (source + installer), not installed. Sections 1–3, 5–8, 10–12 updated; the R123 history below is kept where still true.
- R125 update (2 Oct, later): built, not installed. Hold E to steal (1 s / 0.5 s), biome title redo (logo in a CanvasGroup medallion — R124's plain-Frame title lost the logos in Studio), slower plant growth (owner answers: up to 4 h King; Common/Uncommon/Forest/Mech unchanged; regrow same factor; value x max(1,factor/2) capped 9e10), tutorial TRACK/BASE teaching, Esc-menu offline-growth card, Featured star logo, shovel tip wording. Installer `installers/R125_install.lua` (~60 KB, 13 scripts, base `181aa89` = R124; mock 41/41). Notes: `docs/releases/R125.md`. Install order: R124 then R125.
- R133 update (3 Oct): built, not installed. Owner's R132 play test. MarketLayout: settle() measures VISIBLE parts (HarvestGeometry.Bounds; fruit/plant models carry hidden plant parts, which made fruit tiny and floating), scales about the pivot and turns about the visible centre; sign fruit removed; counter crates hold 3 fruits each (Crates Y 5.5) and sit on the counter (moved down .051); produce stands are solid ground-standing steps (StandStep 1.05); Planter/Flower box soil (Ground); M.ShelfPacks(count,random) shuffles all 42 stage x Pack01-06 pairs, 20 on 4 shelves (Tops 7.565/12.835, X 13.6, Z 13.77); R69 builder: Front fascia wall (22.4x3.25x.5 pre-scale, y 7.3-10.55, z -8.6) behind the sign, no porch diagonal braces, lantern hangers reach the porch header, SurfaceGuis facing the market centre removed from the front and door signs; Polish: Ceiling beam (39.6x.7x.7 at y 19.05 z 3) on the side lintels with lamp cords, string light wire tied post to post (x +-18.19, z -21.76) dipping to each bulb, Porch footings, back props (4 pots with plants, barrel, crates at z 17.1 on the deck), attribute MarketPolish=133. Pedestal: M.FruitHeight 8.4, Projector beam. FruitOfHourDisplay: HarvestGeometry-based size 4.2 and centring, label 5.6x1.5 studs (no pixel floor) above the fruit, two rows FruitName / '×m · mm:ss'. BeginnerGuide text rewritten casual with emojis (+ Fruit of the Hour tip; steps <=14 words, tips <=10). Market float check `docs/proposals/market_R132/preview/check_market.py` (0 floating; R131 had 15). Tests `docs/proposals/R133/tests` (market 50). Installer `installers/R133_install.lua` (37,308 bytes, 4 scripts, base `3a26e67` = R132; mock 30/30). Notes `docs/releases/R133.md`. Next: seeds revision preview (owner asks listed in the R132 line).
- R132 update (2 Oct, later): built, not installed. Owner-approved market polish (owner: keep the current market, no avatar, no chalkboard; use the game's own plants and fruits; pedestal without discs). MarketLayout keeps the R69 builder; M.Polish adds string lights (15 neon bulbs), 3 ceiling lamps (PointLight), 4 flower boxes, 6 produce tiers, removes the R69 'Fresh produce'/'Fruit stem'/'Porch leaves'/'Coral flower'/'Seed jar'/'Jar lid' parts, and in task.defer builds M.Showcase with HarvestPresentation.Build (fruit), PlantVisuals.Build (plants) and SeedPackVisuals.Bag (packs), each in pcall (skipped with a warning), settled by settle() (anchored, no collide/touch/query, scripts/particles/sounds/tags removed, ScaleTo, turned about its own centre). M.Pedestal at M.Center+M.FruitOfHour (-20,0,-30): plinth, teal column, gold cradle, plaque, transparent FruitAnchor at y 7.2 with FruitLight. Fruit of the Hour: ReplicatedStorage.FruitOfHour picks per server-clock hour from SeedPackRules.SeedDesigns in PlantCatalog and not retired (51 fruits; walk-forward pick so never the previous hour's fruit), Multiplier 1.5..3.0 step .1; SaleValue=floor(value*m+.5); owner test override RS attribute FruitOfHourTest 'SeedId:m:endsAt' (F.SetTest; /test fruithour [fruit] [1.5-3] | off, server-wide, 10 min). FruitOfHourService (started in ChestChaseServerMain) publishes RS attributes FruitOfHourSeedId/Name/Multiplier/EndsAt and announces changes (key hour:seed:m) via Notifications; joiners told after 8 s. PlayerDataService SellHarvest/SellAllHarvests pay SaleValue; GetHarvestInventory SellValue includes the bonus and sets HourMultiplier; HarvestSellMenu adds the '🌟 Fruit of the Hour ×m' line. Client FruitOfHourDisplay floats the real fruit (2.6 studs, spin .7 rad/s, bob) over FruitAnchor with a label (name, SELLS ×m, time left), animates only within 170 studs, retries builds after 3 s. Client HomeMarker: BillboardGui 'HomeMarker' in PlayerGui adorned to your base Pad (BaseOwnerUserId==LocalPlayer.UserId), StudsOffsetWorldSpace up 10 (+-.45 bob), Size UDim2.new(6.5,22,6.5,22), AlwaysOnTop false, MaxDistance 900, refreshed every 1 s. Installer `installers/R132_install.lua` (58,511 bytes, 12 scripts, base `624da26` = R131; mock 40/40). Notes `docs/releases/R132.md`; renders `docs/proposals/market_R132/`. Next: seeds revision preview (R133, owner: remove the 'winged' side shards on Diamond Vine/Prism Pepper/Ash Tomato and redesign them; Prism Monarch gets small crystals of different sizes/colours instead of the ring; effects for Rare and up growing with rarity; fix floating/detached parts; proposal files in `docs/proposals/seeds_R132/`). Owner: leave fruit models as they are (the watermelon is meant to be a big green cube).
- R131 update (2 Oct, later): built, not installed. Gifting fix: FruitGiftService accepted only UserId > 0, so Studio test players (negative ids) could never gift; now S.ValidUserId allows negatives only in Studio. Refusals tell the giver why (S:Refusal: save not ready / Studio API access, receiver in a run, busy), S:Settle waits up to 8 s for Busy/Working, Recover reruns once when skipped (Again), inbox GetAsync uses DataStoreGetOptions UseCache=false, TooFar distinguishes blocked line of sight. Receiver: FireClient 'Received' (text, {From,Item}) -> client NoticeFeed83.Gift (priority, cue 'Gift' = GemClaim 82559527540705), no server Notes notice. GardenFenceArt owner badge: Size UDim2.new(11,34,7,22) (studs + px floor), AlwaysOnTop false, portrait hidden for id <= 0, styleBadge restyles old badges (BadgeRevision 131). Weather: BalanceRules Weather*Chance .002 per roll; WeatherService rolls once per object per minute (Minute = ceil(remaining/60)-1; keys ':m'..minute). Installer `installers/R131_install.lua` (35,799 bytes, 8 scripts, base `b30b6e0` = R130; mock 34/34). Notes `docs/releases/R131.md`. Pending owner approval: market redesign + fruit of the hour (design preview first, owner avatar as animated shopkeeper).
- R130 update (2 Oct, later): built, not installed. The owner's performance pass plus two asks. Performance (no visual change): ConcurrentKeeperService._maintainGuardians keeps an IdleKeepers record per stage (full _ensurePersistentGuardian only when dirty via DescendantAdded/Removing/AncestryChanged, replaced, after a chase, or every IdleRefreshSeconds=5; otherwise atHome pivot check and setIf attributes; mock 7 keepers/20 s: 567->35 prepares, 2240->0 attribute writes, 240->0 pivots); MovementGuard reuses one RaycastParams (filter rewritten only when the barrier list changes). Owner 'sky turns dark when the track refreshes': RefreshSky without the EditableImage black sky now removes the texture-less Sky and turns Atmospheres black (Color/Decay 0, Offset 0, Haze/Glare 0, Density >= NightDensity .32; a temporary TrackRefreshNightAir if none), restored exactly; WorldEvents makes no weather clouds while TrackRefreshActive. Owner gifting: FruitGiftClient hover Highlight 'GiftTarget' (in reach 18 studs, 12 Hz, only while a giftable item is held), click opens GiftConfirm popup 'Are you sure you want to give <item> to <player>?' (Give/Cancel/B/Esc), 'Get closer' when far, sends respect the server's 2 s gap; FruitGiftService carries the Tool name as gift.Name (outbox and inbox), receiver gets Notifications:Show '🎁 <giver> gave you <item>!' (status line silent), giver gets 'Gift sent to X! (item)', TooFar status. Installer `installers/R130_install.lua` (43,750 bytes, 7 scripts, base `20f06a8` = R129; mock 33/33). Notes: `docs/releases/R130.md`; perf report `docs/proposals/R130/PERF_REPORT.md`. Install order: R124 … R130.
- R129 update (2 Oct, later): built, not installed. Landscape touch layout (HudLayout wideLayout, m.PhoneWide): wallet text rows bottom-left (WalletPassive: rows not buttons), status stack bottom-right above the jump button (boosts, The Darkened card, timers; StatusCorner/StatusPlain/StatusBox), MENU hub left middle, hotbar centred (5 slots), BASE/TRACK unchanged in the top bar; portrait/computers unchanged; Bag avoids only hotbar+jump on PhoneWide. Weather base-only (WorldEvents: no camera roof raycast, Clouds.Step darkens Terrain clouds and restores, nothing on the track; BiomePresentation passes Clear for stage>0; BiomeMood darker overcast; BiomeWeather runs during weather). Mutation label MaxDistance math.huge. Installer `installers/R129_install.lua` (~42 KB, 11 scripts, base `7b5e423` = R128; mock 37/37). Notes: `docs/releases/R129.md`. Install order: R124..R129.
- R128 update (2 Oct, later): built, not installed. Lights-out hold 4 s (~7 s total); HudLayout desktop slot shrinks (>=66/60) when that lets the side HUD sit beside the bar (StatusBottom 16); biome/global weather particles world-space (LockedToPart=false, AmbientParticleField128 birth box per frame with runner/fall-time lead, teleport-only clears, same rates); carried-item effects stepped every frame (ItemCosmetics Carried, SeedPackRender carried aura/orbit/Mech, VeiledEventClient81 carried Void fx, HeldHarvestRig.Follow); keepers start swings at KeeperCombat.TriggerShare .6 of Reach and a started swing lands within that range +2 studs or on body contact (ConcurrentKeeperService). Installer `installers/R128_install.lua` (~40 KB, 13 scripts, base `0bc992d` = R127; mock 41/41). Notes: `docs/releases/R128.md`. Install order: R124..R128.
- R127 update (2 Oct, later): built, not installed. Weather-mutation highlights (server pack Highlight tag MutationGlow, 20 s, cap 16; owner-only rainbow outline + label via MutationHighlights client, cap 12; notice names the plant via WeatherAdopted Items), owner test `weather <kind> all` (WeatherService.ForceAll), world spawn weights 42.92/28.24/16.94/7.9/3/1 (Legendary 3, Mythic 1; floors unchanged), PackSizes buffed (5x+ 0.6%, 10x+ 0.05%), hotbar 82/72 px desktop and 64 phone, Bag sheet 1080x740, The Darkened arrival = lights-out via EnvironmentLighting.SetBlackout + BiomeMood.Dark (Atmosphere density .7, black; ~10 s; local lantern), replacing the R122 screen overlay. Installer `installers/R127_install.lua` (~59 KB, 15 scripts, base `62f6a0c` = R126; mock 43/43). Notes: `docs/releases/R127.md`. Install order: R124, R125, R126, R127.
- R126 update (2 Oct, later): built, not installed. Bought Mech packs (each pack of a 5/10 bundle) and treadmill bonus rolls (Void Pack too) roll PackSize from BalanceRules.PackSizes like world packs; `SeedPackRules.NewSeedScale` no longer pins MechLimited to 1, so Mech seeds follow the size (1x unchanged). No UI change (owner: "no animation or transition"); bonus result gains `Size`, text unchanged. Installer `installers/R126_install.lua` (~24 KB, 5 scripts, base `d53bd77` = R125; mock 31/31). Notes: `docs/releases/R126.md`. Install order: R124, R125, R126.
- R123 handoff: replaces docs/HANDOFF.md (29 Sep, R107/R110 era) as the current master. The baseline moves from "V149 prepared" to "V150 R123 source".
- R123 handoff: the V4.1 Section 6 plant-visual seed rows are moved to verification debt (no evidence they were worked in this repo). The newest user tasks are reconciled into Section 6.

---

## 1. Executive Project State

- **The game.** Roblox game "Steal A Pack" (internal name Chest Chase). The loop: steal seed packs from 7 keeper-guarded biome tracks, run back past the safe line, open the pack, plant, harvest, sell, and buy upgrades (treadmill, boots, trails, fence). Then push to higher biomes.
- **Source of truth.** Git repo `vbd4j4tt9s-alt/tmz`, branch `claude/chest-chase-handoff-f04hg8`.
  - Scripts are exported Rojo-style under `src/`: `*.server.lua` = Script, `*.client.lua` = LocalScript, `*.lua` = ModuleScript.
  - `src/MANIFEST.tsv` lists every script: 448 rows, matching the files.
- **Source version.** `Config.Version='V150 R124'`, `ProfileVersion=20` (unchanged: no save-format change). R124 source = commits after `b6cdbc7` on branch `claude/compassionate-brown-lohfok`; `installers/R124_install.lua` is built from it with base `b6cdbc7` (= R123 source).
- **Delivery.** Each release is one paste-into-Command-Bar installer with a backup and undo (`installers/R1xx_install.lua`). The owner installs them in Studio. The assistant can't run Studio.
- **Installed (runtime) state, 2 Oct 14:46: R123 INSTALLED in Edit; a clean Play run is not yet reported.**
  - Owner ran the one-line redo (`[R123] Installed` at 14:34:34). `check_R123.lua` at 14:46 (Edit) shows: `Config.Version='V150 R123'`; PremiumRouting needs GiftProducts: false; new R123 scripts missing: none; R123 backup state Installed; R121 backup state Built.
  - The only Play Output so far (14:34:31) was snapshotted mid-install (Section 7 item 2). No Play since the install finished.
- **Earlier state, from the uploaded place `sapf.rbxl` (2 Oct): R123 not installed; Play could not start.**
  - Scripts are byte-exact R121 (`9b13846`) minus the 4 deleted modules. R121 still requires them in 10 places (`PremiumRouting:2`, `PremiumService:5`, `PremiumProgress`, `GamePassClient:11`, `WorldStatusHud:4`), so the server and clients error on start.
  - `ServerStorage.ChestChase_R123_Backup` is State `Undone`. It holds 71 entries, all matching current `src/`, and its Installer hashes to `3558ed99…` (the current build). It was made by the 05:56 paste (`69619fc`), which never set the `Build` attribute. So the 06:04 installer (`fae4310`) refused it as "older": a false refusal.
  - Fix: the paste wrapper now also recognises a same-build backup by its Installer hash (`tools/installer_paste.lua`). The rebuilt `installers/R123_install.lua` is one paste, with no undo or delete. Mock-run against the uploaded place: 28/28. Owner has not run it yet.
  - `ChestChase_R121_Backup` is State `Built`, though its 22 modified sources are exactly in place. Cause unknown. R123 never reads it. Its 4 added scripts are the ones the owner deleted, so R121's own undo/redo can no longer run (expected, not needed).
- **Truth layers.**
  - All R122/R123 features are IMPLEMENTED: present in source, passing offline mock tests.
  - None is VERIFIED at runtime.
  - None is user-accepted, apart from the rename and shop wording the owner explicitly asked for (code exists; result not reviewed).
- **Active task.**
  1. Get the correct R123 build installed and booting.
  2. Owner installs R124 (one paste, ~78 KB) and runs the R124 test list (`docs/releases/R124.md`). Keeper re-look approval is still open.
  3. Live test pass using `docs/COMMANDS.md`.
- **Owner preferences.**
  - Casual and short. Wants results, not theory.
  - One installer per release, with backup and undo.
  - Never ship silently untested: always say what was run versus only reasoned.

## 2. Authoritative Build / Source Inventory

| Item | Value / evidence | Freshness |
|---|---|---|
| Source | Repo `src/` at the latest commit of `claude/compassionate-brown-lohfok`; `Config.lua` reads `Config.Version='V150 R133';Config.ProfileVersion=20` | CURRENT |
| Last confirmed installed release | R121 (owner Output 13:42 showed `[V149 R121]`) | STALE (owner then installed R123 builds) |
| R123 installer | `installers/R123_install.lua`, 324,915 bytes, 71 scripts, build `3558ed99…`. Base = R121 commit `9b13846`. Mock install test 99/99. Mock run against the uploaded `sapf.rbxl`: 28/28 | CURRENT (3rd build: only the paste wrapper changed) |
| R124 installer | `installers/R124_install.lua`, ~77.6 KB, 20 scripts (17 patched + 3 new: HideBushes124, HideBushClient, BiomeEffectGovernor). Base = `b6cdbc7` (R123). Mock install test 48/48; all paths checked against the uploaded `sapf.rbxl` tree | CURRENT, NOT INSTALLED |
| Superseded R123 build | The first build (~320 KB) still required `GiftProducts`. Its backup in the owner's place made later pastes re-run it | SUPERSEDED, possibly still installed |
| Place check | `installers/check_R123.lua`: read-only; prints version, missing new scripts, leftovers, backup states | Not yet run by owner |
| Older reference | `docs/HANDOFF.md`: map geometry, startup order, R107–R110 notes | Historical; geometry notes still valid |
| Release notes | `docs/releases/R110.md`–`R121.md`, `R123.md` (R122 was folded into R123) | CURRENT |
| Mismatch | Owner Output showed `KeeperSignatureStrike is not a valid member of ReplicatedStorage` with the old build. All 3 R123 builds add the module, and the uploaded place has it correctly parked in the Undone backup. So this was a half-applied state, not code. The mock install puts it in place | UNKNOWN / VERIFY |

## 3. Core Game Loop and Current Design

- **Biomes.** Physical order: Forest, Jungle, Desert, Snow, Lava, Crystal, Storm. Stage IDs are `{1,6,2,3,4,5,7}`; Mech = 8 (paid only).
  - Track lengths grow with difficulty. `TrackExpansion83` stretches the saved geometry at runtime. **Never save the map during or after a Play-time expansion.**
  - Track walls have inner faces at |X| = 89.
- **Keepers.** One per biome.
  - A keeper stays locked to its thief until that chase resolves; others can still steal.
  - A hit ragdolls the thief for 2.7–3.3 s and flings them higher at each tier (`KnockbackConfig.Keeper`). The landing is clamped inside the walls by `RagdollService.KeepOnTrack`.
  - The pack drops on the ground and can be reclaimed.
- **The Darkened** (renamed from "The Veiled One"; internal name `Veiled*`/`Event81` unchanged).
  - A special event at Storm Peaks that guards 2 Void Packs and survives refreshes. It leaves after the last pack is banked.
  - Only one event at a time. After 3 refreshes with no steal, the packs reroll.
  - Arrival: sound 113339179211972 plus a 1 s lights-out with a visibility circle. The HUD card reads "ARRIVES IN …" between events.
  - The Void Pack keeps its halo.
- **Shovel holes.**
  - Max 4 per player, 3.4 studs wide, 3-minute lifetime, 3 s cooldown between digs (R124; was 8). A cooldown click shows just the time ("2s"); a fading tip ("Dig holes on the ground to trap pack thieves!") replaces the old permanent hint line.
  - They trap only pack carriers: 4 s ragdoll, and the pack drops.
  - Slots free up on a trap, a cover, expiry, a refresh or leaving.
  - Not allowed on pack pads, keeper camps, The Darkened's home or its Void Packs, or the entrance.
- **Hide-in bushes (R124).** The 8 Forest/Jungle `Bush`/`Bush top` pairs (saved map parts) are enlarged at runtime by `HideBushes124` after the track stretch: 7.5 studs tall, >= 9 wide, walk-through, CanQuery off. `HideBushClient`: see-through for the hider, other players' default names hidden inside (carry nameplate still shows).
- **Treadmill bonus rolls.**
  - One roll per 360 s (6 min, R124; was 600) of treadmill time. Saved progress lives in `Premium.TreadmillBonusProgress`.
  - Up to 2 ready rolls; they are session-only and lost on leave.
  - A CS:GO-style strip with a click per card. The server decides the result and grants the pack via `PlayerData:AddChest`.
  - Pool is cumulative by best treadmill: Forest → +Jungle → … → Storm = all 7 biomes. Void and Mech packs are never included.
  - Odds (R124, owner): Secret = Void Pack (always Storm) 0.1%, Mythic 0.5%, Legendary 2%; Common 43.5 / Uncommon 28.6 / Rare 17.2 / Epic 8.1 (old 38:25:15:7 shape). Mech never. No "Packs from" line in the window (owner).
- **Giving.** Fruit, seeds and packs can be given to a nearby player. Durable DataStore inboxes: `ChestChase_FruitInbox_v1`, `ChestChase_SeedInbox_v1`. Recovery runs every 60 s, on join, and after a send.
- **Shop.**
  - Prices read "N Robux" with no icon.
  - No gift buttons and no DOUBLE SPEED banner.
  - Products: cash/speed bundles, Mech packs x1/x5/x10, game passes, gem perks.
- **Rarity.** Shown only by per-rarity card borders (`GardenCardMotion.Rarity`). Emblems are removed.
- **Economy, gear and leaderboard.**
  - About 200 h of play to reach the top treadmill, boot and trail (R117).
  - The leaderboard shows the top 100 and scrolls (R118).

## 4. Architecture Map

| Area | Owner script(s) (`src/…`) | Notes / interfaces |
|---|---|---|
| Bootstrap | `ServerScriptService/ChestChaseServerMain.server.lua` | Construct/start order. Sets `chaseService.TrackHoles/Gifts/TreadmillBonus` for owner commands |
| Config | `ChestChaseServer/Config.lua` | Version line 732. `RouteBalance83.ApplyConfig` runs last. Contains non-ASCII bytes, so patch by bytes |
| Map | `MapService`, `TrackExpansion83`, `ForestLayout87`, `FloorSafety86` | `TrackHalfWidth` ≈ 114. Do not save the expanded map |
| Chase / keepers | `ChaseService` + `ConcurrentKeeperService` (mixin) | Per-keeper locks. `Finish(false,true,run,hit)` is the drop path. `_applyGuardianFling`; `HitRemote` → clients |
| Ragdoll | `RagdollService` | `Apply(player,velocity,cause,stunSeconds)`. `KeepOnTrack` for `cause=='Keeper'` |
| Keeper art / anim | Server `KeeperStrikeFrames`/`K.Frames` (hit timing, **frozen**). Client `BeastAnimation`, `KeeperSignatureStrike` (new), `KeeperFx`, `KeeperHitEffects`. Models: `BeastModels`, `KeeperRigConfig` | Unique strikes are a client-only layer |
| Event | `VeiledEvent81` (server), `VeiledEventClient81`, `VeiledArrivalFx`, `VoidPackFx`, `EclipsePackArt`, `WorldStatusHud` card | Publishes the `VeiledNextAt`, `VeiledPacksLeft` and `VeiledUnstolenRefreshes` map attributes |
| Packs / inventory | `ChestService`, `SeedPackRules`, `PlayerDataService:AddChest`, `Hotbar.client`, `SeedPackClient` | `SyncTools` after any grant |
| Data | `PlayerDataService`, `PremiumProgress` (Premium sub-table; `Decode` keeps unknown keys), `PassGiftState` | `ProfileVersion` 20. Old R121 fields (`SpeedBoostEndsAt`, `Product*`) are ignored but kept |
| Holes | `TrackHoleService`, `TrackHoleConfig`, `TrackHoleClient`, `DigSoundVariants`, `DigSoundAnalyzer` | Remote via `SecurityGate` |
| Bonus rolls | `TreadmillBonusService` (`GrantReady`/`SetProgress`/`Pool`/`Roll`), `TreadmillBonusRules`, `TreadmillBonusClient` | Counts only `BaseService.TrainingSessions`. Remote `TreadmillBonusRoll` |
| Gifts | `FruitGiftService` (fruit / seed / pack), `PassGiftService` (game-pass gifts) | Outbox → inbox → ack → final |
| Robux | `PremiumService`, `PremiumRouting`, `PremiumPricing`, `MechCatalog`, `GamePassService`, `GamePassClient`, `PremiumShopArt` | `ProcessReceipt` saves before granting |
| Owner commands | `StudioTestCommands` (dispatcher, `/test` `/cctest` F4), `OwnerUpdateCommands82`, `OwnerPlayerCommands`, `OwnerCommandTargets82` (`@target`, global list), `OwnerCommandAccess` (owner + `AdminUserIds` attribute), `StudioTestHelp`, `StudioTestClient` | Access is checked server-side on the caller |
| Audio / FX | `LocalSfx` (35 ms / 6 stud dedupe), `SoundTiming`, `RarityRevealAudio`, `ClientFxBudget`/FastMode | Notes in `docs/proposals/audio_R123/SYNC_AUDIT.md` |
| Tooling | `tools/build_installer.py` (diff vs base, byte patches, hash-guarded, skips deleted scripts), `installer_engine.lua`/`installer_paste.lua` (refuses a different build's same-name backup), `installer_testdata.py` + `tests/test_installer.luau`, `tools/tests/roblox.luau` mock, `/opt/luau` CLI, luau-lsp | Build from a clean worktree at HEAD |

## 5. System-by-System State

Every row except Shop removals, Gifts, Owner commands and Installer uses "Implementation: yes (CURRENT); Runtime: UNKNOWN; Acceptance: none". Each row's Status column also names its evidence.

| System | Desired (latest) | Status | Truth layers |
|---|---|---|---|
| R123 installed in owner place | Correct build boots with no errors | UNKNOWN / VERIFY | Impl: yes. Runtime: the old build is likely installed and the server crashed. Acceptance: n/a |
| Shop removals (gift buttons, 2x banner, icon, "49 Robux"; R121 gift products and timed boost removed) | Removed | IMPLEMENTED (shop suites 6043 + 15) | Runtime: owner deleted the modules by hand; code dependency removed in the rebuilt R123 |
| Giving fruit / seeds / packs | Nearby give, durable | IMPLEMENTED (giving 152 + 11) | DataStores not live-tested |
| Rarity borders (no emblems) | Border per rarity | IMPLEMENTED (borders 2149; render `docs/proposals/borders_R123/borders_sheet.png`) | — |
| The Darkened event | As Section 3 | IMPLEMENTED (veiled 92 + 73 + 37; HUD 58) | — |
| Keeper fling + ragdoll | Higher per tier, inside walls, 2.7–3.3 s | IMPLEMENTED (fling safety; keepers 70/10/3479) | Feel unverified |
| Unique keeper hit animations | Distinct per keeper; server timing unchanged | IMPLEMENTED (`strikes_R123` 196 + 12; server frames diff 0; renders in `docs/proposals/strikes_R123`) | — |
| Shovel holes | As Section 3 | IMPLEMENTED (holes 106 + 66; R124 cooldown/tip) | Dig sound cut points unset until the owner runs the analyzer |
| Treadmill bonus rolls | As Section 3 | IMPLEMENTED (bonus 98 + 128 + 740; R124 odds, 6 min, window redesign; previews `docs/proposals/polish_R124/roll_window*.png`) | R124 not installed; look not owner-reviewed |
| Sound sync + FX polish | All sounds synced; effects polished | IMPLEMENTED (sync 22) | 7 sound ids have unmeasured lead-in silence |
| Garden step / refresh wall / blackout | Runners step onto bed edges; wall and cover sized to the track | IMPLEMENTED (wall 158, blackout 1255) | — |
| Keeper re-look (dragon, snow tiger, snake, gorilla) | Owner must approve renders first | PROPOSED | Proposal only: `docs/proposals/keeper_looks_R123/`; **not in `src/`** |
| Owner commands | Work on others (`@name`/`@all`) in public servers; redundant ones removed | IMPLEMENTED (bonus/holes command tests) | Published-server run not done |
| Installer safety | Hash-guarded; undo; refuses a different build's same-name backup; re-uses the same build's backup even without the `Build` attribute | IMPLEMENTED (installer 99; place mock 28) | Runtime: the stale-backup bug hit the owner once. Then the 06:04 guard falsely refused the owner's same-build backup (fixed) |

## 6. Current Active Task

| Item | Latest desired behavior | Starting status | Acceptance / next evidence |
|---|---|---|---|
| Install R123 correctly | Server boots on V150 R123 | IMPLEMENTED + edit-side VERIFIED (check_R123 at 14:46: version R123, nothing missing, backup Installed) | A clean Play run on R123 was not reported before R124 work started |
| Install R124 | Paste `installers/R124_install.lua` once; wait for `[R124] Installed.` before Play | BUILT, NOT INSTALLED | Owner Output + R124 test list |
| Biome notifier fade | Owner: biome notifier text should fade away | IMPLEMENTED (BiomeEntryNotifier: Frame + per-element fade; mock 8/8). Interpretation: the title already had a CanvasGroup fade that likely failed to render; not verified in Studio | Owner confirms it fades |
| Keeper sounds | Forest hammer + Jungle slam: 73468358342062 at the visual impact; The Darkened catch: 119010321306307 + purple sci-fi impact | IMPLEMENTED (mock 49/49) | Lead-in silence of both ids unmeasured (assets not downloadable here) |
| Bonus roll odds | Owner (2 Oct): "secret pack … just the cosmic pack at 0.1%, the mythic 0.5% and legendary 2%" | IMPLEMENTED in R124 (rest kept in the old 38:25:15:7 shape — an interpretation; owner may want other numbers) | Owner confirms after install |
| Keeper re-look | Refine the dragon, snow tiger, snake and gorilla. Show before/after first | PROPOSED | Owner yes/no/changes per keeper. The "before" renders are reconstructions; compare with Studio. Dragon is 127 parts (a ~100-part option exists) |
| Bonus progress bar placement | Owner asked for a bar "above the treadmill". Implemented: a billboard above the player's head while on the treadmill | UNKNOWN / VERIFY | Owner accepts, or wants it on the treadmill model |
| Ready-button behavior | Owner: "cover the screen in case where players don't press". Implemented interpretation: a prominent pulsing button, not a blocking overlay; missed time is lost past 2 ready rolls | UNKNOWN / VERIFY | Owner confirms that reading |
| Mech pack in bonus pool | Not requested; excluded | UNKNOWN / VERIFY | Owner confirms |
| Live test pass | Every feature, using `docs/COMMANDS.md` (test plan at the end) | APPROVED | Owner Studio run with 2 accounts |
| Dig sound cut points | Variants of sound 93793180254708 | APPROVED | Owner runs `require(game.ReplicatedStorage.DigSoundAnalyzer).Run()` in Play; see `docs/proposals/holes_R122/DIG_SOUND.md` |

## 7. Open Bugs / Verification Debt

1. **Owner place is on R121 with the gift modules deleted, so the server fails to start.** Evidence: uploaded `sapf.rbxl` (Section 1). The 06:04 installer falsely refused the same-build backup; fixed in the rebuilt installer. Next check: owner pastes it once, then runs `check_R123.lua`.
2. **`KeeperSignatureStrike` missing in Play: cause found.** It was Play started while the installer was still writing. Owner Output 14:34:31–34 shows a Play snapshot with entries 01–28 at R123 (`KeeperFx`, `ChaseService`, `ConcurrentKeeperService`, `Config` = V150 R123) and 41+ still R121 (`VeiledEvent81` lacks `PublishSchedule`, `ChestChaseServerMain`, `GamePassClient` requires `GiftProducts`). New scripts 61–71 were not moved yet. The edit-side one-line redo then finished: `[R123] Installed` at 14:34:34. Next check: a NEW Play after Save, plus `check_R123.lua`.
   - **Done in R124:** the installer engine prints "Installing... do not press Play until it says Installed." before writing (R124 and later builds; R123's embedded engine is unchanged).
3. **Plant visuals from the prior chat's snapshot** (Ice Berries, Ash Tomato, Dragonfruit, Glass Cactus, fuller bushes): APPROVED in the old handoff, with no implementation evidence in this repo's R110–R123 history. Next check: inspect `PlantArt*`/`PlantCatalog` and ask the owner if still wanted.
4. **Hold-E harvesting and clear inventory/garden commands:** implementation reported in the prior handoff; runtime never live-tested.
5. **V116 ragdoll-engine keeper catch:** live feel verification still outstanding. Later work (R122 fling heights, KeepOnTrack) builds on it.
6. **Animation id 114302219876492:** permission/ownership warning. `installers/find_asset.lua` locates it; owner action.
7. **Sound lead-in:** 7 sound ids (incl. 113339179211972 and the chase alarm) have unmeasured lead-in silence. Fix by setting `Start_<id>` on `SoundTiming` if late.
8. **Server biome particle emitters ignore FastMode/quality.** Proposal in `docs/proposals/audio_R123/EFFECTS.md`; needs a new client script.
9. **HUD refresh countdown repaints every 0.25 s,** so it can lag the beep by up to 250 ms. Minor.
10. **Gifting a held pack counts as an opening click;** the window to reclaim a dropped pack is short. Minor, unfixed.

## 8. Migration / Installer / Rollback State

- **Install chain.** R110 … R121 are sequential, each requiring the previous one. R122 was never released separately. **R123 requires R121** (base commit `9b13846`). It refuses if any patched script differs from R121 bytes.
- **Owner fix sequence** (Edit mode, Play stopped), for the place as uploaded:
  1. Run `require(game.ServerStorage.ChestChase_R123_Backup.Installer)("install")`. The backup there is this exact build (Installer hash `3558ed99…`, 71 After sources = `src/`). The engine re-checks every hash itself. Expect `[R123] Installed.`
  2. Save, then start a new Play session.
  3. Do NOT use the full paste for this. The owner's paste of the 324,915-byte `R123_install.lua` was cut after line 99 (~324,046 chars), giving `CommandBar:100: Expected 'end' (to close 'do' at line 77), got <eof>`. That is reproduced offline by truncating at 324,046 bytes. Nothing ran.
  4. If the backup is ever lost: build a split (2-part) R123 paste. Not built yet.
- **Scripts removed from source:** `GiftProducts`, `SpeedBoost`, `ProductGiftService`, `ProductGiftState`.
  - The owner deleted all four (confirmed in the uploaded place).
  - The installer never touches deleted scripts. Leftovers are unused and safe to delete.
- **Paste-script rule (new):** a same-name backup from a **different build** is refused with undo steps. The same build pasted again re-runs install, which is harmless.
- **Every backup:** `ServerStorage/ChestChase_R1xx_Backup` holds an `Installer` module; `("undo")` / `("install")`.
  - New scripts are parked inside the backup when undone.
  - Hand edits after install block undo ("later edits").
- **Building an installer:**
  - Command: `python3 tools/build_installer.py R124 ChestChase_R124_Backup installers/R124_install.lua --base <R123 source commit>`, from a clean `git worktree` at HEAD.
  - Test with `tools/installer_testdata.py` + `tools/tests/test_installer.luau`.
  - Builds take ~3–5 min (large Config).
- **Size.** The owner's paste path truncates at ~324,000 characters. A 323,944-byte paste got through; a 324,915-byte one was cut after line 99 and failed to parse (not "damaged while copying": truncation before the end is a syntax error, and nothing runs). Keep every paste under ~300 KB; split anything larger.

## 9. Regression Guardrails

- **Server authority.** Every grant, roll, hole, gift and command is decided server-side. Remotes go through `SecurityGate`. `OwnerCommandAccess` is checked on the caller, and replicated attributes are never credentials.
- **Keeper rules.** Keeper hit timing and reach are frozen: server `K.Frames`/`KeeperStrikeFrames` must stay byte-identical unless a change is explicitly requested. The keeper-to-thief lock and multi-thief concurrency are preserved.
- **Persistence.** `ProfileVersion` 20; stable seed/pack IDs. `PremiumProgress.Decode` keeps unknown keys. Old saves with R121 fields must still load. Never acknowledge a Robux receipt before a successful save.
- **Map.** Never save the expanded map. Fling landings stay inside |X| < 89. Track lengths and encounter coordinates stay synchronized.
- **Halo.** The Void Pack keeps its halo (explicit owner decision).
- **Performance.** Effects respect FastMode, Reduced Motion and the `ClientFxBudget` tier. No new per-frame server loops.
- **Garden flow.** Planting, harvest, sell, save/rejoin and crowded-garden performance stay unaffected.
- **Every release ships with:**
  - all scripts compiling (`luau-compile`);
  - the manifest matching the files;
  - the full suite list in Section 11 passing;
  - an installer mock test.

## 10. Deprecated / Superseded / Do Not Reintroduce

| Item | State |
|---|---|
| R121 gift products (`GiftProducts`, `ProductGiftService`/`State`) and 10-minute x2 boost (`SpeedBoost`, `RobuxBoost`) | DEPRECATED. Owner deleted them; do not re-add |
| Gift buttons in the shop; DOUBLE SPEED banner; Robux icon on prices | DEPRECATED |
| Rarity emblems (`GardenTheme.Icon`/`Badge`) | DEPRECATED, replaced by borders |
| "The Veiled One" display name | SUPERSEDED by "The Darkened" (internal names unchanged) |
| Void Pack halo removal | SUPERSEDED: the halo stays |
| `/test balance84`; duplicate help rows (`eclipse` = `void`, 3× `rarepacks`) | DEPRECATED (the `eclipse` alias still works) |
| Treadmill name labels | DEPRECATED (R119) |
| Seed-inbox poll every 15 s | SUPERSEDED by 60 s plus on join / after a send |
| Bonus roll every 15 min, "Uncommon or higher"; then 10 min with spawn-weight odds 38/25/15/7/10/5 | SUPERSEDED by 6 min with R124 odds (Section 3) |
| Permanent shovel hint line "Click the ground to dig a hole (n/4)…" | DEPRECATED (R124: fading tip) |
| "Packs from: Forest, Jungle…" line in the roll window; full-panel white flash on special results | DEPRECATED (owner, R124) |
| Pasting the 324 KB R123 installer | DO NOT: the owner's paste path truncates at ~324,000 characters; use the one-line redo, keep pastes < 300 KB |
| First R123 build (~320 KB) | SUPERSEDED; never reinstall it |

## 11. Testing / Acceptance Checklist

**Deterministic (offline, establishes Implementation only).** All passed on the R124 source (2 Oct). New in R124: `bushes_R124` 112, `polish_R124` 49 + 8 + 11 (keepers, notifier, perf), wall `run_wall.sh` 168; bonus 98 + 128 + 740; holes 106 + 66; borders 2137; installer R124 48. Previews: `sh docs/proposals/polish_R124/tests/preview.sh`.

- `luau-compile` on all 448 scripts; `MANIFEST.tsv` matches the files.
- Suites via `sh docs/proposals/<suite>/tests/run.sh`:

  | Suite | Checks |
  |---|---|
  | `shop_R120` | 6043 + 15 |
  | `giving_R122` | 152 + 11 |
  | `veiled_R122` | 92 + 73 + 37 |
  | `holes_R122` | 106 + 64 |
  | `treadmill_bonus_R123` | 90 + 93 + 740 |
  | `borders_R123` | 2149 |
  | `audio_R123` | 22 |
  | `trails_R117` / `trails_R118` | 241; 174 + 241 |
  | `boots_R117` | 374 + 637 |
  | `perf_R121` | 0 mismatches |

- Scratch-harness suites, each built from repo test files plus `tools/tests/bundle.py`:

  | Suite | Checks |
  |---|---|
  | Keepers (`keepers_R113` + `strikes_R123`) | 70 / 10 / 3479 / 196 / 12 |
  | Treadmills (`treadmills_R117`) | 518 |
  | Inventory / tabs / wallet | 68 / 44 / 11 |
  | Planting | 70 + 6 |
  | Fruit bonus | 9 |
  | Leaderboard (`leaderboard_R118`) | 22 |
  | Fast travel (`tools/tests/test_fast_travel.luau`) | 59 |
  | HUD | 58 |
  | Wall / blackout | 158 / 1255 |

- Installer: 99. Installer against the uploaded `sapf.rbxl`: 28 (scratch harness built from the place file with `tools/rbxl.py`).

**Live / runtime (owner in Studio; Test > Clients and Servers, 2 players).** Follow the "Test plan by feature" in `docs/COMMANDS.md`:
- Bonus rolls: progress save, the 2-roll cap, loss on leave, pool by tier, strip and clicks, the Legendary/Mythic effect.
- The Darkened: 2 packs, leaves after the last, reroll after 3 refreshes, arrival sound and lights-out, the "ARRIVES IN" timer.
- Holes: trap carriers only, 4 s, pack drops, 4-hole cap, cover, 3 min expiry.
- Fling heights per tier and landing inside the walls.
- Each keeper's unique hit.
- Gifting fruit, seed and pack.
- Borders on every rarity.
- Shop wording.
- Sound sync.

**User acceptance:** recorded separately per feature after the owner reviews it. None recorded yet.

## 12. Next Recommended Action

1. Owner installs R124 (Edit mode, Play stopped, one paste; wait for `[R124] Installed.`), saves, starts a new Play, and sends Output.
2. Owner runs the R124 test list in `docs/releases/R124.md` and reviews the previews in `docs/proposals/polish_R124/`.
3. Open owner decisions: keeper re-look approval; whether the Common–Epic split (43.5/28.6/17.2/8.1) is right; sound `Start_<id>` trims if the new sounds play late.
4. Then R125 … R133 (`docs/releases/R125.md` … `R133.md`), in order, each waiting for its `Installed.` line.
5. Owner checks in Studio how dark The Darkened's lights-out looks (tunables in R127.md) and how the 60% keeper strike range feels (R128.md).
6. The R130 performance pass is done (`docs/proposals/R130/PERF_REPORT.md`); a live MicroProfiler capture before/after would show the real gain. Open question: should weather pack mutations on the track be limited to the base too (R129)?
7. Next: only what the owner asks or the live test finds.

## 13. Fresh-Conversation Bootstrap Block

Treat the MASTER HANDOFF above as the authoritative current project context. Current truth overrides older assumptions.
- **Before changing anything:**
  - Identify the authoritative build and files: repo `src/` at the stated commit, and the owner's installed place as reported by Output or `check_R123.lua`.
  - Keep desired behavior, implementation/source, runtime/installed state and user acceptance separate.
  - Preserve the guardrails in Section 9.
- **Status rules.** Do not mark work IMPLEMENTED or VERIFIED without evidence. Offline mock tests prove Implementation only.
- **Active task.** The active task is Section 6. Older work is verification debt unless the owner reactivates it.
- **Delivery.** Ship changes as one hash-guarded installer per release, built from a clean worktree, with release notes that say exactly what was run versus reasoned.
- **Owner communication.** The owner wants short, plain answers.
- **Workflow.** Use the minimum workflow depth the risk needs. Use real subagents only if the environment supports them. Treat the compliance table as a self-audit, not independent review.

## 14. Generation Compliance Check (self-audit, not independent review)

| Compliance item | Result / evidence |
|---|---|
| Authoritative build/source established | PASS. Repo commit, `Config.lua:732`, installer bytes and base named. The installed state is marked UNKNOWN from the owner's 13:57 Output |
| Truth layers kept distinct | PASS. Section 5 separates Impl/Runtime/Acceptance; no runtime or acceptance claimed |
| Lifecycle statuses evidence-based | PASS. Section 6 uses only the STATUS enum. Keeper re-look is PROPOSED, not IMPLEMENTED; features are IMPLEMENTED, not VERIFIED |
| Latest-user delta reconciled | PASS. The owner's last 3 messages (bonus spec, "darkened", the commands request, the "it's meant to be removed" crash) are reflected in Sections 5, 6, 8 and 10 |
| Architecture/invariants protected | PASS. Section 4 owners/interfaces; Section 9 covers frozen strike frames, persistence, map save rule, server authority |
| Capability claims truthful | PASS. Borders, keeper strikes, audio, bonus rolls and keeper previews were built by background subagents (same model family) in this session. Their results were re-run here by test suites only. No Studio runs |
| Ambiguity preserved | PASS. Odds wording, "cover the screen" and "above the treadmill" are quoted with interpretations labeled UNKNOWN / VERIFY |
| History compressed without continuity loss | PASS. R110–R121 collapsed into current design. V116 debt and old plant-visual seed rows kept in Section 7 |
| Budgets/evidence scope respected | PASS. Offline checks are labeled Implementation-only. Debt is at 10 items; deprecated at 10 |
| Fresh-model continuation test | PASS. Repo, branch, tools, install sequence, test commands and open decisions are all named; nothing needs to be reconstructed from chat |
| Installer stale-backup hazard recorded | PASS. Sections 2, 7 and 8 document the cause and the new refusal rule |
