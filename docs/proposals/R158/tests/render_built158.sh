#!/bin/sh
# Usage: sh render_built158.sh <scratch dir> [node_modules dir with three@0.169] [the owner's reference video]
# R158 bats, BUILT: docs/proposals/R158/bats/swing_preview.png drawn again with the BUILT swing (src/ReplicatedStorage/BatSwingPose.lua + BatConfig.lua)
# in the rows the preview called "proposed" (now "BUILT"); "today" is the approved checkout's swing from git (BATS_BASE, default e9c0900). Same pipeline
# as docs/proposals/R158/bats/preview/run_swing_preview158.sh (the poses sampled on an exact CFrame, three.js in headless Chromium, the reference
# frames from the owner's video); the labels are changed on copies of its scripts. APPROXIMATE renders (a blocky rig, the fallback bat, no Roblox
# lighting; the legs stand still here, in the game they keep running). Not part of run_all_suites (it needs Chromium, three.js and the video).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);PV=$REPO/docs/proposals/R158/bats/preview;OUTDOC=$REPO/docs/proposals/R158/bats
S=${1:?scratch dir};NM=$2;VIDEO=${3:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/bb020a9b-Roblox-2026-10-09T23_40_57.826Z.mp4}
BASE=${BATS_BASE:-e9c0900}
[ -f "$VIDEO" ] || { echo "needs the owner's reference video: $VIDEO";exit 1; }
mkdir -p "$S/render/out" "$S/refs"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatConfig.lua" > "$S/BatConfig_today.lua";git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatSwingPose.lua" > "$S/BatSwingPose_today.lua"
python3 "$REPO/tools/tests/bundle.py" "$S/pose_bundle.luau" BatConfig="$S/BatConfig_today.lua" BatSwingPose="$S/BatSwingPose_today.lua" \
 BatConfigBuilt="$REPO/src/ReplicatedStorage/BatConfig.lua" BatSwingPose158="$REPO/src/ReplicatedStorage/BatSwingPose.lua" >/dev/null
# the dump loads the built module with its own BatConfig (the preview module needed none)
sed "s/^local Proposed=load('BatSwingPose158',{})$/local Built=load('BatConfigBuilt',{});local marker2={};local Proposed=load('BatSwingPose158',{script={Parent={BatConfig=marker2}},require=function(x)assert(x==marker2);return Built end})/" \
 "$PV/dump_poses158.luau" > "$S/dump_built158.luau"
grep -q "BatConfigBuilt" "$S/dump_built158.luau" || { echo "FAIL: the dump script changed (no load line to replace)";exit 1; }
(cd "$S" && /opt/luau/luau dump_built158.luau -a 120 0.97 > poses.jsonl)
grep -q '"proposedTotal":0.850,"proposedContact":0.300' "$S/poses.jsonl" && echo "ok: the built swing: .85 s, contact at .30 s" || { echo "FAIL: the built swing's timing";exit 1; }
# the sheet script with the built labels
sed -e "s/('PROPOSED\\\\nR15', 'proposed_R15'), ('PROPOSED\\\\nR6', 'proposed_R6')/('BUILT\\\\nR15', 'proposed_R15'), ('BUILT\\\\nR6', 'proposed_R6')/" \
 -e "s/'Bat swing: the reference video vs today vs the proposal'/'Bat swing: the reference video vs today vs the BUILT swing (R158)'/" \
 -e "s/real BatSwingPose (today) and the proposed '/the BatSwingPose of today (git) and the BUILT '/" \
 -e "s/'BatSwingPose158 sampled on an exact CFrame./'src BatSwingPose sampled on an exact CFrame./" \
 -e "s/White ribbon = the proposed swing trail (strike only)/White ribbon = the built swing trail (strike only)/" \
 -e "s/('Proposed (BatSwingPose158)', /('Built (src BatSwingPose)', /" \
 -e "s/'Proposed from above:/'Built from above:/" -e "s/'Proposed effects at contact:/'Built effects at contact:/" \
 "$PV/make_swing_preview158.py" > "$S/make_built158.py"
for w in "BUILT\\\\nR15" "the BUILT swing (R158)" "Built (src BatSwingPose)" "Built from above" "Built effects at contact";do grep -q "$w" "$S/make_built158.py" || { echo "FAIL: a label was not changed ($w)";exit 1; };done
cp "$PV/swing_render158.html" "$PV/render_swing158.mjs" "$S/render/"
if [ -n "$NM" ];then [ -e "$S/render/node_modules" ] || ln -s "$NM" "$S/render/node_modules"
else [ -d "$S/render/node_modules/three" ] || (cd "$S/render" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/render/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/render/node_modules/playwright"
python3 -I "$S/make_built158.py" jobs "$S/jobs.json"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render/render_swing158.mjs" "$S/render" "$S/poses.jsonl" "$S/jobs.json" "$S/render/out"
python3 -I "$S/make_built158.py" refs "$VIDEO" "$S/refs"
python3 -I "$S/make_built158.py" sheet "$S/render/out" "$S/refs" "$OUTDOC/swing_preview.png"
echo "ok: $OUTDOC/swing_preview.png (the built swing)"
