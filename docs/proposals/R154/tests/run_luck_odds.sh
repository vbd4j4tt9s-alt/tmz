#!/bin/sh
# Usage: sh run_luck_odds.sh [scratch dir]      (NO_MUTATE=1 skips the teeth; R154_BASE=<ref> = the release it is checked against, default 006daa1 = the R153 release head)
# R154, two owner answers: "the 2x luck is universal" (the 4 Leaf Clover's x2 on every pack, on top of the best boots) and "the elderbloom only pack is not supposed to be
# intentional" (no seed over 80% of any live pack, at any luck; /test rarepacks <rarity> a random real seed). On the Roblox mock (/opt/luau/luau) with the REAL modules:
#  0. static  - the changed / new scripts compile at -O0 (Roblox's 200-locals limit); PackLuck154 is in src/MANIFEST.tsv (sorted); the frozen odds files match R151's frozen.sha256
#               and each R154 change has its note there; Config.Version / ProfileVersion as in R153; BackgroundMusic untouched; the R152 load guard is still line 1 of every client
#               script; the open, the hold tooltip and the BEST PULL hook hand the roll the clover's luck; no model names in the R154 files
#  1. test    - test_luck_odds.luau (the R153 clover world): the doubled cap, the Void / Verity / Mech packs with and without the clover, the 80% rule on every pack x live version x
#               luck sweep (against an independent re-implementation), banked packs untouched, real rolls, /test rarepacks randomness, the fixed display at base luck
#  2. teeth   - the same test on broken copies (each must FAIL): the R153 cap back, the clover ignored by the fixed packs, the rule at 90%, the rule never applied, the upgrade
#               dropped, /test rarepacks back to the first seed, the display reading the shaped table, the open not passing the clover's luck
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R154_BASE:-006daa1}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
CHANGED="ReplicatedStorage/PackLuck154 ReplicatedStorage/SeedPackRules ReplicatedStorage/PackOdds137 ReplicatedStorage/PackOdds112 ReplicatedStorage/BalanceValues81 ReplicatedStorage/SeedRarity153 ReplicatedStorage/WorldStatusHud ReplicatedStorage/StudioTestHelp ReplicatedStorage/GamePassCatalog ReplicatedStorage/PremiumBoostCard ServerScriptService/ChestChaseServer/PlayerDataService ServerScriptService/ChestChaseServer/ChestService ServerScriptService/ChestChaseServer/HubDisplayService ServerScriptService/ChestChaseServer/OwnerUpdateCommands82 ServerScriptService/ChestChaseServer/RarePackTests"
n=0;for f in $CHANGED;do n=$((n+1));/opt/luau/luau-compile -O0 --null "$S/$f.lua" >/dev/null 2>"$OUT/compile.err" || { fail "$f does not compile at -O0";cat "$OUT/compile.err"; };done
echo "ok: $n changed / new scripts compile at -O0"
grep -q "^ModuleScript	ReplicatedStorage/PackLuck154	ReplicatedStorage/PackLuck154.lua$" "$S/MANIFEST.tsv" || fail "PackLuck154 is not in src/MANIFEST.tsv"
python3 - "$S/MANIFEST.tsv" <<'PY' || fail "src/MANIFEST.tsv is not sorted"
import sys
rows=open(sys.argv[1]).read().splitlines()[1:]
assert rows==sorted(rows,key=lambda l:l.split('\t')[1])
PY
echo "ok: PackLuck154 is in the manifest (sorted)"
(cd "$REPO" && grep -v '^#' "$P/R151/tests/frozen.sha256" | sha256sum -c --quiet -) || fail "a frozen file differs from R151's frozen.sha256"
for f in PackOdds112 SeedPackRules PackLuck154;do grep -q "^# R154.*$f.lua" "$P/R151/tests/frozen.sha256" || fail "frozen.sha256 has no R154 note for $f";done
grep -q "  src/ReplicatedStorage/PackLuck154.lua$" "$P/R151/tests/frozen.sha256" || fail "PackLuck154 is not frozen"
echo "ok: the frozen odds files match their hashes; the R154 changes (PackOdds112 / 137, SeedPackRules, the new PackLuck154) carry their notes"
grep -q "Config.Version='V150 R15[0-9a-z]*';Config.ProfileVersion=22" "$S/ServerScriptService/ChestChaseServer/Config.lua" || fail "Config.Version / ProfileVersion changed"
if git -C "$REPO" diff --name-only "$BASE" -- src | grep -i "BackgroundMusic";then fail "BackgroundMusic was touched";fi
echo "ok: Config.Version 'V150 R15x' (the release number is the release step's) and ProfileVersion 22 as in R153; BackgroundMusic untouched since $BASE"
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 && echo "ok: the R152 load guard is still line 1 of every client script" || { fail "the load guard test fails";tail -5 "$OUT/guard.log"; }
SS=$S/ServerScriptService/ChestChaseServer
grep -q "pack.BagVariant,pack.OddsVersion,pack.RateBoost,passLuck)" "$SS/PlayerDataService.lua" || fail "OpenSeedPack does not hand the roll the clover's luck"
grep -q "PassLuck=passLuck" "$SS/PlayerDataService.lua" || fail "the open's hook info has no PassLuck"
grep -q "record.OddsVersion or 0,nil,self.PlayerData:PassLuck(player))" "$SS/ChestService.lua" || fail "the hold tooltip does not ask with the clover's luck"
grep -q "info.Boost,info.PassLuck)" "$SS/HubDisplayService.lua" || fail "BEST PULL's odds do not include the clover's luck"
echo "ok: the open, the hold tooltip and BEST PULL hand the odds the clover's luck"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE" "$P/R154" "$S/ReplicatedStorage/PackLuck154.lua" 2>/dev/null | grep -v '/run_luck_odds.sh:' | grep -q .;then fail "a model name in the R154 files";else echo "ok: no model names in the R154 files";fi
# the test ----------------------------------------------------------------------------------------------------------------------------------------
build(){ # dir [Name=path ...]
 d=$1;shift;rm -rf "$d";mkdir -p "$d"
 cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R153/tests/clover_env.luau" "$HERE/test_luck_odds.luau" "$d/"
 python3 "$P/R153/tests/mkbundle_clover.py" "$d" "$@" > /dev/null
}
echo "== 1. test_luck_odds"
build "$OUT/w"
if ( cd "$OUT/w" && timeout 900 /opt/luau/luau test_luck_odds.luau > out.log 2>&1 );then
 echo "ok: $(grep -v '^WARN\|^TABLE' "$OUT/w/out.log" | tail -1)"
