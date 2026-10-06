--!nocheck
-- R117 boots: tiered geometry + tiered effects + budgets + leaks. Runs the REAL RunnerBootArt, ShopProductArt,
-- RunnerTrailStyles, RunnerTrailEffects, RunnerBootFx, ClientFxBudget and the RunnerTrailClient LocalScript under the
-- shared Roblox mock (tools/tests/roblox.luau). Run with run.sh, which builds boot_bundle.luau.
-- 1 geometry per tier   2 effect data per tier   3 one wearer per tier through stand/sprint/jump/land
-- 4 crowd: culling, caps, budgets (high/mid/low/FastMode/graphics level/Reduced Motion)   5 unequip/respawn/leave/destroy
local R=require('./roblox');local B=require('./boot_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function section(name)print('-- '..name)end
math.randomseed(117)
-- Mock extensions ---------------------------------------------------------------------------------------------
local rawIsA=R.Inst.IsA
R.Inst.IsA=function(self,c)if self._class=='CornerWedgePart'and(c=='BasePart'or c=='PVInstance')then return true end;return rawIsA(self,c)end
local emitted={}
R.Inst.Emit=function(self,n)n=n or 16;emitted[self._props.Name]=(emitted[self._props.Name]or 0)+n end
R.Inst.Clear=function()end
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace')
function workspace.Raycast(_,origin,dir)if origin.Y>0 and origin.Y+dir.Y<=0 then return {Position=V3(origin.X,0,origin.Z),Normal=V3(0,1,0),Instance=workspace}end;return nil end
local camera=new('Camera');camera.Parent=workspace;workspace.CurrentCamera=camera
function camera.WorldToViewportPoint(self,p)local c=self.CFrame;local ahead=(p-c.Position):Dot(c.LookVector);return V3(0,0,ahead),ahead>0 end
local Run=service('RunService');Run.RenderStepped=R.signal();Run.Heartbeat=R.signal();function Run.IsClient()return true end
local UIS=service('UserInputService');UIS.TouchEnabled=false;UIS.KeyboardEnabled=true
local Gui=service('GuiService');Gui.ReducedMotionEnabled=false
local Players=service('Players');Players.PlayerRemoving=R.signal()
function Players.GetPlayers()local out={};for _,c in ipairs(Players:GetChildren())do if c:IsA('Player')then out[#out+1]=c end end;return out end
function Players.GetPlayerFromCharacter(_,ch)for _,p in ipairs(Players.GetPlayers())do if p.Character==ch then return p end end;return nil end
local RS=service('ReplicatedStorage')
local quality={Value=0}
local function UserSettings()return {GetService=function()return {SavedQualityLevel=quality}end}end
-- Module loader -----------------------------------------------------------------------------------------------
local modules,sources={},{}
local env
local function load(name,scriptInst)local fn=assert(loadstring(B[name],'='..name));setfenv(fn,setmetatable({script=scriptInst},{__index=env}));return fn()end
local function req(m)if modules[m]~=nil then return modules[m]end;local src=sources[m];if not src then error('require of unknown module '..tostring(m))end;modules[m]=load(src,m);return modules[m]end
for _,n in ipairs({'RunnerTrailRules','RunnerTrailStyles','RunnerTrailEffects','RunnerBootFx','ClientFxBudget','RunnerBootArt','RunnerTrailArt','ShopProductArt'})do
 local m=new('ModuleScript');m.Name=n;m.Parent=RS;sources[m]=n
end
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,Color3=R.Color3,ColorSequence=R.ColorSequence,
 ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,NumberSequenceKeypoint=R.NumberSequenceKeypoint,NumberRange=R.NumberRange,Enum=R.Enum,
 RaycastParams={new=function()return {}end},UserSettings=UserSettings,typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end,time=os.time},
 warn=function(...)print('WARN',...)end},{__index=_G})
local Styles=req(RS.RunnerTrailStyles);local Effects=req(RS.RunnerTrailEffects);local Boots=req(RS.RunnerBootArt);local Shop=req(RS.ShopProductArt)
local BIOMES={'Desert','Snow','Lava','Crystal','Storm'};local NAMES={'Sand','Frost','Lava','Crystal','Thunder'}
-- Rigs --------------------------------------------------------------------------------------------------------
local function rig(kind)
 local parts={}
 local function part(name,size,cf)local p=new('Part');p.Name=name;p.Size=size;p.CFrame=cf or CF(0,0,0);parts[name]=p;return p end
 if kind=='R6'then part('Left Leg',V3(1,2,1),CF(-.5,1,0));part('Right Leg',V3(1,2,1),CF(.5,1,0))
 else for i,s in ipairs({'Left','Right'})do local x=i==1 and -.5 or .5;part(s..'Foot',V3(1,.3,1),CF(x,.15,0));part(s..'LowerLeg',V3(1,1.1,1),CF(x,.8,0));part(s..'UpperLeg',V3(1,1.2,1),CF(x,1.8,0))end end
 return parts
