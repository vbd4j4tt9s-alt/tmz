#!/bin/sh
# Usage: sh run_hub_zfight154.sh [scratch dir] [place.rbxl] [mutate | before=<src dir>]
# R154 (owner: "remove the cases of z fighting in the hub area too"): the z-fighting sweep's STRICT HUB MODE. The R152 sweep (run_zfight_sweep.sh) only
# counts pairs with a part of our hub decor and leaves look-alike faces out; here every pair whose overlap lies in the hub counts - saved place parts
# against each other, server- and client-built parts, and look-alike faces on a textured material (they flicker in Roblox: each part lays its texture
# out from its own position) - on the owner's place after the real start-up builders, the HubLife151 client, the hub displays, the Void giveaway
# pedestal (build_hub154.sh: hub.json) and in a blizzard with the player at six spots (the hub-wide drifts of HubSnow151: snow_1..6.json).
# check_hub_zfight154.py lists every pair with where it is, ranked by how visible it is, and FAILS on any visible pair (R149's depth rule: coplanar /
# near / far, and R152's .049 for an overlap seen from the 300-stud cap) that is not on its short list of things that are not ours.
# "mutate": broken copies of src (the grass discs of a patch back in one plane, the fence's side sills back under the front / back sills, the double
# lamps' arm back flush with the caps, one shade per drift again, the drifts no longer kept off the lawns' planes) must each make the check fail. "before=<src dir>": the same scenes and list for
# another src tree (e.g. R153's), printed, never failing.
# Without the place file the suite is skipped (it needs the owner's hub).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/5ea4542b-sapkeee.rbxl};MODE=$3
SPOTS="0,-300 -90,-200 90,-200 250,-270 -250,-270 230,-560" # (every lawn within a spot's near band of the drifts, and the back corner)
[ -f "$PLACE" ] || { echo "R154 hub z-fighting: SKIPPED (no place file at $PLACE)";exit 0; }
mkdir -p "$S"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" "$PLACE" "$S/saved.json" Workspace/ChestChaseMap > /dev/null
check() { # $1 = scene dir, $2 = number of blizzard scenes; the rest: extra args
 d=$1;n=$2;shift 2
 set -- "$@" "hub=$d/hub.json";i=1;while [ $i -le $n ];do set -- "$@" "snow$i=$d/snow_$i.json";i=$((i+1));done
 python3 "$HERE/check_hub_zfight154.py" --saved "$S/saved.json" "$@"
}
case "$MODE" in
before=*)
 SRC=${MODE#before=}
 sh "$HERE/build_hub154.sh" "$S/before" "$PLACE" "$SRC" "$SPOTS"
 check "$S/before" 6 --json "$S/before/pairs.json" || true
 exit 0;;
esac
echo "== the hub as players see it (this checkout)"
sh "$HERE/build_hub154.sh" "$S/after" "$PLACE" "$REPO/src" "$SPOTS"
check "$S/after" 6 --json "$S/after/pairs.json"
[ "$MODE" = mutate ] || exit 0
echo "== mutations: broken copies must make the check fail"
mutate() { # $1 = src copy, $2 = file under it, $3 = old, $4 = new (replaced once)
 python3 - "$1/$2" "$3" "$4" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding='utf-8').read()
assert s.count(old) >= 1, 'mutation target not found: ' + old
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
}
RC=0
caught() { # $1 = log, $2 = grep pattern for the FLICKER lines, $3 = what was broken
 n=$(grep "FLICKER" "$1" | grep -c "$2" || true)
 if [ "$n" -gt 0 ];then echo "mutation caught: $3 ($n groups of pairs)";else echo "MUTATION SURVIVED: $3";RC=1;fi
}
# A: the lawns, the fences, the lamps and the drifts' shades at once (they do not hide each other)
M=$S/mutA;rm -rf "$M";mkdir -p "$M/src";cp -r "$REPO/src/." "$M/src/"
mutate "$M/src" ReplicatedStorage/HubLifeArt151.lua "function A.PatchTop(ctx,x,z,r,base)
" "function A.PatchTop(ctx,x,z,r,base)
 do return base end
"
mutate "$M/src" ReplicatedStorage/HubLifeArt151.lua "CF(x,FLOOR+12.15,z)*turn" "CF(x,FLOOR+12.2,z)*turn"
mutate "$M/src" ServerScriptService/ChestChaseServer/GardenFenceArt.lua "V(3.2,depth,front-back-3.8),CF(sign*side,footingY,(back+front)/2-.3)" "V(3.2,depth,front-back),CF(sign*side,footingY,(back+front)/2)"
mutate "$M/src" ReplicatedStorage/HubSnow151.lua " for a=1,out.N do out[a].Shade=out[find(a)].Shade end
" ""
sh "$HERE/build_hub154.sh" "$M/w" "$PLACE" "$M/src" "0,-300" > /dev/null
if check "$M/w" 1 --list 400 > "$M/check.log" 2>&1;then echo "MUTATIONS SURVIVED: the check passed on broken copy A";RC=1;fi
caught "$M/check.log" "Grass patch.*Grass patch" "the grass discs of a patch in one plane"
caught "$M/check.log" "Fence foundation" "the side sills under the front / back sills"
caught "$M/check.log" "Lamp arm" "the lamp arm flush with the caps"
caught "$M/check.log" "Snow patch.*Snow patch" "one shade per drift"
# B: the drifts no longer kept off the lawns' raised discs (alone: with the lawns back in one plane there is nothing raised to meet)
M=$S/mutB;rm -rf "$M";mkdir -p "$M/src";cp -r "$REPO/src/." "$M/src/"
mutate "$M/src" ReplicatedStorage/HubSnow151.lua "H.LawnGap=.049" "H.LawnGap=0"
sh "$HERE/build_hub154.sh" "$M/w" "$PLACE" "$M/src" "0,-300" > /dev/null
if check "$M/w" 1 --list 400 > "$M/check.log" 2>&1;then echo "MUTATIONS SURVIVED: the check passed on broken copy B";RC=1;fi
caught "$M/check.log" "Snow patch.*Grass patch\|Grass patch.*Snow patch" "the drifts' tops near the lawns' raised discs"
[ "$RC" = 0 ] && echo "all mutations caught"
exit $RC
