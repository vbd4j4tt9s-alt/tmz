#!/bin/sh
# Usage: sh run_base_area.sh [scratch dir] [place.rbxl] [before commit, default e5211cc = the branch before R151's hub code]
# R151 Seed Festival Square (owner: "i like this design and polish the trees, give them more variety and the stuff and everything"):
#  test_base_area.luau  - the REAL HubDecor151 (run by MapService.new) and HubLife151.client + HubLifeArt151 on the owner's place in the R149
#                         Roblox mock: the saved walls keep CFrame / Size / CanCollide; only the rook towers' shafts collide; every part anchored,
#                         untouchable, unqueryable; clearances against every gameplay object (base plots and pad interiors, the 32-stud
#                         openings, treadmills, mystery pedestals, spawns, the safe line, market, Verity, leaderboards, the track walkway;
#                         shape-exact for balls / upright cylinders); the reserved back corners (R151 displays) empty; gate
#                         clearances; the gate keys' keeper speeds and the per-player green tick;
#                         re-Apply idempotent; part budgets per device tier; detail by distance, FastMode, Reduced Motion, ambience only when
#                         near; lamps on in The Darkened / storms; sound zones; streaming (the server folder goes and comes back), teardown;
#                         with the STAND-IN studded tree models (preview/standin_tree.luau) in ReplicatedStorage.HubTreeTemplates151:
#                         every part locked, clearances, corners, budgets per tier.
#                         R152 (section 16): no fountain / base entrance / mural / banner / signpost / corner tower / hedge / red crest, 24 of 62
#                         trees, the 18-stud plaza circle at (0, -392) clear, the chess-rook battlement (218 evenly spaced merlons, a corner merlon,
#                         nothing else over the wall top, none near tower height) and the rook gate (stepped base, tapering shaft, ring, collar,
#                         flared crown, 8 merlons each; crenellated gatehouse with the sign and the 7 keys).
#  test_hub_trees.luau  - run_hub_trees.sh: the owner's studded tree models (load routes, scripts stripped, collision off, budget, fit).
#  z-fighting           - the R151 scene check (preview/check_base_area_zfight.py, the R149 detector) on the full built hub WITH the client
#                         props, once with the part-built studded trees and once with the stand-in tree models (no counted finding with
#                         an R151 part), and the R149 whole-map suite (run_zfight.sh <dir> <place> 3484f31:
#                         no counted finding of ours).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BEFORE=${3:-e5211cc}
[ -f "$PLACE" ] || { echo "needs the owner's place file: $PLACE";exit 1; }
mkdir -p "$OUT/t" "$OUT/b" "$OUT/scenes" "$OUT/before"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/t/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/test_base_area.luau" "$REPO/docs/proposals/R151/preview/base_area_scene.luau" "$REPO/docs/proposals/R151/preview/standin_tree.luau" "$OUT/t/"
python3 "$REPO/docs/proposals/R151/preview/bundle_r151.py" "$REPO/src" "$OUT/t" >/dev/null
echo "== test_base_area"
(cd "$OUT/t" && timeout 900 /opt/luau/luau test_base_area.luau > "$OUT/test.log" 2>&1) || { grep -E '^(FAIL|ok)|failed|rror' "$OUT/test.log" | tail -30;exit 1; }
grep -E '^(FAIL|BUDGET)' "$OUT/test.log" || true
grep 'R151 base area:' "$OUT/test.log"
echo "== test_hub_trees"
sh "$HERE/run_hub_trees.sh" "$OUT/trees"
echo "== z-fighting: the R151 scene (the whole built hub with the client props; before = $BEFORE)"
rm -rf "$OUT/before/src";git -C "$REPO" archive "$BEFORE" src | tar -x -C "$OUT/before"
cp "$OUT"/t/*.luau "$OUT/b/";python3 "$REPO/docs/proposals/R151/preview/bundle_r151.py" "$OUT/before/src" "$OUT/b" >/dev/null
for which in before after trees;do
 if [ "$which" = before ];then D=$OUT/b;G='REDESIGN=false';elif [ "$which" = after ];then D=$OUT/t;G='BUILT=true';else D=$OUT/t;G='BUILT=true;STANDIN=true';fi
 (printf '%s\n' "$G;OWNERS={\"Ben\",\"Mia\",\"Leo\",\"Zoe\",\"Sam\"};RUNNER={0,-60}";cat "$D/base_area_scene.luau") > "$D/run_scene.luau"
 (cd "$D" && timeout 900 /opt/luau/luau run_scene.luau > "$OUT/scenes/$which.log" 2>&1) || { tail -20 "$OUT/scenes/$which.log";exit 1; }
 if grep -q 'FAILED' "$OUT/scenes/$which.log";then grep FAILED "$OUT/scenes/$which.log";exit 1;fi
 grep '^SCENE ' "$OUT/scenes/$which.log" | sed 's/^SCENE //' > "$OUT/scenes/$which.json"
done
python3 "$REPO/docs/proposals/R151/preview/check_base_area_zfight.py" "$OUT/scenes/before.json" "$OUT/scenes/after.json" > "$OUT/scene_zfight.txt" || { cat "$OUT/scene_zfight.txt";exit 1; }
cat "$OUT/scene_zfight.txt" | grep -v '^   '
echo "   with the stand-in studded tree models:"
python3 "$REPO/docs/proposals/R151/preview/check_base_area_zfight.py" "$OUT/scenes/before.json" "$OUT/scenes/trees.json" > "$OUT/scene_zfight_trees.txt" || { cat "$OUT/scene_zfight_trees.txt";exit 1; }
cat "$OUT/scene_zfight_trees.txt" | grep -v '^   '
echo "== z-fighting: R149 run_zfight.sh (whole map after the real start-up builders, before = 3484f31)"
sh "$REPO/docs/proposals/R149/tests/run_zfight.sh" "$OUT/zf" "$PLACE" 3484f31 > "$OUT/zfight.log" 2>&1 || { grep -E 'STILL|FAIL|left that are ours' "$OUT/zfight.log" | head -20;exit 1; }
grep -E 'passed|z-fighting check|left that are ours' "$OUT/zfight.log" | tail -6
echo "R151 base area suite passed"
