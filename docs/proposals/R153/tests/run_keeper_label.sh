#!/bin/sh
# Usage: sh run_keeper_label.sh [scratch dir] [place.rbxl]   (needs /opt/luau/luau and python3)
# R153: the SPEED NEEDED sign over the keepers (owner: "make it so that speed needed thing is dislocated from the keeper and is way above the
# keepers head", then "... stays at his spawn point so when he chases the player it doesnt follow the keeper, for other keepers adopt this same
# thing"). docs/proposals/R153/keeper_label.md has the cause and the change. Checks:
#  1. static: line 1 of KeeperSpeedLabels.client.lua is still the R152 load guard (once), the script compiles, and its code (comments left out)
#     has no per-frame API (RenderStepped / Heartbeat / Stepped / PreRender / PreSimulation / BindToRenderStep / a polling loop); the server stamps
#     KeeperHome where it spawns a keeper (ChaseService._preparePersistentGuardian, VeiledEvent81.EnsureGuardian); BackgroundMusic is not touched.
#  2. test_keeper_label.luau on the Roblox mock with the REAL script, the REAL rev 6 data of the 7 biome keepers and The Darkened and
#     VeiledKeeper81's real poses: late / swapped / streamed bodies end with the sign >= 15 studs over the top of the body at rest; effect
#     parts and hitboxes never raise it; the sign sits on its own anchor at the spawn point and never follows the keeper; The Darkened's sign is
#     placed at its spawn and removed on despawn; debounce, stop-listening, write-on-change, no per-frame connection, no leaked anchor.
#  3. check_label_clear.py: in the owner's place nothing saved (hub, track props, biome walls) comes within 12 studs of any of the 7 signs, and the
#     track gate is far from the Forest one (skipped when the place file is not there).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/cl"
PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts;SSS=$REPO/src/ServerScriptService/ChestChaseServer
S=$C/KeeperSpeedLabels.client.lua
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 1. static"
GUARD='R152: start once the whole game has arrived'
head -1 "$S" | grep -q "$GUARD" || fail "KeeperSpeedLabels: line 1 is not the load guard"
[ "$(grep -c "$GUARD" "$S")" = 1 ] || fail "KeeperSpeedLabels: the guard must appear exactly once"
echo "ok: line 1 of KeeperSpeedLabels.client.lua is the R152 load guard"
/opt/luau/luau-compile --binary "$S" >/dev/null || fail "KeeperSpeedLabels does not compile"
# (the code without its comments: a comment may talk about frames and "while the keeper chases")
sed 's/--.*$//' "$S" > "$OUT/code.lua"
if grep -nE 'RenderStepped|Heartbeat|Stepped|PreRender|PreAnimation|PreSimulation|PostSimulation|BindToRenderStep|task\.wait|wait\(|while |repeat ' "$OUT/code.lua";then fail "KeeperSpeedLabels has a per-frame / polling construct";else echo "ok: no per-frame API and no polling loop in the code of KeeperSpeedLabels";fi
grep -q 'GetAttribute(.KeeperHome.)' "$S" || fail "KeeperSpeedLabels does not read KeeperHome"
grep -q 'SetAttribute("KeeperHome"' "$SSS/ChaseService.lua" || fail "ChaseService does not stamp KeeperHome"
grep -q "SetAttribute('KeeperHome'" "$SSS/VeiledEvent81.lua" || fail "VeiledEvent81 does not stamp KeeperHome"
echo "ok: the server stamps KeeperHome (ChaseService, VeiledEvent81) and the sign reads it"
grep -q "$GUARD" "$C/BackgroundMusic.client.lua" && fail "BackgroundMusic must stay untouched (hand-edited in the owner's place)"
echo "== 2. test_keeper_label (the real script on the Roblox mock)"
cp "$T/roblox.luau" "$INV/world.luau" "$HERE/test_keeper_label.luau" "$OUT/cl/"
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$OUT/cl/rs_bundle.luau" KeeperSpeedLabels="$S" >/dev/null
(cd "$OUT/cl" && timeout 600 /opt/luau/luau test_keeper_label.luau > label.log 2>&1) || { grep -v '^WARN' "$OUT/cl/label.log" | tail -40;fail "test_keeper_label";}
grep -v '^WARN' "$OUT/cl/label.log" | tail -1
echo "== 3. does the sign clip into anything saved in the place?"
if [ -f "$PLACE" ];then
 python3 -I "$HERE/check_label_clear.py" "$REPO" "$PLACE" "$OUT/clear" > "$OUT/clear.log" 2>&1 || { tail -20 "$OUT/clear.log";fail "a sign is too close to something saved in the place";}
 tail -3 "$OUT/clear.log"
else echo "SKIP: place file $PLACE not found, clearance not checked";fi
[ $RC = 0 ] && echo "R153 keeper label: PASS" || echo "R153 keeper label: FAIL"
exit $RC
