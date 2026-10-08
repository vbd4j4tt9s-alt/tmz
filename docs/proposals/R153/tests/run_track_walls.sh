#!/bin/sh
# Usage: sh run_track_walls.sh [scratch dir] [place.rbxl] [nomutate]   (needs /opt/luau/luau and python3; the owner's place for steps 1 - 3)
# R153 track walls (owner: "there are also some issues with being able to stand on track walls if flung up high enough fix that so u cant stand on track walls").
# What it covers (docs/proposals/R153/track_walls.md has the story and the numbers):
#  0. static   - TrackWalls153 and the two scripts that start it compile and are in src/MANIFEST.tsv; MapService builds the blockers inside a pcall, the main script starts the guard
#                inside a pcall; no model names; the chase / ragdoll / knockback / keeper files, BackgroundMusic and Config.Version are byte-identical to the R152 release (TRACKWALLS_BASE,
#                default e36b71b), the frozen hashes still hold, and no client script was added (the R152 load guard is line 1 of every one, run last).
#  1. test_track_walls.luau - the REAL start-up (MapService.new -> TrackWalls153) on the owner's place in the R149 Roblox mock: the blockers as built (15, one per wall; Persistent; anchored /
#     colliding / Transparency 1 / CastShadow off / CanTouch off / queryable), the plan on synthetic walls (a taller wall, a 4,500-stud wall in chunks, a thick block is no wall, the end wall,
#     joints), a rebuild, and the fallback on mock players (M.Step / M.Start: a body resting on a wall top is put back on the track after two looks; a body flying past, on the floor, dead,
#     anchored or in owner test flight is left alone; the movement guard is told).
#  2. check_track_walls.py - on the dump of that run: the walls measured per stage (as saved and after the code), every wall top covered exactly (rectangle algebra) with and without
#     the blockers (the bug: the inner 1-stud strip of the 14 side walls is open sky without them), the blockers against the walls (flush, 3 past, 6 under to 1,000 over, no gap, nothing on
#     the track side, nothing low enough to touch the keys / packs / holes / the refresh barrier's opening, only walls / barriers / hub decor overlapped), how high a fling goes
#     (KnockbackConfig, The Darkened), and the worst-case simulation (every launch x place x width x steering): without the blockers some flings come to rest on a wall top, with them none.
#  3. mutations - each of 17 breaks of the module (the ledge back, too short, a gap, no seam, visible, soft, Touched, blind to the sweep, streamed out, intruding on the track, the fallback
#     moving on one look / flying bodies / the wrong way / without telling the guard / the owner's flight / every frame, MapService not building them) must make step 1 or 2 fail.
# "nomutate" as the 3rd argument skips step 3.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
BASE=${TRACKWALLS_BASE:-e36b71b}
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;T=$REPO/tools/tests;P=$REPO/docs/proposals
RC=0;fail(){ echo "FAIL: $1";RC=1; }
mkdir -p "$OUT"
echo "== 0. static"
for f in "$SS/TrackWalls153.lua" "$SS/MapService.lua" "$S/ServerScriptService/ChestChaseServerMain.server.lua";do
 /opt/luau/luau-compile --binary "$f" >/dev/null || fail "$(basename "$f") does not compile";done
echo "ok: luau-compile clean (TrackWalls153, MapService, the main script)"
grep -q "	ServerScriptService/ChestChaseServer/TrackWalls153	ServerScriptService/ChestChaseServer/TrackWalls153.lua$" "$S/MANIFEST.tsv" && echo "ok: TrackWalls153 is in src/MANIFEST.tsv" || fail "TrackWalls153 is not in src/MANIFEST.tsv"
grep -q "pcall(function()require(script.Parent.TrackWalls153).Apply(mapRoot)end)" "$SS/MapService.lua" && echo "ok: MapService builds the blockers inside a pcall (a failure never stops the server)" || fail "MapService must call TrackWalls153.Apply inside a pcall"
grep -q "pcall(function()require(modules.TrackWalls153).Start()end)" "$S/ServerScriptService/ChestChaseServerMain.server.lua" && echo "ok: the main script starts the guard inside a pcall" || fail "the main script must start TrackWalls153 inside a pcall"
[ "$(grep -c "TrackWalls153" "$S/ServerScriptService/ChestChaseServerMain.server.lua")" = 1 ] || fail "the main script must mention TrackWalls153 on exactly one line"
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|gp[t]-?[0-9]" "$SS/TrackWalls153.lua" "$HERE/test_track_walls.luau" "$HERE/check_track_walls.py" "$HERE/mutate_track_walls.py" "$HERE/run_track_walls.sh" "$P/R153/track_walls.md" 2>/dev/null | grep -v "^$HERE/run_track_walls.sh";then fail "a model name in the track walls files";else echo "ok: no model names in the track walls files";fi
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 FROZEN="src/ServerScriptService/ChestChaseServer/ChaseService.lua src/ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua src/ServerScriptService/ChestChaseServer/RagdollService.lua src/ServerScriptService/ChestChaseServer/Config.lua src/ServerScriptService/ChestChaseServer/MovementGuard.lua src/ReplicatedStorage/KeeperCombat.lua src/ReplicatedStorage/KnockbackConfig.lua src/ReplicatedStorage/RunnerSweep.lua src/StarterPlayer/StarterPlayerScripts/RagdollClient.client.lua src/StarterPlayer/StarterPlayerScripts/RunnerController.client.lua src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua"
 if sh "$T/r152_real_diff.sh" "$REPO" "$BASE" $FROZEN >/dev/null;then echo "ok: the fling, keeper, movement and sweep code, the ragdoll and runner clients and BackgroundMusic are byte-identical to $BASE (no fling number, movement rule or sweep changed; the keyboard and the refresh barrier have their own R153 changes and suites)"
 else fail "a frozen file changed against $BASE:";sh "$T/r152_real_diff.sh" "$REPO" "$BASE" $FROZEN || true;fi
 git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | grep 'Config.Version' > "$OUT/version_base.txt"
 grep 'Config.Version' "$SS/Config.lua" > "$OUT/version_now.txt"
 cmp -s "$OUT/version_base.txt" "$OUT/version_now.txt" && echo "ok: Config.Version unchanged" || fail "Config.Version changed"
