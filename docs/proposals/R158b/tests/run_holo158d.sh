#!/bin/sh
# Usage: sh run_holo158d.sh [scratch dir]
# R158d (owner: "do a mini rework on the holo melon and holo tree: make sure they use the updated melon and pumpkin meshes for the holo melon, and for the tree it uses the updated apples"):
#  wiring        - the changed files compile at -O0 (no function over 180 local registers: tools/tests/check_compile_O0.sh over all of src), nothing else under src/ changed except the two
#                  scripts (FruitMeshes149, HologramForms), line 1 of every changed script is as it was, Config.lua / the frozen files are byte-identical (R151's frozen.sha256);
#  test_holo158d - the four scenarios (mesh, parts, fail, loading), see the header of that file.
# The R149 mesh suites (their pins moved from 6 to 10 templates, 3 to 5 keys) run separately: sh docs/proposals/R149/tests/run_fruit_models.sh (needs the R149 base commits).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/w"
BASE=${HOLO_BASE:-1258821}
wiring() {
 # only this rework's own commits (every commit since BASE that touched HologramForms.lua): later fixes merged on top (the pack-leak fix,
 # the gift's silent pull, the release Version line) never trip it
 changed=$(for c in $(git -C "$REPO" rev-list "$BASE"..HEAD -- src/ReplicatedStorage/HologramForms.lua);do git -C "$REPO" diff-tree --no-commit-id --name-only -r "$c" -- src;done | sort -u)
 [ -n "$changed" ] || changed=$(git -C "$REPO" diff --name-only "$BASE" -- src | sort)
 want="src/ReplicatedStorage/FruitMeshes149.lua
src/ReplicatedStorage/HologramForms.lua"
 [ "$changed" = "$want" ] || { echo "src/ changes other than the two scripts:";echo "$changed";return 1; }
 for f in $changed;do
  [ "$(git -C "$REPO" show "$BASE:$f" | head -1)" = "$(head -1 "$REPO/$f")" ] || { echo "line 1 of $f changed";return 1; }
 done
 sh "$REPO/tools/tests/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 || { tail -5 "$OUT/o0.log";return 1; }
 tail -1 "$OUT/o0.log"
 (cd "$REPO" && grep -v '^#' docs/proposals/R151/tests/frozen.sha256 | sha256sum -c --quiet > "$OUT/frozen.log" 2>&1) || { cat "$OUT/frozen.log";return 1; }
 echo "the frozen files (Config.lua ...) are byte-identical"
 echo "wiring ok"
}
echo "== wiring";wiring
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/inventory_R113/tests/world.luau" "$REPO/docs/proposals/R149/tests/fruit_mesh_mock.luau" "$HERE/test_holo158d.luau" "$OUT/w/"
python3 "$REPO/docs/proposals/R149/tests/mkbundle_any.py" "$REPO/src/ReplicatedStorage" "$OUT/w/rs_bundle.luau" >/dev/null
for s in mesh parts fail loading;do
 echo "== test_holo158d $s"
 (cd "$OUT/w" && timeout 900 /opt/luau/luau test_holo158d.luau -a $s > "$OUT/holo_$s.log" 2>&1) || { grep -v '^WARN' "$OUT/holo_$s.log" | tail -40;exit 1; }
 grep '^INFO' "$OUT/holo_$s.log" || true
 grep -v '^WARN\|^INFO' "$OUT/holo_$s.log" | tail -1
done
echo "R158d Holo Melon / Holo Apple Tree suite passed"
