#!/bin/sh
# Usage: sh run_weather.sh [scratch dir] [mutate]. R149 weather rework on the Roblox mock with the REAL scripts:
#  test_weather.luau   - WeatherWorld149.lua (pure maths: fall time vs height, tiles / snapping / hysteresis, area clipping with drift,
#                        tier budgets, patch layouts, fade timing) and WeatherWorld149.client.lua + WorldEvents.client.lua (world-fixed rain /
#                        thunder / blizzard tiles that moving or spinning the camera never touches, tiles follow the player by snapping, fall
#                        distance = cloud height, base-only clipping, splashes, snow patches fading in / out, tiers, FastMode, ReducedMotion,
#                        respawn, teardown, no allocation while running).
#  test_snowbiome.luau - SnowBiome149.client.lua next to the real KeyboardTrack.client.lua (permanent patches: layout, keyboard clearances,
#                        spacebar zone, legend dust rule, LOD, budgets, avoid zones, deterministic, teardown).
#  test_keyboard_fx.luau - the Storm lightning warning / impact rings and the shovel dirt bursts (StormWeather.client.lua, TrackHoleClient.client.lua,
#                        ReplicatedStorage.KeyboardSurface149) next to the real KeyboardTrack.client.lua: on the keyboard they sit at or above the
#                        key tops, everywhere else (arena past the last row, beside the field, no keyboard, no helper) at the old floor height.
# R149 performance patch (review part 1): tier-2 rain cap 900 (phones), opaque snow patches, height steps (no two overlapping patches coplanar),
# Snow-biome patches never cover a shovel hole (and come back when it is filled), the avoid list follows packs / camps / holes, a tier change keeps
# a fade-out going, a clear sky does no raycast / attribute read, the weather area is read when the map changes.
# With "mutate" the same suites run against deliberately broken copies of the sources: every mutation must make a test fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT/cl"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_weather.luau" "$HERE/test_snowbiome.luau" "$HERE/test_keyboard_fx.luau" "$OUT/cl/"
# mkbundle.py reads /home/user/tmz/src; bundle the given src tree (a worktree has its own).
bundle() { # $1 = src tree
 sed "s#'/home/user/tmz/src'#'$1'#" "$INV/mkbundle.py" > "$OUT/mkbundle.py"
 C=$1/StarterPlayer/StarterPlayerScripts
 python3 "$OUT/mkbundle.py" "$OUT/cl/rs_bundle.luau" WeatherWorld="$C/WeatherWorld149.client.lua" SnowBiome="$C/SnowBiome149.client.lua" \
  KeyboardTrackClient="$C/KeyboardTrack.client.lua" WorldEvents="$C/WorldEvents.client.lua" \
  StormWeather="$C/StormWeather.client.lua" TrackHoleClient="$C/TrackHoleClient.client.lua" >/dev/null
}
runall() { # prints the last line of each suite; returns non-zero when one fails
 rc=0
 for t in ${SUITES:-test_weather test_snowbiome test_keyboard_fx}; do
  echo "== $t"
  if (cd "$OUT/cl" && timeout 600 /opt/luau/luau $t.luau > $t.log 2>&1); then tail -1 "$OUT/cl/$t.log"; else tail -12 "$OUT/cl/$t.log"; rc=1; fi
 done
 return $rc
}
if [ "$MODE" != "mutate" ]; then
 bundle "$REPO/src"
 runall
 exit $?
fi
# --- mutation checks: break one thing at a time in a copy of src, the suites must fail ---------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = python expression text to replace (old), $4 = new
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 bundle "$M"
 total=$((total+1))
 if runall >"$OUT/mut.log" 2>&1; then echo "MUTATION SURVIVED: $1"; else echo "mutation caught: $1"; caught=$((caught+1)); fi
}
S=StarterPlayer/StarterPlayerScripts;R=ReplicatedStorage
mutate "tiles are placed at the player, not on the world grid" $S/WeatherWorld149.client.lua "t.Sky.Size=V3(w,.2,d);t.Sky.CFrame=CF(cx,gy+h,cz)" "t.Sky.Size=V3(w,.2,d);t.Sky.CFrame=CF(fx,gy+h,fz)"
mutate "lifetime no longer matches the cloud height" $R/WeatherWorld149.lua "LifeMin=life,LifeMax=life*1.03" "LifeMin=life*.5,LifeMax=life*.52"
mutate "weather is not clipped to the base" $R/WeatherWorld149.lua "if not a or not a.Valid then return true,(x0+x1)/2,(z0+z1)/2,x1-x0,z1-z0 end
 local ax0" "if true then return true,(x0+x1)/2,(z0+z1)/2,x1-x0,z1-z0 end
 local ax0"
