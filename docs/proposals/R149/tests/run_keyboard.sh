#!/bin/sh
# Usage: sh run_keyboard.sh [scratch dir] [mutate]. With "mutate" the suite runs against deliberately broken copies of the sources
# (every mutation must make it fail). R149 candy keyboard (bigger, taller keys, one look out to long range, biome colours, steady
# clicks) on the Roblox mock with the real scripts:
#  test_keyboard.luau - KeyboardTrack.lua (22-column / pitch-8.18 grid, per-biome grids and spacebars, biome palettes and letter contrast,
#                       legend order, row windows and caps per tier, click cadence) and the real KeyboardTrack.client.lua (client only, no
#                       remotes: one keycap look at every distance out to ~1000 studs, rows dressed nearest first and recycled with
#                       hysteresis, no coplanar surfaces (the real floor is hidden locally, the bed is sunken, holes / patches / letters
#                       sit at distinct heights), the arena floor drawn by a local copy, letters upright in keyboard order on strips and
#                       riding with pressed keys, spacebar labels, presses / clicks (one recording, per-presser cadence, no stacked
#                       bursts, Effects volume 0), other players, keepers, shovel holes, pack platforms, tiers, 1000 studs/s, teleports,
#                       reduced motion, teardown (floor restored), template fallbacks).
# The R148 suite (docs/proposals/R147/tests/test_keyboard.luau) tested the retired layered design; its runner now runs this suite.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT/cl"
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
if grep -nE "math\.random|Random\.new" "$REPO/src/ReplicatedStorage/KeyboardTrack.lua" "$C/KeyboardTrack.client.lua"; then echo "the keyboard must be deterministic";exit 1; fi
# Properties a game script cannot write on Roblox (the mock errors on them too).
if grep -nE "CollisionFidelity|RenderFidelity" "$C/KeyboardTrack.client.lua"; then echo "keyboard writes a Studio-only property";exit 1; fi
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_keyboard.luau" "$OUT/cl/"
# mkbundle.py reads /home/user/tmz/src; bundle the given src tree (a worktree has its own).
bundle() { # $1 = src tree
 sed "s#'/home/user/tmz/src'#'$1'#" "$INV/mkbundle.py" > "$OUT/mkbundle.py"
 python3 "$OUT/mkbundle.py" "$OUT/cl/rs_bundle.luau" KeyboardTrackClient="$1/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua" >/dev/null
}
runsuite() { (cd "$OUT/cl" && timeout 600 /opt/luau/luau test_keyboard.luau > keyboard.log 2>&1); }
if [ "$MODE" != "mutate" ]; then
 bundle "$REPO/src"
 echo "== test_keyboard (R149)"
 runsuite || { tail -40 "$OUT/cl/keyboard.log";exit 1; }
 grep -E "^(parts|sprints|teleports|counts):" "$OUT/cl/keyboard.log" || true;tail -1 "$OUT/cl/keyboard.log"
 exit 0
fi
# --- mutation checks: break one thing at a time in a copy of src, the suite must fail ------------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = text to replace (first occurrence), $4 = replacement
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 bundle "$M";total=$((total+1))
 if runsuite; then echo "MUTATION SURVIVED: $1"; else echo "mutation caught: $1"; caught=$((caught+1)); fi
}
S=StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua;R=ReplicatedStorage/KeyboardTrack.lua
mutate "the real floor is not hidden (keys stand on a visible floor again)" $S "  part.LocalTransparencyModifier=1" "  part.LocalTransparencyModifier=0"
mutate "teardown leaves the floor hidden" $S " restoreGround()
 if unlift" " if unlift"
mutate "teardown leaves the shovel holes lifted" $S " if unlift then pcall(unlift);unlift=nil end" " unlift=nil"
mutate "one click budget shared by every presser" $S "  local gate=ownGate
  if kind~=1 then" "  local gate=ownGate
  if false then"
mutate "keys under a hole can be pressed (the hole floats)" $S "   if holeCell[key]then return end" "   if false then return end"
mutate "letters upside down for a +Z runner" $S "  l.Rotation=180;l.Font=FONT" "  l.Rotation=0;l.Font=FONT"
mutate "the bed sits at the floor plane (z-fighting)" $R " BedDepth=1.6," " BedDepth=0,"
mutate "short range (the far keys stop at 330 studs)" $R "[3]={Back=12,Ahead=122," "[3]={Back=12,Ahead=40,"
mutate "Lava keys back to candy strawberry" $R "Shades={{150,36,28},{198,58,26},{236,108,34},{112,30,30}}" "Shades={{255,120,150},{232,72,104},{255,150,170},{196,48,84}}"
mutate "three alternating click recordings" $S "sound.SoundId='rbxassetid://'..tostring(C.ClickSoundId)" "sound.SoundId='rbxassetid://'..tostring(C.ClickSoundIds[(i-1)%3+1])"
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
