# R158 bats: hit detection today, why fast players are not hit, and the proposed fix

**BUILT (R158, 10 Oct): see `bats.md` section 6 (the built suite: `../tests/run_bats158.sh`, its results: `../tests/results158.txt`). The text below is the plan as approved;
section 7 lists what the code review changed.**

PREVIEW, nothing in `src/` changes until the owner approves. Owner: "improve hitbox consistency especially with fast moving players".
Checkout: `V150 R157`. Numbers come from the code, from `tests/sim_bat_hits.luau` (offline mock; today's side runs the real
`BatHitbox.lua` + `BatConfig.lua`), and from `tests/test_bat_anticheat.luau`. Re-run both with `sh tests/run_bat_hits.sh <scratch>`; full tables
are in `tests/results.txt`.

## In short

- Today **the server alone decides a hit, at one instant** (request + 0.30 s), with **one point** (the victim's root centre) in **one box**
  (14 deep x 16 wide x 10 tall), using **its own copies of both players**. Those copies are behind what the swinger's screen shows.
- The gap between "what the swinger saw" and "what the server tests" is about **(swinger's ping / 2 + about 0.1 s) x the victim's speed, plus
  (swinger's ping / 2 + packet age) x the swinger's speed**. At 120 ms ping that is about 0.16 s x speed: **23 studs at 141 studs/s, 80 studs at
  500 studs/s**. The box is 16 wide and 14 deep, so from about 100 studs/s up the server tests a spot the swinger never saw.
- In the mock, with a 120 ms ping, **0 % of the hits the swinger sees count once the victim runs 141 studs/s or more** (crossing, head-on, chase),
  and every hit the server does give is one the swinger saw as a miss. Even at the base speed of 24, a chase counts only 61 %.
- On top of that, the instant check leaves a **7-36 ms click window** against a target at 500-575 studs/s (one or two server frames).
- Proposed: the swing starts on your screen at the click; **your client sweeps the hit area over the whole strike (0.24-0.36 s) on what your
  screen shows** and names the victim; **the server re-checks that claim against a 1 s position history**, rewound by your measured lag (capped
  at 0.30 s), with distance / angle / wall / once-per-swing / rate checks. In the mock this counts 100 % of honest hits at every speed and ping
  tested (91-100 % if the real interpolation delay is 0.05-0.15 s instead of the assumed 0.10 s), and that click window grows to 121-188 ms.
- Cost of being fair to the swinger: a victim crossing at 575 studs/s can be hit ~170 studs (90th percentile, 120 ms ping; ~200 when both run at
  each other) past where it already is, i.e. ~0.3 s of its own run. Today those swings simply miss (or hit at random).

## 1. How a hit is decided today

| step | where | what happens |
|---|---|---|
| click | `BatClient.client.lua:48-50` | `tool.Activated` -> `BatSwing:FireServer()` with **no data**. "No client hit claims" (R43). The client plays nothing yet. |
| request | `BatService:Request` (`BatService.lua:23-38`) | `SecurityGate` `BatSwing` (4/s, burst 6), `MovementGuard.Check`, 0.08 s spam guard, `Cooldown` 1.0 s, bat equipped and enabled, not opening a pack. Stores `At` = server time now, `ImpactAt` = now + `Windup` 0.30 s, `Origin`. Sends `{Kind='Swing', Character, At, Serial}` to **all** clients. |
| animation | `BatClient.client.lua:72-92, 101-118` | Every client (the swinger too) starts the pose when that packet arrives, at pose time `now - At` (`Lead`); the whoosh is timed to peak at `At + 0.30`. **The swinger's own bat starts moving one full ping after the click.** |
| impact | `BatService:Step` (Heartbeat, `:57-72`) | First frame with `now >= ImpactAt` (dropped if > 0.30 s late). Swing cancelled if the swinger moved more than `max(18, WalkSpeed x 0.54)` studs since `Origin`. |
| target | `BatService:_target` (`:39-56`) + `BatHitbox.Contains` | Swinger must be eligible. For every other player that `Ragdoll:CanHit` and is eligible: is the victim's **HumanoidRootPart centre** inside the box in front of the swinger's **HumanoidRootPart**: `0 < depth <= 14`, `|side| <= 8`, `|dy| <= 5` (`HitboxSize` 16 x 10 x 14, flat `LookVector`)? Then a line-of-sight ray root to root (both characters excluded, `RespectCanCollide`). The **nearest** wins; **one victim per swing**. |
| hit | `ConcurrentKeeperService:HitByBat` (`:312-333`) | Re-checks both characters; a carrier already over the base line banks instead. Knockback 88 sideways + 42 up away from the swinger (`KnockbackConfig.Bat`), stun 1.2 s, then **unhittable for 0.65 s more** (`RecoveryGrace`). A stolen pack drops: run `Finish(..., {Cause='Bat'})`, "SMACK! PACK DROPPED"; a pyramid pack goes back: "SMACK! THE PACK WENT BACK IN THE PYRAMID" (`PyramidRules156`). `KeeperHit` packet `Cause='Bat'` -> slap sound, 8-ray star, camera kick (`KeeperHitEffects`); no fling swoosh for bats (`FlingSwoosh153`). |

**Who can hit and be hit** (`BatService:_eligible`, `RagdollService:CanHit`): both players alive, not anchored / platform-standing, not
ragdolled or flung, the map not refreshing; for the hit (not the swing) both must be **inside the biome track** and more than 4 studs past the
base line (`RequireBiome`, `SafeLineMargin`), without a ForceField and not in the first 3 s after spawning (`SpawnGrace`). Swinging works
everywhere (the hub too) but only hits in the track.

## 2. The game's real speeds

The HUD shows **speed points** (millions, billions). The body moves at the walk speed those points buy (`BalanceValues81.PointCurve`,
`Progression81.Speed`), capped in practice at 500 studs/s (+0.1 per tenfold more points). The server clamps sideways velocity at 1.15 x
(`MaxHorizontalVelocityMultiplier`), owner / Studio overrides stop at 500, and `MovementGuard` rejects faster travel.

| HUD speed points | 0 | 6,000 | 1 M | 10 M | 20 M | 100 M | 1 B | 10 B | 100 B and up |
|---|---|---|---|---|---|---|---|---|---|
| studs/s | 24 | 35 | 76 | 112 | 141 | 192 | 285 | 395 | 500 (575 worst case) |
| studs moved in 0.1 s | 2.4 | 3.5 | 7.6 | 11 | 14 | 19 | 28 | 39 | 50 (58) |
| studs moved in 0.2 s | 4.8 | 7.0 | 15 | 22 | 28 | 38 | 57 | 79 | 100 (115) |

Today's box is **16 studs wide and 14 deep**. A runner at 141+ moves more than the box's depth in 0.1 s.

## 3. Why fast players are missed (root causes)

**RC1. The server tests different positions than the swinger saw.** Each player's own client moves its character and sends it to the server
(network ownership), so the server's copy of a player is that player's position from about **their ping / 2 + up to one packet** ago. The
swinger's screen draws other players from the server's copy, another **swinger's ping / 2 + an interpolation delay** later (Roblox does not
publish it; assumed 0.10 s here, see the sensitivity row). The swinger sees itself where it really is. So at the contact frame:

| | the victim | the swinger |
|---|---|---|
| on the swinger's screen | its true spot (victim ping / 2 + swinger ping / 2 + ~0.1 s) ago | its true spot now |
| on the server, at the impact check | its true spot (victim ping / 2 + packet age) ago | its true spot (swinger ping / 2 + packet age) ago |
| **mismatch** | **victim speed x (swinger ping / 2 + ~0.1 s)** (the victim's own ping cancels out) | **swinger speed x (swinger ping / 2 + packet age)** |

Crossing in front at 141 studs/s with a 120 ms ping: the server's victim is ~23 studs further along than the swinger's screen shows, more than
the box's 16-stud width. In a chase both terms add up (both run the same way): the server sees the victim ~0.2 s x speed further ahead, so a
victim that touches the bat on your screen is 5 + 28 = 33 studs ahead on the server at 141 studs/s (box depth 14). Head-on, the server's victim
has already passed. The facing the server uses is also the swinger's old facing.

**RC2. One instant, one point, one small box.** The check runs once (the first server frame after request + 0.30 s), on the victim's root centre
only. The time a target spends inside the box is about 16 / speed (crossing) or 14 / speed (head-on): **0.11 s at 141, 32 ms at 500, 14 ms
when two 500s meet** (less than one 60 Hz frame). The server's copy of a player also moves in steps of one packet (assumed 30 Hz: 17 studs
per step at 500 studs/s), so a fast target can step over the box between two looks.

**RC3. Your own swing starts late.** The swinger's client waits for the server's `Swing` packet: the bat starts moving **one full ping after the
click** (it then skips up to 0.08 s of the wind-back), and contact on your screen is at click + ping / 2 + 0.30 s. You aim at where the runner
will be 0.30 s + half a ping later, but the animation does not show you that it started.

**RC4. The box only reaches forward from the root centre** (`depth > 0`): a target level with you or just behind you (you run past it, it runs
past you, it stands inside you) is never hit, even though the bat sweeps there.

### The mock, today vs proposed (victim ping 120 ms; full tables for pings 60 / 120 / 200 / 300 ms in `tests/results.txt`)

"Counted" = of the swings whose bat visibly hit on the swinger's own screen, the share the server counted. 1,500 random swings per cell.

| victim speed (studs/s) | 24 | 60 | 141 | 226 | 363 | 500 | 575 |
|---|---|---|---|---|---|---|---|
| crossing in front, ping 120 ms: today / proposed | 78 % / 100 % | 52 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % |
| running at you, ping 120 ms | 78 % / 100 % | 39 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % |
| chase at the same speed, ping 120 ms | 61 % / 100 % | 7 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % |
| you run past a standing victim, ping 120 ms | 86 % / 100 % | 64 % / 100 % | 16 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % |
| crossing, ping 300 ms | 67 % / 100 % | 15 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % | 0 % / 100 % |
| click window when crossing, ping 120 ms (ms) | 678 / 1183 | 260 / 509 | 117 / 258 | 64 / 209 | 47 / 182 | 29 / 154 | 33 / 128 |

Today, from 141 studs/s up, **every** server hit in the mock is one the swinger saw as a miss ("ghost hits", `results.txt`): hits feel random.
Proposed ghost hits: 0 % (the server only acts on what the swinger's screen showed). The proposed 100 % assumes the server's assumed delay
(0.10 s) is right; with a real delay of 0.05 or 0.15 s it is 91-100 % (sensitivity table in `results.txt`).

## 4. The proposed fix

### 4.1 The swing starts at the click (client prediction)
The swinger's client plays its own swing the moment it clicks (the same cooldown checked locally) and sends `Start = workspace:GetServerTimeNow()`
with the request. The server accepts `Start` within [receipt - 0.5 s, receipt + 0.02 s], keeps its cooldown / rate / eligibility checks, and
tells everyone else `At = Start` (they join late exactly as today, `Lead`). Your bat now moves with no ping delay; contact is click + 0.30 s.

### 4.2 The swinger's client sweeps the strike, on what its screen shows (`BatLagComp158.ClientFrame`)
- **When:** every rendered frame from `Start + 0.24` to `Start + 0.36` s (the strike, centred on contact at 0.30 = today's `Windup`).
- **Where:** a flat **sector in front: 14 studs** (today's box depth), **150 degrees** (+-75), **+-5 studs up/down** (today's box), plus a
  **4-stud circle all round** (someone inside you). The bat really sweeps right -> front -> left in the new swing (`swing_preview.png`, top view).
- **Swept, not sampled:** each frame tests the target's **path** since the last frame (relative to you, sub-steps of 2 studs, at most 32), so
  nothing can jump through it at any speed. The claim carries the exact sub-frame moment and your position at that moment (a fast swinger can
  pass a victim inside one frame).
- **Claim:** the first victim found -> `BatSwing:FireServer({Kind='Hit', Serial, Victim=Player, ViewTime, Own=root position, Look=flat facing})`.
  Nothing found -> a whiff (no packet).

### 4.3 The server keeps a short history (`BatLagComp158.History / Record / Sample`)
Every player's root position + flat facing, **30 times a second, 32 samples (~1.07 s)**, in preallocated number arrays (a ring buffer; nothing
is created per frame). Recorded in `BatService:Step` (already a Heartbeat step). About 6 number writes per player per sample.

### 4.4 The server checks the claim (`BatLagComp158.Validate`, all must pass)
1. **The swing:** this swinger's live swing with this `Serial`, not yet resolved (**one claim per swing**); claims rate-limited by a new
   `SecurityGate` policy `BatHit` (2/s, burst 3); `ViewTime` inside [Start + 0.19, Start + 0.41] (the strike +-0.05 s); not from the future
   (> now + 0.02 s); arrived within **0.5 s** of `ViewTime`; finite numbers; a facing of about unit length.
2. **The swinger:** the claimed spot lies within **4 studs of the swinger's own server path** from `ViewTime - 0.2 s` to now (plus 0.06 s
   ahead along its newest velocity: its latest packet can be older than the claim); the claimed facing within **45 degrees** of a facing the
   server saw in that span. A spot nowhere on its path, or a turn it never made, is refused. (`MovementGuard` keeps that path honest.)
3. **The victim, rewound:** the server looks the victim up at `ViewTime - min(0.30, claim travel time + 0.10)`, where the claim's travel time
   (`now - ViewTime`) is the swinger's real one-way delay, measured, and 0.10 s is the client's interpolation delay (assumed; measure in
   Studio). It accepts any moment within **+-0.08 s** of that (buffer / packet / frame jitter), so **never more than 0.38 s back**.
4. **Reach:** the victim's history **path** over that +-0.08 s must touch the sector around the claimed spot and facing: **14 studs + a bonus of
   0.02 x the relative speed, capped at +6** (a sample step at high speed), **+-90 degrees** (75 + 15 slack), +-5 up/down, the 4-stud circle.
5. **No walls:** a ray from the claimed spot (chest height) to the matched victim spot must be clear (today's filter: characters excluded,
   `RespectCanCollide`); also a ray from the swinger's current server spot to the claimed spot.
6. **Eligibility, now:** today's `_eligible` for both, `Ragdoll:CanHit(victim)`, then today's `HitByBat` unchanged (knockback from the
   swinger's spot, pack drop, effects packet).

### 4.5 Very high speeds
- **Rewind cap 0.30 s (+0.08 s slack):** a swinger with a ping above ~400 ms has to lead its target again; below that, what you see counts.
- **Paths, not points:** sub-stepped sweeps on the client and on the server; at 1,150 studs/s apart nothing skips the sector.
- **Bounded reach bonus** along relative speed (+6 studs at most, reached at 300 studs/s), so a stretched claim stays short.
- **The swinger's own spot comes from its own claimed position**, checked against its server path (+-4 studs), so a fast swinger is judged
  where it really was, not where the server's old copy was (today's RC1 swinger term).
- **Who wins close calls:** the swinger ("what you see is what you get", as most action games do). Tested alternative "runner first" (cap 0.12 s):
  it barely changes how far the victim really is when hit (e.g. crossing at 575: 166 vs 170 studs) but drops a 300 ms swinger to 1-96 % and a
  450 ms one to 0-69 %. Not recommended (table in `results.txt`).

### 4.6 What a cheater could send, and what stops it (`tests/test_bat_anticheat.luau`, 32 checks, all pass)

| forged claim | refused by |
|---|---|
| a victim 17 or 30 studs away, or behind you | reach / angle (`out of reach`) |
| a victim that was in reach only 0.55 s ago | rewind cap 0.30 + 0.08 (`out of reach`) |
| a short real lag claiming a long rewind | the rewind uses the claim's measured travel time, not a client number |
| a frame before / after the strike, from the future, 0.55 s late | `outside the strike`, `from the future`, `too late` |
| standing 5 or 20 studs off your real path ("I was right next to him") | `swinger not where it claims` |
| facing backwards | `swinger not facing that way` |
| through a wall | `through a wall` |
| two claims for one swing, claim spam | `one claim per swing`, `SecurityGate` `BatHit` |
| NaN / huge numbers, a zero facing, a text time | `bad numbers`, `bad facing`, `bad time` |
| a speed hack to stretch reach | `MovementGuard` (unchanged) + the bonus cap |

Honest claims accepted in the same test: in front, 66 degrees to the side, inside you, the first and last strike moments, a 300+ ms ping, a 575
studs/s swinger passing a standing victim, and two players 1,150 studs/s apart (19.5 studs, inside 14 + 6).

### 4.7 Cost
One `Validate` is ~13 microseconds in the Luau CLI (one per swing that hits). History: 32 x 6 numbers per player, written 30 times a second.
The client sweep runs ~7 frames per swing over the other players. No new instances per frame.

### 4.8 Files that would change (after approval)
`BatService.lua` (history, `Start`, claim validation; the `ImpactAt` check goes), `BatClient.client.lua` (local swing, the sweep, the claim,
the new effects), `BatHitbox.lua` (the sector test replaces the box), `BatConfig.lua` (the numbers above), `SecurityGate.lua` (`BatHit`),
`KeeperHitEffects.client.lua` (hitter kick, pooled star; see `animation.md`). `HitByBat`, knockback, stun, pack rules: unchanged.

## 5. Test plan

**Offline, done here** (`sh tests/run_bat_hits.sh <scratch>`):
- `sim_bat_hits.luau`: 5 scenarios (crossing, head-on, you run past, both run at each other, chase) x 7 speeds (24 .. 575) x 4 pings (60 .. 300
  ms), today (real `BatHitbox` + `BatConfig`, BatService's timing) vs proposed: counted / ghost / click window / how far the victim really was;
  sensitivity to the interpolation delay (0.05 / 0.10 / 0.15 s); swinger-first vs runner-first rewind cap.
- `test_bat_anticheat.luau`: the 32 accept / refuse checks above, and the cost.

**When built:**
- The same mock against the real `BatService` / `BatClient` on `tools/tests/roblox.luau` (history ring, claim handling, one claim per swing,
  cooldown, `Start` window, refusal reasons), plus mutations that must fail the suite (no rewind cap, no path check, no once-per-swing, no wall ray).
- Studio, 2-3 clients on a local server with Studio's incoming replication lag at 0 / 100 / 200 / 300 ms: a test dummy (owner speed command)
  running 141 / 363 / 500 studs/s across, at and away from the swinger; count swings that visibly hit vs hits counted (target: 95 %+).
  Measure the real interpolation delay once (log a remote stamp vs the rendered position) and set `Buffer` to it.
- Live: server counters per refusal reason, so a wrong tolerance shows up as one reason growing.

## 6. Uncertain / to check
- Roblox's interpolation delay and character send rate are not published; the mock assumes 0.10 s and 30 Hz (sensitivity shown). The design
  measures the swinger's delay per claim; only `Buffer` is a guess.
- The mock moves players in straight lines at constant speed; turning players and jumps only add to RC1 / RC2 today.
- Fairness: at 500+ studs/s a victim can be launched ~0.3 s of its own run after it passed you (it sees itself ~150 studs away). That is the price
  of counting what the swinger saw; the knockback still pushes away from the swinger.

## 7. Review fixes (after the code review of the built bats, 10 Oct)

A review found ways a cheater could stretch the rules, and two cases where honest hits were refused. All are fixed. Each one has a test that
failed on the code before the fix (`../tests/test_bat_anticheat158.luau` section 3, `test_bat_client158.luau`, `test_hit_effects158.luau`,
`test_bat_pyramid158_tail.luau`, the sim at 20 Hz) and a "break it on purpose" check in `../tests/run_bats158.sh` (38 now, all caught).

1. **The server looked too far back.** It trusted two times from the swinger's game: when the swing started and when its screen showed the hit.
   A player with no lag could say "I started 0.5 s ago" and send the claim 0.5 s late; the server then looked for the victim almost 0.9 s in the
   past (in the test, a victim already 94 studs away was hit).
   **Now** the server measures the lag itself: `Player:GetNetworkPing()`, never less than 0.05 s, plus 0.05 s (`BatConfig.PingFloor`,
   `PingSlack`; if the ping cannot be read, the 0.05 s floor is used). The start may be at most that lag before the request arrived. A claim
   may take at most that lag + one slow frame (0.1 s, `FrameSlack`) to arrive. The victim is never looked up more than 0.40 s before now
   (`MaxRewind` + `RewindSlack`), nor more than 2 x lag + 0.10 s. A swinger with a ping over about 380 ms has to lead fast runners again
   (the plan said about 400 ms).
2. **Blips and stretched spots.** After the strike a cheater could jump 52 studs forward for a moment and claim from there, or make one big step
   so the server's "a little ahead of your newest spot" stretched 80 studs. **Now** your claimed spot must be within what your walk speed carries
   you since your swing request (at least 18 studs; the same rule the server already used during the strike), a spot the history marked as a
   teleport is never one of your positions, and the stretch never goes faster than your walk speed x 1.2 (`SpeedSlack`). The walk speed is the
   one the server gave you (your Humanoid's speed on the server, or `PhysicalWalkSpeed`), not a number your game sends.
3. **Slow devices (under about 20 fps).** One frame could start before the strike or end after it, so the claimed moment fell outside the
   server's window and an honest hit was refused. **Now** your game sweeps only the part of each frame that is inside the strike (0.24 to 0.36 s);
   the server takes 0.19 to 0.41 s. Tested at 60, 30, 20, 15, 12 and 10 fps.
4. **Fast swingers when positions arrive 20 times a second.** The server's 30-a-second history then repeats positions, and the speed it
   measured over one step read as 0 ("swinger not where it claims"). **Now** speed is measured over 0.10 s (`VelocityWindow`) and the stretch
   ahead is 0.10 s (`OwnAhead`). The sim now runs every box at 30 Hz and at 20 Hz.
5. **Cooldown with a clock a little off.** With your game's clock 60 ms ahead, the server had to move your start, and the 1.0 s cooldown then
   refused every other swing you played. **Now** a moved start may come up to 0.15 s early (`CooldownSlack`), but these early bits add up to
   0.15 s at most, so nobody swings more than once a second over time.
6. **Your hit and someone else's.** The hit packet now names the hitter (`AttackerUserId`). Your screen skips only your own hits (you already saw
   them, and you never shake). If your claim was refused and another player hits the same player right after, you now see that hit (and feel
   the small shake when you are close).

Unchanged on purpose: what you see is what you get (a refused claim has already shown its slap and star; there is no take-back), contact at
0.30 s, the 0.85 s swing, no shake for the hitter, no "SMACK", the white trail, upper body only, R15 and R6. And (the owner, same day) no "SMACK"
anywhere: a bat hit that makes someone drop a pack shows no message ("ZAP!" and "CAUGHT!" stay), the pyramid pack says "THE PACK WENT BACK IN THE
PYRAMID", the owner test text says "hit pose".

**The sim after the fixes** (`../tests/results158.txt`, 1,500 swings per box, victim ping 120 ms): of the hits the swinger saw, the share the
server counted, before R158 / now.

| how they run (swinger ping 120 ms) | 24 | 141 | 285 | 500 | 575 studs/s |
|---|---|---|---|---|---|
| runs across in front, 30 Hz | 77 / 100 | 0 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| runs across in front, 20 Hz | 86 / 100 | 1 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| you run past them, 30 Hz | 84 / 100 | 11 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| you run past them, 20 Hz | 81 / 100 | 14 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| you chase them, 30 Hz / 20 Hz | 61 / 100, 61 / 100 | 0 / 100, 0 / 100 | 0 / 100, 0 / 100 | 0 / 100, 0 / 100 | 0 / 100, 0 / 100 |

Every box at 30 Hz and at 20 Hz, swinger pings 50 / 120 / 250 ms, all five ways of running: 100 % now (the suite requires 90 %). The 30 Hz
numbers are the same as before the review. Before the fixes, at 20 Hz 32 of the 75 boxes were under 90 % (44 % at worst; a 100-swings-per-box run).
Still to measure in Studio (section 5): if the real screen delay is 0.05 s instead of the assumed 0.10 s AND positions come only 20 times a
second, a runner at 500 studs/s counts 77-80 % (93-96 % at 30 Hz). `BatConfig.Buffer` should be set from that measurement.

### Tests changed on purpose (review and "no SMACK")
- `test_bat_anticheat158.luau`: the prototype case "a claim arriving 0.30 s late rewinds 0.30 s: inside" is now two cases: "arriving 0.15 s late
  (a measured 300 ms ping): inside" and "arriving 0.30 s late: never looked up more than 0.40 s before now: out of reach" (the new whole-look-back
  cap). "A start 10 s in the past is held to receipt - 0.5 s" is now "- the measured lag". Section 2's swinger has a 100 ms ping.
- `run_bats158.sh`: the unchanged-files check uses `tools/tests/r152_real_diff.sh` (the R158 release commit's `Config.Version` and the exact R158
  lines below are allowed), the registration check accepts the walls suite between bats and the pyramid on line 6 (both checks failed on the
  branch before the review for those two reasons), `no_rewind_cap` now removes the whole-look-back cap (the old cap on the rewind from the frame
  alone is always inside it), `own_hit_not_skipped` follows the new line; 13 new mutations; a new static check: no "SMACK" in any string of `src`.
- `sim_bat_hits158.luau`: runs every box at 30 and 20 Hz; the swinger's `GetNetworkPing` reads its one-way trip (the stricter reading).
- `bat_world158.luau`: players answer `GetNetworkPing` (`w.Ping`).
- `tools/tests/r152_real_diff.sh`: also puts back three exact R158 lines before comparing (ConcurrentKeeperService's pack-drop notice without
  SMACK and the bat packet's `AttackerUserId`, PyramidRules156's `Text.Bat`). `R149/tests/run_tiger_gear.sh` and `R156/tests/run_pyramid156.sh`
  check ConcurrentKeeperService with it instead of `git diff` (so R152 `run_keepers`, R153 `run_fling_swoosh` / `run_track_walls`, which already
  use it, accept the same three lines and nothing else).
