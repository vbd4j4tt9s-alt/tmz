#!/bin/sh
# Usage: sh run_music156.sh [scratch dir]      (NO_MUTATE=1 skips the teeth; R156_MUSIC_BASE=<ref> = the commit before the music change, default cd8bd24 = the weather release)
# R156 music (owner: "for the track ambience and pre existing music we can just increase the volume by a bit and add these sound tracks 74095461107598, 132448918728086, that
# alternate. for base music we can add these tracks 1837487700, 1837487818, 1836280952."). On the Roblox mock (/opt/luau/luau) with the REAL BackgroundMusic and BiomeMood of this checkout:
#  0. static  - every script in src/ compiles at -O0 within 180 registers per function (check_compile_O0.sh); BackgroundMusic's first lines and Config.lua are as at the base (Config.lua: but for
#               its Version), the base playlist's code (createPeacefulTrack, findPlayablePeacefulTrack, waitForTrack, reportLoadFailure and the rotation thread) is byte for byte what it was; the
#               new BackgroundMusic is the one frozen in R151's frozen.sha256 (with its note), which is what the older "BackgroundMusic untouched" checks accept; the R152 load guard is still line 1
#               of every other client script; this suite is in run_all_suites.sh; no model names in the files of this round
#  1. test    - test_music156.luau: the track playlist (1 -> 2 -> 3 -> 1, a 3 s crossfade at each end, .07), leaving / coming back / the chase / the character, a track that does not load,
#               the base playlist (5 tracks), the track ambience x1.25 on stages 1-7, nothing created while idle, the clean-up
#  2. teeth   - the same test on broken copies of the two scripts (each must FAIL)
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R156_MUSIC_BASE:-cd8bd24} # the R156 weather release: the commit before the music change
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;C=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage;SS=$S/ServerScriptService/ChestChaseServer
INV=$P/inventory_R113/tests;R150=$P/R150/tests
BGM=src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
git -C "$REPO" rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "the base commit $BASE is not in this repository (set R156_MUSIC_BASE)"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/compile.log" 2>&1 && echo "ok: $(tail -2 "$OUT/compile.log" | head -1)" || { fail "check_compile_O0.sh";tail -8 "$OUT/compile.log"; }
[ "$(git -C "$REPO" show "$BASE:$BGM" | head -3)" = "$(head -3 "$C/BackgroundMusic.client.lua")" ] || fail "the first lines of BackgroundMusic changed (it has no load guard; line 1 stays)"
grep -q "R152: start once the whole game has arrived" "$C/BackgroundMusic.client.lua" && fail "BackgroundMusic must not carry the load guard"
norm(){ sed "s/Config\.Version='[^']*'/Config.Version=V/"; }
[ "$(git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | norm)" = "$(norm < "$SS/Config.lua")" ] || fail "Config.lua changed beyond Config.Version since $BASE"
echo "ok: BackgroundMusic keeps its first lines (no load guard), Config.lua is untouched since $BASE"
python3 - "$REPO" "$BASE" > "$OUT/same.log" 2>&1 <<'PY' && echo "ok: $(cat "$OUT/same.log")" || { fail "the base playlist's code changed";cat "$OUT/same.log"; }
import re, subprocess, sys
repo, base = sys.argv[1:3]
F = 'src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua'
old = subprocess.run(['git', '-C', repo, 'show', base + ':' + F], capture_output=True, check=True).stdout.decode('utf-8')
new = open(repo + '/' + F, encoding='utf-8').read()
def block(s, name):
    m = re.search(r'^local function ' + name + r'\(.*?^end$', s, re.S | re.M)
    return m.group(0) if m else None
bad = []
names = ['reportLoadFailure', 'createPeacefulTrack', 'waitForTrack', 'findPlayablePeacefulTrack', 'chaseIsActive', 'selectedMusic', 'ensureChasePlayback', 'trackIsActive', 'tween', 'cancelTween']
for n in names:
    a, b = block(old, n), block(new, n)
    if a is None or a != b:
        bad.append(n)
