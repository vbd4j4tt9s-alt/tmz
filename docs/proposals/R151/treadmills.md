# R151 proposal: the treadmills — same shape, new details

**This is a preview only.** Nothing in `src/` was changed. After you approve, a coder builds it.

Your words:
- *"looking at these treadmills we dont have to copy them but lets add to the ingame treadmills the elements that these treadmills have"*
- *"we dont have to copy the tall fronts dont make it look like a copy keep the shape of the treadmills that we hve but just see what we can improve and addd from the references above"*
- *"show previews before implementation"*

| Picture | What it shows |
|---|---|
| `treadmills.png` | Level 1 (Forest, low), Level 5 (Lava, mid) and Level 7 (Storm, top): today vs the proposal from the same camera, at three-quarter and side views. Then close-ups of the belts, the corner accents, the label, the upgrade sign, the runner's own view, and the machine in the dark. |
| `treadmills_all.png` | All seven levels, today vs the proposal (three-quarter and front views). |
| `treadmills_belt.gif` | The belt moving while someone trains (levels 1, 4, 5 and 7). |

**How the pictures were made.** They are approximate renders, not screenshots.
- The real start-up code builds Base 1 of your place (`sapkeyver.rbxl`) on the Roblox mock.
- The real treadmill builder (`BiomeVisuals.BuildTreadmillV131`) builds each level.
- The real upgrade buttons and the real client effects (`TreadmillFx`) are on, as a nearby player sees them.
- The proposal is a prototype (`treadmills/TreadmillDress151.luau`) added on top.
- three.js draws the result. There is no Roblox lighting, bloom or Fredoka font, and particles are dots.

## What stays exactly as it is
- **Every part of today's treadmill**: the frame, rails, fronts (sun crest, idol, crowns, sigil, coils, cloud), console, chevrons, menu prompt and badge. Each keeps its size, place and colour, so the silhouette is the same in every picture.
- **Gameplay**:
  - The training belt is unchanged (9.4 × 0.4 × 15.84, solid), and so is how a step is detected.
  - Every new part has CanCollide, CanQuery and CanTouch off, so nothing new can be stood on or block the belt check.
  - The R150 bonus button, gift timer and pedestal are untouched.
  - The floor upgrade buttons keep their places and prompts.
- **No gate or arch.**
  - Nothing new is taller than today's front.
  - Everything new stays on the treadmill's own 17 × 22 apron, except the upgrade sign, which stands beside the button.

## What is added, and which reference it comes from
| Reference element | How it appears on our treadmill |
|---|---|
| **Animated belt** (the lava flow, the ice treadmill's light lines, the tech treadmill's falling digits) | Tiled **Texture** layers on the existing belt surface: 1 layer at low levels, 2 at mid, 3 at top. The client scrolls them (`OffsetStudsV`) in step with the chevrons, faster while someone trains. There is no per-part movement. Each biome gets its own mix (see the belt close-ups). **Lava**: dark cooling plates over the glowing belt, with molten veins. **Snow / Crystal**: circuit light lines. **Storm**: circuit lines plus falling digits. |
| **Edge light flows** | Two thin **Beams** along the belt edges, with a moving texture (`TextureSpeed`): fire on Lava, sparkles elsewhere. Mid and top levels only. |
| **Glowing neon trims** | A neon rim line around the chassis on every level. Mid and top levels add a glow line along each soft side bumper. At top levels the trims pulse slowly. |
| **Studs** | Chunky studs along the top of both side bumpers (12–17 per machine), placed so they skip any rail, pillar or root. Studded plinths sit under the corner accents. |
| **Lamp posts / braziers** (small, at our scale) | Two corner accents at the entry end, 3–4 studs tall (lower than the console). **Forest**: trail lantern. **Jungle**: bamboo torch. **Desert**: sun brazier. **Snow**: frost lamp. **Crystal**: prism lamp. **Lava** and **Storm** already have pylons and capacitor banks there, so those get studded plinths instead. |
| **Themed particles** | One subtle emitter per accent: fireflies, embers, frost glints or prism sparkles. Like every treadmill effect today, the client turns them on only near the camera (R117 `TreadmillFx`). |
| **Real glow** | One "entry glow" light between the accents. Mid and top levels add a deck underglow, unless the machine already has one. Lights are capped per level (see below). |
| **"+N/step" label** | Floats just above the existing front. N is what one training step of that level gives: 100 points/s × 1/6 s × the machine's multiplier, shown like the speed popups. Level 1 shows +17/step; Level 7 shows +500K/step. While you run on your own treadmill, your label hides so it never clashes with the popups or the gift timer. |
| **Upgrade sign** | A small studded sign beside the existing floor button (the button itself is unchanged). It shows "UPGRADE", "LV 3 > LV 4", "+333 > +1.7K/step" and the price, in the next level's colours. At level 7 it shows MAX LEVEL. The button's base gets a neon rim in the treadmill's trim colour. |

