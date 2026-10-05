#!/bin/sh
# Usage: sh run_pedestal.sh [scratch dir] [mutate]
# R150 (owner: "polish the pack pedestal that players have in base"): the mystery pedestal's look, states and moments on the Roblox mock, with the real scripts
# (the R149 zfight_world mock + pedestal_harness.luau underneath; every module bundled from THIS checkout's src):
#  test_pedestal_look.luau   - the server's pedestal: MysteryPedestalArt's ~30 static parts (layers, four solids, nothing but parts and one light), its space in the
#                              corner on straight and turned bases next to the REAL treadmill, its colours = the treadmill's theme per biome (read from BiomeVisuals),
#                              the lit parts and the light per state (Locked calm, Ready gold, Taken dim, Empty cold), repainted in place (no new instances).
#  test_pedestal_fx.luau     - MysteryPackClient + MysteryPedestalFx as the local player: LOCKED / UNLOCKED / TAKEN looks, the sign pill (R148's size, place and
#                              ranges), the unlock moment once (ring, flash, chime in the Effects group, padlock opens and drops, hop, sign pop), the take (the pack
#                              lifts off and flies to the player, whoosh at lift-off, the pack pickup cue Bubble06 on arrival, refused takes silent), other players'
#                              pedestals, streaming in and out, reduced motion, quality tiers, nothing per frame for far / hidden pedestals, rotated bases, teardown.
#  dump_zscene.luau + check_pedestal_zfight.py - the pedestal with its client fx and pack in every biome, Locked / Ready / Taken, through the R149 detector
#                              (docs/proposals/R149/tools/zfight.py): no counted (coplanar / near / far) finding on any pedestal part.
# The R147 suites (docs/proposals/R147/tests/run.sh: mystery 282, client 187) and the R149 whole-map check (R149/tests/run_zfight.sh) are run by their own scripts.
# With "mutate" as the 2nd argument, broken copies of src must each make a check fail (the tests have teeth).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
prep() { # $1 = src dir, $2 = work dir
 mkdir -p "$2"
 cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/pedestal_harness.luau" "$HERE"/test_pedestal_look.luau "$HERE"/test_pedestal_fx.luau "$HERE"/dump_zscene.luau "$2/"
 python3 "$HERE/bundle_pedestal.py" "$1" "$2" >/dev/null
}
suite() { # $1 = work dir, $2 = test, $3 = log
 (cd "$1" && timeout 600 /opt/luau/luau "$2" > "$3" 2>&1) || { tail -25 "$3";return 1; }
 tail -1 "$3"
}
zfight() { # $1 = work dir
 (cd "$1" && timeout 600 /opt/luau/luau dump_zscene.luau > zscene.txt 2> zscene.err) || { tail -15 "$1/zscene.err";return 1; }
 python3 "$HERE/check_pedestal_zfight.py" "$1/zscene.txt" > "$1/zfight.log" || { tail -8 "$1/zfight.log";return 1; }
 tail -2 "$1/zfight.log"
}
wiring() { # the client script and the server service use the new modules; the manifest lists them
 S=$REPO/src
 grep -q "MysteryPedestalArt" "$S/ServerScriptService/ChestChaseServer/MysteryPackService.lua"
 grep -q "MysteryPedestalFx" "$S/StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua"
 grep -q "ReplicatedStorage/MysteryPedestalFx	ReplicatedStorage/MysteryPedestalFx.lua" "$S/MANIFEST.tsv"
 grep -q "ChestChaseServer/MysteryPedestalArt	ServerScriptService/ChestChaseServer/MysteryPedestalArt.lua" "$S/MANIFEST.tsv"
 test -f "$S/ReplicatedStorage/MysteryPedestalFx.lua";test -f "$S/ServerScriptService/ChestChaseServer/MysteryPedestalArt.lua"
}
if [ "$MODE" != "mutate" ];then
 echo "== wiring (the service builds with MysteryPedestalArt, the client uses MysteryPedestalFx, both are in src/MANIFEST.tsv)";wiring
 prep "$REPO/src" "$OUT/w"
 echo "== test_pedestal_look";suite "$OUT/w" test_pedestal_look.luau "$OUT/look.log"
 echo "== test_pedestal_fx";suite "$OUT/w" test_pedestal_fx.luau "$OUT/fx.log"
 echo "== pedestal z-fighting (every biome, Locked / Ready / Taken, client fx included)";zfight "$OUT/w"
 exit 0
