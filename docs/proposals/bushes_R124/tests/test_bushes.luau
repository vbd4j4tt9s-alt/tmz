--!nocheck
-- R124 hide bushes under the Roblox mock: real HideBushes124 on the real Forest/Jungle bush geometry, then the real
-- HideBushClient (see-through for the hider, other players' names hidden inside). Run via run.sh.
local R=require('./roblox');local Fix=require('./bush_fixture');local B=require('./bundle')
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Mock gaps: CFrame object-space helpers and Rotation.
local CFm=getmetatable(CF(0,0,0));local oldIndex=CFm.__index
CFm.ToObjectSpace=function(a,b)return a:Inverse()*b end
CFm.PointToObjectSpace=function(a,v)return a:Inverse()*v end
CFm.__index=function(c,k)if k=='Rotation'then return setmetatable({Position=V3(0,0,0),R=c.R,__type='CFrame'},CFm)end;return oldIndex(c,k)end
local function fromFix(f)return setmetatable({Position=V3(f.Pos[1],f.Pos[2],f.Pos[3]),R={{f.R[1],f.R[2],f.R[3]},{f.R[4],f.R[5],f.R[6]},{f.R[7],f.R[8],f.R[9]}},__type='CFrame'},CFm)end
-- Services
local game=R.new('DataModel');local services={}
local function service(n)local s=services[n];if not s then s=R.new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
game.GetService=function(_,n)return service(n)end
local Tags=service('CollectionService');local tagged={};local added=R.signal();local removed=R.signal()
Tags.AddTag=function(_,i,t)tagged[t]=tagged[t]or{};table.insert(tagged[t],i);added:Fire(i)end
Tags.GetTagged=function(_,t)return table.clone(tagged[t]or{})end
Tags.GetInstanceAddedSignal=function()return added end;Tags.GetInstanceRemovedSignal=function()return removed end
local Run=service('RunService');Run.Heartbeat=R.signal()
local function env(scriptObj)return setmetatable({game=game,script=scriptObj,Enum=R.Enum,Vector3=R.Vector3,CFrame=R.CFrame,Instance=R.Instance,require=function(m)return m end},{__index=_G})end
local function load(name,obj)local fn=assert(loadstring(B[name],'='..name));setfenv(fn,env(obj));return fn()end
-- Map: Forest + Jungle bushes from the real place, plus a Desert 'Bush' that must stay untouched.
local map=R.new('Model');map.Name='ChestChaseMap'
local obby=R.new('Folder');obby.Name='Obby';obby.Parent=map
local biomes=R.new('Folder');biomes.Name='Biomes';biomes.Parent=obby
local folders={};local list={}
for _,f in ipairs(Fix)do
 local b=folders[f.Biome];if not b then b=R.new('Folder');b.Name=f.Biome;b.Parent=biomes;local g=R.new('Folder');g.Name='GeneratedScenery';g.Parent=b;folders[f.Biome]=b end
 local g=b.GeneratedScenery;local m=g:FindFirstChild(f.Model)
 if not m then m=R.new('Model');m.Name=f.Model;m.Parent=g end -- both 'Tall jungle tree' bushes share one model: tests the pairing
 local p=R.new('Part');p.Name=f.Name;p.Size=V3(f.Size[1],f.Size[2],f.Size[3]);p.CFrame=fromFix(f);p.CanCollide=false;p.Parent=m
 list[#list+1]={Part=p,Fix=f,Size=p.Size,CFrame=p.CFrame}
end
local desert=R.new('Folder');desert.Name='Biome_2_DESERT';desert.Parent=biomes
local dg=R.new('Folder');dg.Name='GeneratedScenery';dg.Parent=desert
local dbush=R.new('Part');dbush.Name='Bush';dbush.Size=V3(6,4,6);dbush.CFrame=CF(0,6,0);dbush.Parent=dg
-- 1) Server scaling
local H=load('HideBushes124',R.new('ModuleScript'))
local n=H.Apply(map)
check(n==8,'8 bushes enlarged (3 Forest + 5 Jungle): '..n)
check(dbush.Size==V3(6,4,6)and dbush:GetAttribute('HideBushId')==nil,'desert bush untouched')
local byId={}
for _,e in ipairs(list)do local id=e.Part:GetAttribute('HideBushId');check(id~=nil,'tagged: '..e.Fix.Model..'/'..e.Fix.Name);byId[id]=byId[id]or{};byId[id][e.Fix.Name]=e end
for id,pair in pairs(byId)do
 local body,top=pair.Bush,pair['Bush top']
 check(body and top,'bush '..id..' keeps its top')
 local oldBottom=(body.CFrame*CF(0,-body.Size.Y/2,0)).Position
 local base=body.Part.CFrame*CF(0,-body.Part.Size.Y/2,0)
 check((base.Position-oldBottom).Magnitude<1e-3,'bush '..id..' stays on the ground')
 local topY=base:PointToObjectSpace(top.Part.Position).Y+top.Part.Size.Y/2
 check(math.abs(topY-7.5)<.05,('bush %d is 7.5 studs tall (%.2f)'):format(id,topY))
 local w=math.min(body.Part.Size.X,body.Part.Size.Z);local sw=body.Part.Size.X/body.Size.X
 check(w>=9-1e-6 or math.abs(sw-1.7)<1e-6,('bush %d at least 9 wide or capped (%.2f)'):format(id,w))
 check(sw>=1.2-1e-6,'bush '..id..' grows at least 20% wide')
 -- an R6 player (2 wide, 5 tall, root 3 up) standing in the middle is inside the bush
 for _,dy in ipairs({.2,3,5.4})do
  local pt=base*V3(0,dy,0);local inside=false
  for _,p in ipairs({body.Part,top.Part})do local rel=p.CFrame:PointToObjectSpace(pt);local h=p.Size*.5;if math.abs(rel.X)<=h.X and math.abs(rel.Y)<=h.Y and math.abs(rel.Z)<=h.Z then inside=true end end
  check(inside,('bush %d covers a player at height %.1f'):format(id,dy))
 end
 for _,p in ipairs({body.Part,top.Part})do check(p.CanCollide==false and p.CanQuery==false and p.CanTouch==false,'bush '..id..' walk-through, no raycasts, no touch')end
 -- the top keeps its place relative to the body, scaled
 local relOld=body.CFrame:Inverse()*top.CFrame;local relNew=body.Part.CFrame:Inverse()*top.Part.CFrame
 check(math.abs(relNew.Position.X-relOld.Position.X*sw)<1e-3,'bush '..id..' top offset scales with the bush')
end
check(H.Apply(map)==0,'second Apply changes nothing')
-- 2) Client
local Players=service('Players')
local me=R.new('Player');me.Name='Me';me.Parent=Players;Players.LocalPlayer=me
local other=R.new('Player');other.Name='Other';other.Parent=Players
Players.GetPlayers=function()return {me,other}end
local function rig(owner,pos)
 local c=R.new('Model');c.Name=owner.Name;local r=R.new('Part');r.Name='HumanoidRootPart';r.CFrame=CF(pos.X,pos.Y,pos.Z);r.Parent=c
 local h=R.new('Humanoid');h.DisplayDistanceType=R.Enum.HumanoidDisplayDistanceType.Viewer;h.Parent=c;c.Parent=game;owner.Character=c;return r,h
