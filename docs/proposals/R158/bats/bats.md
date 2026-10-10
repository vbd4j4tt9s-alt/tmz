# Bats: what is wrong, and what will change

This is a plan with pictures. Nothing is built yet. You say yes, no, or change it.

## 1. Why your bat misses fast players

- You swing. Your screen shows the bat hit the other player. But the game says "miss".
- Why: the game checks the hit on the server. The server sees you and the other player **a little bit in the past**. Your screen shows them a
  little bit in the past too, but **not the same past**.
- At normal speed that is a small gap. But players here run **very fast**. At top speed a player runs **500 studs every second**. In one tenth
  of a second they move **50 studs**. The bat's hit area is only **14 studs** long.
- Our test (a pretend game with fake internet lag): when the other player runs **141 speed or faster** (that is about **20 million** speed on
  your screen), **almost none** of the hits you see count. The hits that do count are ones your screen showed as a miss. That is why bats
  feel random.
- Also: your bat only starts moving **after the server answers**. With a slow internet, you click, and the bat moves late.

## 2. What will change for hits

- **Your bat swings the moment you click.** No waiting.
- **The game checks what YOUR screen showed.** Your game looks at the whole swing (not just one tiny moment) and says "I hit this player".
- **The server double-checks it**, so cheaters cannot fake hits. It checks: were you really there, were you facing them, were they really
  close at that moment, is there a wall, only one hit per swing, not too many swings. It never looks back more than 0.4 seconds.
- Our test with the fix: **91 to 100 of every 100** hits you see count, at every speed, with normal and slow internet. (Today: often 0 of
  100 once they run 141 or faster.)
- **One thing to know:** if someone runs past you at top speed and you hit them, they get knocked back a moment after they think they got
  away. That is fair to the one who swung (what you see is what you get).

## 3. The new swing

Look at **`swing_preview.png`** (still pictures) and **`swing_preview.gif`** (moving, half speed). Top row: the video you sent.

- **Now:** the bat goes up and over your head and **chops down** in front of you.
- **New (like your video):** the bat jumps **behind your head**, waits a tiny moment, then **sweeps flat across the front at hip height**, from
  your right side to your left side, wraps low behind you, and comes back up.
- The hit happens at the same moment as now (0.3 seconds after the click). The whole swing is a little longer (0.85 seconds, like the video).
- Only your **top half** swings. Your legs keep running and jumping.
- It works for both body types (R15 and R6).

## 4. New effects

- **Swing trail:** a short white streak behind the bat, only during the fast part of the swing.
- **Hit:** the star burst you have now, plus small sparks, plus a tiny "freeze" of your swing for a split second so the hit feels strong.
  The slap sound plays right away on your screen.
- **Miss:** no sound at all. (R158b, owner: "there is only a sound effect for hitting someone": the swing whoosh is gone for every swing, yours and everyone else's; only a hit has a sound.)
- All effects are reused, so they do not slow the game down. They turn off in Fast Mode.

## 5. Your choices

1. **Camera shake when YOU hit someone:** yes (small) / no. (The player who gets hit still shakes, like now.)
2. **Trail colour:** white / the same colour as your running trail. (There is only one bat, so "by bat rarity" does not apply.)
3. **"SMACK!" word that pops up at a hit:** yes / no.

If you say nothing, we use: shake **yes**, trail **white**, SMACK word **no**.

More detail for the builders: `hitbox.md` (hits) and `animation.md` (swing and effects).

## 6. Built (10 Oct)

Your answers: **no** shake for the one who hits, **no** "SMACK!" word, a **white** trail. All of it is built in `src/`.
The pictures in `swing_preview.png` are now drawn from the **built** swing (rows "BUILT"). The GIF is still the plan's.

### What you get
- **Your bat swings the moment you click.** No waiting for the server.
- **What your screen shows is what counts.** While the bat sweeps (0.24 to 0.36 seconds after the click), your game looks at where the
  other players are **on your screen** and tells the server "I hit this player". The server checks it is fair, then the hit does exactly
  what it did before (knock back, fall down, a stolen pack drops, the secret pyramid pack goes back to the pyramid).
- **The new swing:** flat, at hip height, like your video. The hit time is the same as before (0.30 seconds). The whole swing takes
  0.85 seconds. Only your top half swings: your legs keep running and jumping. It works for R15 and R6 bodies.
- **When you hit:** the slap plays at once, the star burst and small sparks show at once, and your swing freezes for a tiny moment
  (0.05 seconds). Your camera does **not** shake. The player you hit still shakes, like before. No "SMACK!" word.
- **When you miss:** nothing is heard. A swing is silent (R158b: the old whoosh was removed on purpose); only a hit makes the slap sound.
- **Trail:** a short white streak behind the bat, only while it sweeps (0.21 to 0.40 seconds). Off in Fast Mode, on slow devices, and
  for swings far away (150+ studs).
- **Carrying a pack:** you can still swing (the same rule as before). Your right arm swings the bat, your left hand stays on the pack.
- Everything is made once and used again (trail, stars, sparks): nothing new is made while the swing plays.

### Our test, built code (`tests/results158.txt`)
Of the hits you **see** on your screen, how many count. Other player's ping 120 ms, 1,500 swings for each box.

| how they run | speed 24 | 141 | 285 | 500 | 575 |
|---|---|---|---|---|---|
| runs across in front of you (your ping 120 ms): before / now | 77 / 100 | 0 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| runs at you | 79 / 100 | 0 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| you chase them | 61 / 100 | 0 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| you run past them | 84 / 100 | 11 / 100 | 0 / 100 | 0 / 100 | 0 / 100 |
| you both run at each other | 90 / 100 | 44 / 100 | 14 / 100 | 0 / 100 | 0 / 100 |

The same with your ping at 50 ms and at 250 ms: now 100 of 100 in every box (before, from 141 speed up: 0 in most boxes, 55 at most).
If the real screen delay is 0.05 or 0.15 seconds instead of the 0.10 we assume: 93 to 100 of 100.
After the code review the test also sends positions 20 times a second (some devices do): 100 of 100 in every box too (77 to 100 if the
screen delay is 0.05 seconds: measure it in Studio, item 5 below).

### How the server checks a hit (for builders; numbers in `BatConfig.lua`)
- One claim per swing; at most 2 claims a second (3 at once). The claim's moment must be inside the sweep (0.19 to 0.41 s after the
  click) and reach the server within your lag + 0.1 s (never more than 0.5 s). Your lag is what the SERVER measures (your ping, at least
  0.05 s, + 0.05 s), not a number your game sends. The click time itself is taken only within that lag before the request arrived.
