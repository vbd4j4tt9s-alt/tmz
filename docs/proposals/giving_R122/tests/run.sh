#!/bin/sh
# Usage: sh run.sh [scratch dir]. Runs test_client.luau (FruitGiftClient input routing) and test_giving.luau (R122 pack/seed giving + fruit regression) under the
# Roblox mock with the real FruitGiftService, PlayerDataService, Config, SecurityGate and PremiumProgress.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE/world.luau" "$HERE/test_giving.luau" "$HERE/test_client.luau" "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT"
cd "$OUT"
/opt/luau/luau test_giving.luau > log.txt 2>&1 || { tail -40 log.txt; exit 1; }
tail -1 log.txt
/opt/luau/luau test_client.luau > client_log.txt 2>&1 || { tail -40 client_log.txt; exit 1; }
tail -1 client_log.txt
