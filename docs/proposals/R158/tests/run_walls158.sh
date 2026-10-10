#!/bin/sh
# Usage: sh run_walls158.sh [scratch dir] [place.rbxl] [nomutate]   (needs /opt/luau/luau, python3 with numpy / PIL; the owner's place for steps 3 - 8)
# R158 walls (owner approved docs/proposals/R158/design/: a wall dressing per biome, the ground outside the walls with the owner's own models on it, stone caps on the hub wall; then
# "no repetitive design", "remove the streams entirely", "and the lava pool"). What it covers (docs/proposals/R158/design/design.md "Built" has the story and the numbers):
#  0. static   - the six new modules (TrackWallSpecs158, TrackWalls158, OuterTrackAssets158, OuterTrackLoader158, OuterTrackModels158, LavaVolcano158) compile and are in src/MANIFEST.tsv;
#                MapService calls TrackWalls158 and LavaVolcano158 inside pcalls; no model names; Config.lua, the bat files, every other client script and the frozen hashes are untouched
#                (LavaFlow.client.lua is the one client script changed, line 1 - the R152 load guard - as it was); this suite is on line 6 of tools/tests/run_all_suites.sh.
#  1. data     - dump_specs158.luau -> check_walls158.py: parts per biome never above the design's numbers (and the exact numbers locked), every placement rule (reach into the track, the keys'
#                Y 5.25, the gatehouse, the Desert walkway, the pyramid's footprint, the ground outside the walls and off the hub, caps on the wall tops), shadows only on parts 20+ studs
#                long, NO REPEATED DESIGN (no run of equal posts, uneven spacing, varied heights, close cap shades), a second dump byte-identical (fixed seeds).
#  2. outer    - test_outer158.luau: the keys, ids and spots (every box at |x| >= 100 or behind the end wall, off the hub), the owner's pyramid (82 blocks) and dark mountain (280 of 1,532)
#                as data: scaling to the box, yaw / mirror / scale maths, deterministic, the snow hills' data, the ground is the only part-built outer thing.
#  3. worlds   - the owner's place after every REAL start-up pass (MapService.new), built twice: with the R158 passes and WITHOUT (MapService's two R158 lines taken out): the hub and
#                one scene per biome (the keyboard around a runner).
#  4. untouched- check_untouched158.py: everything that is not an R158 part or a lava stream / pool is identical (the R157 pyramid, the keyboard, the keepers, the pack spawn spots, the hub,
#                the bases, the track floor and scenery); the 15 saved walls differ only in colour / material; the removed parts are exactly the lava; the built R158 parts obey the rules.
#  5. zfight   - zfight_anywhere158.py on every built scene (the camera may be anywhere, also outside the walls): 0 flickers for any new part or re-coloured wall. (The whole-map R152
#                sweep, run_zfight_sweep.sh, runs as its own suite.)
#  5b. R154 hub z-fighting (run_hub_zfight154.sh, strict hub mode) on the built code: 0 visible pairs (the base walls stand in the hub).
#  6. test_walls158.luau (the real start-up in the mock): the folders, every part against its spec, the flags, the saved walls, the lava, the outer track, the refresh hide, idempotence,
#                the loader on fake models (hand-placed / id / not authorized / never answers / missing), the snow hills, the volcano on the track and outside; the Forest and Jungle trees as
#                built (every spot, each its Look's model, as tall as its spot says, on the ground, in its box, Forest + Jungle under 900 parts); the code review's fixes (a copy of a game model
#                keeps no tag or attribute, a Folder source is wrapped in a Model, the mesh is asked with the cheap fidelities, the refresh hides what sticks out of the cover's sides, the
#                mesh volcano adds no key to the keyboard's skip, every backdrop Model is Atomic).
#  6b. test_boot158.luau: MapService.new never waits for an asset request (every request hangs / the volcano's mesh arrives late), one shared request, the old cone stays until it arrives.
#  7. LavaFlow - test_lavaflow158.luau: no per-frame step with no routes or pools; wakes and sleeps; fails on the old script (the teeth).
#  8. mutations- each of 27 breaks of the code must make a step above fail.   "nomutate" as the 3rd argument skips this step.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
# BASE = the commit before the walls build (the parent of the commit that added TrackWalls158.lua), found in git, so later builds merged on top
# (bats, popups, bunting, the release Version line) never trip step 0. R158_BASE overrides it.
BASE=${R158_BASE:-}
if [ -z "$BASE" ];then first=$(git -C "$REPO" log --diff-filter=A --format=%H -- src/ServerScriptService/ChestChaseServer/TrackWalls158.lua 2>/dev/null | tail -1)
 [ -n "$first" ] && BASE=$(git -C "$REPO" rev-parse -q --verify "$first^" 2>/dev/null);fi
