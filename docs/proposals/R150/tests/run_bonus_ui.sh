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
#  * R153 (owner: "remove this bonus ready bag" and "make the secret pack appear in the roll section area"): the "Ur pack is already in ur bag!" line is gone
#                        (static grep, no text on the roll screen mentions the bag, the spin text is centred between the strip and the buttons); the reel carries
#                        a Secret card 3 or 4 cards before the winner on EVERY roll (it passes under the pointer: desktop / phone / ReducedMotion; a special card is
#                        only animated while in view); the reel always stops on the server's result (never on a Secret unless the server rolled it, Skip included);
#                        the odds are the same bytes (frozen hash above + the literal table lines).
#  * test_bonus_layout - every screen size of the R123 layout test (and a few more): the button and its parts, the roll screen rows, the
#                        gift timer all fit, never overlap, text fits (conservative width model), with and without touch controls.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
cd "$REPO"
sha256sum -c "$HERE/frozen.sha256" > "$OUT/frozen.log" 2>&1 || { cat "$OUT/frozen.log";echo "frozen FAILED";exit 1; }
echo "frozen: $(grep -c ': OK' "$OUT/frozen.log") gameplay files unchanged"
# R153: the rule tables the server rolls with (and the reel is drawn from) are the same lines as in R124: the odds, their order, the Void pack, the specials, the strip size
RULES=$REPO/src/ReplicatedStorage/TreadmillBonusRules.lua
while IFS= read -r line;do
 grep -qxF -- "$line" "$RULES" || { echo "TreadmillBonusRules table line changed: $line";exit 1; }
done <<'TABLES'
B.VariantOrder={'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','EclipseReliquary'}
B.Odds={Pack01=.435,Pack02=.286,Pack03=.172,Pack04=.081,Pack05=.02,Pack06=.005,EclipseReliquary=.001}
B.Void={Variant='EclipseReliquary',Stage=7,Name='Secret',Color=Color3.fromRGB(190,144,255),Label='Void Pack'}
B.Special={Legendary=true,Mythic=true,Secret=true} -- border light-up + fanfare on the result
B.Strip={Count=46,Win=40,Pitch=112,CardWidth=104,Duration=5,ReducedDuration=1.2,ReducedLead=4,MaxTicksPerSecond=30}
TABLES
echo "odds: the rule table lines are unchanged (Secret 0.1%, 46 cards, the winner on card 40)"
# R153: the "already in ur bag" line is gone from the game
if grep -rniE "already in (ur|your) bag|SpinHint" "$REPO/src";then echo "the bonus roll's bag line is back";exit 1;fi
echo "R153: no 'already in ur bag' line and no SpinHint left in src"
# R153: the embedded pack picture stays small (the owner's limit: about 20 KB) and nothing is uploaded for it
size=$(wc -c < "$REPO/src/ReplicatedStorage/BonusPackImage153.lua")
[ "$size" -lt 20000 ] || { echo "BonusPackImage153 is $size bytes (limit 20000)";exit 1; }
if grep -rn "rbxassetid" "$REPO/src/ReplicatedStorage/BonusPackImage153.lua" "$REPO/src/ReplicatedStorage/EmbeddedImage153.lua";then echo "the pack picture must be data, not an upload";exit 1;fi
echo "R153: BonusPackImage153 is $size bytes (under 20000), no uploaded asset id"
SVC=$REPO/src/ServerScriptService/ChestChaseServer/TreadmillBonusService.lua
for msg in "SEED BAG FULL! Make room - your roll stays ready." "Please try again." "Please wait a moment." "No bonus roll ready yet." "YOUR DATA IS STILL LOADING" "Bonus packs are unavailable right now.";do
 grep -qF "$msg" "$SVC" || { echo "server string missing (TreadmillBonusStyle.Flash maps it): $msg";exit 1; }
done
cp "$REPO/tools/tests/roblox.luau" "$REPO/docs/proposals/treadmill_bonus_R123/tests/world.luau" "$HERE"/ui_world.luau "$HERE"/test_bonus_*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
for t in test_bonus_style test_bonus_ui test_bonus_audio test_bonus_layout test_bonus_image;do
 [ -f $t.luau ] || continue
 /opt/luau/luau $t.luau > $t.log 2>&1 || { tail -40 $t.log;echo "$t FAILED";exit 1; }
 echo "$t: $(tail -1 $t.log)"
done
