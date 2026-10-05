#!/bin/sh
# Usage: sh run_badges.sh [scratch dir] [--existing] [--mutations]
# R151 (owner: "the notification for index, the red circle and the +, has to be polished, it looks really low quality and cut out wrongly"): the polished notification badge (NotifyBadge151), and the
# default-pack-shape plumbing (a picture whose proxy carries DefaultPackShape is the plain pouch), on the Roblox mock (/opt/luau/luau) with the REAL modules / client scripts of this checkout.
#  test_indexbadge.luau        the badge: a perfect circle, red gradient, white ring, soft shadow, centred bold text, "9+"; not clipped by ANY ancestor on any screen; the ROOT
#                              CAUSE measured on the R150 code (MODE before): the wheel's CanvasGroup and the tab row cut it; one component for every Index badge; the pop,
#                              the pulse and Reduced Motion
#  test_indexbadge_daily.luau  the DAILY button's and tabs' badges: the same component, not clipped by the screen's top edge (they were), on nine screens
#  test_defaultshape.luau      (client world + the owner's pack templates + the EditableMesh mock) a picture flagged DefaultPackShape asks for the DEFAULT pouch: no variation is requested, no mesh
#                              is baked, every pack is the design's own mesh (Verity: a plain client bake), and the other pictures keep their shapes
# --existing   also runs the suites that were there before and touch the same scripts (R137 / R138 Index, R148 index_limited, R140 daily, R151 pack shapes + Verity pouch + static checks)
# --mutations  breaks the code thirteen ways (mutate_badges.py) and expects the suite that guards each to fail
# INDEX_BASE (default 15d7743, the last commit before R151's badge change) is the "before" of the badge comparison (ChestIndex / HudLayout from git).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=$(mktemp -d);EXISTING=0;MUT=0
for a in "$@";do case "$a" in --existing) EXISTING=1;; --mutations) MUT=1;; *) OUT=$a;; esac;done
mkdir -p "$OUT"
T=$REPO/tools/tests;INV=$REPO/docs/proposals/inventory_R113/tests
BASE=${INDEX_BASE:-15d7743}
LUAU=${LUAU:-/opt/luau/luau}
S=$REPO/src
echo "== static: every touched script compiles, the manifest lists the new one, frozen files are untouched"
for f in ReplicatedStorage/NotifyBadge151 ReplicatedStorage/HudLayout ReplicatedStorage/ItemPictures ReplicatedStorage/SeedPackVisuals \
 ReplicatedStorage/SeedPackRenderer ReplicatedStorage/VerityPackArt ReplicatedStorage/VerityPouch151 StarterPlayer/StarterPlayerScripts/ChestIndex.client StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client;do
 /opt/luau/luau-compile --null "$S/$f.lua" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";exit 1; }
 grep -q "$f.lua" "$S/MANIFEST.tsv" || { echo "FAIL: $f is not in MANIFEST.tsv";exit 1; }
