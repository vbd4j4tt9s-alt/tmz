--!nocheck
-- R130 performance: idle keepers at home. Real ConcurrentKeeperService:_maintainGuardians on the Roblox mock with a
-- counting ChaseService stand-in. A keeper at home is fully re-prepared only when needed (parts changed, reparented,
-- replaced, after a chase, every 5 s), is put back home if it moved, and its idle attributes are written only when wrong.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='RemoteEvent'then o._props.OnClientEvent=R.signal();o._props.OnServerEvent=R.signal()end
 return o end end
local SSS=W.service('ServerScriptService');local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local function serverStub(name,value)W.stub(name,value);local m=R.new('ModuleScript');m.Name=name;m._stubbed=true;m.Parent=folder;return m end
serverStub('RagdollService',{new=function()return {}end});serverStub('KeeperContact',{Touching=function()return false end})
serverStub('BatService',{new=function()return {Start=function()end}end});serverStub('SecurityGate',{Allow=function()return true end})
serverStub('MovementGuard',{Check=function()return true end,Reset=function()end})
local K=R.new('ModuleScript');K.Name='ConcurrentKeeperService';K._source='ConcurrentKeeperService';K.Parent=folder
-- Keepers: odd stages are client-animated (root moves), even stages pivot the whole model.
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local homes,keepers={},{}
local function keeper(stage)
 local m=R.new('Model');m.Name='Guardian_Stage'..stage
 local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=homes[stage];root.Parent=m;m.PrimaryPart=root
 local arm=R.new('Part');arm.Name='Arm';arm.Parent=m
 m.CFrame=homes[stage];if stage%2==1 then m:SetAttribute('KeeperClientAnimated',true)end
 m:SetAttribute('GuardianBehavior','GUARDING');m:SetAttribute('KeeperTravelSpeed',0);m:SetAttribute('GuardianLeaseToken',0);m:SetAttribute('TargetUserId',0)
 m.Parent=mapRoot;return m
end
for stage=1,7 do homes[stage]=CF(0,5,stage*300);keepers[stage]=keeper(stage)end
-- ChaseService stand-in: the full prepare is _ensurePersistentGuardian (rewrites every part, visibility scan).
local prepares={};local Legacy={}
function Legacy:_ensurePersistentGuardian(stage)prepares[stage]=(prepares[stage]or 0)+1;local g=self.Map.GuardiansByStage[stage];return g and g.Parent and g or nil end
function Legacy:_getGuardianHomeCFrame(stage)return homes[stage]end
local Service=W.require(K)(Legacy)
local self=setmetatable({KeeperTargets={},ReturningGuardians={},Config={StageCount=7},Map={MapRoot=mapRoot,GuardiansByStage=keepers}},Service)
-- Count attribute writes and pivots.
local writes=0;local pivots=0
do local set=R.Inst.SetAttribute;R.Inst.SetAttribute=function(o,k,v)if o._class=='Model'then writes+=1 end;return set(o,k,v)end
 local pivot=R.Inst.PivotTo;R.Inst.PivotTo=function(o,c)pivots+=1;return pivot(o,c)end end
