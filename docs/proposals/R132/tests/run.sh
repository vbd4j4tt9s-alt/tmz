#!/bin/sh
# Usage: sh run.sh [scratch dir]. R132 checks on the Roblox mock with the real modules:
#  test_fruit_of_hour.luau - the hourly pick over a year, sale bonus, server announcer, pedestal display, sell menu line.
#  test_market.luau        - the polished R69 market: building kept, real fruit/plants, pedestal without discs.
#  test_home_marker.luau   - the 🏠 over the middle of your own base only.
# Selling with the bonus (PlayerDataService) is in docs/proposals/giving_R122/tests (R132 block).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/*.luau "$OUT/"
SS=$REPO/src/ServerScriptService/ChestChaseServer;SP=$REPO/src/StarterPlayer/StarterPlayerScripts
# The market before R132 (the R131 file) for the "building kept" comparison.
git -C "$REPO" show 624da26:src/ServerScriptService/ChestChaseServer/MarketLayout.lua > "$OUT/MarketLayoutR131.lua"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" FruitOfHourService=$SS/FruitOfHourService.lua \
 MarketLayout=$SS/MarketLayout.lua MarketLayoutR131="$OUT/MarketLayoutR131.lua" FruitOfHourDisplay=$SP/FruitOfHourDisplay.client.lua HomeMarker=$SP/HomeMarker.client.lua >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { tail -20 "$t.log";exit 1; };tail -1 "$t.log";done
