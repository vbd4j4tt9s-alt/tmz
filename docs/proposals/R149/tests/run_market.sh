#!/bin/sh
# Usage: sh run_market.sh [scratch dir]   (needs /opt/luau/luau, python3, git)
# R149 review part 2, finding 10: MarketLayout.clearTops boxes the market's own parts ONCE per build (not the whole market for each of the ~70 showcase
# models). On the Roblox mock with the real MarketLayout of this checkout, built next to the version before the change (PRE, default b32e359) and a copy with
# clearTops switched off: every showcase model (fruit, plants, lanterns) stands exactly where it stood (the packs are random and are not compared), some
# models really are sunk by clearTops (so the comparison is not empty), and the market is walked a few times in all instead of once per model.
# Also (same file): the sink cap of clearTops is .07 (was .045). With the Ash Tomato's thicker flat patches (review part 2, finding 5) a fruit on a stand
# step whose tomato top lies near the next step's top needs .056 to clear both the tomato tops and the patch tops (the old cap gave up and left it flickering;
# run_zfight.sh finds it). The test checks that no model sinks more than .07 and that such a fruit really sinks more than the old cap now.
# The R135 market suite (docs/proposals/R135/tests/run.sh) runs the rest of MarketLayout.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
PRE=${MARKET_PRE:-b32e359}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
INV=$REPO/docs/proposals/inventory_R113/tests;SS=$REPO/src/ServerScriptService/ChestChaseServer
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$REPO/docs/proposals/R135/tests/mockfix.luau" "$HERE/test_market_tops.luau" "$OUT/"
# the version before the change, with the new sink cap (.07, see below) so that only the caching differs
git -C "$REPO" show "$PRE:src/ServerScriptService/ChestChaseServer/MarketLayout.lua" | sed 's/if sink>.045 then return end/if sink>.07 then return end/' > "$OUT/MarketLayoutPre.lua"
if ! grep -q 'sink>.07' "$OUT/MarketLayoutPre.lua"; then echo "the sink cap was not found in $PRE";exit 1; fi
sed 's/ if not hangs then clearTops(model)end//' "$SS/MarketLayout.lua" > "$OUT/MarketLayoutNoSink.lua"
if cmp -s "$SS/MarketLayout.lua" "$OUT/MarketLayoutNoSink.lua"; then echo "the clearTops call was not found";exit 1; fi
# mkbundle.py reads /home/user/tmz/src; bundle this checkout's src
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
python3 "$OUT/mkbundle_cl.py" "$OUT/rs_bundle.luau" MarketLayout="$SS/MarketLayout.lua" MarketLayoutPre="$OUT/MarketLayoutPre.lua" MarketLayoutNoSink="$OUT/MarketLayoutNoSink.lua" >/dev/null
cd "$OUT"
/opt/luau/luau test_market_tops.luau > market.log 2>&1 || { grep -v "pack mesh" market.log | tail -25;exit 1; }
grep '^INFO' market.log || true
tail -1 market.log
