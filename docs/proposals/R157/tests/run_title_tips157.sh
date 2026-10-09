#!/bin/sh
# Usage: sh run_title_tips157.sh [scratch dir]      (NO_MUTATE=1 skips the teeth)
# R157: the title screen's rotating "tip:" line (the owner-approved R156 title_tips.md round 2). On the Roblox mock (/opt/luau/luau) with the REAL TitleScreen104 and TitleTips156 of this checkout:
#  0. static  - every script in src/ compiles at -O0 within 180 registers per function (check_compile_O0.sh); the 24 tips are one line each and are exactly the R156 title_tips.md tables (text,
#               highlighted words, kind); TitleTips156 is in ReplicatedStorage with a MANIFEST row; the title requires it with WaitForChild + pcall like its other modules; TitleScreen.client.lua
#               (ReplicatedFirst: it covers the loading, so it has no R152 load guard and must not wait for the game) is as it was; the R152 load guard test still passes; this suite is in
#               run_all_suites.sh; no model names in the files of this round
#  1. test    - test_title_tips157.luau: the list and its markup, the RichText, the order, the 10 s rotation, the fade / pulse / bob numbers, Reduced Motion, the layout at six (and six more) screen
#               sizes (centred, gap >= line + 20 px, no overlap with the logo / pack / button), no input, nothing allocated per frame, a missing / broken / late list
#  2. teeth   - the same test on broken copies of the two modules (each must FAIL)
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;RSD=$S/ReplicatedStorage;TS=$RSD/TitleScreen104.lua;TIPS=$RSD/TitleTips156.lua
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/compile.log" 2>&1 && echo "ok: $(tail -2 "$OUT/compile.log" | head -1)" || { fail "check_compile_O0.sh";tail -8 "$OUT/compile.log"; }
python3 - "$REPO" > "$OUT/tips.log" 2>&1 <<'PY' && echo "ok: $(cat "$OUT/tips.log")" || { fail "the tips";cat "$OUT/tips.log"; }
import re, sys
repo = sys.argv[1]
src = open(repo + '/src/ReplicatedStorage/TitleTips156.lua', encoding='utf-8').read()
md = open(repo + '/docs/proposals/R156/title_tips.md', encoding='utf-8').read()
bad = []
# one line per tip: every line of the list is one {Kind=...,Text=...} entry
body = src[src.index('T.Tips={') + len('T.Tips={'):]
body = body[:body.index('\n}\n')]
entries = [l for l in body.split('\n') if l.strip()]
tips = []
for l in entries:
    m = re.fullmatch(r" \{Kind='(howto|lore|egg)',Text='((?:[^'\\]|\\.)*)'\},(?: --.*)?", l)
    if not m:
        bad.append('not a one-line tip: ' + l[:60]); continue
    tips.append((m.group(1), m.group(2).replace("\\'", "'")))
rows = {}
for m in re.finditer(r'^\| (\d+) \| (.+?) \| (.+?) \| ', md, re.M):
    rows[int(m.group(1))] = (m.group(2).strip(), m.group(3).strip())
if len(tips) != 24 or sorted(rows) != list(range(1, 25)):
    bad.append('%d tips in the list, rows %s in the .md' % (len(tips), sorted(rows)))
for i, (kind, text) in enumerate(tips, 1):
    if i not in rows:
        continue
    plain = re.sub(r'\{/?[yg]\}', '', text)
    words = re.findall(r'\{([yg])\}(.*?)\{/\1\}', text)
    cell = [(m.group(1), m.group(2).strip()) for m in re.finditer(r'\{([yg])\}\s*(.+?)\s*(?=,\s*\{[yg]\}|$)', rows[i][1])]
    if plain != rows[i][0]:
        bad.append('tip %d text: %r vs the .md %r' % (i, plain, rows[i][0]))
    if words != cell:
        bad.append('tip %d highlighted words: %r vs the .md %r' % (i, words, cell))
    if kind != ('howto' if i <= 19 else 'lore' if i <= 23 else 'egg'):
        bad.append('tip %d kind %s' % (i, kind))
if bad:
    print('\n'.join(bad)); sys.exit(1)