fi
# --- mutation checks: break one thing at a time in a copy of src; the suites must fail --------------------------------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text, $5 = which check catches it: look | fx | zfight
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 total=$((total+1));prep "$M" "$OUT/mw" 2>/dev/null
 case "$5" in
  look) (cd "$OUT/mw" && timeout 600 /opt/luau/luau test_pedestal_look.luau) >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
  zfight) (zfight "$OUT/mw") >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
  *) (cd "$OUT/mw" && timeout 600 /opt/luau/luau test_pedestal_fx.luau) >"$OUT/mut.log" 2>&1 && r=0 || r=1;;
 esac
 if [ "$r" = 0 ];then echo "MUTATION SURVIVED: $1";else echo "mutation caught: $1";caught=$((caught+1));fi
}
C=StarterPlayer/StarterPlayerScripts/MysteryPackClient.client.lua;F=ReplicatedStorage/MysteryPedestalFx.lua;A=ServerScriptService/ChestChaseServer/MysteryPedestalArt.lua
mutate "the unlock moment fires on every update, not once" $C "local changed=before~=nil and before~=state" "local changed=true" fx
mutate "pedestals far away still get fx and a spinning pack" $C "local ACTIVE_IN,ACTIVE_OUT=75,100" "local ACTIVE_IN,ACTIVE_OUT=1e9,1e9" fx
mutate "the per-frame function is never disconnected" $C "if not busy and loop then loop:Disconnect();loop=nil end" "" fx
mutate "reduced motion still animates the halo (client)" $C "if not reduced and entry.Anchor.Parent and measure(entry)<=ACTIVE_OUT" "if entry.Anchor.Parent and measure(entry)<=ACTIVE_OUT" fx
mutate "reduced motion still animates the halo (Fx.Step)" $F " if fx.Still then return end
 fx.Time=now" " fx.Time=now" fx
mutate "the lowest quality tier builds the fx" $C "local want=active and Fx~=nil and tier>=2" "local want=active and Fx~=nil and tier>=1" fx
mutate "taking the pack plays the generic click again" $C "pcall(Audio.Play,'Bubble06')end end" "pcall(Audio.Play,'Bubble04')end end" fx
mutate "the light shaft shows on everybody's pedestal" $F "fx.Shaft.Transparency=(ready and fx.Mine)and .9 or 1" "fx.Shaft.Transparency=ready and .9 or 1" fx
mutate "the unlock chime plays in the Interface group" $F "require(script.Parent.AudioMixer).Route(v,'Effects')" "require(script.Parent.AudioMixer).Route(v,'Interface')" fx
mutate "the padlock never drops away" $F "if u>=1 then F.DestroyLock(fx);if fx.State=='Locked'then F.BuildLock(fx)end" "if u>=2 then F.DestroyLock(fx);if fx.State=='Locked'then F.BuildLock(fx)end" fx
mutate "the hop lifts the pack into the sign" $F "HopSeconds=1.1,HopHeight=.4," "HopSeconds=1.1,HopHeight=1.4," fx
mutate "teardown leaves the flights behind" $C "if flightFolder then flightFolder:Destroy()end" "" fx
mutate "the sign shows only up to 60 studs" $C "local FAR,FAR_MINE=90,120" "local FAR,FAR_MINE=60,120" fx
mutate "a refused take plays the pickup cue (any prompt press)" $C "local function applyPrompt(entry)
 local prompt=entry.Prompt;if not prompt then return end" "local function applyPrompt(entry)
 local prompt=entry.Prompt;if not prompt then return end;if not entry.Hooked then entry.Hooked=true;prompt.Triggered:Connect(function()pickup()end)end" fx
mutate "the take flight starts when it is not the right state (a join)" $C "if before=='Ready'and state=='Claimed'then" "if state=='Claimed'then" fx
mutate "an error in the fx is not contained" $C "local ok,err=pcall(Fx.Step,entry.Fx,t);if not ok then fxFailed(err)end" "Fx.Step(entry.Fx,t)" fx
mutate "the pickup cue plays at lift-off and again on landing" $C "if flown then Fx.PlayLift()else pickup()end" "if flown then Fx.PlayLift();pickup()else pickup()end" fx
mutate "the pedestal's glow ignores the state" $A "p.Color=lit;p.Material=look.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic;p.Transparency=look.Transparency" "p.Color=Color3.fromRGB(176,118,255)" look
mutate "the Lava biome has the wrong colours" ReplicatedStorage/MysteryPackRules.lua "[4]={Body={96,88,111}" "[4]={Body={97,88,111}" look
mutate "every part of the pedestal is solid" $A "p.Anchored=true;p.CanCollide=solid==true;p.CanQuery=solid==true" "p.Anchored=true;p.CanCollide=true;p.CanQuery=true" look
mutate "the plinth grows into the tool boxes" $A "Vector3.new(9.2,.5,9.2)" "Vector3.new(21,.5,21)" look
mutate "a layer floats off the one under it" $A "disc(parent,'Upper collar',.45,5.4,y(5.035),gold)" "disc(parent,'Upper collar',.45,5.4,y(5.2),gold)" look
mutate "the top rim lies in the top plate's own plane (z-fighting)" $A "disc(parent,'Top rim',.14,7.5,y(5.92),gold)" "disc(parent,'Top rim',.55,7.5,y(6.035),gold)" zfight
mutate "the padlock face lies in the lock body's plane (z-fighting)" $F "add(model,'Lock face',V(1.2,.85,.1),CF(0,0,-.3),deep)" "add(model,'Lock face',V(1.2,.85,.1),CF(0,0,-.225),deep)" zfight
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
