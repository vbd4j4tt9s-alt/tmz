#!/bin/sh
# Usage: sh run_weather_ambience.sh [scratch dir]      (NO_MUTATE=1 skips the teeth; R156_BASE=<ref> = the commit this was built on,
#                                                       default 7cd9e87 = the R155 release)
# R156 weather ambience (owner: three looping ambiences, "each should play during its own weather": Blizzard 87749574738390, Thunderstorm 137593145026034, Rain 107960597100236).
# On the Roblox mock (/opt/luau/luau) with the REAL BiomeMood and the REAL BiomeAmbience.client of this checkout (bundled from THIS src tree by R151's bundle_cloudy.py):
#  0. static  - every script in src/ compiles at -O0 (check_compile_O0.sh); BackgroundMusic.client.lua (but for the R156 music script frozen in frozen.sha256) and Config.lua are untouched since the base (Config.lua: but for its
#               Config.Version, which the release step sets, as in R155); the R152 load guard is still line 1 of every client script; this suite is in run_all_suites.sh;
#               no model names in the R156 files and the file this round changed
#  1. test    - test_weather_ambience.luau: SoundTargets (each weather's bed at its volume in the base and only there, none on the track, none when not alive, x0.12 in a chase,
#               never two; the five old keys equal the old formula in every stage / weather / refresh / chase / alive combination), the rows and ids, the owner's override,
#               and the real BiomeAmbience.client (preload, fades, crossfade, track, chase, Ambience slider, character, the 12 s warning by name, teardown)
#  2. teeth   - the same test on broken copies of src (each must FAIL)
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R156_BASE:-7cd9e87} # the R155 release (a merge-base would be HEAD itself once this is merged, and compare nothing)
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;RSD=$S/ReplicatedStorage;C=$S/StarterPlayer/StarterPlayerScripts
INV=$P/inventory_R113/tests
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
git -C "$REPO" rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "the base commit $BASE is not in this repository (set R156_BASE)"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/compile.log" 2>&1 && echo "ok: $(tail -2 "$OUT/compile.log" | head -1)" || { fail "check_compile_O0.sh";tail -8 "$OUT/compile.log"; }
git -C "$REPO" diff --quiet "$BASE" -- src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua || sh "$T/bgm_frozen.sh" "$REPO" || fail "BackgroundMusic.client.lua changed since $BASE (the music stays as it is)" # R156 (on purpose): but for the owner's music change, accepted by its frozen hash
norm(){ sed "s/Config\.Version='[^']*'/Config.Version=V/"; }
[ "$(git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | norm)" = "$(norm < "$SS/Config.lua")" ] || fail "Config.lua changed beyond Config.Version since $BASE"
echo "ok: BackgroundMusic.client.lua (or the R156 music script frozen in frozen.sha256) and Config.lua (all but its Version) are untouched since $BASE"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: $(tail -2 "$OUT/guard.log" | head -1)" || { fail "the R152 load guard test fails";tail -5 "$OUT/guard.log"; }
grep -q "docs/proposals/R156/tests/run_weather_ambience.sh" "$T/run_all_suites.sh" || fail "run_weather_ambience.sh is not registered in tools/tests/run_all_suites.sh"
for row in "Key='RainBed',Name='WeatherRainAmbience',Id='107960597100236',Attribute='RainBedAssetId'" "Key='ThunderBed',Name='WeatherThunderAmbience',Id='137593145026034',Attribute='ThunderBedAssetId'" \
 "Key='BlizzardBed',Name='WeatherBlizzardAmbience',Id='87749574738390',Attribute='BlizzardBedAssetId'" \
 "M.WeatherBeds={Rain={Key='RainBed',Volume=.3},Thunderstorm={Key='ThunderBed',Volume=.32},Blizzard={Key='BlizzardBed',Volume=.3}}";do
 [ "$(grep -cF "$row" "$RSD/BiomeMood.lua")" = 1 ] || fail "BiomeMood.lua does not carry exactly one: $row"
