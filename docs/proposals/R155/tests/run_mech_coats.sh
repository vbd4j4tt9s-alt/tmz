#!/bin/sh
# Usage: sh run_mech_coats.sh [scratch dir]      (STEPS="0 1 2 3 4 5" picks the steps; mutate_mech_coats.py runs broken copies of src through it)
# R155 Mech pack coats (owner: "We can implement 1C", docs/proposals/R153/mech_pack.md section 2) and the limited event's end (owner: the Mech card's "LIMITED TIME!" gets a real end, like
# Verity's event), on the Roblox mock (/opt/luau/luau) with the REAL modules / client scripts of this checkout:
#  0. static           every script compiles; the roll lives in PremiumProgress:GrantMechPacks only (bought packs; a free pack is plain); the world constants and the Mech odds / prices did not move;
#                      ProfileVersion 22 and Config.Version are the release's; the receipt path never asks the sale; the coat line has one source; the shared hooks are one line each
#  1. server           test_mech_coats_server: the purchase roll (rates, independence, free / test packs plain), the saved field, the reveal, the plant / fruit x3 / x6 at 20%, the notice, the
#                      event's end (sale switch, gem purchase refused with nothing charged, Robux prompt refused, a late receipt granted, owned packs open), the hold tooltip's coat line
#  2. shop             test_mech_coats_shop: the real GamePassClient: the coat line, the live countdown (ticks, stops when shut), the end (EVENT OVER!, buttons off, nothing sent)
#  3. art              test_mech_coats_art: a Gold / Diamond Mech pack in every context is a world pack's coat on the pouch and the structure, with the lit parts and hazard stripes kept; the
#                      hotbar picture key; the rig; the seed / plant / fruit looks
#  4. opening          the R153 opening suite (167 checks) run on a Gold and on a Diamond Mech pack (make_opening_coat.py), plus: the seed the real SeedPackClient reveals keeps the coat
#  5. z-fighting       R153's dump_mech_zscene (now also the opening frames and the plain-parts body in both coats) through R152's sweep step
# mutate_mech_coats.py: broken copies of src must each make a suite fail (the checks have teeth).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};STEPS=${STEPS:-"0 1 2 3 4 5"};mkdir -p "$OUT"
step(){ case " $STEPS " in *" $1 "*) return 0;; esac;return 1; }
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;INV=$P/inventory_R113/tests;R151=$P/R151/tests;R152=$P/R152/tests;R153=$P/R153/tests;TB=$P/treadmill_bonus_R123/tests
SS=$S/ServerScriptService/ChestChaseServer;RSD=$S/ReplicatedStorage;SP=$S/StarterPlayer/StarterPlayerScripts
LUAU=${LUAU:-/opt/luau/luau}
SRC=$S
if step 0;then
echo "== 0. static"
bad=0;for f in $(find "$SRC" -name '*.lua');do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
[ "$bad" = 0 ];echo "ok: every script in src/ compiles"
python3 - "$SRC" <<'PY' || exit 1
import re, sys
src = sys.argv[1]
def rd(p): return open(src + '/' + p, encoding='utf-8').read()
prem = rd('ServerScriptService/ChestChaseServer/PremiumProgress.lua')
svc = rd('ServerScriptService/ChestChaseServer/PremiumService.lua')
cat = rd('ReplicatedStorage/MechCatalog.lua')
rules = rd('ReplicatedStorage/SeedPackRules.lua')
balance = rd('ReplicatedStorage/BalanceRules.lua')
config = rd('ServerScriptService/ChestChaseServer/Config.lua')
fail = []
def need(ok, msg):
    if not ok: fail.append(msg)
# 1. the roll: one draw per pack, bought packs only, the world's own RollMutation, in the record's existing field
need("PackMutation=paid==true and P.RollCoat()or'None'" in prem, "GrantMechPacks must draw ONE coat per pack, only when paid == true (a free pack stays plain)")
need("function P.RollCoat()return PackRules.RollMutation(CoatRandom:NextNumber())end" in prem, "P.RollCoat must be the world packs' RollMutation on its own Random")
need(len(re.findall(r"RollMutation\(", prem)) == 1, "PremiumProgress must roll coats in one place")
for f in ('DailyProgress', 'RarePackTests', 'MysteryPackService', 'TreadmillBonusService', 'TutorialProgress'):
    t = rd('ServerScriptService/ChestChaseServer/%s.lua' % f)
    need('RollCoat' not in t and 'RollMutation' not in t, "%s must not roll coats (free and test packs stay plain)" % f)
