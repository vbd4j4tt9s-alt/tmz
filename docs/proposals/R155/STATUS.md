# R155 status

Base: R154 release `8aa15fd`. **Released (built, not installed yet):** two installers `installers/R155_install_part1.lua` / `part2.lua`, notes
`docs/releases/R155.md`, split recipe `docs/releases/R155_parts.txt`, suites `docs/releases/R155_suites.txt`. `Config.Version = 'V150 R155'`.

## In the release
- Speed popups follow the zoom (`popups_zoom.md`).
- Clover icon: the owner's uploaded image `121815230112848` first (`CloverIcon153.AssetId`), then pass icon, drawn picture, plain clover.
- Boots halved: BootLuck {25, 250, 10K, 500K, 25M}, MaxLuck 25M, LuckCeiling 50M (`docs/proposals/R154/luck_and_odds.md` section 6).
- B3 on tier 1 too (`docs/proposals/R154/perf154.md`, R155 section).
- Notification badges smaller and moved (`NotifyBadge151.Sizes` / `Overhang` / `OverhangTop`).
- Cinematic camera for Secret / Cosmic / King and skip only with the SKIP button (`cinematic_camera.md`).
- Mech coats (1C) + countdown to `LimitedEvent.EndsAt`, off sale after (`mech_coats.md`).
- Pack pity: NORMAL / EVENT counts, every 10th open x1.5 luck and cap, two always-visible bars (`pity.md`).
- Inventory like Roblox's Backpack, 200 items max, discard with a ~1 s hold on every item (`inventory.md`; the item tooltip panel it shipped with was removed in R156, owner).
- Installer engine: refuses open script tabs up front, waits up to 3 s for an open tab to sync (`tools/installer_engine.lua`).

## Open owner calls (listed in R155.md "Your call")
- Mech pack card when the Bag is full: a "make room first" button instead of not offering it?
- (Item tooltip odds for packs never held: moot, the tooltip panel was removed in R156.)
- Lucky roll at the per-tier ceilings (11 of 42 world packs don't move at Thunder + clover).
- Still from R154: the clover at the very top.

## Owner notes
- R154 install: the first paste stopped on `HubTrampolineRules153` (its script tab was open), then "Mixed" on re-paste; a repair snippet was given and
  mock-tested. Result not reported.
- On 1 Nov 2026: take the 3 Mech developer products off sale (a forced prompt's receipt is always granted).
