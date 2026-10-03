#!/bin/sh
# Usage: sh run.sh [scratch dir]. R133 + R135 market checks on the Roblox mock with the real modules:
#  test_market.luau - the owner's R132 play-test fixes: fruit on its visible parts, full random pack shelves, soil,
#                     wall behind the front sign, no inside MARKET lettering, hanging lights, back pottery, pedestal.
# Fruit of the Hour display and the home marker: docs/proposals/R132/tests. Tutorial text: tools/tests/test_tutorial.luau.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/*.luau "$OUT/"
SS=$REPO/src/ServerScriptService/ChestChaseServer
git -C "$REPO" show 624da26:src/ServerScriptService/ChestChaseServer/MarketLayout.lua > "$OUT/MarketLayoutR131.lua"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" MarketLayout=$SS/MarketLayout.lua MarketLayoutR131="$OUT/MarketLayoutR131.lua" >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { grep -v "pack mesh" "$t.log" | tail -25;exit 1; };tail -1 "$t.log";done
