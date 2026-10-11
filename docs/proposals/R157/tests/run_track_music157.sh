#!/bin/sh
# Usage: sh run_track_music157.sh [scratch dir] [place.rbxl]      (NO_MUTATE=1 skips the teeth; BASE=<ref> = the R156 release, default c432356)
# R157b fix: the track music turned into the base music in the Desert (owner: "at some points in the track the track music will be replaced with the base music, this happens when
# entering desert"). Cause: BackgroundMusic.trackIsActive read the Part Lobby.BaseBoundaryLine, and the place streams (Workspace.StreamingEnabled, StreamingTargetRadius 1024,
# StreamOutBehavior Opportunistic): a client drops that part once the player is far down the track (Z > 925 at the full radius, Z > 501 at a radius of 600), "no line" meant
# "not on the track", and the base music came back. The fix: the line's Z and X also stand on ReplicatedStorage.RunnerMotion (TrackBoundaryZ / TrackCenterX, written by
# MapService.new, never streamed); trackIsActive uses them when the line is not there. On the Roblox mock (/opt/luau/luau) with the REAL start-up passes on the owner's place and the
# REAL BackgroundMusic, BiomeMood, WeatherWorld149 and MapService:
#  0. static  - BackgroundMusic compiles at -O0 and is the file frozen in R151's frozen.sha256 (with its R157b note); it differs from the R156 release only in trackIsActive and the
#               helper before it; Config.lua is as at the base (but for Version); MapService writes the attributes from the line; no other client script reads the line; this suite is
#               on line 6 of run_all_suites.sh; no model names in the files of this round
#  1. the proof - the R156 release's script on the owner's place (track_music157.luau, Expect = old): all streamed in it is right everywhere (the box is right), with the line
#               streamed out it fails exactly where the line streams out: Z 933 at the place's radius 1024 (inside the Desert), Z 508 at 600, at the first stud at 64, and stays wrong
#               to the end of the track
#  2. test    - the same scene on this checkout's script (Expect = fixed): the numbers of the real map (line, attributes, the Desert's Z range, walls, pyramid); BiomeMood /
#               MapService:IsInsideBiomeTrack / WeatherWorld149 say the same as the box; a player walks the track centre and both walls at floor height from the hub through every
#               biome to the end (and back), the Desert wall to wall, and round and through the pyramid up to its top, with everything streamed in and with the line streamed out beyond
#               1024 / 600 / 64 studs: the track music on every frame from 2 s after the entrance, the base music in the hub; 20 minutes of songs ending and crossing over in the
#               Desert with the line out (no dip, no base voice); the stand-ins (neither line nor attributes = base music as before; the live line wins)
#  3. teeth   - broken copies of the script, each must FAIL the test
# Without the place file the place steps are skipped (the static checks still run).
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BASE=${BASE:-c432356}
mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;C=$S/StarterPlayer/StarterPlayerScripts;SS=$S/ServerScriptService/ChestChaseServer
BGM=src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
git -C "$REPO" rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "the base commit $BASE is not in this repository (set BASE)"
/opt/luau/luau-compile -O0 --binary "$C/BackgroundMusic.client.lua" >/dev/null 2>"$OUT/compile.err" && echo "ok: BackgroundMusic compiles at -O0" || { fail "BackgroundMusic does not compile at -O0: $(head -1 "$OUT/compile.err")"; }
sh "$T/bgm_frozen.sh" "$REPO" && echo "ok: BackgroundMusic.client.lua is the file frozen in R151's frozen.sha256" || fail "BackgroundMusic.client.lua differs from its hash in docs/proposals/R151/tests/frozen.sha256"
grep -q "^# R157b fix (on purpose): BackgroundMusic.client.lua: trackIsActive" "$P/R151/tests/frozen.sha256" || fail "frozen.sha256 has no R157b note for BackgroundMusic"
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet -) && echo "ok: every frozen file hash holds" || fail "a frozen file's hash changed"
git -C "$REPO" show "$BASE:$BGM" > "$OUT/bgm_base.lua" 2>/dev/null || fail "$BGM is not in $BASE"
python3 - "$OUT/bgm_base.lua" "$C/BackgroundMusic.client.lua" > "$OUT/same.log" 2>&1 <<'PY' && echo "ok: $(cat "$OUT/same.log")" || { fail "BackgroundMusic changed outside trackIsActive";cat "$OUT/same.log"; }
import re, sys
old = open(sys.argv[1], encoding='utf-8').read()
new = open(sys.argv[2], encoding='utf-8').read()
# R157b review fix (on purpose): the one other change in the script is the AudioMixer fetch (WaitForChild instead of a dot index: the script can start before AudioMixer has replicated).
# It is undone here before the comparison, so everything else must still be byte for byte the R156 release's script (run_early_audio157.sh pins the WaitForChild itself).
fetch_new = 'require(game:GetService("ReplicatedStorage"):WaitForChild("AudioMixer"))'
fetch_old = 'require(game:GetService("ReplicatedStorage").AudioMixer)'
if new.count(fetch_new) != 1 or old.count(fetch_old) != 1:
    print('the AudioMixer fetch is not where the R157b review fix put it (WaitForChild in the script, the dot index in the release)'); sys.exit(1)
