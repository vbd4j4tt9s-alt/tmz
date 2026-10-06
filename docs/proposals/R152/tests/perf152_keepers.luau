--!nocheck
-- R152 performance patch: the keepers on screen, frame by frame. The bake of the 8 R152 models (keeper_mesh_mock: what the engine would bake), the 7
-- biome keepers dressed by the REAL BeastModels (VARIANT 'R152' = the baked models, 'legacy' = today's keepers: /test keepermodels off) and the REAL
-- BeastAnimation client with the real KeeperFx152 / KeeperFx / KeeperAccents / KeeperSleep / KeeperSurge / CosmeticBudget (pose LOD); only the motion
-- (KeeperMotion: a fixed script of awake / moving / cycle values), the voices and the dash are stand-ins, as in test_keepers.luau. TIER = ClientFxBudget.
-- Phases: asleep (GUARDING), waking (ALERTED), chasing, a strike; the camera near some keepers and far from others. Every frame is a stream frame
-- (perf152_fp.luau) of every keeper and the camera; PERF lines give the per-frame writes and Lua time of BeastAnimation.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./keeper_mesh_mock')
local FP=require('./perf152_fp')(W);FP.orderedPairs()
math.randomseed(152)
local TIER=TIER or 3;local VARIANT=VARIANT or'R152'
local log=Mock.install(W,{})
W.Run.IsServer=function()return true end
local RS=W.RS;local SS=W.service('ServerStorage');local CS=W.service('CollectionService')
local Cfg=W.module('KeeperRigConfig')
do local tf=R.new('Folder');tf.Name='KeeperTemplatesV100';tf.Parent=SS
 for _,stage in ipairs({2,3,4,6})do
  local m=R.new('Model');m.Name='Stage'..stage;m:SetAttribute('VisualVersion',99)
  for _,s in ipairs(Cfg[stage].Parts)do
   local p=R.new('MeshPart');p.Name=s.Name;p.Size=V3(s.Size[1],s.Size[2],s.Size[3]);local rest=CF(s.Center[1],s.Center[2],s.Center[3]);p.CFrame=rest
   p:SetAttribute('RestCFrame',rest);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow);p.Parent=m
  end
  rawset(m,'Clone',function(self)
   local c=R.new('Model');for k,v in pairs(self._props)do c._props[k]=v end;for k,v in pairs(self._attrs)do c._attrs[k]=v end
   for _,ch in ipairs(self._children)do local q=R.Inst.Clone(ch);for k,v in pairs(ch._attrs)do q._attrs[k]=v end;q.Parent=c end
   return c
  end)
  m.Parent=tf
 end
end
local function keeperModel(stage,at)
 local m=R.new('Model');m.Name='Guardian_Stage'..stage;local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=at;root.Parent=m;m.PrimaryPart=root
 m:SetAttribute('GuardianBehavior','GUARDING');m:SetAttribute('GuardianLeaseToken',0);m.Parent=W.workspace;CS:AddTag(m,'BiomeKeeper');return m
end
do local mt=getmetatable(CF(0,0,0))
 rawset(mt,'PointToObjectSpace',function(c,v)return c:Inverse()*v end)
 rawset(mt,'VectorToObjectSpace',function(c,v)local i=c:Inverse();return i*v-i.Position end)
end
if not rawget(R.Inst,'Stop')then rawset(R.Inst,'Stop',function(self)self.Playing=false end)end
-- sounds as the game's helpers expect them (Ended / Loaded, Play), Debris that removes on time
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='Sound'then o.IsLoaded=true;o.TimeLength=3;o.TimePosition=0;o.Loaded=R.signal();o.Ended=R.signal()end
 return o end;W.env.Instance=R.Instance end
if not rawget(R.Inst,'Play')then rawset(R.Inst,'Play',function(self)self.Playing=true end)end
W.service('Debris').AddItem=function(_,o,t)R.task.delay(t or 10,function()o:Destroy()end)end
-- the keepers, in a row along x (60 studs apart); the bake runs, then (R152) the idle swap
local Models=W.module('BeastModels');local Meshes=W.module('KeeperMeshes152')
local guardians={}
for stage=1,7 do local m=keeperModel(stage,CF(stage*60,6,0));Models.Dress(m,stage);guardians[stage]=m end
R.advance(0);R.advance(2.1)
local Cmd=W.module('KeeperMeshCommand152')
if VARIANT=='legacy'then Cmd.Execute({},nil,{'off'});R.advance(.1)end
for stage=1,7 do assert(guardians[stage]:GetAttribute('KeeperMeshVariant')==(VARIANT=='legacy'and'Legacy'or'R152'),'stage '..stage..' is not '..VARIANT)end
-- the client
local S={awake=0,moving=0,cycle=0,urgency=0,speed=0,t=0}
W.Run.IsServer=function()return false end;W.Run.IsClient=function()return true end
W.stub('KeeperAudio',{Voice=function()return nil,0,1 end});W.stub('SoundTiming',{Play=function()end})
W.stub('KeeperVoices',setmetatable({},{__index=function()return {Gap=6}end}))
W.stub('KeeperMotion',{new=function()return {}end,Update=function(_,frame)return {Frame=frame,Awake=S.awake,Time=S.t,Moving=S.moving,Cycle=S.cycle,Urgency=S.urgency,Speed=S.speed,Turn=0}end})
W.stub('KeeperRecoveryDash',{VisualFrame=function(_,_,f)return f end})
W.stub('ClientFxBudget',{Low=function()return TIER==1 end,Get=function()return TIER end})
local camera=W.workspace.CurrentCamera;camera.FieldOfView=70
camera.WorldToViewportPoint=function(self,p)
 local q=self.CFrame:PointToObjectSpace(p);local d=-q.Z
 local tv=math.tan(math.rad(self.FieldOfView)/2);local th=tv*1280/720
 local on=d>0 and math.abs(q.X)<=d*th and math.abs(q.Y)<=d*tv
 return V3(0,0,d),on