end
local myRoot=rig(me,V3(0,0,-500));local otherRoot,otherHum=rig(other,V3(0,0,-500))
load('HideBushClient',R.new('LocalScript'))
local function tick()for _=1,3 do Run.Heartbeat:Fire(.06)end end
local one=byId[1];local base=one.Bush.Part.CFrame*CF(0,-one.Bush.Part.Size.Y/2,0)
myRoot.CFrame=CF((base*V3(0,3,0)).X,(base*V3(0,3,0)).Y,(base*V3(0,3,0)).Z);tick()
check(one.Bush.Part.LocalTransparencyModifier==.6 and one['Bush top'].Part.LocalTransparencyModifier==.6,'my bush turns see-through for me')
check((byId[2].Bush.Part.LocalTransparencyModifier or 0)==0,'other bushes stay solid')
myRoot.CFrame=CF(0,0,-500);tick()
check(one.Bush.Part.LocalTransparencyModifier==0,'solid again when I leave')
local p2=byId[2].Bush.Part.CFrame*CF(0,-byId[2].Bush.Part.Size.Y/2+3,0)
otherRoot.CFrame=p2;tick()
check(otherHum.DisplayDistanceType==R.Enum.HumanoidDisplayDistanceType.None,'another player hiding in a bush: name hidden')
otherRoot.CFrame=CF(0,0,-500);tick()
check(otherHum.DisplayDistanceType==R.Enum.HumanoidDisplayDistanceType.Viewer,'name back when they leave')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
