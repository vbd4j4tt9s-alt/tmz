#!/bin/sh
# Usage: sh run_early_audio157.sh [scratch dir]      (NO_MUTATE=1 skips the teeth)
# R157b fix: the owner's Studio log after installing R157 -- "AudioMixer is not a valid member of ReplicatedStorage - InteractionAudio:36 (function pool / Preload / line 73)", then
# "Requested module experienced an error while loading" in Hotbar, ChestIndex, VerityClient, PackOpeningFeedback, GardenShovel, GamePassClient, NotificationClient83, InteractionFeedback,
# OfflineGrowthNotice, EconomyClient, FruitGiftClient, SettingsClient, DailyRewardsClient: the whole HUD dead for the session. The title runs from ReplicatedFirst before game.Loaded and required
# InteractionAudio the moment it appeared; InteractionAudio's body warmed its voices and required AudioMixer, which had not replicated; Roblox keeps a failed require, so every later require
# failed (R152 fixed the same race for SoundTiming and missed AudioMixer; AudioMixer's own require of SettingsConfig had it one level down).
#  0. static  - InteractionAudio gets AudioMixer with WaitForChild (lazily, cached) and warms its voices in a pcall'd task; AudioMixer waits for SettingsConfig; the title waits for game.Loaded
#               (the R152 guard style, pcall around IsLoaded) before it requires InteractionAudio, and (as before) before SeedPackVisuals; no top-level dot-indexed require is left in
#               InteractionAudio / AudioMixer / SoundTiming / SettingsConfig / TitleTips156; line 1 of every client script (the R152 guard) is untouched; this suite is in run_all_suites.sh;
#               no model names in the files of this round
#  1. test    - test_early_audio157.luau on the Roblox mock (/opt/luau/luau) with the REAL modules, in a ReplicatedStorage where AudioMixer / SettingsConfig arrive late and the game is not loaded
#  2. teeth   - the same test on broken copies (the old dot-indexed requires, a synchronous warm-up, no pcall, no wait in the title): each must FAIL
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;RSD=$S/ReplicatedStorage
IA=$RSD/InteractionAudio.lua;AM=$RSD/AudioMixer.lua;TS=$RSD/TitleScreen104.lua
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
grep -q "require(script.Parent:WaitForChild('AudioMixer'))" "$IA" || fail "InteractionAudio must WaitForChild('AudioMixer')"
grep -q "require(script.Parent.AudioMixer)" "$IA" && fail "InteractionAudio still indexes AudioMixer directly"
grep -q "pcall(M.Preload)" "$IA" || fail "InteractionAudio must warm its voices inside a pcall"
[ "$(grep -c "^M.Preload()" "$IA")" = 0 ] || fail "InteractionAudio must not call M.Preload() directly in its body"
echo "ok: InteractionAudio waits for AudioMixer (WaitForChild, lazily) and warms in a pcall'd task"
grep -q "require(script.Parent:WaitForChild('SettingsConfig'))" "$AM" || fail "AudioMixer must WaitForChild('SettingsConfig')"
grep -q "require(script.Parent.SettingsConfig)" "$AM" && fail "AudioMixer still indexes SettingsConfig directly"
echo "ok: AudioMixer waits for SettingsConfig"
bad=0
for m in InteractionAudio AudioMixer SoundTiming SettingsConfig TitleTips156;do
 if grep -nE "^(local [A-Za-z_0-9]+ *= *)?require\((script\.Parent|game:GetService\('ReplicatedStorage'\))\.[A-Za-z]" "$RSD/$m.lua";then fail "$m has a top-level dot-indexed require";bad=1;fi
