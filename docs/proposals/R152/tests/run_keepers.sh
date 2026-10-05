#!/bin/sh
# Usage: sh run_keepers.sh [scratch dir]   (needs /opt/luau/luau and python3)
# R152 baked keeper models on the Roblox mock with the REAL modules of this checkout, against the BASE commit (KEEPERS_BASE, default 24ed94b:
# the R151 handoff, just before R152):
#  0. static: every changed / new script compiles (luau-compile); in the keeper code proper (Keeper* / Beast* / the Darkened's three
#     scripts / ChaseService / Config.lua) only R152's own files differ from the base (other agents' R152 work elsewhere, e.g. Verity's
#     texts in VerityConfig.lua, is not this suite's business); Config.Version, KeeperCombat,
#     KeeperMotion, KeeperRigConfig, KeeperUpgradeData, ConcurrentKeeperService, KeeperAttackPose, KeeperPolish and ChaseService are
#     byte-identical; the embedded mesh data stays under 400 KB; every new script is in src/MANIFEST.tsv.
#  1. today's keepers unchanged: dump_legacy.luau through the public keeper APIs with no variant (pose / hit / strike frames, dressed rigs,
#     contact parts, accents, the sleep marker, effect anchors, today's Darkened) on the base and on this checkout: identical.
#  2. test_keepers.luau main: the bake, the spawn path, the swap, part counts, both faces, the golem's tree, contact, grounding, the Darkened,
#     the owner command, the new models' effects (KeeperFx152: parts, tiers, sleep, clean-up); then the fallbacks (API off, API missing,
#     no mesh memory mid-keeper, a content failure).
#  3. round trip: roundtrip.luau decodes every keeper on the mock and writes OBJ files; check_roundtrip.py decodes the same modules with
#     an independent Python decoder and compares both with the approved R151 manifests (parts, triangles, bounds) and the Blender dump.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
BASE=${KEEPERS_BASE:-24ed94b}
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests;SSS=$REPO/src/ServerScriptService/ChestChaseServer
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
NEW="src/ReplicatedStorage/KeeperRigConfig152.lua src/ReplicatedStorage/KeeperFx152.lua src/ServerScriptService/ChestChaseServer/KeeperMeshes152.lua src/ServerScriptService/ChestChaseServer/KeeperMeshCommand152.lua"
DATA=""
for n in Golem JungleKing SandSnake IceFang LavaDragon CrystalKnight StormColossus Darkened;do DATA="$DATA src/ServerScriptService/ChestChaseServer/KeeperMeshData152$n.lua";done
CHANGED="src/MANIFEST.tsv src/ReplicatedStorage/BeastPose.lua src/ReplicatedStorage/KeeperAccents.lua src/ReplicatedStorage/KeeperFx.lua src/ReplicatedStorage/KeeperSignatureStrike.lua src/ReplicatedStorage/KeeperSleep.lua src/ReplicatedStorage/KeeperStrikeFrames.lua src/ReplicatedStorage/KeeperSurge.lua src/ReplicatedStorage/KeeperUpgradePose.lua src/ReplicatedStorage/StudioTestHelp.lua src/ReplicatedStorage/VeiledKeeper81.lua src/ServerScriptService/ApprovedPlantsBootstrap.server.lua src/ServerScriptService/ChestChaseServer/BeastModels.lua src/ServerScriptService/ChestChaseServer/KeeperContact.lua src/ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua src/ServerScriptService/ChestChaseServer/VeiledEvent81.lua src/StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua src/StarterPlayer/StarterPlayerScripts/VeiledEventClient81.client.lua"
for f in $NEW $DATA $CHANGED;do echo $f;done | grep -v MANIFEST | LC_ALL=C sort > "$OUT/allowed.txt";echo src/MANIFEST.tsv >> "$OUT/allowed.txt";LC_ALL=C sort -o "$OUT/allowed.txt" "$OUT/allowed.txt"
# the keeper code proper (by file name: Keeper* / Beast* modules and scripts, the Darkened's VeiledKeeper81 / VeiledEvent81 /
# VeiledEventClient81, ChaseService, the two Config.lua): every one that differs from the base must be on R152's list. Other agents' R152
# work (hub, packs, keyboard track, Void giveaway, Verity's texts in VerityConfig.lua) and the shared hook files R152 also edits
# (manifest, help line, bootstrap, owner commands: on the list, compiled below) are not checked here.
KEEPER='/(Keeper[A-Za-z0-9]*|Beast[A-Za-z0-9]*|Veiled(Keeper|Event|EventClient)81|ChaseService|Config)(\.client|\.server)?\.lua$'
{ git -C "$REPO" diff --name-only "$BASE" -- src;git -C "$REPO" ls-files --others --exclude-standard -- src; } | grep -E "$KEEPER" | LC_ALL=C sort -u > "$OUT/changed.txt"
LC_ALL=C comm -13 "$OUT/allowed.txt" "$OUT/changed.txt" > "$OUT/files.diff"
if [ ! -s "$OUT/files.diff" ];then echo "ok: in the keeper code only R152's files differ from $BASE ($(wc -l < "$OUT/changed.txt") changed, all on the list)";else fail "unexpected keeper-code changes:";cat "$OUT/files.diff";fi
FROZEN="src/ServerScriptService/ChestChaseServer/Config.lua src/ReplicatedStorage/KeeperCombat.lua src/ReplicatedStorage/KeeperMotion.lua src/ReplicatedStorage/KeeperRigConfig.lua src/ReplicatedStorage/KeeperUpgradeData.lua src/ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua src/ReplicatedStorage/KeeperAttackPose.lua src/ReplicatedStorage/KeeperPolish.lua src/ServerScriptService/ChestChaseServer/ChaseService.lua src/ServerScriptService/ChestChaseServer/KeeperUpgradeArt.lua src/ReplicatedStorage/KeeperVoices.lua src/ReplicatedStorage/KeeperAudio.lua src/ServerScriptService/ChestChaseServer/RagdollService.lua src/ReplicatedStorage/KnockbackConfig.lua"
if git -C "$REPO" diff --quiet "$BASE" -- $FROZEN;then echo "ok: Config (Config.Version), strike timing, motion, today's rig data, the chase / ragdoll / fling services, voices: byte-identical";else fail "a frozen gameplay file changed:";git -C "$REPO" diff --name-only "$BASE" -- $FROZEN;fi
for f in $NEW $DATA $(echo $CHANGED | tr ' ' '\n' | grep '\.lua$');do /opt/luau/luau-compile --binary "$REPO/$f" >/dev/null || fail "$f does not compile";done;echo "ok: luau-compile clean ($(echo $NEW $DATA $CHANGED | wc -w) files)"
BYTES=$(cat $(for f in $DATA;do echo "$REPO/$f";done) | wc -c);CFG=$(wc -c < "$REPO/src/ReplicatedStorage/KeeperRigConfig152.lua")
if [ "$BYTES" -lt 409600 ];then echo "ok: embedded mesh data $BYTES bytes for 8 keepers (+ KeeperRigConfig152 $CFG bytes), under 400 KB";else fail "mesh data $BYTES bytes";fi
for f in $NEW $DATA;do p=$(echo $f | sed 's#^src/##;s#\.lua$##');grep -q "	$p	" "$REPO/src/MANIFEST.tsv" || fail "$p is not in src/MANIFEST.tsv";done;echo "ok: the $(echo $NEW $DATA | wc -w) new scripts are in src/MANIFEST.tsv"
grep -q "Version" "$REPO/src/ServerScriptService/ChestChaseServer/BeastModels.lua" && grep -q "Version=152" "$REPO/src/ServerScriptService/ChestChaseServer/BeastModels.lua" && echo "ok: the keepers' own visual version (BeastModels.Version) is 152" || fail "BeastModels.Version"
echo "== 1. today's keepers unchanged (no variant, no mesh API) against $BASE"
rm -rf "$OUT/base" "$OUT/now" "$OUT/srcbase";mkdir -p "$OUT/base" "$OUT/now" "$OUT/srcbase"
git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/srcbase"
BS=$OUT/srcbase/src/ServerScriptService/ChestChaseServer
for d in base now;do cp "$T/roblox.luau" "$INV/world.luau" "$HERE/dump_legacy.luau" "$OUT/$d/";done
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$OUT/srcbase/src/ReplicatedStorage" "$OUT/base/rs_bundle.luau" BeastModels="$BS/BeastModels.lua" KeeperUpgradeArt="$BS/KeeperUpgradeArt.lua" KeeperContact="$BS/KeeperContact.lua" >/dev/null
SERVER="KeeperMeshes152=$SSS/KeeperMeshes152.lua KeeperMeshCommand152=$SSS/KeeperMeshCommand152.lua BeastModels=$SSS/BeastModels.lua KeeperUpgradeArt=$SSS/KeeperUpgradeArt.lua KeeperContact=$SSS/KeeperContact.lua"
for n in Golem JungleKing SandSnake IceFang LavaDragon CrystalKnight StormColossus Darkened;do SERVER="$SERVER KeeperMeshData152$n=$SSS/KeeperMeshData152$n.lua";done
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$OUT/now/rs_bundle.luau" $SERVER BeastAnimation="$REPO/src/StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua" VeiledEventClient81="$REPO/src/StarterPlayer/StarterPlayerScripts/VeiledEventClient81.client.lua" >/dev/null
(cd "$OUT/base" && /opt/luau/luau dump_legacy.luau > dump.txt 2> err.txt) || { tail -20 "$OUT/base/err.txt";exit 1; }
(cd "$OUT/now" && /opt/luau/luau dump_legacy.luau > dump.txt 2> err.txt) || { tail -20 "$OUT/now/err.txt";exit 1; }
grep -v '^WARN' "$OUT/base/dump.txt" > "$OUT/base/d.txt";grep -v '^WARN' "$OUT/now/dump.txt" > "$OUT/now/d.txt"
if cmp -s "$OUT/base/d.txt" "$OUT/now/d.txt";then echo "ok: $(wc -l < "$OUT/now/d.txt") lines identical (pose, hit and strike frames of every stage, dressed rigs, contact parts, accents, sleep marker, effect anchors, today's Darkened)"
else fail "today's keepers differ from the base:";diff "$OUT/base/d.txt" "$OUT/now/d.txt" | head -20;fi
echo "== 2. test_keepers"
cp "$T/roblox.luau" "$INV/world.luau" "$HERE/keeper_mesh_mock.luau" "$HERE/test_keepers.luau" "$OUT/now/"
for s in main throw missing failat content nomodule;do
 (cd "$OUT/now" && timeout 900 /opt/luau/luau test_keepers.luau -a $s > keepers_$s.log 2>&1) || { grep -v '^WARN' "$OUT/now/keepers_$s.log" | tail -40;fail "test_keepers $s";continue; }
 grep '^INFO' "$OUT/now/keepers_$s.log" || true;grep -v '^WARN\|^INFO' "$OUT/now/keepers_$s.log" | tail -1
done
echo "== 3. round trip"
cp "$HERE/roundtrip.luau" "$OUT/now/"
(cd "$OUT/now" && /opt/luau/luau roundtrip.luau > roundtrip.txt 2> roundtrip.err) || { tail -20 "$OUT/now/roundtrip.err";exit 1; }
python3 "$HERE/check_roundtrip.py" "$OUT/now/roundtrip.txt" "$OUT/obj" "$REPO" || fail "round trip"
[ $RC = 0 ] && echo "R152 keeper suite: all stages passed"
exit $RC
