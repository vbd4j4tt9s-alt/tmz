-- R69: painted timber market with four wide entrances and a compact island counter.
-- R132 (owner: "use our current market and just polish it"): the R69 building is unchanged. Polish() adds string
-- lights, warm lamps inside, flower boxes, produce stands and the Fruit of the Hour pedestal, and puts the game's own
-- fruit, plants and seed packs where the R69 market had coloured balls and blocks (owner: "incorporate the plants and
-- fruits that are already in the game"). Those models are built just after the market, each on its own, so one that
-- cannot be built never stops the market.
local M={Center=Vector3.new(0,4,-269.275)}
M.FruitOfHour=Vector3.new(-20,0,-30)        -- pedestal centre: right of the arrival spot as you face the market
function M.Apply(map)
 local hub=assert(map:FindFirstChild('EconomyHub'))
 local old=hub:FindFirstChild('MerchantStands');if old then old:Destroy()end
 local model=Instance.new('Model');model.Name='MerchantStands';model:SetAttribute('MarketRevision',69)
 local wood={194,137,86};local lightWood={246,215,155};local darkWood={80,61,53};local trim={32,121,125}
 local function part(name,size,position,color,material,solid)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=CFrame.new(M.Center+position);p.Color=Color3.fromRGB(unpack(color));p.Material=material or Enum.Material.SmoothPlastic
  p.Anchored=true;p.CanTouch=false;p.CanCollide=false;p.CanQuery=false;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=model;return p
 end
 local function beam(name,a,b,width,color)
  local p=part(name,Vector3.new(width,width,(b-a).Magnitude),(a+b)*.5,color)
  local up=math.abs((b-a).Unit:Dot(Vector3.yAxis))>.98 and Vector3.xAxis or Vector3.yAxis
  p.CFrame=CFrame.lookAt(M.Center+(a+b)*.5,M.Center+b,up);return p
 end
 local function ball(name,position,size,color)
  local p=part(name,size,position,color,Enum.Material.SmoothPlastic);p.Shape=Enum.PartType.Ball;return p
 end
 part('Market deck',Vector3.new(30,.5,23),Vector3.new(0,.25,0),lightWood,Enum.Material.SmoothPlastic,true)
 part('Front doorstep',Vector3.new(20,.2,1.6),Vector3.new(0,.1,-11.8),wood,Enum.Material.SmoothPlastic,true)
 -- The open front leaves a direct route from the teleport to the counter.
 for _,x in ipairs({-8,8})do part('Back timber wall',Vector3.new(8,10.5,.7),Vector3.new(x,5.75,9.2),wood,Enum.Material.SmoothPlastic,true)end
 part('Back entrance lintel',Vector3.new(8,1.1,.9),Vector3.new(0,10.45,9.2),trim,Enum.Material.SmoothPlastic,true)
 part('Back doorstep',Vector3.new(12,.2,2),Vector3.new(0,.1,11.7),wood,Enum.Material.SmoothPlastic,true)
 for _,side in ipairs({-1,1})do
  local x=side*11.65
  for _,z in ipairs({-8.6,9.2})do part('Corner timber',Vector3.new(.95,11.1,.95),Vector3.new(x,6,z),darkWood,Enum.Material.SmoothPlastic,true)end
  -- 8-stud opening before scale: 13.6 studs wide, clear from deck to lintel.
  for _,z in ipairs({-6.3,6.9})do
   part('Side lower wall',Vector3.new(.7,3,4.6),Vector3.new(x,2,z),wood,Enum.Material.SmoothPlastic,true)
   part('Side window header',Vector3.new(.7,1.3,4.6),Vector3.new(x,10.35,z),wood,Enum.Material.SmoothPlastic,true)
   local pane=part('Window glass',Vector3.new(.2,5.7,3.7),Vector3.new(x,6.6,z),{104,211,220},Enum.Material.SmoothPlastic,true);pane.Transparency=.25
   for _,y in ipairs({3.7,9.6})do part('Window horizontal frame',Vector3.new(.95,.25,4.3),Vector3.new(x,y,z),lightWood)end
   for _,offset in ipairs({-2,0,2})do part('Window upright',Vector3.new(.95,5.8,.22),Vector3.new(x,6.6,z+offset),darkWood)end
  end
  for _,z in ipairs({-3.7,4.3})do part('Door timber jamb',Vector3.new(.9,10.1,.65),Vector3.new(x,5.5,z),darkWood,Enum.Material.SmoothPlastic,true)end
  part('Side entrance lintel',Vector3.new(.9,1.1,8),Vector3.new(x,10.45,.3),trim,Enum.Material.SmoothPlastic,true)
  part('Side doorstep',Vector3.new(3,.2,9),Vector3.new(side*14,.1,.3),wood,Enum.Material.SmoothPlastic,true)
  part('Side eave beam',Vector3.new(.65,.55,21),Vector3.new(side*13.35,10.95,0),darkWood)
  beam('Porch diagonal brace',Vector3.new(x,8.15,-8.6),Vector3.new(x-side*2.5,10.8,-8.6),.48,trim)
 end
 part('Porch header',Vector3.new(24,.7,.85),Vector3.new(0,10.9,-8.6),darkWood)
 local run,rise=13.65,5.2;local angle=math.atan(rise/run);local slope=math.sqrt(run*run+rise*rise)
 for _,side in ipairs({-1,1})do
  for row=1,6 do
   local f=(row-.5)/6
   local p=part('Green roof course',Vector3.new(slope/6+.10,.55,24.5),Vector3.new(side*run*f,16.25-rise*f,0),row%2==0 and{29,150,151}or{43,173,165},Enum.Material.SmoothPlastic)
   p.CFrame*=CFrame.Angles(0,0,-side*angle)
  end
  for _,z in ipairs({-12.3,12.3})do
   local p=part('Gable edge trim',Vector3.new(slope+.4,.5,.55),Vector3.new(side*run*.5,16.25-rise*.5,z),darkWood)
   p.CFrame*=CFrame.Angles(0,0,-side*angle)
  end
 end
 part('Roof ridge',Vector3.new(.85,.65,25.2),Vector3.new(0,16.38,0),{28,111,129})
 for _,z in ipairs({-8.6,9.2})do
  for level=0,5 do
   local width=math.max(1.6,23.5-level*4.2)
   part('Gable timber infill',Vector3.new(width,.85,.6),Vector3.new(0,11.35+level*.8,z),level%2==0 and lightWood or wood,Enum.Material.SmoothPlastic)
  end
  part('Gable center beam',Vector3.new(.55,4.9,.8),Vector3.new(0,13.6,z),darkWood)
 end
 part('Counter body',Vector3.new(8,3.5,3.1),Vector3.new(0,2.25,2.0),wood,Enum.Material.SmoothPlastic,true)
 part('Counter top',Vector3.new(9,.4,3.8),Vector3.new(0,4.18,2.0),lightWood,Enum.Material.SmoothPlastic,true)
 part('Counter bottom trim',Vector3.new(8.5,.35,.3),Vector3.new(0,.85,.35),darkWood)
 for i=-2,2 do part('Counter panel trim',Vector3.new(.18,2.9,.16),Vector3.new(i*1.55,2.35,.4),trim)end
 for _,x in ipairs({-8,8})do for _,y in ipairs({4.3,7.4})do
  part('Shop shelf',Vector3.new(6.5,.3,1.6),Vector3.new(x,y,8.1),darkWood)
  for i=-1,1 do
   part('Seed jar',Vector3.new(.9,1.15,.9),Vector3.new(x+i*2,y+.72,8),i==0 and{210,180,127}or{135,168,122})
   part('Jar lid',Vector3.new(1,.2,1),Vector3.new(x+i*2,y+1.35,8),trim)
  end
 end end
 for _,x in ipairs({-2.6,0,2.6})do
  part('Produce crate',Vector3.new(2.3,.6,2.6),Vector3.new(x,4.62,2),darkWood,Enum.Material.SmoothPlastic)
  for _,side in ipairs({-1,1})do part('Crate rim',Vector3.new(2.35,.35,.2),Vector3.new(x,5.0,2+side*1.2),lightWood)end
  for n=-1,1 do
   local at=Vector3.new(x+n*.64,5.18,1.9)
   ball('Fresh produce',at,Vector3.new(.72,.85,.85),x<0 and{211,81,57}or x>0 and{113,166,72}or{221,170,66})
   part('Fruit stem',Vector3.new(.12,.22,.12),at+Vector3.new(0,.53,0),darkWood)
  end
 end
 for _,x in ipairs({-9.5,9.5})do
  beam('Lantern hanger',Vector3.new(x,9.65,-9.0),Vector3.new(x,8.45,-9.0),.12,darkWood)
  local glow=part('Warm lantern',Vector3.new(.62,.85,.62),Vector3.new(x,8,-9),{255,207,123},Enum.Material.Neon)
  for _,y in ipairs({7.5,8.5})do part('Lantern cap',Vector3.new(.9,.18,.9),Vector3.new(x,y,-9),darkWood)end
  for _,side in ipairs({-1,1})do part('Lantern frame',Vector3.new(.1,1,.76),Vector3.new(x+side*.38,8,-9),darkWood)end
  local lamp=Instance.new('PointLight');lamp.Color=Color3.fromRGB(255,213,146);lamp.Brightness=.55;lamp.Range=10;lamp.Shadows=false;lamp.Parent=glow
 end
 local sign=part('Market sign',Vector3.new(16.6,2.65,.4),Vector3.new(0,9.2,-9.35),{22,92,108})
 part('Sign top trim',Vector3.new(17.1,.25,.55),Vector3.new(0,10.65,-9.35),lightWood)
 part('Sign bottom trim',Vector3.new(17.1,.25,.55),Vector3.new(0,7.8,-9.35),lightWood)
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do
  local gui=Instance.new('SurfaceGui');gui.Name='Market lettering';gui.Face=face;gui.CanvasSize=Vector2.new(960,160);gui.LightInfluence=0;gui.Parent=sign
  local title=Instance.new('TextLabel');title.Name='MarketTitle';title.Position=UDim2.fromScale(0,.02);title.Size=UDim2.fromScale(1,.94);title.BackgroundTransparency=1;title.Font=Enum.Font.FredokaOne;title.TextColor3=Color3.fromRGB(255,242,203);title.TextStrokeColor3=Color3.fromRGB(12,54,66);title.TextStrokeTransparency=.2;title.TextScaled=true;title.Text='MARKET';title.Parent=gui
 end
 -- Coral and cream porch canopy; all pieces are walk-through, including the porch posts.
 for i=1,10 do
  local x=(i-5.5)*2.15;local color=i%2==0 and{250,116,105}or{255,233,183}
  local canopy=part('Striped porch awning',Vector3.new(2.16,.18,3.9),Vector3.new(x,7.55,-11.0),color)
  canopy.CFrame*=CFrame.Angles(math.rad(-9),0,0)
  part('Awning scallop',Vector3.new(2.14,.5,.17),Vector3.new(x,7.02,-12.95),color)
 end
 for _,side in ipairs({-1,1})do
  part('Porch support',Vector3.new(.42,6.75,.42),Vector3.new(side*10.7,3.88,-12.8),trim,Enum.Material.SmoothPlastic,true)
  part('Porch gold foot',Vector3.new(.65,.8,.65),Vector3.new(side*10.7,.85,-12.8),{241,187,78})
  part('Painted corner planter',Vector3.new(2.5,1.5,2.5),Vector3.new(side*13.2,1.23,-8.2),{34,139,148})
  part('Planter gold rim',Vector3.new(2.7,.22,2.7),Vector3.new(side*13.2,2.0,-8.2),{247,209,119})
  for j=-1,1 do
   ball('Porch leaves',Vector3.new(side*13.2+j*.5,2.45,-8.2),Vector3.new(1.4,1.4,1.5),{98,173,91})
   ball('Coral flower',Vector3.new(side*13.2+j*.5,3,-8.2),Vector3.new(.52,.52,.52),j==0 and{255,206,83}or{250,130,168})
  end

 end
 part('Counter teal frontage',Vector3.new(7.8,2.7,.16),Vector3.new(0,2.35,.30),{36,141,144})
 part('Counter gold rail',Vector3.new(8.25,.16,.22),Vector3.new(0,3.78,.23),{248,211,127})
 -- Matching signs over the rear and side doors make every approach recognizable.
 for _,door in ipairs({{0,9.2,9.7,0},{-12.2,9.2,.3,math.pi/2},{12.2,9.2,.3,math.pi/2}})do
  local extra=sign:Clone();extra.Name='Market entrance sign';extra.Size=Vector3.new(8,1.8,.35)
  extra.CFrame=CFrame.new(M.Center+Vector3.new(door[1],door[2],door[3]))*CFrame.Angles(0,door[4],0);extra.Parent=model
 end
 local sizeFactor=1.70
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
  -- Keep the enlarged building's counter at avatar height.
  local localPosition=p.Position-M.Center
  if p.Name:match('^Counter')then
   p.Size=Vector3.new(p.Size.X,p.Size.Y*.55,p.Size.Z);localPosition=Vector3.new(localPosition.X,.5+(localPosition.Y-.5)*.55,localPosition.Z)
  elseif p.Name=='Produce crate'or p.Name=='Crate rim'or p.Name=='Fresh produce'or p.Name=='Fruit stem'then
   localPosition-=Vector3.new(0,1.656,0)
  end
  p.Size*=sizeFactor;p.CFrame=CFrame.new(M.Center+localPosition*sizeFactor)*p.CFrame.Rotation
 end end
 model:SetAttribute('MarketScale',sizeFactor);M.Polish(model)
 model.Parent=hub
 for _,name in ipairs({'BuyStation','SellStation'})do
  local station=assert(hub:FindFirstChild(name));station.CFrame=CFrame.new(M.Center+Vector3.new(0,3,0));station.Size=Vector3.new(2,2,2);station.Transparency=1;station.CanCollide=false;station.CanTouch=false;station.CanQuery=false
  for _,child in ipairs(station:GetChildren())do if child:IsA('BillboardGui')or child:IsA('SurfaceGui')then child.Enabled=false end end
 end
 for _,name in ipairs({'BuyTeleport','SellTeleport'})do
  local marker=hub:FindFirstChild(name)
  if not marker then marker=Instance.new('Part');marker.Name=name;marker.Parent=hub end
  marker.CFrame=CFrame.lookAt(M.Center+Vector3.new(0,1,-27),M.Center+Vector3.new(0,1,0));marker.Anchored=true;marker.Transparency=1;marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false
 end
 return model
end
-- R132 polish, in final (already scaled) local studs. Floor top y=.85; counter top y~4.48; awning edge z~-22.
local RS=game:GetService('ReplicatedStorage')
local P={Teal={36,141,144},TealDark={22,92,108},Cream={255,233,183},Gold={247,209,119},GoldDeep={241,187,78},
 Wood={194,137,86},LightWood={246,215,155},DarkWood={80,61,53},Stone={232,224,206}}
local function rgb(c)return Color3.fromRGB(c[1],c[2],c[3])end
local function maker(parent,origin)
 local function part(name,size,at,color,material,solid)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=origin*(typeof(at)=='CFrame'and at or CFrame.new(at));p.Color=rgb(color)
  p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=solid==true;p.CanTouch=false;p.CanQuery=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
 end
 local function bulb(name,d,at,color)
  local p=part(name,Vector3.new(d,d,d),at,color,Enum.Material.Neon);p.Shape=Enum.PartType.Ball;p.CastShadow=false;return p
 end
 return part,bulb
end
-- The game's own models, sized to `size` studs (largest side) and stood with their bottom centre at `at`.
local function settle(model,origin,at,size,turn)
 for _,d in ipairs(model:GetDescendants())do
  if d:IsA('BasePart')then d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false;d.CastShadow=d.Size.Magnitude>1.2
  elseif d:IsA('BaseScript')or d:IsA('ParticleEmitter')or d:IsA('Sound')then d:Destroy()end
 end
 local CS=game:GetService('CollectionService')
 for _,d in ipairs({model,table.unpack(model:GetDescendants())})do for _,tag in ipairs(CS:GetTags(d))do CS:RemoveTag(d,tag)end end
 local _,box=model:GetBoundingBox();local biggest=math.max(box.X,box.Y,box.Z)
 if biggest>0 then model:ScaleTo(model:GetScale()*size/biggest)end
 -- Turn about the model's own centre, then stand that centre bounds.Y/2 above `at`.
 local center,bounds=model:GetBoundingBox();local pivot=model:GetPivot()
 local fromCenter=CFrame.new(pivot.Position-center.Position)*pivot.Rotation
 model:PivotTo(origin*CFrame.new(at+Vector3.new(0,bounds.Y/2,0))*CFrame.Angles(0,turn or 0,0)*fromCenter)
 return model
end
local function fruit(id,parent,origin,at,size,turn)
 local model=require(RS:WaitForChild('HarvestPresentation')).Build({SeedId=id,Mutation='None',Weather='None'})
 assert(model,'no fruit model for '..id);model.Name='Market fruit';model.Parent=parent
 return settle(model,origin,at,size,turn)
end
local function plant(id,parent,origin,at,size,turn)
 local model=require(RS:WaitForChild('PlantVisuals')).Build(id,CFrame.new(),nil,4)
 assert(model,'no plant model for '..id);model.Name='Market plant';model.Parent=parent
 return settle(model,origin,at,size,turn)
end
local function pack(stage,parent,origin,at,size,turn)
 local model=require(RS:WaitForChild('SeedPackVisuals')).Bag(CFrame.new(),nil,1,nil,stage,'Pack01',1,1,'None')
 model.Name='Market seed pack';model.Parent=parent
 return settle(model,origin,at,size,turn)
end
-- Real fruit / plants / packs, in light models only (parts, no baked meshes).
M.Showcase={
 Sign={{'AppleSeed',Vector3.new(15.9,14.3,-16.3),2.7},{'EmberBloomSeed',Vector3.new(-15.9,14.3,-16.3),2.8}},
 Counter={{'AppleSeed',-4.42},{'IceberrySeed',0},{'AshRoseSeed',4.42}},
 Stands={[1]={'SunflowerSeed','AppleSeed','BluebellSeed'},[-1]={'EmberBloomSeed','AshRoseSeed','IceberrySeed'}},
 Planters={[1]='SunflowerBloomSeed',[-1]='PineappleSeed'},
 FlowerBox='MooncapSeed',
 Packs={1,6,2,3,4,5,7},
}
function M.Polish(model)
 local origin=CFrame.new(M.Center)
 local part,bulb=maker(model,origin)
 -- The R69 coloured balls and seed-jar blocks make room for the real things.
 for _,d in ipairs(model:GetDescendants())do
  if d:IsA('BasePart')and(d.Name=='Fresh produce'or d.Name=='Fruit stem'or d.Name=='Porch leaves'or d.Name=='Coral flower'or d.Name=='Seed jar'or d.Name=='Jar lid')then d:Destroy()end
 end
 -- String lights under the striped awning
 local colors={{255,214,120},{255,150,170},{140,230,255},{180,255,150}}
 part('Light wire',Vector3.new(36.4,.06,.06),Vector3.new(0,11.2,-22.15),P.DarkWood)
 for i=0,14 do
  local x=-17.5+i*2.5;local sag=math.sin(((i%5)+.5)/5*math.pi)*.6
  bulb('String light',.5,Vector3.new(x,11-sag,-22.15),colors[i%4+1])
 end
 -- Flower boxes under the four side windows
 for _,side in ipairs({-1,1})do for _,z in ipairs({-10.7,11.7})do
  part('Flower box',Vector3.new(1.4,1,6.6),Vector3.new(side*21.1,5.6,z),P.Teal)
  part('Flower box rim',Vector3.new(1.6,.2,6.8),Vector3.new(side*21.1,6.15,z),P.Gold)
 end end
 -- Produce stands beside the porch posts
 for _,side in ipairs({-1,1})do for t=0,2 do
  part('Produce tier',Vector3.new(5.4,.8,1.6),Vector3.new(side*23.2,.4+t*1.05,-23+t*1.4),P.DarkWood,nil,true)
 end end
 -- Warm lamps under the roof (also light the counter at night)
 for _,x in ipairs({-9,0,9})do
  part('Lamp cord',Vector3.new(.12,4,.12),Vector3.new(x,20,3),P.DarkWood)
  local shade=part('Lamp shade',Vector3.new(.5,2.2,2.2),CFrame.new(x,18.1,3)*CFrame.Angles(0,0,math.rad(90)),P.Teal);shade.Shape=Enum.PartType.Cylinder
  local light=Instance.new('PointLight');light.Color=Color3.fromRGB(255,214,160);light.Brightness=.8;light.Range=18;light.Shadows=false
  light.Parent=bulb('Ceiling lamp',1,Vector3.new(x,17.5,3),{255,214,150})
 end
 M.Pedestal(model,origin)
 -- The game's own fruit, plants and seed packs, built right after the market (each one on its own).
 local show=Instance.new('Model');show.Name='MarketShowcase';show.Parent=model
 local function try(fn,...)local ok,why=pcall(fn,...);if not ok then warn('[R132] Market showcase skipped one model: '..tostring(why))end end
 task.defer(function()
  local S=M.Showcase
  for _,s in ipairs(S.Sign)do try(fruit,s[1],show,origin,s[2],s[3],math.rad(-20))end
  for _,c in ipairs(S.Counter)do for n=-1,1,2 do try(fruit,c[1],show,origin,Vector3.new(c[2]+n*.62,5.2,3.2),1.05,n*.6)end end
  for side,list in pairs(S.Stands)do for t=0,2 do
   local id=list[t+1];local count=t==0 and 2 or 3
   for k=1,count do
    local x=side*23.2+(k-(count+1)/2)*(count==2 and 2.4 or 1.6)
    try(fruit,id,show,origin,Vector3.new(x,.8+t*1.05,-23+t*1.4),t==0 and 1.9 or 1.3,k*1.3)
   end
  end end
  for side,id in pairs(S.Planters)do try(plant,id,show,origin,Vector3.new(side*22.44,3.6,-13.94),5,side*.4)end
  for _,side in ipairs({-1,1})do for _,z in ipairs({-10.7,11.7})do try(plant,S.FlowerBox,show,origin,Vector3.new(side*21.1,6.25,z),2.2,side*1.2)end end
  for i,stage in ipairs(S.Packs)do
   local shelf=i<=4 and -13.6 or 13.6;local slot=(i-1)%4
   try(pack,stage,show,origin,Vector3.new(shelf+(slot-1.5)*2.2,7.45+(slot%2)*0,13.6),1.7,math.pi)
  end
 end)
end
-- Fruit of the Hour pedestal: stone plinth, teal column, gold cradle; the fruit floats above the cradle (client:
-- FruitOfHourDisplay builds it, spins it and shows the bonus). No discs or rings (owner: "remove the discs").
function M.Pedestal(parent,origin)
 local holder=Instance.new('Model');holder.Name='FruitOfTheHour';holder.Parent=parent
 local part=maker(holder,origin*CFrame.new(M.FruitOfHour))
 part('Pedestal plinth',Vector3.new(6,.8,6),Vector3.new(0,.4,0),P.Stone,nil,true)
 part('Plinth trim',Vector3.new(6.2,.2,6.2),Vector3.new(0,.9,0),P.Gold)
 for _,x in ipairs({-2.7,2.7})do for _,z in ipairs({-2.7,2.7})do
  part('Plinth stud',Vector3.new(.45,.45,.45),CFrame.new(x,1.05,z)*CFrame.Angles(0,math.rad(45),0),P.GoldDeep)
 end end
 part('Pedestal column',Vector3.new(3.8,2.4,3.8),Vector3.new(0,2.2,0),P.Teal,nil,true)
 for _,face in ipairs({{0,-1.92,0},{0,1.92,math.pi}})do
  part('Column inlay',Vector3.new(2.6,1.5,.08),CFrame.new(0,2.25,face[2])*CFrame.Angles(0,face[3],0),P.TealDark)
 end
 part('Column band',Vector3.new(4.1,.25,4.1),Vector3.new(0,3.5,0),P.Gold)
 part('Pedestal capital',Vector3.new(3.4,1,3.4),Vector3.new(0,4.1,0),P.Stone,nil,true)
 part('Capital top',Vector3.new(4,.35,4),Vector3.new(0,4.78,0),P.GoldDeep,nil,true)
 local glow=part('Cradle glow',Vector3.new(2,.08,2),Vector3.new(0,5,0),{255,230,150},Enum.Material.Neon);glow.CastShadow=false
 for i=0,3 do
  local a=i*math.pi/2+math.pi/4
  part('Cradle prong',Vector3.new(.22,1.7,.22),CFrame.new(math.cos(a)*1.15,5.65,math.sin(a)*1.15)*CFrame.Angles(0,-a,0)*CFrame.Angles(0,0,math.rad(-18)),P.GoldDeep)
 end
 local plaque=part('Pedestal plaque',Vector3.new(3,.7,.1),Vector3.new(0,2.25,-1.98),{30,34,50})
 local gui=Instance.new('SurfaceGui');gui.Name='Lettering';gui.Face=Enum.NormalId.Front;gui.CanvasSize=Vector2.new(500,116);gui.LightInfluence=0;gui.Parent=plaque
 local t=Instance.new('TextLabel');t.Name='Line1';t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.Font=Enum.Font.FredokaOne;t.TextScaled=true
 t.Text='FRUIT OF THE HOUR';t.TextColor3=rgb(P.Gold);t.Parent=gui
 local anchor=part('FruitAnchor',Vector3.new(1,1,1),Vector3.new(0,7.2,0),P.Gold);anchor.Transparency=1
 local light=Instance.new('PointLight');light.Name='FruitLight';light.Color=Color3.fromRGB(255,224,150);light.Brightness=1.2;light.Range=12;light.Shadows=false;light.Parent=anchor
 return holder,anchor
end
return M
