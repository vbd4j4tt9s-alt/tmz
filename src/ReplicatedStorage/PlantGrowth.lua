local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('PlantRules'))
-- V149 revision 9: timestamp-driven growth, shared by near art and server fallback.
-- This module never changes saved crops, readiness, rewards, prompts or collision rules.
local G={};local V,CF=Vector3.new,CFrame.new
local function unit(v)return math.clamp(v,0,1)end
local function ease(a,b,x)local t=unit((x-a)/math.max(.001,b-a));return t*t*(3-2*t)end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local flowers={SunflowerBloomSeed=true,ThunderTulipSeed=true,DatePalmSeed=true,CrystalLilySeed=true,WinterPineSeed=true,LavaLotusSeed=true,OrbitLotusSeed=true,TempestLotusSeed=true,BlackoutBloomSeed=true,PolarStarbloomSeed=true,SupernovaBloomSeed=true,TigerOrchidSeed=true,VoltOrchidSeed=true,SilentFrostbellSeed=true}
local ground={SunflowerSeed=true,SnowdropSeed=true,MoonflowerSeed=true,EmberBloomSeed=true}
function G.Profile(id,def)
 return id=='StarfruitSeed'and 'GroundStar'or ground[id]and 'Vine' or flowers[id]and 'Flower' or id=='MooncapSeed'and 'Mushroom' or def.Tree and 'Tree' or def.Mode=='whole'and 'Leafy' or 'Bush'
end
local function growthSeed(crop)
 local h=17;for i=1,#tostring(crop.Id or '')do h=(h*31+string.byte(tostring(crop.Id or ''),i))%997 end;return h/996
end
function G.Progress(crop,def,now,index)
 local finish=crop.MatureAt or crop.ReadyAt;local start=crop.PlantedAt
 if not finite(start)or not finite(finish)then return 1,now>=(crop.ReadyAt or 0)and 1 or 0 end
 local body=unit((now-start)/math.max(1,finish-start))
 local readyAt=Rules.FruitReadyAt(crop,index or 1);local cycle=Rules.FruitCycle(crop,index or 1)
 local fruit
 if body<1 or cycle==0 then fruit=ease((def.Tree and .57 or ground[crop.SeedId]and .40 or flowers[crop.SeedId]and .50 or .46)+(growthSeed(crop)-.5)*.06,1,body)
 else local state=crop.FruitStates and crop.FruitStates[tostring(index or 1)];local duration=math.max(1,(state and state.Duration)or def.RegrowSeconds or def.Seconds or 1);fruit=unit((now-(readyAt-duration))/duration)end
 if now>=readyAt then fruit=1 end
 return body,fruit
end
function G.Timer(crop,def,now)
 local index,soon,ready=1,math.huge,0
 for i=1,def.FruitCount do local at=Rules.FruitReadyAt(crop,i);if Rules.FruitReady(crop,i,now)then ready+=1 elseif at>now and at<soon then soon=at;index=i end end
 local body,fruit=G.Progress(crop,def,now,index);local seconds=soon<math.huge and math.max(0,math.ceil(soon-now))or 0
 if seconds==0 then return 'READY',1 end
 local phase=body<1 and body or fruit
 local word=body>=1 and 'Regrowing'or phase<.12 and 'Sprouting'or phase<.55 and 'Growing'or phase<.84 and 'Budding'or 'Almost ready'
 local time=seconds>=3600 and string.format('%dh %02dm',math.floor(seconds/3600),math.floor(seconds%3600/60))or seconds>=60 and string.format('%dm %02ds',math.floor(seconds/60),seconds%60)or tostring(seconds)..'s'
 return (ready>0 and tostring(ready)..' ready • Next 'or word..' · ')..time,phase
end
function G.Sway(id,def,crop,time)
 local h=math.max(1,def.Height*(crop.PlantScale or 1));local hash=0
 for i=1,#tostring(crop.Id or id)do hash=(hash*31+string.byte(tostring(crop.Id or id),i))%997 end
 -- Keep giant trees visually aligned with their static climbing surfaces and fruit prompts.
 if id=='StarfruitSeed'or def.Mech then return CFrame.new()end
 local flower=flowers[id]==true;local a=math.min(flower and .044 or def.Tree and .005 or .009,(flower and .68 or .10)/h)
 return CFrame.Angles((math.sin(time*.83+hash)*.82+math.sin(time*1.31+hash*.3)*.18)*a,0,math.sin(time*.64+hash*.7)*a*.70)
