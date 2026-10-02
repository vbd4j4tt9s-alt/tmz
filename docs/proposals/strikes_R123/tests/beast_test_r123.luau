--!nocheck
local R=require('./roblox');local Bn=require('./beast_bundle');local Mx=require('./cfmath')
local new=R.new;local CF=Mx.CFrame;local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local L=require('./loader').new(Bn)
local Data=L.require('KeeperUpgradeData');local Cfg=L.require('KeeperRigConfig');local Combat=L.require('KeeperCombat')
for _,stage in ipairs({1,5,7})do
 local game=new('DataModel');local services={}
 local function service(n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
 function game.GetService(_,n)return service(n)end
 local workspace=service('Workspace');local RS=service('ReplicatedStorage');local Run=service('RunService');Run.RenderStepped=R.signal()
 local now=10;function workspace.GetServerTimeNow()return now end
 local cam=new('Camera');cam.CFrame=CF.new(0,10,40);workspace.CurrentCamera=cam
 local moved={}
 function workspace.BulkMoveTo(_,ps,fs)for i,p in ipairs(ps)do moved[p]=fs[i]end end
 local stubs={KeeperAudio={Voice=function()return nil,0,1 end},SoundTiming={Play=function()end},KeeperVoices=setmetatable({},{__index=function()return {Gap=6}end}),
  KeeperMotion={new=function()return {}end,Update=function(_,frame)return {Frame=frame,Awake=1,Time=now,Moving=0,Cycle=0,Urgency=0,Speed=0,Turn=0}end},
  KeeperRecoveryDash={VisualFrame=function(_,_,f)return f end},KeeperSleep={new=function()return {Update=function()end,Destroy=function()end}end},
  KeeperSurge={New=function()return {}end,Step=function()end,Destroy=function()end},CosmeticBudget={KeeperDue=function()return true end},ClientFxBudget={Low=function()return false end},
  KeeperFx={new=function()return {}end,Step=function()end,Slam=function()end,Wake=function()end,Destroy=function()end},KeeperAccents={new=function()return {}end,Pose=function()end,Destroy=function()end}}
 local mods={}
 local function modscript(n)local m=new('ModuleScript');m.Name=n;m.Parent=RS;return m end
 for n in pairs(stubs)do modscript(n)end
 for _,n in ipairs({'BeastPose','KeeperRigConfig','KeeperAttackPose','KeeperUpgradePose','KeeperStrikeFrames','KeeperCombat','KeeperUpgradeData','CrystalKnightPose','KeeperSignatureStrike','KeeperPolish'})do modscript(n)end
 local env;local cache={}
 local function req(m)if stubs[m.Name]then return stubs[m.Name]end;return L.require(m.Name)end
 env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=Mx.Vector3,CFrame=CF,Color3=R.Color3,Enum=R.Enum,typeof=R.typeof,task=R.task,require=req},{__index=_G})
 local model=new('Model');model.Name='Keeper';model:SetAttribute('GardenerArtVersion',99);model:SetAttribute('CreatureStage',stage);model:SetAttribute('GuardianBehavior','CHASING')
 local root=new('Part');root.Name='HumanoidRootPart';root.CFrame=CF.new(0,4,0);root.Parent=model
 local body=new('Model');body.Name='BeastBody';body:SetAttribute('VisualVersion',59);body.Parent=model
 for _,s in ipairs(Data[stage].Parts)do local p=new('Part');p.Name=s.Name;p.Size=Mx.Vector3.new(table.unpack(s.Size));p:SetAttribute('RestCFrame',CF.new(table.unpack(s.Rest)));p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow);p.Parent=body end
 model.Parent=workspace
 local sc=new('LocalScript');sc.Name='BeastAnimation'
 local fn=assert(loadstring(Bn.BeastAnimation,'=BeastAnimation'));setfenv(fn,setmetatable({script=sc},{__index=env}));fn()
 R.advance(0) -- deferred bind
 Run.RenderStepped:Fire(1/60);check(next(moved)~=nil,stage..' keeper animated')
 local attackAt=now+.06;model:SetAttribute('KeeperAttackAt',attackAt)-- replicated 60 ms late
 local W=Combat.Get(stage).Windup;local arm=nil
 local g=stage==5 and 'Sword' or 'RightArm';for _,p in ipairs(body:GetChildren())do if p:GetAttribute('BeastGroup')==g and(not arm or p:GetAttribute('RestCFrame').Y<arm:GetAttribute('RestCFrame').Y)then arm=p end end
 local track={}
 for i=0,50 do now=attackAt+.06+i/120;Run.RenderStepped:Fire(1/120);track[#track+1]={now-attackAt,moved[arm].Position}end
 local first=track[1][2];local rest=root.CFrame*CF.new(0,0,0)
 -- the first visible frame after late arrival must not jump: arm near its idle place
 local idle=L.require('KeeperStrikeFrames').Frames(stage,track[1][1]+attackAt,nil)
 local expect=(root.CFrame*idle[g]*arm:GetAttribute('RestCFrame')).Position
 check((first-expect).Magnitude<.05,stage..' late attack starts from idle (off '..string.format('%.3f',(first-expect).Magnitude)..')')
 local backMax=-math.huge;local atImpact
 for _,e in ipairs(track)do if e[1]<W then backMax=math.max(backMax,e[2].Z)end;if math.abs(e[1]-W)<1/240 then atImpact=e[2]end end
 check(backMax>first.Z+1,stage..' arm travels back during windup ('..string.format('%.2f',backMax-first.Z)..')')
 now=attackAt+W+Combat.Recovery+.01;Run.RenderStepped:Fire(1/60);check(moved[arm]~=nil,stage..' after R110 window still animates')
 sc.Destroying:Fire()
end
print(('beast animation checks %d, fails %d'):format(checks,fails))
