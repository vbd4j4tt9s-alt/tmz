--!nocheck
-- R117 copy of the R111 suite. Three checks changed with the R117 design: parts per leg (was <=22, now each tier's
-- R117 count, at most 40), the crystal idle orbit (was 3 shards, now 5) and the live-part bound (idle rigs up to 12
-- parts, was 7). Run with run.sh (bundle name boot_bundle).
-- R111 boot effects: runs the REAL RunnerTrailClient + RunnerTrailEffects + RunnerTrailStyles + ClientFxBudget
-- (and RunnerBootArt.Create for the rigs) under the Roblox mock through walk -> stop -> idle -> walk -> 500 st/s ->
-- crowd -> low budget -> reduced motion -> unequip -> respawn -> leave -> script destroyed.
local R=require('./roblox');local B=require('./boot_bundle')
-- The shared mock predates CornerWedgePart: count it as a BasePart.
local rawIsA=R.Inst.IsA
R.Inst.IsA=function(self,c)if self._class=='CornerWedgePart'and(c=='BasePart'or c=='PVInstance')then return true end;return rawIsA(self,c)end
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
math.randomseed(7)
-- Mock extensions ---------------------------------------------------------------------------------------------
local emitted={}
R.Inst.Emit=function(self,n)n=n or 16;self._emitted=(self._emitted or 0)+n;emitted[self._props.Name]=(emitted[self._props.Name]or 0)+n end
R.Inst.Clear=function(self)self._cleared=(self._cleared or 0)+1 end
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace')
local rays=0
function workspace.Raycast(_,origin,dir)rays+=1;if origin.Y>0 and origin.Y+dir.Y<=0 then return {Position=V3(origin.X,0,origin.Z),Normal=V3(0,1,0),Instance=workspace}end;return nil end
local camera=new('Camera');camera.Parent=workspace;workspace.CurrentCamera=camera
function camera.WorldToViewportPoint(self,p)local c=self.CFrame;local rel=p-c.Position;local ahead=rel:Dot(c.LookVector);return V3(0,0,ahead),ahead>0 end
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
local function load(name,scriptInst)
 local fn=assert(loadstring(B[name],'='..name))
 setfenv(fn,setmetatable({script=scriptInst},{__index=env}));return fn()
end
local function req(m)
 if modules[m]~=nil then return modules[m]end
 local src=sources[m];if not src then error('require of unknown module '..tostring(m))end
 modules[m]=load(src,m);return modules[m]
end
for _,n in ipairs({'RunnerTrailRules','RunnerTrailStyles','RunnerTrailEffects','RunnerBootFx','ClientFxBudget','RunnerBootArt','RunnerTrailArt','ShopProductArt'})do
 local m=new('ModuleScript');m.Name=n;m.Parent=RS;sources[m]=n
end
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,Color3=R.Color3,ColorSequence=R.ColorSequence,
 ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,NumberSequenceKeypoint=R.NumberSequenceKeypoint,NumberRange=R.NumberRange,Enum=R.Enum,
 RaycastParams={new=function()return {}end},UserSettings=UserSettings,typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end,time=os.time},
 warn=function(...)print('WARN',...)end},{__index=_G})
local Styles=req(RS.RunnerTrailStyles);local Effects=req(RS.RunnerTrailEffects);local Boots=req(RS.RunnerBootArt)
-- Instrument the effects object the client creates.
local fx;local stamps={Local=0,Others=0};local stampLog={};local bursts=0;local arcs=0
local rawNew=Effects.new
Effects.new=function(...)
 fx=rawNew(...)
 fx.Stamp=function(self,frame,theme,scale,now,ring,speed,mirror)
  stamps[ring]+=1;table.insert(stampLog,{Ring=ring,At=now,Pos=frame.Position,Kind=theme.Print.Kind})
  return Effects.Stamp(self,frame,theme,scale,now,ring,speed,mirror)
 end
 fx.Burst=function(self,...)local n=Effects.Burst(self,...);bursts+=n;return n end
 fx.Arc=function(self,...)local a=Effects.Arc(self,...);if a then arcs+=1 end;return a end
 return fx
end
-- Characters -------------------------------------------------------------------------------------------------
local runners={}
local function rig(kind)
 local parts={}
 local function part(name,size)local p=new('Part');p.Name=name;p.Size=size;parts[name]=p;return p end
 if kind=='R6'then part('Left Leg',V3(1,2,1));part('Right Leg',V3(1,2,1))
 else for _,s in ipairs({'Left','Right'})do part(s..'Foot',V3(1,.3,1));part(s..'LowerLeg',V3(1,1.1,1));part(s..'UpperLeg',V3(1,1.2,1))end end
 return parts