BASE=${BASE:-e9c0900}
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;T=$REPO/tools/tests;P=$REPO/docs/proposals
RC=0;fail(){ echo "FAIL: $1";RC=1; }
mkdir -p "$OUT"
NEW="TrackWallSpecs158 TrackWalls158 OuterTrackAssets158 OuterTrackLoader158 OuterTrackModels158 LavaVolcano158"
echo "== 0. static"
for m in $NEW MapService;do /opt/luau/luau-compile --binary "$SS/$m.lua" >/dev/null || fail "$m does not compile";done
/opt/luau/luau-compile --binary "$S/StarterPlayer/StarterPlayerScripts/LavaFlow.client.lua" >/dev/null || fail "LavaFlow does not compile"
echo "ok: luau-compile clean (the six new modules, MapService, LavaFlow)"
for m in $NEW;do grep -q "	ServerScriptService/ChestChaseServer/$m	ServerScriptService/ChestChaseServer/$m.lua$" "$S/MANIFEST.tsv" || fail "$m is not in src/MANIFEST.tsv";done
echo "ok: the six new modules are in src/MANIFEST.tsv"
grep -q "pcall(function()require(script.Parent.TrackWalls158).Apply(mapRoot)end)" "$SS/MapService.lua" && grep -q "pcall(function()require(script.Parent.LavaVolcano158).Apply(mapRoot)end)" "$SS/MapService.lua" && echo "ok: MapService builds the walls and the volcano inside pcalls (a failure never stops the server)" || fail "MapService must call TrackWalls158.Apply and LavaVolcano158.Apply inside pcalls"
[ "$(grep -c "LavaVolcano158" "$SS/MapService.lua")" = 1 ] && [ "$(grep -c "TrackWalls158" "$SS/MapService.lua")" = 1 ] || fail "MapService must mention each of TrackWalls158 and LavaVolcano158 on exactly one line"
awk '/TrackWalls158/{a=NR}/LavaVolcano158/{b=NR}/KeyboardSkip152/{c=NR}/HubDecor151/{h=NR}END{if(h<a&&a<b&&b<c)print "ok: order in MapService.new: HubDecor151, then the R158 walls, then the volcano, all before the keyboard skip scan (the keys fill the floor where lava was)";else exit 1}' "$SS/MapService.lua" || fail "the R158 lines are not between HubDecor151 and the keyboard scan"
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|gp[t]-?[0-9]" $(for m in $NEW;do echo "$SS/$m.lua";done) "$HERE"/*.luau "$HERE"/*.py "$P/R158/design/make_models158.py" "$P/R158/design/outer_track_assets.md" "$P/R158/design/design.md" 2>/dev/null;then fail "a model name in the R158 walls files";else echo "ok: no model names in the R158 walls files";fi
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 # Only the walls build's OWN commits are checked (every commit since BASE that touched a walls file): each may change only the walls files, MapService, MANIFEST,
 # LavaFlow (the one client script) and KeyboardSkip152 (the mesh volcano's footprint, review fix 5). Config.lua is pinned by frozen.sha256 below.
 WFILES="src/ServerScriptService/ChestChaseServer/TrackWallSpecs158.lua src/ServerScriptService/ChestChaseServer/TrackWalls158.lua src/ServerScriptService/ChestChaseServer/OuterTrackAssets158.lua src/ServerScriptService/ChestChaseServer/OuterTrackLoader158.lua src/ServerScriptService/ChestChaseServer/OuterTrackModels158.lua src/ServerScriptService/ChestChaseServer/LavaVolcano158.lua"
 ALLOW="src/MANIFEST.tsv|ServerScriptService/ChestChaseServer/MapService.lua|StarterPlayerScripts/LavaFlow.client.lua|TrackWallSpecs158|TrackWalls158|OuterTrack(Assets|Loader|Models)158|LavaVolcano158|ReplicatedStorage/KeyboardSkip152.lua"
 commits=$(git -C "$REPO" rev-list "$BASE"..HEAD -- $WFILES)
 [ -n "$commits" ] || fail "no commit since $BASE touched the walls files"
 for c in $commits;do
  other=$(git -C "$REPO" diff-tree --no-commit-id --name-only -r -m "$c" -- src | sort -u | grep -v -E "$ALLOW" || true)
  [ -z "$other" ] || fail "walls commit $(git -C "$REPO" log -1 --format=%h "$c") changed src files this build should not touch: $(echo $other)"
 done
 echo "ok: the walls build's $(echo $commits | wc -w) commit(s) since $BASE touch only the walls files, MapService, MANIFEST, LavaFlow (the one client script) and KeyboardSkip152"
 [ "$(git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/LavaFlow.client.lua" | head -1)" = "$(head -1 "$S/StarterPlayer/StarterPlayerScripts/LavaFlow.client.lua")" ] && echo "ok: LavaFlow's line 1 (the R152 load guard) is untouched" || fail "LavaFlow's line 1 (the load guard) changed"
