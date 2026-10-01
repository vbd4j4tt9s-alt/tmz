#!/bin/sh
# Usage: sh run.sh [repo root]. R121 performance micro-checks (offline, Roblox mock + /opt/luau/luau).
# "base" = the changed files as of commit 352e079 (before R121), "new" = the working tree.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${1:-$(cd "$HERE/../../../.." && pwd)};SRC=$REPO/src;T=$(mktemp -d)
BASE=352e079
cp "$REPO/tools/tests/roblox.luau" "$HERE"/*.luau "$HERE/mkbundle.py" "$T/"
mkdir -p "$T/base"
for f in StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua StarterPlayer/StarterPlayerScripts/KeeperHitEffects.client.lua \
 StarterPlayer/StarterPlayerScripts/LavaFlow.client.lua ServerScriptService/ChestChaseServer/ChaseService.lua \
 ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua; do
 git -C "$REPO" show "$BASE:src/$f" > "$T/base/$(basename "$f")"
done
cd "$T"
SP=$SRC/StarterPlayer/StarterPlayerScripts;SS=$SRC/ServerScriptService/ChestChaseServer
KEEP="KeeperUpgradeArt=$SS/KeeperUpgradeArt.lua BeastModels=$SS/BeastModels.lua KeeperContact=$SS/KeeperContact.lua"
python3 mkbundle.py bundle_new.luau "$SRC/ReplicatedStorage" BeastAnimation=$SP/BeastAnimation.client.lua KeeperHitEffects=$SP/KeeperHitEffects.client.lua $KEEP >/dev/null
python3 mkbundle.py bundle_base.luau "$SRC/ReplicatedStorage" BeastAnimation=base/BeastAnimation.client.lua KeeperHitEffects=base/KeeperHitEffects.client.lua $KEEP >/dev/null
B=$REPO/tools/tests/bundle.py
python3 $B lava_new.luau LavaFlow=$SP/LavaFlow.client.lua;python3 $B lava_base.luau LavaFlow=base/LavaFlow.client.lua
python3 $B vb_new.luau ShopViewport=$SRC/ReplicatedStorage/ShopViewport.lua
python3 $B cb_new.luau ChaseService=$SS/ChaseService.lua;python3 $B cb_base.luau ChaseService=base/ChaseService.lua
python3 $B kb_new.luau K=$SS/ConcurrentKeeperService.lua;python3 $B kb_base.luau K=base/ConcurrentKeeperService.lua
L=/opt/luau/luau
for w in base new; do $L beast_micro.luau -a $w | tail -2; done
for w in base new; do $L hit_micro.luau -a $w | tail -2; done
$L lava_micro.luau | tail -1
$L vis_micro.luau | tail -2
for w in base new; do $L notice_micro.luau -a $w | tail -1; done
for w in base new; do $L drop_micro.luau -a $w | tail -1; done
