#!/bin/sh
# Usage: sh run_growth.sh [scratch dir] [mutate]   (needs /opt/luau/luau, python3 + numpy, git)
# R149 growth style, phase 1 (docs/proposals/R149/growth_style.md #1 - #8; the owner's change to #8: the picked fruit floats into the player) on the Roblox
# mock with the REAL modules of this checkout, proved against the BASE commit (GROWTH_BASE, default 3484f31 = the branch head before the growth change; its
# PlantGrowth is bundled as PlantGrowthBase and its whole src/ as the "before" world of the write benchmark):
#  test_growth.luau        timing / readiness untouched, the curves (size table, swell, colour path, MeshPart tint), and the END STATE: every plant, 3 coats and
#                          every regrowing fruit is byte for byte what the base leaves after Visuals.EndGrowth;
#  test_growth_writes.luau Lantern Fern / Amethyst Grape identical to the base at every step the new module writes (and nothing written between), the write
#                          counts before / after for every plant (#1), no write / no allocation when nothing moved, a regrowing fruit costs its own parts;
#  test_growth_look.luau   #3 sprout pop, #5 solid leaves, #6 fruit colours / swell / material at the ripe moment, #2 Place, the registry; prints the scenes of
#                          every plant at 25 / 50 / 75 % (base and new) for the floating check below;
#  test_growth_fx.luau     #7 ripe bounce + glints and #8 harvest flight: budgets per tier, limits, cleanup, no leaks, no connection per fruit;
#  test_growth_client.luau the real GardenVisuals: sway budget, sprout with the dirt pile, bounce on maturing, flights to the harvester (own / other garden),
#                          reduced motion, stream-out cleanup;
#  test_growth_hotbar.luau the real Hotbar: a harvested item is held out of the inventory view until the fruit arrives, then its slot flashes; (review part 2)
#                          an older fruit of the same plant and slot keeps its slot and the selected label through a flight, the flash lands on the new item;
#  test_growth_unripe.luau (review part 2, #7) the baked Ember Pumpkin grows pale green: its neutral twin while unripe, the baked body from the ripe moment, the
#                          final ripe look identical (with the server bake on the mock);
#  floating parts          the R134 check_floating.py over the plants at 25 / 50 / 75 %: no part floats that did not float in the base's drawing;
#  write benchmark         bench_garden.luau on the base src and on this checkout: the property writes a second of one growing plant under the real scheduler;
#  capture benchmark       bench_capture.luau (review part 2, #5 leaf link): PlantGrowth.Capture of every plant, near detail (leaf attachment pass, yielding through the
#                          build job's budget) and as a server silhouette / distant garden (no pass).
# With "mutate" the suites run against deliberately broken copies of the sources: every mutation must make its test fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${GROWTH_BASE:-3484f31}
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;FL=$REPO/docs/proposals/seeds_R133/preview/check_floating.py
SP=StarterPlayer/StarterPlayerScripts
git -C "$REPO" show "$BASE:src/ReplicatedStorage/PlantGrowth.lua" > "$OUT/PlantGrowthBase.lua"
# bundle <src tree> <world dir>: every ReplicatedStorage module of that tree + the base PlantGrowth + the client scripts the tests load
bundle() {
 mkdir -p "$2"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/growth_common.luau" "$HERE/fruit_mesh_mock.luau" "$HERE"/test_growth*.luau "$HERE/bench_garden.luau" "$HERE/bench_capture.luau" "$2/"
 python3 "$HERE/mkbundle_any.py" "$1/ReplicatedStorage" "$2/rs_bundle.luau" PlantGrowthBase="$OUT/PlantGrowthBase.lua" \
  GardenVisuals="$1/$SP/GardenVisuals.client.lua" Hotbar="$1/$SP/Hotbar.client.lua" >/dev/null
}
TESTS="test_growth test_growth_writes test_growth_look test_growth_fx test_growth_client test_growth_hotbar test_growth_unripe"
runall() { # $1 = world dir, $2... = tests; prints the last line of each; non-zero when one fails
 d=$1;shift;rc=0
 for t in "$@"; do
  echo "== $t"
  if (cd "$d" && timeout 1800 /opt/luau/luau $t.luau > $t.log 2>&1); then grep -v '^WARN\|^SCENE\|^WRITES\|^FROZEN\|^SEMI' "$d/$t.log" | tail -1; else grep -v '^WARN\|^SCENE' "$d/$t.log" | cut -c1-240 | tail -25; rc=1; fi
 done
 return $rc
}
if [ "$MODE" != "mutate" ]; then
 bundle "$REPO/src" "$OUT/new"
 runall "$OUT/new" $TESTS
 grep '^WRITES\|^FROZEN\|^SEMI' "$OUT/new/test_growth_writes.luau.log" "$OUT/new/test_growth_look.luau.log" 2>/dev/null | sed 's#^[^:]*:##' || true
 for t in test_growth_writes test_growth_look; do grep '^WRITES\|^FROZEN\|^SEMI' "$OUT/new/$t.log" || true; done
 echo "== floating parts (R134 check_floating.py) at 25 / 50 / 75 % of the growth"
 grep '^SCENE_GROWTH_NEW ' "$OUT/new/test_growth_look.log" | sed 's/^SCENE_GROWTH_NEW //' > "$OUT/growth_new.json"
 grep '^SCENE_GROWTH_BASE ' "$OUT/new/test_growth_look.log" | sed 's/^SCENE_GROWTH_BASE //' > "$OUT/growth_base.json"
 python3 "$HERE/check_scenes.py" "$FL" plants "$OUT/growth_new.json" "$OUT/growth_base.json"
 echo "== write benchmark: one growing plant under the real GardenVisuals, 5 s at 60 fps (writes = property writes a second, moves = batched CFrames a second)"
 mkdir -p "$OUT/srcbase" "$OUT/basew";git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/srcbase"
 bundle "$OUT/srcbase/src" "$OUT/basew"
 (cd "$OUT/basew" && timeout 1800 /opt/luau/luau bench_garden.luau 2>&1 | grep '^BENCH' > bench.txt)
 (cd "$OUT/new" && timeout 1800 /opt/luau/luau bench_garden.luau 2>&1 | grep '^BENCH' > bench.txt)
 python3 - "$OUT/basew/bench.txt" "$OUT/new/bench.txt" <<'PY'
