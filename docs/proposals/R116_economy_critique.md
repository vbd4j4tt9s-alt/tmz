# Economy relook (after R115): cash balance, progression feel, timeline

**Critique only. Nothing under `src/` changed.** Economy code is unchanged since the R113 study (only `Config.Version`
moved), so the R113 simulator numbers still describe the live game. New runs for this note: first-hour purchase log,
"items bought / longest wait" per economy, and a hybrid price set. The simulator is one greedy, active player, not Studio.
Scripts: `docs/proposals/R113_economy/` (sim.py, proposal.py).

## Timeline today (median active player)

| When (active play) | What happens |
|---|---|
| 0-20 min | 8 purchases: Machine 2, Mint, Arc, Sand boots, Fence 2-3, Machine 3, Frost boots. First Mythic at ~10 min. |
| 20-60 min | 3 more (Solar trail, Machine 4, Fence 4). Snow at ~35 min. |
| 1-5 h | 4 purchases, one every ~1 h. Lava at 1.4 h, Crystal at 4.2 h. First Secret ~1.9 h. |
| 5-15 h | 4 purchases, one every ~2.5 h. Storm at 13.6 h. |
| 15-80 h | 4 purchases total: Fence 7 (28 h), Thunder boots (40 h), Machine 7 (58 h), Royal trail (80 h). Waits of 12-22 h. |
| 80 h + | Nothing left to buy. Cash piles up (70T at 100 h). First King ~57 h. |

In calendar days (active hours / hours played per day):

| Milestone | Active h (now / R113 proposal) | at 30 min a day | at 2 h a day |
|---|---|---|---|
| Storm | 13.6 / 17 | 27 / 35 days | 7 / 9 days |
| Thunder boots | 40 / 62 | 81 / 123 days | 20 / 31 days |
| Own everything | 80 / ~100 | 160 / 200 days | 40 / 50 days |

## Critique, most important first

1. **The pace falls off a cliff.** Today: one purchase every ~2.5 minutes for the first 20 minutes, then one an hour, then
   one a day of play. Almost half the shop (11 of 23 items) goes in the first hour, but the last 4 items take 65 hours.
   A player feels the game "stop" around hour 2-3. My R113 proposal smoothed the middle, but it still has waits of
   ~20 h (Crystal boots 24 h -> Nebula 29 h -> Fence 34 h -> Machine 7 42 h -> Thunder 62 h). **Prices alone cannot fix
   the late game.** There are only 23 things to buy for 80-100 hours.

2. **My R113 proposal slows the first session too much.** It halves the purchases in the first 20 minutes (8 -> 4).
   First sessions on Roblox are short, and the early shopping spree is the best part of the current game. I tried a
   hybrid: today's prices for the first 7 items, proposal prices after that. It keeps 7 buys in 20 minutes, but then has a
   55-minute gap with nothing to buy (0.3 h -> 1.2 h). That needs 1-2 extra cheap items in the first hour, not just
   price changes.

3. **Income is limited by clicking, not by the garden.** One press picks one fruit. In 75 s of harvesting per 5 minutes,
   an active player picks ~75 fruits. By 3 h they own ~100 plants, and by 10 h ~380 plants making far more fruit than
   anyone can pick. So after the first few hours:
   - planting more seeds adds nothing (most fruit never gets picked);
   - Common and Uncommon seeds are worthless (you only pick the best 75);
   - fence "grow faster" does nothing (it's already over-supplied);
   - fast clickers earn more than phone players.
   This is the biggest design problem. It is also a chance to add things to buy: "pick every fruit on a plant with one
   press", then a harvester/sprinkler upgrade line. That fixes the click limit and fills the late-game gaps from point 1.

4. **Coming back gives almost nothing.** Plants grow offline, but each plant holds only its few fruits, and you can still
   pick only ~75 per 5 minutes. There is no daily reward, streak or quest. A 30-minute-a-day player takes 27 days to reach
   Storm and has no reason to come back tomorrow except "number goes up". A daily reward plus a "welcome back" collect
   (e.g. up to 30 minutes of garden income) is cheap to build and helps retention.

5. **Value order is still broken** (unchanged since R113, the part everyone agrees on):
   - Dune Lotus is ~44% of Desert pulls and pays 180M once. Desert packs out-earn Snow packs.
   - Kings pay less than the Secrets/Cosmics of their biome (Storm King 2.5B vs Blackout Bloom 5B). Mech King (paid) pays 4x a Storm King.
   - Single-harvest Legendaries (Aurora Lily, Lava Lotus) out-pay their biome's Secret.
   This is safe to fix on its own (sell values only).

6. **Server luck matters more than the simulator shows.** Every biome gets 5 packs per 5 minutes for the whole server.
   The sim assumes you get 60% of them. On a full server with several players in the same top biome, you might get
   10-20%. At that point the Storm / King chase is 2-4x slower and depends on who else is online. Consider more packs
   in a biome when more players are in it, or per-player packs for the top biome.

7. **No late-game sink.** After ~80-100 h there is nothing to buy (income ~5-8T/h, gems at 1T each). The genre's
   standard answer is a rebirth (reset shop items for a permanent bonus and a badge), or a new biome.

8. **Robux and gems skip the early game.** A 49-Robux +30B bundle equals hours of early play and nothing late. The +25M
   speed bundle takes a new player straight to Lava. Scale bundles to the player's income (the unused
   `EconomyScaling91.CashQuote` already does this) and cap speed bundles by the current biome.

9. **Minor.** Treadmill training has no time limit, so speed can be farmed AFK. That's harmless today, because cash, not
   speed, holds players back. Kings don't matter before Thunder boots (1 in a trillion without them), so for the first
   ~60 h a King's value is only a promise.

## What I would do (in order)

1. **Fix the value order only** (point 5): one release, sell values only, no price changes. Low risk.
2. **Harvest rework** (point 3): one press picks a whole plant. Then add a harvester upgrade line (3-5 tiers) spread over
   5-80 h as new purchases.
3. **Re-pace prices** after 1 and 2. Keep today's first 20 minutes, add 1-2 cheap first-hour items, and stretch from
   hour 1 with no gap longer than ~8 h. Re-run the simulator with the new harvest rule.
4. **Retention:** daily reward and a "welcome back" collect.
5. **Later, your call:** rebirth at Storm, pack supply scaling, Robux bundle scaling.

## How much to trust these numbers

- The simulated player is greedy, never misses a pack, harvests perfectly and plays 5-minute cycles. Real players are
  slower. Treat hours as about ±20% for good players; casual players will be slower.
- Nothing here was measured in real servers. Real session length, server fill and retention need Roblox analytics after
  release.
