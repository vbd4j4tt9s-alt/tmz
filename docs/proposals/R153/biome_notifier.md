# R153: a smaller, calmer biome notifier (previews first, nothing built yet)

Owner: "biome notifier also has to be simplified to take less space and look less distracting. send me previews before implementations".

**Preview:** [`biome_notifier.png`](biome_notifier.png), one sheet at true pixel size: today next to A / B / C on a phone in landscape (844 x 390, whole screen),
a phone in portrait (390 x 844) and a PC (1280 x 720), then each option in Forest, Lava and Storm Peaks, then five moments of each animation, then the numbers.
`preview/run_biome_notifier_preview.sh <scratch dir>` rebuilds it. **No file under `src/` is changed by this step.**

## What it is today

`src/StarterPlayer/StarterPlayerScripts/BiomeEntryNotifier.client.lua` (the R125 rebuild), styles from `src/ReplicatedStorage/BiomeTitleStyle.lua` (name, colour, accent per biome),
logos from `BiomeArtwork` / `BiomeIconData` (96 x 96 pictures), position and size from `HudNotices.client.lua` + `HudNoticeLayout.lua`.

- **Look:** a 490 x 110 box: an 88 px round medallion (glossy disc in the biome colours, inner ring, the logo, a shine), a soft dark pill behind the words, a small "ENTERING" in the accent
  colour (14 px), the biome name in capitals (40 px FredokaOne, white to accent to biome colour, dark outline), an accent underline with two diamond ends and two pulsing sparkles.
- **Size on screen:** `HudNotices` squeezes that 490 x 110 box into a row (94 px high on PC and portrait phones, 58 px on landscape phones, at most 490 wide, on a landscape phone at most 44% of the width).
  For "STORM PEAKS", the longest name, the part you can see (medallion to the end of the pill) is:

| Screen | Visible size | Share of the screen | Its row (reserved at the top) | Scale | Name / "ENTERING" text |
|---|---|---|---|---|---|
| PC 1280 x 720 | 359 x 75 px | 2.9% | 419 x 94 | 0.85 | 34 px / 12 px |
| Phone landscape 844 x 390 | 221 x 46 px | 3.1% | 258 x 58 | 0.53 | 21 px / 7 px (tiny) |
| Phone portrait 390 x 844 | 314 x 66 px | 6.3% | 366 x 82 | 0.75 | 30 px / 10.5 px |

  FOREST and LAVA are narrower: on PC 254 x 75 and 217 x 75 px (landscape phone 157 x 46 and 134 x 46, portrait 222 x 66 and 190 x 66).
- **Time on screen: 3.1 s.** Fade in 0.25 s, fully shown until 2.4 s (2.15 s fully shown), fade away over 0.7 s. If you turn back, die or respawn it fades in 0.45 s instead.
- **Animation:** the box drops in 10 px and settles over 0.35 s; the medallion pops from 0.7 to 1.0 with a small overshoot; two sparkles pulse all the time; it rises 8 px while it fades away.
  Reduced Motion: fade only.
- **When it shows (unchanged by every option below):** `BiomeEntryGate` only lets it appear when you walk forward over a biome border (not on spawn, teleport, sideways or going back).
  `HudNotices` finds it by the names `BiomeEntryUI` / `BiomeTitle`, so those names stay.

## The three options

All sizes are the visible box in screen px for "Storm Peaks"; the strip in the sheet shows them drawn. Names are in Title Case ("Storm Peaks", not "STORM PEAKS"): the biome names are proper names,
so R152's casual style leaves them alone, but capitals shout; one value to switch back if you prefer capitals. Nothing says "ENTERING" in capitals any more.