mutate "snow patches vanish at once when the snow ends" $R/WeatherWorld149.lua "FadeOut={20,40}" "FadeOut={.05,.1}"
mutate "snow patches lie on the key tops (z-fight)" $R/WeatherWorld149.lua " Rise=.1,Thickness=.06,DustThickness=.04" " Rise=-.2,Thickness=.06,DustThickness=.04"
mutate "snow biome patches cover the spacebar zone" $R/WeatherWorld149.lua "SpaceClear=12" "SpaceClear=-200"
mutate "a camera spin moves the tiles (window follows the camera)" $S/WeatherWorld149.client.lua "if W.Recenter(win,fx,fz,tierCfg.Tile,tierCfg.Tile*.2)or" "if W.Recenter(win,workspace.CurrentCamera.CFrame.Position.X,workspace.CurrentCamera.CFrame.Position.Z,tierCfg.Tile,0)or"
# the keyboard effects (R149): only their own suite needs to run
SUITES=test_keyboard_fx
mutate "the storm warning ring is left at floor level (under the keys)" $S/StormWeather.client.lua "clearWarning();center=onKeys(center)" "clearWarning()"
mutate "the storm impact (ring, flash, bolt end) is left at floor level" $S/StormWeather.client.lua "    center=onKeys(center)
    local top=" "    local top="
mutate "the dirt bursts start and land at floor level" $S/TrackHoleClient.client.lua "if okKeys and lift>0 then position+=V3(0,lift,0)end" "if false then position+=V3(0,lift,0)end"
mutate "the helper lifts everywhere (arena, beside the field)" $R/KeyboardSurface149.lua "if x0 and x>=x0 and x<=x1 and z>=z0 and z<z1 then" "if x0 then"
mutate "the helper still lifts after the keyboard is gone" $R/KeyboardSurface149.lua "if not k or not workspace:FindFirstChild('KeyboardTrackVisuals')then return nil end" "if not k then return nil end"
mutate "the helper lowers a surface above the key tops" $R/KeyboardSurface149.lua "return math.max(0,top-(floorY or K.Config.FloorTop))" "return top-(floorY or K.Config.FloorTop)"
mutate "the helper lifts by a fixed .3 instead of the key height" $R/KeyboardSurface149.lua "return math.max(0,top-(floorY or K.Config.FloorTop))" "return .3"
unset SUITES
# R149 performance patch (review part 1)
mutate "phones get the old 1300 particle cap again" $R/WeatherWorld149.lua "[2]={R=1,Tile=50,Cap=900," "[2]={R=1,Tile=50,Cap=1300,"
mutate "weather patches translucent again (.04)" $R/WeatherWorld149.lua "Rise=.07,FinalTransparency=0," "Rise=.07,FinalTransparency=.04,"
mutate "Snow-biome patches translucent again (.06)" $R/WeatherWorld149.lua "FinalTransparency=0,DustClear=26" "FinalTransparency=.06,DustClear=26"
mutate "every patch at the same height (overlaps are coplanar)" $R/WeatherWorld149.lua "function W.PatchLevel(i,j)return(i%2)+2*(j%2)end" "function W.PatchLevel(i,j)return 0 end"
mutate "Snow-biome patches cover shovel holes" $S/SnowBiome149.client.lua "if reachesHole(s,a[1],a[2],a[3])then return true end" "local _=0"
mutate "a cell avoided for a hole goes on the permanent skip list" $S/SnowBiome149.client.lua "  if avoided then if avoidSkipN<4000 then avoidSkip[key]=true;avoidSkipN+=1 end
  elseif skipN<4000 then skip[key]=true;skipN+=1 end" "  if skipN<4000 then skip[key]=true;skipN+=1 end"
mutate "the avoid list is not refreshed when packs / camps / holes change" $S/SnowBiome149.client.lua "  if newSig~=avoidSig then" "  if false then"
mutate "a tier change cuts the weather fade-out" $S/WeatherWorld149.client.lua "if profile and shownKind~='Clear'then setKind(shownKind,now)end end" "if profile then setKind(kind,now)end end"
mutate "a clear sky still raycasts and reads the area every step" $S/WeatherWorld149.client.lua " if kind=='Clear'and shownKind=='Clear'and blend<=0 and boundN==0 and not W.Active(events,now)then return end" " local _=0"
mutate "the weather area is read again every step" $S/WeatherWorld149.client.lua " if map and areaDirty then" " if map then"
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
