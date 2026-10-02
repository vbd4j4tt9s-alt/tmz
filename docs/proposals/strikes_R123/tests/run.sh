#!/bin/sh
# Run from the scratch harness dir (keepers_R113/tests/mk.sh layout: world/loader/cfmath/roblox + bundle_new/bundle_base).
# The R112 snapshot bundle (bundle_base) is the reference for "server frames identical".
set -e
sh mk.sh
for t in states_test side_check polish_check signature_check; do luau $t.luau | tail -1; done
luau dump_strikes.luau > scenes_strikes.json && node render_strikes.mjs   # frame strips -> docs/proposals/strikes_R123
