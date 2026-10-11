#!/bin/sh
# Usage: sh run_inventory.sh [scratch dir] [all|static|layout|client|tooltip|server|perf] [variant order]. R155 (owner: "just make it function like the normal inventory ... i can
# have a blank hot bar if i put everything in my bag ... make the max amount of items a person can hold 200", "allow people to discard items") on the Roblox
# mock (/opt/luau/luau) with the REAL modules / scripts of this checkout.
#  static               - the new / edited scripts compile at -O0 (Roblox's 200-register limit: check_compile_O0.sh), the new files are in src/MANIFEST.tsv, Hotbar
#                         lines 1 / 2 are the load guard, Config.lua unchanged but its Version (the release sets it), the Hotbar still plays no cue but the harvest landing, no model names.
#  test_layout155.luau   - the layout model alone (GardenInventoryState): new-item rule, nothing moves by itself, blank slots, Place / Stow, respawn, rejoin
#                         (Serialize / Parse / Restore), a phone's 5 slots, Target, 3000 random operations.
#  test_inventory155.luau - the REAL Hotbar + InventoryPanel155 + DiscardDialog155 through R153's engine model (engine153.luau), in 6 engine variants x 2 event
#                         orders: every drag, the blank hotbar, tap-tap (touch hold, right-click + number key, gamepad Y / A), instant equip, search, the count,
#                         discarding (amounts, the ~1 s hold on every item, refusals), the layout across a respawn and a rejoin, the seed collect target.
#  test_cap155.luau      - the server: the 200 cap on every grant path (steal / bank with the carried pack's place kept, the bonus roll, daily login + quest, the
#                         mystery pedestal, the Void giveaway, Verity, Mech for Gems and a Robux receipt, gifts in and out, harvesting, the starter pack, owner
#                         grants), an old save above 200 loads whole, the discard service (every refusal, a stack, the count, after a rejoin), the saved layout.
#  test_no_tooltip156.luau - (R156, owner: "these descriptions can be removed from the game") replaces R155's test_tooltip155: the item info panel is gone. On a PC, a landscape
#                         phone and a portrait phone, through the real Hotbar + Bag: ItemTooltip155 is not in the game, the Bag panel has no Hover / Focus / ... calls, the Hotbar
#                         forwards nothing to it, no Instance named like a tooltip or showing a description text is ever created (hover, gamepad selection, a picked item or card,
#                         a just-held pack), the Bag's hint no longer promises "hover for info" / "hold for info". (mode `tooltip`)
#  perf_inventory155.luau - 200 items: refresh, a click to the highlight, the Bag opening and scrolling, idle frames; the R154 Hotbar on the same run for comparison.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=${2:-all};mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts;INV=$P/inventory_R113/tests;SS=$S/ServerScriptService/ChestChaseServer
BASE=${BASE:-ad789e1}
run() { # $1 dir, $2 file, $3 label
 if (cd "$1" && timeout 1500 /opt/luau/luau "$2" > "$2.log" 2>&1);then echo "  $3: $(grep -v '^WARN' "$1/$2.log" | grep -v '^\[Hotbar\]' | tail -1)";return 0
 else echo "  $3: FAILED ($(grep -c '^FAIL' "$1/$2.log") checks)";grep '^FAIL' "$1/$2.log" | head -12;grep -v '^WARN' "$1/$2.log" | grep -iE 'error|stack' | head -4;return 1;fi
}
if [ "$MODE" = all ] || [ "$MODE" = static ];then
 echo "== static checks"
 fail=0;bad() { echo "FAIL: $1";fail=1; }
 for f in "$S/ReplicatedStorage/InventoryStacks155.lua" "$S/ReplicatedStorage/InventoryPanel155.lua" "$S/ReplicatedStorage/DiscardDialog155.lua" "$SS/InventoryCap155.lua" "$SS/InventoryService155.lua";do
  [ -f "$f" ] || bad "$f is missing"
  rel=${f#"$S"/};name=$(basename "$f" .lua);grep -q "	${rel%.lua}	$rel$" "$S/MANIFEST.tsv" || bad "$rel is not in src/MANIFEST.tsv"
 done
 sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/compile.log" 2>&1 || { tail -5 "$OUT/compile.log";bad "check_compile_O0"; }
 tail -1 "$OUT/compile.log"
 head -1 "$SP/Hotbar.client.lua" | grep -q "SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)" || bad "Hotbar line 1 must hide Roblox's backpack (R152 load guard)"
 sed -n 2p "$SP/Hotbar.client.lua" | grep -q "R152: start once the whole game has arrived" || bad "Hotbar line 2 must be the R152 load guard"
 if grep -nE "Audio\.Play\(" "$SP/Hotbar.client.lua" "$S/ReplicatedStorage/InventoryPanel155.lua" "$S/ReplicatedStorage/DiscardDialog155.lua" | grep -v "Bubble06";then bad "the hotbar / Bag play a cue of their own (only the harvest landing, Bubble06)";fi
 grep -qE "Config\.Version='V150 R15[0-9a-z]*'" "$SS/Config.lua" || bad "Config.Version must be a V150 R15x release number (the release step sets it)"
 grep -q "^S.Cap=200$" "$S/ReplicatedStorage/InventoryStacks155.lua" || bad "the cap (InventoryStacks155.Cap) is not 200"
 # R156 (owner: "these descriptions can be removed from the game"): the item info panel is gone from the client - the module (src file and manifest row), its uses in the Bag panel and
 # the Hotbar, and the hint's promise of it. The server still writes Tool.ToolTip (cheap, harmless, and the panel can come back later): ChestService keeps the newline-joined rows.
 [ ! -e "$S/ReplicatedStorage/ItemTooltip155.lua" ] || bad "src/ReplicatedStorage/ItemTooltip155.lua is back (the item info panel was removed in R156)"
 ! grep -q "ItemTooltip155" "$S/MANIFEST.tsv" || bad "src/MANIFEST.tsv still lists ItemTooltip155"
 if grep -rn "ItemTooltip" "$S";then bad "something in src/ still names the removed item info panel (ItemTooltip)";fi
 if grep -nE "Inv\.(Hover|Leave|Focus|Unfocus|TipRefresh|Tip)\b" "$SP/Hotbar.client.lua";then bad "the Hotbar still forwards hover / selection to an item info panel";fi
 if grep -nE "\b(Tip\.|Tip=|M\.(Hover|Leave|Focus|Unfocus|TipRefresh))" "$S/ReplicatedStorage/InventoryPanel155.lua";then bad "InventoryPanel155 still has the item info panel's calls";fi
 if grep -nE "MouseEnter|MouseLeave|SelectionGained|SelectionLost" "$SP/Hotbar.client.lua" | grep -vE "hovered=(true|false);paint\(\)|focused=(true|false);paint\(\)";then bad "the Hotbar connects hover / selection to something other than the slot's own highlight";fi
 if grep -nE "for info|hover for|hold for" "$S/ReplicatedStorage/InventoryPanel155.lua";then bad "the Bag's hint still promises info on hover / hold";fi
 grep -qF "R156 (owner): the client no longer shows this tooltip" "$SS/ChestService.lua" || bad "ChestService:_packTooltip lost its R156 comment (the client no longer shows the tooltip)"
 grep -qF "return table.concat(rows,'\\n')" "$SS/ChestService.lua" && grep -qF "tool.ToolTip=ChestService._packTooltip(self,player,record)" "$SS/ChestService.lua" || bad "ChestService no longer writes the hold tooltip as newline-joined rows (the server side stays as it is)"
 # and the pack carried home is banked with Banked (the 200 cap never refuses it)
 grep -qF "{Luck=true, Banked=true}" "$SS/ChestService.lua" || bad "ChestService:Bank does not pass Banked (a carried pack must never be refused for the 200 cap)"
 # the R155 release sets Config.Version; nothing else in Config.lua may change (older suites keep it byte-identical apart from that)
 [ "$(git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | sed "s/Config\.Version='[^']*'/Config.Version=V/")" = "$(sed "s/Config\.Version='[^']*'/Config.Version=V/" "$SS/Config.lua")" ] || bad "Config.lua changed beyond Config.Version (older suites keep it byte-identical)"
 if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]" "$HERE" "$P/R155"/*.md 2>/dev/null;then bad "a model name in the R155 files";fi
 [ "$fail" = 0 ]
 echo "ok: the new scripts are in the manifest, no item info panel (module, manifest row, Hotbar / Bag calls, hint text), every script compiles at -O0 within 180 registers, Hotbar lines 1 / 2 are the load guard, no new cue, Config.lua untouched but its Version, the cap is 200"
