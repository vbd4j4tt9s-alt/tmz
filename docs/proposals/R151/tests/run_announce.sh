#!/bin/sh
# Usage: sh run_announce.sh [scratch dir] [all|mutate]. R151 pull announcements, CHAT ONLY (the owner: "pull announcement should only be said in chat"), on the Roblox mock (/opt/luau/luau)
# with the REAL modules / scripts of this checkout (PullAnnounceRules, PullAnnouncer, PullAnnouncerClient, OwnerTestPacks, PlayerDataService, StudioTestCommands, OwnerUpdateCommands82,
# RarePackTests, MysteryPackService, TreadmillBonusService, DailyProgress, ChestService, SettingsConfig, SettingsClient, ...):
#  static           - the hooks in shared files are single lines, HudNotices is exactly its R150 version, the client makes no Gui / sound / tween / per-frame code, the announcer is the only
#                     user of MessagingService, no client -> server remote exists, every owner-command path that makes a pack marks it TestGrant, the list of files that add packs is
#                     the known one, every script compiles, the new scripts are in src/MANIFEST.tsv, ProfileVersion is still 22.
#  test_rules       - thresholds (Legendary in the server, Secret and above across servers, attribute overrides), event sanitising (names, ellipsis, odds, ids), the three chat lines and their
#                     colours, rich text well formed and escaped for every seed and kind, the old-chat plain line, the chat rate limit, the 1 kB payload (a pull and a hub record), freshness,
#                     no banner rule left; RevealDelay per rarity (= the latest moment the puller's client shows the seed, RarePullRules, + the margin) and RecordScope (who hears a hub record).
#  test_server      - the real PlayerDataService:OpenSeedPack hook: a real open of a Legendary+ seed is announced once the PULLER's reveal has shown the seed (to everybody in the server;
#                     timing per rarity, the other servers never earlier, a leaving puller releases it, every presentation / skip), TEST guaranteed reveals, gifted /
#                     granted seeds never are; OWNER-MADE PACKS never are: every command path (/test pack, packset, void, eclipse, verity, rarepacks x5, mystery ready, daily week, bonus
#                     roll / ready / progress) through the real StudioTestCommands.Execute, with a control for each that the same pack from a real source IS announced (Robux Mech pack, normal
#                     track pack, normal mystery / daily / bonus pack, Void -> Verity); TestGrant saved, reloaded, gifted, kept through the Verity conversion, and an R150 server loading and
#                     re-saving it (from the git history); MessagingService mock: publish limits (1 per 5 s, coalescing, 1 kB), dedupe, stale drop, failure + retry, subscription retry,
#                     the origin server not double-showing, the per-player "other servers" setting, the receive limit, malformed messages; hub records (scope per rarity, AfterReveal, private To,
#                     what other servers accept); owner commands.
#  test_client      - the real PullAnnouncerClient: chat only (no ScreenGui, no Instance, no tween, no per-frame code, no sound, no picture, no PlayerGui attribute), one correctly coloured line
#                     per event (rarity colour / gold / amber), once per id, the 8 lines per 10 s limit, rich-text escaping and long names, the old chat fallback (never both chats), hostile
#                     payloads, teardown, the puller's own line held until their own hit (RarePullClimaxAt) on a slow device.
#  test_settings    - SettingsConfig (booleans, a saved false stays false), the saved toggle (PlayerDataService save / load, PremiumService SetSetting), the announcer honouring it: it gates
#                     the 🌐 chat lines from other servers and never the lines of this server.
#  test_settings_client - SettingsClient's row (On / Off, saved as a boolean, retried, the other rows untouched).
# "all" also runs every existing suite that touches a file this release changed (see the list below). "mutate" runs mutation_check.py: deliberate breakages of the announcer / client / owner-pack
# marking, each of which must make a suite fail.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
P=$REPO/docs/proposals;S=$REPO/src;T=$REPO/tools/tests
echo "== static checks"
sh "$HERE/static_checks.sh" "$REPO"
echo "== suites"
cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R150/tests/ui_world.luau" "$HERE"/*.luau "$OUT/"
python3 "$HERE/mkbundle.py" "$OUT" >/dev/null
cd "$OUT"
for t in test_rules test_server test_client test_settings test_settings_client;do
 [ -f $t.luau ] || continue
 timeout 900 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;echo "$t FAILED";exit 1; }
 echo "$t: $(grep -v '^WARN' $t.log | tail -1)"
done
grep -h "^SKIP" test_*.log || true
if [ "$MODE" = "all" ]; then
 cd "$REPO"
 for r in R150/tests/run_sfx.sh R150/tests/run_bonus_ui.sh R150/tests/run_pedestal.sh R137/tests/run.sh R138/tests/run.sh R139/tests/run.sh R140/tests/run.sh R147/tests/run.sh R147/tests/run_verity.sh \
  R147/tests/run_verity_pack.sh R148/tests/run_roster.sh R148/tests/run_purchase.sh R148/tests/run_index_limited.sh R149/tests/run_verity.sh R149/tests/run_verity_pack.sh R132/tests/run.sh \
  treadmill_bonus_R123/tests/run.sh giving_R122/tests/run.sh holes_R122/tests/run.sh veiled_R122/tests/run.sh polish_R124/tests/run.sh shop_R120/tests/run.sh R127/tests/run.sh R129/tests/run.sh; do
  [ -f "$P/$r" ] || continue
  echo "######## $r";name=$(echo $r | tr '/' '_')
  if sh "$P/$r" "$OUT/$name" > "$OUT/$name.log" 2>&1; then tail -3 "$OUT/$name.log"; else tail -20 "$OUT/$name.log";echo "$r FAILED";exit 1; fi
 done
fi
if [ "$MODE" = "mutate" ]; then echo "== mutations";python3 "$HERE/mutation_check.py" "$OUT/mut";fi
echo "R151 announcement suites passed"
