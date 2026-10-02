#!/bin/sh
# R124 previews: sh preview.sh [scratch dir] -> PNGs in docs/proposals/polish_R124/ (approximate renders of the real GUIs).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);DOCS=$HERE/..
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE"/*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
run(){ printf '%s\n' "$1" > pre.luau; cat preview.luau >> pre.luau; /opt/luau/luau pre.luau > "$2.log" 2>&1 || { tail -20 "$2.log"; exit 1; }; grep '^JSON ' "$2.log" | sed 's/^JSON //' > "$2.json"; }
run "MODE='roll'" roll;python3 "$HERE/render_gui.py" roll.json "$DOCS/roll_window.png" 1 70,110,80
run "MODE='phone'" phone;python3 "$HERE/render_gui.py" phone.json "$DOCS/roll_window_phone.png" 1.5 70,110,80
run "MODE='wall';SECONDS=3;DOTS_AT=1.3" wall3;python3 "$HERE/render_gui.py" wall3.json "$DOCS/refresh_wall_3s.png" .6 242,242,242
run "MODE='wall';SECONDS=10;DOTS_AT=0.5" wall10;python3 "$HERE/render_gui.py" wall10.json "$DOCS/refresh_wall_10s.png" .6 242,242,242
run "MODE='gems'" gems;python3 "$HERE/render_gui.py" gems.json "$DOCS/borders_after.png" 3 20,46,35
