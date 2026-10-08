"""R151: carries the three documented R151 pack fixes onto an OLDER copy of SeedPackVisuals.lua / EclipsePackArt.lua, in place.
Usage: python3 rebase_r151.py <file> [<file> ...]

Older suites (R147 / R149 Verity pack) prove "every other pack builds exactly what the base commit built" by building each pack with the base commit's
modules and with this checkout's. R151 changed three things on purpose (giant packs' seal / tear strips are GiantVisualParts, the Void's stars / specks / rune
strokes are backed onto the pouch, the pads' moss / ice are .006 thicker), so those suites' base copies get the same three edits first: "identical" then means
"nothing but the R151 fixes changed". A file is only touched where the old text is there (the Void edit in EclipsePackArt, the other two in SeedPackVisuals).
R153 (owner: "parts are dislocated on packs"): the Void's corner details that hung off its pouch are seated on it (EclipsePackArt.Seats, read from this checkout so the
base copy carries exactly today's table); those edits follow the R151 ones."""
import os
import sys

EDITS = [
    # (old, new)
    ("""        strip:SetAttribute("TearIndex",i);strip:SetAttribute("TearCount",8)
    end
    for _,side in ipairs({-1,1}) do""",
     """        strip:SetAttribute("TearIndex",i);strip:SetAttribute("TearCount",8)
    end
    -- R151: GiantVisualSafety fades every GiantVisualPart near the camera, and the pouch's own builders (SeedPackRenderer, EclipsePackArt, SpecialPackArt89
    -- and the Verity pack's) tag the pouch's parts for a giant (> 10x) pack, but the seal and the 8 tear strips (built here) were never tagged: close to a
    -- giant pack the pouch faded away and nine solid bars stayed behind in the air. They fade with the rest now.
    if packSize>10 then for _,p in ipairs(m:GetChildren())do if p:IsA('BasePart')and p~=root then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end end end
    for _,side in ipairs({-1,1}) do"""),
    ("   disk('MossPatch',d.Radius*(i==1 and .22 or .15),.022,top,theme.Moss,Enum.Material.Grass,offset,.72)",
     "   -- R151: .028 thick (was .022): a patch's top stood .018 over the pad's top face, inside the .02 band where two same-way faces can flicker at a distance (tools/zfight.py); .021 now\n   disk('MossPatch',d.Radius*(i==1 and .22 or .15),.028,top,theme.Moss,Enum.Material.Grass,offset,.72)"),
    ("  local ice=disk('IceGlaze',d.Radius*.95,.024,top,Color3.fromRGB(207,244,255),Enum.Material.Glass)",
     "  local ice=disk('IceGlaze',d.Radius*.95,.030,top,Color3.fromRGB(207,244,255),Enum.Material.Glass) -- R151: .030 thick (was .024), its top .022 over the pad's, like the moss"),
    ("""   local at=base*CF(star[1],star[2],-.016)
   pulse(add('StarV'..tag..i,V(.022,star[3],.01),at,star[4]),.6,i*1.7)
   pulse(add('StarH'..tag..i,V(star[3]*.62,.022,.01),at,star[4]),.6,i*1.7)""",
     """   local at=base*CF(star[1],star[2],-.008)
   pulse(add('StarV'..tag..i,V(.022,star[3],.026),at,star[4]),.6,i*1.7)
   pulse(add('StarH'..tag..i,V(star[3]*.62,.022,.026),at,star[4]),.6,i*1.7)"""),
    ("pulse(add('StarSpeck'..tag..i,V(.035,.035,.01),base*CF(speck[1],speck[2],-.016)*CFrame.Angles(0,0,math.pi/4)",
     "pulse(add('StarSpeck'..tag..i,V(.035,.035,.026),base*CF(speck[1],speck[2],-.008)*CFrame.Angles(0,0,math.pi/4)"),
    ("pulse(segment('RuneSigil'..tag..r..'_'..k,base*CF(rune[1]+V(0,0,-.016)),stroke[1],stroke[2],.022,.01,P.Rune),.5,r*1.3)",
     "pulse(segment('RuneSigil'..tag..r..'_'..k,base*CF(rune[1]+V(0,0,-.008)),stroke[1],stroke[2],.022,.026,P.Rune),.5,r*1.3)"),
]

# R153: the Void's seats (the table itself comes from this checkout's EclipsePackArt)
_now = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..', 'src', 'ReplicatedStorage', 'EclipsePackArt.lua'), encoding='utf-8').read()
_seats = _now[_now.index('A.Seats={'):_now.index('\n', _now.index('A.SeatEmbed=')) + 1]
EDITS += [
    ("A.Budget={MaxParts=190}\nlocal P=A.Palette", "A.Budget={MaxParts=190}\n" + _seats + "local P=A.Palette"),
    ("  for i,star in ipairs({{-.66,.50,.13,P.Star},",
     "  local seats=A.Seats[tag]\n  local function depth(kind,i)local s=seats[kind][i];return s and math.abs(face)-s+A.SeatEmbed-.013 or -.008 end\n  for i,star in ipairs({{-.66,.50,.13,P.Star},"),
    ("   local at=base*CF(star[1],star[2],-.008)", "   local at=base*CF(star[1],star[2],depth('Star',i))"),
    ("base*CF(speck[1],speck[2],-.008)*CFrame.Angles", "base*CF(speck[1],speck[2],depth('Speck',i))*CFrame.Angles"),
    ("base*CF(rune[1]+V(0,0,-.008))", "base*CF(rune[1]+V(0,0,depth('Rune',r)))"),
]

for path in sys.argv[1:]:
    text = open(path, encoding='utf-8').read()
    done = 0
    for old, new in EDITS:
        if old in text:
            text = text.replace(old, new, 1); done += 1
    open(path, 'w', encoding='utf-8').write(text)
    print('%s: %d R151 / R153 edit(s) carried over' % (path, done))
