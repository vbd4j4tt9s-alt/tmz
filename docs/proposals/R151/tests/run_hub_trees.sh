#!/bin/sh
# Usage: sh run_hub_trees.sh [scratch dir] [mutate]
# R151 studded hub trees (owner: "tress can also use this" + "there are different variations of trees that we can use make sure they are
# studded" + "make sure they are collision is off as we dont want players jumping around bugging with it in highspeeds" + "remove the apples or red
# stuff on the trees the trees are just trees"):
#  test_hub_trees.luau on the Roblox mock with the REAL HubTreeLoader151 / HubStudTrees151 / HubLifeArt151 / HubLife151.client of this
#  checkout and fake studded tree models: the load routes (AssetService / InsertService / by hand / none), scripts and junk stripped, every
#  part of every tree locked (no collision, touch or query), broken models, the budget per tier, fitting, colours, fruit, the attributes,
#  the rebuild, '/test hubtrees', the part-built trees / bushes / topiary studded, and NO FRUIT on any tree (part-built or model). Fast (no
#  place file needed).
# With "mutate" as the 2nd argument, broken copies of the sources must each make a check fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2
mkdir -p "$OUT/t"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/test_hub_trees.luau" "$OUT/t/"
run() { # $1 = src tree
 python3 "$REPO/docs/proposals/R151/preview/bundle_r151.py" "$1" "$OUT/t" >/dev/null
 (cd "$OUT/t" && timeout 600 /opt/luau/luau test_hub_trees.luau > "$OUT/t/test.log" 2>&1)
}
if [ "$MODE" != "mutate" ]; then
 if run "$REPO/src"; then grep -c '^ok ' "$OUT/t/test.log" >/dev/null;tail -1 "$OUT/t/test.log";else grep -E '^FAIL' "$OUT/t/test.log";tail -5 "$OUT/t/test.log";exit 1;fi
 exit 0
fi
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
 if run "$M"; then echo "MUTATION SURVIVED: $1"; else echo "mutation caught: $1 ($(grep -c '^FAIL' "$OUT/t/test.log") checks failed)"; caught=$((caught+1)); fi
}
T=ReplicatedStorage/HubStudTrees151.lua;A=ReplicatedStorage/HubLifeArt151.lua;C=StarterPlayer/StarterPlayerScripts/HubLife151.client.lua
L=ServerScriptService/ChestChaseServer/HubTreeLoader151.lua;KIT=ReplicatedStorage/HubDecorKit151.lua
mutate "collision back on for template parts" $T "if p.CanCollide~=false then p.CanCollide=false end" "if p.CanCollide~=true then p.CanCollide=true end"
mutate "template parts left touchable / queryable" $T "if p.CanTouch~=false then p.CanTouch=false end;if p.CanQuery~=false then p.CanQuery=false end" "if p.CanTouch~=true then p.CanTouch=true end;if p.CanQuery~=true then p.CanQuery=true end"
mutate "template parts left unanchored" $T " if p.Anchored~=true then p.Anchored=true end" " if p.Anchored~=false then p.Anchored=false end"
mutate "collision back on for the part-built trees (the kit)" $KIT "p.Anchored=true;p.CanCollide=o.collide==true" "p.Anchored=true;p.CanCollide=true"
mutate "scripts kept in the templates" $T "  local code=T.IsCode(o)" "  local code=false"
mutate "the client does not guard parts added later" $C "state.Guard=root.DescendantAdded:Connect(Trees.GuardSquare)" "state.Guard=nil"
mutate "the square's guard strips everything but geometry (signs, lights, particles)" $C "Connect(Trees.GuardSquare)" "Connect(Trees.Guard)"
mutate "the loader does not guard the folder" $L "L.Watch=f.DescendantAdded:Connect(" "L.Watch=f.AncestryChanged:Connect("
mutate "no per-tree budget (any size on every tier)" $T "if i.Parts<=per and" "if true and"
mutate "no total budget" $T "pick=sum.Parts+cheap.Parts<=total and cheap or nil" "pick=pick"
mutate "the AssetService route is never tried" $L "return game:GetService('AssetService'):LoadAssetAsync(id)" "error('skipped')"
mutate "the InsertService route is never tried" $L "return game:GetService('InsertService'):LoadAsset(id)" "error('skipped')"
mutate "clones not scaled to the slot" $T "  m:ScaleTo(m:GetScale()*k)" "  m:ScaleTo(m:GetScale())"
mutate "clones not grounded" $T "(o.Floor or K.Floor)-.3" "(o.Floor or K.Floor)+3"
mutate "leaves not recoloured" $T "  if o.Leaf and info.Recolourable then" "  if false then"
mutate "blossoms take textured models" $T "i.Parts<=per and(s.Kind~='blossom'or i.Recolourable)then" "i.Parts<=per then"
mutate "a clone that cannot be placed leaves a gap" $A "  if plan[i]and A.TemplateTree(ctx,x,z,kind,t[4],plan[i])then" "  if plan[i]then A.TemplateTree(ctx,x,z,kind,t[4],plan[i])"
mutate "the part-built trees are not studded" $A "return ctx.Part(level,x,z,name,size,cf,color,Mat.Plastic,{studs=true})" "return ctx.Part(level,x,z,name,size,cf,color,Mat.Plastic,{})"
mutate "studs on the wrong face" $KIT "top,bottom=bottom,top end" "top,bottom=top,bottom end"
mutate "the client never rebuilds when the folder changes" $C "or treeSig()~=state.TreeSig then build()end" "then build()end"
mutate "fruit back on the leafy trees" $A ";local pal=LEAFY[tone]or LEAFY.fresh" ";local pal=LEAFY[tone]or LEAFY.fresh;ctx.Ball('detail',x,z,'Fruit',1.3,V(x,FLOOR+9,z+3),{226,52,52},Mat.SmoothPlastic)"
mutate "red balls (apples by another name) back on the oaks" $A " local g=pick(rng,GREENS);local top=trunk(ctx,x,z,rng,1.9*s,8.5*s,pick(rng,BARKS))" " local g=pick(rng,GREENS);local top=trunk(ctx,x,z,rng,1.9*s,8.5*s,pick(rng,BARKS));ctx.Ball('detail',x,z,'Tree crown',1.3*s,(top*CF(4*s,2*s,0)).Position,{226,52,52},Mat.SmoothPlastic)"
mutate "red ember crowns back" $A "local EMBERS={{214,150,60}," "local EMBERS={{176,52,34},"
mutate "the templates keep their fruit" $T "if okSizes and #pre>0 then fruit=T.StripFruit(model)end" "if false then fruit=T.StripFruit(model)end"
mutate "unnamed red fruit kept (names only)" $T " if r>=.35 and g<=.55*r and b<=.6*r then return true end -- red" " if false then return true end -- red"
mutate "the server keeps the loaded models' fruit" $L "st.Fruit=T.IsCode(m)and 0 or T.StripFruit(m)" "st.Fruit=0"
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
