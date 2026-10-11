#!/bin/sh
# Usage: sh run_bunting158.sh [scratch dir] [place.rbxl] [mutate]
# R158 bunting (owner: "fix the disconnect flags": the hub's white string was one straight rod from a lamp post to the market's roof, but its triangle pennants hung on a curve up to
# 2.2 studs lower, centred on their points: they floated beside / under the string, and the four market-corner double lamps' strings ended 1 stud over the lamp, in the air).
# Runs docs/proposals/R151/tests/test_base_area.luau (section 19: "bunting: ...") on the owner's place in the Roblox mock, with the REAL HubLifeArt151 + HubLife151.client of this
# checkout, every detail level shown, and reads the PARTS that were built:
#   - the string is a chain of straight rod pieces, one chain per layout string, each piece meeting the next (no gap), no bend over 10 degrees, along the sag curve
#     a:Lerp(b,t) - (0, sin(t pi) 2.2, 0) (within 0.1 stud), 0.15 thick, white SmoothPlastic as before;
#   - every pennant's top edge (its two ends and its middle) lies on the string within 0.1 stud, its point hangs 1+ stud straight under the middle of that edge, its flat sides are
#     vertical and square to the string (it faces along the string), the top edge parallel to the rod piece, a Fabric WedgePart in its string's palette, none touching another;
#   - both ends of every one of the 5 strings are within 0.5 stud of a real part (the lamp's head / cap / arm, the market's green roof course): none in the air;
#   - the part count stays modest (< 80 for the five strings; R154 had 34).
# Run the z-fighting suites for the same change separately (R154 run_hub_zfight154.sh, R152 run_zfight_sweep.sh, R151 run_base_area.sh).
# With "mutate" as the 3rd argument, broken copies of src must each make a "bunting" check fail: the old straight string with the sagging pennants, pennants a stud under the
# string, leaning points, the string's ends back 1 stud over the lamps, pieces with gaps between them, a straight string under the sag, a zigzag (sag 6), plates turned across the
# string, SmoothPlastic pennants, far too many pieces.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
[ -f "$PLACE" ] || { echo "R158 bunting: SKIPPED (needs the owner's place file: $PLACE)";exit 0; }
mkdir -p "$OUT/t"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$REPO/docs/proposals/R151/tests/test_base_area.luau" "$REPO/docs/proposals/R151/preview/base_area_scene.luau" "$REPO/docs/proposals/R151/preview/standin_tree.luau" "$OUT/t/"
run() { # $1 = src tree
 python3 "$REPO/docs/proposals/R151/preview/bundle_r151.py" "$1" "$OUT/t" >/dev/null
 (cd "$OUT/t" && timeout 900 /opt/luau/luau test_base_area.luau > "$OUT/t/test.log" 2>&1)
}
if [ "$MODE" != "mutate" ];then
 if run "$REPO/src";then rc=0;else rc=1;fi
 grep -E '^(ok|FAIL) (bunting|tidy: the flags)|^BUNTING ENDS|^BUDGET bunting' "$OUT/t/test.log" | cut -c1-330
 grep -E '^R151 base area:' "$OUT/t/test.log" || tail -5 "$OUT/t/test.log"
 [ "$rc" = 0 ] && echo "R158 bunting suite passed" && exit 0
 grep -E '^FAIL' "$OUT/t/test.log";exit 1
