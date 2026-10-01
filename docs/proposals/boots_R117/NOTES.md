# Boots R117: each tier clearly better, Crystal and Thunder stand out

This builds on R111/R112. Nothing has been run in Roblox Studio. The `renders/` are three.js approximations of the real `RunnerBootArt.Create()` / `ShopProductArt.Build()` output, and they show geometry only (no particles).

## Files
- `ReplicatedStorage/RunnerBootArt` (changed): tier emblems and trims. Same API. Block, Wedge and CornerWedge parts only.
- `ReplicatedStorage/RunnerTrailStyles` (changed): per-tier effect data (Land, Start, Ring, Strike, Sprint, Glint, Coils, BootArc, idle extras) and new budget fields.
- `ReplicatedStorage/RunnerTrailEffects` (changed): rainbow emitters, bursts keyed per list, rainbow crystal prints, the generalised idle rig (prisms, field nodes, dome), landing and sprint-start detection, and cleanup.
- **New** `ReplicatedStorage/RunnerBootFx` (ModuleScript): emitters mounted on the boots, the coil pulse, landing/start moments (rings, lightning, light) and arcs between the boots. It is installed onto RunnerTrailEffects, so it uses the same pools and the same Destroy. One row was added to `src/MANIFEST.tsv`.
- Not changed: `ShopProductArt` (the preview picks up the new geometry by itself), `RunnerTrailClient`, `RunnerTrailRules`, `EconomyService`, and all server gameplay.

## Look per tier (parts per leg: R111 to R117)
| Boots | Added in R117 |
|---|---|
| Sand (19 to 22) | Stitched leather heel patch with a sandstone sun stone; fabric toe stitch. No glow. |
| Frost (21 to 26) | Ice gem in a snow frame on the heel; a small glowing snowflake on the outer ankle. |
| Lava (21 to 29) | Glowing magma gem in a basalt bezel; a glowing seam all round the sole; a glowing toe welt and tongue vent; an obsidian heel spur; 2 obsidian horns on the outer cuff. |
| Crystal (21 to 35) | Faceted heel gem (glass over a glowing core) in a metal setting; a gem on the tongue; a bigger prism toe; 4 rainbow glass facets on the midsole; a tall glass crown prism with a glowing heart. |
| Thunder (22 to 38) | 3 glowing Tesla coils on a metal base ring; a metal spine with a bolt emblem; 2 prongs with glowing tips; a heel thruster; a glowing bolt on the tongue. |

Glowing parts per leg: 0 / 3 / 12 / 9 (Crystal also has 21 glass parts) / 20. Shop preview parts: 46 / 60 / 66 / 80 / 86.

## Effects per tier (each tier keeps everything from the tier below)
| | Sand | Frost | Lava | Crystal | Thunder |
|---|---|---|---|---|---|
| Walking | prints, dust | + ice glitter | + flame licks | + rainbow glints, prism flash, rainbow print centres | + plasma flash, bolt flecks, ground arcs |
| Landing (0.3 s or more in the air) | dust ring | snow burst, ice shards | magma splash, ash, expanding ring | rainbow burst, flash, rainbow ring | lightning bolt from 16 studs up (re-forks once), blue ring, sparks, brief light |
| Sprint start (after standing 0.35 s) | - | - | same as landing | same as landing | same as landing (a lightning strike) |
| Running above 30 studs/s | - | frost mist from the soles | heel flames, embers | rainbow streak, light streak | plasma streak, static trail, arcs between the boots |
| On the boots | - | - | ember wisps | glints from the heel gem, rainbow sparkle | coil sparks, spine sparks, coils pulse up the leg |
| Idle | sand swirl | frost patches, mist, snowflakes | 6 glowing cracks, embers, haze, lava bubbles | 5 rainbow prisms orbiting over 6 rainbow facets, sparkles, big glints | electric field: force-field dome, 4 orbiting charged nodes, 6 glowing charge lines, arcs (boot to ground, boot to boot, node to node), sparks, motes, glow |

All textures are built-in (`rbxasset://textures/particles/sparkles_main.dds` and `smoke_main.dds`).

## Budget
| | High | Mid | Low / FastMode |
|---|---|---|---|
| Other runners with emitters on their boots (the local wearer always has them) | 3 | 1 | 0 |
| Landing/start moment pool (8 ring + 9 bolt parts each) | 4 | 2 | 1, local wearer only |
| Light on lightning strikes | yes | no | no |

- Boot emitters, moments and arcs between the boots run only at full detail: the local wearer, or another runner who is near and on screen (75 / 60 / 45 studs). If a runner is below full detail for 1.5 s, their boot emitters are removed.
- Moment cooldown is 0.5 s for the local wearer and 1.5 s for others. Landing particles count toward the existing burst cap (160 / 90 / 40 per second).
- Reduced Motion: no rings, bolts, lights, arcs or coil pulse (coils go back to their base colour), and no dome breathing. Particles run at half rate.
- Graphics level 1-3 means low; 4-6 caps at mid (unchanged).

## Tests
`sh docs/proposals/boots_R117/tests/run.sh [scratch-dir]` runs both suites with the Luau CLI and the shared mock:
- `test_boot_fx_r111.luau`: the R111 suite (walk, idle, 500 studs/s, crowd, FastMode, Reduced Motion, unequip, respawn, leave, destroy). Three checks were updated for R117: parts per leg, crystal orbit 5 shards, and the idle-rig part bound. 374 checks, 0 failures.
- `test_boots_r117.luau`: 637 checks, 0 failures. It covers:
  - geometry per tier: strictly more parts per tier; glow and glass rules; emblems; part names the effects hook into; welds and flags; no part strays from the leg; the shop preview.
  - effect data: strictly more effect kinds and emitter specs per tier, and each tier a superset of the one below.
  - one wearer per tier through stand, sprint off, jump and land: 4 / 6 / 9 / 10 / 16 effects seen, each a superset of the tier below.
  - a crowd: culling of off-screen, mid and far runners, caps, high / mid (graphics 5) / FastMode / Reduced Motion, and the off-screen grace period.
  - leaks on unequip, respawn, leave, and script destroy during a strike.

## Check in Studio
1. The lightning bolt and ring: their size, and whether a strike every 1.5 s per nearby Thunder runner is too much in crowds.
2. The ForceField dome (4.4 studs) on Thunder idle: it may look busy. Lower `Dome.Size`, or raise `Dome.Alpha`, in RunnerTrailStyles.
3. Emitters parented to server-replicated boot parts: that they follow the feet, and that Crystal glints read on the heel gem.
4. Coil pulse colour writes on other players' boots (client-only). Check that nothing flickers when the server re-applies cosmetics.
5. Frame time with 8 Thunder/Crystal wearers nearby on mobile (low/mid budgets), compared with R112.
