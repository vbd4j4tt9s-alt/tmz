const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, HeadingLevel, AlignmentType,
  WidthType, ShadingType, BorderStyle, LevelFormat, Header, Footer, PageNumber,
} = require('docx');

const FONT = 'Arial';
const W = 10080; // content width (Letter, 1.05" margins)
const out = process.argv[2];

const P = (text, opts = {}) => new Paragraph({
  spacing: { after: 80, ...(opts.spacing || {}) },
  alignment: opts.align,
  children: runs(text, opts),
});
function runs(text, opts = {}) {
  // **bold** segments
  const parts = String(text).split(/(\*\*[^*]+\*\*)/g).filter(Boolean);
  return parts.map(s => s.startsWith('**')
    ? new TextRun({ text: s.slice(2, -2), bold: true, font: FONT, size: opts.size || 19, color: opts.color })
    : new TextRun({ text: s, font: FONT, size: opts.size || 19, italics: opts.italics, color: opts.color }));
}
const H1 = t => new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 260, after: 100 }, children: [new TextRun({ text: t, font: FONT })] });
const H2 = t => new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 160, after: 80 }, children: [new TextRun({ text: t, font: FONT })] });
const B = (t, lvl = 0) => new Paragraph({ numbering: { reference: 'bullets', level: lvl }, spacing: { after: 50 }, children: runs(t) });

const border = { style: BorderStyle.SINGLE, size: 4, color: 'B8C2CC' };
const borders = { top: border, bottom: border, left: border, right: border };
function table(widths, rows, header = true) {
  const total = widths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths: widths,
    rows: rows.map((r, i) => new TableRow({
      tableHeader: header && i === 0,
      children: r.map((c, j) => new TableCell({
        width: { size: widths[j], type: WidthType.DXA },
        borders,
        shading: header && i === 0 ? { fill: '1F3B57', type: ShadingType.CLEAR, color: 'auto' } : (i % 2 === 0 ? { fill: 'F3F6F9', type: ShadingType.CLEAR, color: 'auto' } : undefined),
        margins: { top: 50, bottom: 50, left: 90, right: 90 },
        children: String(c).split('\n').map(line => new Paragraph({
          spacing: { after: 30 },
          children: runs(line, { size: 16, color: header && i === 0 ? 'FFFFFF' : undefined }).map(x => x),
        })),
      })),
    })),
  });
}
const spacer = () => new Paragraph({ spacing: { after: 60 }, children: [] });

const C = [];
// ---------------------------------------------------------------- title
C.push(new Paragraph({ heading: HeadingLevel.TITLE, spacing: { after: 60 }, children: [new TextRun({ text: 'STEAL A PACK (CHEST CHASE) — MASTER HANDOFF', font: FONT })] }));
C.push(P('R151 • generated with the V4.1 master-handoff prompt • 5 Oct 2026 • repo vbd4j4tt9s-alt/tmz, branch claude/compassionate-brown-lohfok', { italics: true, color: '555555' }));
C.push(P('**Revision changelog**', { spacing: { before: 80 } }));
C.push(B('R151 handoff: replaces the V149 continuity anchor. Baseline = R151 source (Config.Version \'V150 R151\'), owner install in progress.'));
C.push(B('Adds the R151 systems (pull reveals, chat announcements, hub displays, Seed Festival Square, Cloudy sky, pack shapes, treadmill polish, speed popups) and the keeper-model proposal track.'));
C.push(B('Records the R151 part-2 install failure (BackgroundMusic editor draft) and the part-2b route.'));

