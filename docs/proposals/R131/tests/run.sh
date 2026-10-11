#!/bin/sh
# Usage: sh run.sh [scratch dir]. R131 checks on the Roblox mock:
#  test_weather_rate.luau - weather mutations at 0.2% per minute (real WeatherService over thousands of objects).
#  test_badge.luau        - garden owner name bubbles: stud-sized, not on top, no blank circle (real GardenFenceArt).
# Gifting fixes are in docs/proposals/giving_R122/tests (run.sh there).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE"/test_*.luau "$OUT/"
SS=$REPO/src/ServerScriptService/ChestChaseServer
# mkbundle.py reads /home/user/tmz/src; bundle THIS checkout's src (a worktree has its own).
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" > "$OUT/mkbundle.py"
python3 "$OUT/mkbundle.py" "$OUT/rs_bundle.luau" WeatherService=$SS/WeatherService.lua GardenFenceArt=$SS/GardenFenceArt.lua >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { tail -20 "$t.log";exit 1; };tail -1 "$t.log";done
