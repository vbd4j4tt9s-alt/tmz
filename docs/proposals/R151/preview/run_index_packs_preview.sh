#!/bin/sh
# Usage: sh run_index_packs_preview.sh <scratch dir> [node_modules dir with three@0.169 and playwright] [out png, default docs/proposals/R151/index_packs.png]
# Renders index_packs.png: the Index PACKS tab on a desktop and on a phone (a card tapped open), and the notification badge before (R150) and after, zoomed 5x.
#  1. the pack pictures: tests/dump_packs.luau builds every design with the REAL pack builders on the Roblox mock with the owner's templates (the DEFAULT pouch: the Index never asks for a
#     shape variation); render_packs.mjs draws them with three.js (headless Chromium via playwright, swiftshader) on a black and a white background and make_index_packs_pictures.py
#     turns the pair into an exact transparent PNG per pack;
#  2. index_packs_scene.luau runs the REAL ChestIndex of this checkout (and, for "before", the R150 ChestIndex + HudLayout from git: INDEX_BASE, default 15d7743) under the mock,
#     laid out by tests/layout_indexpacks.luau, and prints the GUI tree as JSON (R137/preview/dump_gui.luau);
#  3. compose_index_packs.py draws every JSON with the R137 renderer (Pillow) and assembles the sheet.
# Needs /opt/luau, python3 + Pillow, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and three.js 0.169 (npm install three@0.169.0 in the scratch dir, or pass a node_modules).
# APPROXIMATE: DejaVu for Fredoka, plain three.js materials, the pouch meshes are rounded boxes (their vertices are uploaded assets). Not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${3:-$REPO/docs/proposals/R151/index_packs.png}
BASE=${INDEX_BASE:-15d7743}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;TESTS=$HERE/../tests;P137=$REPO/docs/proposals/R137/preview
mkdir -p "$S/scenes" "$S/pics_raw" "$S/pics"
# --- 1. the pack pictures -----------------------------------------------------------------------------------------------------------------------------------------------------------
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$TESTS/pack_world.luau" "$TESTS/pack_templates.luau" "$TESTS/dump_packs.luau" "$S/scenes/"
python3 "$TESTS/mkbundle_packs.py" "$S/scenes" "$REPO/src" >/dev/null
(cd "$S/scenes" && /opt/luau/luau dump_packs.luau > scenes.txt)
cp "$HERE/packs.html" "$HERE/render_packs.mjs" "$S/"
if [ -n "$2" ];then [ -e "$S/node_modules" ] || ln -s "$2" "$S/node_modules"
else [ -d "$S/node_modules/three" ] || (cd "$S" && npm install three@0.169.0 >/dev/null);fi
[ -e "$S/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/node_modules/playwright"
python3 "$HERE/make_index_packs_pictures.py" jobs "$S/scenes/scenes.txt" "$S/jobs_k.json" "$S/jobs_w.json"
for c in k w;do PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render_packs.mjs" "$S" "$S/scenes/scenes.txt" "$S/pics_raw" "$c" "$S/jobs_$c.json";done
python3 "$HERE/make_index_packs_pictures.py" matte "$S/pics_raw" "$S/pics"
# --- 2. the GUI scenes ------------------------------------------------------------------------------------------------------------------------------------------------------------
scene() { # name, file prefix lines, bundle dir
 d=$S/gui_$3;mkdir -p "$d"
 [ -f "$d/world.luau" ] || cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$TESTS/layout_indexpacks.luau" "$P137/dump_gui.luau" "$d/"
 (echo "$2";cat "$HERE/index_packs_scene.luau") > "$d/scene_$1.luau"
 (cd "$d" && /opt/luau/luau "scene_$1.luau" > "$1.out" 2> "$1.err") || { tail -20 "$d/$1.err";exit 1; }
}
python3 "$TESTS/mkbundle_indexpacks.py" "$S/gui_after" "$REPO/src" >/dev/null
scene desktop_top "VW=1280;VH=1000;WHAT='packs'" after
scene desktop_special "VW=1280;VH=1000;WHAT='packs';SCROLL_TO='Void';SCROLL_OFFSET=40" after
scene phone_top "VW=390;VH=844;WHAT='packs'" after
scene phone_open "VW=390;VH=844;WHAT='packs';SCROLL_TO='Forest_05';OPEN='Forest_05';SCROLL_OFFSET=60" after
scene badge "VW=390;VH=844;WHAT='badge'" after
git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua" > "$S/ChestIndexBase.lua"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/HudLayout.lua" > "$S/HudLayoutBase.lua"
python3 "$TESTS/mkbundle_indexpacks.py" "$S/gui_before" "$REPO/src" ChestIndex="$S/ChestIndexBase.lua" HudLayout="$S/HudLayoutBase.lua" >/dev/null
scene badge "VW=390;VH=844;WHAT='badge'" before
for n in desktop_top desktop_special phone_top phone_open;do grep '^JSON ' "$S/gui_after/$n.out" | sed 's/^JSON //' > "$S/$n.json";done
for w in before after;do
 grep '^JSON_NAV ' "$S/gui_$w/badge.out" | sed 's/^JSON_NAV //' > "$S/badge_${w}_nav.json"
 grep '^JSON_GUI ' "$S/gui_$w/badge.out" | sed 's/^JSON_GUI //' > "$S/badge_${w}_gui.json"
done
# --- 3. the sheet --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
python3 "$HERE/compose_index_packs.py" "$S" "$OUT"