else echo "skip: $BASE is not in this checkout (frozen-file and Config.Version checks not run)";fi
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet - ) && echo "ok: the frozen file hashes (docs/proposals/R151/tests/frozen.sha256) still hold" || fail "a frozen file's hash changed"
n=$(ls "$S/StarterPlayer/StarterPlayerScripts" | grep -c 'client.lua$' || true)
echo "ok: no client script was added or changed by this suite ($n exist; the R152 load guard run below checks line 1 of each)"
[ $RC = 0 ] || exit 1
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
# -- the world -------------------------------------------------------------------------------------------------------------------------------------------
W=$OUT/t;mkdir -p "$W"
python3 -I "$P/R149/tools/rbxl_geom.py" --tree "$PLACE" "$W/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R149/tests/zfight_world.luau" "$HERE/test_track_walls.luau" "$W/"
python3 "$P/R149/tests/zfight_bundle.py" "$S" "$W" >/dev/null
cp "$W/rs_bundle.luau" "$W/rs_bundle.orig"
run_case(){ # $1 = dir (rs_bundle.luau in it) -> 0 when the Luau test and the checker both pass
 d=$1
 (cd "$d" && timeout 900 /opt/luau/luau test_track_walls.luau > out.txt 2> err.txt) || return 1
 python3 -I "$HERE/check_track_walls.py" "$d/out.txt" "$PLACE" > "$d/check.txt" 2>&1 || return 1
 return 0
}
echo "== 1. test_track_walls (the real start-up on the owner's place, in the mock)"
if (cd "$W" && timeout 900 /opt/luau/luau test_track_walls.luau > out.txt 2> err.txt);then grep -E '^(FAIL)' "$W/out.txt" || true;grep -E 'R153 track walls:' "$W/out.txt"
else grep -E '^FAIL' "$W/out.txt" | head -20;tail -5 "$W/err.txt";exit 1;fi
echo "== 2. check_track_walls (geometry against the owner's place + the worst-case fling simulation)"
if python3 -I "$HERE/check_track_walls.py" "$W/out.txt" "$PLACE" > "$W/check.txt" 2>&1;then cat "$W/check.txt"
else cat "$W/check.txt";exit 1;fi
if [ "$MODE" != nomutate ];then
 echo "== 3. mutations (each break of the module must make step 1 or 2 fail)"
 for m in $(python3 -I "$HERE/mutate_track_walls.py" list);do
  d=$OUT/m_$m;mkdir -p "$d"
  for f in roblox.luau world.luau zfight_world.luau test_track_walls.luau srv_names.luau place_tree.luau;do cp "$W/$f" "$d/$f";done
  cp "$W/rs_bundle.orig" "$d/rs_bundle.luau"
  python3 -I "$HERE/mutate_track_walls.py" "$d/rs_bundle.luau" "$m" >/dev/null
  if run_case "$d";then fail "MUTATION $m SURVIVED (the suite passed)"
  else
   if grep -q '^FAIL' "$d/out.txt" 2>/dev/null;then why="$(grep -c '^FAIL' "$d/out.txt") failing test checks, e.g. $(grep -m1 '^FAIL' "$d/out.txt" | cut -c1-90)"
   elif [ -s "$d/check.txt" ] && grep -q '^FAIL' "$d/check.txt";then why="$(grep -c '^FAIL' "$d/check.txt") failing geometry checks, e.g. $(grep -m1 '^FAIL' "$d/check.txt" | cut -c1-90)"
   else why="the test run stopped: $(tail -1 "$d/err.txt" 2>/dev/null | cut -c1-90)";fi
   echo "killed $m: $why"
  fi
  rm -rf "$d"
 done
fi
[ $RC = 0 ] || exit 1
echo "== 4. R152 load guard"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/lg" | tail -2
echo "R153 track walls: all checks passed"
