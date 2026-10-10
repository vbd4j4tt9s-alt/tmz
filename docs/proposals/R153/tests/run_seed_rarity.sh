#!/bin/sh
# Usage: sh run_seed_rarity.sh [scratch dir]   (NO_MUTATE=1 skips the teeth check; SEED_RARITY_BASE=<ref> changes the base, default e36b71b = the R152 release head)
# R153 (owner: "make it fixed visibly so when players pull a cosmic seed from a void pack they are still reminded of how rare it is, for example a change from 1/12 to 1/(the original rate)
# in the index"): ONE fixed chance per seed, shown everywhere a SEED is labelled. On the Roblox mock (/opt/luau/luau) with the REAL modules / scripts of this checkout:
#  1. static            - SeedRarity153 is in src/MANIFEST.tsv (sorted) and compiles, holds no copied odds (no number of 4+ digits, no decimal), the odds / pity files are byte-identical to
#                         the frozen hashes, no script reads a displayed chance back (nothing parses "1/N" text; RarePullRules.TooltipOdds is called by nobody), the touched scripts compile;
#  2. rolls unchanged   - dump_odds.luau on the base (R152 release) and on this checkout: every SeedOdds row (stage x variant x odds version x luck x boost), the Void / Verity / Mech rows,
#                         the Index chip numbers, the hold-tooltip rows, 60,000+ seeded rolls and every seed's rarity: IDENTICAL, byte for byte; the Index numbers equal the new canonical ones;
#                         R154: except what the 80% rule changes (live packs over 80%), each such line checked against an independent re-implementation (R154/tests/check_r154_dump.py),
#                         and the canonical numbers still equal the base Index (the fixed display keeps the base-luck rate);
#  3. test_seed_rarity  - the module (54 seeds, home pack, cache, formats, unknown / retired seeds), the Void example, ChestService's catalog, a held Void pack keeps its own rows, a real Void
#                         pack opened through the real PullAnnouncer (Cosmic / Secret / King / Mech), chat rules, the plaque (ranking unchanged), owner commands, announcement rules by tier;
#                         and the single-seed audit (section 9): no pack of any stage / tier / odds version / luck lists fewer than 2 seeds, a live pack's favourite stays under 90%;
#  4. Index / card / chat tests - the real ChestIndex, the real reveal (RarePullCinematic + card + scenes) and the real PullAnnouncerClient, for all 54 seeds, with every pack / catalog /
#                         payload number set to the wrong "1/12";
#  5. surfaces          - check_surfaces.py: the Index, the card, the chat (client and rules) and the plaque print the SAME text for each of the 54 seeds, equal to the canonical text;
#  6. teeth             - the same tests on a copy of src with the R152 versions of ChestIndex, RarePullCinematic, PullAnnounceRules, PullAnnouncer and HubDisplayRules put back: each must FAIL.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${SEED_RARITY_BASE:-e36b71b}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;LUAU=${LUAU:-/opt/luau/luau}
fail(){ echo "FAIL: $1";exit 1; }
echo "== static"
M=$S/MANIFEST.tsv
grep -q "ReplicatedStorage/SeedRarity153	ReplicatedStorage/SeedRarity153.lua" "$M" || fail "SeedRarity153 is not in src/MANIFEST.tsv"
python3 - "$M" <<'PY'
import sys
rows=open(sys.argv[1]).read().splitlines()[1:]
assert rows==sorted(rows,key=lambda l:l.split('\t')[1]),'MANIFEST not sorted'
PY
for f in ReplicatedStorage/SeedRarity153 ReplicatedStorage/PullAnnounceRules ReplicatedStorage/HubDisplayRules ReplicatedStorage/RarePullCinematic ReplicatedStorage/StudioTestHelp \
 ServerScriptService/ChestChaseServer/ChestService ServerScriptService/ChestChaseServer/HubDisplayService ServerScriptService/ChestChaseServer/PullAnnouncer;do
 /opt/luau/luau-compile --null "$S/$f.lua" >/dev/null 2>&1 || fail "$f does not compile"
