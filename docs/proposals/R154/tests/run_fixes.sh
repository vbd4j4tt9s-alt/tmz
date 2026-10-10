#!/bin/sh
# Usage: sh run_fixes.sh [scratch dir] [mutate]
# R154: the two things the owner found after installing R153, on the Roblox mock (/opt/luau/luau) with the REAL scripts of this checkout:
#  1. badges  - "the number and signs in the notification bubble is also too small": the count / "9+" / "!" are set at an explicit size (NotifyBadge151.TextSize: 78% of the badge for one
#               character, 68% for "9+"), >= 60% of the badge and >= 55% of the red disc's height, inside the badge, centred, on 5 screens (computer and phones) for the INDEX count, the MENU
#               alert and the DAILY count, and not clipped by the wheel's CanvasGroup / tab row: the R151 badge suites (docs/proposals/R151/tests/run_badges.sh carries the R154 checks)
#  2. popups  - "the numbers for speed also should be kept at a consistent size throughout, reduce the size of the speed notifier number by 20% and fix the glitchyness": test_popups154.luau (R158, on purpose: the sizes are 1.5x, 53 / 48 px; the zoom cutoffs are scales, the same distances)
#               (35 / 32 px, constant size from the first frame to the last, no showing frame reused, nothing cut short in the normal stream on any tier, smooth
#               frame-by-frame flight at 30 / 60 / 144 fps; R155, section 5: "make the speed popups consistent in size so when zooming out they don't become bigger ... at a certain point it can
#               disappear": at the default camera zoom, 12.5 studs, they are the R154 size, then they follow the camera's distance (half at 25 studs), are capped at 1.3x close up, fade from 31.25 and are
#               hidden past 36.46 studs, with a smooth zoom change in flight) + the R153 popup test and the R151 speed popup suites, which follow the new numbers
#  static     - every changed script compiles at -O0 (Roblox's 200-locals limit shows only there), line 1 of every client script is still the R152 load guard (BackgroundMusic untouched),
#               Config.Version unchanged, no model names in the R154 files
# "mutate" breaks a copy of the popup code 36 ways (mutate154.py; 18 of them R155's zoom) and the badge text 3 ways (mutate_badges.py) and expects a failure each time.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2
S=$REPO/src;P=$REPO/docs/proposals;T=$REPO/tools/tests
LUAU=${LUAU:-/opt/luau/luau}
mkdir -p "$OUT"
fail(){ echo "FAIL: $1";exit 1; }
echo "== static"
for f in ReplicatedStorage/NotifyBadge151 ReplicatedStorage/SpeedPopupStyle StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client ReplicatedStorage/HudLayout \
 StarterPlayer/StarterPlayerScripts/ChestIndex.client StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client;do
 /opt/luau/luau-compile -O0 --null "$S/$f.lua" >/dev/null 2>&1 || fail "$f does not compile at -O0"
done
for f in "$HERE"/test_*.luau "$P"/R151/tests/test_indexbadge.luau "$P"/R151/tests/test_indexbadge_daily.luau "$P"/R151/tests/layout_badges.luau "$P"/R153/tests/test_popups153.luau;do
 /opt/luau/luau-compile -O0 --null "$f" >/dev/null 2>&1 || fail "$f does not compile at -O0"
done
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|anthrop[i]c|gp[t]-?[0-9]" "$HERE" "$P/R154/fixes.md" 2>/dev/null;then fail "a model name in the R154 files";fi
sh "$P/R152/tests/run_load_guard.sh" "$OUT/guard" > "$OUT/guard.log" 2>&1 || { cat "$OUT/guard.log";fail "the R152 load guard (line 1 of every client script)"; }
# Config.Version is the release step's: unchanged against the R153 release commit when it is here
if git -C "$REPO" cat-file -e 006daa1 2>/dev/null;then
 git -C "$REPO" show 006daa1:src/ServerScriptService/ChestChaseServer/Config.lua | grep 'Config.Version' | sed "s/Config.Version='V150 R15[0-9a-z]*'/Config.Version='V150 R15x'/" > "$OUT/version_base.txt"
 grep 'Config.Version' "$S/ServerScriptService/ChestChaseServer/Config.lua" | sed "s/Config.Version='V150 R15[0-9a-z]*'/Config.Version='V150 R15x'/" > "$OUT/version_now.txt"
 cmp -s "$OUT/version_base.txt" "$OUT/version_now.txt" || fail "Config.Version changed"
fi
echo "ok: the changed scripts and the R154 tests compile at -O0; line 1 of every client script is still the R152 load guard; Config.Version is unchanged; no model names"
echo "== 1. badges (R151 run_badges.sh: the text fills the bubble, sizes, reach on screen, clipping, daily)"
sh "$P/R151/tests/run_badges.sh" "$OUT/badges" > "$OUT/badges.log" 2>&1 || { grep -v '^WARN' "$OUT/badges.log" | tail -30;fail "badges"; }
grep -E "R154|checks|passed" "$OUT/badges.log" | tail -14
echo "== 2. speed popups"
D=$OUT/popups154;mkdir -p "$D"
cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R151/tests/speed_popups_world.luau" "$HERE/test_popups154.luau" "$D/"
python3 "$P/R151/tests/mkbundle_speed_popups.py" "$D" > /dev/null
(cd "$D" && timeout 900 $LUAU test_popups154.luau > popups154.log 2>&1) || { grep -v '^WARN' "$D/popups154.log" | tail -30;fail "popups (R154)"; }
grep -v '^WARN' "$D/popups154.log" | tail -2
# the R153 popup test (sizes, fan, screens, pile-up) against the R152 style as its reference
PP=$OUT/popups153;mkdir -p "$PP"
cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R153/tests/test_popups153.luau" "$PP/"
BASE152=${BASE152:-e36b71b}
git -C "$REPO" show "$BASE152:src/ReplicatedStorage/SpeedPopupStyle.lua" > "$PP/ref_style.luau" 2>/dev/null || fail "no $BASE152 (the R152 SpeedPopupStyle is the reference of the R153 popup test)"
python3 "$P/R149/tests/zfight_bundle.py" "$S" "$PP" > /dev/null
(cd "$PP" && $LUAU test_popups153.luau > popups153.log 2>&1) || { grep -v '^WARN' "$PP/popups153.log" | tail -30;fail "popups (R153 test, R154 numbers)"; }
grep -v '^WARN' "$PP/popups153.log" | tail -1
sh "$P/R151/tests/run_speed_popups.sh" "$OUT/speed_popups" > "$OUT/speed_popups.log" 2>&1 || { tail -30 "$OUT/speed_popups.log";fail "R151 speed popups"; }
grep -E "checks|passed" "$OUT/speed_popups.log" | tail -3
if [ "$MODE" = "mutate" ];then
 echo "== mutations: the suite that guards each must fail on a broken copy"
 python3 "$HERE/mutate154.py" "$OUT/mut"
 sh "$P/R151/tests/run_badges.sh" "$OUT/badges_mut" --mutations > "$OUT/badges_mut.log" 2>&1 || { grep -v '^WARN' "$OUT/badges_mut.log" | tail -20;fail "badge mutations"; }
 grep -E "mutant text_|all badge" "$OUT/badges_mut.log"
fi
echo "all R154 checks passed"
