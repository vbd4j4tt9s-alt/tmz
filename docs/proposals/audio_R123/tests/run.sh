#!/bin/sh
# Usage: sh run.sh [scratch dir]. R123 sound-sync checks on the Roblox mock (/opt/luau/luau), real modules/scripts:
#  LocalSfx same-id de-dupe, RarityRevealAudio latency catch-up, TrackRefreshSky beep + wall number on one frame,
#  ChestRunAlert alarm preloaded + played on the RUN!! frame, NotificationClient83 cue warm-up,
#  TrackHoleClient trap thud preload + FastMode dirt budget. Uses the holes_R122 mock world.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/holes_R122/tests/world.luau" "$HERE/test_sync.luau" "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
/opt/luau/luau test_sync.luau > sync.log 2>&1 || { tail -30 sync.log; exit 1; }
tail -1 sync.log
