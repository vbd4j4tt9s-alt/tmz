# R153 – Mech pack: what it is today and how to make it better (proposal)

Owner: "i also want you to look at an improvement to the current mech pack". **Proposal only: no game code is changed.** You pick from the
lists at the end, then it gets built.

Picture: **`mech_pack.png`** (today next to three looks, three-quarter and side; the four at hotbar size next to a Snow pack's colour;
a five-frame storyboard of the opening with its R152 timing; the value options in one table). Blender renders on R151's stand-in chip-bag pouch. "Today" is the game's own 174 parts
(`SpecialPackArt89`, dumped on the mock) placed on that pouch. Approximate: no Roblox textures, no Future lighting, bloom imitated.
Remake it with `sh docs/proposals/R153/mech_pack/run_mech_pack_preview.sh <scratch> <python with bpy 4.5>`.

## 1. What the Mech pack is today (R152)

| | |
| --- | --- |
| What | **Limited Mech Pack**, variant `MechLimited`, category 8 (an Index category, not a map biome). `MechCatalog.lua` |
| Price | **80 gems or 80 Robux**. **5 for 375** (75 each), **10 for 700** (70 each). Only sold in the shop: the FEATURED banner "LIMITED MECH PACK / LIMITED TIME!", which shows the six seeds with their chances, SINGLE / 5 PACKS / 10 PACKS and the Gems and Robux buttons |
| Sale switch | `SaleEnabled` / `SaleEndsAt` attributes on `MechCatalog`. No end time is set in the repo, so "LIMITED TIME!" never actually ends |
| Odds | One roll on its own table, with no luck: **Plasma Pepper** Legendary **48%**, **Holo Melon** Mythic **26%**, **Prism Lotus** Mythic **16%**, **Holo Apple Tree** Secret **7%**, **Nebula Vine** Cosmic **2.5%**, **Crowncore Tree** King **0.5%**. So 1 pack in 10 is Secret or better, and 1 in 200 is the King |
| Pack size | Since R126 it rolls a size like world packs (the R137 table: 5x or bigger 1 in 71, 10x or bigger 1 in 775). Bought Mech packs neither count toward nor change the hidden size pity (`PackSizePity`) |
| Coat / shape | Always plain (`PackMutation='None'`, never Gold or Diamond). It never gets an R151 shape variation |
| Seed value | Each seed earns like a Storm seed of the same tier (`EconomyBalance90`; the Mech Cosmic is 40x and the Mech King 100x, not 60x and 500x). Cash per second per plant: Plasma Pepper 2.6M, Holo Melon 4.5M, Prism Lotus 4.6M, Holo Apple Tree 13M, Nebula Vine 26M, Crowncore 65M. **An average pack is worth 5.05M/s** at size 1x |
| Index | The **LIMITED** tab (R148): MECH SET (the 6 seeds) plus VERITY, with a countdown to 1 Nov 2026 (`LimitedEvent`). MECH SET pays +10 gems halfway and +100 gems when complete. Completing it needs the 1-in-200 King: **about 207 packs on average** (~14,500 gems at the 10-pack price) |
| How players get it | The shop (gems or Robux), and day 7 of the login week until **R153 makes day 7 a Void pack**. After that it is **mainly a purchase**. Mech *seeds* (not packs) also come from the Void pack (a 1-in-200 Mech branch) and the Verity pack (0.5%, no Crowncore). Both roll the **same Mech table**. Free gems come to about 47 a week (3 quests x 2 gems a day, plus 5 login gems), so a free player can buy one Mech pack every ~1.7 weeks |
| Look | The Forest_01 pouch painted white (231,237,239), plus 174 parts: 5 x 6 fitted armour panels per face (silver and white, 2 gold), 2 pistons with sliding cuffs, a reactor (cyan core, rings, a spinning facet, an 8-blade turbine, 4 counter-gears), power LEDs, 4 bolts and vents. The seal and tear strips are gold. 34 parts move (servos when held). The R151 audit found that the Forest_01 print shows through the white |
| Held / hotbar | When held it gets 12 neon "mechanical scanner" pieces (10 orbiting teeth and 2 scan bars, `ItemVisualEffects`). The rig animates when held or nearby. The hotbar, Bag and Index show the normal pack picture |
| Opening | **Nothing Mech-specific.** 5 clicks (Bubble04), then the R152 reveal for the seed's tier: the Legendary / Mythic card (90% of packs) or the Secret / Cosmic / King story scene (10%). A purchase announces "Bought: 10 Mech Packs!" with confetti (R148) |
| History R137–R152 | R137: bigger sizes also cover Mech packs. R139: the rainbow "new" ring includes Mech packs. R140: the login week's day 7 is a Mech pack. R147: Mech seeds go into the Verity pack. R148: the LIMITED Index tab, purchase confetti, tooltips keep the Mech pool order. R152: text in the owner's voice, and the reveal polish covers all Mech seeds |

