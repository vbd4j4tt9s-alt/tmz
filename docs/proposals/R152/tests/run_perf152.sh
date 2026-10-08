#!/bin/sh
# Usage: sh run_perf152.sh [scratch dir] [place.rbxl]
# R152 performance patch (owner: "do a performance patch after everything is done make sure performance patch doesn't change look and feel or unexpectedly
# revert the change that u did"). The look / sound fingerprints of two sides on the Roblox mock (/opt/luau/luau) with the REAL scripts of each side
# (docs/proposals/R152/perf.md):
#  * default: this checkout against THE SAME checkout with the patch switched off (perf152_off.py: PropCache152 / ViewCull152 replaced by pass-throughs,
#    every inline guard of the patch undone). Texts reworded later, a rebuilt tutorial or anything else that lands after R152 is on both sides, so only
#    the patch is compared. If the patch's guarded lines are edited, perf152_off.py stops the run and names them.
#  * PERF_BASE=<commit> (the patch's own verdict: PERF_BASE=1e7dced, the R152 candidate): that commit (git archive) against this checkout, with the
#    candidate's static rules (the load guard where the candidate has it, Config.Version unchanged). PERF_BASE=1e7dced PERF_NOW_OFF=1: the candidate
#    against this checkout switched off (no difference may show at all: a check of perf152_off.py)
#  0. static   - every changed script compiles, no model names in the perf files, the two helpers' unit checks (+ the PERF_BASE rules above)
#  1. hub      - perf152_world.luau MODE=hub on the owner's place (every start-up builder, the hub decor, the market and the Fruit of the Hour pedestal, the
#                treadmills, the two displays empty / with champions, the Void giveaway pedestal + its client, HubLife151 per tier 1 / 2 / 3): the whole world
#                once, then the moving parts every 4 frames from 7 camera poses (the displays' items are left out while they are provably off screen)
#  2. keyboard - perf152_world.luau MODE=kb per tier: standing at 7 sample rows (every biome), looking along / back / across / down, then a run and a turn
#  3. keepers  - perf152_keepers.luau: the 7 keepers (baked R152 models and today's), BeastAnimation + KeeperFx152 per tier, asleep / waking / chasing /
#                striking / off screen, every frame
#  4. seed     - perf152_seed.luau: the real SeedPackClient + PackOpeningFeedback, every rarity on desktop / phone / low quality at 60 and 30 fps, and an
#                onlooker's Secret / King (the sky beam), every frame, and the sound schedule (which sound, when, file position, speed, volume, heard gain)
#  5. hotbar, speed popups (per tier), every pack (R151 fingerprint_packs.luau: the Verity pack, the Void pack, every design / size / coat / context)
#  (and perf152_units.luau: the two new helpers, PropCache152 and ViewCull152, on their own)
# perf152_canon.py compares each pair: what is drawn must be identical; the allowed differences (instances that are never drawn, a display item frozen
# while off screen) are listed. The PERF lines (instances, SurfaceGuis, writes per frame, Lua ms on the mock) are tabled by perf152_report.py.
# Without the place file the hub and keyboard parts are skipped.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl};BASE=${PERF_BASE:-}
JOBS=${JOBS:-4}
mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;INV=$P/inventory_R113/tests;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts
RC=0;fail(){ echo "FAIL: $1";RC=1; }
# (R153: the Void giveaway pack's pulse skips a colour write that stays inside the same 8-bit level, and a part keeps its colour as 8 bits a channel,
# so a part colour is compared at those 8 bits: R153's fingerprint options, perf153_opts.luau, unless PERF_EXTRA is set, even to nothing)
if [ -z "${PERF_EXTRA+x}" ] && [ -f "$P/R153/tests/perf153_opts.luau" ];then PERF_EXTRA=$P/R153/tests/perf153_opts.luau;fi
echo "== 0. static"
if [ -n "$BASE" ];then
echo "(base: $BASE)"
# (the load guard stays where the candidate has it: line 1 of the client scripts; Hotbar hides Roblox's backpack on line 1 and waits on line 2)
bad=0;n=0;for f in "$SP"/*.client.lua;do
 rel=src/StarterPlayer/StarterPlayerScripts/$(basename "$f")
 want=$(git -C "$REPO" show "$BASE:$rel" 2>/dev/null | grep -n "R152: start once the whole game has arrived" | head -1 | cut -d: -f1)
 have=$(grep -n "R152: start once the whole game has arrived" "$f" | head -1 | cut -d: -f1)
 [ "$want" = "$have" ] || { echo "the load guard moved in $rel (line ${want:-none} -> ${have:-none})";bad=1; };[ "$have" = 1 ] && n=$((n+1))
done
[ "$bad" = 0 ] && echo "ok: the load guard is where the candidate has it (line 1 of $n client scripts, Hotbar line 2)" || fail "load guard"
git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | grep 'Config.Version' > "$OUT/version_base.txt"
grep 'Config.Version' "$S/ServerScriptService/ChestChaseServer/Config.lua" > "$OUT/version_now.txt"
cmp -s "$OUT/version_base.txt" "$OUT/version_now.txt" && echo "ok: Config.Version unchanged" || fail "Config.Version changed"
bad=0;for f in $(git -C "$REPO" diff --name-only "$BASE" -- src | grep '\.lua$');do [ -f "$REPO/$f" ] || continue;/opt/luau/luau-compile --null "$REPO/$f" >/dev/null 2>&1 || { echo "does not compile: $f";bad=1; };done
[ "$bad" = 0 ] && echo "ok: every script changed since $BASE compiles ($(git -C "$REPO" diff --name-only "$BASE" -- src | grep -c '\.lua$') files)" || fail "compile"
else
echo "(base: this checkout with the performance patch switched off, perf152_off.py)"
bad=0;n=0;for f in $(find "$S" -name '*.lua');do n=$((n+1));/opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "does not compile: $f";bad=1; };done
[ "$bad" = 0 ] && echo "ok: every script compiles ($n files)" || fail "compile"
fi
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE"/perf152_* "$HERE/run_perf152.sh" "$P/R152/perf.md" 2>/dev/null;then fail "a model name in the perf files";else echo "ok: no model names in the perf files";fi
# the two sides --------------------------------------------------------------------------------------------------------------------------------------
rm -rf "$OUT/base_src";mkdir -p "$OUT/base_src"
if [ -n "$BASE" ];then git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base_src"
elif [ -n "$PERF_BASE_SRC" ];then mkdir -p "$OUT/base_src/src";cp -r "$PERF_BASE_SRC/." "$OUT/base_src/src/" # (R153: run_perf153.sh hands a ready base tree)
elif ! python3 "$HERE/perf152_off.py" "$S" "$OUT/base_src/src";then fail "perf152_off.py could not switch the patch off";exit 1;fi
HAVE_PLACE=0;[ -f "$PLACE" ] && HAVE_PLACE=1
[ "$HAVE_PLACE" = 1 ] && python3 "$P/R149/tools/rbxl_geom.py" --tree "$PLACE" "$OUT/place_tree.luau" Workspace/ChestChaseMap >/dev/null
prepare() { # $1 = side dir, $2 = src
 d=$1;src=$2;mkdir -p "$d/seed" "$d/keepers" "$d/hotbar" "$d/popups" "$d/packs"
 if [ "$HAVE_PLACE" = 1 ];then python3 "$HERE/perf152_world.py" "$src" "$d/world" "$OUT/place_tree.luau" >/dev/null;fi
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$HERE/rare152_env.luau" "$HERE/sound_levels.luau" "$HERE/perf152_fp.luau" "$HERE/perf152_seed.luau" "$d/seed/"
 python3 "$HERE/perf152_bundle.py" "$src" "$d/seed" all-client >/dev/null
 cp "$T/roblox.luau" "$INV/world.luau" "$HERE/keeper_mesh_mock.luau" "$HERE/perf152_fp.luau" "$HERE/perf152_keepers.luau" "$d/keepers/"
 python3 "$HERE/perf152_bundle.py" "$src" "$d/keepers" server BeastAnimation=StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua >/dev/null
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE/perf152_fp.luau" "$HERE/perf152_hotbar.luau" "$d/hotbar/"
 python3 "$HERE/perf152_bundle.py" "$src" "$d/hotbar" all-client NotificationService=ServerScriptService/ChestChaseServer/NotificationService.lua >/dev/null
 cp "$T/roblox.luau" "$INV/world.luau" "$P/R151/tests/speed_popups_world.luau" "$HERE/perf152_fp.luau" "$HERE/perf152_popups.luau" "$d/popups/"
 python3 "$HERE/perf152_bundle.py" "$src" "$d/popups" SpeedGainPopup=StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua >/dev/null
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$P/R151/tests/fingerprint_packs.luau" "$d/packs/"
 python3 "$P/R151/tests/mkbundle_packs.py" "$d/packs" "$src" >/dev/null
 # (R153: PERF_EXTRA = files put next to every driver, e.g. run_perf153.sh's perf153_opts.luau)
 for f in $PERF_EXTRA;do for e in world seed keepers hotbar popups packs;do if [ -d "$d/$e" ];then cp "$f" "$d/$e/";fi;done;done
}
prepare "$OUT/base" "$OUT/base_src/src"
# (PERF_NOW_OFF=1 with PERF_BASE=1e7dced: the "now" side is this checkout switched off; it must match the candidate with no difference at all, which
# checks perf152_off.py itself)
NOW_SRC=$S
if [ -n "$PERF_NOW_OFF" ];then python3 "$HERE/perf152_off.py" "$S" "$OUT/off_src/src" >/dev/null || { fail "perf152_off.py";exit 1; };NOW_SRC=$OUT/off_src/src;fi
prepare "$OUT/now" "$NOW_SRC"
# the two helpers on their own (PropCache152: write once / on change, by value; ViewCull152: hidden only when provably out of view)
if [ -n "$PERF_NOW_OFF" ];then echo "(the helpers' unit checks skipped: the now side has them switched off)";else
cp "$HERE/perf152_units.luau" "$OUT/now/keepers/"
if (cd "$OUT/now/keepers" && /opt/luau/luau perf152_units.luau > "$OUT/units.txt" 2>&1);then echo "ok: $(tail -n 1 "$OUT/units.txt")";else fail "the helpers' unit checks";tail -n 8 "$OUT/units.txt";fi;fi
# the runs: one line each "<dir> <output> <globals line> <driver>", both sides, JOBS at a time
: > "$OUT/jobs.txt"
# (ONLY=hub,kb,keepers,seed,hotbar,popups,packs: just those runs, for a quick look while working; the full suite runs everything)
want() { [ -z "$ONLY" ] && return 0;case ",$ONLY," in *",${1%%_*},"*) return 0;;esac;return 1; }
job() { want "$2" || return 0;for side in base now;do echo "$OUT/$side/$1|$2|$3|$4" >> "$OUT/jobs.txt";done; }
if [ "$HAVE_PLACE" = 1 ];then
 for t in 3 2 1;do for s in empty champions;do job world "hub_t${t}_$s" "MODE='hub';TIER=$t;HUB_STATE='$s'" scene.luau;done;done
 for t in 3 2 1;do job world "kb_t$t" "MODE='kb';TIER=$t;RUNNER={0,600};KB_ROWS={600,1500,2400,3300,3900,4700,5700};RUNS=true" scene.luau;done
fi
for t in 3 2 1;do for v in R152 legacy;do job keepers "keepers_t${t}_$v" "TIER=$t;VARIANT='$v'" perf152_keepers.luau;done;done
for dev in desktop phone low;do for fps in 60 30;do
 job seed "seed_${dev}_${fps}_a" "SEED_SET={{'$dev',1,$fps},{'$dev',2,$fps},{'$dev',3,$fps},{'$dev',4,$fps},{'$dev',5,$fps}}" perf152_seed.luau
 job seed "seed_${dev}_${fps}_b" "SEED_SET={{'$dev',6,$fps},{'$dev',7,$fps},{'$dev',8,$fps}}" perf152_seed.luau
done;job seed "seed_${dev}_onlooker" "SEED_SET={{'$dev',6,60,'onlooker'},{'$dev',8,60,'onlooker'}}" perf152_seed.luau;done
job hotbar hotbar "" perf152_hotbar.luau
for t in 3 2 1;do job popups "popups_t$t" "TIER=$t" perf152_popups.luau;done
job packs packs "" fingerprint_packs.luau
cat > "$OUT/run1.sh" <<'EOF'
#!/bin/sh
# one run: <dir>|<output name>|<globals>|<driver>
IFS='|' read -r d name globals driver <<END
$1
END
cd "$d" || exit 1
printf '%s\n' "$globals" > "run_$name.luau";cat "$driver" >> "run_$name.luau"
# (the dumps are kept gzipped: the frame streams of the seed opening are large)
(timeout 1800 /opt/luau/luau "run_$name.luau" 2> "$name.err";echo "EXIT $?") | gzip -1 > "$name.out.gz"
if zcat "$name.out.gz" | tail -n 1 | grep -q '^EXIT 0$';then echo "ran $d/$name";else echo "FAILED $d/$name";zcat "$name.out.gz" | tail -n 5;tail -n 5 "$name.err";fi
EOF
echo "== running $(wc -l < "$OUT/jobs.txt") runs ($JOBS at a time)"
xargs -d '\n' -P "$JOBS" -I{} sh "$OUT/run1.sh" {} < "$OUT/jobs.txt" > "$OUT/runs.log" 2>&1 || true
if grep -q '^FAILED' "$OUT/runs.log";then fail "a run failed:";grep -A6 '^FAILED' "$OUT/runs.log" | head -40;fi
# the comparisons ------------------------------------------------------------------------------------------------------------------------------------
compare() { # $1 = area name, $2 = env dir, $3... = outputs
 area=$1;env=$2;shift 2
 for n in "$@";do
  want "$n" || continue
  [ -f "$OUT/base/$env/$n.out.gz" ] && [ -f "$OUT/now/$env/$n.out.gz" ] || { fail "$area $n: no output";continue; }
  if python3 "$HERE/perf152_canon.py" "$OUT/base/$env/$n.out.gz" "$OUT/now/$env/$n.out.gz" --area "$area $n" > "$OUT/cmp_$n.txt" 2>&1;then head -1 "$OUT/cmp_$n.txt";grep '^  allowed' "$OUT/cmp_$n.txt" || true
  else fail "$area $n differs";head -60 "$OUT/cmp_$n.txt";fi
 done
}
echo "== 1. hub"
if [ "$HAVE_PLACE" = 1 ];then compare hub world hub_t3_empty hub_t3_champions hub_t2_empty hub_t2_champions hub_t1_empty hub_t1_champions;else echo "SKIPPED (no place file at $PLACE)";fi
echo "== 2. keyboard"
if [ "$HAVE_PLACE" = 1 ];then compare keyboard world kb_t3 kb_t2 kb_t1;else echo "SKIPPED (no place file at $PLACE)";fi
echo "== 3. keepers"
compare keepers keepers keepers_t3_R152 keepers_t3_legacy keepers_t2_R152 keepers_t2_legacy keepers_t1_R152 keepers_t1_legacy
echo "== 4. seed opening"
for dev in desktop phone low;do compare seed seed "seed_${dev}_60_a" "seed_${dev}_60_b" "seed_${dev}_30_a" "seed_${dev}_30_b" "seed_${dev}_onlooker";done
echo "== 5. hotbar, speed popups, packs (the Verity pack included)"
compare hotbar hotbar hotbar
compare popups popups popups_t3 popups_t2 popups_t1
if want packs;then
for side in base now;do zcat "$OUT/$side/packs/packs.out.gz" > "$OUT/$side/packs/packs.out";echo "$side $(grep '^COUNT' "$OUT/$side/packs/packs.out")";done
if python3 "$P/R151/tests/compare_fingerprints.py" "$OUT/base/packs/packs.out" "$OUT/now/packs/packs.out" --expect-only '(?!)' > "$OUT/cmp_packs.txt" 2>&1;then echo "packs: $(head -1 "$OUT/cmp_packs.txt")"
else fail "packs differ";head -30 "$OUT/cmp_packs.txt";fi
fi
echo "== numbers (before -> after)"
python3 "$HERE/perf152_report.py" "$OUT/base" "$OUT/now" || true
[ "$RC" = 0 ] && echo "R152 perf: all checks passed - the look and the sound are identical (allowed differences listed above; base: ${BASE:-the patch switched off})"
exit $RC
