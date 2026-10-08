#!/bin/sh
# Usage: sh run_cloudy.sh [scratch dir] [mutate] [place.rbxl]
# R151 Cloudy sky (owner: "add a new weather effect where it alternated so th default weather is clear i want you to make the other default weather cloudy
# where it just dims the lighting so that the lanterns around the map can create a warm ambience"). On the Roblox mock (/opt/luau/luau) with the REAL scripts of
# this checkout (every module is bundled from THIS src tree by bundle_cloudy.py; no other bundler is used):
#  static checks         - the files are in src/MANIFEST.tsv, docs/COMMANDS.md and the F4 help list weather cloudy / cycle, OwnerUpdateCommands82's Actions has no new key,
#                          every script in src/ compiles, none of our files names a model;
#  test_cloudy_cycle     - WeatherCycle151 (alternation, durations ~8 / ~6 min with randomness, 20 - 40 s fades, determinism, no jump in three days, the atomic state
#                          string), the REAL WeatherService (publishes each switch once, smooth from the old level, a late joiner, event weather takes priority and the
#                          cycle returns, no mutation roll for Cloudy, owner hold / skip / auto) and the weather command through the REAL OwnerUpdateCommands82;
#  test_cloudy_sky       - BiomeMood's Cloudy palette for every biome (dimmer, cooler, hazier, never darker than a storm), EnvironmentLighting (smooth, few writes,
#                          exact return), the REAL BiomePresentation / WorldEvents clients: event weather priority, track, rare-pull story scenes, track refresh,
#                          The Darkened, FastMode, Terrain clouds, R149's rain / snow untouched, nothing else writes Lighting;
#  test_cloudy_hub       - the REAL HubLife151.client + HubLifeArt151: 16 lamp heads (R154 tidy; 30 before) and 14 wall lanterns warm up, the real lights fade in within the device
#                          tier's cap (8 / 4 / 0), the dark's R151 rule unchanged, the market's tagged lights, Reduced Motion, FastMode, late join, no per-frame work;
#  test_cloudy_place     - the same on the owner's place file (when it is there): the real market tags 6 lights + 2 heads, the real square's lamps tier by tier.
# Keep green next to this (own scripts): R149 run_weather.sh, R151 run_perf.sh, run_base_area.sh, R150 run_sfx.sh, R129 run.sh, veiled_R122 run.sh (The Darkened).
# With "mutate" as the 2nd argument, broken copies of src must each make a suite fail (ONLY=<words of one mutation's name> runs just that one).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;PLACE=${3:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}
mkdir -p "$OUT/cl"
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests
statics() {
 echo "== static checks"
 for f in ReplicatedStorage/WeatherCycle151 ServerScriptService/ChestChaseServer/WeatherSkyCommand151;do
  test -f "$S/$f.lua" || { echo "missing $f";return 1; }
  grep -q "	$f	" "$S/MANIFEST.tsv" || { echo "$f is not in src/MANIFEST.tsv";return 1; }
 done
 for w in "weather cloudy" "weather cycle" "weather cycle skip" "weather cycle auto";do
  grep -q "\`$w\`" "$REPO/docs/COMMANDS.md" || grep -q "$w" "$REPO/docs/COMMANDS.md" || { echo "$w is not in docs/COMMANDS.md";return 1; }
 done
 grep -q "/test weather cloudy" "$S/ReplicatedStorage/StudioTestHelp.lua" || { echo "weather cloudy is not in the F4 help";return 1; }
 grep -q "Cloudy sky" "$REPO/docs/COMMANDS.md" || { echo "the COMMANDS.md checklist has no Cloudy sky item";return 1; }
 # the weather action already existed: this round adds no key to OwnerUpdateCommands82's Actions
 grep -q "weather=true" "$SS/OwnerUpdateCommands82.lua" || { echo "the weather action vanished";return 1; }
 if grep -nE "Actions\.(cloudy|skycycle|cycle|sky)=" "$SS/OwnerUpdateCommands82.lua";then echo "a new Actions key was added";return 1;fi
 if grep -nE "[{,](cloudy|skycycle|cycle|sky)=true" "$SS/OwnerUpdateCommands82.lua";then echo "a new Actions key was added";return 1;fi
 grep -q "WeatherSkyCommand151" "$SS/OwnerUpdateCommands82.lua" || { echo "the weather command is not wired to WeatherSkyCommand151";return 1; }
 # no model names in what this round wrote
 if grep -nwEi "o[p]us|son[n]et|hai[k]u" "$S/ReplicatedStorage/WeatherCycle151.lua" "$SS/WeatherSkyCommand151.lua" "$HERE"/test_cloudy_*.luau "$HERE/bundle_cloudy.py";then echo "a model name is in our files";return 1;fi
 bad=0;for f in $(find "$S" -name '*.lua');do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
 [ "$bad" = 0 ]
 echo "ok: every script in src/ compiles; manifest, docs, help and the owner command are wired; no new Actions key"
}
bundle() { # $1 = src tree, $2 = work dir
 mkdir -p "$2"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/test_cloudy_cycle.luau "$HERE"/test_cloudy_sky.luau "$HERE"/test_cloudy_hub.luau "$2/"
 python3 "$HERE/bundle_cloudy.py" "$1" "$2" >/dev/null
}
runsuites() { # work dir = $OUT/cl; SUITES= which
 rc=0
 for t in ${SUITES:-test_cloudy_cycle test_cloudy_sky test_cloudy_hub}; do
  echo "== $t"
  if (cd "$OUT/cl" && timeout 900 /opt/luau/luau $t.luau > $t.log 2>&1); then grep -E "^  \(" "$OUT/cl/$t.log" || true;tail -1 "$OUT/cl/$t.log"; else grep -E "FAIL|rror" "$OUT/cl/$t.log" | head -12;tail -4 "$OUT/cl/$t.log"; rc=1; fi
 done
 return $rc
}
place() { # $1 = src tree: the owner's place
 [ -f "$PLACE" ] || { echo "(no place file at $PLACE: the place checks were skipped)";return 0; }
 mkdir -p "$OUT/place"
 python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place/place_tree.luau" Workspace/ChestChaseMap >/dev/null
 cp "$T/roblox.luau" "$INV/world.luau" "$REPO/docs/proposals/R149/tests/zfight_world.luau" "$HERE/test_cloudy_place.luau" "$OUT/place/"
 python3 "$HERE/bundle_cloudy.py" "$1" "$OUT/place" >/dev/null
 (cd "$OUT/place" && timeout 900 /opt/luau/luau test_cloudy_place.luau > place.log 2>&1) || { grep -E "^FAIL|rror" "$OUT/place/place.log" | head -12;tail -4 "$OUT/place/place.log";return 1; }
 grep -E "^  phone lamps" "$OUT/place/place.log" || true
 tail -1 "$OUT/place/place.log"
}
if [ "$MODE" != "mutate" ]; then
 statics
 bundle "$S" "$OUT/cl"
 runsuites
 echo "== the owner's place (test_cloudy_place.luau)";place "$S"
 echo "R151 Cloudy suites passed"
 exit 0
