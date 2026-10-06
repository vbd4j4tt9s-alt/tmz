#!/bin/sh
# Usage: sh run_variant.sh <world dir (build_sweep_env.sh)> <name> '<Luau globals, e.g. RUNNER={0,-60};GEO=true>'
# Runs sweep_scene.luau with the given globals in front; writes <world>/<name>.json (the scene for zfight.py), <name>.steps and <name>.log. Exits 1 when a build step failed.
set -e
W=${1:?world dir};N=${2:?name};PRE=${3:-}
(printf '%s\n' "$PRE";cat "$W/sweep_scene.luau") > "$W/run_$N.luau"
(cd "$W" && timeout 900 /opt/luau/luau "run_$N.luau" > "$N.log" 2>&1) || { tail -20 "$W/$N.log";exit 1; }
grep '^SCENE ' "$W/$N.log" | sed 's/^SCENE //' > "$W/$N.json"
grep -v '^SCENE ' "$W/$N.log" > "$W/$N.steps"
if grep -q 'FAILED' "$W/$N.steps";then grep FAILED "$W/$N.steps";exit 1;fi
echo "variant $N: $(grep '^ZSCENE' "$W/$N.steps" | sed 's/^ZSCENE //')"