import sys
def read(p):
    out = {}
    for l in open(p):
        f = l.split(); d = dict(x.split('=') for x in f[3:]); out[(f[1], f[2])] = {k: float(v) for k, v in d.items()}
    return out
b, n = read(sys.argv[1]), read(sys.argv[2])
print('%-18s %5s %6s | %10s %10s | %10s %10s | %s' % ('plant', 'parts', 'secs', 'before w/s', 'before mv', 'still w/s', 'still mv', 'sway: w/s + mv/s  (x fewer than before in all)'))
for (pid, mode), v in b.items():
    if mode != 'still': continue
    s, w = n[(pid, 'still')], n[(pid, 'sway')]
    tot_b = v['total']; tot_s = s['total']; tot_w = w['total']
    print('%-18s %5d %6d | %10.0f %10.0f | %10.0f %10.0f | %7.0f + %6.0f = %7.0f  (x%.1f; no sway x%.0f)' % (pid, v['parts'], v['seconds'], v['writes'], v['moves'], s['writes'], s['moves'], w['writes'], w['moves'], tot_w, tot_b / max(1, tot_w), tot_b / max(1, tot_s)))
PY
 echo "== capture benchmark: PlantGrowth.Capture of every plant on the mock (ms of CPU; near = leaf attachment pass, silhouette = server / distant garden)"
 (cd "$OUT/new" && timeout 1800 /opt/luau/luau bench_capture.luau 2>&1 | grep '^CAPTURE' > capture.txt)
 grep 'FrostFernSeed\|MonsteraSeed\|DesertAloeSeed\|^CAPTURE_TOTAL' "$OUT/new/capture.txt"
 exit 0