done
miss=0;while IFS="$(printf '\t')" read -r class place file; do [ "$class" = class ] && continue; [ -f "$S/$file" ] || { echo "manifest file missing: $file";miss=1; }; done < "$S/MANIFEST.tsv"
[ "$miss" = 0 ] || { echo "FAIL: MANIFEST.tsv lists a file that does not exist";exit 1; }
(cd "$REPO" && sha256sum -c "$HERE/frozen.sha256" >/dev/null) || { echo "FAIL: a frozen file (odds / rules / config) changed";exit 1; }
echo "ok: 9 scripts compile; NotifyBadge151 is in the manifest; the odds, rules and config files (frozen.sha256) are byte for byte what they were"
# --- one suite in one directory against one source tree -------------------------------------------------------------------------------------------------------------
# suite NAME DIR SRC [MODE]: stages the helpers and the bundle, runs it, leaves the log in DIR/NAME.log; returns the exit status
suite() {
 name=$1;d=$2;src=$3;mode=$4;mkdir -p "$d";rm -f "$d"/*.luau
 case "$name" in
  shape) cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/pack_world.luau" "$HERE/pack_templates.luau" "$HERE/pouch_mock.luau" "$HERE/test_defaultshape.luau" "$d/";python3 "$HERE/mkbundle_packs.py" "$d" "$src" >/dev/null;file=test_defaultshape;;
  daily) cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/layout_badges.luau" "$HERE/test_indexbadge_daily.luau" "$d/";python3 "$HERE/mkbundle_badges.py" "$d" "$src" >/dev/null;file=test_indexbadge_daily;;
  badge)
   cp "$T/roblox.luau" "$INV/world.luau" "$HERE/layout_badges.luau" "$d/"
   (echo "MODE='${mode:-after}'";cat "$HERE/test_indexbadge.luau") > "$d/test_indexbadge.luau";file=test_indexbadge
   if [ "$mode" = before ];then
    git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/ChestIndex.client.lua" > "$d/ChestIndexBase.lua"
    git -C "$REPO" show "$BASE:src/ReplicatedStorage/HudLayout.lua" > "$d/HudLayoutBase.lua"
    python3 "$HERE/mkbundle_badges.py" "$d" "$src" ChestIndex="$d/ChestIndexBase.lua" HudLayout="$d/HudLayoutBase.lua" >/dev/null
   else python3 "$HERE/mkbundle_badges.py" "$d" "$src" >/dev/null;fi;;
 esac
 (cd "$d" && timeout 900 $LUAU "$file.luau" > "$name.log" 2>&1)
}
show() { grep -v '^WARN' "$1/$2.log"; }
for pair in "shape:shape" "badge:badge_after:after" "badge:badge_before:before" "daily:daily";do
 name=${pair%%:*};rest=${pair#*:};dir=${rest%%:*};mode=;case "$rest" in *:*) mode=${rest#*:};; esac
 echo "== $dir"
 suite "$name" "$OUT/$dir" "$REPO/src" "$mode" || { show "$OUT/$dir" "$name" | tail -60;exit 1; }
 show "$OUT/$dir" "$name"
done
# --- the suites that were there before -----------------------------------------------------------------------------------------------------------------------------
if [ "$EXISTING" = 1 ];then
 # (the R112 / R113 bundler has the main checkout's path hard-coded: a python3 shim in front of the PATH makes it bundle THIS checkout)
 mkdir -p "$OUT/shim"
 cat > "$OUT/shim/python3" <<SHIM
#!/bin/sh
case "\$1" in
 */inventory_R11*/tests/mkbundle.py) f=\$1;shift;t=\$(mktemp "$OUT/shim/mk_XXXXXX.py");sed "s#/home/user/tmz/src#$REPO/src#g" "\$f" > "\$t";exec $(command -v python3) "\$t" "\$@";;
 *) exec $(command -v python3) "\$@";;
esac
SHIM
 chmod +x "$OUT/shim/python3"
 for r in R137:run.sh R138:run.sh R148:run_index_limited.sh R140:run.sh R151:run_pack_shapes.sh R151:run_verity_pouch.sh R151:static_checks.sh;do
  dir=${r%%:*};f=${r#*:};echo "== existing: $dir/$f"
  case "$f" in static_checks.sh) arg=$REPO;; *) arg="$OUT/existing_${dir}_$f";; esac
  PATH="$OUT/shim:$PATH" sh "$REPO/docs/proposals/$dir/tests/$f" "$arg" > "$OUT/existing.log" 2>&1 || { tail -40 "$OUT/existing.log";exit 1; }
  tail -3 "$OUT/existing.log"
 done
fi
# --- mutations -------------------------------------------------------------------------------------------------------------------------------------------------------------
if [ "$MUT" = 1 ];then
 echo "== mutations: the suite that guards each must fail on a broken copy"
 for m in $(python3 "$HERE/mutate_badges.py" x list);do
  want=$(python3 "$HERE/mutate_badges.py" x suite "$m")
  rm -rf "$OUT/mut";mkdir -p "$OUT/mut";cp -r "$REPO/src" "$OUT/mut/src"
  python3 "$HERE/mutate_badges.py" "$OUT/mut/src" "$m" >/dev/null
  if suite "$want" "$OUT/mut/run" "$OUT/mut/src" after;then echo "FAIL: mutant $m was NOT noticed by the $want suite";exit 1
  else echo "ok: mutant $m noticed by the $want suite ($(grep -c '^FAIL' "$OUT/mut/run/$want.log") failed checks)";fi
 done
fi
echo "all badge / default pack shape checks passed"
