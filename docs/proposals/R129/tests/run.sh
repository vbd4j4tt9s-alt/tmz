#!/bin/sh
# Usage: sh run.sh [scratch dir]. R129 checks on the mock: phone HUD (real HudLayout, GardenWallet, WorldStatusHud) and
# base-only weather (real WorldEvents, BiomeMood; R149: the rain / snow tiles of WeatherWorld149.client.lua replace the old camera emitter).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE"/test_*.luau "$OUT/"
P=$REPO/src/StarterPlayer/StarterPlayerScripts
# mkbundle.py reads /home/user/tmz/src; bundle THIS checkout's src (a worktree has its own; R149 added WeatherWorld149 modules).
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" > "$OUT/mkbundle.py"
python3 "$OUT/mkbundle.py" "$OUT/rs_bundle.luau" WorldEvents=$P/WorldEvents.client.lua BiomePresentation=$P/BiomePresentation.client.lua BiomeWeather=$P/BiomeWeather.client.lua WeatherWorld=$P/WeatherWorld149.client.lua >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { tail -20 "$t.log";exit 1; };tail -1 "$t.log";done
