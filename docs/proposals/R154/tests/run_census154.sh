#!/bin/sh
# Usage: sh run_census154.sh [scratch dir] [place.rbxl]
# R154 B1 + B3 (owner: "for the lag fixes we can implement B3 and B1"): B1 = parts the game's scripts build under 1.5 studs cast no shadow; B3 = phones' keyboard. The census world (the owner's place with
# every real start-up builder and the hub / keyboard / snow clients: lag153_census.luau) is built twice with the real scripts - the R153 release (git archive of
# $R154_BASE, default the commit before R154) and this checkout - and run per tier 3 / 2 / 1 at the hub plaza and on the track (z 1300). Then, per run:
#  * now: no script-built part under 1.5 studs casts a shadow (tiny_scripted = 0); the ones that still do are the saved map's own (tiny_saved), unchanged
#  * the saved map's parts: the same casters / non-casters on both sides (nothing of the saved map was touched)
#  * characters and avatars (parts of a model with a Humanoid): the same casters on both sides
#  * parts of 1.5 studs and more: the same number of casters and non-casters on both sides (bigger parts keep their shadows)
#  * the sun's shadow casters within 400 studs of the runner and the total: before -> after (printed)
#  * B3: the keyboard's keys, SurfaceGuis, letter canvas pixels and letters per tier: before -> after (printed); tier 3 must be unchanged, tier 2 must have fewer keys and a smaller canvas, tier 1 (R155: owner "yes" to the lighter keyboard on the lowest setting too) the same keys / letters and a smaller canvas
# Without the place file the runner stops (the census needs the map).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/5ea4542b-sapkeee.rbxl}
# The base side: this checkout with B1 + B3 switched off (perf154.patch undone), so the other R154 changes (the hub tidy, the bed ramps, the
# trampolines) are on both sides and only B1 / B3 differ. R154_BASE=<commit> uses that commit's src instead (the R153 release: 006daa1).
BASE=${R154_BASE:-}
[ -f "$PLACE" ] || { echo "no place file at $PLACE";exit 1; }
mkdir -p "$OUT/base_src";rm -rf "$OUT/base_src/src"
if [ -n "$BASE" ];then git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base_src"
else cp -R "$REPO/src" "$OUT/base_src/src";patch -s -R -p1 -d "$OUT/base_src" < "$HERE/perf154.patch" || { echo "perf154.patch no longer undoes cleanly (regenerate it: perf154.md)";exit 1; };BASE="this checkout without B1 + B3";fi
python3 -I "$REPO/docs/proposals/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place_tree.luau" Workspace/ChestChaseMap >/dev/null
for side in base now;do
 src=$REPO/src;[ "$side" = base ] && src=$OUT/base_src/src
 python3 "$REPO/docs/proposals/R153/tests/lag153_world.py" "$src" "$OUT/$side/cw" "$OUT/place_tree.luau" >/dev/null
 head -n -1 "$OUT/$side/cw/census.luau" > "$OUT/$side/cw/census_body.luau"
done
: > "$OUT/jobs.txt"
for side in base now;do
 for spec in "3|hub" "2|hub" "1|hub" "3|track" "2|track" "1|track";do
  t=${spec%|*};spot=${spec#*|};z=-60;[ "$spot" = track ] && z=1300
  echo "$OUT/$side/cw|s_t${t}_$spot|TIER=$t;SPOT='$spot';RUNNER={0,$z};ALLCLIENT=true" >> "$OUT/jobs.txt"
 done
done
cat > "$OUT/one.sh" <<EOF
IFS='|' read -r d name globals <<END
\$1
END
printf '%s\n' "\$globals" > "\$d/run_\$name.luau";cat "\$d/census_body.luau" "$HERE/census154_tail.luau" >> "\$d/run_\$name.luau"
(cd "\$d" && timeout 900 /opt/luau/luau "run_\$name.luau" > "\$name.out" 2> "\$name.err";echo "EXIT \$?" >> "\$name.out")
tail -n 1 "\$d/\$name.out" | grep -q '^EXIT 0\$' && echo "ran \$d/\$name" || { echo "FAILED \$d/\$name";tail -n 3 "\$d/\$name.err"; }
EOF
echo "== B1: the census world, base $BASE vs this checkout ($(wc -l < "$OUT/jobs.txt") runs, ${JOBS:-2} at a time)"
xargs -d '\n' -P "${JOBS:-2}" -I{} sh "$OUT/one.sh" {} < "$OUT/jobs.txt" > "$OUT/runs.log" 2>&1 || true
if grep -q '^FAILED' "$OUT/runs.log";then cat "$OUT/runs.log";exit 1;fi
python3 "$HERE/check_census154.py" "$OUT/base/cw" "$OUT/now/cw"