fi
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text (replaced once)
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 total=$((total+1))
 if run "$M";then echo "MUTATION SURVIVED: $1";else
  n=$(grep -cE '^FAIL bunting|^FAIL tidy: the flags' "$OUT/t/test.log" || true)
  if [ "$n" -gt 0 ];then echo "mutation caught: $1 ($n bunting checks failed)";caught=$((caught+1));else echo "MUTATION CRASHED (no bunting check failed): $1";tail -3 "$OUT/t/test.log";fi
 fi
}
A=ReplicatedStorage/HubLifeArt151.lua
mutate "the pennants hang a stud under the string (centred on the sag curve, off the rod)" $A "pennants[#pennants+1]={Index=k,Mid=mid,Left=mid-dir*half,Right=mid+dir*half,Tip=mid-V(0,half,0)}" "mid=mid-V(0,1,0);pennants[#pennants+1]={Index=k,Mid=mid,Left=mid-dir*half,Right=mid+dir*half,Tip=mid-V(0,half,0)}"
mutate "the pennants' points lean off the plumb line" $A "Tip=mid-V(0,half,0)}" "Tip=mid-V(.6,half,0)}"
mutate "the market-corner double lamps' strings end 1 stud over the lamp, in the air" $A "{{52.5,16.25,-236},{22,23,-250},'candy'}" "{{55,17.4,-236},{22,23,-250},'candy'}"
mutate "a string's market end ends in the air beside the eave" $A "{{-52.5,16.25,-308},{-22,23,-287},'candy'}" "{{-52.5,16.25,-308},{-30,23,-287},'candy'}"
mutate "the rod pieces are shortened: a gap at every joint" $A "A.BuntingOverlap=.06" "A.BuntingOverlap=-.3"
mutate "the pieces' joints on the straight line, not on the sag (the string does not sag)" $A "pts[#pts+1]=A.BuntingCurve(a,b,(j-.5)/n)" "pts[#pts+1]=a:Lerp(b,(j-.5)/n)"
mutate "a zigzag: the sag 6 studs deep (bends over 10 degrees, not the same look)" $A "A.BuntingSag=2.2" "A.BuntingSag=6"
mutate "the plates turned across the string (not facing along it)" $A "CFrame.fromMatrix(p.Mid,y:Cross(z),y,z)," "CFrame.fromMatrix(p.Mid,y:Cross(z),y,z)*CFrame.Angles(0,math.pi/2,0),"
mutate "the pennants SmoothPlastic, not Fabric" $A "colours[(p.Index-1)%#colours+1],Mat.Fabric" "colours[(p.Index-1)%#colours+1],Mat.SmoothPlastic"
mutate "a pennant every 2 studs: far too many parts" $A "local n=math.floor((b-a).Magnitude/(spacing or 5))" "local n=math.floor((b-a).Magnitude/(spacing or 2))"
mutate "the string a thick 0.4 rod" $A "A.BuntingLine=.15" "A.BuntingLine=.4"
# the old build, whole: one straight rod, pennants on the sag centred on their points
rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
python3 - "$M/$A" <<'PY'
import sys
p=sys.argv[1]
s=open(p,encoding='utf-8').read()
a=s.index('function A.Bunting(ctx,a,b,colours,spacing)')
b=s.index('\n-- Grass patches',a)
old='''function A.Bunting(ctx,a,b,colours,spacing)
 local mid=(a+b)/2
 ctx.Rod('detail',mid.X,mid.Z,'Bunting line',a,b,.15,{250,250,250})
 local n=math.floor((b-a).Magnitude/(spacing or 5))
 local dir=(b-a).Unit;local side=V(0,1,0):Cross(dir).Unit
 for k=1,n-1 do local t=k/n;local p=a:Lerp(b,t)-V(0,math.sin(t*math.pi)*2.2,0)
  ctx.Wedge('detail',mid.X,mid.Z,'Pennant',V(.12,1.8,1.8),CFrame.fromMatrix(p,-side,V(0,1,0))*CFrame.Angles(math.rad(45),0,0),colours[(k-1)%#colours+1],Mat.Fabric,{shadow=false})
 end
end
'''
open(p,'w',encoding='utf-8').write(s[:a]+old+s[b:])
PY
total=$((total+1))
if run "$M";then echo "MUTATION SURVIVED: the old build (one straight rod, pennants on the sag)";else
 n=$(grep -cE '^FAIL bunting|^FAIL tidy: the flags' "$OUT/t/test.log" || true)
 if [ "$n" -gt 0 ];then echo "mutation caught: the old build (one straight rod, pennants on the sag, ends in the air) ($n bunting checks failed)";caught=$((caught+1));else echo "MUTATION CRASHED: the old build";tail -3 "$OUT/t/test.log";fi
fi
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
