#!/bin/sh
# Usage: sh run.sh [scratch dir]. R124 polish tests under the Roblox mock (real scripts from src/).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE"/*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT"
cd "$OUT"
rc=0
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || rc=1;tail -4 "$t.log";done
exit $rc