mark = 'task.spawn(function()\n\tlocal randomizer'
if old[old.index(mark):] != new[new.index(mark):]:
    bad.append('the rotation thread and what follows it')
for line in ['local PEACEFUL_VOLUME = 0.2', 'local CHASE_VOLUME = 0.10', 'local PLAYLIST_CROSSFADE_SECONDS = 3', 'local CHASE_FADE_IN_SECONDS = 0.65', 'local PEACEFUL_RESUME_SECONDS = 1.25']:
    if line not in new:
        bad.append(line)
if bad:
    print('changed: ' + ', '.join(bad)); sys.exit(1)
print('the base playlist code (%d functions, the rotation thread, the volumes) is byte for byte what it was' % len(names))
PY
sh "$T/bgm_frozen.sh" "$REPO" && echo "ok: BackgroundMusic.client.lua is the file frozen in R151's frozen.sha256" || fail "BackgroundMusic.client.lua differs from its hash in docs/proposals/R151/tests/frozen.sha256"
grep -q "^# R156 (on purpose): BackgroundMusic.client.lua: the track playlist" "$P/R151/tests/frozen.sha256" || fail "frozen.sha256 has no R156 note for BackgroundMusic"
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet -) && echo "ok: every frozen file hash holds" || fail "a frozen file's hash changed"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: $(tail -2 "$OUT/guard.log" | head -1)" || { fail "the R152 load guard test fails";tail -5 "$OUT/guard.log"; }
grep -q "docs/proposals/R156/tests/run_music156.sh" "$T/run_all_suites.sh" || fail "run_music156.sh is not registered in tools/tests/run_all_suites.sh"
echo "ok: registered in run_all_suites.sh"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|\b(op[u]s|sonn[e]t|haik[u]|gemin[i]|llam[a])\b|gp[t]-?[0-9]" "$HERE/run_music156.sh" "$HERE/test_music156.luau" "$P/R156/music156.md" "$RSD/BiomeMood.lua" "$C/BackgroundMusic.client.lua" "$P/R151/tests/frozen.sha256" "$T/bgm_frozen.sh" 2>/dev/null | grep -q .;then fail "a model name in the files of this round";else echo "ok: no model names in the files of this round";fi
# the test ----------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir [BackgroundMusic file] [BiomeMood file]
 d=$1;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$R150/sfx_env.luau" "$HERE/test_music156.luau" "$d/"
 python3 "$R150/mkbundle_sfx.py" "$d" BackgroundMusic="${2:-$C/BackgroundMusic.client.lua}" BiomeMood="${3:-$RSD/BiomeMood.lua}" > /dev/null
}
runtest(){ ( cd "$1" && timeout 600 /opt/luau/luau test_music156.luau > test.log 2>&1 ); }
echo "== 1. test_music156"
build "$OUT/w"
if runtest "$OUT/w";then grep -v '^WARN' "$OUT/w/test.log" | tail -1;else grep -v '^WARN' "$OUT/w/test.log" | tail -30;fail "test_music156";fi
# teeth -------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 2. teeth: each break must make the test fail"
 M=$OUT/mut;mkdir -p "$M";caught=0;total=0
 mutate(){ # name which(BGM|MOOD) old new [old2 new2 ...]
  name=$1;which=$2;shift 2
  cp "$C/BackgroundMusic.client.lua" "$M/BackgroundMusic.lua";cp "$RSD/BiomeMood.lua" "$M/BiomeMood.lua"
  if [ "$which" = BGM ];then target=$M/BackgroundMusic.lua;else target=$M/BiomeMood.lua;fi
  python3 - "$target" "$@" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f = sys.argv[1]; rest = sys.argv[2:]; pairs = list(zip(rest[0::2], rest[1::2]))
s = open(f, encoding='utf-8').read()
for old, new in pairs:
    assert old in s, old
    s = s.replace(old, new, 1)
open(f, 'w', encoding='utf-8').write(s)
PY
  build "$M/w" "$M/BackgroundMusic.lua" "$M/BiomeMood.lua";total=$((total+1))
  if runtest "$M/w";then fail "mutation $name was NOT noticed";else caught=$((caught+1));echo "ok: $name -> fails ($(grep -c '^FAIL' "$M/w/test.log") failing checks)";fi
 }
 mutate volume_back BGM "local SCENIC_VOLUME=.07" "local SCENIC_VOLUME=.055"
 mutate order_swapped BGM "SoundId='rbxassetid://74095461107598'" "SoundId='rbxassetid://XX'" "SoundId='rbxassetid://132448918728086'" "SoundId='rbxassetid://74095461107598'" "SoundId='rbxassetid://XX'" "SoundId='rbxassetid://132448918728086'"
 mutate third_track_missing BGM "{Name='Track music 132448918728086',SoundId='rbxassetid://132448918728086'}," ""
 mutate crossfade_at_the_end BGM "current.TimeLength - current.TimePosition <= PLAYLIST_CROSSFADE_SECONDS then" "current.TimeLength - current.TimePosition <= 0.05 then"
 mutate no_resume BGM "if current.IsPaused then current:Resume() else current:Play() end" "current:Play()"
 mutate failed_track_not_skipped BGM "if scenicReady[index] then return index end" "return index"
 mutate chase_does_not_silence BGM "local scenic=insideTrack and scenicTrackReady and not audible and not characterRemoving" "local scenic=insideTrack and scenicTrackReady and not characterRemoving"
 mutate not_named_for_the_mixer BGM "music.Name = 'BiomeScenicMusic'" "music.Name = 'ScenicMusic'"
 mutate other_sound_group BGM "$(printf "music.SoundGroup = peacefulGroup\n\tmusic:SetAttribute('TrackName'")" "$(printf "music.SoundGroup = chaseGroup\n\tmusic:SetAttribute('TrackName'")"
 mutate tracks_loop BGM "$(printf "music.Looped = false\n\tmusic.PlaybackSpeed = 1\n\tmusic.SoundGroup = peacefulGroup\n\tmusic:SetAttribute('TrackName'")" "$(printf "music.Looped = true\n\tmusic.PlaybackSpeed = 1\n\tmusic.SoundGroup = peacefulGroup\n\tmusic:SetAttribute('TrackName'")"
 mutate crossfade_leave_ignored BGM "elseif scenicNext then" "elseif false then"
 mutate never_paused BGM "elseif not scenicOn then" "elseif false then"
 mutate tween_every_step BGM "local function stepScenic()" "$(printf 'local function stepScenic()\n\tscenicTweens[1] = tween(scenicSounds[1], {Volume = 0}, 0.1)')"
 mutate sounds_left_on_destroy BGM "for _,sound in ipairs(scenicSounds)do sound:Destroy()end" ""
 mutate base_id_wrong BGM 'SoundId = "rbxassetid://1836280952"' 'SoundId = "rbxassetid://1836280953"'
 mutate base_volume_changed BGM "local PEACEFUL_VOLUME = 0.2 " "local PEACEFUL_VOLUME = 0.25"
 mutate ambience_gain_off MOOD "local TRACK_GAIN=1.25" "local TRACK_GAIN=1"
 mutate ambience_stage7_forgotten MOOD "t.Wind=.055*TRACK_GAIN;t.Rumble=.025*TRACK_GAIN end" "t.Wind=.055;t.Rumble=.025*TRACK_GAIN end"
 mutate ambience_base_louder MOOD "if stage==0 then t.Birds=.018;" "if stage==0 then t.Birds=.018*TRACK_GAIN;"
 mutate ambience_weather_bed_moved MOOD "Rain={Key='RainBed',Volume=.3}" "Rain={Key='RainBed',Volume=.35}"
 echo "$caught of $total breaks caught"
 [ "$caught" = "$total" ] || fail "a break was not caught"
fi
[ $RC = 0 ] && echo "R156 music: ALL PASS" || echo "R156 music: FAIL"
exit $RC