- Your claimed spot must be within 4 studs of your own path on the server, your facing within 45 degrees of one the server saw, and no
  further from where you were at the click than your walk speed takes you (at least 18 studs). A teleport is never one of your spots.
- The other player is looked up where they were when your screen showed them: back by your measured delay + 0.10 s, and never more than
  0.40 s before now (and 0.08 s either side). Reach 14 studs + a little for fast players (at most +6), 90 degrees to each side, 5 studs up or down,
  or within 4 studs all round. No wall in between. A teleport is never treated as a run.
- (After the code review, 10 Oct: `hitbox.md` section 7 in simple words.)
- Then the old rules: both of you on the track past the base line, no shield (ForceField), not just spawned, not already knocked down.
- The server counts every answer by its reason. You can see the counts in Studio on `ReplicatedStorage > ChestChaseRemotes > BatSwing`
  (attributes `Claims_hit`, `Claims_out_of_reach`, ...). If one reason grows a lot for honest hits, that number needs a look.

### Small differences from the plan (builders)
- A claim names its swing by the client's own swing number (`Id`, sent with the request), not the server's `Serial` (the claim can leave
  before the server's echo arrives).
- A click time from too far back / ahead is held to the window (your measured lag back, 0.02 s ahead), not refused. The 1.0 s cooldown counts
  between click times; a request may arrive up to 0.15 s "early" (network jitter), and a click the server had to hold may too, 0.15 s in all.
- The second wall ray goes from the nearest point of your server path to your claimed spot (at most 4 studs), not from your current spot
  (a long ray could hit the track's own walls for a fast runner).
- A step faster than 1,200 studs a second in the history (a respawn, a teleport) is never swept as a path.
- The swing stays cancelled if you jump more than max(18, walk speed x 0.54) studs during the sweep (today's rule), not after it.

### Old tests changed on purpose
- `R153/tests/run_fling_swoosh.sh`: the hit effects script (`KeeperHitEffects`) may change now (pooled star, sparks, your own hit not
  shown twice). Its sound order is still tested.
- `R158/bats/tests/run_bat_hits.sh` and `R158/bats/preview/run_swing_preview158.sh`: "today" is read from git now (src holds the new code).
  They still give the same results as before.
- New suite: `R158/tests/run_bats158.sh` (in `run_all_suites.sh`), with 25 "break it on purpose" checks that must all fail (38 after the
  code review: `hitbox.md` section 7 lists the tests changed then).
- **No "SMACK" anywhere (your extra wish, 10 Oct):** a bat hit that makes someone drop a pack shows **no** message now (the "ZAP!" and
  "CAUGHT!" ones stay); the secret pyramid pack says "THE PACK WENT BACK IN THE PYRAMID"; the owner test text says "hit pose". The suite
  checks that no text players can see says SMACK (only the `/test keepersmack` command keeps its name).

### To check in Studio
1. **Feel:** swing a few times standing, running and jumping, R15 and R6. Is the hip-height sweep right? Is the tiny freeze at a hit
   nice or too much (`BatConfig.HitStop`, 0.05)? The slap volume (a swing makes no sound since R158b, so the slap is the only sound).
2. **The trail on the real bat:** it runs from half way up the bat to near the tip (found from the bat's parts). Check it sits on the
   barrel of the imported bat.
3. **Carrying a pack and swinging:** the left hand should stay on the pack.
4. **Real lag test:** 2-3 players on a local server, Studio's "incoming replication lag" at 0 / 100 / 200 / 300 ms. One player runs
   fast (141 / 363 / 500) across, at and away from the swinger. Count the swings that look like a hit and the hits that count
   (goal: 95 of 100 or more). Watch the `BatSwing` counts for refusals.
5. **Measure the real screen delay once** (`BatConfig.Buffer`, now 0.10): on one client, every frame, write down the server time
   (`workspace:GetServerTimeNow()`) and where another player is drawn. On the server, write down where that player was at each server
   time. The delay is how far back in the server's list you must look to find where the client drew them (try 0.05 to 0.20 s and pick
   the best match, minus half your ping). Put that number in `Buffer`.
6. **Fairness at top speed:** a very fast runner can be knocked back a moment after they think they got past you. That is the price of
   "what you see is what you get" for the one who swings.
7. **Bodies:** Rthro / wide heads (the hand may touch the head when the bat goes back), R15 with AnimationConstraints.
