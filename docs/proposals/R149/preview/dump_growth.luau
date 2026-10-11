--!nocheck
-- R149 growth-style preview dump (not a test). For a bush (Blueberry), a tree (Apple) and a ground melon (Watermelon) it builds, with the
-- REAL PlantCatalog / PlantVisuals / PlantGrowth / PlantingEffects of this checkout on the Roblox mock, one frame per moment of a plant's
-- life, twice:
--  * today_*:    exactly what GardenVisuals draws today: Visuals.Build + Visuals.BeginGrowth + Visuals.UpdateGrowth (the real PlantGrowth.Apply);
--  * proposed_*: the same captured state drawn by GrowthStyle149.Apply (scratch proposal, not in src/), plus the ripe bounce + sparkles and
--                the harvest pop + puff that the proposal adds as short moments (in the game: pooled particles, here: small parts).
-- Moments: f0 = 4.2 s after planting (close-up: the R112 dirt pile has just sunk, its soil mark stays), f25 / f50 / f75 = % of the
-- growth time, ripe = 0.13 s after the plant became ripe, harvest = 0.12 s after one fruit was picked, regrow15 / regrow60 = % of that
-- fruit's regrow time. Whole-plant frames share one fixed camera per plant; f0 and the three fruit moments use close-ups (also fixed).
-- Prints "SCENE <name> <json>" lines for render_growth.mjs (fruit_models.html draws them) and INFO rows for growth_style.md.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Growth=W.module('PlantGrowth')
local Planting=W.module('PlantingEffects');local Style=W.module('GrowthStyle149')
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function parts(model)
 local out={}
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and(c.Transparency or 0)<.995 and c.Name~='VisualPivot'then table.insert(out,c)end end
 return out
end
local function dump(list)
 local out={}
 for _,c in ipairs(list)do
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
  local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
  local sm=c:FindFirstChildOfClass('SpecialMesh')
  if sm and enumName(sm.MeshType)=='Sphere'then shape='Ball';local m=sm.Scale or V3(1,1,1);s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
  local key=c:GetAttribute('ApprovedMesh');if key then shape='Mesh'end
  table.insert(out,string.format('{"shape":"%s","mesh":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
   shape,key or'',n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0)))
 end
 return out
end
local function emit(name,list,view,tile)
 print(string.format('SCENE %s {"parts":[%s],"view":%s,"tile":[%d,%d],"plant":true}',name,table.concat(dump(list),','),view,tile[1],tile[2]))
