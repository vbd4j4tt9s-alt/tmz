--!nocheck
-- R153 client bug review, finding 6: a trampoline launch seen late is not pulled back by MovementGuard, and nothing else is relaxed. The REAL MovementGuard + RunnerMotion +
-- RunnerSweep + HubTrampolineRules153 on the Roblox mock (the R130 micro test's setup), with the trampoline folder the server builds (a model with CenterX / CenterZ and a collider).
-- The bounce sets 108.5 studs/s upward (30 studs). The rise over a window t is 108.5 t - 98.1 t^2: 9.9 studs at 0.1 s, 23.7 at 0.30 s, 26.0 at 0.35 s; the guard allows about
-- 25.5 studs per 0.1 s check. A phone whose position updates bunch up hands the server the first check still on the mat and the next one 26 studs up.
--  1. a bounce sampled every 0.1 s is never corrected (as before);
--  2. the hitch: still on the mat, then 0.35 s into the flight in one check: accepted, the player stays up; the rest of the flight is accepted too;
--  3. the same rise anywhere else (away from a trampoline, beside the collider, over it with no collider built) is still corrected, and so is a rise above what the bounce can reach;
--  4. the allowance is once per debounce window: a second launch inside the 0.45 s cooldown is corrected, a later one is accepted;
--  5. it opens no fly or speed exploit: a rise with a sideways jump is corrected, the bounce height (the Studio attribute) moves the cap and nothing else;
--  6. the pure rule (HubTrampolineRules153.LaunchRise) on its own.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local SSS=W.service('ServerScriptService');local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local function serverStub(name,value)W.stub(name,value);local m=R.new('ModuleScript');m.Name=name;m._stubbed=true;m.Parent=folder;return m end
serverStub('SecurityGate',{Finite=function(x)return x==x and x~=math.huge and x~=-math.huge end})
serverStub('OwnerTestState82',{MovementGranted=function()return false end});serverStub('OwnerCommandAccess',{IsAllowed=function()return false end})
local G=R.new('ModuleScript');G.Name='MovementGuard';G._source='MovementGuard';G.Parent=folder
local T=W.module('HubTrampolineRules153')
local GRAV=196.2;W.workspace.Gravity=GRAV
-- the map the server builds: ChestChaseMap.HubTrampolines153 with a model per nook (CenterX / CenterZ) and its collider
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local runtime=R.new('Folder');runtime.Name='Runtime';runtime.Parent=mapRoot
local tramps=R.new('Folder');tramps.Name=T.FolderName;tramps.Parent=mapRoot
local colliders={}
for _,spot in ipairs(T.Spots)do
 local m=R.new('Model');m.Name='Trampoline '..spot.Name;m:SetAttribute('CenterX',spot.X);m:SetAttribute('CenterZ',spot.Z);m.Parent=tramps
 local c=R.new('Part');c.Name='Trampoline collider';c.Size=V3(T.Dims.Radius*2,T.Top()-(T.Floor-.1),T.Dims.Radius*2);c.CFrame=CF(spot.X,(T.Top()+T.Floor-.1)/2,spot.Z);c.Parent=m;colliders[spot.Name]=c
end
local Guard=W.require(G)
Guard.Config={GetPlayerWalkSpeed=function(_,v)return v end};Guard.Data={GetOrCreateSpeedValue=function()return {Value=60}end,IsLoaded=function()return true end};Guard.Started=true
Guard.Bases={TrainingSessions={},Map={MapRoot=mapRoot,RuntimeFolder=runtime}}
local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.UserId=4;player.Parent=Players
local char=R.new('Model');char.Name='P';local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.JumpPower=50;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,5,0);hrp.CollisionGroup='Players';hrp.Anchored=false;hrp.Parent=char
char.CFrame=hrp.CFrame;char.Parent=W.workspace;player.Character=char
local FEET=3 -- root half height 1 + hip height 2
local Top=T.Top();local D=T.Dims;local X0,Z0=T.Spots[1].X,T.Spots[1].Z
local function put(x,feet,z)hrp.CFrame=CF(x,feet+FEET,z);char.CFrame=hrp.CFrame end
local function pos()return char.CFrame.Position end -- (where the guard leaves the character: it moves the model)
-- a fresh record: the player stands at (x, feet, z), the guard has seen it and its grace is over
local function start(x,feet,z)put(x,feet,z);Guard.Reset(player,0);R.advance(.3);Guard.Check(player) end
local function check1(x,feet,z,dt)put(x,feet,z);R.advance(dt or .1);return Guard.Check(player)end
local function corrections()return Guard.Corrections or 0 end
local v=T.Velocity(GRAV)
local function flight(t)return math.max(0,v*t-.5*GRAV*t*t)end -- the feet over the mat t seconds after the launch
check(math.abs(flight(.1)-9.9)<.2 and math.abs(flight(.35)-26)<.5 and T.Height()==30,'the numbers of the review: 9.9 studs at 0.1 s, 26 at 0.35 s, a 30-stud bounce ('..string.format('%.1f / %.1f',flight(.1),flight(.35))..')')

