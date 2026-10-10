#!/bin/sh
# Usage: sh pc_hud158.sh <scratch dir> [golden]     R158 PC HUD: test_pc_hud158.luau on every window of pc_cases158.txt (a process each).
# With `golden` it prints the GOLDEN table lines of the owner's five windows instead (paste them between GOLDEN-BEGIN / GOLDEN-END of the test).
# BUNDLE_ARGS (optional): extra "Name=path" pairs for the bundler (the mutation checks swap a module in); CASES (optional): only these windows ("WxH", space separated).
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:?scratch dir};MODE=$2
INV=$REPO/docs/proposals/inventory_R113/tests
mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE/hud_world158.luau" "$HERE/test_pc_hud158.luau" "$OUT/"
python3 "$HERE/mkbundle_hud158.py" "$OUT" $BUNDLE_ARGS > /dev/null || exit 1
RC=0;N=0
while read -r w h;do
 case "$w" in ''|'#'*) continue;; esac
 [ -z "$CASES" ] || case " $CASES " in *" ${w}x${h} "*) ;; *) continue;; esac
 N=$((N+1))
 if [ "$MODE" = golden ];then
  [ $N -le 5 ] || continue
  (cd "$OUT" && timeout 300 /opt/luau/luau test_pc_hud158.luau -a golden "$w" "$h") 2>&1 | grep '^GOLDEN\|LOADFAIL\|error'
 else
  (cd "$OUT" && timeout 300 /opt/luau/luau test_pc_hud158.luau -a "$w" "$h") > "$OUT/pc_${w}x${h}.log" 2>&1 || { grep -v '^WARN' "$OUT/pc_${w}x${h}.log" | tail -14;RC=1; }
  grep '^PC ' "$OUT/pc_${w}x${h}.log"
 fi
done < "$HERE/pc_cases158.txt"
if [ "$MODE" != golden ];then
 [ $RC = 0 ] && echo "R158 PC HUD: $N windows, every check passes" || echo "R158 PC HUD: FAIL"
fi
exit $RC