fi
if [ "$MODE" = all ] || [ "$MODE" = layout ];then
 D=$OUT/layout;mkdir -p "$D";cp "$T/roblox.luau" "$INV/world.luau" "$HERE/test_layout155.luau" "$D/";python3 "$INV/mkbundle.py" "$D/rs_bundle.luau" >/dev/null
 echo "== test_layout155";run "$D" test_layout155.luau "layout model"
fi
if [ "$MODE" = all ] || [ "$MODE" = client ];then
 D=$OUT/client;mkdir -p "$D"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R153/tests/engine153.luau" "$HERE/test_inventory155.luau" "$D/"
 python3 "$P/R150/tests/mkbundle_sfx.py" "$D" all-client NotificationService="$SS/NotificationService.lua" >/dev/null
 echo "== test_inventory155 (6 engine variants x 2 event orders)"
 failed=0;list=${3:-"began nobegan stale anywhere objscreen nobegan_gui"};orders=${4:-"activated_first release_first"}
 for v in $list;do for o in $orders;do
  printf "VARIANT='%s';ORDER='%s'\n" "$v" "$(echo "$o" | tr '_' ' ')" > "$D/inv_${v}_$o.luau";cat "$D/test_inventory155.luau" >> "$D/inv_${v}_$o.luau"
  run "$D" "inv_${v}_$o.luau" "$v / $o" || failed=$((failed+1))
 done;done
 [ "$failed" = 0 ] || { echo "FAIL: $failed run(s) failed";exit 1; }
