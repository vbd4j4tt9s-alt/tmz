#!/bin/sh
# Usage: sh run_badges_preview.sh <scratch dir> [out png, default docs/proposals/R151/index_badges.png]
# Renders index_badges.png: the Index on a desktop and a phone (as it opens: the FOREST tab, the seed cards), and the notification badge before (R150) and after, zoomed 5x.
#  1. badge_scene.luau runs the REAL ChestIndex of this checkout (and, for "before", the R150 ChestIndex + HudLayout from git: INDEX_BASE, default 15d7743) under the Roblox mock, laid out by
#     tests/layout_badges.luau, and prints the GUI tree as JSON (R137/preview/dump_gui.luau);
#  2. compose_badges.py draws every JSON with the R137 renderer (Pillow) and assembles the sheet.
# Needs /opt/luau and python3 + Pillow.
# APPROXIMATE: DejaVu for Fredoka, no real font metrics. Not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R151/index_badges.png}
BASE=${INDEX_BASE:-15d7743}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;TESTS=$HERE/../tests;P137=$REPO/docs/proposals/R137/preview
mkdir -p "$S"
scene() { # name, lines in front of the scene, bundle dir
 d=$S/gui_$3;mkdir -p "$d"
 [ -f "$d/world.luau" ] || cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$TESTS/layout_badges.luau" "$P137/dump_gui.luau" "$d/"
 (echo "$2";cat "$HERE/badge_scene.luau") > "$d/scene_$1.luau"
 (cd "$d" && /opt/luau/luau "scene_$1.luau" > "$1.out" 2> "$1.err") || { tail -20 "$d/$1.err";exit 1; }
}
python3 "$TESTS/mkbundle_badges.py" "$S/gui_after" "$REPO/src" >/dev/null
scene badge "VW=390;VH=844" after
scene desktop "VW=1280;VH=1000" after
git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua" > "$S/ChestIndexBase.lua"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/HudLayout.lua" > "$S/HudLayoutBase.lua"
python3 "$TESTS/mkbundle_badges.py" "$S/gui_before" "$REPO/src" ChestIndex="$S/ChestIndexBase.lua" HudLayout="$S/HudLayoutBase.lua" >/dev/null
scene badge "VW=390;VH=844" before
for w in before after;do
 grep '^JSON_NAV ' "$S/gui_$w/badge.out" | sed 's/^JSON_NAV //' > "$S/badge_${w}_nav.json"
 grep '^JSON_GUI ' "$S/gui_$w/badge.out" | sed 's/^JSON_GUI //' > "$S/badge_${w}_gui.json"
done
grep '^JSON_GUI ' "$S/gui_after/desktop.out" | sed 's/^JSON_GUI //' > "$S/desktop_after_gui.json"
python3 "$HERE/compose_badges.py" "$S" "$OUT"
