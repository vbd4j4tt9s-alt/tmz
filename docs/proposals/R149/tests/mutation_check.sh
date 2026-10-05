#!/bin/sh
# Usage: sh mutation_check.sh [scratch dir]   -- breaks the shipped code in a COPY of this checkout, one way at a time, and shows that run_fruit_models.sh
# fails each time (it must exit non-zero and name the broken thing). Nothing in this checkout is touched.
#  M1 Art.Key forgets the design suffix (the Ash Tomato's 4 designs would share cache entries / pictures);
#  M2 the Watermelon's gloss patch is no longer decor (it would stay on Gold / Diamond coats);
#  M3 Lantern Fern's art changes by one colour (the owner said to leave it);
#  M4 the Blueberry's stalklets are named 'Berry pedicel' (a connector: the hotbar picture would lose them and the berries float);
#  M5 Art.Get always takes design 1 (the Ash Tomato's variations would never show; the pattern follows the merged designOf line);
#  M6 the "_Neutral" twin keeps the fruit's vertex colours (a Gold / Diamond coat would be tinted green / orange);
#  M7 PlantVisuals sends every mesh key to ApprovedPlantMeshes (the melon / pumpkin keys would never find their templates);
#  M8 the Prickly Pear's art changes by one colour (the owner said to keep it as it is);
#  M9 a failed bake no longer switches the seed back to its part-built fruit;
#  M10 the pumpkin's gloss patch is not moved out (its fuller lobes would bury it);
#  M11 the spec cache key forgets the fruit-mesh suffix (specs cached before the bake would hide the meshes all session);
#  M12 the Ash Tomato's flat ash patches are .02 thinner again (review part 2, finding 5: no z-fighting with the tomato tops).
# MUTANTS="M10 M12" runs only those.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:-$(mktemp -d)};mkdir -p "$S"
mutant(){ # name file sed-expression marker
 name=$1;file=$2;expr=$3;marker=$4
 if [ -n "$MUTANTS" ] && ! echo " $MUTANTS " | grep -q " $name ";then return 0;fi
 rm -rf "$S/m";cp -a "$REPO" "$S/m"
 sed -i "$expr" "$S/m/$file"
 if cmp -s "$REPO/$file" "$S/m/$file";then echo "$name: the mutation did not change $file";exit 1;fi
 echo "== $name: $(diff "$REPO/$file" "$S/m/$file" | grep -c '^>') line(s) changed in $file"
 set +e
 (cd "$S/m" && FRUIT_KEEP_GOING=1 DIFF_LINES=3 sh docs/proposals/R149/tests/run_fruit_models.sh "$S/out" > "$S/$name.log" 2>&1);rc=$?
 set -e
 if [ $rc -eq 0 ];then echo "$name SURVIVED (the suite still passed)";exit 1;fi
 grep -m3 "FAIL\|unexpected\|changed\|floating\|not a variation" "$S/$name.log" | cut -c1-200
 grep -q "$marker" "$S/$name.log" && echo "$name KILLED (exit $rc, '$marker' reported)" || { echo "$name: failed, but not on '$marker'";exit 1; }
}
mutant M1 src/ReplicatedStorage/ApprovedPlantArt.lua "s/(10%n~=0 and('d'..tostring(h%n))or'')/''/" 'gains a design suffix'
mutant M2 src/ReplicatedStorage/PlantArtForest.lua '0,/,decor=true}/s//}/' 'exactly the gloss patch / glints are decor'
mutant M3 src/ReplicatedStorage/ApprovedPlantArt2.lua '0,/\["Height"\]=/s//["Height"]=1+/' "Lantern Fern's art"
mutant M4 src/ReplicatedStorage/PlantArtForest.lua '0,/f="Berry stalklet"/s//f="Berry pedicel"/' 'hotbar picture of fruit 1 has 18 parts'
mutant M5 src/ReplicatedStorage/ApprovedPlantArt.lua 's/local source=loaded\[id\]\[designOf(id,h,#loaded\[id\])\]/local source=loaded[id][1]/' 'all four designs are used'
mutant M6 src/ReplicatedStorage/FruitMeshes149.lua 's/c\[i\]=editable:AddColor(neutral and white or /c[i]=editable:AddColor(/' 'every vertex colour is white'
mutant M7 src/ReplicatedStorage/PlantVisuals.lua 's/return FruitMeshes.Owns(key)and FruitMeshes or ApprovedMeshes end/return ApprovedMeshes end/' 'one MeshPart from the'
mutant M8 src/ReplicatedStorage/ApprovedPlantArt6.lua '0,/\["k"\]={65,143,69}/s//["k"]={66,143,69}/' "Prickly Pear's art"
mutant M9 src/ReplicatedStorage/FruitMeshes149.lua "s/ if a=='Failed'or b=='Failed'then final\[id\]=false;return false end//" 'shows its R149 part-built fruit'
mutant M10 src/ReplicatedStorage/FruitMeshes149.lua 's/,GlossOut=1.1,UnripeNeutral=true}/,UnripeNeutral=true}/' 'the gloss patch lies on the mesh surface'
mutant M11 src/ReplicatedStorage/PlantVisuals.lua 's/\.\.SurfaceStyle\.Key(id,crop)\.\.FruitMeshes\.Suffix(id)end/..SurfaceStyle.Key(id,crop)end/' 'folded into one mesh spec'
mutant M12 src/ReplicatedStorage/ApprovedPlantArt5.lua 's/0\.042437/0.022437/g' 'flat ash patches'
echo "all mutants killed"
