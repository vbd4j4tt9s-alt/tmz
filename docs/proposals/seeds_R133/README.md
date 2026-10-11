# Seeds revision (proposal for R134, not in the game yet)

Owner asks, after the R132 seed preview:
- remove the ugly "winged" side shards (Diamond Vine, Prism Pepper, Ash Tomato) and redesign them;
- Prism Monarch: replace the circle around it with smaller crystals of different sizes and colours;
- effects for Rare and up, more effects and animations the rarer the seed;
- no floating or dislocated parts.

## What this proposal does
- **No side shards on any seed.** The old crystal/thorn addition also sat on Iceberry and Venom Vine; all five are redesigned:
  - **Diamond Vine:** a vine wound tight round the seed, diamond leaves on the vine, and a diamond bud on top.
  - **Prism Pepper:** a new bell-pepper body with three lobes, a green-crystal calyx and stem, and a rainbow glint down the front.
  - **Ash Tomato:** a star of sepals, a stem, and glowing ember cracks.
  - **Iceberry:** a calyx of ice spikes, frost swirls, and an icicle.
  - **Venom Vine:** a dark vine coiled round the bean, with leaves and a glowing venom drop.
- **Prism Monarch:**
  - The four round wings are gone.
  - Eight small crystals in pink, blue, mint, gold, violet and orange grow from its lower facets, in different sizes.
  - Its crown now fits the top of the gem.
- **Nothing floats.**
  - Every addition is placed on the body's real surface using new helpers (`SeedShapes133`: `Extent`, `Span`, `Surface`; `FrontZ` fixed for faceted and round bodies).
  - The crown fits each body; the star sparkle sits on the front surface.
  - Several pieces that used to float now hug the seed: orbit belts, sun rays, sparks, aurora, wind gusts and pulsar beams.
  - Automatic check: `preview/check_floating.py` finds 0 seeds with floating parts. The game now has 15; the R132 proposal had 18.
- **Effects by rarity.** The client effect layer that already runs on held seeds stays:
  - Rare: soft glow and rising motes (minor).
  - Legendary: + 1 orbit.
  - Mythic: + 2 orbits with trails.
  - Secret: + eclipse ring.
  - Cosmic: + bigger double orbit.
  - King: + floating crown.

  New on top of that:
  - **Legendary and up animate their own signature parts:** flames flicker, crystals and sparks twinkle, glows pulse. This is colour only, so held (welded) seeds never move.
  - **King** adds slow golden light rays behind the seed.

## Files
- `SeedPackVisuals133.lua`, `SeedSignatures133.lua`, `SeedShapes133.lua`: proposed versions (drop-in for the R132 proposal modules).
- `seeds_proposed.png`: every seed. `seeds_now.png`: the game today.
- `seeds_fixes.png`: the six redesigned seeds, R132 proposal (top) vs now (bottom).
- `seeds_effects.gif` / `.png`: the rarity ladder Rare → King, with effects, over time.
- `preview/run.sh <scratch> [render]`: builds every seed with the real builder on the mock, runs the floating check, and renders.

These are approximate renders: no Roblox materials, and the glow is drawn as soft sprites.
