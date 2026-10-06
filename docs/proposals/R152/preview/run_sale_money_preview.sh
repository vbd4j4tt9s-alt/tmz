#!/bin/sh
# Usage: sh run_sale_money_preview.sh <scratch dir>
# R152 preview of the sale money flying to the balance (docs/proposals/R152/sale_money.md): preview_sale_money.luau plays the REAL SaleMoneyEffects, GardenWallet and
# HudLayout on the Roblox mock and prints FRAME lines (coin positions, counters, balances); render_sale_money.mjs draws them with headless Chromium (playwright, global;
# PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers) and make_sale_money.py (Pillow) lays out sale_money.png and sale_money.gif.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
S=${1:?scratch dir};P=$REPO/docs/proposals;INV=$P/inventory_R113/tests
mkdir -p "$S/cl" "$S/png"
cp "$REPO/tools/tests/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE/preview_sale_money.luau" "$S/cl/"
python3 "$P/R150/tests/mkbundle_sfx.py" "$S/cl" >/dev/null
(cd "$S/cl" && /opt/luau/luau preview_sale_money.luau | grep '^FRAME' > "$S/frames.txt")
echo "frames: $(wc -l < "$S/frames.txt")"
export PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}
node "$HERE/render_sale_money.mjs" "$S/frames.txt" "$S/png"
python3 "$HERE/make_sale_money.py" "$S/png" "$P/R152"
