#!/bin/sh
# Usage: sh run_shop_states.sh <scratch dir>
# R155: the Mech pack's shop card as the real GamePassClient draws it (R120's shop harness + renderer, docs/proposals/shop_R120/tests), at two server clocks:
#   live   27d 04h 12m 09s before LimitedEvent.EndsAt: the coat line "Gold 4.5% / Diamond 0.5% coat", the countdown, "LIMITED TIME!", both buy buttons on
#   ended  30 s after EndsAt: "EVENT OVER!", "THANKS FOR PLAYING!", both buy buttons "Event over" and off
# Writes <scratch>/live/*.png and <scratch>/ended/*.png (every screen of the R120 harness). The ended run is a preview, not a test (the R120 test's price checks do not apply to it):
# its assertions are ignored here; the behaviour is tested by test_mech_coats_shop.luau.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};P=$REPO/docs/proposals;R120=$P/shop_R120/tests
for state in live ended;do
 d=$S/$state;mkdir -p "$d"
 cp "$REPO/tools/tests/roblox.luau" "$R120/world.luau" "$d/"
 python3 "$R120/mkbundle.py" "$d" "$R120/FredokaOne.ttf" >/dev/null
 if [ $state = live ];then clock="1793491200-(27*86400+4*3600+12*60+9)+R.clock";else clock="1793491200+30+R.clock";fi
 sed "s#^local V2=R.Vector2.new\$#local V2=R.Vector2.new\nW.workspace.GetServerTimeNow=function()return $clock end#" "$R120/test_shop.luau" > "$d/test_shop.luau"
 (cd "$d" && /opt/luau/luau test_shop.luau > log.txt 2>&1 || true)
 grep '^DUMP' "$d/log.txt" | grep -E '\]\}$' | sed 's/^DUMP //' > "$d/dumps.jsonl" # (the ended run stops at a price check of a later screen: a line cut by that error is dropped)
 mkdir -p "$d/png"
 python3 "$R120/render_shop.py" "$d/dumps.jsonl" "$d/png" "$R120/FredokaOne.ttf" >/dev/null
 echo "$state: $(ls "$d/png" | wc -l) pictures in $d/png"
done
