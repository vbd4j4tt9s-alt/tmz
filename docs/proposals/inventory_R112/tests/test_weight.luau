--!nocheck
local W=require('./world')
local Weight=W.module('ItemWeight')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function eq(a,b,msg)check(a==b,msg..': got '..tostring(a)..' want '..tostring(b))end
-- Formatter rules.
eq(Weight.Format(2.44),'2.4kg','one decimal under 10')
eq(Weight.Format(2.45),'2.5kg','round half up') -- 24.5 -> 25
eq(Weight.Format(5),'5kg','drop .0')
eq(Weight.Format(0.01),'0.1kg','minimum 0.1kg')
eq(Weight.Format(9.94),'9.9kg','below 9.95 keeps decimal')
eq(Weight.Format(9.96),'10kg','9.96 -> 10kg (no 10.0kg)')
eq(Weight.Format(12.5),'13kg','whole numbers above 10')
eq(Weight.Format(1250.4),'1,250kg','thousands separator')
eq(Weight.Format(1234567),'1,234,567kg','millions separator')
eq(Weight.Format(0/0),'','NaN -> empty');eq(Weight.Format(-1),'','negative -> empty');eq(Weight.Format(math.huge),'','inf -> empty');eq(Weight.Format(nil),'','nil -> empty')
-- Size is linear; bad sizes fall back to 1.
local base=Weight.Base('Fruit','SunflowerSeed')
eq(Weight.Weight('Fruit','SunflowerSeed',2),base*2,'linear in size')
eq(Weight.Weight('Fruit','SunflowerSeed',0/0),base,'NaN size -> 1')
eq(Weight.Weight('Fruit','SunflowerSeed',-3),base,'negative size -> 1')
eq(Weight.Weight('Plant','SunflowerSeed',1),base,'Plant aliases Fruit')
-- Species ordering: watermelon heavier than a berry; unknown ids get a sane default.
check(Weight.Base('Fruit','SunflowerSeed')>Weight.Base('Fruit','BluebellSeed')*3,'watermelon > 3x berry bunch')
check(Weight.Base('Fruit','NoSuchSeed')>0,'unknown fruit base > 0')
check(Weight.Base('Seed','SunflowerSeed')<Weight.Base('Fruit','SunflowerSeed'),'seed lighter than fruit')
local lo,hi=math.huge,0
for id,def in pairs(W.module('PlantCatalog'))do if type(def)=='table'and def.FruitRadii then
 local f=Weight.Base('Fruit',id);local s=Weight.Base('Seed',id);lo=math.min(lo,f);hi=math.max(hi,f)
 check(f>=.05 and f<=500,'fruit base in range '..id);check(s>=.1 and s<=1,'seed base in range '..id)
end end
-- Packs by tier.
local P=W.module('SeedPackRules')
local last=0
for _,v in ipairs(P.VariantOrder)do local b=Weight.Base('Pack',v);check(b>=last,'pack tiers non-decreasing '..v);last=b end
eq(Weight.Base('Pack','Pack01'),1,'common pack base');eq(Weight.Base('Pack','Pack06'),3,'mythic pack base')
eq(Weight.Base('Pack','EclipseReliquary'),4,'void pack base');eq(Weight.Base('Pack','MechLimited'),3,'limited pack base')
eq(Weight.Base('Pack','Small'),1,'legacy small');eq(Weight.Base('Pack','Grand'),1.5,'legacy grand');eq(Weight.Base('Pack','Bogus'),1.25,'unknown pack -> standard')
eq(Weight.Text('Pack','Pack05',2.5),'6.3kg','legendary 2.5x pack') -- 2.5*2.5=6.25 -> 6.3
eq(Weight.Text('Pack','Pack01',25),'25kg','25x common pack')
-- Tools.
local R=W.R
local fruit=R.new('Tool');fruit:SetAttribute('HarvestItemTool',true);fruit:SetAttribute('SeedId','SunflowerSeed');fruit:SetAttribute('FruitScale',1.5)
eq(Weight.ToolText(fruit),Weight.Text('Fruit','SunflowerSeed',1.5),'fruit tool')
local seed=R.new('Tool');seed:SetAttribute('GardenSeed',true);seed:SetAttribute('SeedId','BluebellSeed');seed:SetAttribute('SeedScale',2)
eq(Weight.ToolText(seed),Weight.Text('Seed','BluebellSeed',2),'seed tool')
local pack=R.new('Tool');pack:SetAttribute('SeedPackTool',true);pack:SetAttribute('BagVariant','Pack03');pack:SetAttribute('PackSize',1.5)
eq(Weight.ToolText(pack),'2.3kg','pack tool 1.5 x 1.5') -- 2.25 -> 2.3
local shovel=R.new('Tool');shovel:SetAttribute('GardenShovel',true);eq(Weight.ToolText(shovel),'','shovel has no weight');eq(Weight.ToolText(nil),'','nil tool')
-- Examples for the report.
for _,e in ipairs({{'Fruit','BluebellSeed',1},{'Fruit','SunflowerSeed',1},{'Fruit','SunflowerSeed',2.5},{'Fruit','AppleSeed',1},{'Fruit','MooncapSeed',1.5},{'Fruit','OrbitLotusSeed',1},{'Seed','SunflowerSeed',1},{'Seed','OrbitLotusSeed',2},{'Pack','Pack01',1},{'Pack','Pack06',2.5},{'Pack','EclipseReliquary',1}})do
 print(string.format('  %-5s %-18s size %-4s -> %s',e[1],e[2],tostring(e[3]),Weight.Text(e[1],e[2],e[3])))
end
print(string.format('fruit base range %.2f..%.2f kg',lo,hi))
print(('%d checks, %d failures'):format(checks,fails))
