#!/bin/sh
# Usage: sh run_zfight.sh [scratch dir] [place.rbxl] [base commit] [mutate]
# R149 z-fighting (owner: "try to take out all the z fighting within the shop and so on"):
#  test_zfight_detector.py - tools/zfight.py on hand-made scenes with a known answer (coplanar / near / far / strict tiers, look-alike
#                            colours, decals and see-through SurfaceGui parts, opposite faces, hidden overlaps, rotations, wedges,
#                            cylinder discs and sides, balls, meshes, the map's outer edge, undersides with no room for a camera, a part or decal hidden
#                            with LocalTransparencyModifier (drawn at 1 - (1 - t) x (1 - ltm): the keyboard hides the real floor that way), the keyboard's
#                            keycaps / bed filling the space under the floor and under a shovel hole's rim).
#  test_zfight_fixer.luau  - ZFightFix149 on the Roblox mock: sane data; moves exactly the matching saved parts by their small local move
#                            and nothing else (decoys, turned / resized / ambiguous parts skipped, idempotent, one log line); on the
#                            owner's place every fix finds exactly one part and no other part changes; MapService.new calls it first.
#  check_zfight.py         - the whole map after the REAL start-up builders (zfight_scenes.sh: MapService.new with the place loaded,
#                            treadmills of all 7 skins, fences of all 7 tiers, mystery pedestals, Verity's dais, leaderboards, a shovel
#                            hole, the client keyboard + snow patches), before (base commit) and after (this checkout): per-area counts,
#                            and no counted z-fighting left that is ours (left for others: keyboard, fruit / plant art, snow discs, meshes).
# The place file is the owner's upload (not in the repo); without it the place checks are skipped. Base commit default: 3484f31 (the branch
# before this change). With "mutate" as the 4th argument, broken copies of the fixes must each make a check fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BASE=${3:-3484f31};MODE=$4
mkdir -p "$OUT/fx"
echo "== test_zfight_detector";python3 "$HERE/test_zfight_detector.py"
fixer() { # $1 = src dir
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/zfight_world.luau" "$HERE/test_zfight_fixer.luau" "$OUT/fx/"
 python3 "$HERE/zfight_bundle.py" "$1" "$OUT/fx" >/dev/null
 if [ -f "$PLACE" ];then python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/fx/place_tree.luau" Workspace/ChestChaseMap >/dev/null;else rm -f "$OUT/fx/place_tree.luau";fi
 (cd "$OUT/fx" && timeout 600 /opt/luau/luau test_zfight_fixer.luau > fixer.log 2>&1) || { tail -15 "$OUT/fx/fixer.log";return 1; }
 tail -1 "$OUT/fx/fixer.log"
}
scenes() { # $1 = out dir, $2 = src dir for "after"
 sh "$HERE/zfight_scenes.sh" "$1" "$PLACE" "$BASE" "$2" >/dev/null
 grep -q '\[R149\] Z-fighting fix: [0-9]* of [0-9]* place parts moved' "$1/after_start.steps"
 python3 "$HERE/check_zfight.py" start "$1/before_start.json" "$1/after_start.json" snow "$1/before_snow.json" "$1/after_snow.json"
}
if [ "$MODE" != "mutate" ];then
 echo "== test_zfight_fixer";fixer "$REPO/src"
 if [ ! -f "$PLACE" ];then echo "(no place file at $PLACE: the whole-map scenes were skipped)";exit 0;fi
 echo "== whole-map scenes (before = $BASE, after = this checkout)"
 sh "$HERE/zfight_scenes.sh" "$OUT/scenes" "$PLACE" "$BASE"
 grep '\[R149\] Z-fighting fix' "$OUT/scenes/after_start.steps"
 echo "== check_zfight";python3 "$HERE/check_zfight.py" start "$OUT/scenes/before_start.json" "$OUT/scenes/after_start.json" snow "$OUT/scenes/before_snow.json" "$OUT/scenes/after_snow.json"
 exit $?
fi
# --- mutation checks: undo one fix at a time in a copy of src; the checks must fail ---------------------------------------------
[ -f "$PLACE" ] || { echo "mutate needs the place file";exit 1; }
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 total=$((total+1))
 if (fixer "$M" && scenes "$OUT/mut_scenes" "$M") >"$OUT/mut.log" 2>&1;then echo "MUTATION SURVIVED: $1";else echo "mutation caught: $1";caught=$((caught+1));fi
}
C=ServerScriptService/ChestChaseServer
mutate "market roof courses no longer lapped" $C/MarketLayout.lua "if row%2==0 then p.CFrame*=CFrame.new(0,.04,0)end" ""
mutate "porch awning stripes overlap again (2.16)" $C/MarketLayout.lua "Vector3.new(2.15,.18,3.9)" "Vector3.new(2.16,.18,3.9)"
mutate "stand tier edge level with the step again" $C/MarketLayout.lua "Vector3.new(side*23.2,h-.04,-23.8+t*1.4)" "Vector3.new(side*23.2,h-.07,-23.8+t*1.4)"
mutate "showcase fruit no longer tucked under nearby tops" $C/MarketLayout.lua " if not hangs then clearTops(model)end" ""
mutate "garden fence sill .02 above the pad again" $C/GardenFenceArt.lua "local depth=pad.Size.Y+.08;local footingY=(.08-pad.Size.Y)/2" "local depth=pad.Size.Y+.02;local footingY=(.02-pad.Size.Y)/2"
mutate "treadmill underlay overlaps the surface again" $C/BiomeVisuals.lua "V(9.2,.12,12.8),CF(0,.06,0)" "V(9.2,.12,12.8),CF(0,.065,0)"
mutate "shovel hole rim .06 again" $C/TrackHoleService.lua "part('Rim',V3(.04,rimD,rimD),CFrame.new(at+V3(0,.02,0))" "part('Rim',V3(.06,rimD,rimD),CFrame.new(at+V3(0,.03,0))"
mutate "place parts no longer fixed (MapService does not call the fixer)" $C/MapService.lua "require(script.Parent.ZFightFix149).Apply(mapRoot)" "local _=0"
mutate "fixer ignores rotation" $C/ZFightFix149.lua "if math.abs(cols[k][row]-c[3+(row-1)*3+k])>F.Rotation then return false end" ""
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