fi
# --- mutation checks: break one thing at a time in a copy of src, a suite must fail --------------------------------------------------------------------
M=$OUT/mut_src;caught=0;total=0
mutate() { # $1 = name, $2 = file under src, $3 = old text, $4 = new text; SUITES= which suites must see it (default all three), PLACE_TOO=1 also the place
 [ -z "$ONLY" ] || printf '%s' "$1" | grep -qi "$ONLY" || return 0
 rm -rf "$M";mkdir -p "$M";cp -r "$REPO/src/." "$M/"
 python3 - "$M/$2" "$3" "$4" <<'PY'
import sys
p,old,new=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(old)>=1,'mutation target not found: '+old
open(p,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
 bundle "$M" "$OUT/cl";total=$((total+1))
 if runsuites >"$OUT/mut.log" 2>&1 && { [ -z "$PLACE_TOO" ] || place "$M" >>"$OUT/mut.log" 2>&1; }; then echo "MUTATION SURVIVED: $1"; else echo "mutation caught: $1"; caught=$((caught+1)); fi
}
RSM=ReplicatedStorage;SP=StarterPlayer/StarterPlayerScripts
SUITES=test_cloudy_sky
mutate "event weather also gets the Cloudy palette" $RSM/BiomeMood.lua " if not event and cloud and cloud>0 then M.Overcast(out,cloud)end" " if cloud and cloud>0 then M.Overcast(out,cloud)end"
mutate "Cloudy does not dim" $RSM/BiomeMood.lua " Brightness=.68," " Brightness=1,"
mutate "Cloudy dimmer than a storm" $RSM/BiomeMood.lua " Brightness=.68," " Brightness=.4,"
mutate "Cloudy not cooler (warm ambient)" $RSM/BiomeMood.lua " Ambient={C(104,118,148),.6}," " Ambient={C(160,140,120),.6},"
mutate "no haze" $RSM/BiomeMood.lua " Haze=.55," " Haze=0,"
mutate "the sun rays stay under Cloudy" $RSM/BiomeMood.lua " out.Sun*=1-k" " out.Sun*=1"
mutate "every step of the level re-eases every property (the fade writes 10,000 times)" $RSM/EnvironmentLighting.lua " local alpha=(dark or self.Snap)and 1 or" " local alpha=dark and 1 or"
mutate "a big jump of the level snaps (a story scene starting would pop)" $RSM/EnvironmentLighting.lua " and math.abs(cq-(self.CQ or 0))<=3/E.CloudSteps;" ";"
mutate "BiomePresentation ignores the sky" $SP/BiomePresentation.client.lua " renderer:Step(stage,weather,player:GetAttribute('FastMode')==true,refresh,step,cloud)" " renderer:Step(stage,weather,player:GetAttribute('FastMode')==true,refresh,step)"
mutate "the clouds ignore Cloudy" $SP/WorldEvents.client.lua "ambient=Cycle.Effective(level,0,kind,player:GetAttribute('RarePullCinematic'))" "ambient=0"
mutate "the Terrain clouds are not restored exactly" $SP/WorldEvents.client.lua "  if Clouds.Made then c:Destroy()else c.Cover=base.Cover;c.Density=base.Density;c.Color=base.Color end" "  if Clouds.Made then c:Destroy()else c.Cover=base.Cover end"
SUITES="test_cloudy_cycle test_cloudy_sky"
mutate "story scenes keep the dimming" $RSM/WeatherCycle151.lua " if cinematic=='Scene'then return 0 end" ""
mutate "the track is dimmed as well" $RSM/WeatherCycle151.lua " if stage and stage~=0 then return level*max(0,min(1,(cfg or C.Config).Track or 0))end" ""
mutate "the fade is a hard step" $RSM/WeatherCycle151.lua "function C.Smooth(k)k=max(0,min(1,k));return k*k*(3-2*k)end" "function C.Smooth(k)k=max(0,min(1,k));return k>=.5 and 1 or 0 end"
SUITES=test_cloudy_cycle
mutate "every phase exactly the same length (no randomness)" $RSM/WeatherCycle151.lua " Spread=.1, " " Spread=0, "
mutate "fades take about a second" $RSM/WeatherCycle151.lua " Fade={20,40}, " " Fade={.5,1}, "
mutate "Clear and Cloudy swap lengths" $RSM/WeatherCycle151.lua " Clear={Seconds=480}, " " Clear={Seconds=240}, "
mutate "Cloudy is an event weather (mutation)" $RSM/WeatherTraits.lua "W.Events={Rain='Drippy',Thunderstorm='Charged',Blizzard='Frosted'}" "W.Events={Rain='Drippy',Thunderstorm='Charged',Blizzard='Frosted',Cloudy='Drippy'}"
mutate "a late joiner always sees the end of the fade" $RSM/WeatherCycle151.lua " if type(fade)~='number'or fade<=0 then return to end" " if true then return to end"
mutate "the server writes the sky every step" ServerScriptService/ChestChaseServer/WeatherService.lua " if cur and cur.Key==key then return false end" ""
mutate "a new state starts from Clear whatever the old level" ServerScriptService/ChestChaseServer/WeatherService.lua " if from==nil then from=cur and Cycle.LevelOf(cur,since)or(kind=='Cloudy'and 0 or 1)end" " if from==nil then from=(kind=='Cloudy'and 0 or 1)end"
mutate "a held sky starts from Clear whatever the level" ServerScriptService/ChestChaseServer/WeatherService.lua "From=cur and Cycle.LevelOf(cur,now)or(kind=='Cloudy'and 0 or 1)}" "From=(kind=='Cloudy'and 0 or 1)}"
mutate "a skip keeps the hold" ServerScriptService/ChestChaseServer/WeatherService.lua " local shown=self.Sky and self.Sky.Kind or'Clear'
 self.SkyHold=nil" " local shown=self.Sky and self.Sky.Kind or'Clear'"
mutate "the schedule's old boundary is used after a hold (a pop)" ServerScriptService/ChestChaseServer/WeatherService.lua " if cur and(cur.Hold or not(start>cur.Since and start<=now and now-start<=5))then since=now end" ""
mutate "weather clear forgets the default sky" ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua "  if kind=='Clear'and service.HoldSky then service:HoldSky('Clear',now)end" ""
mutate "weather cloudy leaves event weather on" ServerScriptService/ChestChaseServer/WeatherSkyCommand151.lua "  eventClear(service,now,W,Cycle);service:HoldSky('Cloudy',now)" "  service:HoldSky('Cloudy',now)"
SUITES=test_cloudy_hub
mutate "phones light every lamp" $RSM/WeatherCycle151.lua " Real={[3]=8,[2]=4,[1]=0}," " Real={[3]=8,[2]=8,[1]=8},"
mutate "FastMode keeps real lights" $RSM/WeatherCycle151.lua " Real={[3]=8,[2]=4,[1]=0}," " Real={[3]=8,[2]=4,[1]=4},"
mutate "the lamp heads never warm" $SP/HubLife151.client.lua " if headsChanged and Cycle then" " if false then"
mutate "the wall lanterns never warm" $SP/HubLife151.client.lua "  for _,part in ipairs(ctx.Lanterns)do warmHead(part,share)end" ""
mutate "the dark only lights lamps when it is cloudy too" $SP/HubLife151.client.lua "   if dark then on=true elseif i<=cap and q>0 then on=true;b=base*q end" "   if i<=cap and q>0 then on=true;b=base*q end"
mutate "the dark is capped by the tier" $SP/HubLife151.client.lua "   if dark then on=true elseif i<=cap and q>0 then on=true;b=base*q end" "   if dark and i<=Cycle.RealLights(t)then on=true elseif i<=cap and q>0 then on=true;b=base*q end"
mutate "every tick passes over every head" $SP/HubLife151.client.lua " local headsChanged=force or hq~=state.HeadQ" " local headsChanged=true"
mutate "the lamps follow Cloudy under an event" $RSM/WeatherCycle151.lua " if weather~=nil and weather~='Clear'then return 0 end" ""
mutate "the market's lights are not strengthened" $SP/HubLife151.client.lua "    local v,r=b.Brightness*(1+M.Brightness*q),b.Range*(1+M.Range*q)" "    local v,r=b.Brightness,b.Range"
mutate "lamp colours cannot return exactly" $SP/HubLife151.client.lua " local c=share>0 and base:Lerp(Cycle.Lamps.Warm,share)or base" " local c=base:Lerp(Cycle.Lamps.Warm,share+1e-4)"
mutate "the lamp lights are not in mirror pairs" $RSM/HubLifeArt151.lua " ctx.Lights=order" " ctx.Lights=lights"
SUITES="test_cloudy_hub";PLACE_TOO=1
mutate "the market's lights are not tagged" ServerScriptService/ChestChaseServer/MarketLayout.lua "  warmTag(lamp);warmTag(glow) -- R151: the Cloudy sky warms them (HubLife151.client)" ""
unset PLACE_TOO
echo "$caught of $total mutations caught"
[ "$caught" = "$total" ]
