--!nocheck
-- Runs the real BeastAnimation + KeeperPolish/KeeperFx/KeeperAccents/KeeperSleep per stage through
-- sleep -> wake -> chase (with turns) -> strike + catch -> taunt -> return -> sleep, then removal.
local W=require('./world');local Mx=W.Mx;local CF,V=Mx.CFrame,Mx.Vector3.new
local which=... or 'new'
local bundle=require('./bundle_'..which)
local fails,checks=0,0
local function check(c,m)checks+=1;if not c then fails+=1;print('FAIL: '..m)end end
local lowFlag=false
local stubs={KeeperAudio={Voice=function()return nil,0,1 end,Asset=function()return nil end},SoundTiming={Play=function()end},
 CosmeticBudget={KeeperDue=function()return true end},ClientFxBudget={Low=function()return lowFlag end},
 KeeperRecoveryDash={VisualFrame=function(_,_,f)return f end}}
local speeds={[1]=23,[2]=57,[3]=92,[4]=147,[5]=236,[6]=37,[7]=379}
local report={};jumpRep={}
local function nan(cf)local p=cf.Position;return p.X~=p.X or p.Y~=p.Y or p.Z~=p.Z end
for stage=1,7 do
 W.emitted=0;W.emits=0
 local world=W.new(bundle,stubs);local req=world.require
 local Cfg=req('KeeperRigConfig');local Combat=req('KeeperCombat')
 local model=W.R.new('Model');model.Name='Keeper'..stage
 model:SetAttribute('GardenerArtVersion',99);model:SetAttribute('CreatureStage',stage);model:SetAttribute('GuardianBehavior','GUARDING')
 local root=W.R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF.new(0,4,0);root.Parent=model
 local body
 if stage==1 or stage==5 or stage==7 then body=req('KeeperUpgradeArt').Build(stage)
 else
  body=W.R.new('Model');body.Name='BeastBody';body:SetAttribute('VisualVersion',99)
  for _,s in ipairs(Cfg[stage].Parts)do local p=W.R.new('MeshPart');p.Name=s.Name;p.Size=V(table.unpack(s.Size));p:SetAttribute('RestCFrame',CF.new(table.unpack(s.Center)));p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow);p.Parent=body end
 end
 body.Name='BeastBody';body.Parent=model;model.Parent=world.Workspace
 local sc=world.run('BeastAnimation')
 world.step(1/60)
 local parts={};for _,p in ipairs(body:GetDescendants())do if p:IsA('BasePart')then table.insert(parts,p)end end
 local accents=model:FindFirstChild('KeeperAccentsLocal')
 local refPart;for _,p in ipairs(parts)do local g=p:GetAttribute('BeastGroup');if g=='Body'or g=='Segment1'then refPart=p;break end end
 local nAcc=accents and #accents:GetChildren()or 0
 local dt=1/60;local t0=world.Now;local maxBulk=0;local bad=0;local zzzSeen,zzzAwake=false,false
 local lights=0;local maxEmitRate=0;local emitWindow={}
 local W_=Combat.Get(stage).Windup;local prevLocal,jumps,phase={},{},nil
 local function frame(state,speed,dir)
  model:SetAttribute('GuardianBehavior',state);model:SetAttribute('KeeperTravelSpeed',speed or 0)
  if speed and speed>0 then local cf=root.CFrame;root.CFrame=CF.new(cf.Position+dir*speed*dt)*CF.new(V(),dir)end
  world.Workspace.CurrentCamera.CFrame=CF.new(world.Me.CFrame.Position+V(0,8,14))
  world.step(dt)
  maxBulk=math.max(maxBulk,world.LastBulk or 0)
  local ref=world.Moved[refPart];local inv=ref and ref:Inverse()or root.CFrame:Inverse()
  for _,p in ipairs(parts)do local f=world.Moved[p];if not f or nan(f)then bad+=1 else
   local l=(inv*f).Position;local o=prevLocal[p];if o and phase then jumps[phase]=math.max(jumps[phase]or 0,(l-o).Magnitude)end;prevLocal[p]=l end end
  local zzz=root:FindFirstChild('KeeperSleepLocal');zzz=zzz and zzz:FindFirstChild('KeeperZzzLocal')
  if zzz and zzz.Enabled then if state=='GUARDING'then zzzSeen=true else zzzAwake=true end end
  local on=0;for _,d in ipairs(root:GetDescendants())do if d.ClassName=='PointLight'and d.Enabled then on+=1 end end;lights=math.max(lights,on)
 end
 world.Me.CFrame=CF.new(0,4,-18) -- the player sneaks up: stir + Zzz nearby
 for _=1,120 do frame('GUARDING')end
 local asleepBulk=maxBulk;phase='wake'
 model:SetAttribute('TargetUserId',77);world.Me.CFrame=CF.new(12,4,-40)
 local before=W.emitted
 for _=1,63 do frame('ALERTED')end
 local wakeParticles=W.emitted-before;phase='chase'
 local fwd=V(0,0,-1)
 before=W.emitted;local e0=W.emits
 for i=1,150 do
  if i==60 then fwd=V(-.6,0,-.8)end;if i==100 then fwd=V(.6,0,-.8)end
  world.Me.CFrame=CF.new(root.CFrame.Position+fwd*30+V(0,0,0))
  frame('CHASING',speeds[stage],fwd)
 end
 local chaseParticles=W.emitted-before;local chaseEmits=W.emits-e0
 -- strike + catch
 phase='strike';local at=world.Now;model:SetAttribute('KeeperAttackAt',at);world.Me.CFrame=CF.new(root.CFrame.Position+fwd*Combat.Get(stage).Reach*.6)
 before=W.emitted
 for _=1,math.ceil((W_+Combat.Recovery)*60)+2 do
  if world.Now>=at+W_ and not model:GetAttribute('KeeperLastHitAt')then model:SetAttribute('KeeperLastHitAt',world.Now)end
  frame('ATTACKING')
 end
 local slamParticles=W.emitted-before
 phase='taunt';for _=1,90 do frame('ATTACKING')end;phase='return' -- taunt while held
 model:SetAttribute('TargetUserId',0)
 for _=1,120 do frame('RETURNING',speeds[stage]*.5,V(0,0,1))end
 for _=1,60 do frame('GUARDING')end
 lowFlag=true;before=W.emitted
 for _=1,60 do frame('CHASING',speeds[stage],V(0,0,-1))end
 local lowParticles=W.emitted-before;lowFlag=false
 check(bad==0,stage..' every part posed every frame, no NaN ('..bad..' bad)')
 check(stage==1 or zzzSeen,stage..' Zzz shows while asleep nearby')
 check(stage~=1 or not zzzSeen,stage..' golem (tree) shows no Zzz')
 check(not zzzAwake,stage..' Zzz hidden while awake')
 check(lights<=1,stage..' at most one eye light per keeper')
 check(wakeParticles>0,stage..' wake burst emitted')
 check(stage==2 or chaseEmits>=4,stage..' footfall dust while chasing ('..chaseEmits..')')
 check(maxBulk==#parts+nAcc,stage..' bulk list = rig parts + accents ('..maxBulk..' vs '..#parts..'+'..nAcc..')')
 -- removal: every client-made instance goes away
 model.Parent=nil;world.step(dt)
 local left=0;for _,d in ipairs(root:GetDescendants())do left+=1 end
 check(left==0,stage..' root cleaned after removal ('..left..' left)')
 check(model:FindFirstChild('KeeperAccentsLocal')==nil,stage..' accents destroyed')
 sc.Destroying:Fire()
 local secs=(150)/60
 table.insert(jumpRep,string.format('%d jumps/frame (studs, rig-local): wake %.2f chase %.2f strike %.2f taunt %.2f return %.2f',stage,jumps.wake or 0,jumps.chase or 0,jumps.strike or 0,jumps.taunt or 0,jumps['return']or 0))
 table.insert(report,string.format('%d %-15s parts %2d +acc %d | wake %3d particles | chase %.0f/s (%d puffs) | slam %d | low-gfx chase %.0f/s',stage,Cfg[stage].Name,#parts,nAcc,wakeParticles,chaseParticles/secs,chaseEmits,slamParticles,lowParticles))
end
for _,l in ipairs(report)do print(l)end;for _,l in ipairs(jumpRep)do print(l)end
print(('state run checks %d, fails %d'):format(checks,fails))
