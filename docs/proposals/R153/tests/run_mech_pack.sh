#!/bin/sh
# Usage: sh run_mech_pack.sh [scratch dir]
# R153 Mech pack, look B "Circuit Mech" + its opening touch (docs/proposals/R153/mech_pack.md; the owner picked look B and the full opening), on the Roblox mock
# (/opt/luau/luau) with the REAL modules / client scripts of this checkout:
#  0. static              every script compiles; the hooks in the shared client scripts are one line each and read the reveal's beats (no timing code
#                         touched); no value change (the Mech odds / offers, bought packs uncoated); no model names in the R153 Mech files
#  1. test_mech_pack153    the art: part count, no Forest_01 print (the flat neutral pouch / the plain-parts body), both faces, the bolts / antenna / LED / hazard
#                         seal / MECH plate / traces / reactor, every context, held (welds, servos, the fx as Attachments, no per-frame writes, no scanner), shapes,
#                         bounds, the shop banner, the rig
#     + check_packs.py     on its SCENE lines (R151's geometry check): no floating part, no z-fighting, on the pouch and on the plain-parts body, held, .5x / 25x
#  2. test_mech_opening153 the opening: clicks 1-4 (bolts + tick), the scan / glow on the pulses, steam + hiss on the tear groups, the ring + spin-down on the
#                         burst, at 30 / 60 fps, every tier; voices and loudness caps; calm; onlooker; skip; clean-up on close / death / script end
#  3. z-fighting          R152's sweep, its Mech step (check_zfight_sweep.py mech): the pack on the flat pouch in every context / size / coat, its opening copy,
#                         its plain-parts body
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;INV=$P/inventory_R113/tests;S=$REPO/src;R151=$P/R151/tests;R152=$P/R152/tests
LUAU=${LUAU:-/opt/luau/luau}
echo "== 0. static"
bad=0;for f in $(find "$S" -name '*.lua');do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
[ "$bad" = 0 ];echo "ok: every script in src/ compiles"
SP=$S/StarterPlayer/StarterPlayerScripts
[ "$(grep -c 'MechPackFx153' "$SP/SeedPackClient.client.lua")" = 1 ] && [ "$(grep -c 'record.Mech' "$SP/SeedPackClient.client.lua")" = 3 ] || { echo "FAIL: SeedPackClient: the Mech touch must be one create line, one update line and one destroy line";exit 1; }
[ "$(grep -c 'MechPackFx153' "$SP/PackOpeningFeedback.client.lua")" = 1 ] && [ "$(grep -c 'mech()' "$SP/PackOpeningFeedback.client.lua")" = 3 ] || { echo "FAIL: PackOpeningFeedback: the Mech clicks must be the one loader line + one line in the click and one in the shake";exit 1; }
[ "$(grep -c 'MechMotion:Live' "$SP/SeedPackRender.client.lua")" = 2 ] || { echo "FAIL: SeedPackRender: the held fx must be switched by two lines (on when detailed, off when discarded)";exit 1; }
if grep -n "BurstAt\s*=\|TearGroups\s*=\|Pulses\s*=\|function L\.\|Ladder\.[A-Za-z]*\s*=" "$S/ReplicatedStorage/MechPackFx153.lua" | grep -v "^[0-9]*:--" | grep -v "local burst\|BurstAt=burst\|Pulses=Ladder.Pulses"; then echo "FAIL: MechPackFx153 must only READ the reveal's beats";exit 1;fi
echo "ok: the shared hooks are one line each (SeedPackClient 3, PackOpeningFeedback 1 + 2, SeedPackRender 2) and MechPackFx153 only reads the beats"
python3 - "$S" <<'PY' || exit 1
import re, sys
src = sys.argv[1]
cat = open(src + '/ReplicatedStorage/MechCatalog.lua', encoding='utf-8').read()
chances = [float(x) for x in re.findall(r'Chance=([0-9.]+)', cat)]
offers = re.findall(r'\{Count=(\d+),GemPrice=(\d+),TargetRobuxPrice=(\d+)', cat)
prem = open(src + '/ServerScriptService/ChestChaseServer/PremiumProgress.lua', encoding='utf-8').read()
# R155 (owner: "We can implement 1C"): a BOUGHT Mech pack rolls the world packs' coat (P.RollCoat); a free one (paid == false) stays plain. The odds and the offers did not move.
ok = chances == [48, 26, 16, 7, 2.5, 0.5] and offers == [('1', '80', '80'), ('5', '375', '375'), ('10', '700', '700')] and "BagVariant=Catalog.Variant,PackSize=PackRules.RollPackSize(SizeRandom:NextNumber()),PackMutation=paid==true and P.RollCoat()or'None'" in prem
print(('ok' if ok else 'FAIL') + ': no odds / price change: the Mech odds %s, the offers %s; bought Mech packs roll a coat (R155), free ones stay plain (pity and Config.Version: the R151 frozen hashes)' % (chances, offers))
sys.exit(0 if ok else 1)
PY
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE"/*mech* "$HERE"/run_mech_pack.sh "$P/R153/mech_pack" "$S/ReplicatedStorage/MechPackArt153.lua" "$S/ReplicatedStorage/MechPackFx153.lua" 2>/dev/null | grep -v "^Binary";then echo "FAIL: a model name in the R153 Mech files";exit 1;fi
echo "ok: no model names in the R153 Mech files"
echo "== 1. the art (test_mech_pack153) + geometry (check_packs.py)"
mkdir -p "$OUT/art"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$HERE/test_mech_pack153.luau" "$OUT/art/"
python3 "$R151/mkbundle_packs.py" "$OUT/art" "$S" >/dev/null
(cd "$OUT/art" && timeout 900 $LUAU test_mech_pack153.luau > test.log 2>&1) || { grep -v '^WARN\|^SCENE' "$OUT/art/test.log" | tail -40;exit 1; }
grep -v '^WARN\|^SCENE' "$OUT/art/test.log" | tail -4
grep '^SCENE ' "$OUT/art/test.log" > "$OUT/art/scenes.txt"
python3 "$R151/check_packs.py" "$OUT/art/scenes.txt"
echo "== 2. the opening (test_mech_opening153)"
mkdir -p "$OUT/open"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$R151/rare_env.luau" "$R152/rare152_env.luau" "$R152/sound_levels.luau" "$HERE/test_mech_opening153.luau" "$OUT/open/"
python3 "$R151/mkbundle_rare.py" "$OUT/open" all-client >/dev/null
(cd "$OUT/open" && timeout 1800 $LUAU test_mech_opening153.luau > test.log 2>&1) || { grep -v '^WARN' "$OUT/open/test.log" | tail -40;exit 1; }
grep -v '^WARN' "$OUT/open/test.log" | tail -3
echo "== 3. z-fighting (R152 sweep, the Mech step)"
mkdir -p "$OUT/z"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$P/R149/tests/zfight_world.luau" "$HERE/dump_mech_zscene.luau" "$OUT/z/"
python3 "$R151/mkbundle_packs.py" "$OUT/z" "$S" >/dev/null
(cd "$OUT/z" && timeout 900 $LUAU dump_mech_zscene.luau > dump.txt 2> dump.err) || { tail -20 "$OUT/z/dump.err";exit 1; }
python3 "$R152/check_zfight_sweep.py" mech "$OUT/z/dump.txt"
echo "R153 Mech pack suites passed"