-- 1. an ordinary bounce, sampled every 0.1 s, is never corrected ---------------------------------------------------------------------------------------
do
 start(X0,Top,Z0);local before=corrections();local worst=0
 for k=1,12 do local t=k*.1;local ok=check1(X0,Top+flight(t),Z0);if not ok then worst=worst+1 end end
 check(worst==0 and corrections()==before,'a bounce sampled every 0.1 s is never corrected ('..worst..' refused)')
end
-- 2. the hitch: still on the mat, then 0.35 s into the flight in one check --------------------------------------------------------------------------------
do
 start(X0,Top,Z0);local before=corrections()
 for _=1,3 do check1(X0,Top,Z0)end -- (the position updates have not arrived: the mat, three checks)
 local ok=check1(X0,Top+flight(.35),Z0)
 check(ok and corrections()==before,'the hitch: still on the mat for 0.3 s, then 26 studs up in one 0.1 s check: accepted, not put back ('..tostring(ok)..', '..(corrections()-before)..' corrections)')
 check(pos().Y>Top+FEET+20,'... the player stays up in the air ('..string.format('%.1f',pos().Y)..')')
 local refused=0;for k=4,11 do if not check1(X0,Top+flight(.35+(k-3)*.1),Z0)then refused+=1 end end
 check(refused==0 and corrections()==before,'... and the rest of the flight is accepted too ('..refused..' refused)')
end
-- 3. the same rise anywhere else is still caught -------------------------------------------------------------------------------------------------------
local function hitchAt(x,feet,z,rise)
 start(x,feet,z);for _=1,3 do check1(x,feet,z)end
 local before=corrections();local ok=check1(x,feet+rise,z);return ok,corrections()-before
