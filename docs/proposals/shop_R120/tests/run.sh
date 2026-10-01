#!/bin/sh
# Usage: sh run.sh [scratch dir] [5 reference PNGs in order: featured passes speed speed-bundles money]
# Runs test_shop.luau under the Roblox mock and renders PNGs into ../renders.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$(mktemp -d)}; [ $# -gt 0 ] && shift
mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE/world.luau" "$HERE/test_shop.luau" "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" "$HERE/FredokaOne.ttf"
cd "$OUT"
/opt/luau/luau test_shop.luau > log.txt 2>&1 || { grep -v '^DUMP' log.txt | tail -40; exit 1; }
grep -v '^DUMP' log.txt | tail -3
grep '^DUMP' log.txt | sed 's/^DUMP //' > dumps.jsonl
python3 "$HERE/render_shop.py" dumps.jsonl "$HERE/../renders" "$HERE/FredokaOne.ttf" "$@"