end
local function dress(runner,biome)
 local old=runner.Character:FindFirstChild('ChestChaseCosmetics');if old then old:Destroy()end
 local folder=new('Folder');folder.Name='ChestChaseCosmetics';folder:SetAttribute('CosmeticVersion',91)
 if biome then
  local count=Boots.Create(runner.Character,folder,biome,R.Color3.fromRGB(200,200,200))
  folder:SetAttribute('BootCount',count);folder:SetAttribute('BootBiome',biome)
 end
 folder.Parent=runner.Character;runner.Folder=folder
end
local function place(runner)
 local p=runner.Pos;local rootCF=CF(p.X,p.Y+3,p.Z)
 runner.Root.CFrame=rootCF;runner.Root.AssemblyLinearVelocity=runner.Vel
 local kind=runner.Kind;local phase=math.sin(R.clock*9)*.4
 for i,s in ipairs({'Left','Right'})do
  local x=i==1 and -.5 or .5;local dz=(i==1 and phase or -phase)
  if kind=='R6'then runner.Parts[s..' Leg'].CFrame=CF(p.X+x,p.Y+1,p.Z+dz)
  else
   runner.Parts[s..'Foot'].CFrame=CF(p.X+x,p.Y+.15,p.Z+dz)
   runner.Parts[s..'LowerLeg'].CFrame=CF(p.X+x,p.Y+.8,p.Z+dz*.5)
   runner.Parts[s..'UpperLeg'].CFrame=CF(p.X+x,p.Y+1.8,p.Z)
  end
 end
end
local function spawnCharacter(runner,biome)
 local c=new('Model');c.Name=runner.Player.Name;runner.Character=c
 local root=new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Parent=c;runner.Root=root
 local h=new('Humanoid');h.Health=100;h.FloorMaterial=R.Enum.Material.Plastic;h.Sit=false;h.PlatformStand=false;h.Parent=c;runner.Humanoid=h
 runner.Parts=rig(runner.Kind);for _,p in pairs(runner.Parts)do p.Parent=c end
 place(runner);c.Parent=workspace;runner.Player.Character=c
 dress(runner,biome)
end
local function addRunner(name,kind,biome,pos,isLocal)
 local player=new('Player');player.Name=name;player.Parent=Players
 if isLocal then Players.LocalPlayer=player end
 local runner={Player=player,Kind=kind,Pos=pos,Vel=V3(0,0,0)};spawnCharacter(runner,biome);runners[name]=runner;return runner
end
local me=addRunner('Me','R15','Crystal',V3(0,0,0),true)
local sand=addRunner('SandNear','R15','Desert',V3(8,0,-20))
local lava=addRunner('LavaMid','R6','Lava',V3(0,0,-80))
local storm=addRunner('StormFar','R15','Storm',V3(-6,0,-130))
local frost=addRunner('FrostOut','R15','Snow',V3(0,0,-220))
-- Boot build checks on the rigs (R15, R6) ---------------------------------------------------------------------
for _,r in pairs(runners)do
 check(r.Folder:GetAttribute('BootCount')==2,r.Player.Name..' boots on both legs')
 local perLeg={}
 for _,m in ipairs(r.Folder:GetChildren())do if m:IsA('Model')then local n=0;for _,p in ipairs(m:GetChildren())do if p:IsA('BasePart')then n+=1;check(p:FindFirstChildOfClass('WeldConstraint')~=nil,'boot part welded')end end;perLeg[m.Name]=n end end
 local want=({Desert=22,Snow=26,Lava=29,Crystal=35,Storm=38})[r.Folder:GetAttribute('BootBiome')]
 check(perLeg.LeftRunnerBoot==want and perLeg.RightRunnerBoot==want and want<=40,r.Player.Name..' R117 parts per leg ('..tostring(perLeg.LeftRunnerBoot)..', want '..tostring(want)..')')
