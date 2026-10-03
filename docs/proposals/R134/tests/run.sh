#!/bin/sh
# Usage: sh run.sh [scratch dir]. R134 seed checks on the Roblox mock with the real modules (needs python3 + numpy):
#  test_seeds.luau - every seed builds, no winged side shards, the five redesigns, Prism Monarch's crystal cluster,
#                    Legendary+ part animation, King rays, part counts against R133; then
#  check_floating.py on the scene it prints: no seed may have a floating or detached part.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE"/*.luau "$REPO/docs/proposals/seeds_R133/preview/check_floating.py" "$OUT/"
git -C "$REPO" show fb845f0:src/ReplicatedStorage/SeedPackVisuals.lua > "$OUT/SeedPackVisualsR133.lua"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" SeedPackVisualsR133="$OUT/SeedPackVisualsR133.lua" >/dev/null
cd "$OUT"
for t in test_*.luau;do echo "== $t";/opt/luau/luau "$t" > "$t.log" 2>&1 || { grep -v '^SCENE' "$t.log" | tail -25;exit 1; };grep -v '^SCENE\|^WARN' "$t.log" | tail -2;done
grep '^SCENE ' test_seeds.luau.log | sed 's/^SCENE //' > seeds.json
echo "== floating parts";python3 check_floating.py seeds.json
