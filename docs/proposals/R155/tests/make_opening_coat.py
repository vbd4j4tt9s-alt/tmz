"""R155: the R153 Mech opening suite (docs/proposals/R153/tests/test_mech_opening153.luau) run on a GOLD or a DIAMOND Mech pack.
Usage: python3 make_opening_coat.py Gold|Diamond OUT.luau

Reads the R153 test and writes a copy in which the server's carried Mech pack (ChestService / SeedPackVisuals.CarryBag) has the coat, so every one of its 167 checks (the clicks, the beats,
the sound caps, calm, onlooker, skip, clean-up) runs on a coated pack, plus one more check at the end: the seed the REAL SeedPackClient reveals from a coated Mech pack is the same coat
(the model's Mutation attribute and the material of every visible part), for every opening the suite drove; a plain pack of another biome reveals a plain seed.
The copy is mechanical (three literal replacements, each asserted), so the R153 suite and this one can never drift apart."""
import sys

coat = sys.argv[1]
assert coat in ('Gold', 'Diamond')
here = __file__.replace('\\', '/').rsplit('/', 1)[0]
src = open(here + '/../../R153/tests/test_mech_opening153.luau', encoding='utf-8').read()


def once(text, old, new):
    assert text.count(old) == 1, 'expected exactly one: ' + old[:60]
    return text.replace(old, new)


# 1. the carried Mech pack has the coat (every other pack is plain, as before)
src = once(src, "Visuals.CarryBag(char,pack.Stage,pack.Variant,1,1,'None')", "Visuals.CarryBag(char,pack.Stage,pack.Variant,1,1,pack.Stage==8 and COAT or'None')")
src = once(src, "local fails,checks=0,0\n", "local COAT='%s'\nlocal seedSeen={}\nlocal fails,checks=0,0\n" % coat)
# 2. every reveal seed is looked at once, on the frame it first exists
src = once(src, "  frames[#frames+1]=f\n", """  frames[#frames+1]=f
  local sd=W.workspace:FindFirstChild('RewardSeed',true)
  if sd and not seedSeen[sd]then
   local e={Coat=sd:GetAttribute('Mutation'),Parts=0,Coated=0,Stage=opts.Pack and opts.Pack.Stage or 8}
   local want=COAT=='Gold'and R.Enum.Material.Metal or R.Enum.Material.Glass
   for _,d in ipairs(sd:GetDescendants())do if d:IsA('BasePart')and d.Transparency<.95 then
    e.Parts+=1
    local c=d.Color;local tint=COAT=='Gold'and(c.R>=.85 and c.G>=.6 and c.G<=.82 and c.B<=.35)or(c.B>=.99 and c.G>=.85) -- (PlantVisuals.Coat's gold / ice colours)
    if d.Material==want and tint then e.Coated+=1 end
   end end
   seedSeen[sd]=e
  end
""")
# 3. the extra check, before the final tally
tail = """local coatedSeeds,plainSeeds,badSeeds=0,0,{}
for _,e in pairs(seedSeen)do
 if e.Stage==8 then
  coatedSeeds+=1
  if not(e.Coat==COAT and e.Parts>0 and e.Coated==e.Parts)then badSeeds[#badSeeds+1]=tostring(e.Coat)..' '..e.Coated..'/'..e.Parts end
 else
  plainSeeds+=1
  if e.Coat~='None'then badSeeds[#badSeeds+1]='plain pack: '..tostring(e.Coat) end
 end
end
check(coatedSeeds>=8 and#badSeeds==0,('the seed the real SeedPackClient reveals from a '..COAT..' Mech pack is '..COAT..' (every visible part %s): %d openings; %d plain-pack control(s) reveal plain seeds (%s)'):format(COAT=='Gold'and'Metal'or'Glass',coatedSeeds,plainSeeds,table.concat(badSeeds,'; ')))
print(('%d Mech openings driven'):format(#opened))
"""
src = once(src, "print(('%d Mech openings driven'):format(#opened))\n", tail)
open(sys.argv[2], 'w', encoding='utf-8').write(src)
