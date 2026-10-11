#!/bin/sh
# Usage: sh run_swing_preview158.sh <scratch dir> [node_modules dir with three@0.169] [the owner's reference video]
# R158 bats (owner: "polish up the animations ... a reference video will be sent"): docs/proposals/R158/bats/swing_preview.png + swing_preview.gif.
#  1. solve_keys158.py   - the proposed keys: an IK fit of where the bat should be at each key (approximate blocky rig) -> keys158.json
#  2. make_pose158.py    - BatSwingPose158.luau (same API as src BatSwingPose) from those keys (the copy beside this script is the result)
#  3. dump_poses158.luau - samples the REAL src BatSwingPose.lua (today) and BatSwingPose158 (proposed) through BatClient's overlay math on an
#                          exact CFrame, 120 per second, R15 and R6 -> poses.jsonl
#  4. render_swing158.mjs + swing_render158.html - three.js in headless Chromium (playwright, software WebGL) -> PNG panels
#  5. make_swing_preview158.py - reference crops from the video (ffmpeg), the sheet and the GIF
# APPROXIMATE: blocky rig, the fallback bat, no Roblox lighting; the legs stand still (in the game they keep running under the swing).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../../.." && pwd);OUTDOC=$(cd "$HERE/.." && pwd)
S=${1:?scratch dir};NM=$2;VIDEO=${3:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/bb020a9b-Roblox-2026-10-09T23_40_57.826Z.mp4}
[ -f "$VIDEO" ] || { echo "needs the owner's reference video: $VIDEO";exit 1; }
mkdir -p "$S/render/out" "$S/refs" "$S/gif"
python3 -I "$HERE/solve_keys158.py" > "$S/keys158.json"
python3 -I "$HERE/make_pose158.py" "$S/keys158.json" > "$S/BatSwingPose158.luau"
cmp -s "$S/BatSwingPose158.luau" "$HERE/BatSwingPose158.luau" && echo "ok: BatSwingPose158.luau matches the solved keys" || echo "NOTE: the solved keys differ from the committed BatSwingPose158.luau"
# (R158 built: src now holds the built swing; "today" is the approved checkout's swing, read from git: BATS_BASE, default e9c0900 = V150 R157b + notes.
#  docs/proposals/R158/tests/render_built158.sh draws the BUILT swing from src in the proposed rows)
BASE=${BATS_BASE:-e9c0900}
git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatConfig.lua" > "$S/BatConfig_today.lua";git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatSwingPose.lua" > "$S/BatSwingPose_today.lua"
python3 "$REPO/tools/tests/bundle.py" "$S/pose_bundle.luau" BatConfig="$S/BatConfig_today.lua" BatSwingPose="$S/BatSwingPose_today.lua" BatSwingPose158="$S/BatSwingPose158.luau"
cp "$HERE/dump_poses158.luau" "$S/"
(cd "$S" && /opt/luau/luau dump_poses158.luau -a 120 0.97 > poses.jsonl)
cp "$HERE/swing_render158.html" "$HERE/render_swing158.mjs" "$S/render/"
if [ -n "$NM" ];then [ -e "$S/render/node_modules" ] || ln -s "$NM" "$S/render/node_modules"
else [ -d "$S/render/node_modules/three" ] || (cd "$S/render" && npm install three@0.169.0 >/dev/null 2>&1);fi
[ -e "$S/render/node_modules/playwright" ] || ln -s "$(npm root -g)/playwright" "$S/render/node_modules/playwright"
python3 -I "$HERE/make_swing_preview158.py" jobs "$S/jobs.json"
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$S/render/render_swing158.mjs" "$S/render" "$S/poses.jsonl" "$S/jobs.json" "$S/render/out"
python3 -I "$HERE/make_swing_preview158.py" refs "$VIDEO" "$S/refs"
python3 -I "$HERE/make_swing_preview158.py" sheet "$S/render/out" "$S/refs" "$OUTDOC/swing_preview.png"
python3 -I "$HERE/make_swing_preview158.py" gif "$S/render/out" "$S/refs" "$S/gif" "$OUTDOC/swing_preview.gif"
cp "$S/render/out/tips.json" "$S/tips.json"
echo "ok: $OUTDOC/swing_preview.png, $OUTDOC/swing_preview.gif"
