#!/bin/sh
# R113 economy proposal: re-dump the live economy from the real modules, re-tune prices, rebuild every table.
# Needs /opt/luau/luau and python3. About 1 minute.
set -e
HERE=$(cd "$(dirname "$0")" && pwd); T=${TMPDIR:-/tmp}/r113; mkdir -p "$T"; cd "$HERE"
python3 bundle.py dump_economy.luau "$T/e.luau" && /opt/luau/luau "$T/e.luau" > econ_live.tsv
python3 proposal.py > /dev/null          # writes proposed_prices.json (report.py uses the rounded copy of it)
python3 report.py 40 > /dev/null         # writes out_tables.md
echo "done: econ_live.tsv, proposed_prices.json, out_tables.md"