else echo "skip: $BASE is not in this checkout (the walls commits' file check not run)";fi
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet - ) && echo "ok: the frozen file hashes (docs/proposals/R151/tests/frozen.sha256) still hold" || fail "a frozen file's hash changed"
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R158/tests/run_walls158.sh .* docs/proposals/R156/tests/run_pyramid156.sh" && echo "ok: run_walls158.sh is on line 6 of tools/tests/run_all_suites.sh, before run_pyramid156.sh" || fail "run_walls158.sh is not registered on line 6 of run_all_suites.sh before run_pyramid156.sh"
sed -n 9p "$T/run_all_suites.sh" | grep -q "R158run_walls158" && echo "ok: ... and its place-file argument is in the case on line 9" || fail "R158run_walls158 is not in the case on line 9 of run_all_suites.sh"
[ $RC = 0 ] || exit 1
echo "== 1. data (the walls, the ground, the caps)"
D=$OUT/data;mkdir -p "$D"
cp "$SS/TrackWallSpecs158.lua" "$HERE/dump_specs158.luau" "$D/"
(cd "$D" && /opt/luau/luau dump_specs158.luau > specs.txt && /opt/luau/luau dump_specs158.luau > specs2.txt)
python3 "$HERE/check_walls158.py" "$D/specs.txt" "$D/specs2.txt" || RC=1
echo "== 2. outer track data (keys, spots, the owner's pyramid and dark mountain as data)"
cp "$SS/OuterTrackAssets158.lua" "$SS/OuterTrackModels158.lua" "$HERE/test_outer158.luau" "$D/"
(cd "$D" && /opt/luau/luau test_outer158.luau > outer.txt 2>&1) && tail -1 "$D/outer.txt" || { grep -E '^FAIL' "$D/outer.txt" | head;tail -3 "$D/outer.txt";RC=1; }
[ $RC = 0 ] || exit 1
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
echo "== 3. the worlds: the map built with and without the R158 passes"
RV=$P/R152/tests/run_variant.sh
variants() { # $1 = world dir
 sh $RV "$1" hub "RUNNER={0,-60};HUB_STATE='champions'" >/dev/null & sh $RV "$1" forest "RUNNER={-30,10};HUB_STATE='empty'" >/dev/null & sh $RV "$1" jungle "RUNNER={-30,330};HUB_STATE='empty'" >/dev/null & wait
 sh $RV "$1" desert "RUNNER={-30,960};HUB_STATE='empty'" >/dev/null & sh $RV "$1" snow "RUNNER={-30,1500};HUB_STATE='empty'" >/dev/null & sh $RV "$1" lava "RUNNER={-30,2400};HUB_STATE='empty'" >/dev/null & wait
 sh $RV "$1" crystal "RUNNER={-30,3600};HUB_STATE='empty'" >/dev/null & sh $RV "$1" storm "RUNNER={-30,5620};HUB_STATE='empty'" >/dev/null & wait
 rm -f "$1"/*.log "$1"/run_*.luau
}
sh "$P/R152/tests/build_sweep_env.sh" "$OUT/built" "$PLACE" "$S" >/dev/null
rm -rf "$OUT/nosrc";mkdir -p "$OUT/nosrc";cp -r "$S/." "$OUT/nosrc/"
grep -v -E "require\(script.Parent.(TrackWalls158|LavaVolcano158)\)" "$SS/MapService.lua" > "$OUT/nosrc/ServerScriptService/ChestChaseServer/MapService.lua"
[ "$(diff "$SS/MapService.lua" "$OUT/nosrc/ServerScriptService/ChestChaseServer/MapService.lua" | grep -c '^<')" = 2 ] || fail "the baseline MapService should lack exactly the two R158 lines"
sh "$P/R152/tests/build_sweep_env.sh" "$OUT/plain" "$PLACE" "$OUT/nosrc" >/dev/null
variants "$OUT/built";variants "$OUT/plain"
for v in hub forest jungle desert snow lava crystal storm;do [ -s "$OUT/built/$v.json" ] && [ -s "$OUT/plain/$v.json" ] || fail "scene $v missing";done
[ $RC = 0 ] || exit 1
echo "ok: 8 scenes built twice ($(grep -o 'ZSCENE.*' "$OUT/built/forest.steps" | head -1))"
echo "== 4. untouched"
python3 "$HERE/check_untouched158.py" "$OUT/plain" "$OUT/built" hub forest jungle desert snow lava crystal storm | grep -v '^placement rules' || RC=1
echo "== 5. z-fighting, the camera anywhere"
for v in hub forest jungle desert snow lava crystal storm;do
 python3 "$HERE/zfight_anywhere158.py" "$OUT/built/$v.json" "$OUT/zany_$v.txt" > "$OUT/zany_$v.log" 2>&1 && echo "$v: $(head -1 "$OUT/zany_$v.log" | cut -c1-170)" || { echo "$v:";cat "$OUT/zany_$v.log";RC=1; }
done
{ for v in hub forest jungle desert snow lava crystal storm;do echo "== $v";cat "$OUT/zany_$v.txt";done; } > "$HERE/../design/zfight_built158.txt" 2>/dev/null || true # (the result for the design folder: the built code, every scene)
echo "== 5b. z-fighting in the hub, strict mode (R154: the base walls stand in the hub; look-alike faces on a textured material count too)"
if sh "$P/R154/tests/run_hub_zfight154.sh" "$OUT/hub154" "$PLACE" > "$OUT/hub154.log" 2>&1;then grep -E "visible hub pairs|strict hub mode" "$OUT/hub154.log";else grep -E "FLICKER|visible hub pairs|strict hub mode" "$OUT/hub154.log" | cut -c1-260;RC=1;fi
echo "== 6. test_walls158 (the real start-up on the owner's place, in the mock)"
W=$OUT/built
cp "$HERE/test_walls158.luau" "$W/"
if (cd "$W" && timeout 900 /opt/luau/luau test_walls158.luau > out158.txt 2> err158.txt);then grep -E '^(FAIL)' "$W/out158.txt" || true;grep -E '^INFO (track wall parts|outer track parts|start-up)' "$W/out158.txt";grep -E 'R158 walls \(mock\):' "$W/out158.txt"
else grep -E '^FAIL' "$W/out158.txt" | head -20;tail -5 "$W/err158.txt";RC=1;fi
echo "== 6b. test_boot158 (MapService.new never waits for an asset request: every request hangs / the volcano's mesh arrives late; one shared request)"
cp "$HERE/test_boot158.luau" "$W/"
for m in hang arrive;do
 (printf "MODE='%s'\n" "$m";cat "$HERE/test_boot158.luau") > "$W/run_boot_$m.luau"
 if (cd "$W" && timeout 900 /opt/luau/luau run_boot_$m.luau > boot_$m.txt 2> boot_$m.err);then grep -E '^FAIL' "$W/boot_$m.txt" || true;grep -E 'R158 boot \(' "$W/boot_$m.txt"
 else grep -E '^FAIL' "$W/boot_$m.txt" | head -20;tail -5 "$W/boot_$m.err";RC=1;fi
done
echo "== 7. LavaFlow (no per-frame step with no streams; the old script must fail)"
L=$OUT/lf;mkdir -p "$L"
cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R149/tests/zfight_world.luau" "$HERE/test_lavaflow158.luau" "$L/"
python3 "$P/R149/tests/mkbundle_any.py" "$S/ReplicatedStorage" "$L/rs_bundle.luau" LavaFlow="$S/StarterPlayer/StarterPlayerScripts/LavaFlow.client.lua" >/dev/null
(cd "$L" && /opt/luau/luau test_lavaflow158.luau > lf.txt 2>&1) && tail -1 "$L/lf.txt" || { grep -E '^FAIL' "$L/lf.txt" | head;RC=1; }
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/LavaFlow.client.lua" > "$L/LavaFlow.old.lua"
 python3 "$P/R149/tests/mkbundle_any.py" "$S/ReplicatedStorage" "$L/rs_bundle.luau" LavaFlow="$L/LavaFlow.old.lua" >/dev/null
 if (cd "$L" && /opt/luau/luau test_lavaflow158.luau > lf_old.txt 2>&1);then fail "the old LavaFlow passed the new test (no teeth)";else echo "killed: the old LavaFlow fails the test ($(grep -c '^FAIL' "$L/lf_old.txt") checks: it steps every frame with nothing to animate)";fi
fi
[ $RC = 0 ] || exit 1
if [ "$MODE" != nomutate ];then
 echo "== 8. mutations (each break must make a step above fail)"
 M=$OUT/mut;rm -rf "$M";mkdir -p "$M"
 mutant() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text -> runs the data check, the outer test and the mock test on a copy with that one change
  n=$1;d=$M/$n;rm -rf "$d";mkdir -p "$d/src";cp -r "$S/." "$d/src/"
  python3 - "$d/src/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
  sh "$P/R152/tests/build_sweep_env.sh" "$d/w" "$PLACE" "$d/src" >/dev/null
  cp "$HERE/test_walls158.luau" "$d/w/"
  killed=
  if ! (cd "$d/w" && timeout 900 /opt/luau/luau test_walls158.luau > o.txt 2> e.txt);then killed="the mock test ($(grep -c '^FAIL' "$d/w/o.txt") failing checks, e.g. $(grep -m1 '^FAIL' "$d/w/o.txt" | cut -c1-80))";fi
  if [ -z "$killed" ];then # the boot test: every asset request hangs / the volcano's mesh arrives late
   for bm in hang arrive;do
    if [ -z "$killed" ];then
     (printf "MODE='%s'\n" "$bm";cat "$HERE/test_boot158.luau") > "$d/w/run_boot_$bm.luau"
     (cd "$d/w" && timeout 900 /opt/luau/luau run_boot_$bm.luau > b.txt 2> be.txt) || killed="the boot test, $bm ($(grep -c '^FAIL' "$d/w/b.txt") failing checks, e.g. $(grep -m1 '^FAIL' "$d/w/b.txt" | cut -c1-80))"
    fi
   done
  fi
  if [ -z "$killed" ];then
   mkdir -p "$d/data";cp "$d/src/ServerScriptService/ChestChaseServer/TrackWallSpecs158.lua" "$d/src/ServerScriptService/ChestChaseServer/OuterTrackAssets158.lua" "$d/src/ServerScriptService/ChestChaseServer/OuterTrackModels158.lua" "$HERE/dump_specs158.luau" "$HERE/test_outer158.luau" "$d/data/"
   (cd "$d/data" && /opt/luau/luau dump_specs158.luau > s1.txt 2>/dev/null && /opt/luau/luau dump_specs158.luau > s2.txt 2>/dev/null) || true
   if ! python3 "$HERE/check_walls158.py" "$d/data/s1.txt" "$d/data/s2.txt" > "$d/data/c.txt" 2>&1;then killed="the data check ($(grep -m1 'RULE' "$d/data/c.txt" | cut -c1-90))";fi
   if [ -z "$killed" ] && ! (cd "$d/data" && /opt/luau/luau test_outer158.luau > t.txt 2>&1);then killed="the outer data test ($(grep -m1 '^FAIL' "$d/data/t.txt" | cut -c1-90))";fi
  fi
  if [ -n "$killed" ];then echo "killed $n: $killed";else fail "MUTATION $n SURVIVED (every step passed)";fi
  rm -rf "$d"
 }
 C=ServerScriptService/ChestChaseServer
 mutant collide "$C/TrackWalls158.lua" "p.Anchored=true;p.CanCollide=false;" "p.Anchored=true;p.CanCollide=true;"
 mutant query "$C/TrackWalls158.lua" "p.CanTouch=false;p.CanQuery=false;" "p.CanTouch=false;p.CanQuery=true;"
 mutant noRestyle "$C/TrackWalls158.lua" " step('Restyled',function()return M.Restyle(map)end)" " made.Restyled=0"
 mutant rebuildDoubles "$C/TrackWalls158.lua" " M.Remove(map)
 local made={}" " local made={}"
 mutant noHide "$C/TrackWalls158.lua" " if ok and signal then M.Connection=signal:Connect(function()setRefreshing(map:GetAttribute('BiomesRefreshing')==true)end)end" " "
 mutant lavaStays "$C/LavaVolcano158.lua" " local res={Removed=M.RemoveLava(map),Replaced=false}" " local res={Removed={Parts=0,Things={}},Replaced=false}"
 mutant randomSeed "$C/TrackWallSpecs158.lua" "local st=(seed*2654435761+12345)%4294967296" "local st=(seed*2654435761+12345+math.floor(os.clock()*1000))%4294967296"
 mutant groundInside "$C/TrackWallSpecs158.lua" "box('Outer ground',s*OUT,s*(OUT+D.Ground.Width)" "box('Outer ground',s*(OUT-30),s*(OUT+D.Ground.Width)"
 mutant keepScripts "$C/OuterTrackLoader158.lua" "  local scripts,other=T.Sanitize(m)
  T.Lock(m)" "  local scripts,other=0,0
  T.Lock(m)"
 mutant bandsOverlap "$C/TrackWallSpecs158.lua" "s0,s1=depth,sec.len-depth end" "s0,s1=depth-SINK,sec.len-(depth-SINK) end"
 mutant towerCapsOnePlane "$C/TrackWallSpecs158.lua" "-(i%2)*.04," "-(i%2)*0,"
 mutant slotInside "$C/OuterTrackAssets158.lua" "{Key='DesertPyramid',X=470," "{Key='DesertPyramid',X=170,"
 # the Forest and Jungle trees
 mutant treeInside "$C/OuterTrackAssets158.lua" "{Key='ForestTree',X=" "{Key='ForestTree',X=-60+0*"
 mutant treeStamp "$C/OuterTrackLoader158.lua" "return tpl.Protos[1+(((slot.Look or index)-1)%n)]" "return tpl.Protos[1]"
 # the code review's fixes
 mutant swapOnBoot "$C/LavaVolcano158.lua" " task.spawn(function()
  local ok,err=pcall(M.Swap,map,old,res,removedText)" " pcall(function()
  local ok,err=pcall(M.Swap,map,old,res,removedText)"
 mutant noSharedRequest "$C/OuterTrackLoader158.lua" " if L.Pending[key]then" " if false then"
 mutant tagsStay "$C/OuterTrackLoader158.lua" "  strip(m);for _,d in ipairs(m:GetDescendants())do strip(d)end
" ""
 mutant folderBare "$C/OuterTrackLoader158.lua" "if not m:IsA('Model')then local w=Instance.new('Model')" "if m:IsA('BasePart')then local w=Instance.new('Model')"
 mutant meshBox "$C/OuterTrackLoader158.lua" "CollisionFidelity=Enum.CollisionFidelity.Box" "CollisionFidelity=Enum.CollisionFidelity.Default"
 mutant notAtomic "$C/OuterTrackLoader158.lua" " m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic" " local _noAtomic=true"
 mutant meshSquare "$C/LavaVolcano158.lua" "   if d:IsA('MeshPart')then d:SetAttribute('KeyboardDisc',math.max(.5,disc))end" "   local _noDisc=true"
 mutant coverSides "$C/TrackWallSpecs158.lua" "(hi[2]>D.CoverTop or reach>D.CoverSide+1e-6)" "(hi[2]>D.CoverTop)"
 mutant icicleFloats "$C/TrackWallSpecs158.lua" "R.r(.1,.25))),50.2,a}" "R.r(.1,.6))),50.2,a}"
 mutant leafNamed "$C/TrackWallSpecs158.lua" " wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')" " wrap('Leaf crown',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')"
 mutant lavaDripsBack "$C/TrackWallSpecs158.lua" " wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')" " wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')
 face('Lava drip',s,z0+10,z0+11,40,49.7,.46,{255,110,36},'Neon',BAY)"
 mutant ballBack "$C/TrackWallSpecs158.lua" " wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')" " wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')
 part('Rock lump','Ball',{5,5,5},cf(s*88,53,z0+20),{58,124,58},'Basalt')"
 mutant eggBack "$C/TrackWallSpecs158.lua" " wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')" " wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')
 part('Rock lump','Block',{6,4,12},cf(s*90,53,z0+20),{58,124,58},'Basalt',{mesh='Sphere'})"
fi
[ $RC = 0 ] || exit 1
echo "== 9. R152 load guard (line 1 of every client script)"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/lg" | tail -2
echo "R158 walls: all checks passed"
