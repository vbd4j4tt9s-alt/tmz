#!/bin/sh
# Usage: sh run_seed_opening.sh [scratch dir] [only|all]. R152 seed (pack) opening polish, on the Roblox mock (/opt/luau/luau) with the REAL
# modules / scripts of this checkout (docs/proposals/R152/seed_opening.md):
#  test_seed_loudness.luau    - loudness: every presentation played and what is heard added up frame by frame (the owner's files measured:
#                               sound_levels.luau): the mix, any single sound, whooshes, beds and the sample peak under their caps, the hit
#                               the loudest moment, the ladder growing with the tier, the voice cap, every presentation quieter than R151.
#  test_seed_sync.luau        - sync and clean-up: the sounds load when the client starts; every hit heard within 1/60 s of the frame that
#                               shows its beat (measured hits and lead-ins), whooshes swelling on each flight's fastest frame, risers ending
#                               on the silence, at 30 / 60 / 144 fps, every tier and presentation; nothing outlives its presentation; skip /
#                               abort / death / the script destroyed clean up; two fast openings hand over; the music duck; cold files; the
#                               chat line after the puller's seed.
#  test_seed_fx.luau          - the look: the client-drawn images (sizes, the same every time, see-through, seamless tiles, drawn a slice
#                               at a time, none on low quality); the stages with and without them (budgets, fallbacks); every beam /
#                               emitter / light / image anchored to its subject; the sky beam (slam, landing on its beat, ground impact,
#                               tiers); clean-up on skip / close / a second pack; smoothness at 30 and 60 fps (no pop, no kink, the same
#                               picture at both); particle and layer budgets per tier.
#  test_seed_stress.luau      - reliability: the real client scripts, a slow join, then 240 random openings (every tier, seed, pack,
#                               device; fast second packs, deaths + respawns, the tool put away, errors injected in each step): every
#                               one produces its reveal and ends clean; nothing leaks.
# "all" (default) also runs the suites that touch the same files: R151 run_rare_pull.sh (only), R150 run_sfx.sh, R138, R151 run_announce.sh,
# R150 test_packs (in run_sfx.sh), R147 Verity UI and R149 Verity pack.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=${2:-all};mkdir -p "$OUT/cl"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src
echo "== static checks"
bad=0;for f in $(find "$S" -name '*.lua');do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
[ "$bad" = 0 ];echo "ok: every script in src/ compiles"
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|anthrop[i]c|gp[t]-" "$HERE" "$P/R152/seed_opening.md" "$P/R152/tools" 2>/dev/null | grep -v "^Binary" | grep -v '/\.cla[u]de/uploads/';then echo "FAIL: a model name in the R152 files";exit 1;fi
echo "ok: no model names in the R152 files"
INV=$P/inventory_R113/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$HERE"/*.luau "$OUT/cl/"
python3 "$P/R151/tests/mkbundle_rare.py" "$OUT/cl" all-client >/dev/null
cd "$OUT/cl"
for t in test_seed_sync test_seed_loudness test_seed_fx test_seed_stress;do
 [ -f $t.luau ] || continue
 echo "== $t"
 timeout 1800 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;exit 1; }
 grep -v '^WARN' $t.log | tail -2
done
if [ "$MODE" = "all" ];then
 for r in R151/tests/run_rare_pull.sh R150/tests/run_sfx.sh R138/tests/run.sh R151/tests/run_announce.sh R147/tests/run_verity_ui.sh R149/tests/run_verity_pack.sh;do
  echo "######## $r";a="$OUT/$(echo $r | tr '/' '_')";[ "$r" = "R151/tests/run_rare_pull.sh" ] && a="$a only"
  sh "$P/$r" $a 2>&1 | grep -v '^ok:' | tail -8
 done
fi
echo "R152 seed opening suites passed"
