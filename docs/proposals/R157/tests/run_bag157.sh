#!/bin/sh
# Usage: sh run_bag157.sh [scratch dir]. R157 (owner: "dont make this green and remove that text saying click to hold and so on"; Option 2 of docs/proposals/R156/bag_look.md: the Bag
# without green, and without the hint line) on the Roblox mock (/opt/luau/luau) with the REAL modules / scripts of this checkout.
#  static checks      - the Bag's scripts have no hint label and none of the hint's words, no lime (Theme.Colors.Mint / the old C.Green) and none of the old green panel colours; the new palette and
#                       the light "lit" colour are in; the Discard bin and the popup's Discard stay red; GardenTheme / GardenMenuStyle (the colours every other menu uses) are not edited by this
#                       change; Hotbar lines 1 / 2 are the load guard; the Hotbar's main chunk adds no register (check_compile_O0.sh: at most 174 of 180); no model names.
#  test_bag157.luau   - the real Hotbar + Bag + discard popup through R153's engine model, on a PC (1280 x 720), a landscape phone (844 x 390) and a portrait phone (390 x 844): no hint label or
#                       hint text in any state, the bottom bar is the count and Discard (the count 8 px left of Discard); every new colour; the drop highlight is the light rim (#EAF0FF, 2 px, a
#                       faint brighten) on the sheet, a slot and the Bag button, the Discard bin's highlight stays red; the slot outlines, the picked ring and the "Moving ..." text are #EAF0FF; no
#                       Color3 on the GUI is #93FF45 or an old green after any state; GardenTheme / GardenMenuStyle.Panel still give every other menu its green.
# (The Bag's behaviour - drag, tap-tap, discard, search, the count - is run by R155's run_inventory.sh, which this change leaves passing.)
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts;INV=$P/inventory_R113/tests;SS=$S/ServerScriptService/ChestChaseServer
HOTBAR=$SP/Hotbar.client.lua;PANEL=$S/ReplicatedStorage/InventoryPanel155.lua;DIALOG=$S/ReplicatedStorage/DiscardDialog155.lua
echo "== static checks"
fail=0;bad() { echo "FAIL: $1";fail=1; }
for f in "$HOTBAR" "$PANEL" "$DIALOG";do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || bad "$f does not compile"
done
# no hint line: no label named Hint (DropHint, the slot outlines, is another thing), nothing that reads one, none of its words
if grep -nE "'Hint'|\"Hint\"|\.Hint\b|FindFirstChild\('Hint'\)" "$HOTBAR" "$PANEL" "$DIALOG";then bad "the Bag still makes or reads a Hint label";fi
if grep -rnE "Click to hold|Tap to hold|Drag it onto the hotbar|right-click for more|drag to move|hold to move or discard" "$S";then bad "the Bag's hint text is still in src";fi
# no lime, no old green: the Hotbar's palette (C.Green was Theme.Colors.Mint), the panel, the popup
if grep -nE "Theme\.Colors\.Mint|Colors\.Mint|C\.Green|Green=|147, ?255, ?69|93FF45|93ff45" "$HOTBAR" "$PANEL" "$DIALOG";then bad "the Bag still uses the lime (Theme.Colors.Mint / C.Green)";fi
if grep -nE "fromRGB\((20, ?46, ?35|37, ?76, ?57|65, ?120, ?76|14, ?33, ?25|70, ?110, ?86|65, ?99, ?77)\)" "$HOTBAR" "$PANEL" "$DIALOG";then bad "an old green panel colour is still in the Bag's scripts";fi
# the new palette (old -> new, docs/proposals/R157/bag157.md)
grep -qF "Lit=Color3.fromRGB(234,240,255)" "$HOTBAR" || bad "Hotbar C.Lit must be #EAF0FF"
grep -qF "Sheet=Color3.fromRGB(31,34,70),Tile=Color3.fromRGB(48,54,106),TileOn=Color3.fromRGB(74,85,153),Well=Color3.fromRGB(25,32,65)" "$HOTBAR" || bad "Hotbar palette (Sheet / Tile / TileOn / Well) is not the new navy one"
grep -qF "panel.GardenTrim.Color=Color3.fromRGB(106,144,225);panel.GardenHeader.BackgroundColor3=Color3.fromRGB(66,74,128);panel.HeaderRule.BackgroundColor3=Color3.fromRGB(106,144,225)" "$HOTBAR" || bad "the Bag does not recolour its own trim / header band / rule"
grep -qF "st.Color=color;st.Thickness=2;st.Transparency=.15" "$HOTBAR" || bad "the drop highlight's rim is not the thin light rim (2 px, 15% see-through)"
grep -qF "cover(b,'DropTarget',C.Lit,b==panel and .92 or .86)" "$HOTBAR" || bad "the drop highlight is not the faint brighten of C.Lit"
if grep -nF "st.Color=color;st.Thickness=3" "$HOTBAR";then bad "the 3 px drop rim is back in the Hotbar";fi
grep -qF "fromRGB(31,34,70);f.Active=true" "$DIALOG" && grep -qF "st.Color=Color3.fromRGB(106,144,225)" "$DIALOG" && grep -qF "pic.BackgroundColor3=Color3.fromRGB(48,54,106)" "$DIALOG" && grep -qF "local tile=Color3.fromRGB(48,54,106)" "$DIALOG" \
 && grep -qF "box.BackgroundColor3=Color3.fromRGB(25,32,65)" "$DIALOG" && grep -qF "Color3.fromRGB(66,76,138))" "$DIALOG" || bad "the discard popup is not the new navy palette"
