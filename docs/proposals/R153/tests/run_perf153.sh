#!/bin/sh
# Usage: sh run_perf153.sh [scratch dir] [place.rbxl]
# R153 performance patch (owner: "do a performance patch after all these as its quite laggy"; rules: no look change, no feel change, no feature
# reverted). docs/proposals/R153/perf153.md. Two sides on the Roblox mock (/opt/luau/luau) with the REAL scripts of each side:
#  * default: this checkout against THE SAME checkout with the patch switched off (perf153_off.py: perf153.patch applied in reverse; the 73 retired
#    dead files stay retired on both sides, nothing loads them). PERF153_BASE=<commit>: that commit (git archive) against this checkout.
#  0. static   - every script compiles; line 1 of every client script is the R152 load guard (Hotbar: its Backpack line, then the guard);
#                Config.Version and BackgroundMusic as on the base side; the retired files are gone from src and src/MANIFEST.tsv and the manifest
#                matches the files; nothing in src names a retired module; no model names in the perf153 files
#  1. look     - the R152 fingerprints (run_perf152.sh with this base: the hub on the owner's place per tier with the displays empty / with
#                champions, the keyboard per tier, the 7 keepers per tier and state, the seed opening on desktop / phone / low incl. its SOUND
#                schedule, the hotbar, the speed popups, every pack), compared on what the engine can draw (perf153_opts.luau: part colours at
#                the 8 bits the engine keeps, Anchored / Massless left out, a gui's MaxDistance as in or out of range)
#  2. UI       - every client script started (lag153_census.luau, ALLCLIENT) on a PC (1280 x 720, tier 3) and a phone (844 x 390, touch, tier 2):
#                the whole PlayerGui fingerprinted before and after the icons' images load (IMAGES), and every sound played (FACT)
#  3. packs    - perf153_packs.luau: the track packs' outlines per tier, without / with 16 weather glows: within 150 studs identical
#  4. numbers  - lag153_census.luau (IMAGES) per tier 3 / 2 / 1 at the hub and on the track, both sides: PlayerGui instances (images loading /
#                loaded), drawn parts within 400 studs, per-frame connections, property writes per frame (the giveaway pack's own), Lua ms
#  5. units    - test_live_methods153 (which functions are live), test_skin_spread153 (D9: the spread re-skin = the one-frame re-skin),
#                test_quality153 (one quality signal = the old SettingsClient windows)
# Without the place file parts 1 (hub / keyboard), 2 and 4 are skipped.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BASE=${PERF153_BASE:-}
JOBS=${JOBS:-3}
mkdir -p "$OUT"
P=$REPO/docs/proposals;T=$REPO/tools/tests;INV=$P/inventory_R113/tests;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts;SS=$S/ServerScriptService/ChestChaseServer
RC=0;fail(){ echo "FAIL: $1";RC=1; }
HAVE_PLACE=0;[ -f "$PLACE" ] && HAVE_PLACE=1
echo "== the base side"
rm -rf "$OUT/base_src";mkdir -p "$OUT/base_src"
if [ -n "$BASE" ];then git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base_src";echo "(base: $BASE)"
elif python3 "$HERE/perf153_off.py" "$S" "$OUT/base_src/src";then :;else fail "perf153_off.py could not switch the patch off";exit 1;fi
B=$OUT/base_src/src
echo "== 0. static"
bad=0;n=0;for f in $(find "$S" -name '*.lua');do n=$((n+1));/opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "does not compile: $f";bad=1; };done
[ "$bad" = 0 ] && echo "ok: every script compiles ($n files)" || fail "compile"
bad=0;n=0;for f in "$SP"/*.client.lua;do
 b=$(basename "$f");[ "$b" = BackgroundMusic.client.lua ] && continue;n=$((n+1))
 line=1;[ "$b" = Hotbar.client.lua ] && line=2
 sed -n "${line}p" "$f" | grep -qF "R152: start once the whole game has arrived" || { echo "the load guard is not line $line of $b";bad=1; }
done
[ "$bad" = 0 ] && echo "ok: line 1 of every client script is the R152 load guard (Hotbar: line 2, after its Backpack line), $n scripts" || fail "load guard"
cmp -s "$B/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua" "$SP/BackgroundMusic.client.lua" && echo "ok: BackgroundMusic untouched" || fail "BackgroundMusic changed"
[ "$(grep 'Config.Version' "$B/ServerScriptService/ChestChaseServer/Config.lua" | sed "s/Config.Version='V150 R15[0-9a-z]*'/Config.Version='V150 R15x'/")" = "$(grep 'Config.Version' "$SS/Config.lua" | sed "s/Config.Version='V150 R15[0-9a-z]*'/Config.Version='V150 R15x'/")" ] && echo "ok: Config.Version unchanged" || fail "Config.Version changed"
retired=0;left=0
for p in ReplicatedStorage/AncientWorldrootSeedArt45 ReplicatedStorage/ElderbloomSeedArt45 ReplicatedStorage/NavigationArtwork ReplicatedStorage/TopNavigationLayout ReplicatedStorage/VectorIcons91 \
 ServerScriptService/ChestChaseServer/ActiveTraining81 StarterPlayer/StarterPlayerScripts/SpeedMilestones87 StarterPlayer/StarterPlayerScripts/ColourfulText81;do
 retired=$((retired+1));if [ -e "$S/$p.lua" ] || [ -e "$S/$p.client.lua" ] || grep -q "	$p	" "$S/MANIFEST.tsv";then echo "still there: $p";left=1;fi
done
for k in SeedPackArt SeedPackLOD SeedPackShapes;do if ls "$S"/ReplicatedStorage/$k*.lua >/dev/null 2>&1 || grep -q "	ReplicatedStorage/$k" "$S/MANIFEST.tsv";then echo "still there: $k*";left=1;fi;done
[ "$left" = 0 ] && echo "ok: the retired files (the 65 pack-art modules, 5 unused modules, the ActiveTraining81 stub, 2 do-nothing client scripts) are gone from src and its manifest" || fail "retired files"
tail -n +2 "$S/MANIFEST.tsv" | cut -f3 | LC_ALL=C sort > "$OUT/manifest_files.txt";(cd "$S" && find . -name '*.lua' | sed 's#^\./##' | LC_ALL=C sort) > "$OUT/src_files.txt"
cmp -s "$OUT/manifest_files.txt" "$OUT/src_files.txt" && echo "ok: src/MANIFEST.tsv lists exactly the $(wc -l < "$OUT/src_files.txt") files in src" || { fail "src/MANIFEST.tsv and src differ";diff "$OUT/manifest_files.txt" "$OUT/src_files.txt" | head; }
if grep -rnwE "SeedPackArt[A-Za-z]*[0-9]*|SeedPackLOD[A-Za-z]+|SeedPackShapes[A-Za-z]+|NavigationArtwork|TopNavigationLayout|VectorIcons91|AncientWorldrootSeedArt45|ElderbloomSeedArt45|SpeedMilestones87|ColourfulText81" "$S" --include=*.lua | grep -v -- "--" ;then fail "src still names a retired module";else echo "ok: no code in src names a retired module (only comments may)";fi
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE"/perf153_* "$HERE"/run_perf153.sh "$HERE"/test_*153.luau "$P/R153/perf153.md" 2>/dev/null;then fail "a model name in the perf153 files";else echo "ok: no model names in the perf153 files";fi

echo "== 1. look and sound: the R152 fingerprints, base = $( [ -n "$BASE" ] && echo "$BASE" || echo 'this checkout with the R153 perf patch switched off')"
if PERF_BASE_SRC="$B" PERF_EXTRA="$HERE/perf153_opts.luau" JOBS=$JOBS sh "$P/R152/tests/run_perf152.sh" "$OUT/fp" "$PLACE" > "$OUT/fp.log" 2>&1;then
 grep -E "^(ok|SKIPPED|R152 perf)|identical|same-visible|offscreen|^  allowed" "$OUT/fp.log" | grep -v "^ok: every script compiles" | cut -c1-220 | sort | uniq -c | sort -rn | head -40
 echo "ok: every fingerprint (hub, keyboard, keepers, seed opening and its sounds, hotbar, popups, packs) matches what is drawn"
else fail "the R152 fingerprints differ";grep -E "FAIL|DIFFERENT|differs" "$OUT/fp.log" | head -40;fi
sed -n '/^== numbers/,$p' "$OUT/fp.log" > "$OUT/fp_numbers.txt" || true

if [ "$HAVE_PLACE" = 1 ];then
 python3 "$P/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place_tree.luau" Workspace/ChestChaseMap >/dev/null
 for side in base now;do src=$S;[ "$side" = base ] && src=$B;python3 "$HERE/lag153_world.py" "$src" "$OUT/$side/cw" "$OUT/place_tree.luau" >/dev/null;done
 : > "$OUT/census_jobs.txt"
 for side in base now;do
  echo "$OUT/$side/cw|ui_pc|TIER=3;SPOT='hub';RUNNER={0,-60};ALLCLIENT=true;IMAGES=true;UISHOTS=true;VIEW={1280,720};TOUCH=false" >> "$OUT/census_jobs.txt"
  echo "$OUT/$side/cw|ui_phone|TIER=2;SPOT='hub';RUNNER={0,-60};ALLCLIENT=true;IMAGES=true;UISHOTS=true;VIEW={844,390};TOUCH=true" >> "$OUT/census_jobs.txt"
  for t in 3 2 1;do for spot in hub track;do z=1300;[ "$spot" = hub ] && z=-60
   echo "$OUT/$side/cw|n_t${t}_$spot|TIER=$t;SPOT='$spot';RUNNER={0,$z};ALLCLIENT=true;IMAGES=true" >> "$OUT/census_jobs.txt"
  done;done
 done
 cat > "$OUT/census1.sh" <<'EOF'
IFS='|' read -r d name globals <<END
$1
END
printf '%s\n' "$globals" > "$d/run_$name.luau";cat "$d/census.luau" >> "$d/run_$name.luau"
(cd "$d" && timeout 1500 /opt/luau/luau "run_$name.luau" > "$name.out" 2> "$name.err";echo "EXIT $?" >> "$name.out")
tail -n 1 "$d/$name.out" | grep -q '^EXIT 0$' && echo "ran $d/$name" || { echo "FAILED $d/$name";tail -n 3 "$d/$name.err"; }
gzip -f -1 "$d/$name.out"
EOF
 echo "== 2. UI (PC 1280 x 720 tier 3, phone 844 x 390 tier 2) before / after the images load, and the sounds; 4. numbers (running $(wc -l < "$OUT/census_jobs.txt") census runs, $JOBS at a time)"
 xargs -d '\n' -P "$JOBS" -I{} sh "$OUT/census1.sh" {} < "$OUT/census_jobs.txt" > "$OUT/census_runs.log" 2>&1 || true
 if grep -q '^FAILED' "$OUT/census_runs.log";then fail "a census run failed";grep -A3 '^FAILED' "$OUT/census_runs.log" | head -20;fi
 for v in ui_pc ui_phone;do
  if python3 "$P/R152/tests/perf152_canon.py" "$OUT/base/cw/$v.out.gz" "$OUT/now/cw/$v.out.gz" --area "UI $v" > "$OUT/cmp_$v.txt" 2>&1;then head -1 "$OUT/cmp_$v.txt";grep '^  allowed' "$OUT/cmp_$v.txt" | head -5 || true
  else fail "UI $v differs";head -40 "$OUT/cmp_$v.txt";fi
 done
else echo "SKIPPED parts 2 and 4 (no place file at $PLACE)";fi

echo "== 3. track packs: the outlines (D7)"
for side in base now;do src=$S;[ "$side" = base ] && src=$B
 d=$OUT/$side/packs;mkdir -p "$d"
 cp "$T/roblox.luau" "$INV/world.luau" "$P/R149/tests/zfight_world.luau" "$INV/fixtures.luau" "$HERE/jitter_world.luau" "$HERE/perf153_packs.luau" "$d/"
 sed "s#'/home/user/tmz/src'#'$src'#" "$INV/mkbundle.py" > "$d/mkbundle.py"
 python3 "$d/mkbundle.py" "$d/rs_bundle.luau" SeedPackRender="$src/StarterPlayer/StarterPlayerScripts/SeedPackRender.client.lua" >/dev/null
 (cd "$d" && timeout 900 /opt/luau/luau perf153_packs.luau > packs.out 2>&1) || { fail "perf153_packs ($side)";tail -5 "$d/packs.out"; }
done
if [ -f "$OUT/base/packs/packs.out" ] && [ -f "$OUT/now/packs/packs.out" ];then
 grep '^FACT near' "$OUT/base/packs/packs.out" > "$OUT/packs_near_base.txt";grep '^FACT near' "$OUT/now/packs/packs.out" > "$OUT/packs_near_now.txt"
 if [ -s "$OUT/packs_near_now.txt" ] && cmp -s "$OUT/packs_near_base.txt" "$OUT/packs_near_now.txt";then echo "ok: within 150 studs the same packs wear the same outline on every tier, with and without weather ($(wc -l < "$OUT/packs_near_now.txt") cases)"
 else fail "the near packs' outlines differ";diff "$OUT/packs_near_base.txt" "$OUT/packs_near_now.txt" | head -20;fi
 over=$(grep '^PERF packs' "$OUT/now/packs/packs.out" | sed 's/.*highlights_in_workspace=//' | awk '$1>31' | wc -l)
 [ "$over" = 0 ] && echo "ok: never more than 31 Highlights in the workspace (Roblox's limit), weather glows included" || fail "more than 31 Highlights at once"
 grep '^PERF packs' "$OUT/base/packs/packs.out" | sed 's/^PERF packs /  before: /' > "$OUT/packs_numbers.txt"
 grep '^PERF packs' "$OUT/now/packs/packs.out" | sed 's/^PERF packs /  after:  /' >> "$OUT/packs_numbers.txt"
fi

echo "== 5. units"
d=$OUT/units/live;mkdir -p "$d";cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE/clover_env.luau" "$HERE/test_live_methods153.luau" "$d/"
python3 "$HERE/mkbundle_clover.py" "$d" --src "$S" >/dev/null
if (cd "$d" && timeout 600 /opt/luau/luau test_live_methods153.luau > t.log 2>&1);then echo "ok: test_live_methods153: $(tail -n 1 "$d/t.log")";grep '^INFO never-run' "$d/t.log" | cut -c1-220;else fail "test_live_methods153";grep -v '^WARN' "$d/t.log" | tail -10;fi
d=$OUT/units/skin;mkdir -p "$d";cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$P/R151/tests/pouch_mock.luau" "$HERE/test_skin_spread153.luau" "$d/"
python3 "$P/R151/tests/mkbundle_packs.py" "$d" "$S" --server >/dev/null
if (cd "$d" && timeout 900 /opt/luau/luau test_skin_spread153.luau > t.log 2>&1);then echo "ok: test_skin_spread153: $(tail -n 1 "$d/t.log")";else fail "test_skin_spread153";grep -v '^WARN' "$d/t.log" | tail -12;fi
d=$OUT/units/quality;mkdir -p "$d";cp "$HERE/test_quality153.luau" "$d/"
if [ -n "$BASE" ];then git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/SettingsClient.client.lua" > "$d/old_settings.lua";else cp "$B/StarterPlayer/StarterPlayerScripts/SettingsClient.client.lua" "$d/old_settings.lua";fi
python3 "$HERE/textbundle153.py" "$d/quality_bundle.luau" ClientFxBudget.lua="$S/ReplicatedStorage/ClientFxBudget.lua" SettingsClient.client.lua="$SP/SettingsClient.client.lua" old_settings.lua="$d/old_settings.lua"
if (cd "$d" && timeout 300 /opt/luau/luau test_quality153.luau > t.log 2>&1);then echo "ok: test_quality153: $(tail -n 1 "$d/t.log")";else fail "test_quality153";tail -10 "$d/t.log";fi

echo "== numbers (before -> after)"
[ "$HAVE_PLACE" = 1 ] && python3 "$HERE/perf153_report.py" "$OUT/base/cw" "$OUT/now/cw" || true
[ -f "$OUT/packs_numbers.txt" ] && { echo "track packs (outlines worn by packs / weather glows / every Highlight):";cat "$OUT/packs_numbers.txt"; }
[ -s "$OUT/fp_numbers.txt" ] && { echo "the R152 hub runs (writes per frame at the plaza, a display, looking away, far; full table: $OUT/fp_numbers.txt):";grep -E "hub\.(plaza|display1|away|far) " "$OUT/fp_numbers.txt" | cut -c1-150; }
[ "$RC" = 0 ] && echo "R153 perf: all checks passed - the look and the sound are identical (allowed differences listed above; base: ${BASE:-the patch switched off})"
exit $RC
