#!/bin/sh
# Phone HUD previews: sh preview.sh [scratch dir] [suffix] -> docs/proposals/R129/phone_<size><suffix>.png
# (approximate renders of the REAL HUD scripts under the mock; stand-in world, Roblox buttons and touch controls).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);DOCS=$HERE/..
OUT=${1:-$(mktemp -d)};SUFFIX=${2:-};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" \
   "$REPO/docs/proposals/polish_R124/tests/dump_gui.luau" "$HERE/phone_preview.luau" "$OUT/"
P=$REPO/src/StarterPlayer/StarterPlayerScripts
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" Hotbar=$P/Hotbar.client.lua TravelButtons=$P/TravelButtons.client.lua >/dev/null
cd "$OUT"
for size in 844x390 932x430 667x375 740x360; do
 w=${size%x*};h=${size#*x}
 printf 'W_=%s;H_=%s;EVENT=true\n' "$w" "$h" > pre.luau;cat phone_preview.luau >> pre.luau
 /opt/luau/luau pre.luau > "p$size.log" 2>&1 || { tail -20 "p$size.log";exit 1; }
 grep '^JSON ' "p$size.log" | sed 's/^JSON //' > "p$size.json";grep '^METRICS' "p$size.log" || true
 python3 "$REPO/docs/proposals/polish_R124/tests/render_gui.py" "p$size.json" "$DOCS/phone_${size}${SUFFIX}.png" 2 86,196,86
done