end
-- Client --------------------------------------------------------------------------------------------------------
local clientScript=new('LocalScript');clientScript.Name='RunnerTrailClient'
load('RunnerTrailClient',clientScript)
check(fx~=nil,'client created the effects object')
local function followCamera()local p=me.Pos;camera.CFrame=R.CFrame.lookAt(p+V3(0,12,20),p+V3(0,2,-10))end
local peakParts,peakSpent=0,0
local effectNames={['Boot idle patch']=true,['Fading boot mark']=true,['Boot idle aura']=true,['Boot idle shard']=true,['Boot static arc']=true,['Ground ribbon anchor']=true,['Boot step bursts']=true}
local function aliveEffectParts()local n=0;for _,o in ipairs(R.created)do if effectNames[o._props.Name]and not o._destroyed then n+=1 end end;return n end
local function run(seconds,dt)
 dt=dt or 1/60
 for _=1,math.floor(seconds/dt+.5)do
  R.advance(dt)
  for _,r in pairs(runners)do if r.Character and r.Character.Parent then r.Pos=r.Pos+r.Vel*dt;place(r)end end
  followCamera()
  Run.RenderStepped:Fire(dt);Run.Heartbeat:Fire(dt)
  peakSpent=math.max(peakSpent,fx.Spent)
 end
 peakParts=math.max(peakParts,aliveEffectParts())
