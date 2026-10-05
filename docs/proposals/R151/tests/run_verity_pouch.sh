#!/bin/sh
# Usage: sh run_verity_pouch.sh [scratch dir] [--mutations]
# R151 (owner: the Verity pack should be the REAL standard chip-bag pouch in pure yellow, made at runtime; the sachet only as the fallback): VerityPouch151 (the
# server bake: AssetService:CreateEditableMeshAsync -> every vertex colour white -> CreateMeshPartAsync -> ReplicatedStorage.VerityPouchTemplate151) and VerityPackArt
# (the pouch pack, the sachet fallback) on the Roblox mock (/opt/luau/luau) with the REAL modules of this checkout, the REAL pack templates of the owner's place
# (pack_templates.luau) and a mock of the EditableMesh route with a switch for every failure (pouch_mock.luau). See test_verity_pouch.luau for what is checked.
#  --mutations  also breaks the code ten ways (the colours not whitened / not read back, a hard-coded mesh id, the EditableMesh not destroyed, a tinted Decal, a
#               pouch that is not yellow, the Decals on the seal, a client that does not wait, another design built from the pouch, no sachet fallback) and
#               expects the test to notice each one (a failed check, or the test stopping on the error).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=$(mktemp -d);MUT=0
if [ -n "$1" ] && [ "${1#--}" = "$1" ];then OUT=$1;shift;fi
[ "$1" = "--mutations" ] && MUT=1
mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests
LUAU=${LUAU:-/opt/luau/luau}
stage() { mkdir -p "$1";cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/pack_world.luau" "$HERE/pack_templates.luau" "$HERE/pouch_mock.luau" "$HERE/test_verity_pouch.luau" "$1/"; }
echo "== test_verity_pouch (this checkout)"
stage "$OUT/run";python3 "$HERE/mkbundle_packs.py" "$OUT/run" "$REPO/src" >/dev/null
(cd "$OUT/run" && timeout 900 $LUAU test_verity_pouch.luau > test_verity_pouch.log 2>&1) || { grep -v '^WARN' "$OUT/run/test_verity_pouch.log" | tail -60;exit 1; }
grep -v '^WARN' "$OUT/run/test_verity_pouch.log"
if [ "$MUT" = 1 ];then
 echo "== mutations: the test must notice each broken copy"
 for m in $(python3 "$HERE/mutate_pouch.py" x list);do
  rm -rf "$OUT/mut";mkdir -p "$OUT/mut";cp -r "$REPO/src" "$OUT/mut/src"
  python3 "$HERE/mutate_pouch.py" "$OUT/mut/src" "$m" >/dev/null
  stage "$OUT/mut/run";python3 "$HERE/mkbundle_packs.py" "$OUT/mut/run" "$OUT/mut/src" >/dev/null
  if (cd "$OUT/mut/run" && timeout 900 $LUAU test_verity_pouch.luau > t.log 2>&1);then echo "FAIL: mutant $m was NOT noticed";exit 1;else echo "ok: mutant $m noticed ($(grep -c '^FAIL' "$OUT/mut/run/t.log") failed checks)";fi
 done
fi
echo "all Verity pouch checks passed"
