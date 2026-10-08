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
#                       reduced motion, teardown (floor restored), template fallbacks) and, from the R149 performance patch (review part 1):
#                       the camera never sinks under the keys (a render step after the camera module; Scriptable / first person / off the
#                       keyboard untouched), a camera turn on a phone is spread over ~8 cheap frames (no burst; the measured worst frame and
#                       frames-to-settle are printed), unchanged letter values / recycled keys' Transparency are not rewritten, parked strips are
#                       off, spacebar labels have a render limit, the stripped template is cloned (no per-key children), a template that stops
#                       cloning falls back once, the floor is hidden last and given back when start() or the frame step fails, the connection
#                       list does not grow with streaming.
# R151 (owner: "doesn't push down far enough", "the words are missing", spacebar names "parallel to the safe zone and horizontal"): resting key tops 1.2
# above the floor, pressed .05 (1.15 of travel, feet planted on the pressed key), the runner's footprint leads his velocity; letters laid out on the REAL
# Top-face SurfaceGui canvas (x -> world -Z, y -> world +X: the owner's screenshots show R149 put every label but one off the canvas), turned 270 degrees,
# every key of every bound row has a visible label over it in every biome / tier / with plain-block keys; the spacebar name runs across the track; strips
# and pressed-key letters follow the key top measured from the keycap template (a taller mesh); 15 new mutations.
# R151 performance patch (owner's screenshots: a large area near the player with no keys, "almost no keys" on a phone): the window follows the camera's
# heading (along +Z / -Z, or symmetric when it looks across / down), the NEAR zone (114 / 90 / 65 studs each side) is dressed in the same frame and never
# missing (section 5d: teleports into every biome, sprints to 2,000 studs/s, tiers 3 / 2 / 1 at 60 and 30 fps, every camera way), far rows still
# waiting show a flat stand-in in the biome's key colour; 4 new mutations.
# R152 (owner: "keys behind also not rendering and its not loud enough"; far keys were bare caps; "no keyboard tiles" over the Desert oasis; Forest / Jungle presses play their own sound):
#  5e  keys AND letters from anywhere on every tier, looking along / back / across (hard studs written in the test: keys 990 / 600 / 365 ahead, 320 / 225 / 175 behind; letters
#      500 / 340 / 230 ahead, 220 / 170 / 140 behind), every key of every letter row has exactly one upright label over it (near strips and the far one-strip-a-row letters);
#      the per-tier budget (parts in use, SurfaceGuis, letters shown) is printed ("budget tier ..", "reach: ..") and capped; the track ends; the near zone is unchanged.
#  5f  the click: volume 1.8 (was .8, +7 dB = ~1.6x), roll-off 28 .. 160 (was 16 .. 90), a slight per-click gain, the voice cap; a press on a normal key in EVERY biome plays
#      rbxassetid://73942179280083 (volume Config.PressSoundVolume), a spacebar press in every biome the original click (Config.PressSound by key kind).
#  5g  cells left out (water / lava / pools / props on the floor): the shared KeyboardSkip encoding and geometry, the server scan (KeyboardSkip152) on a synthetic map (thresholds,
#      turned boxes, balls, discs, flush patches, invisible / non-scenery parts, spacebars), the client with cells left out (no key / press / letter, strips trimmed, the floor
#      kept under them as local copies, no stand-in over them, effects stay at the floor, live attribute changes, a string for another grid ignored).
#  place scene (keyboard_place.luau, needs the owner's place file: PLACE=...): the REAL start-up passes + the scan on the whole map (prints AREAS per biome and DROPPED), the oasis
#      checked with the water parts' oriented boxes (no key over them), the real client next to it. "NEWONLY=1 ... mutate" runs only the R152 mutations, "DRY=1 ... mutate"
#      only checks that every mutation target is still in the sources.
# R153 (owner: "when keepers knock players up the keyboard clicking sounds play, it should only play when players step on the keyboard"):
#  7c  a key SOUNDS only when a player character really steps on it (K.Steps: feet within StepReach of the floor, not rising faster than StepMaxRise; K.Thrown: not ragdolled /
#      flung / knocked back = the player's GuardianRagdollActive / GuardianFlingActive, the character's ChestChaseRagdollActive, PlatformStand, the Physics / FallingDown states).
#      For you and for every other player: a grounded walk clicks; a body lying on the keys presses them silently; one flying over them (a stale FloorMaterial) presses nothing and
#      clicks nothing; a knock-up's first frames (no flag yet) and a high hop are silent; landing, recovering and walking again clicks; a thrown body and a walker on one key the
#      same frame: one click, the walker's; keepers press the keys and never sound; the per-kind sounds are unchanged (normal key 73942179280083, spacebar the click). 14 mutations.
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
 python3 "$OUT/mkbundle.py" "$OUT/cl/rs_bundle.luau" KeyboardTrackClient="$1/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua" TrackHoleClient="$1/StarterPlayer/StarterPlayerScripts/TrackHoleClient.client.lua" >/dev/null # (R153: section 8b runs the real shovel client next to the keyboard)
}
runsuite() { (cd "$OUT/cl" && timeout 600 /opt/luau/luau test_keyboard.luau > keyboard.log 2>&1); }
# R152: the owner's place (not in the repo; the checks are skipped without it): the REAL start-up passes + KeyboardSkip152 + the real client next to the Desert oasis.
PLACE=${PLACE:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
place_scene() { # $1 = src tree
 [ -f "$PLACE" ] || { echo "(no place file at $PLACE: the whole-map keyboard scene was skipped)";return 0; }
 mkdir -p "$OUT/pl"
 cp "$T/roblox.luau" "$INV/world.luau" "$HERE/zfight_world.luau" "$OUT/pl/"
 python3 "$HERE/zfight_bundle.py" "$1" "$OUT/pl" >/dev/null
 python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/pl/place_tree.luau" Workspace/ChestChaseMap >/dev/null
 (echo '--!nocheck';sed -n 11,63p "$HERE/zfight_scene.luau";cat "$HERE/keyboard_place.luau") > "$OUT/pl/run.luau"
 (cd "$OUT/pl" && timeout 900 /opt/luau/luau run.luau > place.log 2>&1) || { grep -E "FAIL|rror|STEP" "$OUT/pl/place.log" | head -20;return 1; }
 grep -E "^(AREAS|DROPPED)" "$OUT/pl/place.log" || true;tail -1 "$OUT/pl/place.log"
}
if [ "$MODE" != "mutate" ]; then
 bundle "$REPO/src"
 echo "== test_keyboard (R149)"
 runsuite || { tail -40 "$OUT/cl/keyboard.log";exit 1; }
 grep -E "^(parts|sprints|teleports|counts|sprint writes|turn |click|budget|reach|press sounds|dirt float)" "$OUT/cl/keyboard.log" || true;tail -1 "$OUT/cl/keyboard.log"
 echo "== keyboard on the owner's place (R152: no keys over water / lava / props)"
 place_scene "$REPO/src"
 exit 0
fi
# --- mutation checks: break one thing at a time in a copy of src, the suite must fail ------------------------------------------------
M=$OUT/mut_src;caught=0;total=0;PHASE=old
mutate() { # $1 = name, $2 = file under src, $3 = text to replace (first occurrence), $4 = replacement
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 if [ -n "$NEWONLY" ]&&[ "$PHASE" = old ];then return 0;fi # NEWONLY=1: only the R152 and R153 mutations
 if [ -n "$OLDONLY" ]&&[ "$PHASE" != old ];then return 0;fi # OLDONLY=1: only the mutations before R152
 if [ -n "$R153ONLY" ]&&[ "$PHASE" != r153 ];then return 0;fi # R153ONLY=1: only the R153 mutations (key sounds only for a player who really steps on a key)
 if [ -n "$ONLY" ]&&[ "$ONLY" != "$1" ];then return 0;fi # ONLY="<name>": just that mutation
 if [ -n "$ONLYRE" ]&&! echo "$1" | grep -qE "$ONLYRE";then return 0;fi # ONLYRE="<regex>": the mutations whose name matches
 if [ -n "$DRY" ];then echo "target found: $1";return 0;fi # DRY=1: only check that every mutation target is still in the sources
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
mutate "letters turned 180 degrees (the R149 orientation: a quarter turn off on the real Top-face canvas)" $S "  l.Rotation=ROT;l.Font=FONT" "  l.Rotation=180;l.Font=FONT"
mutate "the bed sits at the floor plane (z-fighting)" $R " BedDepth=1.6," " BedDepth=0,"
mutate "short range (the far keys stop at 330 studs)" $R "[3]={Near=14,Back=40,Ahead=122," "[3]={Near=14,Back=40,Ahead=40,"
mutate "Lava keys back to candy strawberry" $R "Shades={{150,36,28},{198,58,26},{236,108,34},{112,30,30}}" "Shades={{255,120,150},{232,72,104},{255,150,170},{196,48,84}}"
mutate "three alternating click recordings" $S "sound.Name='KeyClickSound';sound.SoundId=id" "sound.Name='KeyClickSound';sound.SoundId='rbxassetid://'..tostring(C.ClickSoundIds[(i-1)%3+1])"
# R149 performance patch (review part 1)
mutate "the camera clamp runs before the camera module (one frame late)" $S "Enum.RenderPriority.Camera.Value+1" "Enum.RenderPriority.Camera.Value-1"
mutate "the camera clamp never lifts the camera" $S "  cam.CFrame=cf+V3(0,camMinY-y,0)" "  local _=cf"
mutate "the camera clamp also moves Scriptable cameras" $S "  if not cam or cam.CameraType==SCRIPTABLE then return end" "  if not cam then return end"
mutate "the camera clamp fights first person" $S "  if focus and(focus.Position-p).Magnitude<1.2 then return end" "  local _=focus"
mutate "a camera turn is a burst again (4x the budget in two frames)" $S "  local burst=false
" "  local burst=true
"
mutate "RowsPerFrame back to 8" $R "Font='FredokaOne',RowsPerFrame=4," "Font='FredokaOne',RowsPerFrame=8,"
mutate "letter labels rewritten on every bind" $S "     if st.PX[i]~=px or st.PY[i]~=py then" "     if true then"
mutate "a parked strip keeps its gui on" $S "    if st.On then st.On=false;st.Gui.Enabled=false end
   end
  end
  parkN=0" "    local _=0
   end
  end
  parkN=0"
mutate "a bound strip's gui is never switched back on" $S "   if not st.On then st.On=true;st.Gui.Enabled=true end" "   local _=0"
mutate "the spacebar labels have no render limit" $S "pcall(function()gui.MaxDistance=C.SpacebarMaxDistance end);" ""
mutate "a recycled key is hidden at once and shown again" $S "    hideN+=1;hideList[hideN]=s -- hidden at the end of the pass unless a row dressed in it takes the slot (then it is never written twice)" "    kPart[s].Transparency=1;shown[s]=nil"
mutate "the real floor is hidden before the keeper scan (early in start)" $S " scanKeepers()
 table.insert(conns,CS:GetInstanceAddedSignal('BiomeKeeper'):Connect(addKeeper))
 armGround()" " armGround()
 scanKeepers()
 table.insert(conns,CS:GetInstanceAddedSignal('BiomeKeeper'):Connect(addKeeper))"
mutate "start() is not protected: an error leaves the floor hidden" $S " local ok,err=pcall(start)" " local ok,err=true,start()"
mutate "a failing frame step never gives the floor back" $S "  if failed>=3 and not stopped then" "  if false then"
mutate "a template that cannot clone is retried every frame" $S "  template=nil
  warn('[R149] keyboard: the keycap template stopped cloning; the keys stay plain blocks')" "  warn('[R149] keyboard: the keycap template stopped cloning; the keys stay plain blocks')"
mutate "the template is cloned with its toolbox children" $S "then stripPart(c);template=c end" "then template=c end"
mutate "connections of containers that left the game stay in the list" $S "   if not c.Connected or not container:IsDescendantOf(workspace)then c:Disconnect();watched[container]=nil end" "   local _=0"
# R149 review part 2 (z-fighting touch-ups)
mutate "the end rims are .02 under the lobby floor again (z-fighting)" $R "RimDrop=.04," "RimDrop=.02,"
mutate "the lifted hole rim is coplanar with the letter strips (z-fighting)" $R " HoleLift=REST+.06," " HoleLift=REST,"
# R151: key press depth, the Top-face frame of the letters and the spacebar name, the measured key top
mutate "the press travels .47 again (resting top .55 above the floor)" $R "local REST=1.2 " "local REST=.55 "
mutate "pressed keys sink under the soles (feet hover over them)" $R "PressedRise=.05," "PressedRise=-.6,"
mutate "the footprint has no lead (the key ahead is late)" $S "    local lx=math.clamp(vel.X*lead,-cap,cap);local lz=math.clamp(vel.Z*lead,-cap,cap)" "    local lx,lz=0,0"
mutate "the footprint lead is not capped" $S "    local lx=math.clamp(vel.X*lead,-cap,cap);local lz=math.clamp(vel.Z*lead,-cap,cap)" "    local lx,lz=vel.X*lead,vel.Z*lead"
mutate "letters placed in the R149 frame (canvas x toward +X: all but one label off the canvas)" $S "     local _,py=K.TopPoint(st.X,z,w,d,PPS,LEFT-(c-.5)*P,z)" "     local px,py=((LEFT-(c-.5)*P)-xMin)*PPS,d/2*PPS"
mutate "the spacebar name is one canvas wide again (it runs along the track)" $S "label.Size=UDim2.fromScale(width/depth*.9,depth/width*.9)" "label.Size=UDim2.fromScale(1,.9)"
mutate "the spacebar name is turned 180 degrees (along the track)" $S "label.Rotation=ROT" "label.Rotation=180"
mutate "the strips ignore the measured key top" $S "(template and C.TopOffset or 0)+topExtra end" "(template and C.TopOffset or 0) end"
mutate "the strips ignore a tuned TopOffset (the mesh keys stand higher than the letters)" $S "K.KeyTop(0)+(template and C.TopOffset or 0)+topExtra end" "K.KeyTop(0)+topExtra end"
mutate "a pressed key's own letter is not offset by the measured excess" $S "  if topExtra>0 then pcall(function()gui.ZOffset=topExtra+LG.Margin end)end" "  local _=0"
mutate "the probe key is left in the world" $S "   local okMesh,me=pcall(meshExtra)
   probe:Destroy()" "   local okMesh,me=pcall(meshExtra)"
mutate "any ray answer counts, not only the probe's" $S "     if hit and hit.Instance==probe then" "     if hit then"
mutate "the measured excess is not capped" $R " return min(extra,C.Legend.MaxExtra)" " return extra"
mutate "the strips are coplanar with the key tops (no margin)" $R "Margin=.05,MaxExtra" "Margin=0,MaxExtra"
mutate "the canvas of a Top face is width x depth (R149)" $R "function K.TopCanvas(sizeX,sizeZ,pps)return sizeZ*pps,sizeX*pps end" "function K.TopCanvas(sizeX,sizeZ,pps)return sizeX*pps,sizeZ*pps end"
# R151 performance patch: the near zone is never missing
mutate "no across way (a camera looking across / down keeps its long side behind it: the owner's bare floor)" $R "if math.abs(h)<=C.FacingAcross then return 0 end" ""
mutate "the R149 near zone on tier 1 (Back 5 = 41 studs)" $R "[1]={Near=8,Back=22,Ahead=45,Hyst=1," "[1]={Near=5,Back=5,Ahead=48,Hyst=1,"
mutate "no stand-ins (bare bed while the far rows wait)" $S "  if Fill.Update(wa,wb)>0 then pending=true end" ""
mutate "the stand-ins reach the key-top plane (z-fighting)" $R "FillerDrop=.08," "FillerDrop=0,"
PHASE=new
# R152: keys behind and far letters, the louder click, the Forest / Jungle sound, the cells left out (water / lava / pools / props)
K2=ReplicatedStorage/KeyboardSkip152.lua;KS=ReplicatedStorage/KeyboardSurface149.lua
mutate "keys behind the camera's way back to 114 studs (tier 3 Back 14)" $R "[3]={Near=14,Back=40," "[3]={Near=14,Back=14,"
mutate "the near zone is as big as Back (a teleport dresses 81 rows at once)" $R "return t.Near or t.Back end" "return t.Back end"
mutate "letters stop where the near letters stop (no far letters)" $R "FarBehind=28,FarAhead=64,FarRows=4," "FarBehind=2,FarAhead=19,FarRows=4,"
mutate "the far strips' guis stop rendering at 300 studs" $R "FarPixelsPerStud=4,FarMaxDistance=800}" "FarPixelsPerStud=4,FarMaxDistance=300}"
mutate "far strips are never bound" $S "if fn<farN then Far.Bind(r);fn+=1 else pending=true end" "local _=0"
mutate "far letters turned 180 degrees" $S "l.TextSize=FTEXT;l.Size=UDim2.fromOffset(KW*FPPS,KW*FPPS)" "l.TextSize=FTEXT;l.Rotation=180;l.Size=UDim2.fromOffset(KW*FPPS,KW*FPPS)"
mutate "the click volume back to .8" $R "ClickVolume=1.8," "ClickVolume=.8,"
mutate "the click roll-off / range back to 90" $R "ClickRollOffMax=160,ClickRange=160," "ClickRollOffMax=90,ClickRange=90,"
mutate "a click gain above 1 (the peak rises: clipping)" $R "ClickGains={1,.94,.97,.91}" "ClickGains={1,1.3,1.6,.91}"
mutate "no per-click gain" $S "v.Sound.Volume=K.PressVolume(sk,stage)*K.ClickGain(gate.N)" "v.Sound.Volume=K.PressVolume(sk,stage)"
mutate "normal keys play the click (no key sound)" $R "PressSound={Key='rbxassetid://73942179280083',Spacebar=" "PressSound={Spacebar="
mutate "the key sound only in the Forest and Jungle again (a biome override back to the click)" $R "PressSoundBiome={}," "PressSoundBiome={Desert='rbxassetid://113108830240353',Snow='rbxassetid://113108830240353',Lava='rbxassetid://113108830240353',Crystal='rbxassetid://113108830240353',['Storm Peaks']='rbxassetid://113108830240353'},"
mutate "the spacebars play the key sound too" $R "Spacebar='rbxassetid://113108830240353'}," "Spacebar='rbxassetid://73942179280083'},"
mutate "the key sound starts at another volume than the click" $R "PressSoundVolume=1.8," "PressSoundVolume=.5,"
mutate "every press plays the click (the key kind is ignored)" $S "local pool=pools[K.PressSoundId(sk,stage)]or pools[DEFAULT]" "local pool=pools[DEFAULT]"
mutate "a spacebar is treated as a normal key (it plays the key sound)" $S "click(kind,who,px,pz,true,bar and bar.Stage)" "click(kind,who,px,pz,false,bar and bar.Stage)"
mutate "keys are dressed on left-out cells" $S "for col=1,COLS do if not skip[row*64+col]then" "for col=1,COLS do if true then"
mutate "near letter strips are not trimmed to their keys" $S "local a0,a1=keyedSpan(row,c0,c1)" "local a0,a1=c0,c1"
mutate "far letter strips are not trimmed to their keys" $S "local a0,a1=keyedSpan(row,1,COLS)" "local a0,a1=1,COLS"
mutate "the real floor is not kept under left-out cells" $S "local e=rec.Ext
  for _,r in ipairs(skipRects)do" "local e=rec.Ext
  for _,r in ipairs({})do"
mutate "a stand-in covers rows with left-out cells" $S "if not rowBound[r]and not barOfRow[r]and not geo.RowSkip[r]then" "if not rowBound[r]and not barOfRow[r]then"
mutate "a changed KeyboardSkip attribute is never applied" $S "if skipDirty then refreshSkip()end" "local _=0"
mutate "the skip string is read for any grid" $R "if v=='1'and tonumber(c0)==cols and tonumber(r0)==rows and math.abs(" "if v=='1'and math.abs("
mutate "the scan counts a prop from 0% (any touch)" $K2 "Flat=.10,Prop=.60,Grid=8," "Flat=.10,Prop=.00,Grid=8,"
mutate "props leave a key out from 25% again (a wall bank buries the whole edge column)" $K2 "Flat=.10,Prop=.60,Grid=8," "Flat=.10,Prop=.25,Grid=8,"
mutate "the scan samples the key footprint on a coarse 5 x 5 grid (a 42% bank reads as 60%)" $K2 "Flat=.10,Prop=.60,Grid=8," "Flat=.10,Prop=.60,Grid=5,"
mutate "a ball is a box in the scan" $K2 "if shape:find('Ball',1,true)then" "if false then"
mutate "the scan looks under Lobby too" $K2 "S.Roots={'Obby/Biomes'," "S.Roots={'Lobby','Obby/Biomes',"
mutate "the scan counts invisible parts" $K2 "d.Transparency<S.Config.InvisibleAt and" "true and"
mutate "the scan counts flush patches and parts above the keys as props" $K2 "local prop=not item.Flat and fp.Y0<=K.KeyTop(0)and fp.Y1>=F+C.PropMinTop" "local prop=not item.Flat"
mutate "the scan uses the axis-aligned box of a turned part" $K2 "local h=hull(pts);if #h<3 then return nil end" "local h;do local a,b,c,e=math.huge,-math.huge,math.huge,-math.huge;for _,p in ipairs(pts)do a=math.min(a,p[1]);b=math.max(b,p[1]);c=math.min(c,p[2]);e=math.max(e,p[2])end;h={{a,c},{b,c},{b,e},{a,e}}end;if #h<3 then return nil end"
mutate "effects lift onto keys over a left-out cell" $KS "if geo and geo.SkipCount>0 and geo.Skip[geo.RowOfZ(z)*64+geo.ColOfX(x)]then return nil end" "if false then return nil end"
# R153: the shovel holes are 1.5x the radius (rim 3.0): the keys under the whole rim stay up
mutate "the keys under a bigger hole's rim can be pressed (HoleReach back to the old rim, 2)" $R " HoleReach=4.6," " HoleReach=2,"
mutate "a crumb of the ring can hang over a key that goes down (HoleReach covers the rim only, 3)" $R " HoleReach=4.6," " HoleReach=3,"
mutate "the hole parts are not lifted onto the key tops (the bigger hole sinks into the keys)" $S "   d:SetAttribute(HOLE_BASE,y);setY(d,y+C.HoleLift)" "   d:SetAttribute(HOLE_BASE,y);setY(d,y)"
PHASE=r153
# R153: key sounds only for a player who really steps on a key
mutate "a keeper's press sounds again" $S "   if kind<3 then playKey(idx,kind,who,px,pz)else mutedAt[idx]=frameNo end" "   playKey(idx,kind,who,px,pz)"
mutate "a ragdolled / flung runner sounds (the thrown state is ignored)" $S "  local thrown=K.Thrown(p,char,hum)" "  local thrown=false"
mutate "a flying body with a stale FloorMaterial presses keys under it" $S "  if thrown and feetY>F+C.PlayerFeetReach then return nil end -- a stale FloorMaterial under a flying body must not press anything" "  local _=0"
mutate "every press sounds (K.Steps ignored)" $S "if K.Steps(feetY,typeof(vel)=='Vector3'and vel.Y or 0,thrown)then return own and 1 or 2 end" "if true then return own and 1 or 2 end"
mutate "a runner above the floor sounds (K.Steps ignores the feet height)" $R "return not thrown and feetY<=C.FloorTop+C.StepReach and(velY or 0)<=C.StepMaxRise" "return not thrown and(velY or 0)<=C.StepMaxRise"
mutate "a runner being knocked up sounds (K.Steps ignores the rising speed)" $R "return not thrown and feetY<=C.FloorTop+C.StepReach and(velY or 0)<=C.StepMaxRise" "return not thrown and feetY<=C.FloorTop+C.StepReach"
mutate "GuardianRagdollActive is not a thrown state" $R "player:GetAttribute('GuardianRagdollActive')==true or " ""
mutate "GuardianFlingActive is not a thrown state" $R " or player:GetAttribute('GuardianFlingActive')==true" ""
mutate "ChestChaseRagdollActive is not a thrown state" $R "if char and char:GetAttribute('ChestChaseRagdollActive')==true then return true end" "local _=0"
mutate "PlatformStand is not a thrown state" $R "if hum.PlatformStand==true then return true end" "local _=0"
mutate "the Humanoid states are not read" $R "local ok,state=pcall(hum.GetState,hum);if ok and THROWN_STATES[state]then return true end" "local _=0"
mutate "FallingDown is not a thrown state" $R "{'Physics','Ragdoll','FallingDown','PlatformStanding','Flying'}" "{'Physics','Ragdoll','PlatformStanding','Flying'}"
mutate "a walker loses his click to a keeper / a thrown body that pressed the key first" $S "if mutedAt[idx]==frameNo and kind>0 and kind<3 then" "if false then"
mutate "you press with FloorMaterial Air (the grounded test is gone)" $S "  if own and hum.FloorMaterial==AIR then return nil end" "  local _=0"
# R153 (owner: "the dirt piles float up into the sky"): section 8b, a hole must never climb (the lift is absolute, recorded on the part, guarded and capped)
mutate "a part with no record that is already on the key tops is lifted again (the dirt climbs when the memory is lost)" $S "   if y>=restTop then" "   if false then"
mutate "the part's height before the lift is not kept on the part (a stranded crumb cannot go back, teardown cannot restore)" $S "   d:SetAttribute(HOLE_BASE,y);setY(d,y+C.HoleLift)" "   setY(d,y+C.HoleLift)"
mutate "stranded dirt stays in the air (no ceiling)" $R " HoleCeiling=1, " " HoleCeiling=1e9, "
mutate "a pack platform presses a key under a hole (the hole floats over the dip)" $S "markRects(platRects,platCell,platList,holeCell)" "markRects(platRects,platCell,platList)"
mutate "another player's landing on the key he pressed silently does not click" $S "elseif kind==2 and who and quietBy[idx]==who then" "elseif false then"
mutate "a runner a little above the floor is not remembered (his landing is silent)" $S "return thrown and 4 or 5" "return 4"
mutate "a part that is not at its record is lifted again relative to where it is (the dig tween makes the crumbs climb)" $S "   if abs(y-want)>1e-3 and(abs(y-base)<1e-3 or y>want+C.HoleCeiling)then setY(d,want)end" "   if abs(y-want)>1e-3 then setY(d,y+C.HoleLift)end"
[ -z "$DRY" ] || exit 0
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
