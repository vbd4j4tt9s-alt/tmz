#!/bin/sh
# Usage: sh run.sh [scratch dir]. R136 checks on the Roblox mock with the real modules:
#  test_reveal.luau - Legendary / Mythic seed pulls (charge-up timing, RevealFlourish burst, onlooker sound) and
#                     every chance reading 1/N. Reveal audio: docs/proposals/audio_R123/tests. Lantern lights in the
#                     market: docs/proposals/R135/tests.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/*.luau "$OUT/"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { tail -25 "$t.log";exit 1; };tail -1 "$t.log";done