end
local function bounds(list)
 local lo,hi
 for _,p in ipairs(list)do
  local c=p.CFrame.Position;local h=p.Size*.5
  local a,b=c-h,c+h
  lo=lo and V3(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
  hi=hi and V3(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
 end
 return lo,hi
end
local function part(name,size,cframe,color,material,alpha)
 local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=color;p.Material=material or R.Enum.Material.SmoothPlastic;p.Transparency=alpha or 0
 return p
end
local function ball(name,size,cframe,color,alpha)
 local p=part(name,size,cframe,color,R.Enum.Material.SmoothPlastic,alpha)
 local m=R.new('SpecialMesh');m.MeshType=R.Enum.MeshType.Sphere;m.Scale=V3(1,1,1);m.Parent=p
 return p
end
local function concat(a,b)local out=table.clone(a);for _,x in ipairs(b)do table.insert(out,x)end;return out end
local O=CF(0,0,0)
local function baseCrop(id,key)
 local d=Catalog[id];return {Id='growth-preview-'..key,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
end
-- The R112 soil mark that stays after the dirt pile sinks (~3.5 s): two flat discs, sized and coloured as PlantingEffects:ShowMark does.
local function mark(id,crop)
 local size=Planting.Size(Planting.BaseRadius(id,crop.PlantScale));local tones=Planting.Palette();local flat=R.CFrame.Angles(0,0,math.pi/2)
 local outer=part('Planting mark',V3(.08,size.Mark*2,size.Mark*2),O*flat,tones[1]:Lerp(R.Color3.new(0,0,0),.12),R.Enum.Material.Ground);outer.Shape=R.Enum.PartType.Cylinder
 local inner=part('Planting mark hole',V3(.08,size.Mark*.9,size.Mark*.9),O*CF(0,.02,0)*flat,tones[1]:Lerp(R.Color3.new(0,0,0),.42));inner.Shape=R.Enum.PartType.Cylinder
 return {outer,inner},size.Mark
end
-- A growing plant at `now`: the real build path of GardenVisuals (BuildGrowing) with the drawing chosen by `proposed`.
local function growing(id,crop,now,proposed)
 local ripe=table.clone(crop);ripe.ReadyAt=0
 local model=Visuals.Build(id,O,ripe,4,math.huge)
 local state=Visuals.BeginGrowth(model,id,crop,O)
 if proposed then Style.Apply(state,crop,now)else Visuals.UpdateGrowth(model,crop,now)end
 return model,state
end
local function fruitBox(model)
 local lo,hi=bounds(parts(model));if not lo then return V3(0,0,0),.5 end
 local s=hi-lo;return (lo+hi)*.5,math.max(s.X,s.Y,s.Z)*.5
end
-- #7 ripe moment: every fruit group bounces (scale about its centre) and four glints sparkle around it.
local function bounce(model,t)
 local extra={}
 for _,group in ipairs(model:GetChildren())do if group.Name:match('^Harvest_%d+$')then
  local centre,radius=fruitBox(group);local s=Style.Bounce(t)
  for _,p in ipairs(parts(group))do
   local cf=p.CFrame;local d=cf.Position-centre
   p.Size=p.Size*s;p.CFrame=CF(centre.X+d.X*s,centre.Y+d.Y*s,centre.Z+d.Z*s)*cf.Rotation
  end
  local gold=R.Color3.fromRGB(255,240,170)
  for i,o in ipairs({{-1.05,.55,-.4},{1.0,.25,-.55},{.15,1.15,-.35},{-.55,-.35,-.85}})do
   local at=centre+V3(o[1],o[2],o[3])*radius*1.05;local z=math.clamp(radius*(i==3 and .42 or .30),.14,.9)
   table.insert(extra,part('Ripe glint',V3(z,z*.16,z*.16),CF(at.X,at.Y,at.Z),gold,R.Enum.Material.Neon))
   table.insert(extra,part('Ripe glint',V3(z*.16,z,z*.16),CF(at.X,at.Y,at.Z),gold,R.Enum.Material.Neon))
  end
 end end
 return extra
end
-- #8 harvest moment: the picked fruit (a clone) squashes, stretches up and fades; a puff in the fruit's own colour, lightened.
local function pop(id,crop,index,t)
 local art=Visuals.Build(id,O,crop,4,math.huge,index);local fruit=art:FindFirstChild('Harvest_'..index)
 local list=parts(fruit);local centre,radius=fruitBox(fruit);local sx,sy,lift,fade=Style.Pop(t)
 local out={}
 for _,p in ipairs(list)do
  local cf=p.CFrame;local d=cf.Position-centre;local r=cf.R
  -- Scale along world X/Z by sx and world Y by sy, mapped onto the part's own axes.
  local axis={}
  for k=1,3 do local ax=V3(r[1][k],r[2][k],r[3][k]);axis[k]=math.abs(ax.Y)*sy+(1-math.abs(ax.Y))*sx end
  local q=part(p.Name,V3(p.Size.X*axis[1],p.Size.Y*axis[2],p.Size.Z*axis[3]),CF(centre.X+d.X*sx,centre.Y+d.Y*sy+lift*radius,centre.Z+d.Z*sx)*cf.Rotation,p.Color,p.Material,p.Transparency+(1-p.Transparency)*math.max(fade,.15))
  q.Shape=p.Shape;local sm=p:FindFirstChildOfClass('SpecialMesh');if sm then local m=R.new('SpecialMesh');m.MeshType=sm.MeshType;m.Scale=sm.Scale;m.Parent=q end
  if p:GetAttribute('ApprovedMesh')then q:SetAttribute('ApprovedMesh',p:GetAttribute('ApprovedMesh'))end
  table.insert(out,q)
 end
 local tint=(list[1]and list[1].Color or R.Color3.new(1,1,1)):Lerp(R.Color3.new(1,1,1),.6)
 for i=1,6 do
  local a=(i-1)/6*math.pi*2+.4;local z=radius*(.42+(i%2)*.12)
  local at=centre+V3(math.cos(a)*radius*1.05,-radius*.45+(i%3)*radius*.22,math.sin(a)*radius*1.05)
  table.insert(out,ball('Harvest puff',V3(z,z,z),CF(at.X,at.Y,at.Z),tint,.45))
 end
 art:Destroy()
 return out
end
-- az / el: the side that shows the most fruit (these designs carry most of their fruit on the +Z side).
local plants={
 {Key='blueberry',Id='BluebellSeed',Label='Blueberry (bush)',Az=165,El=22},
 {Key='apple',Id='AppleSeed',Label='Apple (tree)',Az=150,El=12},
 {Key='melon',Id='SunflowerSeed',Label='Watermelon (ground vine)',Az=172,El=24},
}
local function camera(target,dist,az,el)
 local a,b=math.rad(az),math.rad(el)
 return target+V3(math.sin(a)*math.cos(b),math.sin(b),-math.cos(a)*math.cos(b))*dist
end
local function viewJson(t,dist,az,el)return string.format('{"target":[%s,%s,%s],"dist":%s,"az":%d,"el":%d,"fov":30}',n(t.X),n(t.Y),n(t.Z),n(dist),az,el)end
local tile={300,330}
for _,e in ipairs(plants)do
 local id=e.Id;local def=Catalog[id];local crop=baseCrop(id,e.Key);local S=def.Seconds;local Rg=def.RegrowSeconds
 local mature=Visuals.Build(id,O,crop,4,math.huge)
 local lo,hi=bounds(parts(mature));local centre=(lo+hi)*.5;local half=(hi-lo)*.5
 local radius=math.sqrt(half.X^2+half.Y^2+half.Z^2)*.86
 local dist=radius/math.sin(math.rad(15))*1.0
 local view=viewJson(centre,dist,e.Az,e.El)
 -- The picked fruit: the one nearest this camera; the fruit moments get a close-up on it.
 local eye=camera(centre,dist,e.Az,e.El);local pick,best=1,math.huge
 for i=1,def.FruitCount do local c=Visuals.FruitPosition(crop,def,i);local d=(c-eye).Magnitude;if d<best then best=d;pick=i end end
 local fruitAt=Visuals.FruitPosition(crop,def,pick);local fruitR=def.FruitRadii and def.FruitRadii[pick]or .8
 local closeFruit=viewJson(fruitAt,math.max(3.2,fruitR*6.5),e.Az,math.max(e.El,18))
 local _,state=growing(id,crop,S*.5,false)
 local temps=0;for _,c in ipairs(state.Model:GetDescendants())do if c:IsA('BasePart')and c:GetAttribute('GrowthTemporary')then temps+=1 end end
 print(table.concat({'INFO',e.Key,id,def.Name,'seconds',S,'regrow',Rg,'fruits',def.FruitCount,'parts rewritten per growth tick',#state.Parts,'temporaries today',temps,'proposal adds',5*def.FruitCount,'picked',pick},'\t'))
 -- f0: just planted (close-up camera on the soil, both rows the same).
 local soil,mr=mark(id,crop)
 local close=viewJson(V3(0,.32,0),3.4,e.Az,22)
 for _,row in ipairs({'today','proposed'})do
  local model=growing(id,crop,4.2,row=='proposed')
  emit(e.Key..'_'..row..'_f0',concat(parts(model),soil),close,tile)
  for _,pct in ipairs({25,50,75})do
   local m=growing(id,crop,S*pct/100,row=='proposed');emit(e.Key..'_'..row..'_f'..pct,parts(m),view,tile)
  end
  -- Ripe: today nothing happens at that moment; proposed: one bounce + glints.
  local ripe=Visuals.Build(id,O,crop,4,S+.13)
  emit(e.Key..'_'..row..'_ripe',row=='proposed'and concat(parts(ripe),bounce(ripe,.13))or parts(ripe),view,tile)
  -- Harvest and regrow of the picked fruit (the server's FruitStates after a pick at Tp).
  local Tp=S+20;local picked=table.clone(crop);picked.FruitStates={}
  for i=1,def.FruitCount do picked.FruitStates[tostring(i)]={ReadyAt=i==pick and Tp+Rg or S,Cycle=i==pick and 1 or 0,Duration=i==pick and Rg or nil}end
  picked.HarvestCycle=0;picked.ReadyAt=S
  for _,moment in ipairs({{'harvest',Tp+.12},{'regrow15',Tp+Rg*.15},{'regrow60',Tp+Rg*.60}})do
   local now=moment[2]
   local model=Visuals.Build(id,O,picked,4,now)
   local source=table.clone(picked);source.ReadyAt=0
   local art=Visuals.Build(id,O,source,4,math.huge,pick);local child=art:FindFirstChild('Harvest_'..pick);child.Parent=model;art:Destroy()
   local st=Visuals.BeginGrowth(child,id,picked,O)
   if row=='proposed'then Style.Apply(st,picked,now)else Visuals.UpdateGrowth(child,picked,now)end
   local list=parts(model)
   if row=='proposed'and moment[1]=='harvest'then list=concat(list,pop(id,crop,pick,.12))end
   emit(e.Key..'_'..row..'_'..moment[1],list,closeFruit,tile)
  end
 end
end
-- Fruit colour from 0 to 100 % of a fruit's growth, for the sheet's swatch panel. Today = PlantGrowth.Apply's fruit colour (leaf green
-- 83,157,64 blended in RGB towards the ripe colour over 30-94 %: PlantGrowth.lua "color=green:Lerp(r.Color,ease(.30,.94,fruit))");
-- proposed = GrowthStyle149.Ripen over 55-98 %. The ripe colour is the biggest non-leaf part of fruit 1 as the game builds it.
local green=R.Color3.fromRGB(83,157,64)
local swatches={}
for _,id in ipairs({'AppleSeed','StrawberrySeed','BluebellSeed','SunflowerSeed','EmberBloomSeed','AshRoseSeed'})do
 local art=Visuals.Build(id,O,baseCrop(id,'swatch'),4,math.huge,1);local best,colour=0,R.Color3.new(1,1,1)
 for _,p in ipairs(parts(art))do
  local v=p.Size.X*p.Size.Y*p.Size.Z
  if v>best and p:GetAttribute('GrowthRole')~='Leaf'and p:GetAttribute('GrowthForm')~='LeafBlade'and p:GetAttribute('GrowthRole')~='Stem'then best=v;colour=p.Color end
 end
 local today,proposed={},{}
 for i=0,10 do local f=i/10;table.insert(today,c3(green:Lerp(colour,Style.Ease(.30,.94,f))));table.insert(proposed,c3(Style.Ripen(colour,Style.Ease(.55,.98,f))))end
 table.insert(swatches,string.format('{"name":"%s","today":[%s],"proposed":[%s]}',Catalog[id].HarvestName or Catalog[id].Name,table.concat(today,','),table.concat(proposed,',')))
end
print('SWATCHES ['..table.concat(swatches,',')..']')
-- Plant size over the growth time (bush power .8), today vs proposed, for growth_style.md.
for _,b in ipairs({.05,.10,.25,.50,.75})do print(string.format('SIZE\t%d%%\ttoday %.0f%%\tproposed %.0f%%',b*100,Style.TodaySkeleton(b,.8)*100,Style.Skeleton(b)*100))end
