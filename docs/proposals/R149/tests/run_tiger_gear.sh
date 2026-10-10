#!/bin/sh
# Usage: sh run_tiger_gear.sh [scratch dir] [--mutations]. R149 snow tiger gear checks on the Roblox mock with the REAL modules of this
# checkout (KeeperAccents, BeastPose, KeeperSignatureStrike, KeeperAttackPose, KeeperPolish, KeeperRigConfig and the BeastAnimation
# client script); needs /opt/luau and python3. "Other keepers unchanged" compares KeeperAccents against the base commit's
# (git show BASE:..., loaded as KeeperAccentsBase). With --mutations it also breaks the module five ways and expects the test to notice.
#  test_tiger_gear.luau - the gear exists only on the Snow keeper (38 parts, other keepers part-for-part identical to the base), each
#                         part follows exactly its own limb through sleep / idle / gait / a pounce in the real BeastAnimation, is
#                         non-colliding / non-queryable / massless / anchored, silver + sapphire colours and materials, the part budget,
#                         the rig-scale following, the LOD (studs + facets hidden far away and in low graphics), cleanup.
#  static checks        - no hit / reach / rig module changed against BASE and no server script requires KeeperAccents.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${TIGER_BASE:-d3c621d}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
S=$REPO/src
echo "== static checks"
# Reach, contact, pose and rig data must be byte-identical to the base: the gear changes no hitbox and no animation.
# R152 (the baked rev 6 keeper models) changed BeastPose, KeeperUpgradePose, KeeperStrikeFrames, KeeperSignatureStrike (an optional variant
# argument: the new models' floor samples), KeeperContact (face / cosmetic parts never hit) and BeastModels (the baked build); with no variant
# they give today's frames, contact parts and rigs exactly: docs/proposals/R152/tests/run_keepers.sh checks that against the base. The rest stay frozen here.
FROZEN="src/ReplicatedStorage/KeeperRigConfig.lua src/ReplicatedStorage/KeeperUpgradeData.lua src/ReplicatedStorage/KeeperAttackPose.lua src/ReplicatedStorage/KeeperCombat.lua src/ReplicatedStorage/KeeperPolish.lua src/ReplicatedStorage/KeeperMotion.lua src/ServerScriptService/ChestChaseServer/KeeperUpgradeArt.lua"
# R158 (on purpose): ConcurrentKeeperService is checked by tools/tests/r152_real_diff.sh: it may differ from the base only by the owner's "no SMACK" pack-drop
# notice (a bat hit shows none) and the bat packet's AttackerUserId (exact lines; no reach, contact or keeper line).
CKS=src/ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua
if git -C "$REPO" diff --quiet "$BASE" -- $FROZEN && sh "$REPO/tools/tests/r152_real_diff.sh" "$REPO" "$BASE" $CKS >/dev/null; then echo "ok: reach / contact / pose / rig modules unchanged against $BASE (R152's variant-aware ones: run_keepers.sh)"; else echo "FAIL: a frozen keeper module changed:";git -C "$REPO" diff --name-only "$BASE" -- $FROZEN;sh "$REPO/tools/tests/r152_real_diff.sh" "$REPO" "$BASE" $CKS;exit 1; fi
[ -f "$REPO/docs/proposals/R152/tests/run_keepers.sh" ] || { echo "FAIL: R152 changed keeper pose / contact modules without its legacy-equivalence suite";exit 1; }
# R151 (pack shapes): ChaseService passes a carried / dropped pack's chip-bag shape (chest.PackShape) to the three places that build the pack. Those three arguments are the only
# difference allowed: with them taken out the file is byte-identical to the base (no chase, hit, reach or keeper line changed). R153: and the one line that stamps KeeperHome (the spawn point the SPEED NEEDED sign is pinned to; nothing in the chase reads it), taken out by its comment.
CS=src/ServerScriptService/ChestChaseServer/ChaseService.lua
# R153 (architecture review): the owner commands no longer start from ChaseService (the Start override at the end of the file moved to the main script, inside a pcall): the override is taken out of the base and its two comment lines out of now.
mkdir -p "$OUT";git -C "$REPO" show "$BASE:$CS" | sed -e '/^local startV142=ChaseService.Start$/,/^end$/d' > "$OUT/ChaseServiceBase.lua"
sed -e '/^-- R153 (architecture review): the owner \/ test commands no longer start from here/d' -e '/^-- and with it the whole server). ChestChaseServerMain starts them/d' -e '/-- R153: the spawn point the SPEED NEEDED sign is pinned to/d' -e 's/,chest\.PackShape) -- R151:.*$/)/' -e 's/;model:SetAttribute("PackShape",chest\.PackShape)//' -e 's/chest\.PackMutation,chest\.PackShape)$/chest.PackMutation)/' "$REPO/$CS" > "$OUT/ChaseServiceNow.lua"
if cmp -s "$OUT/ChaseServiceBase.lua" "$OUT/ChaseServiceNow.lua" && [ "$(grep -c 'chest\.PackShape' "$REPO/$CS")" = 3 ]; then echo "ok: ChaseService unchanged against $BASE but the three chip-bag shape arguments (R151)"; else echo "FAIL: ChaseService changed against $BASE beyond the R151 shape arguments";diff "$OUT/ChaseServiceBase.lua" "$OUT/ChaseServiceNow.lua" | head;exit 1; fi
if grep -rIl "KeeperAccents" "$S/ServerScriptService" >/dev/null 2>&1; then echo "FAIL: a server script requires KeeperAccents";exit 1; else echo "ok: no server script requires KeeperAccents (the gear is client only)"; fi
/opt/luau/luau-compile --binary "$S/ReplicatedStorage/KeeperAccents.lua" >/dev/null && /opt/luau/luau-compile --binary "$S/StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua" >/dev/null && echo "ok: luau-compile clean"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/inventory_R113/tests/fixtures.luau" "$HERE/test_tiger_gear.luau" "$OUT/"
git -C "$REPO" show "$BASE:src/ReplicatedStorage/KeeperAccents.lua" > "$OUT/KeeperAccentsBase.lua"
bundle(){ # $1 = KeeperAccents source to test
 python3 "$REPO/docs/proposals/R147/tests/mkbundle_verity.py" "$OUT/rs_bundle.luau" KeeperAccents="$1" KeeperAccentsBase="$OUT/KeeperAccentsBase.lua" BeastAnimation="$S/StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua" >/dev/null
}
bundle "$S/ReplicatedStorage/KeeperAccents.lua"
cd "$OUT"
echo "== test_tiger_gear";/opt/luau/luau test_tiger_gear.luau > test_tiger_gear.log 2>&1 || { grep -v '^WARN' test_tiger_gear.log | tail -60;exit 1; }
grep -v '^WARN' test_tiger_gear.log
if [ "$2" = "--mutations" ]; then
 echo "== mutation checks (each break must make the test fail)"
 mutate(){ # $1 = name, $2 = sed expression
  mkdir -p "$OUT/mut_$1";sed "$2" "$S/ReplicatedStorage/KeeperAccents.lua" > "$OUT/mut_$1/KeeperAccents.lua"
  if cmp -s "$OUT/mut_$1/KeeperAccents.lua" "$S/ReplicatedStorage/KeeperAccents.lua"; then echo "BAD MUTATION $1: the sed changed nothing";exit 1; fi
  bundle "$OUT/mut_$1/KeeperAccents.lua";cd "$OUT"
  if /opt/luau/luau test_tiger_gear.luau > "mut_$1.log" 2>&1; then echo "MUTATION $1 SURVIVED (test passed)";exit 1; fi
  echo "killed $1: $(grep -c '^FAIL' "mut_$1.log") failing checks, e.g. $(grep -m1 '^FAIL' "mut_$1.log")"
 }
 mutate pauldron_on_body "s/plate('Pauldron'..tag,(side<0 and'Left'or'Right')..'FrontLeg'/plate('Pauldron'..tag,'Body'/"
 mutate collidable "s/p.CanCollide=false;p.CanQuery=false/p.CanCollide=not s.Gear;p.CanQuery=false/"
 mutate gear_on_snake "s/A.Gear={\[3\]=tigerGear()}/A.Gear={[3]=tigerGear(),[2]=tigerGear()}/"
 mutate no_scale "s/local k=rigScale(model,stage)/local k=1/"
 mutate no_lod "s/if s.Detail then\$/if false then/"
 mutate sapphire_colour "s/SAPPHIRE,FACET=rgb(30,80,200),rgb(90,150,255)/SAPPHIRE,FACET=rgb(200,30,30),rgb(90,150,255)/"
fi
