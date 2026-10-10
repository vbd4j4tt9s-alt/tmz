#!/bin/sh
# Usage: sh mutation_fruit_fixes.sh [scratch dir]   -- breaks the shipped code in a COPY of this checkout (src, docs, tools), one way at a time, and shows that run_fruit_fixes.sh fails each
# time (it must exit non-zero and name the broken thing). Nothing in this checkout is touched. MUTANTS="F2 F5" runs only those.
#  Shine (stage 1: every plant of the catalog against the base commit)
#  S1 the Watermelon gets a gloss part back (a leaf spec renamed 'Fruit gloss');
#  S2 the art index no longer skips the removed parts (every later part of the plant would take another tint / growth stagger);
#  S3 PlantSurfaceStyle forgets the removed parts' positions (the same, for the surface details).
#  Verity face (stage 2)
#  V1 the planted Verity faces -Z again (the item's side), not the path;
#  V2 the Verity fruit grows its second face again (a back Decal next to the front one).
#  Float bug (stages 3 / 4: the real PlayerDataService, then the real runtime + client + HarvestArrival + Hotbar, every seed, every path)
#  F1 the server forgets to mark the harvest that removes the plant (PlayerDataService);
#  F2 the runtime marks the plant without HarvestedBy (an OBSERVER's client never sees the fruit leave);
#  F3 the fruit that is too big for the cap flies as a ball again (FlightMaxParts back to 48: the Frost Fern, ~220 parts);
#  F4 HarvestArrival.LandCrop lets go of a hold whose fruit is in the air (the item would appear before the fruit arrives);
#  F5 letGo does nothing (the plant's rigs keep posing the fruit that flies);
#  F6 a plant that is removed with the harvest does not fly its fruit (harvestedAway is not called before the model goes);
#  F7 a flight that ends does not release the arrival (the inventory would never show the item);
#  F8 the plants that move their own parts (Mech) are eligible for the own-parts flight again;
#  F9 the copy rate limit is gone and the budget of copies per window is 0 (a harvest of many at once would fly as balls).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:-$(mktemp -d)};mkdir -p "$S";SURVIVORS=""
mutant(){ # name stages file sed-expression marker
 name=$1;stages=$2;file=$3;expr=$4;marker=$5
 if [ -n "$MUTANTS" ] && ! echo " $MUTANTS " | grep -q " $name ";then return 0;fi
 rm -rf "$S/m";mkdir -p "$S/m"
 cp -r "$REPO/src" "$REPO/docs" "$REPO/tools" "$S/m/";cp "$REPO/.git" "$S/m/.git"
 sed -i "$expr" "$S/m/$file"
 if cmp -s "$REPO/$file" "$S/m/$file";then echo "$name: the mutation did not change $file";exit 1;fi
 echo "== $name: $(diff "$REPO/$file" "$S/m/$file" | grep -c '^>') line(s) changed in $file (stages: $stages)"
 set +e
 (cd "$S/m" && ONLY="$stages" sh docs/proposals/R151/tests/run_fruit_fixes.sh "$S/out_$name" > "$S/$name.log" 2>&1);rc=$?
 set -e
 if [ $rc -eq 0 ];then echo "$name SURVIVED (the suite still passed)";SURVIVORS="$SURVIVORS $name";return 0;fi
 grep -v '^WARN\|^SCENE\|^SEED\|^PATHS' "$S/$name.log" | grep -m3 -i "FAIL\|changed\|not \|expected\|differ" | cut -c1-220
 if [ -n "$marker" ];then grep -q "$marker" "$S/$name.log" && echo "$name KILLED (exit $rc, '$marker' reported)" || { echo "$name: failed, but not on '$marker'";SURVIVORS="$SURVIVORS $name"; };else echo "$name KILLED (exit $rc)";fi
}
SRC=src/ReplicatedStorage;SP=src/StarterPlayer/StarterPlayerScripts;SRV=src/ServerScriptService/ChestChaseServer
mutant S1 1 $SRC/PlantArtForest.lua '0,/f="Melon leaf"/s//f="Fruit gloss"/' 'changed'
mutant S2 1 $SRC/PlantVisuals.lua 's/at+=1;while skipped and skipped\[at\]do at+=1 end/at+=1/' 'changed'
mutant S3 1 $SRC/PlantSurfaceStyle.lua 's/while skipped and skipped\[i\]do shift+=1;i+=1 end/shift+=0/' 'changed'
mutant V1 2 $SRC/VerityPlantArt.lua 's/^ return Enum.NormalId.Back$/ return Enum.NormalId.Front/' ''
mutant V2 2 $SRC/VerityPlantArt.lua 's/^ return d$/ local b=d:Clone();b.Face=Enum.NormalId.Back;b.Parent=part;return d/' ''
mutant F1 3 $SRV/PlayerDataService.lua "s/marks\[crop.Id\]={Index=fruitIndex,By=player.UserId,At=os.clock()}/local _=nil/" ''
mutant F2 4 $SRV/GardenPlantRuntime.lua "s/;model:SetAttribute('HarvestedBy',mark.By)//" ''
mutant F3 4 $SRC/PlantGrowthFx.lua 's/FlightMaxParts=300/FlightMaxParts=48/' ''
mutant F4 4 $SRC/HarvestArrival.lua 's/ and not entry.Flying then table.insert(list,k)end/ then table.insert(list,k)end/' ''
mutant F5 4 $SP/GardenVisuals.client.lua 's/^local function letGo(r)$/local function letGo(r) if true then return end/' ''
mutant F6 4 $SP/GardenVisuals.client.lua 's/^  harvestedAway(item,r) -- R151:.*$/  local _=nil/' ''
mutant F7 4 $SRC/PlantGrowthFx.lua '352s/Arrival.Land(flight.CropId,flight.Index)/local _=nil/' ''
mutant F8 4 $SRC/PlantGrowthFx.lua 's/return def~=nil and not def.Mech and not def.Verity/return def~=nil and not def.Verity/' ''
mutant F9 4 $SRC/PlantGrowthFx.lua 's/ProxyWindow=.5,ProxyMax=2,/ProxyWindow=.5,ProxyMax=0,/' ''
if [ -n "$SURVIVORS" ];then echo "NOT KILLED:$SURVIVORS";exit 1;fi
echo "all mutants killed"
