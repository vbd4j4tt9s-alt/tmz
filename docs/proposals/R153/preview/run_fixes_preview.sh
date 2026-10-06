#!/bin/sh
# Usage: sh run_fixes_preview.sh <scratch dir> [out png, default docs/proposals/R153/fixes.png] [place.rbxl]
# Renders fixes.png: the refresh barrier in the rook gate's opening (R152 vs R153, from the REAL start-up builders on the owner's place file with the track closed), the notification
# badges 1.5x (the REAL ChestIndex / HudLayout / NotifyBadge151, R152 vs R153) and the 2x speed popups on a phone (the REAL SpeedPopupStyle / HudLayout). Needs /opt/luau, python3 + Pillow.
# APPROXIMATE: flat elevations / trees drawn with Pillow (DejaVu for Fredoka), no lighting. Not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R153/fixes.png}
PLACE=${3:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
BASE=${BASE152:-e36b71b}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;R151=$REPO/docs/proposals/R151;TESTS=$R151/tests;P137=$REPO/docs/proposals/R137/preview
mkdir -p "$S"
# 1. the gate with the track closed: R152 (the src of $BASE) and this checkout
rm -rf "$S/base_src";mkdir -p "$S/base_src";git -C "$REPO" archive "$BASE" src | tar -x -C "$S/base_src"
SRC="$S/base_src/src" sh "$HERE/../tests/run_barrier_zfight.sh" "$S/zf_before" "$PLACE" > "$S/zf_before.log" 2>&1 || true
sh "$HERE/../tests/run_barrier_zfight.sh" "$S/zf_after" "$PLACE" > "$S/zf_after.log" 2>&1 || { tail -5 "$S/zf_after.log";exit 1; }
cp "$S/zf_before/scenes/refresh.json" "$S/refresh_before.json";cp "$S/zf_after/scenes/refresh.json" "$S/refresh_after.json"
# 2. the badges: the real ChestIndex tree, this checkout and the R152 ChestIndex + HudLayout + NotifyBadge151
scene() { # name, lines in front of the scene, bundle dir
 d=$S/gui_$3;mkdir -p "$d"
 [ -f "$d/world.luau" ] || cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$TESTS/layout_badges.luau" "$P137/dump_gui.luau" "$d/"
 (echo "$2";cat "$R151/preview/badge_scene.luau") > "$d/scene_$1.luau"
 (cd "$d" && /opt/luau/luau "scene_$1.luau" > "$1.out" 2> "$1.err") || { tail -20 "$d/$1.err";exit 1; }
}
python3 "$TESTS/mkbundle_badges.py" "$S/gui_after" "$REPO/src" >/dev/null
scene badge "VW=390;VH=844" after
for n in StarterPlayer/StarterPlayerScripts/ChestIndex.client ReplicatedStorage/HudLayout ReplicatedStorage/NotifyBadge151;do git -C "$REPO" show "$BASE:src/$n.lua" > "$S/base_$(basename $n).lua";done
python3 "$TESTS/mkbundle_badges.py" "$S/gui_before" "$REPO/src" ChestIndex="$S/base_ChestIndex.client.lua" HudLayout="$S/base_HudLayout.lua" NotifyBadge151="$S/base_NotifyBadge151.lua" >/dev/null
scene badge "VW=390;VH=844" before
for w in before after;do
 grep '^JSON_NAV ' "$S/gui_$w/badge.out" | sed 's/^JSON_NAV //' > "$S/badge_${w}_nav.json"
 grep '^JSON_GUI ' "$S/gui_$w/badge.out" | sed 's/^JSON_GUI //' > "$S/badge_${w}_gui.json"
done
# 3. the popups: the R152 style (1x) and this checkout's (2x) with the HUD boxes of the screens
d=$S/popups;mkdir -p "$d"
cp "$T/roblox.luau" "$INV/world.luau" "$HERE/popups_scene.luau" "$d/"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$d/ref_style.luau"
python3 "$REPO/docs/proposals/R149/tests/zfight_bundle.py" "$REPO/src" "$d" >/dev/null
(cd "$d" && /opt/luau/luau popups_scene.luau 2>&1 | grep '^POPUPS ' | sed 's/^POPUPS //' > "$S/popups.json")
python3 "$HERE/compose_fixes.py" "$S" "$OUT"