end
-- 1. Geometry per tier ===============================================================================================
section('1 geometry')
local geo={}
for t,biome in ipairs(BIOMES)do
 for _,kind in ipairs({'R15','R6'})do
  local c=new('Model');for _,p in pairs(rig(kind))do p.Parent=c end
  local folder=new('Folder');folder.Parent=c
  local count=Boots.Create(c,folder,biome,R.Color3.fromRGB(200,200,200))
  check(count==2,NAMES[t]..' '..kind..' boots on both legs')
  local g={Parts=0,Neon=0,Names={},Materials={},Glass=0,Corner=0,Legs={}}
  for _,m in ipairs(folder:GetChildren())do
   local n=0
   for _,p in ipairs(m:GetChildren())do if p:IsA('BasePart')then
    n+=1;g.Names[p.Name]=(g.Names[p.Name]or 0)+1;g.Materials[p.Material.Name]=true
    if p.Material.Name=='Neon'then g.Neon+=1 end
    if p.Material.Name=='Glass'then g.Glass+=1 end
    if p._class=='CornerWedgePart'then g.Corner+=1 end
    local weld=p:FindFirstChildOfClass('WeldConstraint')
    if not(weld and weld.Part1==p and p.Massless==true and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p.CastShadow==false and p.Anchored==false)then
     check(false,NAMES[t]..' '..kind..' part '..p.Name..' welded, massless, no collision/query/touch/shadow')
    end
    -- Nothing strays from the leg: within 1.25 studs sideways/forward of the leg, between the ground and the knee.
    local pos=p.CFrame.Position;local legX=m.Name=='LeftRunnerBoot'and -.5 or .5
    if not(math.abs(pos.X-legX)<=1.25 and math.abs(pos.Z)<=1.25 and pos.Y>=-.25 and pos.Y<=1.8)then check(false,NAMES[t]..' '..kind..' part '..p.Name..' near the leg ('..tostring(pos)..')')end
   end end
   g.Legs[m.Name]=n
  end
  g.Parts=(g.Legs.LeftRunnerBoot or 0);g.Neon/=2;g.Glass/=2
  check(g.Legs.LeftRunnerBoot==g.Legs.RightRunnerBoot,NAMES[t]..' '..kind..' both legs have the same part count')
  geo[kind..t]=g
 end
end
local row={}
for t=1,5 do
 local g=geo['R15'..t];row[t]=string.format('%s %d parts/leg (neon %d, glass %d)',NAMES[t],g.Parts,g.Neon,g.Glass)
 check(g.Parts<=40,NAMES[t]..' at most 40 parts per leg')
 check(geo['R6'..t].Parts==g.Parts,NAMES[t]..' same part count on R6')
 if t>1 then
  check(g.Parts>geo['R15'..(t-1)].Parts,NAMES[t]..' has more parts than '..NAMES[t-1])
  check(geo['R6'..t].Parts>geo['R6'..(t-1)].Parts,NAMES[t]..' has more parts than '..NAMES[t-1]..' (R6)')
 end