done
/opt/luau/luau-compile --null "$S/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua" >/dev/null 2>&1 || fail "ChestIndex does not compile"
echo "ok: SeedRarity153 is in the manifest (sorted) and the 9 touched scripts compile"
if sed 's/--.*//' "$S/ReplicatedStorage/SeedRarity153.lua" | grep -v "R153" | grep -nE '[0-9]{4,}|[0-9]\.[0-9]';then fail "SeedRarity153 holds a number that looks like copied odds";fi
echo "ok: SeedRarity153 computes everything from the odds code (no copied number)"
(cd "$REPO" && grep -E ' src/ReplicatedStorage/(PackOdds81|PackOdds112|PackOdds137|SeedPackRules|PackLuck154|VoidPackOdds85|VerityPackOdds|PackSizePity|PackSchedule81|RarePackRules|MysteryPackRules)\.lua$|PackSizePityData' "$P/R151/tests/frozen.sha256" | sha256sum -c - >/dev/null) || fail "an odds / pity file differs from its frozen hash"
echo "ok: the odds and pity files are byte-identical to their frozen hashes"
if grep -rnE "match\('\^1/|match\(\"\^1/|TooltipOdds\(" "$S" | grep -v "RarePullRules.lua";then fail "a script reads a displayed chance back";fi
echo "ok: no script parses a displayed chance (RarePullRules.TooltipOdds is called by nobody)"
for f in "$S"/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua;do head -1 "$f" | grep -q "R152: start once the whole game has arrived" || fail "$f lost its load guard (line 1)";done
echo "ok: ChestIndex keeps the R152 load guard as line 1"

echo "== rolls unchanged (the base $BASE against this checkout)"
BUNDLER=docs/proposals/treadmill_bonus_R123/tests
rm -rf "$OUT/dump";mkdir -p "$OUT/dump/base/$BUNDLER" "$OUT/dump/new"
git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/dump/base"
cp "$P/treadmill_bonus_R123/tests/mkbundle.py" "$OUT/dump/base/$BUNDLER/"
for d in base new;do cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE/dump_odds.luau" "$OUT/dump/$d/";done
python3 "$OUT/dump/base/$BUNDLER/mkbundle.py" "$OUT/dump/base" >/dev/null
python3 "$P/treadmill_bonus_R123/tests/mkbundle.py" "$OUT/dump/new" >/dev/null
(cd "$OUT/dump/base" && timeout 900 $LUAU dump_odds.luau > dump.txt 2> err.txt || true) &
(cd "$OUT/dump/new" && timeout 900 $LUAU dump_odds.luau > dump.txt 2> err.txt || true)
wait
for d in base new;do grep -q '^VALIDATE	true' "$OUT/dump/$d/dump.txt" || { tail -5 "$OUT/dump/$d/err.txt";fail "the $d dump did not run (Config.Validate)"; };done
grep -v '^CANON ' "$OUT/dump/new/dump.txt" > "$OUT/dump/new_core.txt"
if cmp -s "$OUT/dump/base/dump.txt" "$OUT/dump/new_core.txt";then
 echo "ok: $(wc -l < "$OUT/dump/base/dump.txt") lines (SeedOdds rows, Void / Verity / Mech, Index chips, tooltips, seeded rolls, rarities): identical to the base, byte for byte"
else
 # R154 (owner: no single-seed packs): the 80% rule changes the live packs that gave one seed more than 80%; every other line must still be identical, and every changed one must be
 # exactly what an independent re-implementation of the rule makes of the base line (docs/proposals/R154/tests/check_r154_dump.py)
 python3 -I "$P/R154/tests/check_r154_dump.py" "$OUT/dump/base/dump.txt" "$OUT/dump/new/dump.txt" || fail "a roll table / odds row / seeded roll / rarity differs from the base beyond the R154 80% rule"
 echo "ok: $(wc -l < "$OUT/dump/base/dump.txt") lines (SeedOdds rows, Void / Verity / Mech, Index chips, tooltips, seeded rolls, rarities): identical to the base apart from the R154 80% rule"
fi
python3 - "$OUT/dump/base/dump.txt" "$OUT/dump/new/dump.txt" <<'PY'
import sys
base={};new={}
for l in open(sys.argv[1]):
    if l.startswith('INDEX '):
        _,sid,stage,pct,text=l.split();base[sid]=(text,float(pct))
for l in open(sys.argv[2]):
    if l.startswith('CANON '):
        _,sid,text,pct=l.split();new[sid]=(text,float(pct))
assert len(base)==54 and len(new)==54,(len(base),len(new))
bad=[s for s in base if base[s][0]!=new[s][0] or abs(base[s][1]-new[s][1])>1e-9*max(1,base[s][1])]
assert not bad,bad
print('ok: the canonical chance of all 54 seeds = the number the Index showed before R153 (the Index keeps its values; the base pack for every seed was already its home pack; R154: also where the 80% rule changed the home pack)')
PY