rpt = rd('ServerScriptService/ChestChaseServer/RarePackTests.lua')
need("PackMutation=Packs.MutationKey(coat),TestGrant=true" in rpt and 'function T.Grant(data,player,selector,requester,coat)' in rpt and 'RollMutation' not in rpt, "/test rarepacks packs are plain unless the owner names a coat (never rolled)")
std = rd('ServerScriptService/ChestChaseServer/StudioTestCommands.lua')
need("Use /test rarepacks [rarity] [gold|diamond]." in std and "Grant(data,player,a[1],requester,coat)" in std and 'RollMutation' not in std, "/test rarepacks takes an optional gold / diamond and refuses another word")
# 2. the world's numbers did not move; the odds / prices / saved shape did not move
need("None={Weight=95}" in rules and "Gold={Weight=4.5," in rules and "Diamond={Weight=.5," in rules, "SeedPackRules.PackMutations must still be None 95 / Gold 4.5 / Diamond .5")
need("B.MutationWeights={None=95,Gold=4.5,Diamond=.5}" in balance and "B.MutationInheritance=.20" in balance and "B.MutationMultipliers={Gold=3,Diamond=6}" in balance, "BalanceRules coat constants moved")
chances = [float(x) for x in re.findall(r'Chance=([0-9.]+)', cat)]
offers = re.findall(r'\{Count=(\d+),GemPrice=(\d+),TargetRobuxPrice=(\d+)', cat)
need(chances == [48, 26, 16, 7, 2.5, 0.5] and offers == [('1', '80', '80'), ('5', '375', '375'), ('10', '700', '700')], "the Mech odds or prices moved")
need("ProfileVersion=22" in config.replace(' ', '') or 'ProfileVersion = 22' in config, "ProfileVersion must stay 22")
need(re.search(r"Version\s*=\s*'V150 R154'", config) is not None, "Config.Version must stay 'V150 R154' (the owner's release number)")
# 3. the disclosure line: one source, read from the world table; shown on the card, the hold tooltip and /test mechshop
need("function C.CoatLine()" in cat and "SeedPackRules" in cat and "M.Gold.Weight" in cat and "M.Diamond.Weight" in cat, "MechCatalog.CoatLine must read the world coat weights")
need('4.5' not in cat.split('function C.CoatLine()')[1].split('\nend')[0], "CoatLine must not hard-code the numbers")
need('CoatLine()' in rd('ServerScriptService/ChestChaseServer/ChestService.lua') and rd('ServerScriptService/ChestChaseServer/ChestService.lua').count('CoatLine') == 1, "the hold tooltip shows the coat line (one line in ChestService)")
need('CoatLine()' in rd('StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua'), "the shop card shows the coat line")
need('CoatLine()' in rd('ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua'), "/test mechshop shows the coat line")
# 4. the event's end: the sale is the clock; a purchase cannot START after it; a receipt is never refused
need("and Limited.Active(now)" in cat, "MechCatalog.OnSale must include LimitedEvent.Active")
m = re.search(r"function Service:ProcessReceipt.*?\nend\n", svc, re.S)
need(m is not None and 'OnSale' not in m.group(0) and 'EventOver' not in m.group(0) and 'Limited' not in m.group(0), "ProcessReceipt must never ask the sale or the event (a prompted purchase is always granted)")
need("Catalog.EventOver()then okay=false;message=Catalog.Event.Refused" in svc, "a Robux prompt after the end must be refused")
need("if Catalog.EventOver()then return false,Catalog.Event.Refused end" in prem, "a gem purchase after the end must be refused before anything is charged")
need(prem.index('Catalog.EventOver()') < prem.index('state.Gems-=offer.GemPrice'), "the event check must come before the gems are charged")
# 5. the art: the coat's kept parts are one attribute checked in one place
vis = rd('ReplicatedStorage/SeedPackVisuals.lua')
need(vis.count("MechCoatKeep") == 1, "SeedPackVisuals.Bag skips the kept parts in ONE place")
need("local coating=Rules.PackMutations[mutation]" in vis, "the coat treatment is still the world packs' (Rules.PackMutations)")
if fail:
    for f in fail: print('FAIL: ' + f)
    sys.exit(1)
