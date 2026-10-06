#!/bin/sh
# Usage: sh run_treadmills.sh [scratch dir] [place.rbxl] [all | mutate]
# R151 treadmill polish (owner: "works we can implement the treadmill polishes"; "adjust the steps per second on top of the treadmill to multples of 5";
# "for numnbers obvere 1000 it willl be read as 1k"), on the Roblox mock (/opt/luau/luau, tools/tests/roblox.luau via the R149 zfight_world):
#  static              - the new / changed scripts compile; TreadmillLook151 and TreadmillBeltArt151 are in src/MANIFEST.tsv (sorted); the speed popup code is
#                        untouched (TreadmillAnimation.client.lua as at 19d05d4; R153: SpeedGainPopup.client.lua and SpeedPopupStyle only changed for the 2x popups the owner asked for - sizes, fan scale - plus FormatGain, the default 1/5 s step and comments); no model names.
#  test_treadmills151  - the REAL BiomeVisuals / TreadmillFx / TreadmillBeltArt151 / GardenUpgradeService / Config: every skin x level builds; every part of the
#                        machine keeps its size, place, colour and material (only the per-part flow pieces are retired, the chevrons stay); the training belt
#                        (running surface + step detection), the prompt and badge unchanged; nothing in the art or the sign collides, answers raycasts or
#                        touches; per-grade budgets (new parts, real lights of the whole machine, emitters, beams, <= 260 parts); new lights / particles / beams
#                        start off and are gated by TreadmillFx; no asset id in the machine; the belt animation is texture scroll (3.0 / 1.3 studs a second x
#                        rate, wrapped, none far / away / Reduced Motion / low quality / FastMode) and beam TextureSpeed, no new part moves; the image routes
#                        (generated with EditableImage, one per image name; uploaded ids win; the grid texture as the fallback; published); the "+N/step"
#                        label (round multiples of 5 = the real award of Config.GetTrainingAward, the rounding rule, one formatter) and its hide for the
#                        training owner; the upgrade sign (next level, gains, price colour, MAX LEVEL, the buttons unchanged); teardown and rebuilds, and a
#                        failing dressing pass that leaves the machine as before.
#  belt images         - the images the game draws are byte for byte the PNGs shipped for upload (docs/proposals/R151/treadmills/textures).
#  place + z-fighting  - Base 1 of the owner's place after the real start-up builders, every level, before (19d05d4) vs after: budgets, the belt, collision,
#                        the label, and the R149 detector (tools/zfight.py): no counted finding with a new part, none new (docs/proposals/R151/treadmills).
#  R117 treadmills     - the R117 tier suite, unchanged (it bundles BiomeVisuals without ReplicatedStorage: the machine undressed, exactly as before).
# "all" also runs the suites that must stay green: R150 run_all.sh (bonus UI + R123 treadmill bonus + R128 / R129 / R137 / R138), R150 run_sfx.sh and
# run_pedestal.sh, R151 run_base_area.sh, run_speed_popups.sh and run_cloudy.sh, R149 run_zfight.sh. "mutate" runs mutation_treadmills.py: 12
# deliberate breakages of a copy of src/ (scroll speed, label hide, a solid part, kept flow pieces, the step length, the formatter, the light cap, an image,
# the grid fallback, the sign colour, scrolling far away, the belt collider), each of which must make the suite fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};MODE=$3
S=$REPO/src;P=$REPO/docs/proposals;T=$REPO/tools/tests;BASE=19d05d4
mkdir -p "$OUT/t"
fail(){ echo "FAIL: $1";exit 1; }
echo "== static checks"
NEW="$S/ReplicatedStorage/TreadmillLook151.lua $S/ReplicatedStorage/TreadmillBeltArt151.lua"
for f in $NEW "$S/ReplicatedStorage/TreadmillFx.lua" "$S/ReplicatedStorage/SpeedPopupStyle.lua" "$S/ReplicatedStorage/BalanceValues81.lua" \
 "$S/ServerScriptService/ChestChaseServer/BiomeVisuals.lua" "$S/ServerScriptService/ChestChaseServer/GardenUpgradeService.lua" "$S/ServerScriptService/ChestChaseServer/BaseService.lua" \
 "$HERE/test_treadmills151.luau" "$P/R151/treadmills/treadmill_scene.luau";do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || fail "$f does not compile"