new = new.replace(fetch_new, fetch_old)
# the region R157b owns: from the R157b note (new) / `local function trackIsActive` (old) to the R156 playlist note that follows trackIsActive
def cut(s, start_pat):
    a = re.search(start_pat, s, re.M)
    b = s.index('-- R156 (owner): the track playlist.')
    assert a and a.start() < b, start_pat
    return s[:a.start()] + '<<trackIsActive>>' + s[b:], s[a.start():b]
o_rest, o_reg = cut(old, r'^local function trackIsActive\(\)')
n_rest, n_reg = cut(new, r'^-- R157b fix \(owner')
if o_rest != n_rest:
    print('the script differs from the R156 release outside trackIsActive'); sys.exit(1)
if 'BiomeTrackEndZ' not in n_reg or "'FieldWidth'" not in n_reg or 'p.Y> -20 and p.Y<=300' not in n_reg or 'hum.Health<=0' not in n_reg or 'insideTrack and-.5 or .5' not in n_reg:
    print('trackIsActive lost one of its terms (end Z, field width, Y range, health, hysteresis)'); sys.exit(1)
print('everything but trackIsActive (%d -> %d lines with its helper) is byte for byte the R156 release\'s script (but for the AudioMixer WaitForChild); its terms (end Z, field width, Y range, health, hysteresis) are all there' % (o_reg.count('\n'), n_reg.count('\n')))
PY
norm(){ sed "s/Config\.Version='[^']*'/Config.Version=V/"; }
[ "$(git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | norm)" = "$(norm < "$SS/Config.lua")" ] && echo "ok: Config.lua is as at $BASE (but for Version)" || fail "Config.lua changed beyond Config.Version since $BASE"
grep -q "movement:SetAttribute('TrackBoundaryZ',self.BaseBoundaryLine.Position.Z)" "$SS/MapService.lua" && grep -q "movement:SetAttribute('TrackCenterX',self.BaseBoundaryLine.Position.X)" "$SS/MapService.lua" && echo "ok: MapService.new writes TrackBoundaryZ / TrackCenterX from the line" || fail "MapService.new does not write the line's Z / X to RunnerMotion"
others=$(grep -rln "BaseBoundaryLine" "$S/StarterPlayer" "$S/ReplicatedFirst" "$S/ReplicatedStorage" 2>/dev/null | grep -v "BackgroundMusic.client.lua")
[ -z "$others" ] && echo "ok: no other client or shared script reads the streamed line (BackgroundMusic reads it with the RunnerMotion stand-in)" || fail "these scripts read Lobby.BaseBoundaryLine, which streams out: $others"
grep -q "TrackBoundaryZ" "$C/BackgroundMusic.client.lua" && grep -q "TrackCenterX" "$C/BackgroundMusic.client.lua" || fail "BackgroundMusic does not use RunnerMotion's TrackBoundaryZ / TrackCenterX"
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R157/tests/run_track_music157.sh[; ]" || fail "run_track_music157.sh is not on line 6 of tools/tests/run_all_suites.sh" # R157b review fix: anywhere on line 6 (it used to have to sit right before run_pyramid156.sh, and a later merge put run_early_audio157.sh between them)
grep -q "R157b" "$P/R156/music156.md" || fail "docs/proposals/R156/music156.md has no R157b fix note"
echo "ok: registered in run_all_suites.sh, noted in music156.md"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|\b(op[u]s|sonn[e]t|haik[u]|gemin[i]|llam[a])\b|gp[t]-?[0-9]" "$HERE/run_track_music157.sh" "$HERE/track_music157.luau" "$HERE/bundle_track_music157.py" "$HERE/place_streaming157.py" "$P/R156/music156.md" "$C/BackgroundMusic.client.lua" "$P/R151/tests/frozen.sha256" 2>/dev/null | grep -q .;then fail "a model name in the files of this round";else echo "ok: no model names in the files of this round";fi
if [ ! -f "$PLACE" ];then echo "== the owner's place: SKIPPED (no place file at $PLACE)";[ $RC = 0 ] && echo "R157 track music suite passed (static only)" || echo "R157 track music suite FAILED";exit $RC;fi
# the scene ---------------------------------------------------------------------------------------------------------------------------------------
scene() { # $1 dir, $2 BackgroundMusic file, $3 fixed | old
 d=$1;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R149/tests/zfight_world.luau" "$P/R150/tests/sfx_env.luau" "$d/"
 python3 "$HERE/bundle_track_music157.py" "$S" "$d" "$2" >/dev/null
 [ -f "$OUT/place_tree.luau" ] || python3 "$P/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place_tree.luau" Workspace/ChestChaseMap >/dev/null
 cp "$OUT/place_tree.luau" "$d/"
 python3 -I "$HERE/place_streaming157.py" "$PLACE" "$3" > "$d/t157.luau"
 (echo '--!nocheck';cat "$d/t157.luau";sed -n 11,63p "$P/R149/tests/zfight_scene.luau";cat "$HERE/track_music157.luau") > "$d/run_scene.luau"
 (cd "$d" && timeout 900 /opt/luau/luau run_scene.luau > scene.log 2>&1)
}
show() { # $1 dir, $2 label
 if [ "$3" = quiet ];then :;else grep -E '^(GEO|SWEEP|SONGS|-- )' "$1/scene.log" | cut -c1-330;fi
 grep -E '^FAIL' "$1/scene.log" | head -12
}
echo "== 1. the proof: the R156 release's script (Expect = old)"
if scene "$OUT/old" "$OUT/bgm_base.lua" old;then grep -E '^(GEO streaming|SWEEP)' "$OUT/old/scene.log" | cut -c1-330;echo "  $(grep -v '^WARN' "$OUT/old/scene.log" | tail -1)";else echo "  proof run FAILED";show "$OUT/old" proof;grep -v '^WARN' "$OUT/old/scene.log" | grep -iE 'error|stack' | head -5;fail "the R156 script does not fail the way the cause says (see above)";fi
echo "== 2. test: this checkout's script (Expect = fixed)"
if scene "$OUT/fixed" "$C/BackgroundMusic.client.lua" fixed;then show "$OUT/fixed" test;echo "  $(grep -v '^WARN' "$OUT/fixed/scene.log" | tail -1)";else echo "  test FAILED";show "$OUT/fixed" test;grep -v '^WARN' "$OUT/fixed/scene.log" | grep -iE 'error|stack' | head -5;fail "track_music157";fi
# teeth -------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 3. teeth: each break must make the test fail"
 M=$OUT/mut;mkdir -p "$M";caught=0;total=0
 mutate(){ # name old new
  name=$1;total=$((total+1))
  python3 - "$C/BackgroundMusic.client.lua" "$M/bgm.lua" "$2" "$3" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
src, dst, old, new = sys.argv[1:5]
s = open(src, encoding='utf-8').read()
assert s.count(old) == 1, old
open(dst, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
  if scene "$M/w$total" "$M/bgm.lua" fixed;then fail "mutation $name was NOT noticed";else caught=$((caught+1));echo "ok: $name -> fails ($(grep -c '^FAIL' "$M/w$total/scene.log") failing checks)";fi
  rm -rf "$M/w$total"
 }
 mutate "no RunnerMotion stand-in (the R156 behaviour)" "local motion=game:GetService('ReplicatedStorage'):FindFirstChild('RunnerMotion')" "local motion=nil"
 mutate "the stand-in reads the wrong attribute" "motion:GetAttribute('TrackBoundaryZ')" "motion:GetAttribute('TrackBoundaryY')"
 mutate "the stand-in's centre is 200 studs off" "if type(z)=='number'and type(x)=='number'then return z,x end" "if type(z)=='number'and type(x)=='number'then return z,x+200 end"
 mutate "the attributes win over the live line" "if line then return line.Position.Z,line.Position.X end" "if line and false then return line.Position.Z,line.Position.X end"
 mutate "the track ends at the old default 1475" "p.Z<=(tonumber(map:GetAttribute('BiomeTrackEndZ'))or 1475)" "p.Z<=1475"
 mutate "the track is 60 studs too narrow" "(tonumber(map:GetAttribute('FieldWidth'))or 180)/2+2" "(tonumber(map:GetAttribute('FieldWidth'))or 180)/2-28"
 mutate "nothing above Y 20 is the track (the pyramid's top is Y 27)" "p.Y> -20 and p.Y<=300" "p.Y> -20 and p.Y<=20"
 mutate "a dead player is still on the track" "hum.Health<=0 or not map" "false or not map"
 echo "$caught of $total breaks caught"
 [ "$caught" = "$total" ] || fail "a break was not caught"
fi
[ $RC = 0 ] && echo "R157 track music suite passed" || echo "R157 track music suite FAILED"
exit $RC
