# R152 – a tutorial a new player gets in 5 seconds

Owner: "make tutorial understandable in 5 seconds for new players see player know instantly", every text "like how I talk".

Preview (drawn first, before the code): `tutorial.png`, every step on a landscape phone (844×390 with the notch inset) and a PC
(1280×720). Regenerate: `node docs/proposals/R152/preview/render_tutorial_mock.mjs` (playwright + Chromium, FredokaOne from
`shop_R120/tests`). The world in the mock is a stand-in drawing; the HUD is faded so the card's spot is clear.

## The rule for every step

- **One idea.** A big icon, a title of at most 4 words and a chip of at most 3 (6 words on screen, tested).
- **Point at the exact thing.** In the world: a light beam + a pulsing ring on it, a bubble with the step icon over it, and
  the red chevron ghost path from your feet to it. On the screen: a ring + a pressing 👆 hand on the button to press
  (hotbar slot, TRACK, BASE). On the dirt: a pressing 👇 hand.
- **Show the button.** The chip is the key / button for your device: `[E]` / `[CLICK]` on PC, `👆` / `[TAP]` on a phone,
  `[X]` / `[RB]` / `[R2]` on a gamepad.
- **It moves on by itself** the moment you do it: the icon flips to a green ✓, NICE!!, a bubble sound (0.7 s; while a pack's
  reveal plays it waits up to 2.5 s), then the next step bounces in. Nothing to click, no welcome page, no NEXT, no slides.
- **Never in the way.** Nothing but the small two-tap X can take a click or tap; everything else lets input through. The
  card sits inside the phone's safe area, clear of the HUD and your character (26 screen sizes, tested).

## The steps

| # | You see | Words (owner's voice) | Next when |
| --- | --- | --- | --- |
| 1 | off the track: ring + hand on **TRACK**, beam + path to the track gate | 🏃 **GO TO THE TRACK!** `[TRACK]` tap it | you're on the track |
| 1 | beam + ring + path on the nearest pack | 🎒 **GRAB A PACK!** `[E]` hold (`👆` hold it, `[X]` hold) | you pick it up |
| 1 | no pack on the track yet | ⏳ **PACKS COMING!** hang tight | a pack shows up |
| 2 | beam + path to the home line, keepers behind you | 🏠 **RUN HOME!!** ➜ to ur base | the pack is banked |
| 3 | ring + hand on the pack's hotbar slot | 🎁 **OPEN IT!** `[CLICK]` / `[TAP]` / `[RB]` ur pack | it's in your hand |
| 3 | hand + TAP! + 5 pips next to the pack in your hand (R138) | 🎁 **KEEP TAPPING!!** `[TAP]` open it (CLICKING / PRESSING) | it opens (reveal plays) |
| 4 | beam + ring + pressing hand on your garden dirt | 🌱 **PLANT IT!** `[TAP]` / `[CLICK]` / `[R2]` the dirt | it's planted |
| 4 | seed not in your hand: ring + hand on its hotbar slot | 🌱 **PLANT IT!** `[TAP]` ur seed | it's in your hand |
| 4–5 | on the track: ring + hand on **BASE** | 🏠 **GO HOME!** `[BASE]` tap it | you're off the track |
| 5 | beam + ring + path on your treadmill | ⚡ **GET FASTER!** ➜ hop on it | you step on it (or 40 s) |
| ✓ | end: confetti + gem sound, 4 s, then nothing is left | 🏆 **U GOT THIS!!** 🎁 FREE PACK! (replay: have fun Alex!) | — |

The free pack notice: "🎁 FREE Forest pack!! check ur Bag".

## Why these steps (and not more)

- **Grab → home → open → plant is the whole game in four moves.** After them a new player has done the loop once with their
  own hands, which is what "I get it" means.
- **Step 5 is the treadmill, not slides.** Speed is the only part of the loop you can't see from the first four (it's how you
  get further down the track), your treadmill is a few steps from the garden, and it fills the wait while the first plant
  grows. It is a *do* step like the others; if you ignore it, it finishes by itself after 40 s so the free pack still comes.
  It reuses the old step 5 (`TreadmillInfo`), so saves are unchanged.
- **Harvest and sell are not steps.** The first plant needs minutes to grow; a step that waits for it would hold the
  tutorial open. Fruit and the market are found by playing (the plant shows its fruit, the market has its sign).
- **Teleports only when they help.** TRACK is shown only while you're off the track in step 1; BASE only when the next goal
  (garden, treadmill) is at your base and you're on the track. You can't teleport while carrying, so step 2 never shows it.
- **No welcome page.** It was a click-to-continue page; the step row on the card (🎒 🏠 🎁 🌱 ⚡) shows the loop instead.

## Kept from R138 / R139

- Saved progress is the same `{Version=1, Mask, Done}` with the same bits and actions: `Pack` → step 3, `Seed` → 4,
  `Plant` → 5, `TreadmillInfo` (now sent when you step on the treadmill) finishes, `Skip`, `Replay`. Old saves land on the
  same step.
- The free Forest pack (2x on the server only, never said) for finishing, once per account; skipping at the start gives
  nothing, skipping the last step still counts. Returning players (a save from before the tutorial existed) skip it.
- The two-tap X to skip, the owner's avatar as the guide, the R138 clicking indicator, the TRACK/BASE ring, the chevron
  trail, Reduced Motion (no bouncing), `TutorialCardBottom` for the notices.

## Files

- `src/ReplicatedStorage/BeginnerGuide.lua` – the words, icons, chips and step targets (step 5 = the treadmill).
- `src/StarterPlayer/StarterPlayerScripts/BeginnerTutorial.client.lua` – the card, beam, ring, hands, pops; no welcome page,
  no slides; the world pieces exist only while the tutorial runs.
- Tests: `tools/tests/test_tutorial.luau`, `test_guide_flow.luau`, `test_guide_layout.luau` (run by `R138/tests/run.sh`),
  the starter-pack tests in `R138/tests` and `R139/tests`.
