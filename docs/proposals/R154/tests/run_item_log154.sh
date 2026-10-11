#!/bin/sh
# Usage: sh run_item_log154.sh [scratch dir]. R154 logging-only change in ItemPictures (the Studio Output flood "[R112] Item picture fallback ...: Pack shape is
# still loading", one line per item): the real module on the Roblox mock, in Studio: one summary line per 5 s, a real failure still warns once.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
INV=$REPO/docs/proposals/inventory_R113/tests
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_item_log154.luau" "$OUT/"
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$INV/mkbundle.py" > "$OUT/mkbundle.py"
python3 "$OUT/mkbundle.py" "$OUT/rs_bundle.luau" >/dev/null
/opt/luau/luau-compile -O0 --null "$REPO/src/ReplicatedStorage/ItemPictures.lua" >/dev/null || { echo "ItemPictures does not compile at -O0";exit 1; }
cd "$OUT"
if timeout 600 /opt/luau/luau test_item_log154.luau > log.txt 2>&1;then grep -E "^LOG |checks" log.txt;tail -n 1 log.txt;else tail -n 25 log.txt;exit 1;fi
