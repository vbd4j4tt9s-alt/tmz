#!/bin/sh
# Usage: sh run_hub_zfight.sh <scratch dir> [place.rbxl] [before ref, default 24ed94b = R151 as handed over]
# R152 hub z-fighting: builds the finished hub before / after (preview/run_hub_scenes.sh: the real HubDecor151 + HubLife151.client on the owner's
# place file in the R149 Roblox mock) and runs check_hub_zfight.py on both: no counted (coplanar / near / far) finding with a hub decor part, no
# tight (< 0.1 stud) pair between decor parts or a decor part and a saved wall other than the paving's designed 0.05 - 0.06 steps.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BEFORE=${3:-24ed94b}
sh "$REPO/docs/proposals/R152/preview/run_hub_scenes.sh" "$S" "$PLACE" "$BEFORE"
python3 "$HERE/check_hub_zfight.py" "$S/scenes/before.json" "$S/scenes/after.json"
