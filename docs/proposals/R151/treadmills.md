# R151: the treadmills — same shape, new details

> **Update (5 Oct 2026): approved and built.**
> - You said *"works we can implement the treadmill polishes"*.
> - Then *"adjust the steps per second on top of the treadmill to multples of 5 and also for the speed gain popup for numnbers obvere 1000 it willl be read as 1k"*.
> - Your sub-choices were not answered, so the proposed defaults are used:
>   - the label shows the machine's own gain, the same for everyone;
>   - the belt runs forward with the arrows;
>   - the upgrade sign is on;
>   - the old moving belt pieces are retired.
> - **§ As built** below says what changed. The pictures (`treadmills.png`, `treadmills_all.png`, `treadmills_belt.gif`) are now drawn from the real game code.
> - The original proposal follows, kept as written. Its prototype (`treadmills/TreadmillDress151.luau`) is gone: the real code replaced it, and the preview tools now run the real `src/`.

## As built

### The "+N/step" numbers: round, and real
Each level's own gain per training step is now a round multiple of 5:
- **Rule:** round to the nearest round value, but round **up** wherever the nearest would lose more than about 3%.
- **Same for everyone:** the label shows 100 points/s × 1/6 s × the machine's multiplier.
- **Real:** the server pays exactly that number every step (whole fives, as before). The label is the real award, not a rounded display.

| Level | Biome | Per step before | Per step now | Change | Machine multiplier before → now |
|---|---|---|---|---|---|
| 1 | Forest | +16.7 (shown +17) | **+20** | +20% (up: +15 would lose 10%) | 1 → 1.2 |
| 2 | Jungle | +66.7 (+67) | **+65** | −2.5% | 4 → 3.9 |
| 3 | Desert | +333.3 (+333) | **+335** | +0.5% | 20 → 20.1 |
| 4 | Snow | +1,666.7 (+1.7K) | **+2K** | +20% (up: +1.5K would lose 10%) | 100 → 120 |
| 5 | Lava | +10K | **+10K** | 0 | 600 → 600 |
| 6 | Crystal | +66.7K | **+65K** | −2.5% | 4,000 → 3,900 |
| 7 | Storm | +500K | **+500K** | 0 | 30,000 → 30,000 |

**Where this lives:** `BalanceValues81.MachineMultipliers`, the one table every machine multiplier comes from.

**What else reads these multipliers, checked:**
- the server's training gain, through `BaseService` and `BalanceRules.Training`;
- the HUD's speed-boost chip (`WorldStatusHud`, "×1.2" etc.):
  - at level 1 it now shows **×1.2**;
  - before, a level-1 player with no trail saw no chip, because ×1 is hidden;
- the treadmill snapshot.

**What does not read them:**
- the upgrade costs (`MachineCosts`);
- the bonus-roll timer and pool (`TreadmillBonusRules`);
- the R150 bonus UI copy;
- the keeper speeds.

All of these are unchanged.

**Tests:**
- Every suite that touches them was re-run green (list below).
- The new suite checks:
  - each level's award over 600 steps;
  - the rounding rule.

### Numbers of 1,000 or more read as K / M / B / T
`SpeedPopupStyle.FormatGain`, the speed-popup text, now picks its unit **after** rounding:
- 999.6 reads **1K**, not "1000".
- 999,950 reads **1M**, not "1000K".
- The same holds at the B and T boundaries.
- A positive amount below 1 reads **1**, so it never shows "+0".

Everywhere else the text is exactly as before. Only `FormatGain` changed; the popup motion is untouched. The treadmill label and the upgrade sign use this same function, so all three always match.

Other number displays that show a speed of 1,000 or more in full were left alone, because they are not speed gains:
- **The HUD speed counter** (the wallet; `CashNumbers.Compact` → `SpeedPoints.Compact`) shows whole numbers below 1,000,000, e.g. 250000.
- **The keeper "SPEED NEEDED" signs** (`SpeedPoints.NeedText`) write numbers below 10,000 in full with commas, e.g. 3,800. That is your R148 rule.
- **The speed bundles' internal `Name`** is `+250000 SPEED` (`PremiumPricing`). The shop cards and the purchase announcement already show **+250K SPEED** (`PremiumBundleCard.AmountText`, `PurchaseAnnouncer`).

Say if you want any of these changed too.

### What was built (files)
- **`ReplicatedStorage.TreadmillLook151`** (new) holds the config:
  - per grade (low = levels 1–2, mid = 3–5, top = 6–7): belt layers, edge flows, bumper lines, underglow, pulse, stud spacing, the light cap and the part, emitter and beam budgets;
  - per biome: belt layers (image, colour, transparency, tile size, speed), edge flow, trim colour, corner accent, particle and lamp colour;
  - the uploaded-image overrides;
  - the belt scroll speeds;
  - the label formatter.
- **`ReplicatedStorage.TreadmillBeltArt151`** (new) holds the five belt patterns and the code that puts each image on the belt. It tries three routes in order:
  1. uploaded ids;
  2. drawn on the client;
  3. the grid texture.
- **`BiomeVisuals.BuildTreadmillV131`** gains a dressing pass after the existing build:
  - the belt texture layers, the edge light flows, neon trims, bumper studs, two corner accents with one particle each, a capped light or two, and the "+N/step" label;
  - the old moving belt pieces are retired; the chevrons stay.
  - Without `TreadmillLook151`, or if the pass fails, the machine is built exactly as before and the server warns once.
