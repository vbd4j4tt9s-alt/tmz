#!/bin/sh
# Usage: sh run.sh [scratch dir]. R123 treadmill bonus rolls under the Roblox mock (tools/tests/roblox.luau):
# test_server.luau (real TreadmillBonusService + PlayerDataService + Config + SecurityGate), test_client.luau
# (real TreadmillBonusClient + HudLayout) and test_layout.luau (button placement over 26 screens).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
cp "$HERE/../../../../tools/tests/roblox.luau" "$HERE/world.luau" "$HERE"/test_*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
for t in test_server test_client test_layout; do
 /opt/luau/luau $t.luau > $t.log 2>&1 || { tail -40 $t.log; echo "$t FAILED"; exit 1; }
 echo "$t: $(tail -1 $t.log)"
done
