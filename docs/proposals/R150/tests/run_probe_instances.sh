#!/bin/sh
# Usage: sh run_probe_instances.sh [scratch dir] [client.lua] [BonusGiftArt.lua]. Prints how many Instances the roll screen creates on the frame it opens and on the
# reveal frame (probe_instances.luau, the REAL client on the Roblox mock). Without the two paths it measures this checkout; pass a copy of an older client / art
# (git show <commit>:src/StarterPlayer/StarterPlayerScripts/TreadmillBonusClient.client.lua, ...:src/ReplicatedStorage/BonusGiftArt.lua) to compare.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$HERE/ui_world.luau" "$HERE/probe_instances.luau" "$OUT/"
if [ -n "$2" ] && [ -n "$3" ];then python3 "$HERE/mkbundle.py" "$OUT" TreadmillBonusClient="$2" BonusGiftArt="$3" >/dev/null
else python3 "$HERE/mkbundle.py" "$OUT" >/dev/null;fi
cd "$OUT" && /opt/luau/luau probe_instances.luau
