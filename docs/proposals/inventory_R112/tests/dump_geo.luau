--!nocheck
local W=require('./world');local F=require('./fixtures');local R=W.R
F.packAssets(W)
local P=W.module('ItemPictures');local Weight=W.module('ItemWeight');local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local Players=W.service('Players');local player=R.new('Player');player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Parent=player;local gui=R.Instance.new('ScreenGui');gui.Parent=pg;local h=R.new('Folder')
local items={
 {F.pack(W,h,1,'Pack01',1,'None'),3},{F.pack(W,h,2,'Pack05',2.5,'Gold'),1},{F.pack(W,h,3,'Pack03',1.5,'None'),1},
 {F.seed(W,h,'SunflowerSeed',1,'None','Watermelon Seed'),4},{F.seed(W,h,'BluebellSeed',2,'Gold','Gold Blueberry Seed'),1},{F.seed(W,h,'SunflowerBloomSeed',1,'None','Sunflower Seed'),2},{F.seed(W,h,'AppleSeed',1,'None','Apple Seed'),1},
 {F.fruit(W,h,'SunflowerSeed',1.5,'None'),3},{F.fruit(W,h,'BluebellSeed',1,'None'),1},{F.fruit(W,h,'AppleSeed',2.5,'Gold'),1},{F.fruit(W,h,'HoloMelonSeed',1,'None',700,1,'None','Holo Melon'),1},{F.fruit(W,h,'MooncapSeed',1,'None'),1},{F.fruit(W,h,'StrawberrySeed',1,'Diamond'),1},{F.fruit(W,h,'SnowdropSeed',1,'None'),2},
 {F.shovel(W,h),1},{F.bat(W,h),1},{F.loot(W,h),1}}
local out={}
local function num(n)return string.format('%.4f',n)end
for i,e in ipairs(items)do local t=e[1]
 local f=R.new('Frame');f.Parent=gui;f.AbsolutePosition=R.Vector2.new(i,1);f.AbsoluteSize=R.Vector2.new(80,80);P.Show(f,t,2)
end
W.frames(900)
for i,e in ipairs(items)do local t=e[1];local f=gui:GetChildren()[i];local v=f:FindFirstChild('ItemViewport')
 local parts={}
 local cam=v and v:FindFirstChildOfClass('Camera')
 if v then for _,p in ipairs(v:GetDescendants())do if p:IsA('BasePart')then
  local m=p:FindFirstChildWhichIsA('SpecialMesh');local c=p.Color or R.Color3.new(.6,.6,.6);local cf=p.CFrame
  local r=cf.R
  table.insert(parts,string.format('{"c":"%s","shape":"%s","s":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"col":[%s,%s,%s],"t":%s,"mat":"%s","mesh":%s}',
   p._class,tostring(p.Shape and p.Shape.Name or ''),num(p.Size.X),num(p.Size.Y),num(p.Size.Z),num(cf.Position.X),num(cf.Position.Y),num(cf.Position.Z),
   num(r[1][1]),num(r[1][2]),num(r[1][3]),num(r[2][1]),num(r[2][2]),num(r[2][3]),num(r[3][1]),num(r[3][2]),num(r[3][3]),num(c.R),num(c.G),num(c.B),num(p.Transparency or 0),tostring(p.Material and p.Material.Name or ''),
   m and string.format('{"type":"%s","scale":[%s,%s,%s]}',tostring(m.MeshType and m.MeshType.Name or ''),num((m.Scale or R.Vector3.new(1,1,1)).X),num((m.Scale or R.Vector3.new(1,1,1)).Y),num((m.Scale or R.Vector3.new(1,1,1)).Z))or'null'))
 end end end
 local camstr='null'
 if cam then local c=cam.CFrame;local r=c.R;camstr=string.format('{"p":[%s,%s,%s],"look":[%s,%s,%s],"up":[%s,%s,%s],"fov":%s}',num(c.Position.X),num(c.Position.Y),num(c.Position.Z),num(-r[1][3]),num(-r[2][3]),num(-r[3][3]),num(r[1][2]),num(r[2][2]),num(r[3][2]),num(cam.FieldOfView))end
 local kind=t:GetAttribute('HarvestItemTool')and'Fruit'or(t:GetAttribute('GardenSeed')or t:GetAttribute('SeedPackTool'))and'Seeds'or'Tools'
 local name=Names.Tool(t,Catalog);local kg=Weight.ToolText(t)
 local def=Catalog[t:GetAttribute('SeedId')];local rar=t:GetAttribute('Rarity')or(def and def.Rarity)or'Common'
 if t:GetAttribute('SeedPackTool')then rar=({Pack01='Common',Pack03='Rare',Pack05='Legendary'})[t:GetAttribute('BagVariant')]or'Common'end
 if def and not t:GetAttribute('SeedPackTool')then rar=def.Rarity end
 table.insert(out,string.format('{"name":"%s","kg":"%s","count":%d,"kind":"%s","rarity":"%s","mutation":"%s","camera":%s,"parts":[%s]}',name,kg,e[2],kind,rar,tostring(t:GetAttribute('Mutation')or t:GetAttribute('PackMutation')or'None'),camstr,table.concat(parts,',')))
end
print('['..table.concat(out,',\n')..']')
