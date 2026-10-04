#!/bin/sh
# Usage: sh run_keyboard.sh [scratch dir]. R148 candy keyboard runway (this suite kept its R147 location) on the Roblox mock with the real scripts:
#  test_keyboard.luau - KeyboardTrack.lua (60-column / pitch-3 grid, per-biome grids and spacebars, zones and shades, legend order, hierarchy,
#                       LOD windows: budgets, no overlap, no gaps over every position of the track, tiers 3/2/1) and the real
#                       KeyboardTrack.client.lua (client only, no remotes: full-width / full-length coverage, upright legends reading left ->
#                       right for a +Z runner, spacebar label, zone colours without bands, presses / clicks, other players, keepers,
#                       shovel holes near and far, pack platforms, tier changes, 1000 studs/s, reduced motion, teardown, fallbacks).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/cl"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts
# The retired GPT keyboard (R142-R146) must stay gone from src/.
for f in ReplicatedStorage/KeyboardCore142 ReplicatedStorage/KeyboardCore143 ReplicatedStorage/KeyboardScene142 ReplicatedStorage/KeyboardScene143 \
 ReplicatedStorage/KeyboardClient142 ReplicatedStorage/KeyboardClient143 ReplicatedStorage/KeyboardClient144 ReplicatedStorage/KeyboardClient145 ReplicatedStorage/KeyboardClient146 \
 ServerScriptService/ChestChaseServer/KeyboardServer142 ServerScriptService/ChestChaseServer/KeyboardServer143 \
 StarterPlayer/StarterPlayerScripts/KeyboardBoot142.client StarterPlayer/StarterPlayerScripts/KeyboardBoot143.client StarterPlayer/StarterPlayerScripts/KeyboardBoot144.client \
 StarterPlayer/StarterPlayerScripts/KeyboardBoot145.client StarterPlayer/StarterPlayerScripts/KeyboardBoot146.client; do
 [ ! -e "$REPO/src/$f.lua" ] || { echo "retired file still present: src/$f.lua";exit 1; }
done
[ ! -e "$REPO/src/Workspace/Keycap_Keyboard" ] || { echo "toolbox keycap scripts still present: src/Workspace/Keycap_Keyboard";exit 1; }
# The keyboard is client-only: no remotes, no server calls, no randomness in the shared module.
if grep -nE "RemoteEvent|RemoteFunction|FireServer|InvokeServer|OnClientEvent|ChestChaseRemotes" "$C/KeyboardTrack.client.lua" "$REPO/src/ReplicatedStorage/KeyboardTrack.lua"; then echo "keyboard script touches remotes";exit 1; fi
if grep -nE "math\.random|Random\.new" "$REPO/src/ReplicatedStorage/KeyboardTrack.lua"; then echo "KeyboardTrack.lua must be deterministic";exit 1; fi
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_keyboard.luau" "$OUT/cl/"
# mkbundle.py reads /home/user/tmz/src; bundle THIS checkout's src (a worktree has its own).
sed "s#'/home/user/tmz/src'#'$REPO/src'#" "$INV/mkbundle.py" > "$OUT/mkbundle.py"
python3 "$OUT/mkbundle.py" "$OUT/cl/rs_bundle.luau" KeyboardTrackClient="$C/KeyboardTrack.client.lua" >/dev/null
cd "$OUT/cl";echo "== test_keyboard";timeout 300 /opt/luau/luau test_keyboard.luau > keyboard.log 2>&1 || { tail -40 keyboard.log;exit 1; };tail -1 keyboard.log
