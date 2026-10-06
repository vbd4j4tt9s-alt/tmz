#!/bin/sh
# Runs every suite (64 at R151; R152 adds keepers, the Void giveaway, the seed opening, the whole-game z-fighting sweep, the performance patch's look / sound fingerprints and the sale money that flies to the balance by itself). Usage: REPO=<checkout> LOGDIR=<dir> PLACE=<owner place .rbxl> sh tools/tests/run_all_suites.sh ; results in $LOGDIR/summary.txt (one PASS/FAIL line per suite).
REPO=${REPO:-/home/user/tmz}; cd $REPO
L=${LOGDIR:-/tmp/suites}; mkdir -p $L
R=docs/proposals/R151/tests
for r in docs/proposals/*/tests/run.sh docs/proposals/wall_notifier_R122/tests/run_wall.sh docs/proposals/R147/tests/run_*.sh docs/proposals/R148/tests/run_*.sh docs/proposals/R149/tests/run_tiger_gear.sh docs/proposals/R149/tests/run_weather.sh docs/proposals/R149/tests/run_fruit_models.sh docs/proposals/R149/tests/run_verity.sh docs/proposals/R149/tests/run_verity_pack.sh docs/proposals/R149/tests/run_keyboard.sh docs/proposals/R149/tests/run_growth.sh docs/proposals/R149/tests/run_market.sh docs/proposals/R149/tests/run_zfight.sh docs/proposals/R150/tests/run_bonus_ui.sh docs/proposals/R150/tests/run_pedestal.sh docs/proposals/R150/tests/run_sfx.sh $R/run_hub_displays.sh $R/run_announce.sh $R/run_rare_pull.sh $R/run_packs.sh $R/run_base_area.sh $R/run_perf.sh $R/run_offline.sh $R/run_fruit_fixes.sh $R/run_verity_pouch.sh $R/run_pack_shapes.sh $R/run_cloudy.sh $R/run_hub_trees.sh $R/run_speed_popups.sh $R/run_treadmills.sh $R/run_badges.sh docs/proposals/R152/tests/run_void_giveaway.sh $R/static_checks.sh docs/proposals/R152/tests/run_keepers.sh docs/proposals/R152/tests/run_load_guard.sh docs/proposals/R152/tests/run_zfight_sweep.sh docs/proposals/R152/tests/run_seed_opening.sh docs/proposals/R152/tests/run_perf152.sh docs/proposals/R152/tests/run_sale_money.sh docs/proposals/R153/tests/run_clover.sh; do
 name=$(echo $r | cut -d/ -f3)$(basename $r .sh | sed "s/^run$//")
 case $name in keeper_looks_R123|strikes_R123) continue;; esac
 arg=$L/w_$name; case $name in perf_R121|trails_R117|trails_R118|R151static_checks) arg=$REPO;; R149run_zfight) arg="$L/w_$name ${PLACE:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl} 3484f31";; R152run_zfight_sweep) arg="$L/w_$name ${PLACE:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}";; R152run_seed_opening) arg="$L/w_$name only";; R152run_perf152) arg="$L/w_$name ${PLACE:-/root/.claude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/b4f113d1-sapkeyver.rbxl}";; esac
 start=$(date +%s)
 if sh $r $arg > $L/$name.log 2>&1; then st=PASS; else st=FAIL; fi
 echo "$st $name $(( $(date +%s)-start ))s :: $(grep -v '^WARN' $L/$name.log | grep -iE 'checks|passed|fail|mismatch' | tail -4 | tr '\n' ' ')" >> $L/summary.txt
 rm -rf "${L:?}/w_$name"
done
git checkout -- docs/proposals/shop_R120/renders 2>/dev/null; rm -f docs/proposals/shop_R120/renders/portrait_375x667_money.png
echo DONE >> $L/summary.txt
