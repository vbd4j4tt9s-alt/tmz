#!/bin/sh
# Usage: sh run_zoom_preview155.sh <scratch dir> [out png, default docs/proposals/R155/popups_zoom.png]
# Renders popups_zoom.png: the speed popups over a runner at camera distances 12.5 (the default zoom), 25 (2x), 50 (4x) and 4 studs (close-up), R154 vs R155 side by side. The popups are read
# off the tree of the REAL SpeedGainPopup client of each (BASE, default 8aa15fd = the R154 release, and this checkout) on the Roblox mock (/opt/luau/luau) after a 2 s stream; the runner is drawn with
# Pillow at the size a 70 degree camera gives it at that distance. APPROXIMATE: DejaVu for Fredoka, a block runner; not a Studio screenshot. Needs /opt/luau and python3 + Pillow.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir};OUT=${2:-$REPO/docs/proposals/R155/popups_zoom.png}
BASE=${BASE154:-8aa15fd}
T=$REPO/tools/tests;TESTS=$REPO/docs/proposals/R151/tests
mkdir -p "$S"
for w in before after;do
 d=$S/zoom_$w;mkdir -p "$d"
 cp "$T/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$TESTS/speed_popups_world.luau" "$HERE/zoom_scene155.luau" "$d/"
 if [ $w = before ];then
  git -C "$REPO" show "$BASE:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$d/Style154.lua"
  git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua" > "$d/Popup154.lua"
  python3 "$TESTS/mkbundle_speed_popups.py" "$d" SpeedPopupStyle="$d/Style154.lua" SpeedGainPopup="$d/Popup154.lua" >/dev/null
 else python3 "$TESTS/mkbundle_speed_popups.py" "$d" >/dev/null;fi
 (cd "$d" && /opt/luau/luau zoom_scene155.luau 2>&1 | grep -E '^(ZOOM|CURVE) ' > "$S/zoom_$w.txt")
done
python3 "$HERE/compose_zoom155.py" "$S" "$OUT"
