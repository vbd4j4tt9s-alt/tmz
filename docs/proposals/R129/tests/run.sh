#!/bin/sh
# Usage: sh run.sh [scratch dir]. R129 checks on the mock: phone HUD (real HudLayout, GardenWallet, WorldStatusHud) and
# base-only weather (real WorldEvents, BiomeMood).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE"/test_*.luau "$OUT/"
P=$REPO/src/StarterPlayer/StarterPlayerScripts
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" WorldEvents=$P/WorldEvents.client.lua BiomePresentation=$P/BiomePresentation.client.lua BiomeWeather=$P/BiomeWeather.client.lua >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { tail -20 "$t.log";exit 1; };tail -1 "$t.log";done
