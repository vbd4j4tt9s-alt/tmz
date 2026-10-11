#!/bin/sh
# Usage: sh run_popups_preview158.sh <scratch dir> [out png, default docs/proposals/R158/speed_popups158.png]
# Renders speed_popups158.png: the treadmill speed popups before (the build this round started from, BASE158: 35 px text) and after (this checkout: 53 px, 1.5x) on a computer at the default camera
# distance, zoomed out and zoomed right in, and on phones (landscape and portrait) with the HUD boxes of the real HudLayout. The popups are read off the tree of the REAL SpeedGainPopup client of
# each build on the Roblox mock (/opt/luau/luau) after a 2 s stream of "+60" popups (popups_scene158.luau); the runner is drawn with Pillow (compose_popups158.py). APPROXIMATE: DejaVu for
# Fredoka, a block runner; not a Studio screenshot. Needs /opt/luau and python3 + Pillow.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R158/speed_popups158.png}
BASE158=${BASE158:-93ce597}
T=$REPO/tools/tests;TESTS=$REPO/docs/proposals/R151/tests
mkdir -p "$S"
for w in before after;do
 d=$S/shots_$w;mkdir -p "$d"
 cp "$T/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$TESTS/speed_popups_world.luau" "$HERE/popups_scene158.luau" "$d/"
 if [ $w = before ];then
  git -C "$REPO" show "$BASE158:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$d/StyleOld.lua"
  git -C "$REPO" show "$BASE158:src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua" > "$d/PopupOld.lua"
  python3 "$TESTS/mkbundle_speed_popups.py" "$d" SpeedPopupStyle="$d/StyleOld.lua" SpeedGainPopup="$d/PopupOld.lua" >/dev/null
 else python3 "$TESTS/mkbundle_speed_popups.py" "$d" >/dev/null;fi
 (cd "$d" && /opt/luau/luau popups_scene158.luau 2>&1 | grep '^SHOT ' > "$S/shots_$w.txt")
done
python3 "$HERE/compose_popups158.py" "$S" "$OUT"