done
for n in TreadmillLook151 TreadmillBeltArt151;do grep -q "^ModuleScript	ReplicatedStorage/$n	ReplicatedStorage/$n.lua$" "$S/MANIFEST.tsv" || fail "$n is not in src/MANIFEST.tsv";done
tail -n +2 "$S/MANIFEST.tsv" | cut -f2 > "$OUT/manifest_paths.txt";LC_ALL=C sort -c "$OUT/manifest_paths.txt" || fail "src/MANIFEST.tsv is not sorted"
if git -C "$REPO" rev-parse -q --verify $BASE >/dev/null 2>&1;then
 sh "$T/r152_real_diff.sh" "$REPO" $BASE "$S/StarterPlayer/StarterPlayerScripts/TreadmillAnimation.client.lua" >/dev/null || fail "the treadmill animation changed" # (the R152 load guard line aside)
 # R153 (owner: "numbers should also be bigger", then "2x bigger"): the speed popups are 2x. SpeedGainPopup.client.lua changed in exactly three places (the pooled popup carries the fan's
 # size on this screen, FanX / FanY, and apply() multiplies by it: SpeedPopupStyle.FanScale) and SpeedPopupStyle in its sizes (Size, StrokeThickness), the pooled field (Field), the fan
 # numbers (Fan) and FanScale; everything else of both must still be what it was at $BASE (the motion curves, the rate, the colours, the formatting).
 git -C "$REPO" show $BASE:src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua > "$OUT/popup_base.lua"
 python3 - "$OUT/popup_base.lua" "$S/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua" <<'EOF' || fail "SpeedGainPopup.client.lua changed outside the R153 fan scale (the load guard line aside)"
import sys
skip = ("R152: start once the whole game has arrived",)
def norm(text):
    return '\n'.join(l for l in text.split('\n') if not any(s in l for s in skip))
old = norm(open(sys.argv[1], encoding='utf-8').read())
new = norm(open(sys.argv[2], encoding='utf-8').read())
undo = [  # the three R153 edits, put back as they were at the base
    ("Unit = 1, FanX = 1, FanY = 1, PX = 0,", "Unit = 1, PX = 0,"),
    ("\tx, y = x * unit * popup.FanX, y * unit * popup.FanY -- (R153: the fan's size on this screen, SpeedPopupStyle.FanScale)", "\tx, y = x * unit, y * unit"),
    ("\tlocal viewport = camera and camera.ViewportSize\n\tpopup.Unit = Style.Unit(viewport and viewport.Y)\n\tpopup.FanX, popup.FanY = Style.FanScale(viewport and viewport.X, viewport and viewport.Y)", "\tpopup.Unit = Style.Unit(camera and camera.ViewportSize.Y)"),
]
for a, b in undo:
    assert new.count(a) == 1, a
    new = new.replace(a, b)
sys.exit(0 if old == new else 1)
EOF
 git -C "$REPO" show $BASE:src/ReplicatedStorage/SpeedPopupStyle.lua > "$OUT/style_base.lua"
 python3 - "$OUT/style_base.lua" "$S/ReplicatedStorage/SpeedPopupStyle.lua" <<'EOF' || fail "SpeedPopupStyle changed outside FormatGain, the 1/5 s step and the R153 sizes / fan"
import re, sys
def cut(s, head):  # a whole function: from its header line to the next line that is just "end"
    a = s.index(head); b = s.index('\nend\n', a) + 5
    return s[:a] + s[b:]
def strip(path):
    s = open(path, encoding='utf-8').read()
    s = cut(s, 'function S.FormatGain(amount)')                   # FormatGain itself (the owner's K / M request)
    if 'function S.FanScale(' in s:
        s = cut(s, 'function S.FanScale(')                        # R153: the fan's size on this screen (does not exist at the base)
    s = s.replace('num(interval, 1 / 6)', 'num(interval, STEP)').replace('num(interval, 1 / 5)', 'num(interval, STEP)')   # the default step: 1/6 -> 1/5 s
    out = []
    for line in s.split('\n'):
        line = re.sub(r'\s*--.*$', '', line)                      # comments may change (the cadence note: 10 a second at the 1/5 s step)
        # R153 (owner: "numbers should also be bigger", then "2x bigger"): the popup sizes, the outline, the pooled field and the fan numbers are new values
        if re.match(r'^S\.(Size|StrokeThickness|Field|Fan) = ', line.strip()):
            continue
        if line.strip():
            out.append(line)
    return '\n'.join(out)
sys.exit(0 if strip(sys.argv[1]) == strip(sys.argv[2]) else 1)
EOF
 echo "ok: TreadmillAnimation.client.lua as at $BASE; SpeedGainPopup.client.lua and SpeedPopupStyle changed only in the R153 2x popups (sizes, outline, field, fan scale), FormatGain, the default step (1/5 s) and comments"
