#!/bin/sh
# bundles: new = working tree, base = R112 snapshot
D=/tmp/claude-0/-home-user-tmz/3b81e797-bc5f-5803-9d1a-e4f30034f130/scratchpad/keepers
for w in new base; do
 if [ $w = new ]; then S=/home/user/tmz/src; else S=$D/base/src; fi
 python3 $D/mkbundle.py $D/bundle_$w.luau $S/ReplicatedStorage BeastAnimation=$S/StarterPlayer/StarterPlayerScripts/BeastAnimation.client.lua KeeperHitEffects=$S/StarterPlayer/StarterPlayerScripts/KeeperHitEffects.client.lua KeeperUpgradeArt=$S/ServerScriptService/ChestChaseServer/KeeperUpgradeArt.lua BeastModels=$S/ServerScriptService/ChestChaseServer/BeastModels.lua KeeperContact=$S/ServerScriptService/ChestChaseServer/KeeperContact.lua
done
