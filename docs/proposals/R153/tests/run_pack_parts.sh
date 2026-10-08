#!/bin/sh
# Usage: sh run_pack_parts.sh [scratch dir] [--base REF]
# R153 (owner, on R152: "parts are dislocated on packs"; the yellow Verity pouch held edge-on, its seal and tear strips off to one side, the top one stepped):
# every part of every pack against its REAL pouch, on the Roblox mock (/opt/luau/luau) with the REAL modules of this checkout, the REAL pack templates of the
# owner's place (R151 pack_templates.luau) and the pouches' real geometry (the native render data each uploaded pouch mesh was made from: tools/pouch_mesh.py).
#  1. test_pack_parts.luau   the BottomSeal and the 8 TearStrips against the pouch's crimps - centred (depth and across), touching, not sticking out past the
#                            crimp's ends - for the Verity flat pouch and its sachet fallback, the 42 designs x the default + 6 shapes (the REAL PackShapes151.Deform
#                            run on the real crimp rows), the legacy variants, the Void and the Mech; on the ground, held R15 / R6, CarryBag, pictures (also the
#                            real ItemPictures viewport: hotbar / Bag / Index / the Verity dialog), the opening copy, market, mystery pedestal, viewport, giants, coats.
#  2. check_pack_parts.py    the native data IS the place's pouch (the template's box, to 1e-4), every pouch closes where the seal and strips are, and no part
#                            hangs off its pouch (attach.py: within .03 of the real surface, or touching a static part that is); the Void's halo is listed as by
#                            design; the Mech (R153 look B) is COUNTED on its own body: the generated flat pouch's triangles or its plain-parts sachet.
#  3. reproduce              the same on REF (default 8208603, R152 as released + the R153 proposals): test_pack_parts must fail ONLY on the R152 kinds (seam: the
#                            Verity pouch .047 off the seal / strips; crimp: the 16 tall designs' shapes pulling their top crimp in under the strips), the geometric
#                            check must find the Void's floating corner details, and EclipsePackArt.Seats must be exactly their pouch depths there.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=$(mktemp -d);BASE=${PACK_PARTS_BASE:-8208603}
if [ -n "$1" ] && [ "${1#--}" = "$1" ];then OUT=$1;shift;fi
while [ $# -gt 0 ];do case "$1" in --base) shift;BASE=$1;; esac;shift;done
mkdir -p "$OUT"
LUAU=${LUAU:-/opt/luau/luau};R=$REPO/docs/proposals/R151/tests;INV=$REPO/docs/proposals/inventory_R113/tests
stage() { mkdir -p "$1";cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R/pack_world.luau" "$R/pack_templates.luau" "$R/pouch_mock.luau" "$HERE/test_pack_parts.luau" "$HERE/dump_pack_parts.luau" "$1/";python3 "$R/mkbundle_packs.py" "$1" "$2" >/dev/null; }

# R153 perf (dead code retired): the V120 native render data (src/ReplicatedStorage/SeedPackArt<Biome><NN>.lua) is no longer shipped - no game script
# required it, the pouches are uploaded meshes. This suite measures the pouches against that data, so "now" is this checkout's src plus those files
# from the last commit that shipped them (PACK_ART_REF, default 0260e00); a checkout that still has them is used as it is.
ART_REF=${PACK_ART_REF:-0260e00};NOW_SRC=$REPO/src
if ! ls "$REPO"/src/ReplicatedStorage/SeedPackArt*.lua >/dev/null 2>&1;then
 rm -rf "$OUT/now_src";mkdir -p "$OUT/now_src";cp -r "$REPO/src" "$OUT/now_src/"
 git -C "$REPO" archive "$ART_REF" src/ReplicatedStorage | tar -x -C "$OUT/now_src" --wildcards 'src/ReplicatedStorage/SeedPackArt*'
 NOW_SRC=$OUT/now_src/src;echo "(the retired pouch render data: $(ls "$NOW_SRC"/ReplicatedStorage/SeedPackArt*.lua | wc -l) files from $ART_REF)"
fi
echo "== this checkout: seal / strips against the crimps (every pack, context, shape)"
stage "$OUT/now" "$NOW_SRC"
(cd "$OUT/now" && timeout 900 $LUAU test_pack_parts.luau > t.log 2>&1) || { grep -v '^WARN' "$OUT/now/t.log" | tail -40;echo "FAIL: test_pack_parts";exit 1; }
grep -v '^WARN' "$OUT/now/t.log" | tail -4
echo "== this checkout: every part on its real pouch"
(cd "$OUT/now" && timeout 600 $LUAU dump_pack_parts.luau > scenes.txt 2>&1)
python3 "$HERE/check_pack_parts.py" "$OUT/now/scenes.txt" "$NOW_SRC" > "$OUT/now/check.log" || { cat "$OUT/now/check.log";echo "FAIL: check_pack_parts";exit 1; }
grep -vE '^[A-Z][a-z]+_0[0-9] ' "$OUT/now/check.log"

echo "== reproduce on $BASE (R152): the same checks must find the reported bug"
mkdir -p "$OUT/base_src";git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base_src"
stage "$OUT/base" "$OUT/base_src/src"
if (cd "$OUT/base" && timeout 900 $LUAU test_pack_parts.luau > t.log 2>&1);then echo "FAIL: test_pack_parts passes on $BASE (it does not see the R152 bug)";exit 1;fi
kinds=$(grep '^failures by kind:' "$OUT/base/t.log" | sed 's/^failures by kind: //')
echo "base: $kinds"
echo "$kinds" | grep -q 'seam=' || { echo "FAIL: on $BASE the Verity pouch is not seen off the seal / strips";exit 1; }
echo "$kinds" | grep -q 'crimp=' || { echo "FAIL: on $BASE the tall designs' shaped crimps are not seen";exit 1; }
if echo "$kinds" | tr ' ' '\n' | grep -vqE '^(seam|crimp)=[0-9]+$';then echo "FAIL: on $BASE something else fails too: $kinds";exit 1;fi
grep -E '^FAIL \[seam\]: Verity held R15 1x: top' "$OUT/base/t.log" | head -1
grep -E '^worst:' "$OUT/base/t.log"
(cd "$OUT/base" && timeout 600 $LUAU dump_pack_parts.luau > scenes.txt 2>&1)
python3 "$HERE/check_pack_parts.py" "$OUT/base/scenes.txt" "$OUT/base_src/src" --expect-floating > "$OUT/base/check.log" || { cat "$OUT/base/check.log";echo "FAIL: on $BASE the Void's floating corner details are not seen";exit 1; }
grep -E '^base:|floats \(base\): Void: RuneSigilF1_3' "$OUT/base/check.log"
python3 "$HERE/check_pack_parts.py" "$OUT/base/scenes.txt" "$NOW_SRC" --seats || { echo "FAIL: EclipsePackArt.Seats is not what the pouch says under the details that float on $BASE";exit 1; }
echo "all pack-parts checks passed"