end
do
 local ok,n=hitchAt(100,Top,-100,flight(.35))
 check(ok==false and n==1,'the same 26-stud rise far from any trampoline is corrected ('..tostring(ok)..', '..n..')')
 check(pos().Y<Top+FEET+1,'... and the player is put back where the last frame was ('..string.format('%.1f',pos().Y)..')')
 ok,n=hitchAt(X0+D.Radius+.8,Top,Z0,flight(.35)) -- (beside the collider: 6.85 from the centre, the collider reaches 6.05, the rule 6.25)
 check(ok==false and n==1,'... beside the collider (0.8 stud off its edge) it is corrected too ('..tostring(ok)..', '..n..')')
 ok,n=hitchAt(X0,Top,Z0,40)
 check(ok==false and n==1,'over the mat but higher than the bounce can lift (the feet 40 studs up; the apex is at '..string.format('%.1f',Top+.35+T.Height())..') is corrected ('..tostring(ok)..', '..n..')')
 ok,n=hitchAt(X0,Top,Z0,T.Height()+T.GuardMargin-1) -- (just under the cap: a 35-stud rise)
 check(ok==true and n==0,'... while 35 studs (apex plus a margin) is accepted ('..tostring(ok)..', '..n..')')
 -- no collider built (the server has none: the folder is gone, or the model has no collider): nothing is allowed
 local c=colliders.Desert;c.Parent=nil
 ok,n=hitchAt(X0,Top,Z0,flight(.35))
 check(ok==false and n==1,'a trampoline model without its collider allows nothing ('..tostring(ok)..', '..n..')')
 c.Parent=tramps:FindFirstChild('Trampoline Desert')
 tramps.Parent=nil
 ok,n=hitchAt(X0,Top,Z0,flight(.35))
 check(ok==false and n==1,'... and neither does a map with no trampoline folder at all ('..tostring(ok)..', '..n..')')
 tramps.Parent=mapRoot
 -- a rise from the floor of a dark gap under the mat is not a launch either (below the floor)
 ok,n=hitchAt(X0,T.Floor-3,Z0,flight(.35)+3)
 check(ok==false and n==1,'... nor a rise that starts under the floor ('..tostring(ok)..', '..n..')')
 -- the rise by itself: the very same on the mat is fine again
 ok,n=hitchAt(X0,Top,Z0,flight(.35))
 check(ok==true and n==0,'(control: the same hitch on the mat is accepted again ('..tostring(ok)..', '..n..'))')
 -- the Lava nook's mat works too
 ok,n=hitchAt(T.Spots[2].X+2,Top,T.Spots[2].Z-2,flight(.35))
 check(ok==true and n==0,'the second nook\'s trampoline allows it too ('..tostring(ok)..', '..n..')')
end
-- 4. once per debounce window ---------------------------------------------------------------------------------------------------------------------------
do
 start(X0,Top,Z0);for _=1,2 do check1(X0,Top,Z0)end
 local before=corrections();local first=check1(X0,Top+flight(.35),Z0)
 local back=check1(X0,Top,Z0) -- (down onto the mat again: falling needs no allowance)
 local second=check1(X0,Top+flight(.35),Z0) -- (0.2 s after the first allowed launch: inside the 0.45 s cooldown)
 check(first and back and second==false and corrections()==before+1,'a second launch inside the cooldown (0.2 s after the first) is corrected ('..tostring(first)..', '..tostring(back)..', '..tostring(second)..', '..(corrections()-before)..' corrections)')
 R.advance(.7);Guard.Check(player) -- (grace after the correction, then a fresh frame on the mat)
 put(X0,Top,Z0);R.advance(.1);Guard.Check(player)
 local later=check1(X0,Top+flight(.35),Z0)
 check(later,'... and one 0.9 s after the first is accepted (the cooldown has passed) ('..tostring(later)..')')
