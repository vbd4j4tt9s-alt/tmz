#!/bin/sh
# Usage: sh mutation_check.sh [scratch dir]   -- breaks the shipped code in a COPY of this checkout, one way at a time, and shows that run_fruit_models.sh
# fails each time (it must exit non-zero and name the broken thing). Nothing in this checkout is touched.
#  M1 Art.Key forgets the design suffix (the Ash Tomato's 4 designs would share cache entries / pictures);
#  M2 the Watermelon's gloss patch is no longer decor (it would stay on Gold / Diamond coats);
#  M3 Lantern Fern's art changes by one colour (the owner said to leave it);
#  M4 the Blueberry's stalklets are named 'Berry pedicel' (a connector: the hotbar picture would lose them and the berries float);
#  M5 Art.Get always takes design 1 (the Ash Tomato's variations would never show).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:-$(mktemp -d)};mkdir -p "$S"
mutant(){ # name file sed-expression marker
 name=$1;file=$2;expr=$3;marker=$4
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
mutant M5 src/ReplicatedStorage/ApprovedPlantArt.lua 's/local source=loaded\[id\]\[h%#loaded\[id\]+1\]/local source=loaded[id][1]/' 'all four designs are used'
echo "all mutants killed"
