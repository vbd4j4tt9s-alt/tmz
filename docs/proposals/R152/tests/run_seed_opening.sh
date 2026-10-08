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
#                               one produces its reveal and ends clean; nothing leaks. R153: every opener's presentation is the full one
#                               (the short one when "Skip pack animations" is on, now and then) and plays to its end; random skips.
#  R153 (owner: "pack animations should play all the time and shouldn't stop after 2/3 times. they can skip if they want or we can add a
#  skip cutscene option in the settings"):
#  test_seed_choice.luau      - the real client scripts: the setting is OFF by default; packs opened back to back (0.1 / 1 / 3 s after the
#                               last ended, 73 in one session, one while the last card is still up) each play the FULL timeline to its end
#                               (no "quick" reveal, no session cap on the story scenes); a click / tap / Enter / B / R2 (cards) or the
#                               scene's button / keys skip to the hit, the result shows, a second press closes; the pack in the world and
#                               its sky beam jump with the card; the seed still lands in the hand on the server's time; presses that are
#                               not a choice never skip; the puller's chat line goes out at the skipped result; the setting ON gives the
#                               short version (quick card, the result card in place of the story scene) every time, OFF the full one.
#  test_seed_press.luau       - a press that skips / closes a card is never also the held tool's: planting (EconomyClient's routes, from its
#                               source), the shovel (GardenShovel), digging (TrackHoleClient), giving (FruitGiftClient) by click / tap / R2;
#                               packs and the bat (ManualActivationOnly exactly while a press would be the card's); a story scene owns every
#                               press; with no card, and once it is gone, every tool works as before.
#  test_seed_server.luau      - the server half (R151's pack harness, the real ChestService / PlayerDataService): packs opened back to back
#                               each get the full RevealDuration, the seed is committed (and announced) on the 5th click whatever the client
#                               shows, a pack equipped during a reveal goes back to the Backpack and opens after it; nothing stuck or lost.
#  (and test_seed_sync / loudness / fx check the card skips too: the hit heard on its frame, no louder than the full reveal, nothing left;
#  the setting's menu row and its saving: R151 run_announce.sh, test_settings / test_settings_client.)
# "all" (default) also runs the suites that touch the same files: R151 run_rare_pull.sh (only), R150 run_sfx.sh, R138, R151 run_announce.sh,
# R150 test_packs (in run_sfx.sh), R147 Verity UI and R149 Verity pack.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=${2:-all};mkdir -p "$OUT/cl"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src
echo "== static checks"
bad=0;for f in $(find "$S" -name '*.lua');do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
[ "$bad" = 0 ];echo "ok: every script in src/ compiles"
# (real model names / ids only, e.g. a vendor name + version or a "xx-yy-4" id; a path like /root/.claude/... is not one. The brackets keep this very line from matching itself.)
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE" "$P/R152/seed_opening.md" "$P/R152/tools" 2>/dev/null | grep -v "^Binary";then echo "FAIL: a model name in the R152 files";exit 1;fi
echo "ok: no model names in the R152 files"
INV=$P/inventory_R113/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$HERE"/*.luau "$OUT/cl/"
python3 "$P/R151/tests/mkbundle_rare.py" "$OUT/cl" all-client >/dev/null
cd "$OUT/cl"
for t in test_seed_sync test_seed_loudness test_seed_fx test_seed_stress test_seed_choice test_seed_press;do
 [ -f $t.luau ] || continue
 echo "== $t"
 timeout 1800 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;exit 1; }
 grep -v '^WARN' $t.log | tail -2
done
# R153: the server half, on R151's pack harness (the real server modules)
SRV=$OUT/srv;mkdir -p "$SRV";R151=$P/R151/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$R151/pack_shape_samples.luau" "$HERE/test_seed_server.luau" "$SRV/"
python3 "$R151/mkbundle_packs.py" "$SRV" "$S" --server >/dev/null
echo "== test_seed_server"
(cd "$SRV" && timeout 900 /opt/luau/luau test_seed_server.luau > test_seed_server.log 2>&1) || { grep -v '^WARN' "$SRV/test_seed_server.log" | tail -40;exit 1; }
grep -v '^WARN' "$SRV/test_seed_server.log" | tail -1
# R153: a skip (or the setting) is the client's own business: no reveal script calls the server, and the server's reveal length is the
# rarity's alone (SeedPackRules.GetRevealDuration, never shortened)
SP=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage
if grep -nE "FireServer|InvokeServer" "$RSD/RarePullCinematic.lua" "$RSD/RarePullCard.lua" "$RSD/RarePullRules.lua" "$RSD/RarePullWorld.lua" "$RSD/RarePullAudio.lua" "$SP/SeedPackClient.client.lua" "$SP/PackOpeningFeedback.client.lua";then echo "FAIL: a reveal script calls the server";exit 1;fi
grep -q 'local duration=PackRules.GetRevealDuration(reward.Rarity)' "$S/ServerScriptService/ChestChaseServer/ChestService.lua" || { echo "FAIL: the server's reveal length must be GetRevealDuration(rarity)";exit 1; }
if grep -nE "QuickWindow|LastRevealEnd" "$RSD"/*.lua "$SP"/*.lua;then echo "FAIL: R151's quick window is back";exit 1;fi
echo "ok: no reveal script calls the server; the server's reveal length is the rarity's own; no quick window"
if [ "$MODE" = "all" ];then
 for r in R151/tests/run_rare_pull.sh R150/tests/run_sfx.sh R138/tests/run.sh R151/tests/run_announce.sh R147/tests/run_verity_ui.sh R149/tests/run_verity_pack.sh;do
  echo "######## $r";a="$OUT/$(echo $r | tr '/' '_')";[ "$r" = "R151/tests/run_rare_pull.sh" ] && a="$a only"
  sh "$P/$r" $a 2>&1 | grep -v '^ok:' | tail -8
 done
fi
echo "R152 seed opening suites passed"