end
print('  '..table.concat(row,' | '))
local want={22,26,29,35,38}
for t=1,5 do check(geo['R15'..t].Parts==want[t],NAMES[t]..' parts per leg = '..want[t]..' (documented)')end
-- Emissive accents grow with the tier: Sand none, Frost a little, Thunder the most.
check(geo.R151.Neon==0,'Sand has no glowing parts')
check(geo['R15'..2].Neon>0 and geo['R15'..2].Neon<geo['R15'..3].Neon,'Frost glows a little, less than Lava')
for t=3,4 do check(geo['R15'..5].Neon>geo['R15'..t].Neon,'Thunder has more glowing parts than '..NAMES[t])end
check(geo['R15'..4].Glass>geo['R15'..3].Glass and geo['R15'..4].Corner>=8,'Crystal: the most glass and faceted (CornerWedge) parts')
-- Tier emblems and the parts the effects hook into.
for t,name in ipairs({'Sun stone','Frost gem','Magma gem','Heel gem','Bolt emblem'})do check((geo['R15'..t].Names[name]or 0)>=2,NAMES[t]..' carries its '..name..' on both boots')end
for t=1,5 do check(geo['R15'..t].Names.Outsole==2 and geo['R15'..t].Names['Boot shaft']==2,NAMES[t]..' has Outsole and Boot shaft on both boots')end
check(geo.R154.Names['Heel gem']==2 and geo.R154.Names['Toe prism']==2 and geo.R154.Names['Prism facet']==8 and geo.R154.Names['Crown prism']==2,'Crystal heel gem, toe prism, 4 rainbow facets, crown prism per boot')
check(geo.R155.Names['Volt coil']==6 and geo.R155.Names['Tesla spine']==2 and geo.R155.Names['Prong tip']==4 and geo.R155.Names['Thruster glow']==2,'Thunder 3 coils, spine, 2 prongs, thruster per boot')
check(geo.R153.Names['Magma sole seam']==2 and geo.R153.Names['Heel horn']==4 and geo.R153.Names['Heel spur']==2,'Lava sole seam, 2 horns on each outer side, spur')
check(geo.R152.Names['Snowflake']==6 and geo.R152.Names['Frost gem']==2,'Frost snowflake (3 bars) on each outer ankle only')
-- Shop preview builds the same geometry through ShopProductArt.Build (API unchanged).
local shopParts={}
for t,biome in ipairs(BIOMES)do
 local before=#R.created
 local product={Id='Boot'..t,Name=NAMES[t]..' Boots',Type='Accessory',Biome=biome,Color={R=200,G=200,B=200}}
 local specs=Shop.Specs(product,'Forest');local model=Shop.Build(product,'Forest')
 local n,glassT,corner=0,0,0
 for _,p in ipairs(model:GetChildren())do n+=1;if (p.Transparency or 0)>0 then glassT+=1 end;if p._class=='CornerWedgePart'then corner+=1 end;check(p.Anchored==true,'shop part anchored')end
 local expect=#Boots.Specs(R.Vector3.new(1,.7,1.8),false,biome)+#Boots.ShinSpecs(R.Vector3.new(1.05,1.45,1.05),false,biome)
 check(n==#specs and n==2*expect,NAMES[t]..' shop preview builds every spec on both boots ('..n..')')
 shopParts[t]=n
 if t>1 then check(n>shopParts[t-1],NAMES[t]..' shop preview richer than '..NAMES[t-1])end
 if t==4 then check(glassT>0 and corner>0,'Crystal shop preview keeps glass transparency and CornerWedges')end
end
print('  shop preview parts: '..table.concat(shopParts,' / '))
-- No uploaded assets anywhere in the boot modules.
for _,name in ipairs({'RunnerBootArt','RunnerTrailStyles','RunnerTrailEffects','RunnerBootFx','RunnerTrailClient'})do
 local src=B[name];check(not src:find('rbxassetid')and not src:find('http'),name..' uses no uploaded asset ids')
 for tex in src:gmatch("'(rbxasset://[^']+)'")do check(tex:sub(1,30)=='rbxasset://textures/particles/',name..' built-in particle texture only ('..tex..')')end
end
-- 2. Effect data per tier ============================================================================================
section('2 effect data')
local function specs(theme)
 local n=#(theme.Burst or{})+#(theme.Land or{})+#(theme.Glint or{})+#((theme.Sprint or{}).Emitters or{})+#((theme.Idle or{}).Emitters or{})
 return n
end
local function dataKinds(theme)
 local k={Print=theme.Print~=nil,Burst=theme.Burst~=nil,Land=theme.Land~=nil,Idle=theme.Idle~=nil,Sprint=theme.Sprint~=nil,Start=theme.Start==true,Ring=theme.Ring~=nil,
  Glint=theme.Glint~=nil,IdlePatches=theme.Idle.Patches~=nil,IdleShards=(theme.Idle.Shards or 0)>0,Strike=theme.Strike~=nil,Coils=theme.Coils~=nil,BootArc=theme.BootArc~=nil,
  GroundArc=theme.Arc~=nil,Dome=theme.Idle.Dome~=nil}
 local list={};for name,on in pairs(k)do if on then list[name]=true end end;return list
end
local prevKinds,prevSpecs=nil,0
for t,biome in ipairs(BIOMES)do
 local theme=Styles.Theme(biome);check(theme and theme.Tier==t,NAMES[t]..' theme tier '..t)
 local kinds=dataKinds(theme);local count=0;for _ in pairs(kinds)do count+=1 end
 local n=specs(theme)
 print(string.format('  %s: %d effect kinds, %d emitter specs',NAMES[t],count,n))
 if prevKinds then
  local pc=0;for name in pairs(prevKinds)do pc+=1;check(kinds[name],NAMES[t]..' keeps '..NAMES[t-1]..' effect kind '..name)end
  check(count>pc,NAMES[t]..' has more effect kinds than '..NAMES[t-1])
  check(n>prevSpecs,NAMES[t]..' has more emitter specs than '..NAMES[t-1])
 end
 prevKinds,prevSpecs=kinds,n
 for _,list in ipairs({theme.Burst,theme.Land,theme.Glint,(theme.Sprint or{}).Emitters,theme.Idle.Emitters})do for _,spec in ipairs(list or{})do
  check(type(spec.Texture)=='string'and spec.Texture:sub(1,30)=='rbxasset://textures/particles/',NAMES[t]..' '..spec.Name..' built-in texture')
 end end
end
-- Budgets.
local b3,b2,b1=Styles.Budget(3,false),Styles.Budget(2,false),Styles.Budget(1,false);local br=Styles.Budget(3,true)
check(b3.Attach>b2.Attach and b2.Attach>b1.Attach and b1.Attach==0,'other runners with boot emitters: high > mid > low (0)')
check(b3.Moments>b2.Moments and b2.Moments>b1.Moments and b1.Moments==1,'moment pool: high > mid > low (1, local only)')
check(b3.Light and not b2.Light and not b1.Light,'strike light only on high')
check(br.Moments==0 and br.Arcs==0 and br.Light==false and br.Scale==.5,'Reduced Motion: no rings/bolts/arcs/light, half particles')
check(Styles.Budget(3,false,2).Tier==1 and Styles.Budget(3,false,5).Tier==2,'graphics level 1-3 -> low, 4-6 -> mid')
-- 3. One wearer per tier, through stand / sprint off / run / jump / land ==============================================
section('3 per-tier runtime')
local fx;local momentLog={};local bootArcs=0;local groundArcs=0
local rawNew=Effects.new
Effects.new=function(...)
 fx=rawNew(...)
 fx.Moment=function(self,r,kind,position,now)
  local n=Effects.Moment(self,r,kind,position,now)
  local entry={Kind=kind,Local=r.Local,Name=r.Character.Name,Particles=n,Ring=false,Strike=false,Light=false}
  for _,m in ipairs(self.Moments)do if m.Until and m.Born==now and m.Center==position then
   entry.Ring=m.Ring[1]~=nil and m.Ring[1].Transparency<1;entry.Strike=m.Strike~=nil;entry.Light=m.Light~=nil and m.Light.Enabled==true
  end end
  if n>0 or entry.Ring or entry.Strike then table.insert(momentLog,entry)end
  return n
 end
 fx.BootArc=function(self,...)local a=Effects.BootArc(self,...);if a then bootArcs+=1 end;return a end
 fx.Arc=function(self,...)local a=Effects.Arc(self,...);if a then groundArcs+=1 end;return a end
 return fx
end
local runners={}
local function dress(runner,biome)
 local old=runner.Character:FindFirstChild('ChestChaseCosmetics');if old then old:Destroy()end
 local folder=new('Folder');folder.Name='ChestChaseCosmetics';folder:SetAttribute('CosmeticVersion',91)
 if biome then local count=Boots.Create(runner.Character,folder,biome,R.Color3.fromRGB(200,200,200));folder:SetAttribute('BootCount',count);folder:SetAttribute('BootBiome',biome)end
 folder.Parent=runner.Character;runner.Folder=folder
end
local function place(runner)
 local p=runner.Pos;runner.Root.CFrame=CF(p.X,p.Y+3,p.Z);runner.Root.AssemblyLinearVelocity=runner.Vel
 local phase=math.sin(R.clock*9)*.4
 for i,s in ipairs({'Left','Right'})do
  local x=i==1 and -.5 or .5;local dz=i==1 and phase or -phase
  runner.Parts[s..'Foot'].CFrame=CF(p.X+x,p.Y+.15,p.Z+dz);runner.Parts[s..'LowerLeg'].CFrame=CF(p.X+x,p.Y+.8,p.Z+dz*.5);runner.Parts[s..'UpperLeg'].CFrame=CF(p.X+x,p.Y+1.8,p.Z)
 end
end
local function spawnCharacter(runner,biome)
 local c=new('Model');c.Name=runner.Player.Name;runner.Character=c
 local root=new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Parent=c;runner.Root=root
 local h=new('Humanoid');h.Health=100;h.FloorMaterial=R.Enum.Material.Plastic;h.Sit=false;h.PlatformStand=false;h.Parent=c;runner.Humanoid=h
 runner.Parts=rig('R15');for _,p in pairs(runner.Parts)do p.Parent=c end
 place(runner);c.Parent=workspace;runner.Player.Character=c;dress(runner,biome)
end
local function addRunner(name,biome,pos,isLocal)
 local player=new('Player');player.Name=name;player.Parent=Players;if isLocal then Players.LocalPlayer=player end
 local runner={Player=player,Pos=pos,Vel=V3(0,0,0),Name=name};spawnCharacter(runner,biome);runners[name]=runner;return runner
end
local function removeRunner(runner)runner.Character:Destroy();runner.Player.Parent=nil;Players.PlayerRemoving:Fire(runner.Player);runners[runner.Name]=nil end
local me=addRunner('Me','Desert',V3(0,0,0),true)
local clientScript=new('LocalScript');clientScript.Name='RunnerTrailClient'
load('RunnerTrailClient',clientScript)
check(fx~=nil,'client created the effects object')
local function followCamera()local p=me.Pos;camera.CFrame=R.CFrame.lookAt(p+V3(0,12,20),p+V3(0,2,-10))end
local peakSpent,peakParts,peakMoments,peakAttachedOthers=0,0,0,0
local effectNames={['Boot idle patch']=true,['Fading boot mark']=true,['Boot idle aura']=true,['Boot idle shard']=true,['Boot idle dome']=true,['Boot static arc']=true,
 ['Ground ribbon anchor']=true,['Boot step bursts']=true,['Boot landing ring']=true,['Boot lightning']=true,['Boot strike light']=true}
local function aliveEffectParts()local n=0;for _,o in ipairs(R.created)do if effectNames[o._props.Name]and not o._destroyed then n+=1 end end;return n end
local function liveMoments()local n=0;for _,m in ipairs(fx.Moments)do if m.Until then n+=1 end end;return n end
local watch=nil -- per-tick observer
local function run(seconds,dt)
 dt=dt or 1/60
 for _=1,math.floor(seconds/dt+.5)do
  R.advance(dt)
  for _,r in pairs(runners)do if r.Character and r.Character.Parent then r.Pos=r.Pos+r.Vel*dt;place(r)end end
  followCamera();Run.RenderStepped:Fire(dt);Run.Heartbeat:Fire(dt)
  peakSpent=math.max(peakSpent,fx.Spent);peakMoments=math.max(peakMoments,liveMoments());peakAttachedOthers=math.max(peakAttachedOthers,fx.Attached)
  if watch then watch()end
 end
 peakParts=math.max(peakParts,aliveEffectParts())
end
local function recordOf(runner)for r in pairs(fx.Records)do if r.Character==runner.Character then return r end end;return nil end
local function jump(runner,air)
 runner.Humanoid.FloorMaterial=R.Enum.Material.Air;runner.Pos=runner.Pos+V3(0,3,0);run(air or .5)
 runner.Pos=V3(runner.Pos.X,0,runner.Pos.Z);runner.Humanoid.FloorMaterial=R.Enum.Material.Plastic
end
local observed={};local emitterNames={}
for t,biome in ipairs(BIOMES)do
 dress(me,biome);me.Vel=V3(0,0,0);run(.3)
 local theme=Styles.Theme(biome);local rm=recordOf(me)
 check(rm and rm.ThemeName==biome,NAMES[t]..' bound')
 table.clear(emitted);table.clear(momentLog);bootArcs=0;groundArcs=0
 local k={}
 -- a: stand still -> idle aura.
 run(2.2)
 local rig1=rm.Idle
 if rig1 then
  k.Idle=false;for _,e in ipairs(rig1.Emitters)do if e.Enabled and e.Rate>0 then k.Idle=true end end
  for _,s in ipairs(rig1.Shards)do if s.Transparency<1 then k.IdleShards=true end end
  for _,s in ipairs(rig1.Patches)do if s.Transparency<1 then k.IdlePatches=true end end
  if rig1.Dome and rig1.Dome.Transparency<1 then k.Dome=true end
 end
 -- b: sprint off from standing at 60 studs/s.
 local coilsChanged=false
 watch=function()
  local a=rm.Attach;if not a then return end
  for _,x in ipairs(a.Sprint)do if x.Emitter.Enabled and x.Emitter.Rate>0 then k.Sprint=true end end
  for _,x in ipairs(a.Glint)do if x.Emitter.Enabled and x.Emitter.Rate>0 then k.Glint=true end end
  for _,c in ipairs(a.Coils)do if c.Part.Color~=c.Color then coilsChanged=true end end
 end
 me.Vel=V3(0,0,-60);run(2)
 for _,e in ipairs(momentLog)do if e.Kind=='Start'then k.Start=true end end
 -- c: jump and land while running.
 jump(me,.5);run(.6);watch=nil
 me.Vel=V3(0,0,0);run(.4)
 for _,e in ipairs(momentLog)do
  if e.Kind=='Land'then k.Land=true end
  if e.Ring then k.Ring=true end;if e.Strike then k.Strike=true end;if e.Light then k.Light=true end
 end
 k.Coils=coilsChanged or nil
 k.BootArc=bootArcs>0 or nil;k.GroundArc=(groundArcs-bootArcs)>0 or nil
 local nPrints=0;for _,m in ipairs(fx.Rings.Local.Marks)do if m.Live then nPrints+=1 end end
 k.Print=nPrints>0 or nil
 for _,spec in ipairs(theme.Burst)do if (emitted[spec.Name]or 0)>0 then k.Burst=true end end
 local names=0;for name,n in pairs(emitted)do if n>0 then names+=1 end end
 for _,list in ipairs({rm.Attach and rm.Attach.Sprint or{},rm.Attach and rm.Attach.Glint or{}})do for _,x in ipairs(list)do names+=1 end end
 local set={};local count=0;for name,on in pairs(k)do if on then set[name]=true;count+=1 end end
 local list={};for name in pairs(set)do table.insert(list,name)end;table.sort(list)
 print(string.format('  %s: %d effects seen: %s',NAMES[t],count,table.concat(list,', ')))
 observed[t]=set;emitterNames[t]=names
 if t>1 then
  local pc=0;for name in pairs(observed[t-1])do pc+=1;check(set[name],NAMES[t]..' shows '..NAMES[t-1]..' effect '..name)end
  check(count>pc,NAMES[t]..' shows more effects than '..NAMES[t-1]..' ('..count..' vs '..pc..')')
 end
 -- Every effect the data promises actually shows (Light only on high, which this is).
 for name in pairs(dataKinds(theme))do check(set[name],NAMES[t]..' shows its '..name..' effect')end
end
check(observed[5].Strike and observed[5].Light and observed[5].Coils and observed[5].BootArc and observed[5].Dome,'Thunder: lightning strike + light, coil pulse, arcs between boots, field dome')
check(observed[4].IdleShards and observed[4].Ring and not observed[4].Strike,'Crystal: prism orbit + rainbow ring, no lightning')
-- Crystal prints cycle through rainbow centres.
dress(me,'Crystal');run(.3);me.Vel=V3(0,0,-20);run(2);me.Vel=V3(0,0,0)
local colours={};for _,m in ipairs(fx.Rings.Local.Marks)do if m.Live and m.Print.Kind=='Crystal'then colours[tostring(m.Parts[3].Color.R)..tostring(m.Parts[3].Color.G)]=true end end
local nc=0;for _ in pairs(colours)do nc+=1 end;check(nc>=3,'Crystal print centres cycle rainbow colours ('..nc..')')
-- Coil pulse: colours change only in steps (bounded writes) and are restored on detach.
dress(me,'Storm');run(.3)
local rm=recordOf(me);local writes=0
local coilParts={};for _,c in ipairs(rm.Attach and rm.Attach.Coils or{})do coilParts[c.Part]=c.Color end
local rawNewIndex=R.instMeta.__newindex
R.instMeta.__newindex=function(o,key,v)if key=='Color'and coilParts[o]then writes+=1 end;return rawNewIndex(o,key,v)end
me.Vel=V3(0,0,-60);run(2)
R.instMeta.__newindex=rawNewIndex
check(rm.Attach and#rm.Attach.Coils==6,'Thunder: 6 coils found (3 per boot) ('..tostring(rm.Attach and#rm.Attach.Coils)..')')
check(writes>0 and writes<=6*40,'coil pulse writes bounded ('..writes..' in 2 s; <=40 per coil)')
-- 4. Crowd: culling, caps and budgets ==================================================================================
section('4 crowd and budgets')
me.Vel=V3(0,0,0);run(1)
local crowd={}
local base=me.Pos
for i=1,4 do crowd[i]=addRunner('Near'..i,'Storm',base+V3(-6+i*2.5,0,-12))end
local behind=addRunner('Behind','Crystal',base+V3(4,0,32)) -- near but behind the camera: off screen
local mid=addRunner('MidLava','Lava',base+V3(0,0,-75))
local far=addRunner('FarStorm','Storm',base+V3(-4,0,-110))
run(1)
local recBehind,recMid,recFar=recordOf(behind),recordOf(mid),recordOf(far)
check(recordOf(crowd[1]).Detail==3 and recBehind.Detail==2 and recMid.Detail==2 and recFar.Detail==1,'detail: near on-screen 3, off-screen 2, mid 2, far 1 ('..recBehind.Detail..','..recMid.Detail..','..recFar.Detail..')')
-- Everyone sprints off, runs, then jumps together.
table.clear(momentLog);peakAttachedOthers=0;peakMoments=0;peakSpent=0
for _,r in pairs(runners)do r.Vel=V3(0,0,-40)end
run(1.5)
for _,r in pairs(runners)do r.Humanoid.FloorMaterial=R.Enum.Material.Air;r.Pos=r.Pos+V3(0,3,0)end
run(.5)
for _,r in pairs(runners)do r.Pos=V3(r.Pos.X,0,r.Pos.Z);r.Humanoid.FloorMaterial=R.Enum.Material.Plastic end
run(.6)
local b=fx.Budget
print(string.format('  high: attached others peak %d (cap %d), moments peak %d (cap %d), particles/s peak %d (cap %d)',peakAttachedOthers,b.Attach,peakMoments,b.Moments,peakSpent,b.Particles))
check(peakAttachedOthers<=b.Attach,'high: boot emitters on at most '..b.Attach..' other runners')
check(peakAttachedOthers==b.Attach,'high: the cap is used by near on-screen runners')
check(recordOf(me).Attach~=nil,'local wearer always has boot emitters')
local function attachOf(x)local r=recordOf(x);return r and r.Attach end
check(recordOf(behind)and recordOf(mid)and recordOf(far),'off-screen, mid and far runners still handled')
check(attachOf(behind)==nil and attachOf(mid)==nil and attachOf(far)==nil,'no boot emitters on off-screen, mid or far runners')
check(peakMoments<=b.Moments,'high: live moments within the pool ('..b.Moments..')')
check(peakSpent<=b.Particles,'high: burst particles within the per-second cap')
local byName={};for _,e in ipairs(momentLog)do byName[e.Name]=byName[e.Name]or{};table.insert(byName[e.Name],e)end
check(byName.Me and byName.Me[#byName.Me].Strike and byName.Me[#byName.Me].Light,'high: local landing strikes with a light')
local othersStrike=false;for i=1,4 do for _,e in ipairs(byName['Near'..i]or{})do if e.Strike then othersStrike=true end end end
check(othersStrike,'high: near on-screen runners get lightning strikes too')
check(byName.Behind==nil and byName.MidLava==nil and byName.FarStorm==nil,'no moments for off-screen, mid or far runners')
-- Off-screen grace: a runner with boot emitters that leaves the screen loses them after Styles.Grace.
local near1=recordOf(crowd[1]);local hadAttach=near1.Attach;local emittersBefore=hadAttach and hadAttach.Sprint[1].Emitter
for _,r in pairs(runners)do r.Vel=V3(0,0,0)end
crowd[1].Pos=me.Pos+V3(0,0,34);run(.8)
check(near1.Attach~=nil,'grace: boot emitters kept for a moment after leaving the screen')
run(1.4)
check(near1.Attach==nil and emittersBefore and emittersBefore._destroyed==true,'grace: boot emitters removed after '..Styles.Grace..' s off screen')
crowd[1].Pos=me.Pos+V3(-3.5,0,-12);run(.6)
-- Mid budget via the graphics level.
quality.Value=5;run(.5)
check(fx.Budget.Tier==2 and fx.Attached<=fx.Budget.Attach,'graphics level 5: mid budget, boot emitters on <= '..fx.Budget.Attach..' other runner ('..fx.Attached..')')
table.clear(momentLog);peakMoments=0;peakAttachedOthers=fx.Attached
jump(me,.5);for i=1,4 do crowd[i].Humanoid.FloorMaterial=R.Enum.Material.Air end;run(.4);for i=1,4 do crowd[i].Humanoid.FloorMaterial=R.Enum.Material.Plastic end;run(.6)
local anyLight=false;for _,e in ipairs(momentLog)do if e.Light then anyLight=true end end
check(not anyLight,'mid: strikes without the light')
check(peakMoments<=fx.Budget.Moments and peakAttachedOthers<=fx.Budget.Attach,'mid: moments and boot emitters within caps')
quality.Value=0
-- Low budget via FastMode.
me.Player:SetAttribute('FastMode',true);run(.5)
check(fx.Budget.Tier==1 and fx.Attached==0,'FastMode: low budget, no boot emitters on other runners')
check(recordOf(me).Attach~=nil,'FastMode: the local wearer keeps boot emitters')
table.clear(momentLog);peakMoments=0
for _,r in pairs(runners)do r.Humanoid.FloorMaterial=R.Enum.Material.Air end;run(.4)
for _,r in pairs(runners)do r.Humanoid.FloorMaterial=R.Enum.Material.Plastic end;run(.6)
local localRing,otherRing,lowLight=false,false,false
for _,e in ipairs(momentLog)do if e.Local then localRing=localRing or e.Strike else otherRing=otherRing or e.Ring or e.Strike end;lowLight=lowLight or e.Light end
check(localRing and not otherRing and not lowLight,'FastMode: only the local wearer gets a ring/strike, no light')
check(peakMoments<=1,'FastMode: one moment at a time')
local bound=0;for _ in pairs(fx.Records)do bound+=1 end
check(bound<=4,'FastMode: at most 4 runners handled')
me.Player:SetAttribute('FastMode',false);run(.5)
-- Reduced Motion.
Gui.ReducedMotionEnabled=true;run(.5)
table.clear(momentLog);bootArcs=0;groundArcs=0
me.Vel=V3(0,0,-60);run(1);jump(me,.5);run(.6)
local rm2=recordOf(me);local restored=true
for _,c in ipairs(rm2.Attach and rm2.Attach.Coils or{})do if c.Part.Color~=c.Color then restored=false end end
check(restored,'Reduced Motion: coils at their base colour (no pulse)')
local rmMoment=false;for _,e in ipairs(momentLog)do rmMoment=rmMoment or e.Ring or e.Strike or e.Light end
check(#momentLog>0 and not rmMoment,'Reduced Motion: landing particles only, no ring/bolt/light')
check(bootArcs==0 and groundArcs==0,'Reduced Motion: no arcs')
local sprintRate=rm2.Attach and rm2.Attach.Sprint[1].Emitter.Rate
check(sprintRate and math.abs(sprintRate-Styles.Theme('Storm').Sprint.Emitters[1].Rate*.5)<.3,'Reduced Motion: boot emitters at half rate')
me.Vel=V3(0,0,0);run(2.2)
local dome=rm2.Idle and rm2.Idle.Dome;local size1=dome and dome.Size.X;run(.3)
check(dome and dome.Size.X==size1,'Reduced Motion: the field dome does not breathe')
Gui.ReducedMotionEnabled=false;run(.5)
-- Bound on live effect parts across everything above.
local hb=Styles.Budget(3,false)
local maxParts=3*(hb.LocalMarks+hb.OtherMarks)+3*hb.Arcs+12*(hb.Idle+1)+(8+9+1)*hb.Moments+2*hb.Characters+1
print(string.format('  peak live effect parts %d (bound %d)',peakParts,maxParts))
check(peakParts<=maxParts,'peak effect parts within the pool bound')
-- 5. Unequip / respawn / leave / destroy ==================================================================================
section('5 leaks')
local function liveEmitters()local n=0;for _,o in ipairs(R.created)do if o._class=='ParticleEmitter'and not o._destroyed and o._parent and o._parent.Name~='Boot idle aura'and o._parent.Name~='Boot step burst'then n+=1 end end;return n end
me.Vel=V3(0,0,-60);run(.8)
local mine=recordOf(me);local myEmitters={}
for _,list in ipairs({mine.Attach.Sprint,mine.Attach.Glint})do for _,x in ipairs(list)do table.insert(myEmitters,x.Emitter)end end
dress(me,nil);run(.4)
local allGone=true;for _,e in ipairs(myEmitters)do if not e._destroyed then allGone=false end end
check(allGone and mine.Attach==nil,'unequip: boot emitters destroyed')
local mine2=recordOf(me);check(mine2 and mine2.Theme==nil and mine2.Attach==nil,'unequip: no boot look, no emitters')
table.clear(momentLog);jump(me,.5);run(.4);check(#momentLog==0,'unequip: no landing moments without boots')
local oldChar=me.Character;oldChar:Destroy();spawnCharacter(me,'Storm');me.Vel=V3(0,0,-60);run(.8)
local mine3=recordOf(me);check(mine3 and mine3.Character==me.Character and mine3.Attach~=nil,'respawn: boot emitters on the new boots')
local onNewBoots=true;for _,x in ipairs(mine3.Attach.Sprint)do if not x.Emitter._parent:IsDescendantOf(me.Character)then onNewBoots=false end end
check(onNewBoots,'respawn: emitters live inside the new character')
local leaver=crowd[2];local lrec=recordOf(leaver);local lAttach=lrec and lrec.Attach;local attachedBefore=fx.Attached
local lEmitters={};if lAttach then for _,x in ipairs(lAttach.Sprint)do table.insert(lEmitters,x.Emitter)end end
removeRunner(leaver)
local lGone=true;for _,e in ipairs(lEmitters)do if not e._destroyed then lGone=false end end
check(not fx.Records[lrec]and lGone,'leave: record and boot emitters released at once')
check(not lAttach or fx.Attached==attachedBefore-1,'leave: attached count drops')
-- A strike in flight when the script is destroyed.
jump(me,.5);run(.1)
check(liveMoments()>0,'a moment is live before destroy')
local coilBase={};for _,c in ipairs(mine3.Attach and mine3.Attach.Coils or{})do coilBase[c.Part]=c.Color end
local hbBefore=0;for _,c in ipairs(Run.RenderStepped._c)do if c.Connected then hbBefore+=1 end end -- (R153: the trail client steps in RenderStepped)
clientScript:Destroy()
local hbAfter=0;for _,c in ipairs(Run.RenderStepped._c)do if c.Connected then hbAfter+=1 end end
local removalLive=0;for _,c in ipairs(Players.PlayerRemoving._c)do if c.Connected then removalLive+=1 end end
check(hbBefore==1 and hbAfter==0 and removalLive==0,'destroy: connections closed')
check(aliveEffectParts()==0,'destroy: no effect parts left ('..aliveEffectParts()..')')
check(liveEmitters()==0,'destroy: no boot emitters left in any character ('..liveEmitters()..')')
local coilsBack=true;for p,c in pairs(coilBase)do if p.Color~=c then coilsBack=false end end
check(coilsBack,'destroy: coil colours restored')
local lights=0;for _,o in ipairs(R.created)do if o._class=='PointLight'and not o._destroyed then lights+=1 end end
check(lights==0,'destroy: no strike lights left')
check(workspace:FindFirstChild('RunnerGroundEffects')==nil,'destroy: effects folder removed')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('R117 boot test failed')end