- **`TreadmillFx`**:
  - puts the belt images on;
  - scrolls the belt textures with the arrows: 3.0 studs a second while training, 1.3 idle, × each layer's rate. They only move near the camera, on screen, and with motion allowed (not with Reduced Motion, low quality or FastMode);
  - hides your own label while you train on your machine.
- **`GardenUpgradeService`** adds the studded sign beside the Treadmill floor button and a neon rim round that button. The button, its prompt and its click detector are unchanged.
- **`BaseService`** passes the machine level to the builder: one line.
- **`BalanceValues81`**: the multipliers in the table above.
- **`SpeedPopupStyle.FormatGain`**: the unit boundaries above.
- **`src/MANIFEST.tsv`**: the two new modules.

### Belt images: no upload needed
- **How each client gets them:** it draws the five patterns once with `EditableImage` (`AssetService:CreateEditableImage` + `WritePixelsBuffer`) and applies them with `Content.fromObject`.
  - **Cost:** about 0.7 MB in total, drawn a few milliseconds per frame.
  - **Fallback:** if a client cannot (no image budget, or an older client), that layer uses your place's own grid texture (6372755229).
- **How to check which route a client used:**
  - each belt `Texture` carries `BeltRoute` = `generated`, `uploaded` or `grid`;
  - the local player carries `TreadmillBeltTextures`, the routes in use, e.g. `generated`.
- **Uploading instead (optional):**
  1. The same five images are `docs/proposals/R151/treadmills/textures/*.png`. They are byte for byte what the game draws, and the tests check this.
  2. Import them: Studio > View > Asset Manager > Bulk Import.
  3. Paste each id into `TreadmillLook151.Images`, e.g. `slats='rbxassetid://123'`.
  4. An uploaded id then wins on every client.

### Budgets (measured on the mock, every level)

| Level | Grade | Parts before → now | New / retired | Real lights (cap) | New emitters / beams | Belt layers | Label |
|---|---|---|---|---|---|---|---|
| 1 Forest | low | 127 → 166 | +39 / −0 | 2 → 3 (3) | 2 / 0 | 1 | +20/step |
| 2 Jungle | low | 186 → 226 | +40 / −0 | 2 → 3 (3) | 2 / 0 | 1 | +65/step |
| 3 Desert | mid | 202 → 223 | +43 / −22 | 1 → 3 (5) | 2 / 2 | 2 | +335/step |
| 4 Snow | mid | 212 → 240 | +36 / −8 | 1 → 3 (5) | 2 / 2 | 2 | +2K/step |
| 5 Lava | mid | 217 → 232 | +35 / −20 | 4 → 4 (5) | 0 / 2 | 2 | +10K/step |
| 6 Crystal | top | 223 → 250 | +43 / −16 | 4 → 6 (6) | 2 / 2 | 3 | +65K/step |
| 7 Storm | top | 240 → 256 | +34 / −18 | 5 → 5 (6) | 0 / 2 | 3 | +500K/step |

**Budget limits and other costs:**
- **Budgets:** new parts at most 44 (low) and 50 (mid / top). The whole machine stays at 260 parts or fewer (the R117 limit).
- **Upgrade sign:** 16 parts per owned base.
- **Per frame**, for each nearby treadmill: 1–3 texture offsets, plus today's 32 chevron pieces. That replaces 8–22 belt pieces that were moved one by one.
- **Lights and particles:** near the camera only (R117 `TreadmillFx`).
- **Collision:** nothing new collides, answers raycasts or touches.
- **Z-fighting:** 0 (the R149 detector on Base 1 of your place, at every level).

### Studio checklist
1. **Belt direction.** Train on each level: the belt texture must run the same way as the arrows. If it runs backwards, set `TreadmillLook151.Scroll.Sign = -1`.
2. **Edge light flows** (levels 3–7) run toward the front.
3. **Image route.** In the client's Explorer, the local player shows `TreadmillBeltTextures = generated`. If it shows `grid`, the client had no image budget; the belt then shows the grid lines, and uploading the PNGs fixes it.
4. **Lava belt (level 5).** The dark plates sit over the glowing belt, and the cracks glow. Check that the Neon bloom does not wash the plates out.
5. **Label and sign:**
   - The "+N/step" label is readable at 30–60 studs, gone past 90, and hidden on your own screen while you train.
   - The sign beside the Treadmill button shows the next level and the price: green when you can afford it, red when not, MAX LEVEL at level 7.
6. **Lights and particles:**
   - The corner lamps' particles and lights are off far away, in FastMode and on low graphics.
   - In The Darkened and under Cloudy skies the entry glow lights the apron.
7. **Upgrades.** Buy an upgrade: the machine, its label and the sign change level together.
8. **HUD.** A new player at level 1 sees the speed chip **×1.2**. Before, ×1 was hidden.

### Tests
`sh docs/proposals/R151/tests/run_treadmills.sh [scratch] [place.rbxl] [all | mutate]` runs:
- static checks;
- `test_treadmills151.luau`: 241 checks on the real code;
- the belt images: the game's patterns equal the PNGs byte for byte;
- the owner's place: every level before vs after, 63 checks, including z-fighting and clearance;
- the R117 treadmill suite, unchanged: 532 checks.

`mutate` also runs 12 deliberate breakages of a copy of `src/`; all 12 are caught.

`all` also runs:
- R150 `run_all.sh`, `run_sfx.sh` and `run_pedestal.sh`;
- R151 `run_speed_popups.sh`, `run_cloudy.sh` and `run_base_area.sh`;
- R149 `run_zfight.sh`.

`run_speed_popups.sh` gained the formatter boundary checks.

---

# The approved proposal (kept as written)

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