end
local function plain(parent,name,color,kind)
 local p=Instance.new(kind or 'Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Size=V(.1,.1,.1);p.Transparency=1;p.Parent=parent
 return p
end
local green=Color3.fromRGB(83,157,64)
function G.Capture(model,id,def,crop,origin,sockets)
 if def.Mech then return require(script.Parent.MechGrowth).Capture(model,id,def,crop,origin,sockets)end
 local state={Model=model,Id=id,Def=def,Origin=origin,Parts={},Buds={},Profile=G.Profile(id,def)}
 local groupBounds={}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 then
  local frame=origin:ToObjectSpace(p.CFrame);local g=p:GetAttribute('GrowthGroup')or 0
  local form=p:GetAttribute('GrowthForm')or'';local role=p:GetAttribute('GrowthRole')or'';local name=p.Name:lower()
  local fruit=g>0 and def.Mode~='whole'
  local foliage=role=='Canopy'or role=='Leaf'or form=='LeafBlade'or form=='ProxyBlade'or name:find('petal',1,true)or name:find('dome',1,true)
  local r={Part=p,Frame=frame,Size=p.Size,Color=p.Color,Material=p.Material,Alpha=p.Transparency,Query=p.CanQuery,Group=g,Fruit=fruit,Foliage=foliage,Index=p:GetAttribute('ArtSpecIndex')or 1}
  table.insert(state.Parts,r)
  if fruit then
   local b=groupBounds[g]or{Min=V(math.huge,math.huge,math.huge),Max=V(-math.huge,-math.huge,-math.huge)}
   local c=frame.Position;local z=p.Size/2
   b.Min=V(math.min(b.Min.X,c.X-z.X),math.min(b.Min.Y,c.Y-z.Y),math.min(b.Min.Z,c.Z-z.Z));b.Max=V(math.max(b.Max.X,c.X+z.X),math.max(b.Max.Y,c.Y+z.Y),math.max(b.Max.Z,c.Z+z.Z));groupBounds[g]=b
  end
 end end
 state.Seed=plain(model,'New seed',Color3.fromRGB(117,89,51));state.Seed.Shape=Enum.PartType.Ball
 state.Seed:SetAttribute('GrowthTemporary',true)
 state.Sprout={plain(model,'Baby stem',green),plain(model,'Baby leaf',green,'WedgePart'),plain(model,'Baby leaf',green,'WedgePart')}
 for _,part in ipairs(state.Sprout)do part:SetAttribute('GrowthTemporary',true)end
 state.Anchors={} 
 for i,b in pairs(groupBounds)do
  local socket=(sockets and sockets[i]or V(table.unpack(def.Sockets[i])))*(crop.PlantScale or 1);local anchor=socket
  -- Every fruit grows from its authored branch/stem socket, including ground vines.
  state.Anchors[i]=anchor
  local bud=plain(model,'Growing bud',green);bud.Shape=Enum.PartType.Ball;bud:SetAttribute('GrowthTemporary',true)
  local stem=plain(model,'Growing fruit stalk',green);stem:SetAttribute('GrowthTemporary',true)
  state.Buds[i]={Part=bud,Stem=stem,Anchor=anchor,Socket=socket}
 end
 return state
end
function G.Apply(state,crop,now)
 if state.Mech then return require(script.Parent.MechGrowth).Apply(state,crop,now,G.Progress)end
 local body,fruit=G.Progress(crop,state.Def,now)
 local scale=body>=1 and 1 or ease(.025,1,body)^(state.Profile=='Tree'and(.84+growthSeed(crop)*.12)or state.Profile=='Vine'and(.68+growthSeed(crop)*.10)or(.73+growthSeed(crop)*.14))
 local alive=body>.028
 local seed=state.Seed;local seedSize=.14+.20*ease(0,.10,body)
 seed.Size=V(seedSize,seedSize,seedSize);seed.CFrame=state.Origin*CF(0,seedSize*.45,0)
 seed.Transparency=body>=.18 and 1 or ease(.07,.18,body)
 local baby=state.Sprout;local h=.10+.50*ease(.02,.25,body);local fade=state.Id=='StarfruitSeed'and 1 or(body<.025 and 1 or ease(.26,.46,body))
 baby[1].Size=V(.055,h,.055);baby[1].CFrame=state.Origin*CF(0,h*.5,0);baby[1].Transparency=fade
 for i=2,3 do local side=i==2 and -1 or 1;baby[i].Size=V(.055,.14+h*.18,.21+h*.17);baby[i].CFrame=state.Origin*CF(side*(.08+h*.08),h*.78,0)*CFrame.Angles(0,0,side*.65);baby[i].Transparency=fade end
 -- Progress depends on fruit slots, not on the number of mesh/surface pieces.
 local progress,readiness={},{}
 for i=1,state.Def.FruitCount do local _,f=G.Progress(crop,state.Def,now,i);progress[i]=f;readiness[i]=Rules.FruitReady(crop,i,now)end
 local previous=state.Progress or{};local priorReady=state.Readiness or{}
 local sameBody=state.Body==1 and body==1 and state.Mutation==crop.Mutation
 for _,r in ipairs(state.Parts)do
  local p=r.Part;local index=math.max(1,r.Group);local fruit=progress[index]or progress[1];local ripe=readiness[index]
  if p.Parent and(not sameBody or(r.Fruit and(previous[index]~=fruit or priorReady[index]~=ripe)))then
   local factor=1;local alpha=r.Alpha;local pos=r.Frame.Position;local color=r.Color
   if r.Fruit then
    factor=ease(.015,1,fruit)
    local anchor=state.Anchors[r.Group]or V(table.unpack(state.Def.Sockets[r.Group]))*(crop.PlantScale or 1)
    pos=anchor+(pos-anchor)*factor
    if fruit<.01 then alpha=1 end
    if (crop.Mutation=='None'or crop.Mutation==nil)and state.Id~='StarfruitSeed'then color=green:Lerp(r.Color,ease(.30,.94,fruit))end
   elseif r.Foliage and body<1 then
    -- Reveal attached foliage in staggered groups; geometry stays joined to the stems.
    local start=.12+(r.Index%5)*.025;alpha=1-(1-r.Alpha)*ease(start,.78+(r.Index%3)*.04,body)
   elseif body<1 and(crop.Mutation=='None'or crop.Mutation==nil)then color=green:Lerp(r.Color,ease(.25,.78,body))end
   local amount=scale*factor
   p.Size=V(math.max(.01,r.Size.X*amount),math.max(.01,r.Size.Y*amount),math.max(.01,r.Size.Z*amount))
   p.CFrame=state.Origin*CF(pos*scale)*r.Frame.Rotation
   p.Transparency=alive and amount>.0001 and alpha or 1;p.Color=color
   p.Material=r.Fruit and fruit<.82 and Enum.Material.SmoothPlastic or r.Material
   p.CanQuery=ripe and body>=1 and r.Query or false
   p.CanCollide=false
  end
 end
 for index,b in pairs(state.Buds)do
  local fruit=progress[index]or progress[1]
  local show=state.Id~='StarfruitSeed'and alive and fruit>.012 and fruit<.94
  local z=math.max(.01,math.clamp((state.Def.BaseScale or 1)*(crop.PlantScale or 1)*(.10+.12*fruit),.10,.85)*scale)
  local c=b.Anchor*scale
  -- The bud centre stays at the socket, so new fruit never separates from its stem.
  b.Part.Size=V(z,z,z);b.Part.CFrame=state.Origin*CF(c);b.Part.Transparency=show and ease(.75,.94,fruit)or 1
  local a=b.Socket*scale;local d=c-a
  b.Stem.Transparency=show and d.Magnitude>.015 and 0 or 1
  if d.Magnitude>.015 then b.Stem.Size=V(math.max(.025,z*.15),d.Magnitude,z*.15);b.Stem.CFrame=state.Origin*CFrame.lookAt((a+c)/2,c)*CFrame.Angles(math.pi/2,0,0)end
 end
 state.Body=body;state.Fruit=fruit;state.Progress=progress;state.Readiness=readiness;state.Mutation=crop.Mutation
 state.Model:SetAttribute('VisualGrowth',body);state.Model:SetAttribute('VisualFruitGrowth',fruit)
 return body,fruit
end
return G
