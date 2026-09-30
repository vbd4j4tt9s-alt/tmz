#!/bin/sh
cd /home/user/tmz/src/ReplicatedStorage && args=""; for f in *.lua; do n=${f%.lua}; args="$args $n=/home/user/tmz/src/ReplicatedStorage/$f"; done
cd /tmp/claude-0/-home-user-tmz/3b81e797-bc5f-5803-9d1a-e4f30034f130/scratchpad/planting && python3 bundle.py rs_bundle.luau $args GardenVisuals=/home/user/tmz/src/StarterPlayer/StarterPlayerScripts/GardenVisuals.client.lua
