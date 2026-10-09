#!/bin/sh
# Usage: sh run_preview154.sh <scratch dir> [out png, default docs/proposals/R154/badges_popups.png] [owner badge screenshot] [owner popup screenshot]
# Renders badges_popups.png (before / after): the notification badge text (R153 vs R154, the REAL ChestIndex / HudLayout / NotifyBadge151 on the Roblox mock), the speed popups (R153 vs R154: the REAL
# SpeedPopupStyle and HudLayout, one popup over its life) and the popups' lifetimes on quality tier 1 (the REAL SpeedGainPopup client of each, frame by frame). BASE (default 006daa1, the R153
# release) is the "before". Needs /opt/luau, python3 + Pillow. APPROXIMATE: DejaVu for Fredoka, drawn from the mock's tree. Not a Studio screenshot.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R154/badges_popups.png}
OWNER_BADGE=${3:-};OWNER_POPUP=${4:-}
BASE=${BASE153:-006daa1}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;R151=$REPO/docs/proposals/R151;TESTS=$R151/tests;P137=$REPO/docs/proposals/R137/preview
mkdir -p "$S"
# 1. the badges: this checkout and the same checkout with the R153 NotifyBadge151; two screens of rewards each (2 waiting, 11 waiting = "9+")
scene() { # name, lines in front of the scene, bundle dir
 d=$S/gui_$3;mkdir -p "$d"
 [ -f "$d/world.luau" ] || cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$TESTS/layout_badges.luau" "$P137/dump_gui.luau" "$d/"
 (echo "$2";cat "$HERE/badge_scene154.luau") > "$d/scene_$1.luau"
 (cd "$d" && /opt/luau/luau "scene_$1.luau" > "$1.out" 2> "$1.err") || { tail -20 "$d/$1.err";exit 1; }
}
git -C "$REPO" show "$BASE:src/ReplicatedStorage/NotifyBadge151.lua" > "$S/base_NotifyBadge151.lua"
python3 "$TESTS/mkbundle_badges.py" "$S/gui_after" "$REPO/src" >/dev/null
python3 "$TESTS/mkbundle_badges.py" "$S/gui_before" "$REPO/src" NotifyBadge151="$S/base_NotifyBadge151.lua" >/dev/null
for w in before after;do
 scene badge "VW=390;VH=844;NINE=false" $w
 scene badge9 "VW=390;VH=844;NINE=true" $w
 grep '^JSON_NAV ' "$S/gui_$w/badge.out" | sed 's/^JSON_NAV //' > "$S/badge_${w}_nav.json"
 grep '^JSON_NAV ' "$S/gui_$w/badge9.out" | sed 's/^JSON_NAV //' > "$S/badge9_${w}_nav.json"
done
# 2. the popups: the R153 style (ref_style) and this checkout's
d=$S/popups;mkdir -p "$d"
cp "$T/roblox.luau" "$INV/world.luau" "$HERE/popups_scene154.luau" "$d/"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$d/ref_style.luau"
python3 "$REPO/docs/proposals/R149/tests/zfight_bundle.py" "$REPO/src" "$d" >/dev/null
(cd "$d" && /opt/luau/luau popups_scene154.luau 2>&1 | grep '^POPUPS ' | sed 's/^POPUPS //' > "$S/popups.json")
# 3. the popups' lifetimes on tier 1: the R153 client + style and this checkout's
for w in before after;do
 d=$S/life_$w;mkdir -p "$d"
 cp "$T/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$TESTS/speed_popups_world.luau" "$HERE/lifetimes_scene.luau" "$d/"
 if [ $w = before ];then
  git -C "$REPO" show "$BASE:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$d/Style153.lua"
  git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua" > "$d/Popup153.lua"
  python3 "$TESTS/mkbundle_speed_popups.py" "$d" SpeedPopupStyle="$d/Style153.lua" SpeedGainPopup="$d/Popup153.lua" >/dev/null
 else python3 "$TESTS/mkbundle_speed_popups.py" "$d" >/dev/null;fi
 (cd "$d" && /opt/luau/luau lifetimes_scene.luau 2>&1 | grep '^LIFE ' | sed 's/^LIFE //' > "$S/life_$w.json")
done
python3 "$HERE/compose_r154.py" "$S" "$OUT" "$OWNER_BADGE" "$OWNER_POPUP"
