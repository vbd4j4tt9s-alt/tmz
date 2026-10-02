# CHEST CHASE / "Steal A Pack" — MASTER HANDOFF (R123)

Generated 2 Oct 2026 from the Claude Code session that built R114–R123, following MASTER HANDOFF GENERATION PROMPT V4.1.

Revision changelog
- R123 handoff: replaces docs/HANDOFF.md (29 Sep, R107/R110 era) as the current master. The baseline moves from "V149 prepared" to "V150 R123 source".
- R123 handoff: the V4.1 Section 6 plant-visual seed rows are moved to verification debt (no evidence they were worked in this repo). The newest user tasks are reconciled into Section 6.

---

## 1. Executive Project State

- **The game.** Roblox game "Steal A Pack" (internal name Chest Chase). The loop: steal seed packs from 7 keeper-guarded biome tracks, run back past the safe line, open the pack, plant, harvest, sell, and buy upgrades (treadmill, boots, trails, fence). Then push to higher biomes.
- **Source of truth.** Git repo `vbd4j4tt9s-alt/tmz`, branch `claude/chest-chase-handoff-f04hg8`.
  - Scripts are exported Rojo-style under `src/`: `*.server.lua` = Script, `*.client.lua` = LocalScript, `*.lua` = ModuleScript.
  - `src/MANIFEST.tsv` lists every script: 448 rows, matching the files.
- **Source version.** `Config.Version='V150 R123'`, `ProfileVersion=20`. Source is CURRENT at commit `fae4310`. The last source change was the commit before it; `fae4310` only added the rebuilt installer.
- **Delivery.** Each release is one paste-into-Command-Bar installer with a backup and undo (`installers/R1xx_install.lua`). The owner installs them in Studio. The assistant can't run Studio.
- **Installed (runtime) state: UNKNOWN / VERIFY.**
  - The last owner Output (13:57) showed `V150 R123` running the first, superseded R123 build. The server failed to start because `PremiumRouting` requires `GiftProducts`, which the owner had deliberately deleted.
  - The owner was given these fix steps:
    1. Undo the old R123 backup.
    2. Delete `ServerStorage.ChestChase_R123_Backup`.
    3. Paste the rebuilt `installers/R123_install.lua`.
  - No confirmation has come back yet.
- **Truth layers.**
  - All R122/R123 features are IMPLEMENTED: present in source, passing offline mock tests.
  - None is VERIFIED at runtime.
  - None is user-accepted, apart from the rename and shop wording the owner explicitly asked for (code exists; result not reviewed).
- **Active task.**
  1. Get the correct R123 build installed and booting.
  2. Owner decisions: bonus-roll odds and keeper re-look approval.
  3. Live test pass using `docs/COMMANDS.md`.
- **Owner preferences.**
  - Casual and short. Wants results, not theory.
  - One installer per release, with backup and undo.
  - Never ship silently untested: always say what was run versus only reasoned.

## 2. Authoritative Build / Source Inventory

| Item | Value / evidence | Freshness |
|---|---|---|
| Source | Repo `src/` at `fae4310`; `Config.lua:732` reads `Config.Version='V150 R123';Config.ProfileVersion=20` | CURRENT |
| Last confirmed installed release | R121 (owner Output 13:42 showed `[V149 R121]`) | STALE (owner then installed R123 builds) |
| R123 installer | `installers/R123_install.lua`, 324,481 bytes, 71 scripts. Base = R121 commit `9b13846`. Mock install test 94/94 | CURRENT |
| Superseded R123 build | The first build (~320 KB) still required `GiftProducts`. Its backup in the owner's place made later pastes re-run it | SUPERSEDED, possibly still installed |
| Place check | `installers/check_R123.lua`: read-only; prints version, missing new scripts, leftovers, backup states | Not yet run by owner |
| Older reference | `docs/HANDOFF.md`: map geometry, startup order, R107–R110 notes | Historical; geometry notes still valid |
| Release notes | `docs/releases/R110.md`–`R121.md`, `R123.md` (R122 was folded into R123) | CURRENT |
| Mismatch | Owner Output showed `KeeperSignatureStrike is not a valid member of ReplicatedStorage` with the old build. Cause unknown; possibly a partial or stale-backup state | UNKNOWN / VERIFY |

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
  - Max 4 per player, 3.4 studs wide, 3-minute lifetime.
  - They trap only pack carriers: 4 s ragdoll, and the pack drops.
  - Slots free up on a trap, a cover, expiry, a refresh or leaving.
  - Not allowed on pack pads, keeper camps, The Darkened's home or its Void Packs, or the entrance.
- **Treadmill bonus rolls.**
  - One roll per 600 s of treadmill time. Saved progress lives in `Premium.TreadmillBonusProgress`.
  - Up to 2 ready rolls; they are session-only and lost on leave.
  - A CS:GO-style strip with a click per card. The server decides the result and grants the pack via `PlayerData:AddChest`.
  - Pool is cumulative by best treadmill: Forest → +Jungle → … → Storm = all 7 biomes. Void and Mech packs are never included.
  - Current odds are the track spawn weights 38/25/15/7/10/5 (Common → Mythic). See Section 6 for the open question.
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
| Shovel holes | As Section 3 | IMPLEMENTED (holes 106 + 64) | Dig sound cut points unset until the owner runs the analyzer |
| Treadmill bonus rolls | As Section 3 | IMPLEMENTED (bonus 90 + 93 + 740) | Odds question open |
| Sound sync + FX polish | All sounds synced; effects polished | IMPLEMENTED (sync 22) | 7 sound ids have unmeasured lead-in silence |
| Garden step / refresh wall / blackout | Runners step onto bed edges; wall and cover sized to the track | IMPLEMENTED (wall 158, blackout 1255) | — |
| Keeper re-look (dragon, snow tiger, snake, gorilla) | Owner must approve renders first | PROPOSED | Proposal only: `docs/proposals/keeper_looks_R123/`; **not in `src/`** |
| Owner commands | Work on others (`@name`/`@all`) in public servers; redundant ones removed | IMPLEMENTED (bonus/holes command tests) | Published-server run not done |
| Installer safety | Hash-guarded; undo; refuses a stale same-name backup | IMPLEMENTED (installer 94) | Runtime: the stale-backup bug hit the owner once |