fi
# --- mutation checks: break one thing at a time in a copy of src; the named test must fail ----------------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = text to replace (first occurrence), $4 = new text, $5.. = tests that must fail
 name=$1;file=$2;old=$3;new=$4;shift 4
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$file" "$old" "$new" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding='utf-8').read()
assert s.count(old) >= 1, 'mutation target not found: ' + old
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
 bundle "$M" "$OUT/mut"
 total=$((total+1))
 if runall "$OUT/mut" "$@" > "$OUT/mut.log" 2>&1; then echo "MUTATION SURVIVED: $name"; else echo "mutation caught: $name"; caught=$((caught+1)); fi
}
P=ReplicatedStorage/PlantGrowth.lua;F=ReplicatedStorage/PlantGrowthFx.lua;G=$SP/GardenVisuals.client.lua;H=$SP/Hotbar.client.lua
mutate "Lantern Fern drawn in the new look" $P "G.Frozen={LanternFernSeed=true,AmethystSeed=true}" "G.Frozen={AmethystSeed=true}" test_growth_writes
mutate "the ripe end is not today's colour" $P "if k>=1 then return r.Ripe end" "if k>=1 then return r.Color end" test_growth
mutate "the plump never settles (ripe size 1.05)" $P "if f>from and f<1 then base+=T.SwellPeak*math.sin(math.pi*(f-from)/(1-from))end" "if f>from then base+=T.SwellPeak*math.sin(math.pi*.5*(f-from)/(1-from))end" test_growth
mutate "every refresh rewrites (no 1/600 gate)" $P "Steps=600," "Steps=1e12," test_growth_writes
mutate "leaves fade in again (ghost leaves)" $P "elseif r.Foliage and body<1 then
    -- #5" "elseif false then
    -- #5" test_growth_look
