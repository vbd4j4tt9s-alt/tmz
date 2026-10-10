#!/bin/sh
# Usage: sh run_announce_preview.sh <scratch dir>
# R151 preview -> docs/proposals/R151/announcements_chat.png: the chat lines of the pull announcements (Legendary / Mythic / Secret / Cosmic / King in this server in their rarity colours,
# a Secret+ pull in another server in gold, a record in amber). The REAL PullAnnouncerClient and PullAnnounceRules run under the Roblox mock (tools/tests/roblox.luau + the R123 world); the
# rich text each chat line carries is captured from RBXGeneral:DisplaySystemMessage and drawn in a chat window by headless Chromium (render_chat.mjs). Only the window around the lines is
# drawn by hand; the lines are exactly what the game writes.
# Needs /opt/luau, python3, node + playwright (global, PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and an emoji font (Noto Color Emoji).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd);S=${1:?scratch dir}
mkdir -p "$S"
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$HERE/chat_lines.luau" "$S/"
python3 "$HERE/../tests/mkbundle.py" "$S" >/dev/null
(cd "$S" && /opt/luau/luau chat_lines.luau > chat.log 2>&1) || { tail -20 "$S/chat.log";exit 1; }
grep '^LINE ' "$S/chat.log"
export PLAYWRIGHT_NODE_ROOT=$(npm root -g)
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers} node "$HERE/render_chat.mjs" "$S/chat.log" "$REPO/docs/proposals/R151/announcements_chat.png" 2