end
-- 5. no fly or speed exploit ---------------------------------------------------------------------------------------------------------------------------
do
 -- a launch together with a sideways jump of 100 studs: the sideways distance is still checked
 start(X0,Top,Z0);for _=1,3 do check1(X0,Top,Z0)end
 local before=corrections();local ok=check1(X0+100,Top+flight(.35),Z0)
 check(ok==false and corrections()==before+1,'a launch with a 100-stud sideways jump in the same check is corrected ('..tostring(ok)..')')
 -- climbing in 20-stud steps (a fly hack that stays inside the old allowance) is not helped by the mat: each check is the old rule, the launch is allowed once
 start(X0,Top,Z0);before=corrections();local steps=0;local feet=Top
 for _=1,6 do feet+=20;if check1(X0,feet,Z0)then steps+=1 end end
 check(steps==6 and corrections()==before,'(the old allowance is unchanged: 20 studs per check is accepted as it always was)')
 -- 30 studs per check, again and again, over the mat: the first is a launch, the next ones are not
 start(X0,Top,Z0);before=corrections();local accepted=0;feet=Top
 for _=1,4 do feet+=30;if check1(X0,feet,Z0)then accepted+=1 else break end end
 check(accepted<=1 and corrections()==before+1,'climbing 30 studs a check over the mat is allowed once, then corrected ('..accepted..' accepted)')
 -- the same climb far from the mat is corrected at once
 start(100,Top,-100);before=corrections();local first=check1(100,Top+30,-100)
 check(first==false and corrections()==before+1,'... and away from it at the first step')
 -- the bounce height (the Studio attribute, 12 - 40) moves the cap and nothing else
 local rules=W.RS:FindFirstChild('HubTrampolineRules153')
 rules:SetAttribute('BounceHeight',40)
 check(T.Height()==40,'(BounceHeight 40: the rules say '..T.Height()..')')
 start(X0,Top,Z0);for _=1,3 do check1(X0,Top,Z0)end
 local v40=T.Velocity(GRAV);local rise40=v40*.3-.5*GRAV*.09
 before=corrections();local ok40=check1(X0,Top+rise40,Z0)
 check(ok40 and corrections()==before,string.format('BounceHeight 40: a 0.3 s hitch (%.1f studs up in one check) is accepted',rise40))
 ok40=select(1,hitchAt(X0,Top,Z0,50))
 check(ok40==false,'BounceHeight 40: 50 studs is above the new cap ('..(Top+.35+40+T.GuardMargin)..' for the feet) and is corrected')
 rules:SetAttribute('BounceHeight',nil)
 check(T.Height()==30,'(BounceHeight back to the default 30)')
 -- a body standing on the mat and not rising at all, a body falling: nothing to allow, nothing breaks
 start(X0,Top,Z0);before=corrections()
 local still=check1(X0,Top,Z0);local fall=check1(X0,Top-0.5,Z0)
 check(still and fall and corrections()==before,'standing on the mat is accepted as always')
end
-- 6. the pure rule --------------------------------------------------------------------------------------------------------------------------------------
do
 local spots={{X=312,Z=-269}}
 local cap=Top+.35+T.Height()+T.GuardMargin
 check(T.LaunchRise(spots,312,-269,Top,Top+26,.1,math.huge)==true,'LaunchRise: on the mat, 26 up, 0.1 s, no earlier launch: yes')
 check(T.LaunchRise(spots,312,-269,Top+4,Top+26,.1,math.huge)==true,'... over the mat (4 studs above it): yes')
 check(T.LaunchRise(spots,312+7,-269,Top,Top+26,.1,math.huge)==false,'... 7 studs off the centre (the collider reaches 6.05): no')
 check(T.LaunchRise(spots,312,-269,Top,cap+.1,.1,math.huge)==false and T.LaunchRise(spots,312,-269,Top,cap-.1,.1,math.huge)==true,'... above the cap '..string.format('%.2f',cap)..': no; just under it: yes')
 check(T.LaunchRise(spots,312,-269,Top,Top+26,T.GuardWindow+.01,math.huge)==false and T.LaunchRise(spots,312,-269,Top,Top+26,T.GuardWindow-.01,math.huge)==true,'... the last frame older than the debounce window ('..string.format('%.2f',T.GuardWindow)..' s): no')
 check(T.LaunchRise(spots,312,-269,Top,Top+26,.1,T.Cooldown-.01)==false and T.LaunchRise(spots,312,-269,Top,Top+26,.1,T.Cooldown)==true,'... a launch allowed less than the cooldown ago: no')
 check(T.LaunchRise({},312,-269,Top,Top+26,.1,math.huge)==false,'... no trampoline at all: no')
 check(T.LaunchRise(spots,312,-269,T.Floor-1,T.Floor+25,.1,math.huge)==false,'... starting under the floor: no')
 check(T.GuardMargin>0 and T.GuardMargin<=10 and T.GuardWindow<=T.Cooldown+.2,'the margin ('..T.GuardMargin..' studs) and the window ('..T.GuardWindow..' s) are small')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
