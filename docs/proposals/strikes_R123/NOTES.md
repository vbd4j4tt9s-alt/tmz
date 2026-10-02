# R123: a signature hit animation per keeper

Nothing here was run in Studio. The real modules were run offline with the Luau CLI and exact CFrame math. In the renders, mesh keepers (Snake, Ice Fang, Dragon, Jungle King) are drawn as boxes.

## Hit rule
- The server still tests contact with `KeeperContact` -> `KeeperStrikeFrames` -> `BeastPose` / `KeeperAttackPose`. None of those changed, and neither did `KeeperCombat`, `ConcurrentKeeperService` or `ChaseService`.
- `signature_check` compares the server's frames over the whole strike window (wind-up to window end) against the R112 snapshot: max difference 0 on all 7 stages. The Veiled One's `K.Frames` is also identical.
- The client move lands its contact pose at exactly `KeeperAttackAt + Windup`, the server hit time. It holds through `HitHold`, then follows through and settles by `Windup + Recovery`.
- The striking tip closes on the contact point into the hit, at its fastest near the hit. At contact the tip is 0.5 to 4.7 studs from the server's striking tip (red cube in the strips).

## Moves (`KeeperSignatureStrike`, client only)
| keeper | move | wind-up | contact | follow-through | accent |
|---|---|---|---|---|---|
| 1 Timber Golem | Overhead hammer | rises, fists flung up in a V over the crown | both fists hammer down together | sinks into the slam | dust ring and burst |
| 2 Sand Snake | Coil strike | neck lifts into a raised S coil, jaw gapes | head lunges forward and snaps shut | whip runs down the body to the tail | sand spray |
| 3 Ice Fang | Pounce swipe | crouch, tail high, paw cocked out | short hop-arc pounce, paw rakes inward | paw sweeps across, landing squash, tail lash | frost sparkle and ring |
| 4 Lava Dragon | Rear-up rake | rears on its hind legs, wings up, claws high | comes down raking one claw, wings buffet forward | tail sweeps round | fire arc (3 ember bursts) |
| 5 Crystal Knight | Diagonal slash | blade high over the sword shoulder, torso turned away | diagonal cut over the top and across | blade carried past the far hip | crystal shards and ring |
| 6 Jungle King | Chest-beat slam | rears back with two quick alternating chest beats, fists overhead | two-handed ground slam | bounce and roar | double dust ring |
| 7 Storm Colossus | Storm uppercut | crouch and twist, fist drawn back low | rising fist connects low in front | uppercut carries high overhead | lightning bolt flash, sparks, ring |
| Veiled One | Spectral lunge | sinks back, head cocked, claws spread wide, twitching | low lunge with both claws forward | glitching stutter, then a drift back | violet ring, wisps, dark dust |

Each move keeps the R112 late-replication lead: a client that sees the attack late restarts the wind-up from the idle pose. The Veiled One plays through `VeiledKeeper81.ClientFrames`, which is client only; the server keeps `K.Frames`.

## Effects (`KeeperFx.Accent`)
- Accents use the pooled rings (at most 6 at once) and the shared particle token bucket.
- Low graphics keeps only rings and half the dust: no sparks and no bolt.
- ReducedMotion removes the bolt's light flash.
- Each strike emits 12 to 26 particles.
- **Bug fixed:** `Fx.Spend` was refilled with two different clocks: server time from Step/Wake/Slam and `os.clock` from `Burst`. After any footfall the bucket went far negative, which silently dropped the R113 hit dust. It now uses one clock.

## Files
- `KeeperSignatureStrike.lua` (new, MANIFEST row added)
- `KeeperFx.lua`
- `CrystalKnightPose.lua`: optional `custom` argument and `M.Direction`; server callers do not pass `custom`
- `VeiledKeeper81.lua`: optional `sig` and `ClientFrames`; `K.Frames` is unchanged
- `BeastAnimation.client.lua`
- `VeiledEventClient81.client.lua`

## Check in Studio
- How the mesh keepers' moves read.
- How bright the bolt is at night.
- Accent density next to the R113 hit ring.
