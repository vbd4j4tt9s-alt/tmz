"""R158 HUD-lock preview: writes the two PROPOSED "MENU higher" HudLayout scripts into OUT_DIR as patched copies of this checkout's src/ (src/ itself is never touched):
  HudLayout_A.lua   PC: the MENU button's centre is 1/3 of the HUD area's height from the top (the wheel opens round it)
  HudLayout_B.lua   PC: the MENU button sits so that the TOP of the open wheel is at the HUD's top margin (8 px under Roblox's top bar, so right under its top-left buttons)
Only the computer branch of readLayout changes (touch layouts are not read there); nothing else moves: the balances, hotbar and status keep R157's sizes and places, and because
the wheel no longer reaches down into the balances' corner, R157's "shorten the three rows" rule has nothing to do. B's first option stands where the owner-only TOOLS square
(top-left, 10 / 8, 48 px) is drawn; StudioTestClient hides that square while the wheel is open (GardenMenuExpanded), so B's wheel search does not avoid it. Every replacement must match exactly once, so a changed
source stops the script instead of silently previewing something else.
Usage: python3 make_variants158.py SRC_DIR OUT_DIR"""
import os
import sys

SRC, OUT = os.path.normpath(sys.argv[1]), sys.argv[2]
os.makedirs(OUT, exist_ok=True)
text = open(os.path.join(SRC, 'ReplicatedStorage', 'HudLayout.lua'), encoding='utf-8').read()


def rep(t, old, new, label):
    n = t.count(old)
    if n != 1:
        sys.exit('make_variants158: %s: expected exactly one match, found %d' % (label, n))
    return t.replace(old, new)


CENTRE = {
    # A: a third of the way down
    'A': " local hubCenter=math.min(h/2,math.floor(h/3+.5)) -- R158 preview A: the MENU button's centre, 1/3 of the height from the top\n",
    # B: the first option (radius up from the hub) touches the top margin: centre = margin + radius + half an option
    'B': (" local hubCenter=math.min(h/2,(h<212 and 4 or 8)+(hubSize==64 and 102 or 84)+(h<224 and 44 or h<280 and 50 or 64)/2) -- R158 preview B: the top of the open wheel at the HUD's top margin\n"),
}

for name, centre in CENTRE.items():
    t = text
    t = rep(t, " local hubSize=h<280 and 52 or 64;local hubTop=(h-hubSize)/2\n",
            " local hubSize=h<280 and 52 or 64\n" + centre + " local hubTop=hubCenter-hubSize/2\n", 'hub centre')
    t = rep(t, "margin,h-margin,h/2,true,w,{{X=10,Y=8,W=48,H=48}", "margin,h-margin,hubCenter,true,w,{{X=10,Y=8,W=48,H=48}", 'arc centre')
    t = rep(t, "local boxes={{X=10,Y=(h-hubSize)/2,W=hubSize,H=hubSize},", "local boxes={{X=10,Y=hubCenter-hubSize/2,W=hubSize,H=hubSize},", 'hub box')
    t = rep(t, "boxes[#boxes+1]={X=10+(hubSize-optionSize)/2+at.X,Y=(h-optionSize)/2+at.Y,W=optionSize,H=optionSize}",
            "boxes[#boxes+1]={X=10+(hubSize-optionSize)/2+at.X,Y=hubCenter-optionSize/2+at.Y,W=optionSize,H=optionSize}", 'option boxes')
    if name == 'B':
        t = rep(t, "hubCenter,true,w,{{X=10,Y=8,W=48,H=48},{X=(w-barWidth)/2,", "hubCenter,true,w,{{X=(w-barWidth)/2,", 'owner tools tile (hidden while the wheel is open)')
    t = rep(t, "reach=math.max(reach or 0,h/2+at.Y+optionSize/2)", "reach=math.max(reach or 0,hubCenter+at.Y+optionSize/2)", 'reach')
    t = rep(t, "for _,b in ipairs(wheelBoxes(arc,hubSize,h/2))do avoid[#avoid+1]=b end", "for _,b in ipairs(wheelBoxes(arc,hubSize,hubCenter))do avoid[#avoid+1]=b end", 'name rows avoid')
    t = rep(t, "WalletX=walletX,MenuSize=hubSize,MenuX=10,MenuOptionSize=optionSize,", "WalletX=walletX,MenuSize=hubSize,MenuX=10,MenuShiftY=hubCenter-h/2,MenuOptionSize=optionSize,", 'MenuShiftY')
    open(os.path.join(OUT, 'HudLayout_%s.lua' % name), 'w', encoding='utf-8').write(t)
    print('HudLayout_%s.lua' % name)
