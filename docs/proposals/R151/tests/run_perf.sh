#!/bin/sh
# Usage: sh run_perf.sh [scratch dir] [place.rbxl] [mutate]
# R151 (owner): "for the snow make sure the snow piles are visible throughout ... also do a performance patch on the weather and keyboards, see what
# we can improve in performance while retaining quality and feel" (+ "snow piles can be bigger and more combined", "some of the droplets can have
# impact with the ground, not all"). On the Roblox mock (/opt/luau/luau) with the REAL scripts of this checkout:
#  test_hubsnow.luau - HubSnow151.lua (the hub-wide drift layout: deterministic, all kinds, nothing on the track, all 9 zones, big drifts, banks
#                      fitted beside the bases, no shared plane, clear of the R151 street planes, budgets per tier, LOD bands, the ellipse / box
#                      test) and WeatherWorld149.client.lua on a mock of the owner's hub (the whole hub fills from one spot, LOD, solid after the
#                      fade, nothing on beds / aisles / treadmills / pedestals / market / Verity / displays / R151 streets / tagged props / the
#                      track, heights, holes, a bed streaming in, the fade out, tiers + FastMode budgets, walking writes, standing still costs
#                      nothing, put away down the track, Reduced Motion, teardown).
#                      The rain part: the drops keep their R149 density, a share of them splash (fewer far away / on lower tiers).
#  the owner's place (when the file is there): hub_snow_scene.luau runs the real start-up builders + the R151 festival square + the weather
#                      client for each tier and three spots; every one must cover all 9 zones, put no snow on an avoided part and stay
#                      inside the tier's part budget.
# With "mutate" as the 3rd argument, broken copies of the sources must each make a check fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
mkdir -p "$OUT/cl"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests
bundle() { # $1 = src tree
 sed "s#'/home/user/tmz/src'#'$1'#" "$INV/mkbundle.py" > "$OUT/mkbundle.py"
 C=$1/StarterPlayer/StarterPlayerScripts
 python3 "$OUT/mkbundle.py" "$OUT/cl/rs_bundle.luau" WeatherWorld="$C/WeatherWorld149.client.lua" WorldEvents="$C/WorldEvents.client.lua" \
  KeyboardTrackClient="$C/KeyboardTrack.client.lua" SnowBiome="$C/SnowBiome149.client.lua" >/dev/null
}
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_hubsnow.luau" "$OUT/cl/"
runsuites() {
 rc=0
 for t in ${SUITES:-test_hubsnow}; do
  echo "== $t"
  if (cd "$OUT/cl" && timeout 900 /opt/luau/luau $t.luau > $t.log 2>&1); then grep -E "^(budget|parts drawn|walking|  Rain|  Thunder)" "$OUT/cl/$t.log" || true;tail -1 "$OUT/cl/$t.log"; else grep FAIL "$OUT/cl/$t.log" | head -20;tail -5 "$OUT/cl/$t.log"; rc=1; fi
 done
 return $rc
}
place() { # $1 = src tree; the owner's place: three spots x three tiers
 [ -f "$PLACE" ] || { echo "(no place file at $PLACE: the place checks were skipped)";return 0; }
 mkdir -p "$OUT/place"
 python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place/place_tree.luau" Workspace/ChestChaseMap >/dev/null
 cp "$T/roblox.luau" "$INV/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$OUT/place/"
 python3 "$HERE/bundle_hubsnow.py" "$1" "$OUT/place" >/dev/null
 prc=0
 for t in 3 2 1; do for p in "-118,-186" "44,-316" "230,-560"; do
  printf '%s\n' "PLAYER={$p};SECONDS=30;TIER=$t" > "$OUT/place/run.luau";cat "$HERE/hub_snow_scene.luau" >> "$OUT/place/run.luau"
  (cd "$OUT/place" && timeout 900 /opt/luau/luau run.luau > run.log 2>&1) || { tail -5 "$OUT/place/run.log";return 1; }
  line=$(grep '^STATS' "$OUT/place/run.log")
  python3 - "$line" "$t" <<'PY' || prc=1
import json, sys
s = json.loads(sys.argv[1][6:]); t = int(sys.argv[2])
budget = s['budget']
ok = s['zones'] == 9 and not s['bad'] and s['made'] <= budget and s['coverage'] >= .09 and s['failed'] == 0
print('%s tier %d at %s: %d parts drawn (budget %d), hub covered %.1f%%, %d of 9 zones, avoided parts under snow: %s' % (
    'ok  ' if ok else 'FAIL', t, s['player'], s['discs'], budget, s['coverage'] * 100, s['zones'], s['bad'] or 'none'))
sys.exit(0 if ok else 1)
PY
 done; done
 return $prc
}
if [ "$MODE" != "mutate" ]; then
 bundle "$REPO/src"
 runsuites
 echo "== the owner's place (hub_snow_scene.luau)";place "$REPO/src"
 exit $?
