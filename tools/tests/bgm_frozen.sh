#!/bin/sh
# R156 (on purpose): "is BackgroundMusic.client.lua exactly the file R156 froze?" Older suites assert that the music script is untouched since their base; the owner's
# R156 music change (the track playlist, three base tracks) is the one change they accept, and only that one: the file passes when its sha256 is the one that
# docs/proposals/R151/tests/frozen.sha256 lists for it. Any other edit changes the hash and falls back to the suite's own "unchanged since the base" check.
# Usage: sh bgm_frozen.sh <repo> [file]     (file: a copy of the script to check instead of the repo's own)  -> exit 0 when it is the frozen one
REPO=${1:?repo root}
F=src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua
FILE=${2:-$REPO/$F}
have=$(sha256sum "$FILE" 2>/dev/null | cut -d' ' -f1)
[ -n "$have" ] || exit 1
grep -v '^#' "$REPO/docs/proposals/R151/tests/frozen.sha256" | grep -q "^$have  $F\$"
