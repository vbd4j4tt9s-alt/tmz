-- Shared garden / harvested-item presentation. Callers own one bounded scheduler.
local RS=game:GetService('ReplicatedStorage')
local Visuals=require(RS:WaitForChild('PlantVisuals'))
local Rules=require(RS:WaitForChild('PlantRules'))
local PackRules=require(RS:WaitForChild('SeedPackRules'))
local FruitEffects=require(RS:WaitForChild('ApprovedFruitEffects'))
local Trees=require(RS:WaitForChild('TreeReworkMotion'))
local Effects={}
local function move(part,frame,batch)if batch then batch:Set(part,frame)else part.CFrame=frame end end
function Effects.Part(parent,name,size,color)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.Neon
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent;return p
end
function Effects.Profile(def,id)
 if id=='HollowGeodeSeed'then return 'RainbowGeode' end
 if id=='MoonflowerSeed'then return 'Moon' end
 if id=='StarfruitSeed'then return 'DuneStar' end
 if id=='SupernovaBloomSeed'then return 'Supernova' end
 if id=='AncientWorldrootSeed'or id=='ElderbloomSeed'then return 'Ancient' end
 if id=='ObsidianMawSeed'then return 'Magma' end
 if id=='IceberrySeed'or def.Biome=='Snow'then return 'Frost' end
 if id=='AshRoseSeed'then return 'Ash' end
 if def.Biome=='Lava'then return 'Ember' end
 if def.Biome=='Crystal'then return 'Crystal' end
 if def.Biome=='Storm'then return 'Storm' end
 if id=='MooncapSeed'then return 'Spore' end
 if id=='VenomVineSeed'then return 'Venom' end
 if id=='LanternFernSeed'then return 'Firefly' end
 if id=='MirageFigSeed'then return 'Mirage' end
 if id=='SolarStarfruitSeed'or id=='SunKingPalmSeed'then return 'Solar' end
 return nil
