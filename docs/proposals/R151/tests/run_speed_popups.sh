#!/bin/sh
# Usage: sh run_speed_popups.sh [scratch dir] [all]. R151 treadmill speed popups ("proposed + split") on the Roblox mock (/opt/luau/luau) with the REAL
# SpeedGainPopup.client.lua (popups + the V134 belt arrows that share the script) and the REAL SpeedPopupStyle:
#  static            - the popup half of the script has no TweenService, task.delay / defer / spawn, Heartbeat or Stepped, creates no Instance outside the pool builders,
#                      has ONE RenderStepped connection site; the belt-arrows half (from "-- V134") is byte for byte what it was before R151 (sha256 in speed_popups_frozen.sha256);
#                      Config.TreadmillPopupLifetime and the SpeedGainPopup remote are untouched; SpeedPopupStyle is in src/MANIFEST.tsv (sorted); TreadmillFx is untouched by this
#                      round; no model names in the new files; every script compiles.
#  test_speed_popups_style  - the pure curves at sample times against the numbers measured in the reference clip (pop, fling, hold, fade, life), retire, plans (7 shuffled
#                      slots), caps per tier (own 8 / 6 / 4, others 3 / 2 / 1), Reduced Motion, splitting an award (exact sum, every share >= 1, 10 a second at the 1/5 s step), spacing, units,
#                      bad numbers, the formatted text unchanged, our colours / font / bolt unchanged, the approved numbers.
#  test_speed_popups_client - the real client: pooling and the one updater, the curves read off the real frames, caps per tier (and FastMode = tier 1), the split sum, other
#                      players (range, caps, not split), Reduced Motion, a player leaving or resetting, hostile events, units, colours, the belt arrows, and no leak / no churn after
#                      10,000 awards (no Instance built or destroyed, no tween, no task.delay, flat memory, one RenderStepped listener).
# "all" also runs the suites that must stay green: R150 run_all.sh (bonus UI + R123 treadmill bonus + R128 / R129 / R137 / R138), R150 run_sfx.sh, R117 treadmills.
# "mutate" runs the mutation checks: deliberate breakages of the script / style, each of which must make a suite fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
S=$REPO/src;P=$REPO/docs/proposals;T=$REPO/tools/tests
SCRIPT=$S/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua
fail(){ echo "FAIL: $1";exit 1; }
echo "== static checks"
# 1. the popup half of the script is cheap by construction
n=$(grep -n '^-- V134:' "$SCRIPT" | cut -d: -f1);[ -n "$n" ] || fail "the V134 belt block marker is gone"
head -n $((n-2)) "$SCRIPT" > "$OUT/popup_half.lua"
# (R153 jitter: the belt arrows move every frame on a near belt in view; the sha below is of the block with that edit put back: undo_jitter153.py)
python3 "$P/R153/tests/undo_jitter153.py" "$SCRIPT" "$OUT/popup_undone.lua" || fail "the R153 jitter edits of SpeedGainPopup changed (undo_jitter153.py)"
m=$(grep -n '^-- V134:' "$OUT/popup_undone.lua" | cut -d: -f1);tail -n +$((m-1)) "$OUT/popup_undone.lua" > "$OUT/belt_half.lua"
code=$(grep -v '^[[:space:]]*--' "$OUT/popup_half.lua")
for pat in 'Tween' 'task\.delay' 'task\.defer' 'task\.spawn' 'task\.wait' 'Heartbeat' '[^r]Stepped' 'PreSimulation' 'PostSimulation'; do
 if printf '%s\n' "$code" | grep -Eq "$pat"; then fail "the popup half of SpeedGainPopup uses $pat"; fi