fi
if grep -niE "claude|opus|sonnet|haiku|anthropic|gpt" $NEW "$HERE/test_treadmills151.luau" "$HERE/check_belt_images.py" "$HERE/mutation_treadmills.py" "$P/R151/treadmills.md" "$P/R151/treadmills/"*.luau "$P/R151/treadmills/"*.py "$P/R151/treadmills/"*.mjs "$P/R151/treadmills/"*.html;then fail "a model name in the treadmill files";fi
echo "ok: everything compiles, the two modules are in src/MANIFEST.tsv (sorted), no model names"
echo "== test_treadmills151"
cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/R149/tests/zfight_world.luau" "$HERE/test_treadmills151.luau" "$OUT/t/"
python3 "$P/R149/tests/zfight_bundle.py" "$S" "$OUT/t" >/dev/null
(cd "$OUT/t" && timeout 900 /opt/luau/luau test_treadmills151.luau > test.log 2>&1) || { grep -E '^(FAIL|ok)|rror|stack' "$OUT/t/test.log" | grep -v '^ok' | tail -30;fail "test_treadmills151"; }
grep -E '^(FAIL|BUDGET|GAINS)' "$OUT/t/test.log" || true
grep 'R151 treadmills:' "$OUT/t/test.log"
echo "== belt images"
python3 "$HERE/check_belt_images.py" "$OUT/t/test.log" "$REPO" "$OUT/images"
if [ -f "$PLACE" ];then
 echo "== the owner's place: every level before ($BASE) vs after, budgets, collision, label, z-fighting"
 SKIP_RENDER=1 sh "$P/R151/treadmills/run_treadmill_preview.sh" "$OUT/place" "" "$PLACE" "$BASE" > "$OUT/place.log" 2>&1 || { grep -E 'FAIL|rror' "$OUT/place.log" | head -20;fail "the place scenes"; }
 grep -E '^(FAIL|L[0-9] z-fighting)|checks:' "$OUT/place.log"
else echo "(no place file at $PLACE: the place scenes were skipped)";fi
echo "== R117 treadmills (unchanged suite: the machine undressed)"
mkdir -p "$OUT/r117";cp "$T/roblox.luau" "$OUT/r117/";R117BASE=25396f1;git -C "$REPO" cat-file -e $R117BASE 2>/dev/null || R117BASE=67c9260
git -C "$REPO" show $R117BASE:src/ServerScriptService/ChestChaseServer/BiomeVisuals.lua > "$OUT/r117/base_BiomeVisuals.lua"
python3 "$T/bundle.py" "$OUT/r117/tread_bundle.luau" BiomeVisuals="$S/ServerScriptService/ChestChaseServer/BiomeVisuals.lua" BiomeVisualsBase="$OUT/r117/base_BiomeVisuals.lua" \
 TreadmillFx="$S/ReplicatedStorage/TreadmillFx.lua" TreadmillAnimation="$S/StarterPlayer/StarterPlayerScripts/TreadmillAnimation.client.lua" >/dev/null
cp "$P/treadmills_R117/tests/test_treadmills.luau" "$OUT/r117/"
(cd "$OUT/r117" && /opt/luau/luau test_treadmills.luau > t.log 2>&1) || { tail -20 "$OUT/r117/t.log";fail "R117 treadmills"; }
tail -1 "$OUT/r117/t.log"
if [ "$MODE" = "all" ];then
 echo "######## R150 run_all (bonus UI, R123 treadmill bonus, R128 / R129 / R137 / R138)";sh "$P/R150/tests/run_all.sh" "$OUT/r150all" | tail -3
 echo "######## R150 run_sfx";sh "$P/R150/tests/run_sfx.sh" "$OUT/sfx" | tail -2
 echo "######## R150 run_pedestal";sh "$P/R150/tests/run_pedestal.sh" "$OUT/ped" | tail -2
 echo "######## R151 run_speed_popups";sh "$HERE/run_speed_popups.sh" "$OUT/popups" | tail -2
 echo "######## R151 run_cloudy";sh "$HERE/run_cloudy.sh" "$OUT/cloudy" | tail -2
 echo "######## R151 run_base_area";sh "$HERE/run_base_area.sh" "$OUT/base_area" "$PLACE" | tail -2
 echo "######## R149 run_zfight";sh "$P/R149/tests/run_zfight.sh" "$OUT/zfight" "$PLACE" | tail -3
fi
if [ "$MODE" = "mutate" ];then echo "== mutations";python3 "$HERE/mutation_treadmills.py" "$OUT/mut";fi
echo "R151 treadmill suites passed"