end
local palette={RainbowGeode=Color3.fromRGB(190,203,255),Moon=Color3.fromRGB(184,226,255),DuneStar=Color3.fromRGB(255,220,105),Ancient=Color3.fromRGB(173,232,149),Supernova=Color3.fromRGB(255,198,101),Magma=Color3.fromRGB(255,115,55),Frost=Color3.fromRGB(164,232,251),Ash=Color3.fromRGB(170,161,149),Ember=Color3.fromRGB(255,151,67),Crystal=Color3.fromRGB(193,158,255),Storm=Color3.fromRGB(122,227,242),Spore=Color3.fromRGB(127,255,212),Venom=Color3.fromRGB(158,224,90),Firefly=Color3.fromRGB(255,211,105),Mirage=Color3.fromRGB(241,184,233),Solar=Color3.fromRGB(255,205,88)}
-- R148: every plant of rank 4 or more (Legendary and up) wears a Highlight as its rarity aura, and Roblox draws at most 31 Highlights in all (the plant
-- selection view, pack previews and the weather glow use some too). The scheduler already allows only four effect plants (two in low mode, which makes no
-- aura), but it used to hand the slots out nearest-first, so a few near Legendary or Mythic plants could crowd out a King, Cosmic or Secret plant standing
-- a little further off. Slots now go by rarity rank first (higher first), then distance, then a stable key; callers pass only the plants that qualify.
function Effects.GrantSlots(entries,cap)
 table.sort(entries,function(a,b)
  if a.FxRank~=b.FxRank then return a.FxRank>b.FxRank end
  if a.Distance~=b.Distance then return a.Distance<b.Distance end
  return a.SortKey<b.SortKey
 end)
 for i,entry in ipairs(entries)do entry.FxGranted=i<=cap end
 return math.min(#entries,cap)
end
function Effects.Create(item,r,def,crop,at,mode)
 if require(RS.HologramProjection).Is(crop.SeedId)then return end
 local style=PackRules.Rarities[def.Rarity];local profile=Effects.Profile(def,crop.SeedId)
 if not profile and style.Rank<4 and crop.Mutation=='None'then return end
 local mature=not def.Mech or workspace:GetServerTimeNow()>=(crop.MatureAt or crop.ReadyAt or 0)
 local treeBody=mature and Trees.Has(crop.SeedId)and not r.FruitOnly and not r.OnlyFruit
 if not item:GetAttribute('FruitReady')and profile~='Ancient'and not treeBody then return end
 local eligible={};local camera=workspace.CurrentCamera
 for index=1,def.FruitCount do
  if (crop._VisualHarvest or Rules.FruitReady(crop,index,workspace:GetServerTimeNow()))and(not r.FruitOnly or r.Selection[index])and(not r.OnlyFruit or r.OnlyFruit==index)then
   local center=at:PointToWorldSpace(crop._HarvestCenter or Visuals.FruitPosition(crop,def,index));local saved=crop._VisualHarvest;local trait=saved and saved.Index==index and{Scale=saved.Scale,Mutation=saved.Mutation}or Rules.Fruit(crop,index,def)
   table.insert(eligible,{Index=index,Center=center,Trait=trait,Distance=camera and(center-camera.CFrame.Position).Magnitude or index})
  end
 end
 table.sort(eligible,function(a,b)return a.Distance<b.Distance end)
 if #eligible==0 and profile~='Ancient'and not treeBody then return end
 local effects=Instance.new('Model');effects.Name='PlantRarityEffects';effects:SetAttribute('EffectTheme',profile or 'Pollen');effects.Parent=item;r.Effects=effects;r.Orbits={};r.Anchors={};r.Sparks={}
 local auraColor=palette[profile]or style.Color
 if treeBody and mode=='normal'then r.TreeMotion=Trees.Capture(r.Visual,r.Origin or at);r.TreeMotion.Identity=crop.Id end
 if style.Rank>=4 and mode~='low'then
  local aura=Instance.new('Highlight');aura.Name='Rarity aura';aura.Adornee=r.Visual
  aura.FillColor=auraColor;aura.OutlineColor=auraColor;aura.FillTransparency=.95;aura.OutlineTransparency=.78
  aura.DepthMode=Enum.HighlightDepthMode.Occluded;aura.Parent=effects;r.Aura=aura
  effects:SetAttribute('AuraRank',style.Rank)
 end
 -- Pulse at most four existing luminous details; no extra lights or Heartbeat connections.
 r.GlowParts={}
 if mode~='low'and crop.Mutation=='None'then
  for _,p in ipairs(r.Visual:GetDescendants())do
   if p:IsA('BasePart')and p.Name=='Infused bark channel'then table.insert(r.GlowParts,{Part=p,Color=p.Color});if #r.GlowParts>=4 then break end end
  end
  for _,p in ipairs(r.Visual:GetDescendants())do
   if p:IsA('BasePart')and(p.Name=='Ancient living rune'or p.Name=='Royal bark inlay'or p.Name=='Supernova core'or p.Name=='Magma lobe vein'or p.Name=='Bark crystal core')and(p.Parent:GetAttribute('Mutation')or'None')=='None'then
    table.insert(r.GlowParts,{Part=p,Color=p.Color});if #r.GlowParts>=8 then break end
   end
  end
 end
 if profile=='Ancient'and not r.OnlyFruit then
  for j=1,(mode=='low'and 2 or 5)do
   local p=Effects.Part(effects,'Ancient firefly',Vector3.new(.11,.16,.11)*math.min(3,crop.PlantScale or 1),palette.Ancient)
   table.insert(r.Orbits,{Part=p,LocalCenter=CFrame.new(0,def.Height*(crop.PlantScale or 1)*.22,0),Radius=math.min(18,def.Radius*(crop.PlantScale or 1)*.44),Phase=j*2.399,Theme='Ancient'})
  end
 end
 if profile=='DuneStar'and mode~='low'then
  for _,p in ipairs(r.Visual:GetDescendants())do if p:IsA('BasePart')and p.Material==Enum.Material.Neon then
   table.insert(r.GlowParts,{Part=p,Color=p.Color});if #r.GlowParts>=8 then break end
  end end
 end
 if crop.SeedId=='MirageFigSeed'or crop.SeedId=='EmberEmperorSeed'then
  local selected={};for i=1,math.min(mode=='low'and 1 or 2,#eligible)do selected[eligible[i].Index]=true end
  r.FruitEffectsCleanup,r.FruitEffectsStep=FruitEffects.Start(r.Visual,crop.SeedId=='MirageFigSeed'and 'FigMagic'or 'EmberLava',selected,mode=='low',{Manual=true})
  return
 end
 for i=1,math.min(mode=='low'and 1 or 2,#eligible)do
  local entry=eligible[i];local index,trait=entry.Index,entry.Trait
  local radius=math.clamp((def.FruitRadii[index]or .5)*trait.Scale,.25,8)
  local color=trait.Mutation=='Gold'and Color3.fromRGB(244,191,75)or trait.Mutation=='Diamond'and Color3.fromRGB(173,216,235)or auraColor
  local anchor=Instance.new('Part');anchor.Name='Harvest glints';anchor.Size=Vector3.new(radius*.8,radius*.45,radius*.8);anchor.CFrame=CFrame.new(entry.Center)
  anchor:SetAttribute('HarvestIndex',index);anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Parent=effects;table.insert(r.Anchors,{Part=anchor,Local=at:ToObjectSpace(anchor.CFrame)})
  local emitter=Instance.new('ParticleEmitter');emitter.Name=profile or 'Golden pollen';emitter.Texture='rbxasset://textures/particles/sparkles_main.dds'
  emitter.Color=ColorSequence.new(color);emitter.LightEmission=.5;emitter.LightInfluence=.35
  emitter.Rate=mode=='low'and .7 or 1.7;emitter.Lifetime=NumberRange.new(.8,1.5)
  emitter.Speed=NumberRange.new(.12,.42);emitter.SpreadAngle=Vector2.new(100,100)
  emitter.Acceleration=Vector3.new(0,.10,0);emitter.Rotation=NumberRange.new(0,360);emitter.RotSpeed=NumberRange.new(-22,22)
  emitter.Size=NumberSequence.new(math.clamp(radius*.12,.07,.30));emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,.3),NumberSequenceKeypoint.new(1,1)})
  if profile=='RainbowGeode'then
   emitter.Name='Prismatic mineral glints';emitter.LightEmission=.9;emitter.LightInfluence=0
   if trait.Mutation=='None'then emitter.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(235,143,241)),ColorSequenceKeypoint.new(.33,Color3.fromRGB(119,195,255)),ColorSequenceKeypoint.new(.66,Color3.fromRGB(134,239,160)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,207,114))})end
   emitter.Rate=mode=='low'and 1 or 3;emitter.Speed=NumberRange.new(.15,.4)
  elseif profile=='Moon'then
   emitter.Name='Moon dust';emitter.LightEmission=.65;emitter.Rate=mode=='low'and .4 or 1.2
  elseif profile=='DuneStar'then
   emitter.Name='Dune starlight';emitter.LightEmission=1;emitter.LightInfluence=0
   emitter.Rate=mode=='low'and 3 or 9;emitter.Lifetime=NumberRange.new(.7,1.25)
   emitter.Speed=NumberRange.new(.4,1.1);emitter.Acceleration=Vector3.new(0,.6,0);emitter.SpreadAngle=Vector2.new(35,35)
   emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.06),NumberSequenceKeypoint.new(.25,.24),NumberSequenceKeypoint.new(1,0)})
  elseif profile=='Frost'or profile=='Ash'or profile=='Venom'or profile=='Mirage'then
   anchor.Name=profile=='Frost'and 'Iceberry chill'or profile..' drift'
   emitter.Name=profile=='Frost'and 'Chilling frost'or profile..' drift';emitter.Texture='rbxasset://textures/particles/smoke_main.dds'
   emitter.LightEmission=profile=='Ash'and 0 or .18;emitter.LightInfluence=.70
   emitter.Rate=mode=='low'and 1 or 2.2;emitter.Lifetime=NumberRange.new(.85,1.5)
   emitter.Speed=NumberRange.new(.1,.35);emitter.Acceleration=Vector3.new(.08,profile=='Frost'and -.3 or .20,0)
   emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,math.clamp(radius*.35,.15,.85)),NumberSequenceKeypoint.new(1,math.clamp(radius*.70,.3,1.6))})
   emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,.78),NumberSequenceKeypoint.new(1,1)})
  elseif profile=='Ember'or profile=='Supernova'or profile=='Magma'then
   emitter.Name='Rising embers';emitter.LightEmission=.8;emitter.LightInfluence=.1;emitter.Speed=NumberRange.new(.35,.85);emitter.Acceleration=Vector3.new(.10,.50,0)
   emitter.Rate=mode=='low'and 1 or 2.4
  elseif profile=='Spore'then
   emitter.Name='Luminous spores';emitter.Color=ColorSequence.new(palette.Spore);emitter.LightEmission=.75;emitter.Speed=NumberRange.new(.12,.32);emitter.Acceleration=Vector3.new(0,.18,0)
  elseif profile=='Storm'then
   emitter.Name='Static sparks';emitter.Lifetime=NumberRange.new(.3,.65);emitter.Speed=NumberRange.new(.3,.65);emitter.LightEmission=.8
  elseif profile=='Crystal'then
   emitter.Name='Crystal shimmer';emitter.Speed=NumberRange.new(.08,.22);emitter.LightEmission=.65
  end
  emitter.Parent=anchor
  if profile=='Ash'and mode~='low'then
   local ember=emitter:Clone();ember.Name='Ash embers';ember.Texture='rbxasset://textures/particles/sparkles_main.dds';ember.Color=ColorSequence.new(palette.Ember)
   ember.Rate=.9;ember.Lifetime=NumberRange.new(.6,1.1);ember.LightEmission=.75;ember.LightInfluence=.15;ember.Size=NumberSequence.new(.10);ember.Acceleration=Vector3.new(.1,.35,0);ember.Parent=anchor
  end
  if profile=='Supernova'then
   for j=1,(mode=='low'and 5 or 12)do
    local line=Effects.Part(effects,'Boom bloom spark line',Vector3.new(.06,.06,1),color)
    local phase=j*2.399+index*.9
    table.insert(r.Sparks,{Part=line,LocalCenter=at:ToObjectSpace(CFrame.new(entry.Center)),Radius=radius,Phase=phase,Direction=Vector3.new(math.cos(phase),.20+math.sin(j*1.71)*.65,math.sin(phase)).Unit})
   end
  end
  if mode~='low'and (style.Rank>=4 or profile)and profile~='Supernova'and profile~='Ancient'then
   for j=1,(profile=='DuneStar'and 6 or profile=='Frost'and 2 or math.max(1,math.min(3,style.Rank-2)))do
    local orb=Instance.new(profile=='Storm'and 'WedgePart'or 'Part');orb.Name='Harvest biome accent'
    if orb:IsA('Part')then orb.Shape=(profile=='Ember'or profile=='Spore'or profile=='Firefly'or not profile)and Enum.PartType.Ball or Enum.PartType.Block end
    local z=math.clamp(radius*.085,.07,.28);orb.Size=Vector3.new(z,z*1.35,z*.70)
    orb.Material=profile=='Frost'and Enum.Material.Ice or Enum.Material.Neon;orb.Color=color;orb.Transparency=.25
    orb.Anchored=true;orb.CanCollide=false;orb.CanQuery=false;orb.CanTouch=false;orb.CastShadow=false
    orb:SetAttribute('HarvestIndex',index);orb.Parent=effects
    table.insert(r.Orbits,{Part=orb,LocalCenter=at:ToObjectSpace(CFrame.new(entry.Center)),Radius=radius*.9,Phase=index*1.37+j*2.399,Biome=def.Biome,Theme=profile})
   end
  end
 end