fi
if [ "$MODE" = all ] || [ "$MODE" = tooltip ];then
 D=$OUT/tooltip;mkdir -p "$D"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE/test_no_tooltip156.luau" "$D/"
 # (the engine model at this view's screen size and top inset, as the preview does)
 sed "s/local INSET=V2(0,58);local SCREEN=V2(1280,720)/local INSET=opts.Inset and V2(0,opts.Inset) or V2(0,58);local SCREEN=opts.Screen or V2(1280,720)/" "$P/R153/tests/engine153.luau" > "$D/engine155p.luau"
 grep -q "opts.Screen" "$D/engine155p.luau" || { echo "engine153.luau changed: the screen size patch did not apply";exit 1; }
 python3 "$P/R150/tests/mkbundle_sfx.py" "$D" all-client NotificationService="$SS/NotificationService.lua" >/dev/null
 echo "== test_no_tooltip156 (pc, landscape phone, portrait phone)"
 failed=0
 for v in pc phone portrait;do
  printf "VIEW='%s'\n" "$v" > "$D/tip_$v.luau";cat "$D/test_no_tooltip156.luau" >> "$D/tip_$v.luau"
  run "$D" "tip_$v.luau" "$v" || failed=$((failed+1))
 done
 [ "$failed" = 0 ] || { echo "FAIL: $failed run(s) failed";exit 1; }
fi
if [ "$MODE" = all ] || [ "$MODE" = server ];then
 D=$OUT/server;mkdir -p "$D";cp "$T/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$HERE/test_cap155.luau" "$D/";python3 "$P/treadmill_bonus_R123/tests/mkbundle.py" "$D" >/dev/null
 echo "== test_cap155";run "$D" test_cap155.luau "the cap, discarding, the saved layout (server)"
fi
if [ "$MODE" = all ] || [ "$MODE" = perf ];then
 D=$OUT/perf;mkdir -p "$D"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R153/tests/engine153.luau" "$HERE/perf_inventory155.luau" "$D/"
 python3 "$P/R150/tests/mkbundle_sfx.py" "$D" all-client NotificationService="$SS/NotificationService.lua" >/dev/null
 git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" > "$D/Hotbar_r154.lua"
 git -C "$REPO" show "$BASE:src/ReplicatedStorage/GardenInventoryState.lua" > "$D/GardenInventoryState_r154.lua"
 mkdir -p "$D/old";cp "$D"/*.luau "$D/old/" 2>/dev/null || true
 python3 "$P/R150/tests/mkbundle_sfx.py" "$D/old" all-client NotificationService="$SS/NotificationService.lua" Hotbar="$D/Hotbar_r154.lua" GardenInventoryState="$D/GardenInventoryState_r154.lua" >/dev/null
 echo "== perf_inventory155 (200 items)"
 (cd "$D/old" && printf "LABEL='R154'\n" > p.luau && cat perf_inventory155.luau >> p.luau && timeout 1500 /opt/luau/luau p.luau > p.log 2>&1) || { tail -5 "$D/old/p.log";echo "FAIL: the R154 run";exit 1; }
 (cd "$D" && printf "LABEL='R155'\n" > p.luau && cat perf_inventory155.luau >> p.luau && timeout 1500 /opt/luau/luau p.luau > p.log 2>&1) || { grep '^FAIL' "$D/p.log";tail -5 "$D/p.log";echo "FAIL: perf";exit 1; }
 grep '^PERF' "$D/old/p.log";grep '^PERF\|^FAIL' "$D/p.log";tail -1 "$D/p.log"
fi
echo "R155 inventory suites passed"
