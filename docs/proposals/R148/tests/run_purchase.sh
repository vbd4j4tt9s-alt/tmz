#!/bin/sh
# Usage: sh run_purchase.sh [scratch dir]. R148 purchase feedback on the Roblox mock with the real scripts:
#  test_purchase.luau        - server: the real PremiumService / PurchaseAnnouncer / GamePassService (+ PremiumRouting,
#                              PremiumProgress, PassGiftService, SecurityGate) with a fake PlayerDataService. Opening a Robux
#                              prompt returns no message (real errors still do); one "✅ Purchased: <what>!" notice + one
#                              ChestChaseRemotes.PurchaseDone {Kind, Name} to the buyer only for every granted receipt (Mech
#                              packs, the 10 bundles, gift credits), game-pass purchase and successful gem purchase (BuyPack,
#                              BuyBundle, BuyPerk, Convert); never for a duplicate / retried-after-announce receipt, a failed
#                              grant or save, a refused gem purchase or a cancelled prompt; a broken announcer changes nothing.
#  test_purchase_client.luau - client: the real PurchaseCelebration (chime, ring + confetti, character sparkles, ReducedMotion,
#                              FastMode, caps, cleanup, hostile payloads) and the whole path server announcer ->
#                              NotificationService -> NotificationClient83 / NoticeFeed83 showing the notice.
#  test_purchase_shop.luau   - client: the real GamePassClient shop: no status strip after a prompt opens (nil / empty / blank
#                              message), real errors and the Gem hints still shown, no KaChing on top of the chime.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT/srv" "$OUT/cl" "$OUT/shop"
T=$REPO/tools/tests;TB=$REPO/docs/proposals/treadmill_bonus_R123/tests;INV=$REPO/docs/proposals/inventory_R113/tests;C=$REPO/src/StarterPlayer/StarterPlayerScripts;S=$REPO/src/ServerScriptService/ChestChaseServer
cp "$T/roblox.luau" "$TB/world.luau" "$HERE"/test_purchase.luau "$OUT/srv/";python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
# (the R113 bundler has this checkout's path hard-coded: point it at this worktree's src)
sed "s#/home/user/tmz/src#$REPO/src#" "$INV/mkbundle.py" > "$OUT/mkbundle_cl.py"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/test_purchase_client.luau "$OUT/cl/"
python3 "$OUT/mkbundle_cl.py" "$OUT/cl/rs_bundle.luau" PurchaseCelebration="$C/PurchaseCelebration.client.lua" NotificationClient83="$C/NotificationClient83.client.lua" \
 PurchaseAnnouncer="$S/PurchaseAnnouncer.lua" NotificationService="$S/NotificationService.lua" >/dev/null
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/test_purchase_shop.luau "$OUT/shop/"
python3 "$OUT/mkbundle_cl.py" "$OUT/shop/rs_bundle.luau" GamePassClient="$C/GamePassClient.client.lua" >/dev/null
cd "$OUT/srv";echo "== test_purchase";/opt/luau/luau test_purchase.luau > purchase.log 2>&1 || { tail -40 purchase.log;exit 1; };tail -1 purchase.log
cd "$OUT/cl";echo "== test_purchase_client";/opt/luau/luau test_purchase_client.luau > client.log 2>&1 || { tail -40 client.log;exit 1; };tail -1 client.log
cd "$OUT/shop";echo "== test_purchase_shop";/opt/luau/luau test_purchase_shop.luau > shop.log 2>&1 || { tail -40 shop.log;exit 1; };tail -1 shop.log