done
echo "ok: registered in run_all_suites.sh; the three rows and M.WeatherBeds are in BiomeMood.lua as the owner gave them"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|\b(op[u]s|sonn[e]t|haik[u]|gemin[i]|llam[a])\b|gp[t]-?[0-9]" "$HERE" "$P/R156/weather_ambience.md" "$RSD/BiomeMood.lua" 2>/dev/null | grep -q .;then fail "a model name in the R156 files";else echo "ok: no model names in the R156 files or BiomeMood.lua";fi
# the tests ---------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir src-tree
 d=$1;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$HERE/test_weather_ambience.luau" "$d/"
 python3 "$P/R151/tests/bundle_cloudy.py" "$2" "$d" > /dev/null
}
runtest(){ ( cd "$1" && timeout 300 /opt/luau/luau test_weather_ambience.luau > test.log 2>&1 ); }
echo "== 1. test_weather_ambience"
build "$OUT/w" "$S"
if runtest "$OUT/w";then grep -E "^  [0-9]+ combinations" "$OUT/w/test.log";grep -v '^WARN' "$OUT/w/test.log" | tail -1;else grep -v '^WARN' "$OUT/w/test.log" | tail -30;fail "test_weather_ambience";fi
# teeth -------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 2. teeth: each break must make the test fail"
 M=$OUT/mut;mkdir -p "$M";caught=0;total=0
 mutate(){ # name file(under src) old new [old2 new2 ...]
  name=$1;file=$2;shift 2
  rm -rf "$M/src";mkdir -p "$M/src";cp -r "$S/." "$M/src/"
  python3 - "$M/src/$file" "$@" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f=sys.argv[1];rest=sys.argv[2:];pairs=list(zip(rest[0::2],rest[1::2]))
s=open(f,encoding='utf-8').read()
for old,new in pairs:
    assert old in s,old
    s=s.replace(old,new,1)
open(f,'w',encoding='utf-8').write(s)
PY
  build "$M/w" "$M/src";total=$((total+1))
  if runtest "$M/w";then fail "mutation $name was NOT noticed";else caught=$((caught+1));echo "ok: $name -> fails ($(grep -c '^FAIL' "$M/w/test.log") failing checks)";fi
 }
 BM=ReplicatedStorage/BiomeMood.lua;BA=StarterPlayer/StarterPlayerScripts/BiomeAmbience.client.lua
 mutate rain_louder $BM "Rain={Key='RainBed',Volume=.3}" "Rain={Key='RainBed',Volume=.4}"
 mutate thunder_quieter $BM "Thunderstorm={Key='ThunderBed',Volume=.32}" "Thunderstorm={Key='ThunderBed',Volume=.3}"
 mutate bed_on_the_track $BM "local bed=stage==0 and M.WeatherBeds[weather]" "local bed=M.WeatherBeds[weather]"
 mutate bed_not_ducked_in_a_chase $BM " if bed then t[bed.Key]=bed.Volume end
" "" " if chase then for key,value in pairs(t)do t[key]=value*.12 end end
" " if chase then for key,value in pairs(t)do t[key]=value*.12 end end
 if bed then t[bed.Key]=bed.Volume end
"
 mutate two_beds_in_a_storm $BM " if bed then t[bed.Key]=bed.Volume end" " if bed then t[bed.Key]=bed.Volume;t.RainBed=math.max(t.RainBed,.3)end"
 mutate cloudy_has_a_bed $BM "Blizzard={Key='BlizzardBed',Volume=.3}}" "Blizzard={Key='BlizzardBed',Volume=.3},Cloudy={Key='RainBed',Volume=.1}}"
 mutate beds_in_old_formula $BM "if stage==0 then t.Birds=.018;t.Leaves=.022" "if stage==0 then t.Birds=.019;t.Leaves=.022"
 mutate track_gain_off $BM "local TRACK_GAIN=1.25" "local TRACK_GAIN=1"
 mutate base_louder_too $BM "if stage==0 then t.Birds=.018;t.Leaves=.022" "if stage==0 then t.Birds=.018*TRACK_GAIN;t.Leaves=.022"
 mutate wrong_rain_id $BM "Id='107960597100236'" "Id='107960597100263'"
 mutate no_blizzard_row $BM " {Key='BlizzardBed',Name='WeatherBlizzardAmbience',Id='87749574738390',Attribute='BlizzardBedAssetId'},
" ""
 mutate override_ignored $BM "local value=script:GetAttribute(row.Attribute)" "local value=nil"
 mutate bed_is_not_alive_aware $BM " if not alive then return t end" " if not alive and stage~=0 then return t end"
 mutate client_no_fade $BA "local value=sound.Volume+(target-sound.Volume)*alpha;" "local value=target;"
 mutate client_warning_unnamed $BA "warn('[R73] '..sound.Name..' unavailable;" "warn('[R73] a sound unavailable;"
 mutate client_not_on_ambience $BA "sound.SoundGroup=Mixer.Group('Ambience');" "sound.SoundGroup=Mixer.Group('Effects');"
 mutate client_not_preloaded $BA "preload[#preload+1]=sound" "if row.Key=='Birds'then preload[#preload+1]=sound end"
 echo "$caught of $total breaks caught"
 [ "$caught" = "$total" ] || fail "a break was not caught"
fi
[ $RC = 0 ] && echo "R156 weather ambience: ALL PASS" || echo "R156 weather ambience: FAIL"
exit $RC
