--!nocheck
-- Shared fixtures: fake pack mesh assets and inventory tools of every kind.
local F={}
function F.packAssets(W)
 local R=W.R;local folder=R.new('Folder');folder.Name='SeedPackMeshAssets'
 for _,biome in ipairs({'Forest','Desert','Snow','Lava','Crystal','Jungle','Storm'})do for d=1,6 do
  local m=R.new('Model');m.Name=string.format('%s_%02d',biome,d);m:SetAttribute('MeshBakeVersion',123)
  local parts={{'Body',R.Vector3.new(1.9,2.3,.5),R.CFrame.new(0,0,0)},{'Band',R.Vector3.new(1.95,.3,.55),R.CFrame.new(0,.9,0)},{'Label',R.Vector3.new(1.2,.8,.05),R.CFrame.new(0,0,-.27)}}
  for i,s in ipairs(parts)do local p=R.new('MeshPart');p.Name=s[1];p.Size=s[2];p.CFrame=s[3];p.Color=R.Color3.fromRGB(180+i*20,140,90);p:SetAttribute('PackLocalFrame',s[3]);p.Parent=m end
  m:SetAttribute('MeshCount',#parts);m.Parent=folder
 end end
 folder.Parent=W.RS
end
function F.tool(W,name,attrs,parent,parts)
 local R=W.R;local t=R.new('Tool');t.Name=name
 for k,v in pairs(attrs)do t:SetAttribute(k,v)end
 local h=R.new('Part');h.Name='Handle';h.Size=R.Vector3.new(.2,.2,.2);h.Transparency=1;h.Parent=t
 for i,p in ipairs(parts or{})do local q=R.new('Part');q.Name=p[1];q.Size=p[2];q.CFrame=p[3];q.Color=p[4];q.Transparency=0;q.Parent=t end
 t.Parent=parent;return t
end
local n=0
local function id()n+=1;return string.format('inv-%04d',n)end
function F.pack(W,parent,stage,variant,size,mutation,name)
 local biomes={[1]='Forest',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[6]='Jungle',[7]='Storm'}
 return F.tool(W,name or((mutation~='None'and mutation..' 'or'')..(biomes[stage]or'Biome')..' Seed Pack'),{SeedPackTool=true,SeedInventoryId=id(),PackSize=size,PackMutation=mutation,Weather='None',Stage=stage,BagVariant=variant,SeedScale=1},parent)
end
function F.seed(W,parent,seedId,scale,mutation,name)
 return F.tool(W,name or((mutation~='None'and mutation..' 'or'')..seedId),{GardenSeed=true,SeedInventoryId=id(),SeedId=seedId,SeedScale=scale,Mutation=mutation,Weather='None',Rarity='Common',Stage=1},parent)
end
function F.fruit(W,parent,seedId,scale,mutation,value,index,weather,fruitName)
 local inv=id()
 return F.tool(W,(mutation~='None'and mutation..' 'or'')..seedId,{HarvestItemTool=true,HarvestInventoryId=inv,InventoryKey=inv,SeedId=seedId,Mutation=mutation,Weather=weather or'None',FruitScale=scale,SellValue=value or 100,FruitName=fruitName,SourceCropId='crop-'..seedId,FruitIndex=index or 1,HarvestCycle=0,Rarity='Common'},parent)
end
function F.shovel(W,parent)return F.tool(W,'Shovel',{GardenShovel=true,InventoryKey='shovel'},parent)end
function F.bat(W,parent)
 local R=W.R;local brown=R.Color3.fromRGB(178,139,91)
 return F.tool(W,'Bat',{ChestChaseBat=true,BatAppearanceAssetId=123,BatAppearanceVersion=42},parent,{
  {'Neck',R.Vector3.new(1.1,.34,.34),R.CFrame.new(0,.9,0)*R.CFrame.Angles(0,0,math.pi/2),brown},
  {'Barrel',R.Vector3.new(2.5,.64,.64),R.CFrame.new(0,2.55,0)*R.CFrame.Angles(0,0,math.pi/2),brown},
  {'Knob',R.Vector3.new(.14,.43,.43),R.CFrame.new(0,-.5,0)*R.CFrame.Angles(0,0,math.pi/2),R.Color3.fromRGB(43,39,37)}})
end
function F.loot(W,parent)
 local R=W.R
 return F.tool(W,'Golden Idol',{LootItemTool=true,LootInstanceName='loot-1',LootName='Golden Idol',Rarity='Rare'},parent,{{'Idol',R.Vector3.new(.8,1.2,.8),R.CFrame.new(0,0,0),R.Color3.fromRGB(255,210,80)}})
end
return F