end
function W.workspace.BulkMoveTo(_,parts,frames)for i,p in ipairs(parts)do p.CFrame=frames[i]end end
local sc=R.new('LocalScript');sc.Name='BeastAnimation'
local fn=assert(loadstring(W.B.BeastAnimation,'=BeastAnimation'));setfenv(fn,setmetatable({script=sc},{__index=W.env}))
fn();R.advance(0);W.frames(2,1/60)
-- phases: the camera beside keepers 2 / 3 (near: every frame), the others 60 .. 360 studs away (the pose LOD and KeeperFx152's 200-stud range apply)
local st=FP.stream(string.format('keepers %s t%d',VARIANT,TIER))
local roots={camera};for stage=1,7 do roots[#roots+1]=guardians[stage]end
local f=0
local function run(n,label,each)
 for _=1,n do
  S.t+=1/60;if S.moving>0 then S.cycle=(S.cycle+1/60*1.6)%1 end
  if each then each()end
  W.frames(1,1/60);f+=1
  st:frame(label..' f'..f,roots)
 end
end
local function state(s)for stage=1,7 do guardians[stage]:SetAttribute('GuardianBehavior',s)end end
camera.CFrame=R.CFrame.lookAt(V3(150,24,-60),V3(150,6,0))
state('GUARDING');S.awake=0;S.moving=0
run(90,'asleep')
state('ALERTED');S.awake=.5;run(30,'waking')
state('CHASING');S.awake=1;S.moving=1;S.speed=30;S.urgency=.6
run(90,'chasing',function()for stage=1,7 do local r=guardians[stage].HumanoidRootPart;r.CFrame=r.CFrame*CF(0,0,-.4)end end)
for stage=1,7 do guardians[stage]:SetAttribute('KeeperAttackAt',W.workspace:GetServerTimeNow())end
run(90,'strike')
for stage=1,7 do guardians[stage]:SetAttribute('KeeperAttackAt',nil)end
-- the camera turns away from every keeper (behind it): far LOD and off-screen poses
camera.CFrame=R.CFrame.lookAt(V3(150,24,-60),V3(150,24,-400))
run(60,'away')
camera.CFrame=R.CFrame.lookAt(V3(150,24,-60),V3(150,6,0))
state('GUARDING');S.awake=0;S.moving=0;S.speed=0;S.urgency=0
run(60,'asleep again')
-- per-frame cost: chasing, near
state('CHASING');S.awake=1;S.moving=1;S.speed=30
FP.probeStart();FP.Probe.Where=PERF_WHERE==true
local tm=FP.minTimes(W.Run,4,30,function()S.t+=1/60;S.cycle=(S.cycle+1/60*1.6)%1;W.frames(1,1/60)end)
local p=FP.probeStop()
print(string.format('PERF keepers.chase variant=%s tier=%d lua: BeastAnimation %.3f ms | %s',VARIANT,TIER,tm.BeastAnimation or 0,FP.probeText(p,120,10)))
if PERF_WHERE then FP.whereText(120)end
state('GUARDING');S.awake=0;S.moving=0;W.frames(10,1/60)
FP.probeStart();FP.Probe.Where=PERF_WHERE==true
tm=FP.minTimes(W.Run,4,30,function()S.t+=1/60;W.frames(1,1/60)end)
p=FP.probeStop()
print(string.format('PERF keepers.asleep variant=%s tier=%d lua: BeastAnimation %.3f ms | %s',VARIANT,TIER,tm.BeastAnimation or 0,FP.probeText(p,120,10)))
if PERF_WHERE then FP.whereText(120)end
local c=FP.counts(W.workspace)
print(string.format('PERF keepers.counts variant=%s tier=%d %s',VARIANT,TIER,FP.countText(c)))
print('PERF152 KEEPERS DONE')
