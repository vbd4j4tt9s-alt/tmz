#!/bin/sh
# Usage: sh run_announce.sh [scratch dir] [all]. R151 pull announcements on the Roblox mock (/opt/luau/luau) with the REAL modules / scripts of this checkout
# (PullAnnounceRules, PullAnnouncer, PullAnnouncerClient, PlayerDataService, SettingsConfig, SettingsClient, HudNotices, RarityRevealAudio, ...):
#  static           - the hooks in shared files are single lines, the announcer is the only user of MessagingService, no client -> server remote exists,
#                     the display names are never typed text, every script compiles, the new scripts are in src/MANIFEST.tsv.
#  test_rules       - thresholds (Legendary in the server, Secret and above across servers, attribute overrides), event sanitising, the sentences, the chat line,
#                     the queue / flood rule, timing, the chat rate limit, the 1 kB payload, freshness.
#  test_server      - the real PlayerDataService:OpenSeedPack hook: a real open of a Legendary+ seed is announced after its reveal, TEST packs (rarepacks) and gifted /
#                     granted seeds never are; MessagingService mock: publish limits (1 per 5 s, coalescing, 1 kB), dedupe, stale drop, failure + retry, subscription
#                     retry, the origin server not double-showing, the per-player "other servers" setting, the receive limit, malformed messages; records; owner commands.
#  test_client      - the real PullAnnouncerClient: banner text / colours per rarity, the small other-server banner, the record banner, the queue under a flood, the
#                     headshot cache, chat lines (TextChatService and the old chat), sounds (own pull silent, Effects 0 silent), ReducedMotion, FastMode, the real
#                     HudNotices pushing its rows below the banner, no per-frame work when idle, teardown.
#  test_layout      - the banner on 26 screen sizes (touch with and without controls): inside the screen, clear of the HUD boxes, the notice rows below it, every part
#                     inside the panel, no overlaps, every text fits.
#  test_audio       - the REAL RarityRevealAudio / AudioMixer: the burst per rarity through the Effects group, your own pull and Effects 0 silent, a cold voice dropped.
#  test_settings    - SettingsConfig (booleans, a saved false stays false), the saved toggle (PlayerDataService save / load, PremiumService SetSetting), the announcer honouring it.
#  test_settings_client - SettingsClient's new row (On / Off, saved as a boolean, retried, the other rows untouched).
# "all" also runs every existing suite that touches a file this release changed (PlayerDataService, SettingsClient / SettingsConfig, HudNotices,
# OwnerUpdateCommands82, StudioTestHelp, the server main script). "mutate" runs mutation_check.py: 26 deliberate breakages of the announcer
# (TEST packs announcing, the origin server showing its own message, no stale / dedupe / rate limits, the setting ignored ...), each of which must make a suite fail.
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
for t in test_rules test_server test_client test_layout test_audio test_settings test_settings_client;do
 [ -f $t.luau ] || continue
 timeout 900 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;echo "$t FAILED";exit 1; }
 echo "$t: $(grep -v '^WARN' $t.log | tail -1)"
done
if [ "$MODE" = "all" ]; then
 cd "$REPO"
 for r in R150/tests/run_sfx.sh R150/tests/run_bonus_ui.sh R137/tests/run.sh R138/tests/run.sh R140/tests/run.sh R147/tests/run.sh R147/tests/run_verity.sh R147/tests/run_verity_pack.sh \
  R148/tests/run_roster.sh R148/tests/run_purchase.sh R149/tests/run_verity.sh R132/tests/run.sh treadmill_bonus_R123/tests/run.sh giving_R122/tests/run.sh holes_R122/tests/run.sh \
  polish_R124/tests/run.sh R127/tests/run.sh R129/tests/run.sh; do
  [ -f "$P/$r" ] || continue
  echo "######## $r";sh "$P/$r" "$OUT/$(echo $r | tr '/' '_')" | tail -3
 done
fi
if [ "$MODE" = "mutate" ]; then echo "== mutations";python3 "$HERE/mutation_check.py" "$OUT/mut";fi
echo "R151 announcement suites passed"