fi
# --- mutation checks: break one thing at a time in a copy of src, the checks must fail ------------------------------------------------
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
 bundle "$M";total=$((total+1))
 if runsuites >"$OUT/mut.log" 2>&1; then echo "MUTATION SURVIVED: $1"; else echo "mutation caught: $1"; caught=$((caught+1)); fi
}
S=StarterPlayer/StarterPlayerScripts/WeatherWorld149.client.lua;H=ReplicatedStorage/HubSnow151.lua;R=ReplicatedStorage/WeatherWorld149.lua
SUITES=test_hubsnow
mutate "snow only in a radius around the player again (no hub-wide layout)" $S " if not(haveFocus and nearHub())then return end" " if not(haveFocus and nearHub())or true then if boundN>0 then for i=boundN,1,-1 do local rec=boundList[i];if(rec.Spec.X-fx)^2+(rec.Spec.Z-fz)^2>130*130 then dropPatch(rec)end end end end
 if not(haveFocus and nearHub())then return end"
mutate "the avoid list is ignored" $S "if not avoided(t,1,1)then v,sc,ox,oz" "if true then v,sc,ox,oz"
mutate "the R151 streets are not avoided" $S "  if kit and kit.Streets then" "  if false then"
mutate "holes are not avoided" $S "    addCircle(pit.Position.X,pit.Position.Z,d*.5+.3)" "    local _=d"
mutate "every drift on one plane (no height slots)" $H "function H.Thickness(s,k)return(base(s,k)+s.Slot)*H.Unit end" "function H.Thickness(s,k)return H.Kinds[s.Kind].Th end"
mutate "drift tops may sit on the street planes" $H "H.KeepGap=.012" "H.KeepGap=0"
mutate "no level of detail (every lobe everywhere)" $H " return min(n,count)" " return count"
mutate "no tier budget (tier 1 as many parts as tier 3)" $H " [1]={Discs=170," " [1]={Discs=340,"
mutate "tier 1 keeps the sprinkle inside the bases" $H "MinPri=2,Bind=4" "MinPri=1,Bind=4"
mutate "the drifts are not released down the track" $S " if boundN>0 and not nearHub(hubCfg.Hyst*2)then clearPatches()end" " local _=0"
mutate "standing still rewrites the snow" $S "  if want~=rec.Lobes and reshape>0 then" "  if reshape>0 then"
mutate "small R149 patches again (no big drifts)" $H " open={Pri=2,Lobes=3,Th=.07,Taper={1,.8,.62},Far=1.2,Cell=38,Chance=.78,R={10,16},Clear=20}," " open={Pri=2,Lobes=3,Th=.07,Taper={1,.8,.62},Far=1.2,Cell=38,Chance=.78,R={4.5,8.5},Clear=20},"
mutate "the snow fades in at once" $R "FadeIn={10,20}" "FadeIn={.05,.1}"
mutate "a bed that streams in does not drop the snow over it (until the 4 s re-read)" $S "   basesWatch=bases.DescendantAdded:Connect(function(d)" "   basesWatch=bases.DescendantAdded:Connect(function(d)do return end"
mutate "every drop splashes the R149 way again (.4 / .3)" $R "W.Splash={Rise=.12,SprayShare=.2,RippleShare=.14," "W.Splash={Rise=.12,SprayShare=.4,RippleShare=.3,"
mutate "the second blizzard shows no snow (R149: a pruned history's old times were read)" $R "(k<ev.N and ev.T[k+1]or now)" "(ev.T[k+1]or now)"
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