print('ok: one coat draw per bought Mech pack in GrantMechPacks (free / test / daily / bonus packs never roll); the world constants, the Mech odds / prices, ProfileVersion 22 and Config.Version are as they were;')
print('    the coat line is read from the world table and is on the card, the hold tooltip and /test mechshop; the sale is the clock (gems and prompts refused after the end, a receipt never asked); the art skips the kept parts in one place')
PY
fi
if step 1;then
echo "== 1. server (test_mech_coats_server)"
mkdir -p "$OUT/srv";cp "$T/roblox.luau" "$TB/world.luau" "$R151/announce_env.luau" "$HERE/test_mech_coats_server.luau" "$OUT/srv/"
python3 "$R151/mkbundle.py" "$OUT/srv" >/dev/null
(cd "$OUT/srv" && timeout 900 $LUAU test_mech_coats_server.luau > test.log 2>&1) || { grep -v '^WARN' "$OUT/srv/test.log" | tail -40;exit 1; }
grep -v '^WARN' "$OUT/srv/test.log" | tail -2
fi
if step 2;then
echo "== 2. shop (test_mech_coats_shop)"
mkdir -p "$OUT/shop"
sed "s#/home/user/tmz/src#$SRC#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/test_mech_coats_shop.luau" "$OUT/shop/"
python3 "$OUT/mkbundle_cl.py" "$OUT/shop/rs_bundle.luau" GamePassClient="$SRC/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua" >/dev/null
(cd "$OUT/shop" && timeout 300 $LUAU test_mech_coats_shop.luau > test.log 2>&1) || { grep -v '^WARN' "$OUT/shop/test.log" | tail -40;exit 1; }
grep -v '^WARN' "$OUT/shop/test.log" | tail -2
fi
if step 3;then
echo "== 3. art (test_mech_coats_art)"
mkdir -p "$OUT/art"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$HERE/test_mech_coats_art.luau" "$OUT/art/"
python3 "$R151/mkbundle_packs.py" "$OUT/art" "$SRC" >/dev/null
(cd "$OUT/art" && timeout 900 $LUAU test_mech_coats_art.luau > test.log 2>&1) || { grep -v '^WARN\|^SCENE' "$OUT/art/test.log" | tail -40;exit 1; }
grep -v '^WARN\|^SCENE' "$OUT/art/test.log" | tail -2
fi
if step 4;then
for COAT in Gold Diamond;do
 echo "== 4. opening on a $COAT Mech pack (the R153 suite + the revealed seed keeps the coat)"
 d=$OUT/open_$COAT;mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$R151/rare_env.luau" "$R152/rare152_env.luau" "$R152/sound_levels.luau" "$d/"
 python3 "$HERE/make_opening_coat.py" $COAT "$d/test_mech_opening_coat.luau"
 python3 "$R151/mkbundle_rare.py" "$d" all-client >/dev/null
 (cd "$d" && timeout 1800 $LUAU test_mech_opening_coat.luau > test.log 2>&1) || { grep -v '^WARN' "$d/test.log" | tail -40;exit 1; }
  grep -v '^WARN' "$d/test.log" | tail -3
done
fi
if step 5;then
echo "== 5. z-fighting (R152 sweep, the Mech step: ground / held / picture / opening frames / plain-parts body, plain + Gold + Diamond)"
mkdir -p "$OUT/z"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$P/R149/tests/zfight_world.luau" "$R153/dump_mech_zscene.luau" "$OUT/z/"
python3 "$R151/mkbundle_packs.py" "$OUT/z" "$SRC" >/dev/null
(cd "$OUT/z" && timeout 900 $LUAU dump_mech_zscene.luau > dump.txt 2> dump.err) || { tail -20 "$OUT/z/dump.err";exit 1; }
python3 "$R152/check_zfight_sweep.py" mech "$OUT/z/dump.txt"
fi
echo "R155 Mech coats suites passed"