**Removed:** the moving belt pieces. These are the sand ripples, frost reflections, molten currents and flakes, prism glints and travelling lightning (8–22 parts per level). Today they are moved one by one every frame. The scrolling textures replace them. **The chevrons (forward arrows) stay.**

## How the look grows with the level
Each level is its own biome: Level 1 Forest … Level 7 Storm. So "low / mid / top" means levels 1–2, 3–5 and 6–7.

The config is split **per grade** (how rich the effects are) and **per biome** (images, colours, accent, particle).

| Grade | Levels | Belt | Trims | Real lights, whole machine (cap) |
|---|---|---|---|---|
| low | 1–2 | 1 texture layer | rim line | ≤ 3 |
| mid | 3–5 | 2 layers + edge flows | rim + bumper lines | ≤ 5 |
| top | 6–7 | 3 layers + edge flows | rim + bumper lines, pulsing | ≤ 6 |

## Cost (measured on the mock, Base 1, every level)
| Level | Parts today → proposal | New / removed | Real lights | Emitters | Beams | Belt textures | Label |
|---|---|---|---|---|---|---|---|
| 1 Forest | 127 → 166 | +39 / −0 | 2 → 3 | 3 → 5 | 0 → 0 | 1 | +17/step |
| 2 Jungle | 186 → 226 | +40 / −0 | 2 → 3 | 4 → 6 | 0 → 0 | 1 | +67/step |
| 3 Desert | 202 → 223 | +43 / −22 | 1 → 3 | 6 → 8 | 0 → 2 | 2 | +333/step |
| 4 Snow | 212 → 240 | +36 / −8 | 1 → 3 | 5 → 7 | 1 → 3 | 2 | +1.7K/step |
| 5 Lava | 217 → 232 | +35 / −20 | 4 → 4 | 11 → 11 | 0 → 2 | 2 | +10K/step |
| 6 Crystal | 223 → 250 | +43 / −16 | 4 → 6 | 8 → 10 | 1 → 3 | 3 | +66.7K/step |
| 7 Storm | 240 → 256 | +34 / −18 | 5 → 5 | 10 → 10 | 5 → 7 | 3 | +500K/step |

**Other costs:**
- **Upgrade sign**: +16 parts on each owned base.
- **Per-frame work**:
  - Today, each nearby treadmill moves its 32 chevron pieces plus 8–22 belt pieces every frame.
  - The proposal moves the 32 chevron pieces plus 1–3 texture offsets. That is cheaper than today from level 3 up.
  - Beams scroll on the graphics card (`TextureSpeed`), with no script work.
  - Lights and particles stay "near the camera only", as today.
- **Collision**: no new solid or raycast-visible part. The belt is checked identical at every level.
- **Z-fighting**: 0. The R149 detector ran on the whole of Base 1 at every level, before and after, and found no finding with a new part and no new finding.
- **Uploads**: five small images (`treadmills/textures/*.png`, 256–512 px, white on transparent, tinted per biome). Until they are uploaded, the belt falls back to the place's own grid texture (asset 6372755229, already on every pad).

## What you need to choose
1. **The label number**:
   - the machine's own gain, the same for everyone (proposed);
   - or the owner's actual gain, including trail, pass and friends.
2. **Belt images**: upload the five PNGs (recommended), or use the grid fallback with no uploads.
3. **Belt direction**:
   - forward, with the chevrons, as the arrows move today (proposed);
   - or backward, like a real treadmill belt.
4. **The upgrade sign**: yes or no.
5. **The old moving belt pieces**: retire them (proposed: cheaper, and the textures replace them), or keep them under the textures.

## After approval (implementation plan)
- **Build**:
  - The prototype becomes a dressing pass in `BiomeVisuals.BuildTreadmillV131`.
  - A shared config module holds the grades and biomes.
  - The texture scroll and the owner-label hide go into `TreadmillFx`; `SpeedGainPopup` and the popup code are not touched.
  - The sign goes into `GardenUpgradeService`.
- **Tests** (`docs/proposals/R151/tests/run_treadmills.sh`):
  - every level builds;
  - collision is unchanged;
  - the running surface is unchanged;
  - part, light and emitter budgets hold per grade;
  - the belt animation is a texture or beam scroll;
  - the label shows the right /step;
  - z-fighting is 0;
  - teardown works.
- **Other suites kept green**: R150 bonus, R123 treadmill bonus, R150 pedestal and R151 base area.

**Studio checks for the build:**
- The texture scroll moves with the chevrons; flip the sign if not.
- The Beam flow runs toward the front.
- The textures read well on the Neon lava belt.
- The label is readable at 30–60 studs and hidden while you train.
- The lights stay off far away and in FastMode.

## How to rebuild the pictures
`sh docs/proposals/R151/treadmills/run_treadmill_preview.sh <scratch dir> [node_modules with three@0.169] [place.rbxl]`
- The script runs the mock scenes before and after.
- It then runs `check_treadmill_dress.py`, which covers the belt, collision, budgets, label and z-fighting, and prints "treadmill dress checks: all passed".
- Finally it renders and composes the sheets and the GIF.
- `make_belt_textures.py` regenerates the five belt images.