end

function Effects.Step(r,t,batch,pose)
 local at=pose or r.Visual:GetPivot()
 if r.TreeMotion then Trees.Step(r.TreeMotion,at,t,r.TreeMotion.Identity,batch)end
 if r.FruitEffectsStep then r.FruitEffectsStep(t,batch)end
 if r.GlowParts then for i,e in ipairs(r.GlowParts)do if e.Part.Parent then
  local seam=e.Part.Name=='Infused bark channel'
  e.Part.Color=e.Color:Lerp(seam and e.Color:Lerp(Color3.new(0,0,0),.22) or Color3.new(1,1,.86),(.5+.5*math.sin(t*(r.Crop.SeedId=='SupernovaBloomSeed'and 1.05 or .65)+i*.6))*(seam and .35 or .18))
 end end end
 if r.Aura then r.Aura.FillTransparency=.95+math.sin(t*.85)*.025;r.Aura.OutlineTransparency=.77+math.sin(t*.85)*.07 end
 if r.LastAnchorPose~=at then
  for _,a in ipairs(r.Anchors or{})do if a.Part.Parent then move(a.Part,at*a.Local,batch)end end
  r.LastAnchorPose=at
 end
 for _,orbit in ipairs(r.Orbits or{})do
  local angle=t*.36+orbit.Phase;local y=math.sin(angle*1.3)*orbit.Radius*.28
  if orbit.Theme=='Ember'or orbit.Theme=='Ash'or orbit.Theme=='Magma'then y=((t*.23+orbit.Phase)%1-.5)*orbit.Radius*1.1 end
  if orbit.Theme=='DuneStar'then y=orbit.Radius*(.15+.10*math.sin(angle*1.3));orbit.Part.Transparency=.20+.25*(.5+.5*math.sin(t*2+orbit.Phase))end
  local radius=orbit.Radius*(1+math.sin(t*.65+orbit.Phase)*.08)
  move(orbit.Part,at*orbit.LocalCenter*CFrame.new(math.cos(angle)*radius,y,math.sin(angle)*radius)*CFrame.Angles(t*.3,angle,.5),batch)
 end
 for _,spark in ipairs(r.Sparks or{})do
  local u=(t*.95+spark.Phase)%1;local distance=spark.Radius*(.12+u*1.28)
  local travel=spark.Direction*distance+Vector3.new(0,-u*u*spark.Radius*.28,0)
  local length=spark.Radius*(.11+.28*math.sin(u*math.pi));local endPoint=at*spark.LocalCenter*CFrame.new(travel)
  local forward=at:VectorToWorldSpace(spark.Direction)
  move(spark.Part,CFrame.lookAt(endPoint.Position,endPoint.Position+forward),batch)
  spark.Part.Size=Vector3.new(math.max(.025,spark.Radius*.023),math.max(.025,spark.Radius*.023),length)
  spark.Part.Transparency=u<.06 and 1-u/.06 or u>.65 and(u-.65)/.35 or 0
 end
end
function Effects.Clear(r)
 if r.TreeMotion then Trees.Reset(r.TreeMotion,r.Origin or r.Visual:GetPivot());r.TreeMotion=nil end
 if r.GlowParts then for _,e in ipairs(r.GlowParts)do if e.Part.Parent then e.Part.Color=e.Color end end;r.GlowParts=nil end
 if r.FruitEffectsCleanup then r.FruitEffectsCleanup();r.FruitEffectsCleanup=nil end;r.FruitEffectsStep=nil
 if r.Effects then r.Effects:Destroy();r.Effects=nil end
 r.Orbits=nil;r.Aura=nil;r.Sparks=nil;r.Anchors=nil;r.LastAnchorPose=nil
end
return Effects
