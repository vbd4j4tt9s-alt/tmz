"""R156 preview: OPTION 2 ("no green at all", no hint line) applied to a SCRATCH copy of src/ (never to src/ itself).
Usage: python3 make_option2_src.py SCRATCH_SRC      (SCRATCH_SRC = a copy of the checkout's src/)
Every edit is an exact replacement that must match the expected number of times, so the script is also the exact list of what the real change would touch.
The palette (old -> new hex) is in PALETTE below and is the table in bag_look.md."""
import os
import re
import sys

root = sys.argv[1]
HOTBAR = 'StarterPlayer/StarterPlayerScripts/Hotbar.client.lua'
PANEL = 'ReplicatedStorage/InventoryPanel155.lua'
DIALOG = 'ReplicatedStorage/DiscardDialog155.lua'

# (old, new, count)  per file; text edits, not regexes
EDITS = {
    HOTBAR: [
        # the Hotbar's palette: sheet, tiles (Bag cards, category tabs, rarity button), the selected tab / drag ghost, the wells (search box, count), the lit colour
        ("Green=Theme.Colors.Mint,", "Green=Color3.fromRGB(234,240,255),", 1),  # 93FF45 -> EAF0FF   (drop highlight, slot outlines, picked ring and text)
        ("Sheet=Color3.fromRGB(20,46,35),Tile=Color3.fromRGB(37,76,57),TileOn=Color3.fromRGB(65,120,76),Well=Color3.fromRGB(14,33,25)}",
         "Sheet=Color3.fromRGB(31,34,70),Tile=Color3.fromRGB(48,54,106),TileOn=Color3.fromRGB(74,85,153),Well=Color3.fromRGB(25,32,65)}", 1),
        # the sheet's trim, header band and rule (GardenMenuStyle.Panel paints them green for every menu: the Bag recolours its own after the call)
        ("panel.BackgroundColor3=C.Sheet;panel.BackgroundTransparency=.1 -- R112: dark translucent green sheet.",
         "panel.BackgroundColor3=C.Sheet;panel.BackgroundTransparency=.1 -- R156: dark navy sheet (was green).\n"
         "panel.GardenTrim.Color=Color3.fromRGB(106,144,225);panel.GardenHeader.BackgroundColor3=Color3.fromRGB(66,74,128);panel.HeaderRule.BackgroundColor3=Color3.fromRGB(106,144,225)", 1),
        # the drop highlight: a thin light rim (2 px, a little see-through) and a slight brighten instead of the 3 px lime rim over a .55 lime fill
        ("local st=Instance.new('UIStroke');st.Color=color;st.Thickness=3;st.Parent=f end",
         "local st=Instance.new('UIStroke');st.Color=color;st.Thickness=2;st.Transparency=.15;st.Parent=f end", 1),
        ("cover(b,'DropTarget',C.Green,.55).Visible=true", "cover(b,'DropTarget',C.Green,b==panel and .92 or .86).Visible=true", 1),
        # no hint line
        ("label(panel,'Hint',UDim2.new(1,-32,0,26),UDim2.new(0,16,1,-32),'Click to hold it • Drag it onto the hotbar',12).TextColor3=C.Muted\n", "", 1),
        ("panel.Hint.Visible=not short;", "", 1),
    ],
    PANEL: [
        (" local hint=ctx.panel:FindFirstChild('Hint')\n", "", 1),
        (";if ctx.panel:FindFirstChild('Hint')then ctx.panel.Hint.Visible=picked==nil and ctx.panel.Hint:GetAttribute('Room')~=false end", "", 1),
    ],
    DIALOG: [
        ("f.BackgroundColor3=Color3.fromRGB(20,46,35)", "f.BackgroundColor3=Color3.fromRGB(31,34,70)", 1),                    # 142E23 -> 1F2246
        ("st.Color=Theme.Colors.Mint;st.Transparency=.4", "st.Color=Color3.fromRGB(106,144,225);st.Transparency=.4", 1),          # 93FF45 -> 6A90E1
        ("pic.BackgroundColor3=Color3.fromRGB(37,76,57)", "pic.BackgroundColor3=Color3.fromRGB(48,54,106)", 1),                  # 254C39 -> 30366A
        ("local tile=Color3.fromRGB(37,76,57)", "local tile=Color3.fromRGB(48,54,106)", 1),                                      # 254C39 -> 30366A
        ("box.BackgroundColor3=Color3.fromRGB(14,33,25)", "box.BackgroundColor3=Color3.fromRGB(25,32,65)", 1),                    # 0E2119 -> 192041
        ("Color3.fromRGB(70,110,86))", "Color3.fromRGB(66,76,138))", 1),                                                          # 466E56 -> 424C8A (Keep it)
    ],
}
# regex edits (the hint block in InventoryPanel155.Layout spans two lines)
REGEX = {
    PANEL: [(r"\n if hint then hint\.Size=.*?right-click for more'end", "", 1)],
}

for rel, edits in EDITS.items():
    path = os.path.join(root, rel)
    s = open(path, encoding='utf-8').read()
    for old, new, count in edits:
        n = s.count(old)
        assert n == count, '%s: expected %d match(es), found %d for: %s' % (rel, count, n, old[:70])
        s = s.replace(old, new)
    for pat, new, count in REGEX.get(rel, []):
        s, n = re.subn(pat, new, s, flags=re.S)
        assert n == count, '%s: expected %d regex match(es), found %d for: %s' % (rel, count, n, pat[:70])
    open(path, 'w', encoding='utf-8').write(s)
    print('patched', rel, len(edits) + len(REGEX.get(rel, [])), 'edits')