## 6. Current Active Task

| Item | Latest desired behavior | Starting status | Acceptance / next evidence |
|---|---|---|---|
| Install R123 correctly | Server boots on V150 R123 with no `GiftProducts`/`SpeedBoost`/`KeeperSignatureStrike` errors | UNKNOWN / VERIFY | Owner runs the 3 fix steps (Section 8) and sends Output plus the `check_R123.lua` lines |
| Bonus roll odds | Owner wording: "same rarities as the already existing percentages for seeds regarding the packs it just common to mythic". Earlier: "mythic ≈0.5% and legendary 2". Implemented interpretation: track spawn weights 38/25/15/7/10/5 | UNKNOWN / VERIFY | Owner confirms 10% / 5% or 2% / 0.5%; it's a one-line change in `TreadmillBonusRules` |
| Keeper re-look | Refine the dragon, snow tiger, snake and gorilla. Show before/after first | PROPOSED | Owner yes/no/changes per keeper. The "before" renders are reconstructions; compare with Studio. Dragon is 127 parts (a ~100-part option exists) |
| Bonus progress bar placement | Owner asked for a bar "above the treadmill". Implemented: a billboard above the player's head while on the treadmill | UNKNOWN / VERIFY | Owner accepts, or wants it on the treadmill model |
| Ready-button behavior | Owner: "cover the screen in case where players don't press". Implemented interpretation: a prominent pulsing button, not a blocking overlay; missed time is lost past 2 ready rolls | UNKNOWN / VERIFY | Owner confirms that reading |
| Mech pack in bonus pool | Not requested; excluded | UNKNOWN / VERIFY | Owner confirms |
| Live test pass | Every feature, using `docs/COMMANDS.md` (test plan at the end) | APPROVED | Owner Studio run with 2 accounts |
| Dig sound cut points | Variants of sound 93793180254708 | APPROVED | Owner runs `require(game.ReplicatedStorage.DigSoundAnalyzer).Run()` in Play; see `docs/proposals/holes_R122/DIG_SOUND.md` |

## 7. Open Bugs / Verification Debt

1. **Owner place may still run the superseded R123 build, so the server fails to start.** Evidence: Output 13:57. Next check: the fix steps, then `check_R123.lua`.
2. **`KeeperSignatureStrike` missing in Play** with the old build. Cause unknown. Next check: `check_R123.lua` "missing" line after a correct reinstall.
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
- **Owner fix sequence** (Edit mode, Play stopped):
  1. `require(game.ServerStorage.ChestChase_R123_Backup.Installer)("undo")`
  2. Delete `ServerStorage.ChestChase_R123_Backup`.
  3. Paste the rebuilt `R123_install.lua`.
  4. Save, then start a new Play session.
- **Scripts removed from source:** `GiftProducts`, `SpeedBoost`, `ProductGiftService`, `ProductGiftState`.
  - The owner already deleted at least the first two.
  - The installer never touches deleted scripts. Leftovers are unused and safe to delete.
- **Paste-script rule (new):** a same-name backup from a **different build** is refused with undo steps. The same build pasted again re-runs install, which is harmless.
- **Every backup:** `ServerStorage/ChestChase_R1xx_Backup` holds an `Installer` module; `("undo")` / `("install")`.
  - New scripts are parked inside the backup when undone.
  - Hand edits after install block undo ("later edits").
- **Building an installer:**
  - Command: `python3 tools/build_installer.py R124 ChestChase_R124_Backup installers/R124_install.lua --base <R123 source commit>`, from a clean `git worktree` at HEAD.
  - Test with `tools/installer_testdata.py` + `tools/tests/test_installer.luau`.
  - Builds take ~3–5 min (large Config).
- **Size.** About 324 KB. If the Command Bar truncates the paste, it refuses with "damaged while copying"; split into two releases.

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
| Bonus roll every 15 min, "Uncommon or higher" | SUPERSEDED by 10 min, Common–Mythic (odds still open) |
| First R123 build (~320 KB) | SUPERSEDED; never reinstall it |

## 11. Testing / Acceptance Checklist

**Deterministic (offline, establishes Implementation only).** All passed at `fae4310`'s source.

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

- Installer: 94.

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

1. Get the owner's Output after the fix steps (Section 8) plus the `check_R123.lua` lines. Don't build new features until V150 R123 boots cleanly.
2. Resolve the Section 6 questions: bonus odds, keeper re-look approval, progress-bar placement, button interpretation, Mech in the pool.
3. Then ship R124 with only the approved deltas:
   - odds change;
   - approved keeper models (`BeastModelsRefined` → `BeastModels` routing, a version bump to 123, and the KeeperAccents Ice Fang shard removal per `docs/proposals/keeper_looks_R123/NOTES.md`);
   - any fixes from the live test.

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
