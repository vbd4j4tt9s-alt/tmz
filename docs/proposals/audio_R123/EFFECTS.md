# R123 effects polish

## Applied (small, safe)

| File | Change | Why |
|---|---|---|
| ReplicatedStorage/SeedPackVisuals.lua | `SeedRaritySparkles`: transparency fade-in (1 -> .15 -> 1), size taper (.05 -> .08 -> .02 x scale), `LightInfluence=0` | Motes were born at full size and opacity (popping in) and were lit inconsistently between day and night |
| StarterPlayerScripts/StormWeather.client.lua | Strike "Impact sparks": `LightInfluence=0`, fade-out transparency, low count under Reduced Motion as well as low tier | Sparks vanished at full opacity; Reduced Motion was ignored |
| StarterPlayerScripts/TrackHoleClient.client.lua | Dirt burst follows ClientFxBudget (FastMode / tier 1: x0.5, tier 2: x0.75, min 3) and Reduced Motion (toss height x0.5) | It was the only new R122 effect that ignored the shared budget |

Performance: every change keeps or lowers the part and particle counts. Nothing new runs per frame.

## Checked and left as is

- TreadmillFx, RunnerBootFx, RunnerTrailEffects / RunnerTrailAuraFx, VoidPackFx and PlantingEffects already handle tier,
  FastMode, Reduced Motion, distance, fades and explicit LightInfluence/LightEmission.
- WorldEvents / BiomeWeather precipitation and LavaFlow are tiered. VeiledArrivalFx lights-out uses a smoothstep fade.
- AlwaysOnTop uses are intentional: the dropped-pack DropTimer (gameplay info, 120 studs), SpeedGainPopup, the tutorial goal
  marker, the garden owner badge and the PlantSelectionView highlight.
- Storm warning / impact SurfaceGuis sit on their own thin parts above the ground, so they do not z-fight.

## Recommendations (bigger, not done)

1. **Server biome emitters ignore FastMode / tier.** BiomeVisuals `emitter()` creates always-enabled WindblownSnow,
   CinderSmoke, RisingEmbers, PrismMotes and CrystalDust (tagged with the `BiomeEffect` attribute). Add a client governor that
   halves `Rate` on tier 2 and disables them on tier 1 or FastMode. It needs a new LocalScript plus a MANIFEST entry, so it is
   left out of this pass.
2. **Storm warning ring pops in and out.** Fade the ring stroke in over about 0.15 s and fade it into the impact, rather than
   clearing it on the phase change.
3. **PlantingEffects emitter pool (3).** Give each queued sound layer its own position (or a 4th emitter) so a late
   Sink layer cannot play at a newer pile.
4. **KeeperHitEffects** (do-not-touch): the 2 s stale window applies to the burst and camera kick too. See SYNC_AUDIT
   item 1.
5. **Unmeasured leading silence**: see the SYNC_AUDIT list. Set `Start_<id>` once it is measured in Studio.