# the Discard bin and the popup's Discard stay red
grep -qF "trash.BackgroundColor3=Color3.fromRGB(122,44,52)" "$PANEL" && grep -qF "local RED,AMBER=Color3.fromRGB(255,96,96),Color3.fromRGB(255,190,70)" "$PANEL" || bad "the Discard bin is not red any more"
grep -qF "f.BackgroundColor3=RED;f.BackgroundTransparency=.55" "$PANEL" || bad "the Discard bin's drop highlight is not its own red"
grep -qF "'Discard',UDim2.new(.5,8,1,-62),UDim2.new(.5,-24,0,48),Color3.fromRGB(196,64,72))" "$DIALOG" || bad "the popup's Discard button is not red (#C44048)"
# the shared palette is not what this change edits: Mint stays in GardenTheme, GardenMenuStyle.Panel still trims every other menu green
grep -qF "Mint=RGB(147,255,69)" "$S/ReplicatedStorage/GardenTheme.lua" || bad "GardenTheme.Colors.Mint changed (other menus use it)"
grep -qF "edge.Color=C.Mint" "$S/ReplicatedStorage/GardenMenuStyle.lua" && grep -qF "rule.BackgroundColor3=C.Mint" "$S/ReplicatedStorage/GardenMenuStyle.lua" || bad "GardenMenuStyle.Panel changed (every other menu's trim, header band and rule)"
# the load guard and the register budget
head -1 "$HOTBAR" | grep -q "SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)" || bad "Hotbar line 1 must hide Roblox's backpack (R152 load guard)"
sed -n 2p "$HOTBAR" | grep -q "R152: start once the whole game has arrived" || bad "Hotbar line 2 must be the R152 load guard"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/compile.log" 2>&1 || { tail -5 "$OUT/compile.log";bad "check_compile_O0"; }
regs=$(sed -n 's/.*Hotbar\.client\.lua:1 function <main chunk or anonymous> uses \([0-9]*\) local registers.*/\1/p' "$OUT/compile.log");regs=${regs:-0}
[ "$regs" -le 174 ] || bad "the Hotbar main chunk uses $regs registers (it was 174 of 180: add no top-level local)"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]" "$HERE" "$P/R157"/*.md 2>/dev/null;then bad "a model name in the R157 files";fi
[ "$fail" = 0 ]
echo "ok: no hint label or text, no lime / old green in the Bag's scripts, the navy palette and the light lit colour are in, Discard stays red, GardenTheme / GardenMenuStyle untouched, Hotbar lines 1 / 2 are the load guard, Hotbar main chunk at ${regs:-under 160} registers (limit 180)"
run() { # $1 dir, $2 file, $3 label
 if (cd "$1" && timeout 1500 /opt/luau/luau "$2" > "$2.log" 2>&1);then echo "  $3: $(grep -v '^WARN' "$1/$2.log" | grep -v '^\[Hotbar\]' | tail -1)";return 0
 else echo "  $3: FAILED ($(grep -c '^FAIL' "$1/$2.log") checks)";grep '^FAIL' "$1/$2.log" | head -12;grep -v '^WARN' "$1/$2.log" | grep -iE 'error|stack' | head -4;return 1;fi
}
D=$OUT/bag;mkdir -p "$D"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE/test_bag157.luau" "$D/"
# (the engine model at this view's screen size and top inset, as the R155 tooltip test and the R156 preview do)
sed "s/local INSET=V2(0,58);local SCREEN=V2(1280,720)/local INSET=opts.Inset and V2(0,opts.Inset) or V2(0,58);local SCREEN=opts.Screen or V2(1280,720)/" "$P/R153/tests/engine153.luau" > "$D/engine155p.luau"
grep -q "opts.Screen" "$D/engine155p.luau" || { echo "engine153.luau changed: the screen size patch did not apply";exit 1; }
python3 "$P/R150/tests/mkbundle_sfx.py" "$D" all-client NotificationService="$SS/NotificationService.lua" >/dev/null
echo "== test_bag157 (pc, landscape phone, portrait phone)"
failed=0
for v in pc phone portrait;do
 printf "VIEW='%s'\n" "$v" > "$D/bag_$v.luau";cat "$D/test_bag157.luau" >> "$D/bag_$v.luau"
 run "$D" "bag_$v.luau" "$v" || failed=$((failed+1))
done
[ "$failed" = 0 ] || { echo "FAIL: $failed run(s) failed";exit 1; }
echo "R157 Bag look suite passed"