| | **A: slim chip** | **B: text only** | **C: corner toast** |
|---|---|---|---|
| Idea | dark rounded chip at the top centre: small logo + name | no box: tiny "entering" over the name in the biome colour | same chip, top-left under the top bar: logo + name |
| Words | `Storm Peaks` (no "entering" line) | `entering` (lowercase) over `Storm Peaks` | `Storm Peaks` |
| PC 1280 x 720 | **149 x 30** (0.49% of the screen; 40% of today's height, 17% of its area) | **143 x 44** (0.68%; 59% of the height, 23% of the area) | **145 x 30** (0.47%; 40% of the height, 16% of the area) |
| Phone landscape 844 x 390 | **122 x 24** (0.89%; 52% of the height, 28% of the area) | **113 x 37** (1.27%; 80%, 41%) | **121 x 24** (0.88%; 52%, 28%) |
| Phone portrait 390 x 844 | **132 x 27** (1.08%; 41%, 17%) | **125 x 39** (1.48%; 59%, 24%) | **130 x 27** (1.07%; 41%, 17%) |
| Text sizes (PC / portrait / landscape) | name 16 / 14 / 13 px, icon 22 / 20 / 18 px | name 24 / 21 / 19 px, "entering" 12 / 11 / 11 px | same as A |
| On screen | **2.0 s** (fully shown 1.4 s) | **2.4 s** (fully shown 1.5 s) | **2.1 s** (fully shown 1.5 s) |
| Animation | slides down 14 px while it fades in over 0.2 s, still, fades and lifts 6 px over 0.4 s. No pop, no sparkles | fades in over 0.3 s with a 6 px settle, still, fades out over 0.6 s. Nothing else moves | slides in from the left 26 px while fading in over 0.25 s, still, slides back out and fades over 0.35 s |
| Reduced Motion | fade only | same (already fade only) | fade only |
| Biome identity | the real logo + the biome colour on the name + accent outline | the biome colour on the name only (no logo) | the real logo + biome colour + an accent bar down the left edge |
| Space it takes from other notices | a 34 px row (28 px on landscape phones) instead of 94 / 58 | a 46 px row (40 on landscape phones) | none: it is not in the centre stack, so the other notices move up |

"40% of today's height" is measured against today's visible height (the medallion: 75 / 66 / 46 px on PC / portrait / landscape). A and C are 40% of it on PC and about 41% in portrait. On a landscape phone
today's is already squeezed to 46 px, and 13 px text is about as small as is still comfortable to read, so there they are 24 px (52%).

Look of each, in Roblox terms (what would be built):

- **A:** `Frame` (12,20,34) at 28% transparency, fully rounded, 1 px `UIStroke` in the biome accent colour; the logo (`BiomeArtwork.Attach`) straight on the chip (no medallion, no disc, no CanvasGroup),
  the name in FredokaOne in the biome colour with a thin dark `UIStroke`. About 6 instances (today: about 30 plus gradients).
- **B:** two `TextLabel`s, no frame: "entering" in GothamMedium (white, 90%) and the name in FredokaOne (biome colour), each with a dark `UIStroke` (about 1.2 to 1.8 px, 20 to 25% transparent) and a second dark label 2 px below as the
  soft shadow. Roblox cannot blur, so the real shadow is a little harder than the blur drawn in the preview. Text over a bright sky needs that dark edge: without it, pale biomes
  (Snow, Desert, and Forest's light green over clouds) would be hard to read. That is the weak spot of B.
- **C:** like A (corners 8 px instead of a full pill) plus a 3 px accent bar down the left edge, fixed at 12 px from the left and 8 px under the top bar (the safe area's top-left, where nothing of the HUD is
  in the live game for normal players: `HudLayout` keeps a 48 px tile reserved at that corner for the owner's test tools, which only Studio and command-enabled accounts get).

Where A and B sit: the same slot as today's notifier (56 px under the top bar on PC and portrait phones, 44 px on landscape phones), so the tutorial card, the run warning and the other notices stack under it exactly as now, just with a smaller row.

## What would change in the code (when you pick one)

- `BiomeEntryNotifier.client.lua`: only the drawing and the fade/slide numbers; the gate, the polling, the spawn reset and the `BiomeEntryUI` / `BiomeTitle` names stay. The 490 x 110 box, the medallion, the pill, the underline and the sparkles go.
  The size is picked from the viewport (PC / portrait / landscape) instead of a scale-to-fit, so the `NoticeFit` attribute that `HudNotices` writes is no longer needed for A and B.
- `HudNoticeLayout.lua` (`row('Biome', ...)`): the row heights above (A 34 / 28, B 46 / 40); for C the Biome row is dropped from the stack.
- `BiomeTitleStyle.lua`: a Title Case name (a `Label` field) next to the capitals one.
- Tests that would be updated with it: the R124 notifier suite (`docs/proposals/polish_R124/tests/test_notifier.luau`), the R151 layout static checks and the `HudNoticeLayout` row expectations; the frozen manifest hashes for the touched files.

## Recommendation: A

- It is the smallest change that still looks like the game: it keeps the real biome logo (you asked for the logos to come back in R125, so I would not drop them) and the biome colour, and it has no
  word the player does not need ("ENTERING" tells nothing the name does not).
- It is as small as C (about 17% of today's area on PC and portrait, 28% on a landscape phone) but stays where players already look for short notices, and it does not need a new spot or touch the HUD layout; it only shrinks a row.
- 2.0 s is a third shorter than today, and nothing pops or sparkles: it appears, you read two words, it goes.
- C is the calmest if the centre must stay completely empty, at the cost of being easier to miss. B is the lightest on the eye but has no logo and the weakest legibility on bright skies, so I would only pick it if you
  really do not want any box.

## Your choice

Reply with **A**, **B** or **C**, and optionally:

1. Name in **Title Case** ("Storm Peaks", as drawn) or keep the **CAPITALS** ("STORM PEAKS")?
2. Time on screen as drawn (A 2.0 s / B 2.4 s / C 2.1 s) or longer / shorter?
3. Anything to bring back from today (for example a tiny "entering" above the name on A)?

I will build only the one you pick, with the tests updated, after you say so.

## How faithful is the preview

- Real: the biome logos (decoded from `BiomeIconData.lua`), the biome colours and accents (`BiomeTitleStyle.lua`), today's numbers (`BiomeEntryNotifier.client.lua`: sizes, positions, times, easing, pop, sparkle rate) and the row each
  screen gives it (`HudNoticeLayout.Calculate` with the 44 px top bar drawn, exact for the formulas, the bar height is a guess: Roblox's real top bar differs by device).
- Approximate: the fonts (Fredoka One and Montserrat stand in for Roblox's FredokaOne and Gotham, so text widths are close but not exact), the track (a drawn keyboard, not a screenshot), and the soft shadow in B (see above).
- The numbers in the table come from the same functions that draw the panels, so sheet and table cannot disagree.
