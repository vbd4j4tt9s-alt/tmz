#!/bin/sh
# Usage: sh run_nooks.sh [scratch dir] [place.rbxl]
# R153 hub fixes (owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit and also at some points like the side
# of the garden bed players have to jump to pass it fix this issue"):
#  1. test_hub_gardens.luau - the REAL code (MapService.new -> GardenBaseLayout, HubDecor151 -> HubTrampoline153, HubLifeArt151, HubTrampoline153.client,
#     HubTrampolineRules153) on the owner's place in the R149 Roblox mock:
#       hub:     the three nooks' (the two garden nooks, radius 13, and the back lane's, radius 10) benches and flower beds are gone (the other benches stay), a
#                trampoline FILLS each brick circle (R153 second round, owner: "it should fit the whole circle": the frame's outer edge 0.4 stud inside the disc's
#                rim; ONE collider and a ring of invisible 22 degree wedges that walk a body up the 0.9 kerb, matching frame / mat / springs / feet; the bounce covers
#                the whole circle); the bounce (one config value) lifts the feet 25 - 35 studs; debounce, no stacking, no sky launch; the client script launches the
#                local character, squashes the mat, plays the owner's boing (94320656351627, pitch 1; ONE sound per bounce, none for a debounced contact, none for
#                the old Bubble04; checked on a stubbed and on the real LocalSfx: Effects group, SoundTiming's default lead-in); MovementGuard's rise allowance covers
#                the launch at each nook's own radius (test_guard_trampoline.luau, run_fixes_client.sh); 48 walks onto the three trampolines from every side have no
#                ledge; the lane nook's ring and the neighbouring beds' skirts join in a valley.
#       gardens: (R153 second round: owner: "these garden sides also have not been fixed and players cant walk over them") every raised block - each of the 60
#                soil beds AND the pad - has a continuous 22 degree invisible skirt (a wedge along every exposed face, a fan of wedges at every convex corner),
#                so a body walks from the hub floor over the pad's rim, the 1.0 apron beside the fence and onto the soil with no ledge: every side of every plot
#                every .5 stud, every convex corner diagonally, the pad's rim on its four sides and a line through every fence pillar are walked on all 6 bases
#                (no ledge over 0.2, no slope over 0.85 per stud; without the ramps 99.9% of them fail) and a flood fill over a .25 grid of the real ground from
#                the lawn reaches every cell of every bed and of the pad within 3 studs of one; the bed borders and the fence stay walk-through and unmoved;
#                planting's clear-view rays (6828) cross no ramp; ramps cannot be touched, stay inside the hub, stand off the spawn / treadmill / pedestal.
#  2. static checks - no pathfinding anywhere (keepers / NPCs do not walk the hub), the new client script starts with the R152 load guard, the boing is
#     the owner's trampoline file (94320656351627) at pitch 1 through LocalSfx (R153: it replaced the Bubble04 placeholder), the manifest lists the new files.
#  3. the R152 load guard run and the hub z-fight run (run_hub_zfight.sh: no counted finding, no tight pair, the trampoline parts included).
#  (R153, the look: the hub's trampolines take their look from the owner's asset 12088629887 (scaled so its farthest point lies on the nook's circle; HubTrampoline153: a hand-placed ReplicatedStorage.HubTrampolineTemplates153 model, else
#     InsertService:LoadAsset, else the built one): section 6 of the test mocks the routes: a store model with scripts and junk inside (stripped: scripts, sounds, prompts, welds, humanoids,
#     absurd and invisible parts), its scale / centring / mat height, one collider, the squash on its mat, the same bounce and debounce, "User is not authorized to access Asset" -> the
#     hand-placed template -> the built trampoline, a timeout, too many parts, a single part, a look with no findable mat, the paving-plane nudge, /test trampoline.)
# "mutate" as the 3rd argument also runs broken copies (no ramps; a bounce that stacks; no debounce; a loader that strips nothing) that the test must fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/5ea4542b-sapkeee.rbxl};MODE=$3
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
grep -q "BOING={Id='rbxassetid://94320656351627',Volume=[.0-9]*,Pitch=1}" "$C/HubTrampoline153.client.lua" || fail "the boing must be the owner's file 94320656351627 at pitch 1 (no pitch shift)"
if grep -n "96764044228884\|Bubble04\|InteractionAudio" "$C/HubTrampoline153.client.lua" | grep -v "^[0-9]*:--" ;then fail "the trampoline client still touches the Bubble04 placeholder";fi
[ "$(grep -c "Sfx.Play(BOING.Id," "$C/HubTrampoline153.client.lua")" = 1 ] || fail "the boing must be played in exactly one place (LocalSfx.Play, once per bounce)"
for f in ReplicatedStorage/HubTrampolineRules153 ServerScriptService/ChestChaseServer/HubTrampoline153 StarterPlayer/StarterPlayerScripts/HubTrampoline153;do
 grep -q "	$f	" "$S/MANIFEST.tsv" || fail "$f is not in src/MANIFEST.tsv";done
SS=$S/ServerScriptService/ChestChaseServer
grep -q "T.Step(st,os.clock(),dx,dz,feetY(char,root,hum),v.Y,workspace.Gravity,s.R)" "$C/HubTrampoline153.client.lua" || fail "the client must bounce by each spot's own radius (s.R)"
grep -q "m:GetAttribute('Radius')" "$SS/MovementGuard.lua" || fail "MovementGuard must read each trampoline's own Radius for the launch allowance"
grep -q "Trampoline ramp" "$SS/HubTrampoline153.lua" || fail "the trampoline's ramp ring is gone"
# the look from the owner's asset (R153): the owner command is registered and documented, and the loader never leaves a code path open
grep -q "X.Actions.trampoline=true" "$SS/OwnerUpdateCommands82.lua" && grep -q "action=='trampoline'then return require(script.Parent.HubTrampoline153).Command" "$SS/OwnerUpdateCommands82.lua" || fail "/test trampoline is not registered in OwnerUpdateCommands82"
grep -q "/test trampoline" "$S/ReplicatedStorage/StudioTestHelp.lua" || fail "/test trampoline is not in StudioTestHelp"
for w in '`trampoline`' 'trampoline reload' 'HubTrampolineTemplates153' 'Get Model' 'not authorized';do grep -q "$w" "$REPO/docs/COMMANDS.md" || fail "docs/COMMANDS.md does not mention $w";done
grep -q "12088629887" "$S/ReplicatedStorage/HubTrampolineRules153.lua" || fail "the owner's asset id is not in HubTrampolineRules153"
grep -q "InsertService" "$SS/HubTrampoline153.lua" && grep -q "Trees.Sanitize" "$SS/HubTrampoline153.lua" && grep -q "Trees.Lock" "$SS/HubTrampoline153.lua" || fail "HubTrampoline153 must load with InsertService and sanitise + lock what it loads"
if grep -n "Clone()" "$SS/HubTrampoline153.lua" | grep -v "src:Clone\|prepared.Model:Clone" >/dev/null;then fail "HubTrampoline153 clones something it should not";fi
echo "ok: no pathfinding in the game (keepers and NPCs do not walk the hub or the gardens), the client script starts with the load guard, the boing is the owner's file at pitch 1 played in one place through LocalSfx, the manifest lists the new files, /test trampoline is registered, listed in the help and documented with the not-authorized cure"
[ $RC = 0 ] || exit 1
echo "== R152 load guard"
sh "$REPO/docs/proposals/R152/tests/run_load_guard.sh" "$OUT/lg" | tail -2
echo "== hub z-fight run (trampolines included)"
sh "$REPO/docs/proposals/R152/tests/run_hub_zfight.sh" "$OUT/zf" "$PLACE" > "$OUT/hub_zfight.log" 2>&1 || { tail -30 "$OUT/hub_zfight.log";exit 1; }
grep -E 'AFTER|counted|tight|PASS|FAIL' "$OUT/hub_zfight.log" | head -12
if [ "$MODE" = mutate ];then
 echo "== mutants (each must make the test fail)"
 for m in noramps stack nodebounce nostrip;do
  if run "m_$m" "MUTANT='$m'";then echo "FAIL: mutant $m passed the test";exit 1;else echo "ok: mutant $m fails ($(grep -c '^FAIL' "$OUT/m_$m.log") checks)";fi
 done
fi
echo "R153 hub fixes suite passed"