done
[ "$(printf '%s\n' "$code" | grep -c 'RenderStepped:Connect')" = 1 ] || fail "the popup half must connect RenderStepped in exactly one place"
[ "$(printf '%s\n' "$code" | grep -c 'Instance.new')" = 8 ] || fail "the popup half must create Instances in the pool builders only (TextLabel, UIStroke, Frame, UIListLayout, UIScale, BillboardGui = 6 sites; R155: the field's zoom Frame and its UIScale = 8)"
echo "ok: the popup half: no TweenService, task.*, Heartbeat; one RenderStepped connection site; Instances only in the pool builders"
# 2. the belt arrows are untouched
(cd "$OUT" && sha256sum belt_half.lua) > "$OUT/belt.sha"
want=$(cut -d' ' -f1 "$HERE/speed_popups_frozen.sha256");have=$(cut -d' ' -f1 "$OUT/belt.sha")
[ "$want" = "$have" ] || fail "the belt arrows block of SpeedGainPopup changed (sha256 $have, expected $want)"
echo "ok: the belt arrows (V134) block is byte for byte what it was before R151"
# 3. the server side did not move
grep -q '^Config.TreadmillPopupLifetime = 1.35$' "$S/ServerScriptService/ChestChaseServer/Config.lua" || fail "Config.TreadmillPopupLifetime changed"
grep -q 'SpeedGainPopupRemote = "SpeedGainPopup"' "$S/ServerScriptService/ChestChaseServer/Config.lua" || fail "Config.SpeedGainPopupRemote changed"
grep -q 'self.SpeedGainRemote:FireAllClients(player, actualGain, speed.Value,' "$S/ServerScriptService/ChestChaseServer/BaseService.lua" || fail "the remote's payload changed"
echo "ok: Config.TreadmillPopupLifetime, the remote's name and its payload are as before"
# 4. manifest, compile, no model names
grep -q "^ModuleScript	ReplicatedStorage/SpeedPopupStyle	ReplicatedStorage/SpeedPopupStyle.lua$" "$S/MANIFEST.tsv" || fail "SpeedPopupStyle is not in src/MANIFEST.tsv"
tail -n +2 "$S/MANIFEST.tsv" | cut -f2 > "$OUT/manifest_paths.txt";LC_ALL=C sort -c "$OUT/manifest_paths.txt" || fail "src/MANIFEST.tsv is not sorted"
for f in "$SCRIPT" "$S/ReplicatedStorage/SpeedPopupStyle.lua" "$HERE/test_speed_popups_style.luau" "$HERE/test_speed_popups_client.luau" "$HERE/speed_popups_world.luau";do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || fail "$f does not compile"
done
if grep -rniE "claude|opus|sonnet|haiku|anthropic|gpt" "$SCRIPT" "$S/ReplicatedStorage/SpeedPopupStyle.lua" "$HERE/test_speed_popups_style.luau" "$HERE/test_speed_popups_client.luau" "$HERE/speed_popups_world.luau" "$HERE/speed_popups_frozen.sha256" "$HERE/mkbundle_speed_popups.py" "$P/R151/speed_popups.md" "$P/R151/speed_popups/"*.luau "$P/R151/speed_popups/"*.py "$P/R151/speed_popups/"*.mjs "$P/R151/speed_popups/"*.html; then fail "a model name in the speed popup files"; fi
echo "ok: SpeedPopupStyle is in src/MANIFEST.tsv (sorted), every new script compiles, no model names"
if git -C "$REPO" rev-parse -q --verify d54d626 >/dev/null 2>&1; then
 git -C "$REPO" diff --quiet d54d626 -- src/ReplicatedStorage/TreadmillFx.lua src/ReplicatedStorage/TreadmillBonusStyle.lua src/ReplicatedStorage/ClientFxBudget.lua || echo "note: TreadmillFx / TreadmillBonusStyle / ClientFxBudget differ from d54d626 (not this round's change if you rebased)"
fi
echo "== suites"
cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE/speed_popups_world.luau" "$HERE/test_speed_popups_style.luau" "$HERE/test_speed_popups_client.luau" "$OUT/"
python3 "$HERE/mkbundle_speed_popups.py" "$OUT" >/dev/null
cd "$OUT"
for t in test_speed_popups_style test_speed_popups_client;do
 timeout 900 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;echo "$t FAILED";exit 1; }
 echo "$t: $(grep -v '^WARN' $t.log | tail -1)"
done
if [ "$MODE" = "all" ];then
 echo "######## R150 run_all (bonus UI, R123 treadmill bonus, R128 / R129 / R137 / R138)"
 sh "$P/R150/tests/run_all.sh" "$OUT/r150all" | tail -12
 echo "######## R150 run_sfx"
 sh "$P/R150/tests/run_sfx.sh" "$OUT/sfx" | tail -4
 echo "######## R117 treadmills"
 mkdir -p "$OUT/r117";cp "$T/roblox.luau" "$OUT/r117/";BASE=25396f1;git -C "$REPO" cat-file -e $BASE 2>/dev/null || BASE=67c9260 # (the R117 base commit is not in a shallow checkout: the oldest BiomeVisuals there is is used)
 git -C "$REPO" show $BASE:src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua > "$OUT/r117/base_BiomeVisuals.lua"
 python3 "$T/bundle.py" "$OUT/r117/tread_bundle.luau" BiomeVisuals="$S/ServerScriptService/ChestChaseServer/BiomeVisuals.lua" BiomeVisualsBase="$OUT/r117/base_BiomeVisuals.lua" \
  TreadmillFx="$S/ReplicatedStorage/TreadmillFx.lua" TreadmillAnimation="$S/StarterPlayer/StarterPlayerScripts/TreadmillAnimation.client.lua" >/dev/null
 cp "$P/treadmills_R117/tests/test_treadmills.luau" "$OUT/r117/"
 (cd "$OUT/r117" && /opt/luau/luau test_treadmills.luau > t.log 2>&1 || { tail -20 t.log;echo "R117 treadmills FAILED";exit 1; };tail -1 t.log)
fi
if [ "$MODE" = "mutate" ];then python3 "$HERE/mutation_speed_popups.py" "$OUT/mut";fi
echo "R151 speed popups suites passed"