echo "== the tests"
run_all() { # $1 = root of the checkout whose src is bundled (REPO or a mutated copy), $2 = work dir; sets nothing, writes $2/{srv,idx,card,chat}/out.log (each test's exit status in $2/<name>.rc)
 root=$1;w=$2;rm -rf "$w";mkdir -p "$w/srv" "$w/idx" "$w/card" "$w/chat"
 cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R151/tests/announce_env.luau" "$HERE/test_seed_rarity.luau" "$w/srv/"
 python3 "$root/$BUNDLER/mkbundle.py" "$w/srv" >/dev/null
 cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$HERE/test_seed_rarity_index.luau" "$w/idx/"
 python3 "$root/docs/proposals/inventory_R113/tests/mkbundle.py" "$w/idx/rs_bundle.luau" ChestIndex="$root/src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua" >/dev/null
 cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$HERE/test_seed_rarity_card.luau" "$w/card/"
 python3 "$root/docs/proposals/R151/tests/mkbundle_rare.py" "$w/card" all-client >/dev/null
 cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R150/tests/ui_world.luau" "$HERE/test_seed_rarity_chat.luau" "$w/chat/"
 python3 "$root/docs/proposals/R151/tests/mkbundle.py" "$w/chat" >/dev/null
 for t in srv:test_seed_rarity idx:test_seed_rarity_index card:test_seed_rarity_card chat:test_seed_rarity_chat;do
  d=${t%%:*};f=${t#*:}
  (cd "$w/$d" && if timeout 900 $LUAU $f.luau > out.log 2>&1;then echo 0;else echo 1;fi > "$w/$d.rc") &
 done
 wait
}
run_all "$REPO" "$OUT/real"
RC=0
for t in srv:server idx:Index card:card chat:chat;do
 d=${t%%:*};label=${t#*:}
 if [ "$(cat "$OUT/real/$d.rc")" = 0 ];then echo "ok: $label: $(grep -v '^WARN\|^SURFACE' "$OUT/real/$d/out.log" | grep -E 'checks, [0-9]+ failures' | tail -1)"
 else grep -v '^WARN\|^SURFACE' "$OUT/real/$d/out.log" | tail -25;RC=1;echo "FAIL: the $label test";fi
done
[ "$RC" = 0 ] || exit 1
echo "== surfaces"
cat "$OUT/real/srv/out.log" "$OUT/real/idx/out.log" "$OUT/real/card/out.log" "$OUT/real/chat/out.log" > "$OUT/real/all.log"
python3 "$HERE/check_surfaces.py" "$OUT/dump/new/dump.txt" index="$OUT/real/all.log" card="$OUT/real/all.log" chat="$OUT/real/all.log" chat-rules="$OUT/real/all.log" plaque="$OUT/real/all.log" || fail "the surfaces differ"
if [ -z "$NO_MUTATE" ];then
 echo "== teeth: the R152 versions of five scripts put back must make the tests fail"
 M=$OUT/mut;rm -rf "$M";mkdir -p "$M"
 cp -r "$S" "$M/src"
 for f in StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua ReplicatedStorage/RarePullCinematic.lua ReplicatedStorage/PullAnnounceRules.lua ReplicatedStorage/HubDisplayRules.lua ServerScriptService/ChestChaseServer/PullAnnouncer.lua;do
  git -C "$REPO" show "$BASE:src/$f" > "$M/src/$f"
 done
 for b in treadmill_bonus_R123/tests/mkbundle.py inventory_R113/tests/mkbundle.py R151/tests/mkbundle_rare.py R151/tests/mkbundle.py;do mkdir -p "$M/docs/proposals/$(dirname $b)";cp "$P/$b" "$M/docs/proposals/$b";done
 run_all "$M" "$OUT/mutant"
 for t in idx:Index card:card chat:chat srv:server;do
  d=${t%%:*};label=${t#*:}
  if [ "$(cat "$OUT/mutant/$d.rc")" = 0 ];then fail "the $label test did NOT notice the R152 scripts";fi
  echo "ok: the $label test fails on the R152 scripts ($(grep '^FAIL' "$OUT/mutant/$d/out.log" | wc -l) failed checks)"
 done
fi
total=$(grep -h -oE '[0-9]+ checks, 0 failures' "$OUT"/real/*/out.log | awk '{s+=$1} END{print s}')
teeth="teeth ok";[ -z "$NO_MUTATE" ] || teeth="teeth skipped"
echo "R153 seed rarity: ALL PASS: $total checks, 0 failures (static, rolls identical to the base, server / Index / card / chat tests, 54 seeds x 5 surfaces identical, $teeth)"