done
[ "$bad" = 0 ] && echo "ok: no top-level dot-indexed require in InteractionAudio / AudioMixer / SoundTiming / SettingsConfig / TitleTips156"
# the title: the load guard (pcall around IsLoaded) comes before the InteractionAudio require, and the SeedPackVisuals wait is before its require
a=$(grep -n "pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end" "$TS" | head -1 | cut -d: -f1)
b=$(grep -n "RS:WaitForChild('InteractionAudio',10)" "$TS" | head -1 | cut -d: -f1)
[ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || fail "TitleScreen104: the game.Loaded guard must come before the InteractionAudio WaitForChild / require"
c=$(grep -n "if not game:IsLoaded()then game.Loaded:Wait()end" "$TS" | head -1 | cut -d: -f1)
d=$(grep -n "RS:WaitForChild('SeedPackVisuals',10)" "$TS" | head -1 | cut -d: -f1)
[ -n "$c" ] && [ -n "$d" ] && [ "$c" -lt "$d" ] || fail "TitleScreen104: the SeedPackVisuals preview must wait for game.Loaded before it requires SeedPackVisuals"
echo "ok: TitleScreen104 waits for game.Loaded before it requires InteractionAudio (line $a before $b) and, as before, SeedPackVisuals (line $c before $d)"
F=$S/ReplicatedFirst/TitleScreen.client.lua
grep -q "game:IsLoaded\|game.Loaded" "$F" && fail "TitleScreen.client.lua (ReplicatedFirst) must not wait for game.Loaded: it covers the loading"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: $(tail -2 "$OUT/guard.log" | head -1) (line 1 of every client script is still the R152 guard)" || { fail "the R152 load guard test fails";tail -5 "$OUT/guard.log"; }
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R157/tests/run_early_audio157.sh[; ]" || fail "run_early_audio157.sh is not on line 6 of tools/tests/run_all_suites.sh"
echo "ok: registered on line 6 of run_all_suites.sh"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|\b(op[u]s|sonn[e]t|haik[u]|gemin[i]|llam[a])\b|gp[t]-?[0-9]" "$HERE/run_early_audio157.sh" "$HERE/test_early_audio157.luau" "$IA" "$AM" "$TS" 2>/dev/null | grep -q .;then fail "a model name in the files of this round";else echo "ok: no model names in the files of this round";fi
# the test ----------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir [InteractionAudio file] [AudioMixer file] [TitleScreen104 file]
 d=$1;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R150/tests/sfx_env.luau" "$HERE/test_early_audio157.luau" "$d/"
 python3 "$P/R150/tests/mkbundle.py" "$d" InteractionAudio="${2:-$IA}" AudioMixer="${3:-$AM}" TitleScreen104="${4:-$TS}" > /dev/null
}
runtest(){ ( cd "$1" && timeout 600 /opt/luau/luau test_early_audio157.luau > test.log 2>&1 ); }
echo "== 1. test_early_audio157"
build "$OUT/w"
if runtest "$OUT/w";then grep -v '^WARN' "$OUT/w/test.log" | tail -8;else grep -v '^WARN' "$OUT/w/test.log" | tail -30;fail "test_early_audio157";fi
# teeth -------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 2. teeth: each break must make the test fail"
 M=$OUT/mut;mkdir -p "$M";caught=0;total=0
 mutate(){ # name which(IA|AM|TS) old new [old2 new2 ...]
  name=$1;which=$2;shift 2
  cp "$IA" "$M/InteractionAudio.lua";cp "$AM" "$M/AudioMixer.lua";cp "$TS" "$M/TitleScreen104.lua"
  case $which in IA) target=$M/InteractionAudio.lua;; AM) target=$M/AudioMixer.lua;; *) target=$M/TitleScreen104.lua;; esac
  python3 - "$target" "$@" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f = sys.argv[1]; rest = sys.argv[2:]; pairs = list(zip(rest[0::2], rest[1::2]))
s = open(f, encoding='utf-8').read()
for old, new in pairs:
    assert s.count(old) == 1, old
    s = s.replace(old, new, 1)
open(f, 'w', encoding='utf-8').write(s)
PY
  build "$M/w" "$M/InteractionAudio.lua" "$M/AudioMixer.lua" "$M/TitleScreen104.lua";total=$((total+1))
  if runtest "$M/w";then fail "mutation $name was NOT noticed";else caught=$((caught+1));echo "ok: $name -> fails ($(grep -c '^FAIL' "$M/w/test.log") failing checks)";fi
 }
 # the code before this fix, restored in full (the owner's crash): the dot-indexed require inside pool() and the warm-up run by the module body
 mutate the_old_code_restored IA " local mix=Mixer() -- (R157b fix: first, so a wait for AudioMixer never leaves a half-built pool behind)
" "" "  mix.Route(voice,'Interface')" "  require(script.Parent.AudioMixer).Route(voice,'Interface')" "task.spawn(function()local ok,why=pcall(M.Preload);if not ok then warn('[InteractionAudio] preload: '..tostring(why))end end)" "M.Preload()"
 mutate interaction_audio_dot_indexes_mixer IA "mixer=require(script.Parent:WaitForChild('AudioMixer'))" "mixer=require(script.Parent.AudioMixer)"
 mutate audio_mixer_dot_indexes_config AM "require(script.Parent:WaitForChild('SettingsConfig'))" "require(script.Parent.SettingsConfig)"
 mutate warm_up_runs_in_the_require IA "task.spawn(function()local ok,why=pcall(M.Preload);if not ok then warn('[InteractionAudio] preload: '..tostring(why))end end)" "M.Preload()"
 mutate warm_up_without_pcall IA "task.spawn(function()local ok,why=pcall(M.Preload);if not ok then warn('[InteractionAudio] preload: '..tostring(why))end end)" "task.spawn(M.Preload)"
 mutate mixer_fetched_inside_the_voice_loop IA " local mix=Mixer() -- (R157b fix: first, so a wait for AudioMixer never leaves a half-built pool behind)
" "" "  mix.Route(voice,'Interface')" "  Mixer().Route(voice,'Interface')"
 mutate title_does_not_wait_for_loaded TS "do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end
  if dead then return end
  local module=RS:WaitForChild('InteractionAudio',10)" "local module=RS:WaitForChild('InteractionAudio',10)"
 mutate title_waits_but_loads_when_closed TS "game.Loaded:Wait()end end
  if dead then return end
  local module=RS:WaitForChild('InteractionAudio',10)" "game.Loaded:Wait()end end
  local module=RS:WaitForChild('InteractionAudio',10)"
 mutate title_guard_without_pcall TS "do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end
  if dead" "if not game:IsLoaded()then game.Loaded:Wait()end
  if dead"
 mutate title_preview_does_not_wait TS "    if not game:IsLoaded()then game.Loaded:Wait()end
    if dead then return end
    local module=RS:WaitForChild('SeedPackVisuals',10)" "    local module=RS:WaitForChild('SeedPackVisuals',10)"
 echo "$caught of $total breaks caught"
 [ "$caught" = "$total" ] || fail "a break was not caught"
fi
[ $RC = 0 ] && echo "R157 early audio: ALL PASS" || echo "R157 early audio: FAIL"
exit $RC