print('the 24 tips are one line each and exactly the R156 title_tips.md tables (text, highlighted words, kind)')
PY
grep -q "$(printf 'ModuleScript\tReplicatedStorage/TitleTips156\tReplicatedStorage/TitleTips156.lua')" "$S/MANIFEST.tsv" && [ -f "$TIPS" ] || fail "TitleTips156 has no row in src/MANIFEST.tsv (or no file)"
[ "$(grep -c "$(printf '\tReplicatedStorage/TitleTips156\t')" "$S/MANIFEST.tsv")" = 1 ] || fail "TitleTips156 must have exactly one MANIFEST row"
echo "ok: src/ReplicatedStorage/TitleTips156.lua has its MANIFEST row"
grep -q "pcall(function()return require(RS:WaitForChild('TitleTips156',10))end)" "$TS" || fail "TitleScreen104 must load TitleTips156 with WaitForChild + pcall"
echo "ok: TitleScreen104 loads TitleTips156 with WaitForChild(10) + pcall inside task.spawn (like its InteractionAudio and SeedPackVisuals), so a missing list never blocks the title"
F=$S/ReplicatedFirst/TitleScreen.client.lua
head -1 "$F" | grep -q "^-- R104. One title sequence per connection" || fail "TitleScreen.client.lua: line 1 changed (it has no load guard: it runs before the game loads and covers the loading)"
grep -q "R152: start once the whole game has arrived" "$F" && fail "TitleScreen.client.lua must not carry the R152 load guard (it would hold the title back until the game has loaded)"
grep -q "WaitForChild('TitleScreen104',20)" "$F" || fail "TitleScreen.client.lua must wait for TitleScreen104 in ReplicatedStorage (WaitForChild, 20 s)"
grep -q "game:IsLoaded\|game.Loaded" "$F" && fail "TitleScreen.client.lua must not wait for game.Loaded"
echo "ok: TitleScreen.client.lua (ReplicatedFirst) has no load guard and waits for its module with WaitForChild(20), as it did"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: $(tail -2 "$OUT/guard.log" | head -1)" || { fail "the R152 load guard test fails";tail -5 "$OUT/guard.log"; }
sed -n 6p "$T/run_all_suites.sh" | grep -q "docs/proposals/R157/tests/run_title_tips157.sh; do$" || fail "run_title_tips157.sh is not at the end of line 6 of tools/tests/run_all_suites.sh"
echo "ok: registered at the end of line 6 of run_all_suites.sh"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|\b(op[u]s|sonn[e]t|haik[u]|gemin[i]|llam[a])\b|gp[t]-?[0-9]" "$HERE" "$P/R157/title_tips157.md" "$P/R157/preview" "$TS" "$TIPS" 2>/dev/null | grep -q .;then fail "a model name in the files of this round";else echo "ok: no model names in the files of this round";fi
# the test ----------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir [TitleScreen104 file] [TitleTips156 file]
 d=$1;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE/test_title_tips157.luau" "$d/"
 python3 "$P/R150/tests/mkbundle.py" "$d" TitleScreen104="${2:-$TS}" TitleTips156="${3:-$TIPS}" > /dev/null
}
runtest(){ ( cd "$1" && timeout 600 /opt/luau/luau test_title_tips157.luau > test.log 2>&1 ); }
echo "== 1. test_title_tips157"
build "$OUT/w"
if runtest "$OUT/w";then grep -v '^WARN' "$OUT/w/test.log" | sed -n '/^   [0-9]/p;$p';else grep -v '^WARN' "$OUT/w/test.log" | tail -30;fail "test_title_tips157";fi
# teeth -------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 2. teeth: each break must make the test fail"
 M=$OUT/mut;mkdir -p "$M";caught=0;total=0
 mutate(){ # name which(TITLE|TIPS) old new [old2 new2 ...]
  name=$1;which=$2;shift 2
  cp "$TS" "$M/TitleScreen104.lua";cp "$TIPS" "$M/TitleTips156.lua"
  if [ "$which" = TITLE ];then target=$M/TitleScreen104.lua;else target=$M/TitleTips156.lua;fi
  python3 - "$target" "$@" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f = sys.argv[1]; rest = sys.argv[2:]; pairs = list(zip(rest[0::2], rest[1::2]))
s = open(f, encoding='utf-8').read()
for old, new in pairs:
    assert s.count(old) == 1, old
    s = s.replace(old, new, 1)
open(f, 'w', encoding='utf-8').write(s)
PY
  build "$M/w" "$M/TitleScreen104.lua" "$M/TitleTips156.lua";total=$((total+1))
  if runtest "$M/w";then fail "mutation $name was NOT noticed";else caught=$((caught+1));echo "ok: $name -> fails ($(grep -c '^FAIL' "$M/w/test.log") failing checks)";fi
 }
 mutate interval_9s TIPS "T={Interval=10," "T={Interval=9,"
 mutate fade_slower TIPS "Fade=.4," "Fade=.3,"
 mutate pulse_bigger TIPS "PulseAmount=.05,PulsePeriod=.5," "PulseAmount=.08,PulsePeriod=.5,"
 mutate pulse_slower TIPS "PulsePeriod=.5," "PulsePeriod=.6,"
 mutate bob_bigger TIPS "BobPixels=1.5," "BobPixels=3,"
 mutate bob_period TIPS "BobPeriod=1.9," "BobPeriod=2.5,"
 mutate yellow_changed TIPS "y='#FFE14D'" "y='#FFE14E'"
 mutate green_changed TIPS "g='#77E542'" "g='#77E543'"
 mutate a_tip_reworded TIPS "dont look into the {y}pyramid{/y}" "don\\'t look into the {y}pyramid{/y}"
 mutate a_tip_u_for_you TIPS "hit thieves with your {y}bat{/y}" "hit thieves with ur {y}bat{/y}"
 mutate a_tip_missing TIPS " {Kind='lore',Text='beware {y}the darkened{/y}'},
