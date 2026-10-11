#!/bin/sh
# Gift popup previews: sh preview.sh [scratch dir] -> docs/proposals/R130/gift_popup_<size>.png
# (approximate render of the REAL FruitGiftClient popup under the mock; plain green backdrop, stand-in font).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);DOCS=$HERE/..
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/polish_R124/tests/dump_gui.luau" "$HERE/gift_preview.luau" "$OUT/"
python3 "$REPO/docs/proposals/inventory_R113/tests/mkbundle.py" "$OUT/rs_bundle.luau" FruitGiftClient=$REPO/src/StarterPlayer/StarterPlayerScripts/FruitGiftClient.client.lua >/dev/null
cd "$OUT"
for size in 1280x720 844x390; do
 w=${size%x*};h=${size#*x}
 printf 'W_=%s;H_=%s\n' "$w" "$h" > pre.luau;cat gift_preview.luau >> pre.luau
 /opt/luau/luau pre.luau > "g$size.log" 2>&1 || { tail -20 "g$size.log";exit 1; }
 grep '^JSON ' "g$size.log" | sed 's/^JSON //' > "g$size.json"
 python3 "$REPO/docs/proposals/polish_R124/tests/render_gui.py" "g$size.json" "$DOCS/gift_popup_${size}.png" 1.5 86,140,86
done