mutate "the sprout ignores the pile's beat" $P "return crop.SproutAt or planted+T.SproutAt" "return planted+T.SproutAt" test_growth_look
mutate "the real material switches on early" $P "if not ripe then material=Enum.Material.SmoothPlastic end" "if f<.82 then material=Enum.Material.SmoothPlastic end" test_growth_look
mutate "the final write keeps the sway pose" $P "if final and state.Pose then" "if false and state.Pose then" test_growth_look
mutate "the sway budget is not respected" $G "windModels<6 and windParts+entry.Cost<=600 then
     windParts+=entry.Cost;windModels+=1
     if r.MotionDue then
      r.Pose=r.Origin*Growth.Sway(seed" "true then
     windParts+=entry.Cost;windModels+=1
     if r.MotionDue then
      r.Pose=r.Origin*Growth.Sway(seed" test_growth_client
mutate "reduced motion does not stop the growing sway" $G "if not reducedNow and r.Mode=='normal'and not r.FruitOnly and Growth.Sways" "if r.Mode=='normal'and not r.FruitOnly and Growth.Sways" test_growth_client
mutate "no limit on ripe cues" $F "CueGap=.18,CueWindow=2,CueMax=6," "CueGap=0,CueWindow=2,CueMax=600," test_growth_fx
mutate "no cap on flying fruit" $F "{Pulses=4,PulseParts=120,Sparks=4,Flights=8,FlightParts=200,Range=48}" "{Pulses=4,PulseParts=120,Sparks=4,Flights=80,FlightParts=2000,Range=48}" test_growth_fx
mutate "reduced motion does not stop the effects" $F "if reduced or off then return M.Off end" "if false then return M.Off end" test_growth_fx test_growth_client
mutate "a refused flight leaves the inventory held" $F "local function refuse()Arrival.Land(cropId,index);return false end" "local function refuse()return false end" test_growth_fx
mutate "the flight ignores a harvester that died" $F "if not f.Model.Parent or not root.Parent or f.Humanoid.Health<=0 then" "if not f.Model.Parent or not root.Parent then" test_growth_fx test_growth_client
mutate "the fruit does not shrink on the way" $F "1-(1-M.Tuning.ShrinkTo)*smooth(u)" "1" test_growth_fx
mutate "the inventory shows the item before the fruit arrives" $H "if tool:IsA('Tool')and(seen[tool]or not Arrival.Holds(tool))then" "if tool:IsA('Tool')then" test_growth_hotbar
mutate "a hold hides older fruit of the same plant and slot (they lose their hotbar slots)" $H "if tool:IsA('Tool')and(seen[tool]or not Arrival.Holds(tool))then" "if tool:IsA('Tool')and not Arrival.Holds(tool)then" test_growth_hotbar
mutate "the arrival flash lands on any tool of that plant and slot" $H "local arrival=isNew and released[Arrival.ToolKey(tool)or'']" "local arrival=released[Arrival.ToolKey(tool)or'']" test_growth_hotbar
mutate "no flash when the item arrives" $H "flashOf(b).BackgroundTransparency=.3;flashes[b]=os.clock()" "flashes[b]=nil" test_growth_hotbar
# review part 2
V=ReplicatedStorage/PlantVisuals.lua;D=ReplicatedStorage/DistantPlantView.lua;FM=ReplicatedStorage/FruitMeshes149.lua;AF=ReplicatedStorage/ApprovedFruitEffects.lua
mutate "the server's silhouettes run the leaf attachment pass" $V "origin,PLAIN);Visuals.UpdateGrowth(parent,crop,now)
end
function Visuals.GrowingFruitSupports" "origin);Visuals.UpdateGrowth(parent,crop,now)
end
function Visuals.GrowingFruitSupports" test_growth_look
mutate "a distant garden runs the leaf attachment pass" $D "crop.SeedId,crop,origin,PLAIN)" "crop.SeedId,crop,origin)" test_growth_look
mutate "the near-detail build never yields in the leaf attachment pass" $P "if work and tests%LINK_YIELD==0 then work.BeforePart(1)end" "if false then work.BeforePart(1)end" test_growth_look
mutate "BuildGrowing does not hand its work budget down" $V "origin,work and{Work=work}or nil)" "origin,nil)" test_growth_look
mutate "the pumpkin grows tinted again (no neutral twin)" $FM "Tone={232,108,28},GlossOut=1.1,UnripeNeutral=true}" "Tone={232,108,28},GlossOut=1.1}" test_growth_unripe
mutate "the baked pumpkin body shows while it is unripe" $P "elseif r.Held and not ripe then tr=1 end" "elseif false then tr=1 end" test_growth_unripe
mutate "the twin stays visible at the ripe moment" $P "if r.Twin then if ripe then tr=1 end" "if r.Twin then if false then tr=1 end" test_growth_unripe
mutate "EndGrowth leaves the twins in the plant" $V " if state.Twins then for _,p in ipairs(state.Twins)do p:Destroy()end end" " local _=state.Twins" test_growth_unripe
mutate "a coated plant gets twins too" $P " if crop.Mutation~=nil and crop.Mutation~='None'then return end" " local _=crop" test_growth_unripe
mutate "a flying Emberfruit snaps back to its plain look when the effect ends" $AF "if part.Parent and part:IsDescendantOf(model)then" "if part.Parent then" test_growth_fx
mutate "a failed animation step leaves Growth.Batch set" $G " Growth.Batch=nil -- (also when the pass failed: another script's UpdateGrowth in this frame must not queue into the garden's batch, review part 2)
 if not passOk then error(passWhy,0)end" " if not passOk then error(passWhy,0)end
 Growth.Batch=nil" test_growth_client
A=ReplicatedStorage/HarvestArrival.lua
mutate "an unreleased inventory hold never ends" $A "if left>.01 then watch(k,entry,left)else release(k,true)end" "if left>.01 then watch(k,entry,left)end" test_growth_fx test_growth_hotbar
mutate "a flight does not extend the inventory hold" $A "entry.Flying=true;entry.Due=os.clock()+seconds+A.Tuning.Margin" "entry.Flying=true" test_growth_fx
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
