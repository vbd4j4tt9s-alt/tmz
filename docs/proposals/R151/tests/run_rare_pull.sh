#!/bin/sh
# Usage: sh run_rare_pull.sh [scratch dir] [only|all]. R151 pull reveals on the Roblox mock (/opt/luau/luau) with the REAL modules / scripts of
# this checkout (docs/proposals/R151/rare_pull.md):
#  test_rare_rules.luau      - RarePullRules: every tier's timeline (story scenes Full / Calm / InPlace, the Common..Mythic ladder, quick
#                              reveals), the suspense hint colours, wobble and tear, the server timeline unchanged, framing of the seed in
#                              every climax / end frame (desktop, phone, tablet), the safety rule, odds, layout, the cue sheets.
#  test_rare_cinematic.luau  - RarePullCinematic + RarePullScenes + RarePullCard + RarePullAudio: each story scene played through (camera,
#                              HUD, Core GUI, controls, colour grade, stage, sounds), restoration after the normal end / skip / error /
#                              death / character removed / being moved / a keeper / a replaced camera / the script destroyed, ReducedMotion
#                              and phone variants, the in-place version when unsafe, part budgets, no per-frame work after the end, the
#                              Common..Mythic seed card and quick reveals, the owner previews, the sound slots (owner ids drop in).
#  test_rare_world.luau      - the real SeedPackClient + PackOpeningFeedback: the pack's suspense in the world for every tier (wobble,
#                              bit-by-bit tear, hint glow), the seed's new timing, the light pillar and afterglow aura onlookers see
#                              (Secret+ only), its lifetime and LOD, onlookers never get the story scene, the opener's reveal starts the
#                              right presentation, the R150 onlooker impact still once.
# "all" (default) also runs the existing reveal suites: R136, R137, R138, R148 purchase, R147 Verity UI, R149 Verity pack, audio_R123,
# borders_R123 and R150 run_sfx.sh / run_bonus_ui.sh.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=${2:-all};mkdir -p "$OUT/cl"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src
echo "== static checks"
bad=0;for f in $(find "$S" -name '*.lua');do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
[ "$bad" = 0 ];echo "ok: every script in src/ compiles"
python3 - "$S" <<'PY'
import sys,os
src=sys.argv[1];rows=open(os.path.join(src,'MANIFEST.tsv')).read().splitlines()[1:]
files={r.split('\t')[2] for r in rows}
need=['ReplicatedStorage/'+n+'.lua' for n in ('PackSuspense','RarePullAudio','RarePullCard','RarePullCinematic','RarePullRules','RarePullScenes','RarePullSounds','RarePullWorld')]+['ServerScriptService/ChestChaseServer/RarePullTestCommands.lua']
missing=[n for n in need if n not in files or not os.path.exists(os.path.join(src,n))]
assert not missing,'MANIFEST / files missing: %s'%missing
assert rows==sorted(rows,key=lambda l:l.split('\t')[1]),'MANIFEST not sorted'
print('ok: the 9 new scripts are in src/MANIFEST.tsv (sorted)')
PY
# no new uploads: every asset id the reveal sounds use already exists elsewhere in the game
python3 - "$S" <<'PY'
import sys,os,re
src=sys.argv[1]
mine=open(os.path.join(src,'ReplicatedStorage/RarePullAudio.lua')).read()
ids=set(re.findall(r"rbxassetid://(\d+)",mine))
other=''
for d,_,fs in os.walk(src):
  for f in fs:
    if f.endswith('.lua') and f not in('RarePullAudio.lua','RarePullSounds.lua'):other+=open(os.path.join(d,f),encoding='utf-8').read()
new=[i for i in ids if i not in other]
assert not new,'sound ids not used anywhere else in the game: %s'%new
sl=open(os.path.join(src,'ReplicatedStorage/RarePullSounds.lua')).read()
owner=set(re.findall(r"Id=(\d+)",sl))
confirmed={'126242461105018','133616032782359','100663216159686','130581466623902','115669680103388','103090716252123','104885054288395','120422004598250',
 '71607900050825','77199097157197','110440649150958','120548831466483','119158277815268','75435110351652','100732233406279'} # the owner's uploads: 8 shared + 3 King + 4 Cosmic
assert owner==confirmed,'slot ids are not exactly the owner\'s confirmed uploads: %s'%sorted(owner)
print('ok: the fallback sounds use only the game\'s existing sounds (%d ids); the slots carry exactly the owner\'s 15 confirmed uploads (8 shared, 3 King, 4 Cosmic)'%len(ids))
PY
# Lighting is never written by the reveal (its grade / blur live on the Camera)
if grep -nE "Lighting\.|GetService\('Lighting'\)|GetService\(\"Lighting\"\)" "$S/ReplicatedStorage/RarePullCinematic.lua" "$S/ReplicatedStorage/RarePullCard.lua" "$S/ReplicatedStorage/RarePullScenes.lua" "$S/ReplicatedStorage/RarePullWorld.lua" "$S/ReplicatedStorage/PackSuspense.lua";then echo "FAIL: a reveal module touches Lighting";exit 1;fi
echo "ok: no reveal module touches Lighting"
INV=$P/inventory_R113/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE"/*.luau "$OUT/cl/"
python3 "$HERE/mkbundle_rare.py" "$OUT/cl" all-client >/dev/null
cd "$OUT/cl"
for t in test_rare_rules test_rare_cinematic test_rare_world;do
 [ -f $t.luau ] || continue
 echo "== $t"
 timeout 900 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;exit 1; }
 grep -v '^WARN' $t.log | tail -1
done
if [ "$MODE" = "all" ];then
 for r in R136/tests/run.sh R137/tests/run.sh R138/tests/run.sh R148/tests/run_purchase.sh R147/tests/run_verity_ui.sh R149/tests/run_verity_pack.sh \
  audio_R123/tests/run.sh borders_R123/tests/run.sh R150/tests/run_sfx.sh R150/tests/run_bonus_ui.sh;do
  echo "######## $r";sh "$P/$r" "$OUT/$(echo $r | tr '/' '_')" 2>&1 | grep -v '^ok:' | tail -12
 done
fi
echo "R151 pull reveal suites passed"
