# R155 status (work in progress)

Base: R154 release `8aa15fd` (installer `installers/R154_install.lua`, base R153b `dd3a4c6`). R155 installer not built yet.

## Merged on `claude/compassionate-brown-lohfok`
- Speed popups follow the zoom (`docs/proposals/R155/popups_zoom.md`): 12.5 studs = R154 exactly, smaller zoomed out, fade 31-36 studs, capped 1.3x close up.
- Clover icon: the owner's uploaded image `121815230112848` first (`CloverIcon153.AssetId`), then pass icon, drawn picture, plain clover.
- Boots halved: BootLuck {25, 250, 10K, 500K, 25M}, MaxLuck 25M, LuckCeiling 50M (`docs/proposals/R154/luck_and_odds.md` section 6).
- B3 on tier 1 too: near keyboard letters 12 px/stud on tiers 1 and 2 (`docs/proposals/R154/perf154.md`, R155 section).

## Being built (agents, worktree branches) when this was written
- Cinematic camera for Secret / Cosmic / King (`docs/proposals/R154/cinematic_camera.md`), owner answers: cuts as designed; Cosmic seed with the star (~0.5 s later) ok; NO world opening move and NO hand-back offset (today's push-in and cut stay); depth of field on ALL devices. Plus: no skipping by clicking / spam-clicking anywhere; skip ONLY with a SKIP button at the bottom right (gamepad B / R2 press it); collecting the waiting result is still click anywhere, but only a press that starts after the result is shown.
- Mech packs option 1C: Gold 4.5% / Diamond 0.5% coats like world packs, the seed keeps the coat. Mech "LIMITED TIME!" gets a countdown to `LimitedEvent.EndsAt` (2026-11-01 00:00 UTC, the Verity event); after it, no new Mech purchases (a late Robux receipt is still granted).
- Inventory like Roblox's default backpack (keep our look): number keys, click to equip instantly, Bag with ` key and search, drag Bag <-> hotbar both ways (a blank hotbar is possible), swap hotbar slots, tap-tap on phone, layout saved across respawns and rejoins. Max 200 items held (packs, seeds, fruit; not garden plants or gear); players already above 200 keep everything but can't receive more. Discarding items: trash drop zone in the Bag (and a Discard action), choose an amount for stacks, confirm popup, ~1 s hold for Secret+ / Mech / Verity / mutated / Gold / Diamond items; server-validated, logged.

## Not started (blocked: auto mode could not evaluate launching the build)
Pity, owner decisions in order:
1. "every 10th pack" gets **x1.5 luck** (not "10 in a row without a Secret+").
2. **Two separate counts**, both saved: EVENT pity = Void + Verity + Mech packs share one count; NORMAL pity = every other pack. In each, the 10th open is lucky, then the count resets. Owner / Studio test packs don't count.
3. x1.5 stacks on top of boots x clover (Void / Verity / Mech: clover only) and raises that roll's cap by x1.5 too (lucky rolls may reach 75M); per-tier ceilings, the 80% rule and the shown odds unchanged.
4. **Two bars, always visible, slightly above the hotbar, polished:** NORMAL pity GOLD, EVENT pity PURPLE ("3/10 pity" / "3/10 event pity"); the bar of the held pack's group highlighted; 9/10 glow, pop + shine when the lucky pack opens; phone layout fits; Reduced Motion respected. Own client script (not inside `Hotbar.client.lua`, which is at 174 of the 180-register guard).
5. Listed with the odds (shop cards for the paid Mech packs, hold tooltip, `/test odds`); `/test pity`, `/test pity set <normal> <event>`.

## Owner notes
- R154 install: the first paste stopped on `HubTrampolineRules153` (its script tab was open), then "Mixed" on re-paste; a one-line repair (puts that script back from the backup, then runs the R154 install) was given and mock-tested.
- Installer engine hardening (refuse open script tabs up front, wait up to 3 s for an open tab to sync): patch in `docs/proposals/R155/installer_engine_hardening.patch` (engine + mock tests), not applied yet (rebuilding R154 with it was blocked); apply it before building R155.