**What is weak today:**
1. **9 buys in 10 show a Legendary or Mythic card.** After R153 the free weekly reward is a Void pack, which always gives Secret or better. That makes the 80-Robux pack look worse than a free one, even though its seeds earn more on average (Storm-level Mech seeds against Secrets from every biome).
2. **It looks pale.** At hotbar size it sits close to the pale Snow packs, and the cyan core is the only cue.
3. **Opening it feels like opening any pack.**

## 2. Value and excitement

**Two rules for every option:**
- **The per-seed table does not change** (48 / 26 / 16 / 7 / 2.5 / 0.5).
  - R153's odds display shows each seed's original rate.
  - The Void and Verity packs roll Mech seeds from this same table, so editing it would quietly move their odds too.
  - Anything extra gets **its own line** next to the odds, in the shop and on the hold tooltip. It is part of the paid-random disclosure.
- **Prices stay at 80 / 375 / 700** (gems = Robux):
  - 80 gems is ~1.7 weeks of free gems.
  - 80 Robux sits between the 49 and 149 bundles, and the 10-pack matches the 699 tier.
  - A price cut floods servers with Secret Mech plants. A price rise right after a free weekly Void pack would feel bad.
  - It is better to add value than to change the price.

| Option | What | Secret+ rate | Value per pack | Effort |
| --- | --- | --- | --- | --- |
| **1A Secret+ pity** | Every Mech pack you open without a Secret+ adds 1 to a saved counter. The 10th in a row rolls only the Secret+ rows, at their original rates rescaled (Holo Apple Tree 70%, Nebula Vine 25%, Crowncore 5%). A meter says "SECRET+ IN 7" | 10% → **15.4%** | **+16%** | medium (1–2 days): a saved counter like `PackSizePity`, a branch in `OpenSeedPack`, the meter, tests |
| 1B 10-pack guarantee | Every 10-PACK purchase has at least one Secret+ (the last unopened pack of a batch with none yet rolls the Secret+ rows) | 10% → 13.5% (10-packs only) | +11% (10-packs) | low-medium: a batch flag on the 10 records |
| **1C Coats** | Mech packs roll Gold 4.5% / Diamond 0.5% like world packs, and the seed keeps the coat. Mech plants already draw Gold / Diamond (`MechArt.BuildNative`). Fruit get x3 / x6 at the usual 20% | same | +2.3% | low-medium: the roll in `GrantMechPacks`, plus a gold / glass version of the pack art |
| 1D Not now | A 2-in-1 or "overclocked" pack, or a 7th Mech-only seed | – | – | high. Two seeds means two reveals in one opening (the R152 reveal is one seed per pack). A new seed needs new plant art and grows the MECH SET. Better kept for a "Mech season 2". A "mega" moment already exists: the size roll (5x+ 1 in 71) |

- **1A pros:** fair to single buyers too, and it ends bad streaks. Today 35% of players who open 10 Mech packs see no Secret+, and 12% after 20. The meter is a reason to buy "just 2 more".
- **1A cons:** one more saved field, and it must be listed with the odds.
- **The dial:** a pity of 15 gives 12.6% (+8%), and 20 gives 11.4% (+4%).
- **1B pros / cons:** no saved counter, and it pushes the 700 bundle. Single buyers get nothing, and the guarantee depends on the order the packs are opened.
- **1C pros / cons:** cheap excitement ("GOLD MECH PACK!") through an existing system. It needs two coat looks for the pack.

