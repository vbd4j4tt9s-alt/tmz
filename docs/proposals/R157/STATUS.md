# R157 status (UI update + text + pyramid), in progress

Base: R156 (weather ambience, music, item info panel removed; installer `installers/R156_install.lua`).

## Owner-approved, being built (agent branches)
- Pity bars v2 (`docs/proposals/R156/pity_bars_v2.*`): shade **Fresh**: NORMAL clover green, EVENT gold with a clover-green rim, clover icon,
  8 px above the slots on PC / 6 px on phones, the held item's name rows above the bars, gold star on the event notice.
- Reveal fixes (`docs/proposals/R156/reveal_fixes.*`): SKIP in the bottom-right corner in story scenes, SKIP only for Secret / Cosmic / King,
  the Common..Mythic card fitted between BASE / TRACK and the bars, "click to collect!" under the seed name (story result too).
- DAILY + INVITE in the MENU wheel (`docs/proposals/R156/menu_wheel_daily.*`): 5-option half circle, BASE / TRACK alone in the top row, the
  DAILY badge at its corner, a red "!" on the closed MENU button while a daily reward waits.
- Bag option 2 (`docs/proposals/R156/bag_look.*`): no green (hotbar navy), a light rim for drop targets, no hint line.
- Title tips round 2 (`docs/proposals/R156/title_tips.*`): style B, centred between the logo and the button, every 10 s, ±5% pulse, yellow /
  green words, 24 simple tips with "you" / "your" (`TitleTips156`).
- Game-wide text: every "u" / "ur" becomes "you" / "your" / "you're" (owner: "this goes for all u and urs in the game"). From now on all new
  player-visible text uses "you" / "your", simple words (about a 3rd-grade level).

## Approved after its preview (owner: "yes")
- The owner's Classic Pyramid (Creator Store 113814131474028; 18 limestone slabs, parsed to `docs/proposals/R156/pyramid/`) replaces the
  Sunscar Pyramid in the Desert at 0.6834 scale (the old 44.8-stud footprint; full size would cut the Desert's wall), walk-through like every
  landmark, hollow, with the plain Desert Mythic pack (Pack06) floating inside; hold E from outside (37.7 studs, only inside a box around it);
  one claim per player (counts when banked; caught / lost -> straight back into the pyramid); the Sand Snake chases; the 42 keys under it are
  left out. Preview `docs/proposals/R156/pyramid.png`, notes `pyramid.md`.
- Free Void Pack: claimable after 20 minutes of total play (`Premium.PlaySeconds157`), countdown on the pedestal, owed packs still given.