" ""
 mutate a_highlight_unclosed TIPS "hold {y}E{/y} to" "hold {y}E to"
 mutate no_escape TIPS "text=text:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')" "text=text"
 mutate shuffle_duplicates TIPS "order[i],order[j]=order[j],order[i] end" "order[i]=order[j] end"
 mutate shuffle_off TIPS "local j=random:NextInteger(1,i);order[i]" "local j=i;order[i]"
 mutate avoid_ignored TIPS "if avoid and order[1]==avoid and #T.Tips>1 then order[1],order[2]=order[2],order[1] end" ""
 mutate no_fade_out TITLE "(tips.Interval-tipClock)/tips.Fade)" "99)"
 mutate fade_in_slow TITLE "math.min(1,tipClock/tips.Fade," "math.min(1,tipClock/(tips.Fade*2),"
 mutate pulse_too_big TITLE "1+tips.PulseAmount*math.sin(" "1+tips.PulseAmount*1.6*math.sin("
 mutate pulse_slow TITLE "pulseClock*math.pi*2/tips.PulsePeriod)" "pulseClock*math.pi*2/(tips.PulsePeriod*1.2))"
 mutate no_bob TITLE "tipLabel.Position=tipBob[step]end" "tipLabel.Position=tipRest end"
 mutate reduced_still_pulses TITLE "   if reduced then
    tipScale.Scale=1" "   if false then
    tipScale.Scale=1"
 mutate reduced_still_fades TITLE "local alpha=reduced and 1 or math.min(" "local alpha=math.min("
 mutate bob_builds_a_udim2 TITLE "tipLabel.Position=tipBob[step]" "tipLabel.Position=UDim2.fromOffset(tipRest.X.Offset,tipRest.Y.Offset+tips.BobPixels*math.sin(pulseClock*math.pi*2/tips.BobPeriod))"
 mutate takes_the_click TITLE "Active=false,Interactable=false,Selectable=false" "Active=true,Interactable=false,Selectable=false"
 mutate interactable TITLE "Active=false,Interactable=false,Selectable=false" "Active=false,Interactable=true,Selectable=false"
 mutate runs_while_leaving TITLE "if tipLabel and phase~='Leaving'then stepTip(dt,reduced)end" "if tipLabel then stepTip(dt,reduced)end"
 mutate no_reshuffle TITLE "tipIndex=1;tips.Order(tipRandom,tipOrder,tipOrder[#tipOrder])" "tipIndex=1;"
 mutate gap_too_small TITLE "local tipGap=tipHeight+20" "local tipGap=tipHeight+6"
 mutate not_centred TITLE "TipY=(logoY+logoHeight/2+buttonTop)/2" "TipY=(logoY+logoHeight/2)*.4+buttonTop*.6"
 mutate logo_not_smaller TITLE "-26-tipGap)*1.7768)" "-50)*1.7768)"
 mutate list_not_checked TITLE "assert(type(list[key])=='number'and list[key]==list[key],'Tips.'..key)" "local _=list[key]"
 mutate starts_visible TITLE "TextTransparency=1,Active=false" "TextTransparency=0,Active=false"
 mutate outline_colour TITLE "Color=RGB(23,37,16),LineJoinMode=Enum.LineJoinMode.Round,Transparency=1" "Color=RGB(0,0,0),LineJoinMode=Enum.LineJoinMode.Round,Transparency=1"
 mutate text_size_cap TITLE "MaxTextSize=layout.TipSize" "MaxTextSize=40"
 mutate resize_ignored TITLE "    tipLabel.Size=UDim2.fromOffset(layout.TipWidth,layout.TipHeight)
" ""
 echo "$caught of $total breaks caught"
 [ "$caught" = "$total" ] || fail "a break was not caught"
fi
[ $RC = 0 ] && echo "R157 title tips: ALL PASS" || echo "R157 title tips: FAIL"
exit $RC
