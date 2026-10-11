#!/bin/sh
# Usage: sh run_unit154.sh [scratch dir]. R154 B1: the shared helper SmallShadow154 (the 1.5-stud rule, parts it must not touch, no listener) on the Roblox mock.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
INV=$REPO/docs/proposals/inventory_R113/tests
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_small_shadow154.luau" "$OUT/"
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$INV/mkbundle.py" > "$OUT/mkbundle.py"
python3 "$OUT/mkbundle.py" "$OUT/rs_bundle.luau" >/dev/null
cd "$OUT"
if timeout 300 /opt/luau/luau test_small_shadow154.luau > t.log 2>&1;then grep checks t.log;tail -n 1 t.log;else tail -n 12 t.log;exit 1;fi
