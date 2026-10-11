#!/bin/sh
# Usage: sh touch_lock158.sh <scratch dir> [golden]     R158 touch lock: test_touch_lock158.luau on every touch screen of touch_cases158.txt (a process each).
# With `golden` it prints the GOLDEN table lines instead (run it on the code BEFORE the PC rework, paste the lines between GOLDEN-BEGIN / GOLDEN-END of the test).
# BUNDLE_ARGS (optional): extra "Name=path" pairs for the bundler (the mutation checks swap a module in); CASES (optional): only these tags (space separated).
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:?scratch dir};MODE=$2
INV=$REPO/docs/proposals/inventory_R113/tests
mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/hud_world158.luau" "$HERE/test_touch_lock158.luau" "$OUT/"
python3 "$HERE/mkbundle_hud158.py" "$OUT" $BUNDLE_ARGS > /dev/null || exit 1
RC=0;N=0
while read -r tag w h ix iy vw vh;do
 case "$tag" in ''|'#'*) continue;; esac
 [ -z "$CASES" ] || case " $CASES " in *" $tag "*) ;; *) continue;; esac
 N=$((N+1))
 if [ "$MODE" = golden ];then
  (cd "$OUT" && timeout 300 /opt/luau/luau test_touch_lock158.luau -a golden "$tag" "$w" "$h" "$ix" "$iy" "$vw" "$vh") 2>&1 | grep '^GOLDEN\|LOADFAIL\|error'
 else
  (cd "$OUT" && timeout 300 /opt/luau/luau test_touch_lock158.luau -a "$tag" "$w" "$h" "$ix" "$iy" "$vw" "$vh") > "$OUT/$tag.log" 2>&1 || { grep -v '^WARN' "$OUT/$tag.log" | tail -12;RC=1; }
 fi
done < "$HERE/touch_cases158.txt"
if [ "$MODE" != golden ];then
 [ $RC = 0 ] && echo "R158 touch lock: $N touch screens, every fingerprint as before the PC rework" || echo "R158 touch lock: FAIL"
fi
exit $RC