local function total()local n=0;for s=1,7 do n+=prepares[s]or 0 end;return n end
local function run(seconds)for _=1,math.floor(seconds*4+.5)do R.advance(.25);self:_maintainGuardians()end end
-- 1. Twenty quiet seconds at 4 Hz: the old loop did 7 x 80 = 560 full prepares.
self:_maintainGuardians();check(total()==7,'first pass prepares every keeper once ('..total()..')')
writes=0;pivots=0;run(20)
check(total()<=7*5,('20 s idle: %d full prepares (was 560)'):format(total()))
check(total()>=7*4,'5 s safety-net prepare still happens ('..total()..')')
check(writes==0,'no attribute writes while everything is already right ('..writes..')')
check(pivots==0,'no re-pivot while keepers stand at home ('..pivots..')')
for s=1,7 do check(keepers[s]:GetAttribute('GuardianBehavior')=='GUARDING','stage '..s..' still guarding')end
-- 2. Cheap checks still run every pass: wrong attributes are put right and a moved keeper is put back home.
local before=total()
keepers[2]:SetAttribute('GuardianBehavior','CHASING');keepers[2]:SetAttribute('TargetUserId',99)
keepers[2]:PivotTo(CF(40,5,600));keepers[3].PrimaryPart.CFrame=CF(-30,5,900)
writes=0;pivots=0;R.advance(.25);self:_maintainGuardians()
check(keepers[2]:GetAttribute('GuardianBehavior')=='GUARDING'and keepers[2]:GetAttribute('TargetUserId')==0,'idle attributes restored on the next pass')
check(writes==2,'only the two wrong attributes are written ('..writes..')')
check((keepers[2]:GetPivot().Position-homes[2].Position).Magnitude<1e-6,'moved keeper (whole model) back home')
check((keepers[3].PrimaryPart.CFrame.Position-homes[3].Position).Magnitude<1e-6,'moved keeper (client-animated root) back home')
check(total()==before,'putting things right needs no full prepare')
-- 3. Part changes: added or removed parts, or a reparent, mean a full prepare on the next pass.
local function quiet()R.advance(.25);self:_maintainGuardians()end
before=total();local hat=R.new('Part');hat.Name='Hat';hat.Parent=keepers[4];quiet()
check(prepares[4]and total()==before+1,'a part added to a keeper -> full prepare')
before=total();keepers[5].DescendantRemoving:Fire(keepers[5].Arm);quiet()
check(total()==before+1,'a part removed -> full prepare')
before=total();keepers[6].Parent=W.workspace;quiet()
check(total()==before+1,'keeper reparented -> full prepare')
before=total();quiet();quiet();check(total()==before,'clean again afterwards')
-- 4. A replaced or destroyed keeper.
before=total();local old=keepers[1];keepers[1]=keeper(1);quiet()
check(total()==before+1,'replaced keeper -> full prepare of the new one')
before=total();old.Arm.Parent=nil;old.Name='x';hat=R.new('Part');hat.Parent=old;quiet()
check(total()==before,'the old model no longer counts')
before=total();keepers[7]:Destroy();quiet()
check(prepares[7]and total()==before+1,'destroyed keeper -> the full path (which rebuilds it)')
keepers[7]=keeper(7);quiet()
-- 5. Chases: a keeper with a target or on its way home is never touched, and is fully prepared when idle again.
-- (other stages may get their 5 s refresh meanwhile, so count stage 2 only)
local writes2,pivots2=0,0
do local set=R.Inst.SetAttribute;R.Inst.SetAttribute=function(o,k,v)if o==keepers[2]then writes2+=1 end;return set(o,k,v)end
 local pivot=R.Inst.PivotTo;R.Inst.PivotTo=function(o,c)if o==keepers[2]then pivots2+=1 end;return pivot(o,c)end end
before=prepares[2];self.KeeperTargets[2]={};keepers[2]:SetAttribute('GuardianBehavior','CHASING');keepers[2]:PivotTo(CF(10,5,700))
writes2=0;pivots2=0;run(2)
check(prepares[2]==before and writes2==0 and pivots2==0,'a chasing keeper is left alone')
check(self.IdleKeepers[2]==nil,'its idle record is dropped')
self.KeeperTargets[2]=nil;self.ReturningGuardians[2]={};run(1)
check(prepares[2]==before and writes2==0 and pivots2==0,'a returning keeper is left alone')
self.ReturningGuardians[2]=nil;quiet()
check(prepares[2]==before+1,'back from a chase -> full prepare')
check(keepers[2]:GetAttribute('GuardianBehavior')=='GUARDING'and(keepers[2]:GetPivot().Position-homes[2].Position).Magnitude<1e-6,'and it guards from home again')
-- 6. Connections are released.
local idle=self.IdleKeepers[4];self.KeeperTargets[4]={};quiet()
local m=idle.Model;idle.Dirty=false;hat=R.new('Part');hat.Parent=m
check(idle.Dirty==false,'old part listeners disconnected when a record is dropped')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