**Recommendation: 1A at 10, plus 1C.** Together that is about +19% value per Robux. Product prices stay as they are, the shown odds do not move, and a Secret story scene comes at least every 10 packs.

## 3. The look

All three options keep the standard pouch, its seal and tear strips, pivot, bounds and size roll, so the pack still reads as a chip bag (side views in the picture). A, B and C would use a **neutral pouch** (the white-vertex twin route that `VerityPouch151` already uses, falling back to today's tinted Forest_01). That way the gunmetal or chrome is the real colour and the Forest print no longer shows through.

| Option | What changes | Pros | Cons | Effort |
| --- | --- | --- | --- | --- |
| **A Refit** | A repaint: gunmetal pouch, darker steel panels, the gold panels become a hazard-yellow band, a yellow / black block seal (the 8 tear strips alternate colours, no texture), bigger bright hex bolt heads | No new parts. The rig and motion stay. Reads darker and more "machine" | Still today's busy panel grid. The hazard seal is blocky | **low**, ~0.5 day |
| **B Circuit Mech** | Gunmetal pouch, riveted steel frame, cyan **circuit traces** running out of the reactor (a pulse runs along them, using the existing `MechPulse`), 4 **hex corner bolts**, a diagonal **hazard-stripe seal**, a small **antenna with a blinking LED** on the top crimp, a MECH plate. **Keeps today's reactor and turbine** and drops the panels and pistons, so the part count stays about the same | Clearly "robot" at every size. The bolts and the seal give the opening something to do. Matches the Mech Index colours (dark body, cyan ink, gold / yellow trim) | The diagonal stripes need a texture: drawn on the client like R152's `RarePullArt`, or one uploaded decal. The fallback is A's block seal | **medium**, ~2–3 days |
| **C Holo-Chrome** | A holographic chrome pouch (the rainbow shifts as it turns, like the Holo plants), a round **scanner window** with a seed hologram and a scan ring, a chrome seal with a cyan light line | Very "premium", and ties to the hologram plants | Reads "shiny special" more than "robot". Needs a foil texture or SurfaceAppearance, and the iridescence cannot be checked offline | **medium-high**, ~3–5 days plus an asset |

**Held effect (with B):** replace the 12 orbiting scanner pieces with a soft cyan hum glow (one pulsing light) and a few sparks from the antenna (one emitter, 2–3 a second). It is calmer, cheaper in `CosmeticBudget` (Mech costs 12 there today), and reads as "powered on".

**Recommendation: B.**

## 4. The opening (a Mech touch on the R152 reveal)

**What stays the same:**
- **Same clock and same beats.** Every Mech cue sits on a beat the reveal already has, so nothing gets longer and the R152 timelines do not change.
- **Existing sounds only, at most 2 extra voices,** each quieter than the hit, under R152's caps (mix ≤ -18 LUFS, voice ≤ -20, whoosh ≤ -30). The loudness and sync suites get Mech cases.
- **Onlookers see it too,** because `SeedPackClient` draws the opening pack for everyone.
- **ReducedMotion / low quality:** no spinning bolts and no steam, just the scan colour.

**The cues (storyboard in the picture, drawn on B; today's pack and A have bolts and a reactor too):**

| Beat (R152) | Mech cue | Sound |
| --- | --- | --- |
| Clicks 1–4 (before the clock) | Each click backs out one corner bolt; click 5 opens as now | `UpgradeClick` (a ratchet tick) instead of Bubble04, same volume |
| Wobble pulses (`RarePullRules.Pulses`; Mythic .35 / .66 / .94 / 1.16 s) | A scan line sweeps the face in the R152 **hint colour**; the core and traces take the same colour (the colour walks up the ladder exactly as the seam glow does) | none added (PackShake as now) |
| Tear groups (`TearTicks`: 2, 3, 3 strips at 0 / .38 / .72 of the suspense) | The hazard seal flips open group by group, with a puff of steam each | the `Flight` whoosh pitched up into a soft hiss (it measures about -40 LUFS at its R152 volume) |
| Burst (`BurstAt`; Mythic 1.30 s) | A steam ring, the turbine spins down, the seed comes out | unchanged |
| Card / Secret+ scenes | **Unchanged.** The scene's pack is already the Mech pack | unchanged |

**Parts:** 1 scan part per face and 1 steam emitter. The bolts and strips already exist and are moved like the rig.

**Effort:**
- Clicks only: **low** (~0.5–1 day).
- The full touch: **medium** (~2 days with tests).

**Recommendation: the full touch.**

## 5. Choices for the owner

**Value** (pick one):
- **A. Secret+ pity at 10 + Gold / Diamond coats** (recommended). Dial: pity at 10 / 15 / 20.
- B. 10-pack guarantee + coats (singles unchanged).
- C. Coats only (nothing about Secret+ changes).

**Look** (pick one):
- A. Refit (repaint, ~0.5 day).
- **B. Circuit Mech** (recommended, ~2–3 days).
- C. Holo-Chrome (~3–5 days + an asset).

**Opening** (pick one):
- A. Clicks only: bolts back out with a ratchet tick.
- **B. The full Mech touch:** bolts, scan in the hint colour, unlatch with steam, steam ring (recommended).
- C. Leave the opening as it is.

**Questions:**
- **"LIMITED TIME!"**: should the pack go off sale when the Index LIMITED countdown ends (1 Nov 2026, set `SaleEndsAt`)? Or is it permanent, in which case drop "LIMITED TIME!" from the banner?
- **Keep the prices** at 80 / 375 / 700? (Recommended: yes.)

## 6. Built (R153): look B and the full opening

The owner picked **look B** and **the full Mech touch**. Value (pity, coats) is **not** approved yet: odds, prices, pity and coats are unchanged.
Picture of the real build: **`mech_pack_built.png`** (today next to the built pack, front / side / back, both at hotbar size), made from the parts the
game now builds (`sh docs/proposals/R153/mech_pack/run_mech_built_preview.sh <scratch> <python with bpy 4.5>`).

| | |
| --- | --- |
| Design | `MechPackArt153` (new; `SpecialPackArt89` delegates to it). Gunmetal pouch, riveted steel frame, 10 cyan traces a face out of R103's reactor + turbine (a soft `MechPulse` runs out along them), 4 hex corner bolts a face (3 blocks 60 degrees apart), MECH plate (14 neon strokes), a hazard seal (yellow strips / seal, a black diagonal stripe through each), an antenna with a red LED that blinks on the top crimp. Both faces. **173 design parts** (today 174) |
| The print | The pouch is `VerityPouch151`'s **generated flat pouch** (every vertex colour white, the same 1.97 x 2.06 footprint as Forest_01): gunmetal is the real colour. One server bake serves both packs. While it is not there, a plain-parts body with the same faces |
| Layers | Every layer stands .046 off the one under it, so nothing is in tools/zfight.py's .02 band even on a .5x pack. Seal, strips and stripes sit on the body's own mid-plane and the faces follow the body's depth, so every part sits flush on the pouch or the sachet, on the ground and in hand (tested) |
| Held | A soft cyan hum (one PointLight) and 2.5 sparks a second from the antenna (one ParticleEmitter), both in Attachments on the pack; `SeedPackRender` switches them on while it details the pack (no per-frame writes). No orbiting scanner any more (the Mech plants keep theirs) |
| Bounds | Only `MaxY` grows (the LED): the carry layout, pad and pickup point are unchanged. Never shaped (`PackShapes151`), as before |
| Opening | `MechPackFx153`, on the reveal's own beats (read, never set): clicks 1-4 back out a bolt each with UpgradeClick's tick at Bubble04's volume; a scan line in the hint colour on every wobble pulse (core + traces flash in it); steam + a soft hiss (the Flight whoosh pitched up, -39 LUFS) on every tear group; a steam ring and the turbine spinning down on the burst. ReducedMotion / low quality: just the colour |
| Tests | `docs/proposals/R153/tests/run_mech_pack.sh` (in the full runner) and the R152 z-fight sweep's Mech step |
