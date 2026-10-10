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
- **Miss:** the whoosh you have now (it plays at the click now, not late).
- All effects are reused, so they do not slow the game down. They turn off in Fast Mode.

## 5. Your choices

1. **Camera shake when YOU hit someone:** yes (small) / no. (The player who gets hit still shakes, like now.)
2. **Trail colour:** white / the same colour as your running trail. (There is only one bat, so "by bat rarity" does not apply.)
3. **"SMACK!" word that pops up at a hit:** yes / no.

If you say nothing, we use: shake **yes**, trail **white**, SMACK word **no**.

More detail for the builders: `hitbox.md` (hits) and `animation.md` (swing and effects).
