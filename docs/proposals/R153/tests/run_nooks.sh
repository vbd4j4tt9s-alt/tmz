#!/bin/sh
# Usage: sh run_nooks.sh [scratch dir] [place.rbxl]
# R153 hub fixes (owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit and also at some points like the side
# of the garden bed players have to jump to pass it fix this issue"):
#  1. test_hub_gardens.luau - the REAL code (MapService.new -> GardenBaseLayout, HubDecor151 -> HubTrampoline153, HubLifeArt151, HubTrampoline153.client,
#     HubTrampolineRules153) on the owner's place in the R149 Roblox mock:
#       hub:     the garden nooks' benches and flower beds are gone (the other benches stay), a trampoline (ONE collider, matching frame / mat / springs / feet,
#                0.9 over the floor: under the runner's step limit) stands in each nook clear of the paths and the wall; the bounce (one config value) lifts
#                the feet 25 - 35 studs; debounce, no stacking, no sky launch; the client script launches the local character, squashes the mat, plays an
#                existing sound; MovementGuard's rise allowance covers the launch.
#       gardens: the step heights ground -> pad -> border -> soil are measured against the runner's step limit (RunnerSweep.Hull); every exposed soil face of
#                every bed of the 6 bases gets an invisible ramp (the bed borders stay walk-through) so no climb on any edge - fronts, sides, corners, the
#                rear bed's three outer faces - exceeds the limit; the soil, the plots and their plants are untouched; ramps cannot be queried or touched
#                and stay inside the hub (the keepers' track is not affected).
#  2. static checks - no pathfinding anywhere (keepers / NPCs do not walk the hub), the new client script starts with the R152 load guard, the boing is an
#     existing asset, the manifest lists the new files.
#  3. the R152 load guard run and the hub z-fight run (run_hub_zfight.sh: no counted finding, no tight pair, the trampoline parts included).
# "mutate" as the 3rd argument also runs broken copies (no ramps; a bounce that stacks; no debounce) that the test must fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$OUT/t"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/test_hub_gardens.luau" "$OUT/t/"
python3 "$REPO/docs/proposals/R149/tests/zfight_bundle.py" "$REPO/src" "$OUT/t" >/dev/null
python3 - "$OUT/t" "$REPO/src/StarterPlayer/StarterPlayerScripts/HubTrampoline153.client.lua" "$REPO/src/StarterPlayer/StarterPlayerScripts/HubLife151.client.lua" <<'EOF'
import sys
out,*files=sys.argv[1:]
text=open(out+'/rs_bundle.luau',encoding='utf-8').read().rstrip();assert text.endswith('}')
extra=[]
for name,path in (('HubTrampoline153Client',files[0]),):
    s=open(path,encoding='utf-8').read();lvl=1
    while (']'+'='*lvl+']') in s:lvl+=1
    extra.append('["%s"]=[%s[\n%s]%s],'%(name,'='*lvl,s,'='*lvl))
open(out+'/rs_bundle.luau','w',encoding='utf-8').write(text[:-1]+'\n'.join(extra)+'\n}')
EOF
run() { # $1 = name, $2 = globals
 (printf '%s\n' "$2";cat "$OUT/t/test_hub_gardens.luau") > "$OUT/t/run_$1.luau"
 (cd "$OUT/t" && timeout 900 /opt/luau/luau "run_$1.luau" > "$OUT/$1.log" 2>&1) && return 0 || return 1
}
echo "== test_hub_gardens (the real code on the owner's place in the mock)"
if run main "MUTANT=nil";then grep -E '^(FAIL|INFO)' "$OUT/main.log" || true;grep -E 'R153 hub fixes:' "$OUT/main.log"
else grep -E '^FAIL|rror' "$OUT/main.log" | head -30;exit 1;fi
echo "== static checks"
S=$REPO/src;C=$S/StarterPlayer/StarterPlayerScripts;RC=0;fail(){ echo "FAIL: $1";RC=1; }
GUARD='R152: start once the whole game has arrived'
head -1 "$C/HubTrampoline153.client.lua" | grep -q "$GUARD" || fail "HubTrampoline153.client: line 1 is not the load guard"
[ "$(grep -c "$GUARD" "$C/HubTrampoline153.client.lua")" = 1 ] || fail "HubTrampoline153.client: the guard must appear exactly once"
if grep -rn "PathfindingService\|CreatePath\|ComputeAsync" "$S" --include=*.lua >/dev/null;then fail "something paths through the world: the ramps / trampolines were only checked against walking players";fi
grep -q "96764044228884" "$S/ReplicatedStorage/InteractionAudio.lua" || fail "the boing id is not InteractionAudio's Bubble04 any more"
grep -q "BOING={Id='rbxassetid://96764044228884'" "$C/HubTrampoline153.client.lua" || fail "the boing must be the existing Bubble04 asset"
for f in ReplicatedStorage/HubTrampolineRules153 ServerScriptService/ChestChaseServer/HubTrampoline153 StarterPlayer/StarterPlayerScripts/HubTrampoline153;do
 grep -q "	$f	" "$S/MANIFEST.tsv" || fail "$f is not in src/MANIFEST.tsv";done
echo "ok: no pathfinding in the game (keepers and NPCs do not walk the hub or the gardens), the client script starts with the load guard, the boing is an existing asset, the manifest lists the new files"
[ $RC = 0 ] || exit 1
echo "== R152 load guard"
sh "$REPO/docs/proposals/R152/tests/run_load_guard.sh" "$OUT/lg" | tail -2
echo "== hub z-fight run (trampolines included)"
sh "$REPO/docs/proposals/R152/tests/run_hub_zfight.sh" "$OUT/zf" "$PLACE" > "$OUT/hub_zfight.log" 2>&1 || { tail -30 "$OUT/hub_zfight.log";exit 1; }
grep -E 'AFTER|counted|tight|PASS|FAIL' "$OUT/hub_zfight.log" | head -12
if [ "$MODE" = mutate ];then
 echo "== mutants (each must make the test fail)"
 for m in noramps stack nodebounce;do
  if run "m_$m" "MUTANT='$m'";then echo "FAIL: mutant $m passed the test";exit 1;else echo "ok: mutant $m fails ($(grep -c '^FAIL' "$OUT/m_$m.log") checks)";fi
 done
fi
echo "R153 hub fixes suite passed"
