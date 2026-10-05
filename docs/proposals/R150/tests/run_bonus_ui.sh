#!/bin/sh
# Usage: sh run_bonus_ui.sh [scratch dir]. R150 treadmill bonus UI (button, gift timer, roll screen) on the Roblox mock with the REAL
# TreadmillBonusClient, TreadmillBonusStyle, BonusGiftArt, TreadmillBonusRules and HudLayout:
#  * frozen        - the gameplay files (TreadmillBonusRules, TreadmillBonusService) are byte-identical to R149 (sha256 list in frozen.sha256),
#                    and every server error string TreadmillBonusStyle.Flash shortens still exists in the service.
#                    (R151 changed ONE line of TreadmillBonusService, after AddChest in Roll: OwnerTestPacks.Claim marks the pack of a roll that an owner "bonus"
#                    command made ready as a TEST pack; frozen.sha256 holds the hash with that line. Nothing about rolls, odds or timing changed.)
#  * test_bonus_style  - copy / state / timeline functions and the shape builders (gift fill, bow, rays, stripes, bursts, candy buttons).
#  * test_bonus_ui     - button states (charging / almost / ready / count), press, refusals, gift timer states (normal / almost / ready pop /
#                        full), roll flow for all seven rarities (spin, status line, reveal word, rays, confetti, close caption, again), ReducedMotion,
#                        low quality, no per-frame work when idle, teardown, no leaks over repeated rolls.
#                        R150 review fixes: the reveal confetti is drawn under the ribbon header (Sibling draw order, every frame, desktop and phone), the reveal word
#                        and the HUD button pop about their centres, Denied on every refusal and never on a roll that starts, no twinkle on the fine print, the gift
#                        timer's shadow follows its pop and shake, the roll opens with fewer instances (gloss for special cards only, one Frame per sparkle).
#  * test_bonus_layout - every screen size of the R123 layout test (and a few more): the button and its parts, the roll screen rows, the
#                        gift timer all fit, never overlap, text fits (conservative width model), with and without touch controls.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cd "$REPO"
sha256sum -c "$HERE/frozen.sha256" > "$OUT/frozen.log" 2>&1 || { cat "$OUT/frozen.log";echo "frozen FAILED";exit 1; }
echo "frozen: $(grep -c ': OK' "$OUT/frozen.log") gameplay files unchanged"
SVC=$REPO/src/ServerScriptService/ChestChaseServer/TreadmillBonusService.lua
for msg in "SEED BAG FULL! Make room - your roll stays ready." "Please try again." "Please wait a moment." "No bonus roll ready yet." "YOUR DATA IS STILL LOADING" "Bonus packs are unavailable right now.";do
 grep -qF "$msg" "$SVC" || { echo "server string missing (TreadmillBonusStyle.Flash maps it): $msg";exit 1; }
done
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$HERE"/ui_world.luau "$HERE"/test_bonus_*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
for t in test_bonus_style test_bonus_ui test_bonus_audio test_bonus_layout;do
 [ -f $t.luau ] || continue
 /opt/luau/luau $t.luau > $t.log 2>&1 || { tail -40 $t.log;echo "$t FAILED";exit 1; }
 echo "$t: $(tail -1 $t.log)"
done