// ---------------------------------------------------------------- 1
C.push(H1('1. Executive Project State'));
[
  '**Game.** Roblox game "Steal A Pack" (internal name Chest Chase). Players steal seed packs from 7 keeper-guarded biome tracks (keyboard-key track surface), cross the safe line, open packs for seeds (Common → King), plant / harvest / sell in their base garden, and train speed on treadmills to outrun faster keepers.',
  '**Authoritative source:** GitHub vbd4j4tt9s-alt/tmz, branch claude/compassionate-brown-lohfok, newest commit; `src/` + `src/MANIFEST.tsv` (541 rows). Config.Version = \'V150 R151\', ProfileVersion = 22. CURRENT.',
  '**Installed / runtime:** the owner\'s Studio place had R150 (INFERRED: R151 part 1 accepted every R150 hash). R151 install is IN PROGRESS: part 1 installed; part 2 failed on StarterPlayerScripts.BackgroundMusic (open editor draft) and its rollback reported "Restore incomplete". Owner was told: reopen WITHOUT saving → part 1 → part 2b → part 3 → part 4 → set two music ids by hand → Save. Outcome UNKNOWN / VERIFY.',
  '**Truth layers:** every R151 feature has Implementation established (source + 64 offline suites + installer mock tests). Runtime: unestablished (not yet played in Studio). User Acceptance: only at preview level (owner approved designs from rendered previews / GIFs; offline renders are not Roblox screenshots).',
  '**Active task:** (1) confirm the R151 install and run the Studio checklist; (2) keeper model redesign, proposal rev 6 (thicker Ice Fang torso, Storm Colossus as a real stone giant), then implementation via owner-uploaded FBX; (3) R151 follow-up fixes (review findings).',
  '**Owner working style:** short casual answers; say what was run vs reasoned; show previews before implementing visual changes; every release = installer(s) + docs/releases/RNNN.md + COMMANDS/HANDOFF update + Config.Version bump.',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 2
C.push(H1('2. Authoritative Build / Source Inventory'));
C.push(table([2600, 5980, 1500], [
  ['Item', 'Value / location', 'Freshness'],
  ['Source of truth', 'Repo vbd4j4tt9s-alt/tmz, branch claude/compassionate-brown-lohfok (newest commit). Scripts under src/; place paths in src/MANIFEST.tsv (sorted; one row per script).', 'CURRENT'],
  ['Version markers', 'Source: Config.Version=\'V150 R151\'; ProfileVersion=22. Installer part trees use \'V150 R151p1\' / \'p2\' / \'p3\' between parts. Owner place: expected \'V150 R151p1\' after part 1 (UNKNOWN / VERIFY).', 'CURRENT / UNKNOWN'],
  ['Last fully released base', 'R150 release commit 9a6c757 (owner\'s place matched it when R151 part 1 ran).', 'INFERRED'],
  ['R151 installers', 'installers/R151_install_part1.lua (28 scripts), part2b (31; replaces part2), part3 (26), part4 (33). installers/R151_part2_repair.lua (only for the old part-2 route). installers/R151_install_part2.lua = SUPERSEDED.', 'CURRENT'],
  ['Split recipe', 'docs/releases/R151_parts.txt. The part-tree commits (86275eb, 3362adf, 06220a6 = part-2b tree, 2428fa6) were LOCAL ONLY in the old container; rebuild them from the recipe if needed.', 'CURRENT'],
  ['Release docs', 'docs/releases/R151.md (owner notes + Studio checklist + known issues), R151_suites.txt, R151_parts.txt; docs/COMMANDS.md (all /test commands); docs/HANDOFF_MASTER_R124.md (rolling per-release notes, newest first).', 'CURRENT'],
  ['Design records', 'docs/proposals/R151/* (design docs, previews, test runners). Keepers: docs/proposals/R151/keepers/ (keepers.md, sheets, blender/ scripts, fbx/ 8 FBX + manifests).', 'CURRENT'],
  ['Tests', 'tools/tests/run_all_suites.sh (64 suites; REPO/LOGDIR/PLACE env); suite runners in docs/proposals/*/tests; Luau mock /opt/luau/luau + tools/tests/roblox.luau; installer mock tools/installer_testdata.py + tools/tests/test_installer.luau.', 'CURRENT'],
  ['Owner place file', 'sapkeyver.rbxl (an upload in the old chat) = R140 + daily + keyboard era. Used only for geometry / z-fight tests. Uploads do NOT carry over to a new chat: ask the owner to re-upload a current .rbxl if needed.', 'STALE'],
  ['Mismatches', 'The previous handoff\'s "V149 prepared" anchor is superseded. docs/HANDOFF_MASTER_R124.md says "R151 built, not installed" (true at writing).', 'CURRENT'],
]));

// ---------------------------------------------------------------- 3
C.push(H1('3. Core Game Loop and Current Design'));
[
  '**Loop:** spawn at base → run a biome track → steal a seed pack (hold E) → keeper wakes and chases → cross the safe line → pack goes to hotbar / Bag → open it (reveal) → plant in the base garden → harvest (fruit flies into the player) → sell at the market → buy upgrades → train speed on the treadmill → reach faster biomes.',
  '**Biomes / keepers (track order):** Forest Timber Golem, Jungle King (gorilla), Desert Sand Snake, Snow Ice Fang (tiger, R149 armour), Lava Dragon, Crystal Knight, Storm Colossus. "SPEED NEEDED" sign over each keeper. The Darkened = Void-pack event keeper (every 3rd track refresh; Secret-tier).',
  '**Track lengths progress with biome difficulty** (continuity anchor). Route, scenery, bounds, hazards, encounter coordinates stay in sync.',
  '**Keeper concurrency:** a keeper stays locked to its thief until that chase resolves; other players can still steal. A hit ragdolls and flings the thief (KnockbackConfig, RagdollService.KeepOnTrack).',
  '**Packs:** 7 biomes × 6 designs (42 uploaded pouch meshes, print in vertex colours) + Void, Mech (Robux), Verity (quest), mystery (daily pedestal), starter. Sizes 0.5x–25x. Every NEW pack rolls one of 6 chip-bag shapes (Pillow, Hourglass, Pear, Top-heavy, Shoulders, Flat) and keeps it for life.',
  '**Seeds:** Common, Uncommon, Rare, Legendary, Mythic, Secret, Cosmic, King. Odds always shown as 1/N whole numbers (owner rule). Hidden soft pity; starter pack hidden 2x luck.',
  '**Treadmill:** 7 levels (multipliers 1/4/20/100/600/4000/30000). One training step every 1/5 s (5 steps/s); +N/step = +20/+80/+400/+2K/+12K/+80K/+600K. Bonus rolls, gift timer, upgrade sign.',
  '**Hub:** Seed Festival Square (walls, murals, gate, streets, base arches, studded trees with no fruit and no collision, lamps), market, Verity (yellow ball NPC, quest), BEST PULL TODAY / BIGGEST FRUIT TODAY displays, Clear ↔ Cloudy sky cycle, event weather (rain / thunder / blizzard) with mutations.',
  '**Social / retention:** daily login rewards + quests, friend speed boost, offline growth + "plant is ready" notifications, chat-only pull announcements (Legendary+ in server, Secret+ all servers), Index, gifting.',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 4
C.push(H1('4. Architecture Map'));
C.push(table([2900, 3900, 3280], [
  ['Owner (src path)', 'Responsibility', 'Key interfaces / invariants'],
  ['ServerScriptService/ChestChaseServer/ChestChaseServerMain + Config', 'Boot order, all tunables, versions', 'Config.Version / ProfileVersion 22; GetTrainingAward; TrainingInterval 1/5'],
  ['PlayerDataService', 'Profiles, inventory, OpenSeedPack, HarvestPlant, item records', 'Server-only rolls; optional record fields TestGrant, PackShape; stack keys include PackShape'],
  ['ChestService / MapService / BiomeVisuals', 'World packs + biome refresh, map build, treadmill build (+ R151 dressing pass)', 'Pack builds must never yield on the server; MapService pcall-hooks HubDecor151, ZFightFix149'],
  ['ChaseService + ConcurrentKeeperService, KeeperRigConfig, KeeperUpgradeData, BeastPose, KeeperSignatureStrike, VeiledKeeper81', 'Keepers: rigs, pose groups, chase locks, catch', 'Per-keeper thief lock; catch by distance or visible part touch; poses drive part groups (BulkMoveTo)'],
  ['BaseService, GardenUpgradeService, TreadmillFx (client), SpeedGainPopup.client + SpeedPopupStyle', 'Training gain, upgrades, treadmill FX, speed popups', 'Label = real award; popups pooled, one RenderStepped updater; FormatGain K/M/B/T'],
  ['SeedPackVisuals / SeedPackRenderer / ItemPictures / PackShapes151 / VerityPouch151', 'Pack visuals in every context; EditableMesh shape bake; Verity neutral pouch', 'Same parts in every context; DefaultPackShape flag for shop/market pictures; fallback to the original mesh'],
  ['RarePullRules / Cinematic / Scenes / Card / Audio / Sounds / World, PackSuspense', 'Pull reveals for every rarity', 'RarePullRules = single timing source (server reveal delay reads it)'],
  ['PullAnnouncer (+Rules, Client), OwnerTestPacks', 'Chat announcements; cross-server via MessagingService PullAnnounce151', 'Chat only; after the puller\'s reveal; TestGrant packs never announce'],
  ['HubDisplayService / Store / Board / Avatar / Art, HubDisplayRules, HubDisplayClient', 'BEST PULL / BIGGEST FRUIT displays', 'MemoryStore HubDisplays151; records announced via PullAnnouncer.Announce'],
  ['HubDecor151, HubLife151.client, HubDecorKit151, HubLifeArt151, HubStudTrees151, HubTreeLoader151', 'Seed Festival Square, studded trees, owner tree assets', 'Only gate towers + saved walls collide; scripts stripped from loaded models; no fruit on trees'],
  ['WeatherService, WeatherCycle151, WeatherWorld149(.client), HubSnow151, SnowPatches149, BiomeMood, EnvironmentLighting', 'Event weather, Clear/Cloudy cycle, snow, lighting', 'EnvironmentLighting is the only writer of Lighting / Atmosphere / ColorCorrection'],
  ['KeyboardTrack + KeyboardTrack.client, KeyboardSurface149', 'Keyboard track surface (client-only keys)', 'Real floor hidden locally; near zone always drawn; Top-face canvas = depth × width, Rotation 270'],
  ['SocialService, DailyRewardsClient, OfflineGrowthNotice.client', 'Friends, plant-ready notifier (MemoryStore PlantReady140, Open Cloud), Esc text', '24 h cooldown; secret PlantReadyKey; MessageId attribute'],
  ['OwnerUpdateCommands82 + StudioTestCommands + StudioTestHelp', '/test owner commands', 'Actions table = union of keys; owner-only (IsAllowed)'],
  ['tools/build_installer.py, installer_engine.lua, installer_paste.lua', 'Paste-into-Command-Bar installers with backup / undo / redo', 'Hash-guarded byte patches; chunked StringValues (<200k chars each)'],
]));

// ---------------------------------------------------------------- 5
C.push(H1('5. System-by-System State'));
C.push(table([1700, 3500, 1250, 2230, 1400], [
  ['System', 'Desired behavior (implemented the same unless noted)', 'Status', 'Truth layers', 'Evidence / freshness'],
  ['Pull reveals', 'Secret / Cosmic / King story scenes (seed is the star, floats down); Common–Mythic ladder of equal quality; more suspense on every pack; owner-supplied sound ids', 'IMPLEMENTED', 'Impl yes; Runtime no; Accept: design approved from previews', 'run_rare_pull.sh; CURRENT'],
  ['Pull announcements', 'Chat only; Legendary+ in server, Secret+ all servers; sent after the puller\'s reveal shows the seed; owner test packs never announce; hub records announced', 'IMPLEMENTED', 'Impl yes; Runtime no; Accept no', 'run_announce.sh, static_checks.sh; CURRENT'],
  ['Hub displays', 'BEST PULL TODAY / BIGGEST FRUIT TODAY with avatar, cross-server, daily fruit rotation', 'IMPLEMENTED', 'Impl yes; Runtime no (MemoryStore live unverified)', 'run_hub_displays.sh; CURRENT'],
  ['Seed Festival Square + trees', 'Dressed hub; studded trees (owner assets 16637971059, 17280628013 loaded by id when allowed), no fruit, no collision', 'IMPLEMENTED', 'Impl yes; Runtime no; asset loading needs a Studio setting', 'run_base_area.sh, run_hub_trees.sh; CURRENT'],
  ['Weather / lighting', 'Clear ~8 min ↔ Cloudy ~6 min (dim, warm lamps); hub-wide blizzard drifts; fewer rain splashes', 'IMPLEMENTED', 'Impl yes; Runtime no', 'run_cloudy.sh, run_perf.sh, R149 run_weather.sh; CURRENT'],
  ['Keyboard track', 'Letters on every key; 1.15-stud press; FOREST/DESERT across the track; no missing keys near the player', 'IMPLEMENTED', 'Impl yes; Runtime no; legend rotation UNKNOWN / VERIFY', 'R149 run_keyboard.sh (465); CURRENT'],
  ['Treadmills + popups', 'Same shape + moving belt pattern (EditableImage), trims, studs, corner lamps, +N/step label, upgrade sign; 5 steps/s; popups pop/fling/fade, 10/s, white-ish colours kept', 'IMPLEMENTED', 'Impl yes; Runtime no; Accept: approved from previews', 'run_treadmills.sh, run_speed_popups.sh, shop_R120; CURRENT'],
  ['Packs', 'Per-pack chip-bag shape (EditableMesh deform of the real meshes); Verity pack = real pouch in pure yellow; giant packs no floating bars', 'IMPLEMENTED', 'Impl yes; Runtime no; EditableMesh permission / replication UNKNOWN / VERIFY', 'run_pack_shapes.sh, run_verity_pouch.sh, run_packs.sh; CURRENT'],
  ['Fruit / growth', 'No shine dots; Verity fruit one face; every fruit of all 65 seeds flies into the player on harvest', 'IMPLEMENTED', 'Impl yes; Runtime no', 'run_fruit_fixes.sh; CURRENT'],
  ['Verity NPC', 'No mouth; ball bounces with her voice; greeting cut at 2.35 s (a guess)', 'IMPLEMENTED', 'Impl yes; Runtime no; cut point needs ear tuning', 'R149 run_verity.sh; CURRENT'],
  ['Offline notifier / notices', 'Plant-ready notifications fixed (shutdown, paging, cooldown 24 h, retries); Esc rainbow "Plants grow offline"; daily login window opens itself', 'IMPLEMENTED', 'Impl yes; Runtime no; Open Cloud from game servers UNKNOWN', 'run_offline.sh; CURRENT'],
  ['UI badges', 'Whole round red badges (INDEX, DAILY, tabs, MENU), not clipped', 'IMPLEMENTED', 'Impl yes; Runtime no', 'run_badges.sh; CURRENT'],
  ['Chase music', 'Keeper chase = 90864299965930 (GTA track); The Darkened = 127003062753525 (intense)', 'IMPLEMENTED', 'Impl yes in source; NOT installed by part 2b — owner edits BackgroundMusic by hand', 'BackgroundMusic.client.lua; CURRENT'],
  ['Keeper models', 'Roblox-charm block builds, two faces (awake / asleep), no floating parts except Storm Colossus; rev 5 approved ("works"), rev 6 delta (sturdy Ice Fang, stone-giant Colossus) built as a proposal, not yet reviewed by the owner', 'APPROVED', 'Impl no (proposal only, no src changes); Runtime no; Accept: rev 6 pending', 'docs/proposals/R151/keepers (rev 6 ddd635b); CURRENT'],
]));

// ---------------------------------------------------------------- 6
C.push(H1('6. Current Active Task'));
C.push(table([1800, 3700, 1300, 3280], [
  ['Item', 'Latest desired behavior', 'Starting status', 'Acceptance / next evidence'],
  ['Finish R151 install', 'Owner place on R151: part 1 → part 2b → part 3 → part 4 (all four before Play), then BackgroundMusic CHASE_TRACK = rbxassetid://90864299965930 and SPECIAL_TRACK = rbxassetid://127003062753525 by hand, Save', 'IMPLEMENTED', 'Runtime: get the owner\'s Output lines ("[R151 part N] Installed.") and Config.Version \'V150 R151\'; then the Studio checklist in docs/releases/R151.md'],
  ['One-time Studio settings', 'Game Settings → Security: "Allow Loading Third Party Assets" (tree models), "Allow Mesh / Image APIs" (pack shapes, belts, melons); plant-notify setup (MessageId attribute, PlantReadyKey secret, HTTP)', 'APPROVED', 'Owner confirms; /test hubtrees, /test packshape, /test plantnotify outputs'],
  ['Keeper redesign rev 6', 'Ice Fang: fox head, thicker sturdier torso and legs. Storm Colossus: a real ancient stone colossus (massive boulders, craggy chest, huge stone fists, glowing storm cracks, moss, runes, stone crown, storm cloud) keeping today\'s identity and its floating pieces. Golem / Dragon / Knight as rev 5; Jungle King, Sand Snake, The Darkened frozen', 'APPROVED', 'Rev 6 proposal is on the branch (ddd635b, docs only): show keepers_before_after.png, keeper_ice_fang.png, keeper_storm_colossus.png; owner approves; then implementation (Section 12)'],
  ['Knight sword sleep pose', 'Rev 5 longsword point goes ~6 studs into the floor in the sleep pose; options: planted look (current), tilt ~50°, or shorter blade', 'UNKNOWN / VERIFY', 'Ask the owner when showing rev 6'],
  ['R151 follow-ups', 'Fix the Section 7 review findings; finish the phone / visual review that was cut short', 'APPROVED', 'Fix round + suites; send with the next release'],
]));
C.push(B('Owner ideas offered but not chosen (do not build unless asked): per-biome chase themes, distance-based chase intensity, chase stingers, high-stakes theme.'));

// ---------------------------------------------------------------- 7
C.push(H1('7. Open Bugs / Verification Debt'));
[
  '**R151 install state** in the owner place after the failed part 2 (rollback "Restore incomplete"). Next: owner Output after the part-2b route; Config.Version.',
  '**EditableMesh / EditableImage at runtime** (pack shapes, Verity pouch, R149 melons, treadmill belt patterns): permission setting and whether server-baked MeshParts replicate. Evidence for replication: the owner\'s screenshot of the smooth baked watermelon. Kill switches: /test packshape off; belt falls back to grid texture 6372755229.',
  '**Keyboard legends** read upright / in order is unproven: if upside down set KeyboardTrack.Config.Legend.Rotation = 90; if mirrored flip the sign in K.TopPoint.',
  '**Tree assets by id** (AssetService:LoadAssetAsync + AllowInsertFreeAssets) untested; fallbacks: InsertService (owner "Get Model"), manual folder ReplicatedStorage.HubTreeTemplates151, studded built trees.',
  '**Plant-ready notifications**: Open Cloud user-notification call from game servers may be refused; check /test plantnotify send.',
  '**Review A minors (not fixed):** owner-granted boots / seeds not treated as test (announce / hub boards); hub fruit-of-day mismatch can starve BEST PULL sync; SocialService Deliver blocks its loop on a backlog; quick re-equip during a shape bake can drop the pack; PackShapes151 LastFailure attribute names the design.',
  '**Review B (phones / visuals) unfinished:** phone frame cost of hub decor, snow, keyboard, cinematics, popups; lighting writers; UI on phones.',
  '**Tune by ear / eye:** Verity GreetingEnd 2.35 (/test verityvoice); dig sound segments (DigSoundAnalyzer, R150 notes); treadmill belt scroll sign (TreadmillLook151.Scroll.Sign); Cloudy brightness.',
  '**V116 ragdoll keeper-catch** live feel verification (carried debt from the earlier handoff; not the active task).',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 8
C.push(H1('8. Migration / Installer / Rollback State'));
[
  '**Safe start:** owner place at the R150 release (9a6c757 sources). R151 parts run strictly in order; each refuses unless the previous part is in (Config hash chain \'R151p1\' → \'p2\' → \'p3\' → \'V150 R151\'). Do not Play or publish between parts.',
  '**Backups:** ServerStorage.ChestChase_R151p1_Backup, ChestChase_R151p2b_Backup (ChestChase_R151p2_Backup if the old part 2 ever completed), _p3_, _p4_. Undo newest first: require(game.ServerStorage.<Backup>.Installer)("undo").',
  '**Partial state seen:** part 2 → "Mixed script versions", then "Restore incomplete; reopen your saved place". Cause: BackgroundMusic had an editor draft / open tab, so Source ≠ editor source. Rule: close script tabs and commit or discard Team Create drafts before pasting; never save a session after "Restore incomplete".',
  '**Persistence:** ProfileVersion 22 unchanged. New optional record fields: TestGrant (owner test packs) and PackShape (1–6). An R150 server ignores them (a re-saved pack loses its shape only).',
  '**Tooling:** build with python3 tools/build_installer.py "<label>" <BackupName> <out.lua> --base <rev> (diffs base → working tree; line diff first). Mock-test with tools/installer_testdata.py + tools/tests/test_installer.luau. Keep each paste ≲ 340 KB (split by intermediate local commits; recipe docs/releases/R151_parts.txt). Run the builder from the checkout it diffs (it uses its own repo root).',
  '**Retire list:** none in R151 (no scripts deleted since R150).',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 9
C.push(H1('9. Regression Guardrails'));
[
  'Server authority: rolls (packs, seeds, shapes, odds, pity) only on the server; no new client→server remote without validation; owner commands owner-only.',
  'ProfileVersion stays 22 unless a real migration is designed; stable seed / pack / plant ids.',
  'Keeper thief lock, catch rules, safe line, ragdoll clamp; keeper hitboxes unchanged by visual work (cosmetic parts flagged so catch checks skip them).',
  'Server pack builds never yield (PackShapes151 returns the default until baked); every visual fallback leaves today\'s look.',
  'Decor never collides (trees, props, treadmill dressing, hub displays) except the gate towers and saved walls; z-fighting 0 (docs/proposals/R149/tools/zfight.py).',
  'EnvironmentLighting stays the single Lighting writer; Cloudy, Darkened blackout, cinematics compose through it.',
  'Announcements chat-only, after the puller\'s reveal, test packs excluded. Odds shown as 1/N whole numbers; owner rounding preferences (multiples of 5, K formatting).',
  'Speed economy: points per second unchanged by the 1/5 s step; HUD multiplier chip ×1 at treadmill level 1 (shop_R120 test).',
  'Owner aesthetic: classic studded Roblox look, Roblox charm, no floating / dislocated parts (Storm Colossus excepted), keep shapes of existing assets when "improving".',
  'Pack pictures in shop / market / pedestal silhouette use the default shape; every other context shows the pack\'s own rolled shape.',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 10
C.push(H1('10. Deprecated / Superseded / Do Not Reintroduce'));
[
  'Index PACKS tab (scrapped by the owner; the default-shape plumbing stays).',
  'Pull announcement banners / sounds (chat only now).',
  'Per-design pack shapes (superseded by per-pack rolls); per-level treadmill multiplier tweak 1.2/3.9/20.1/… (superseded by the 1/5 s step).',
  'Fruit shine / gloss / glint parts; Verity two-faced fruit; Verity mouth and lip sync.',
  'Fruit or red "fruit-like" bits on hub trees; collision on hub decor.',
  'Tall treadmill gates / arches copied from references (owner: keep our treadmill shape).',
  'Keeper proposal revs 1–5 (bubbly / human-like faces, five face states, carved faces, original gorilla / snake, thin fox, plain colossus); superseded by rev 6.',
  'Old chase music "Playful Chase" 1839530854 and Darkened "Chaser" 9042664292.',
  'installers/R151_install_part2.lua for this owner (use part 2b).',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 11
C.push(H1('11. Testing / Acceptance Checklist'));
C.push(H2('Deterministic (offline, establishes Implementation only)'));
[
  'REPO=<checkout> LOGDIR=<dir> PLACE=<owner .rbxl> sh tools/tests/run_all_suites.sh → 64 suites PASS (R151: docs/releases/R151_suites.txt). The place file is required by a few suites (z-fight, base area, perf).',
  'Installer: build, then mock install / undo / redo per part (R151: 230 / 249 (2b) / 231 / 256 checks).',
  'For each change: the area\'s runner + its mutation mode where it exists; keep src/MANIFEST.tsv sorted with every new script.',
].forEach(t => C.push(B(t)));
C.push(H2('Live / runtime (needs the owner in Studio; establishes Runtime, not Acceptance)'));
[
  '/test rarepull king|cosmic|secret|common..mythic; open real packs; a Legendary+ pull: chat line after your reveal.',
  'Walk the hub (no tree collision at full speed), the two displays, /test weather cycle skip (Cloudy + warm lamps), /test weather blizzard.',
  'Keyboard: letters upright on every key, press, FOREST across the track, no bare floor after running back.',
  'Treadmill: belt moves with the arrows, +20/step at level 1, upgrade sign, popups; HUD ×2 with the pass.',
  'Harvest watermelon, Frost Fern, Verity fruit (flies in, slot flashes); packs show different chip shapes in hand / hotbar.',
  'Phone emulator frame rate in the hub, in a blizzard, on the keyboard. User Acceptance = the owner\'s own verdict, recorded separately.',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 12
C.push(H1('12. Next Recommended Action'));
[
  'Get the owner\'s R151 install result (Output lines). If anything refuses, read the message; never ask them to save after "Restore incomplete".',
  'Run the Section 11 live checklist with the owner; record Runtime / Acceptance per system; fix regressions first.',
  'Keepers: show the rev 6 previews (docs/proposals/R151/keepers). Changes need Blender again (pip install bpy==4.5.* into a venv; Cycles CPU only, EEVEE needs EGL; scripts in keepers/blender/, run.sh). After approval: owner imports the 8 FBX (docs/proposals/R151/keepers/fbx, 1 unit = 1 stud, facing -Z) with the 3D Importer and shares the mesh / texture ids; then wire them into the keeper builders keeping pose groups, hitboxes and catch rules; two faces via LocalTransparencyModifier.',
  'Then a fix round for the Section 7 review items + the unfinished phone / visual review → next release (R152) with installer, notes, Config bump.',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 13
C.push(H1('13. Fresh-Conversation Bootstrap Block'));
C.push(P('Treat this MASTER HANDOFF as the authoritative project context for "Steal A Pack" (Chest Chase). Current truth overrides older assumptions. Before changing anything, identify the authoritative build/files (repo vbd4j4tt9s-alt/tmz, branch claude/compassionate-brown-lohfok, newest commit; ask the owner for the installed state); separate desired behavior, implementation/source, runtime/installed state, and user acceptance; preserve the Section 9 guardrails; do not mark work IMPLEMENTED or VERIFIED without evidence. The active task is Section 6; older items stay verification debt unless reactivated. Use the minimum workflow depth for the risk. Use real agents/subagents/model routing only if the environment supports and invokes them. Treat Section 14 as a self-audit, not independent review.'));
C.push(P('**Project conventions:**', { spacing: { before: 60 } }));
[
  'Work and push only on branch claude/compassionate-brown-lohfok; no pull requests unless asked; never bare `git stash`.',
  'Commit messages end with the session\'s attribution trailer lines (owner rule); never put model ids in commits or repo files.',
  'Owner preference for delegation: a cheaper model for coding, the strongest model for reviews and complex work (only if the environment actually provides agents).',
  'Every release: installer(s) sent as files + docs/releases/RNNN.md (plain-English owner notes) + docs/COMMANDS.md + docs/HANDOFF_MASTER_R124.md line + Config.Version bump; say what was run vs reasoned; offline renders are labeled approximate.',
  'Visual changes: show previews (rendered stand-ins clearly labeled) before implementing; follow owner references closely but never copy other games\' assets 1:1.',
  'Scratch / Blender venv / owner uploads live in an ephemeral container: re-create or re-request them.',
].forEach(t => C.push(B(t)));

// ---------------------------------------------------------------- 14
C.push(H1('14. Generation Compliance Check'));
C.push(table([3000, 1000, 6080], [
  ['Compliance item', 'Result', 'Evidence'],
  ['Authoritative build/source established', 'PASS', 'Source = repo branch newest commit with Config \'V150 R151\'; owner installed state stated as INFERRED R150 + R151 in progress (UNKNOWN).'],
  ['Truth layers kept distinct', 'PASS', 'Section 5 lists Impl / Runtime / Accept separately; previews are not acceptance.'],
  ['Lifecycle statuses evidence-based', 'PASS', 'Section 6 uses only the STATUS enum; no R151 item marked VERIFIED.'],
  ['Latest-user delta reconciled', 'PASS', 'Part-2 failure + 2b route, manual music ids, keeper rev 6 (built, awaiting review), Index tab scrapped, all represented.'],
  ['Architecture/invariants protected', 'PASS', 'Sections 4 and 9: server authority, ProfileVersion 22, keeper locks, no-yield builds, single Lighting writer, collision rules.'],
  ['Capability claims truthful', 'PASS', 'Real subagents and Blender were used in the old session; reviews were same-model fresh-context passes; review B unfinished is stated.'],
  ['Ambiguity preserved', 'PASS', 'Legend rotation, EditableMesh replication, Open Cloud, sword sleep pose, install outcome all UNKNOWN / VERIFY.'],
  ['History compressed without continuity loss', 'PASS', 'Releases collapsed to current state; V116 ragdoll debt and deprecations retained.'],
  ['Budgets/evidence scope respected', 'PASS', 'Offline suites and mock installs presented as Implementation evidence only.'],
  ['Fresh-model continuation test', 'PASS', 'Paths, commands, installer order, settings and next steps are self-contained; uploads must be re-requested.'],
]));

const doc = new Document({
  creator: 'Steal A Pack dev',
  title: 'Steal A Pack — Master Handoff R151',
  styles: {
    default: { document: { run: { font: FONT, size: 19 } } },
    paragraphStyles: [
      { id: 'Title', name: 'Title', basedOn: 'Normal', run: { size: 34, bold: true, font: FONT, color: '1F3B57' }, paragraph: { spacing: { after: 80 } } },
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 26, bold: true, font: FONT, color: '1F3B57' }, paragraph: { spacing: { before: 260, after: 100 }, outlineLevel: 0, border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '1F3B57', space: 2 } } } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 21, bold: true, font: FONT, color: '2E5C86' }, paragraph: { spacing: { before: 160, after: 80 }, outlineLevel: 1 } },
    ],
  },
  numbering: { config: [{ reference: 'bullets', levels: [
    { level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 360, hanging: 240 } } } },
    { level: 1, format: LevelFormat.BULLET, text: '–', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 240 } } } },
  ] }] },
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 }, margin: { top: 1080, bottom: 1080, left: 1080, right: 1080 } } },
    headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: 'Steal A Pack — Master Handoff R151', font: FONT, size: 15, color: '888888' })] })] }) },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: ['Page ', PageNumber.CURRENT, ' of ', PageNumber.TOTAL_PAGES], font: FONT, size: 15, color: '888888' })] })] }) },
    children: C,
  }],
});
Packer.toBuffer(doc).then(b => { fs.writeFileSync(out, b); console.log('wrote', out, b.length); });