end
local function recordOf(name)for r in pairs(fx.Records)do if r.Character==runners[name].Character then return r end end;return nil end
local function liveMarks(ring)local n=0;for _,m in ipairs(fx.Rings[ring].Marks)do if m.Live then n+=1 end end;return n end
local function reset()stamps.Local=0;stamps.Others=0;table.clear(stampLog);bursts=0;arcs=0 end
local function stampsBy(runnerName)local n=0;local root=runners[runnerName];for _,s in ipairs(stampLog)do if math.abs(s.Pos.Z-root.Pos.Z)<40 and math.abs(s.Pos.X-root.Pos.X)<3 then n+=1 end end;return n end
followCamera();run(.5)
check(recordOf('Me')and recordOf('SandNear')and recordOf('LavaMid')and recordOf('StormFar'),'4 runners bound within range')
check(recordOf('FrostOut')==nil,'runner beyond Range not bound')
check(recordOf('Me').Detail==3 and recordOf('SandNear').Detail==3,'local and near runner at full detail')
check(recordOf('LavaMid').Detail==2,'mid runner prints only (got '..tostring(recordOf('LavaMid').Detail)..')')
check(recordOf('StormFar').Detail==1,'far runner ribbons only (got '..tostring(recordOf('StormFar').Detail)..')')
check(recordOf('Me').ThemeName=='Crystal'and recordOf('SandNear').ThemeName=='Desert','themes come from BootBiome (no treadmill gate)')
-- A: walk at 16 studs/s ---------------------------------------------------------------------------------------------
reset()
for _,r in pairs(runners)do r.Vel=V3(0,0,-16)end
run(3)
print(string.format('A walk16: local stamps %d, others %d, bursts %d',stamps.Local,stamps.Others,bursts))
check(stamps.Local>=15 and stamps.Local<=24,'local prints at walking pace ('..stamps.Local..')')
check(stampsBy('SandNear')>=10,'near player prints ('..stampsBy('SandNear')..')')
check(stampsBy('LavaMid')>=8,'mid player prints ('..stampsBy('LavaMid')..')')
check(stampsBy('StormFar')==0,'far player: no prints')
check(bursts>0 and(emitted['Crystal sparkles']or 0)>0 and(emitted['Dust puff']or 0)>0,'bursts for local + near')
check((emitted['Magma sparks']or 0)==0,'no bursts for the mid (detail 2) player')
local rm=recordOf('Me');check(rm.Ground[1].Trail.Enabled==true,'local ground ribbon on while walking')
check(recordOf('StormFar').Ground[1].Trail.Enabled==true,'far player keeps the ground ribbon')
check(fx.IdleActive==0,'no idle aura while walking')
check(liveMarks('Local')<=fx.Budget.LocalMarks and#fx.Rings.Local.Marks<=fx.Budget.LocalMarks,'local ring capped')
-- B: stop, idle aura fades in ------------------------------------------------------------------------------------------
me.Vel=V3(0,0,0);lava.Vel=V3(0,0,0)
run(.5);check(rm.Fade==0 and rm.Idle==nil,'no aura before the still delay')
run(1.2);check(rm.Idle~=nil and rm.Fade>.9,'aura faded in after standing ('..string.format('%.2f',rm.Fade)..')')
local rig1=rm.Idle
local rate=0;for _,e in ipairs(rig1 and rig1.Emitters or{})do if e.Enabled then rate+=e.Rate end end
check(rate>0,'idle emitters running')
check(rig1 and#rig1.Shards==5 and rig1.Shards[1].Transparency<.3,'crystal orbit shards visible (R117: 5)')
check(recordOf('LavaMid').Idle==nil,'mid player (detail 2) gets no aura')
local a0=rig1 and rig1.Angle;run(.5);check(rig1 and rig1.Angle~=a0,'crystal shards orbit')
run(3.2);check(liveMarks('Local')==0,'local prints faded out after standing ('..liveMarks('Local')..')')
-- C: walk again, aura fades out and the rig returns to the pool ----------------------------------------------------------------
me.Vel=V3(0,0,-16);run(.45)
check(rm.Idle==nil and fx.IdleActive==0,'aura dropped after moving again')
check(rig1 and not rig1.Emitters[1].Enabled and rig1.Shards[1].Transparency==1,'pooled rig switched off')
check(fx.IdleFree.Crystal and#fx.IdleFree.Crystal==1,'rig back in the free list')
me.Vel=V3(0,0,0);run(1.6);check(rm.Idle==rig1,'rig reused on next stop')
-- D: 500 studs/s ----------------------------------------------------------------------------------------------------------
reset();me.Vel=V3(0,0,-500);sand.Vel=V3(0,0,-500);lava.Vel=V3(0,0,-500);storm.Vel=V3(0,0,-500)
run(3)
local perSecond=stamps.Local/3;local minGap=math.huge;local last
for _,s in ipairs(stampLog)do if s.Ring=='Local'then if last then minGap=math.min(minGap,(s.Pos-last).Magnitude)end;last=s.Pos end end
print(string.format('D 500st/s: local %.1f prints/s, min gap %.1f studs, bursts %d, peak spent/s %d',perSecond,minGap,bursts,peakSpent))
check(perSecond<=9.5 and perSecond>=5,'prints/s bounded at 500 studs/s')
check(minGap>=50,'prints spread out with speed')
check(peakSpent<=fx.Budget.Particles,'burst particles within the per-second cap')
check(#fx.Rings.Local.Marks<=fx.Budget.LocalMarks and#fx.Rings.Others.Marks<=fx.Budget.OtherMarks,'rings never grow past their caps')
check(rm.Idle==nil,'no aura at speed')
-- E: crowd of idle players nearby ------------------------------------------------------------------------------------------
for _,r in pairs(runners)do r.Vel=V3(0,0,0)end
local crowd={}
for i=1,7 do local biomes={'Desert','Snow','Lava','Crystal','Storm','Desert','Snow'};crowd[i]=addRunner('Crowd'..i,'R15',biomes[i],me.Pos+V3(-9+i*2.5,0,-12))end
run(2.5)
local bound=0;for _ in pairs(fx.Records)do bound+=1 end
print(string.format('E crowd: bound %d, idle active %d (cap %d+1 local), rigs %d',bound,fx.IdleActive,fx.Budget.Idle,fx.IdleRigs))
check(bound<=fx.Budget.Characters,'bound runners within the character cap')
check(fx.IdleActive<=fx.Budget.Idle+1,'idle rigs within cap')
check(rm.Idle~=nil,'local wearer keeps an aura in a crowd')
-- F: low budget (FastMode) ------------------------------------------------------------------------------------------------
me.Player:SetAttribute('FastMode',true)
for _,r in pairs(runners)do r.Vel=V3(0,0,-20)end
run(4)
for _,r in pairs(runners)do r.Vel=V3(0,0,0)end
run(3.5)
print(string.format('F low: tier %d, local marks %d/%d, others %d/%d, idle %d, rigs %d, alive fx parts %d',fx.Budget.Tier,#fx.Rings.Local.Marks,fx.Budget.LocalMarks,#fx.Rings.Others.Marks,fx.Budget.OtherMarks,fx.IdleActive,fx.IdleRigs,aliveEffectParts()))
check(fx.Budget.Tier==1,'FastMode drops to tier 1')
check(#fx.Rings.Local.Marks<=12 and#fx.Rings.Others.Marks<=6,'rings shrink on low budget')
local bound2=0;for _ in pairs(fx.Records)do bound2+=1 end;check(bound2<=4,'4 runners on low budget')
check(fx.IdleActive<=2 and fx.IdleRigs<=2,'idle rigs trimmed on low budget')
me.Player:SetAttribute('FastMode',false)
quality.Value=2;run(.5);check(fx.Budget.Tier==1,'graphics level 2 caps to tier 1');quality.Value=0
-- G: reduced motion ------------------------------------------------------------------------------------------------------------
Gui.ReducedMotionEnabled=true
for _,c in ipairs(crowd)do c.Character:Destroy();c.Player.Parent=nil;Players.PlayerRemoving:Fire(c.Player);runners[c.Player.Name]=nil end
reset();storm.Pos=me.Pos+V3(3,0,-10);me.Vel=V3(0,0,0);storm.Vel=V3(0,0,0);run(2)
local stormRec=recordOf('StormFar')
check(fx.Budget.Reduced and fx.Budget.Arcs==0,'reduced motion: no arcs budget')
check(arcs==0,'no static arcs under reduced motion')
local angle=rm.Idle and rm.Idle.Angle;run(.5);check(rm.Idle and rm.Idle.Angle==angle,'no swirl/orbit under reduced motion')
Gui.ReducedMotionEnabled=false;reset();run(3)
check(stormRec and stormRec.Idle~=nil,'storm aura when close and still')
check(arcs>0,'storm idle arcs when motion is allowed ('..arcs..')')
-- H: unequip ----------------------------------------------------------------------------------------------------------------------
local oldRibbon=rm.Ground[1].Part
dress(me,nil);run(.4)
local rm2=recordOf('Me')
check(rm2~=rm and rm2.Theme==nil and#rm2.Ground==0,'unequip: rebound without a boot look')
check(oldRibbon._destroyed==true,'unequip: old ribbons destroyed')
check(rm.Idle==nil,'unequip: aura released')
me.Vel=V3(0,0,-16);reset();run(1);check(stamps.Local==0,'no prints without boots')
-- I: respawn with other boots ----------------------------------------------------------------------------------------------------------
local oldChar=me.Character;oldChar:Destroy();spawnCharacter(me,'Storm');run(.4)
local rm3=recordOf('Me');check(rm3 and rm3.ThemeName=='Storm'and rm3.Character==me.Character,'respawn: rebound to the new character')
reset();run(1);check(stamps.Local>0,'respawn: prints again')
-- J: leave -------------------------------------------------------------------------------------------------------------------------------
local sandRec=recordOf('SandNear');local sandRibbon=sandRec and sandRec.Ground[1].Part
sand.Player.Parent=nil;Players.PlayerRemoving:Fire(sand.Player);runners.SandNear=nil
check(sandRibbon and sandRibbon._destroyed==true and not fx.Records[sandRec],'leave: record released immediately')
run(.5)
-- Pure rules ---------------------------------------------------------------------------------------------------------------------------------
local b3=Styles.Budget(3,false);local b1=Styles.Budget(1,false)
check(Styles.Spacing(16)<=Styles.Spacing(100)and Styles.Spacing(1000)==60,'spacing grows with speed, capped')
check(Styles.Detail(false,200,true,b3)==1 and Styles.Detail(false,10,false,b3)==2 and Styles.Detail(true,1e9,false,b1)==3,'detail levels')
for _,k in ipairs({'Sand','Frost','Ember','Crystal','Lightning'})do check(#Styles.PrintParts(k,1,1.5,-1)==3,k..' print has 3 parts')end
-- K: client script destroyed -----------------------------------------------------------------------------------------------------------------
local hbBefore=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then hbBefore+=1 end end
clientScript:Destroy()
local hbAfter=0;for _,c in ipairs(Run.Heartbeat._c)do if c.Connected then hbAfter+=1 end end
local removalLive=0;for _,c in ipairs(Players.PlayerRemoving._c)do if c.Connected then removalLive+=1 end end
check(hbBefore==1 and hbAfter==0 and removalLive==0,'connections disconnected on destroy')
check(aliveEffectParts()==0,'no effect parts left after destroy ('..aliveEffectParts()..')')
check(workspace:FindFirstChild('RunnerGroundEffects')==nil,'effects folder removed')
local maxParts=3*(b3.LocalMarks+b3.OtherMarks)+3*b3.Arcs+12*(b3.Idle+1)+1+2*b3.Characters -- R117: idle rigs hold up to 12 parts (was 7)
print(string.format('peak live effect parts %d (bound %d), rays %d',peakParts,maxParts,rays))
check(peakParts<=maxParts,'peak effect parts within the pool bound')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('boot fx test failed')end
