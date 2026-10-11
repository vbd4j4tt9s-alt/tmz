#!/bin/sh
# Usage: sh run_one.sh <scratch dir> <suite name>. Bundles the current src and runs ONE R151 suite (used by mutation_check.py).
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:?scratch dir};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$REPO/docs/proposals/R150/tests/ui_world.luau" "$HERE"/*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
timeout 900 /opt/luau/luau "${2:?suite}.luau" > "$2.log" 2>&1