else grep -v '^WARN\|^TABLE' "$OUT/w/out.log" | tail -30;fail "test_luck_odds";fi
grep '^TABLE ' "$OUT/w/out.log" > "$OUT/tables.txt" || true
echo "(before -> after tables: $OUT/tables.txt)"
# teeth -------------------------------------------------------------------------------------------------------------------------------------------
if [ -z "$NO_MUTATE" ];then
 echo "== 2. teeth: each break must make the test fail"
 M=$OUT/mut;mkdir -p "$M"
 mutate(){ # name file old new
  name=$1;file=$2
  python3 - "$file" "$3" "$4" "$M/$name.lua" <<'PY' || { fail "mutation $name: the pattern is not in the file";return 0; }
import sys
f,old,new,out=sys.argv[1:5]
s=open(f,encoding='utf-8').read()
assert old in s,old
open(out,'w',encoding='utf-8').write(s.replace(old,new,1))
PY
  mod=$(basename "$file" .lua)
  build "$M/w_$name" "$mod=$M/$name.lua"
  if ( cd "$M/w_$name" && timeout 900 /opt/luau/luau test_luck_odds.luau > out.log 2>&1 );then fail "mutation $name was NOT noticed";else echo "ok: $name -> fails ($(grep -c '^FAIL' "$M/w_$name/out.log") failing checks)";fi
 }
 RSD=$S/ReplicatedStorage
 mutate old_cap "$SS/PlayerDataService.lua" "BalanceValues81).MaxLuck*passLuck)" "BalanceValues81).MaxLuck)"
 mutate old_clamp "$RSD/PackOdds137.lua" "math.clamp(luck,1,T.LuckCeiling or T.MaxLuck)" "math.clamp(luck,1,T.MaxLuck)"
 mutate no_clover "$RSD/SeedPackRules.lua" "if kind and luck>1 then return PackLuck.FixedOdds(kind,config,Rules,luck)end" ""
 mutate limit_90 "$RSD/PackLuck154.lua" "Limit=.8," "Limit=.9,"
 mutate no_rule "$RSD/SeedPackRules.lua" " if Rules.LiveOdds(stage,variantKey,seen)then odds=PackLuck.Shape(odds,Rules.GetRarity)end" ""
 mutate no_upgrade "$RSD/PackLuck154.lua" " for _,id in ipairs(ups)do out[id]+=L.Upgrade/#ups end
 out[top]-=L.Upgrade" ""
 mutate roll_unshaped "$RSD/SeedPackRules.lua" "  if changed then return PackLuck.Roll(config,shaped,Rules.GetRarity,draw)end" ""
 mutate first_seed "$SS/RarePackTests.lua" "return list[T.Random:NextInteger(1,#list)]" "return list[1]"
 mutate shaped_display "$RSD/SeedRarity153.lua" "pcall(Rules.RawSeedOdds or Rules.SeedOdds," "pcall(Rules.SeedOdds,"
 mutate open_no_pass "$SS/PlayerDataService.lua" "pack.BagVariant,pack.OddsVersion,pack.RateBoost,passLuck)" "pack.BagVariant,pack.OddsVersion,pack.RateBoost)"
fi
[ $RC = 0 ] && echo "R154 luck and odds: ALL PASS" || echo "R154 luck and odds: FAIL"
exit $RC
