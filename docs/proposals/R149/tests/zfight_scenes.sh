#!/bin/sh
# Usage: sh zfight_scenes.sh <out dir> <place.rbxl> <base commit> [src dir for "after", default this checkout's src]
# Builds the whole-map z-fighting scenes (zfight_scene.luau) from the owner's place file:
#   <out>/before_start.json, <out>/after_start.json  - treadmill skins / fence tiers 1-6 on the six bases, the runner at the track start
#   <out>/before_snow.json,  <out>/after_snow.json   - skin / tier 7 everywhere, the runner in the Snow biome (snow patches, keys)
# "before" runs the base commit's src (git archive), "after" this checkout's src (or the given src dir). Each .log has the steps.
# Needs /opt/luau and python3 (tools/rbxl.py reads the place: zstd / lz4 through ctypes).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:?out dir};PLACE=${2:?place.rbxl};BASE=${3:?base commit};AFTER=${4:-$REPO/src}
mkdir -p "$OUT/w" "$OUT/base_src"
python3 "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/w/place_tree.luau" Workspace/ChestChaseMap >/dev/null
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$HERE/zfight_world.luau" "$HERE/zfight_scene.luau" "$OUT/w/"
rm -rf "$OUT/base_src/src";git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base_src"
for which in before after;do
 if [ "$which" = before ];then SRC=$OUT/base_src/src;else SRC=$AFTER;fi
 D=$OUT/$which;mkdir -p "$D";cp "$OUT"/w/* "$D/"
 python3 "$HERE/zfight_bundle.py" "$SRC" "$D" >/dev/null
 for variant in start snow;do
  if [ "$variant" = start ];then PRE='RUNNER={0,-60}';else PRE='SKINS={7,7,7,7,7,7};FENCES={7,7,7,7,7,7};RUNNER={30,1500}';fi
  (printf '%s\n' "$PRE";cat "$D/zfight_scene.luau") > "$D/run_$variant.luau"
  (cd "$D" && timeout 600 /opt/luau/luau "run_$variant.luau" > "$OUT/${which}_$variant.log" 2>&1) || { tail -20 "$OUT/${which}_$variant.log";exit 1; }
  grep '^SCENE ' "$OUT/${which}_$variant.log" | sed 's/^SCENE //' > "$OUT/${which}_$variant.json"
  grep -v '^SCENE ' "$OUT/${which}_$variant.log" > "$OUT/${which}_$variant.steps"
  if grep -q 'FAILED' "$OUT/${which}_$variant.steps";then echo "scene $which/$variant: a step failed";grep FAILED "$OUT/${which}_$variant.steps";exit 1;fi
  echo "scene $which/$variant: $(grep '^ZSCENE' "$OUT/${which}_$variant.steps" | sed 's/^ZSCENE //')"
 done
done
