--!nocheck
-- R130 performance: MovementGuard reuses one RaycastParams (it made a new one 10 times a second per moving player).
-- Real MovementGuard + RunnerMotion + RunnerSweep on the Roblox mock: the barrier list is still read on every check,
-- so the refresh wall blocks from the first check after it appears, and a runner is still stopped at a wall.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local SSS=W.service('ServerScriptService');local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
local function serverStub(name,value)W.stub(name,value);local m=R.new('ModuleScript');m.Name=name;m._stubbed=true;m.Parent=folder;return m end
serverStub('SecurityGate',{Finite=function(x)return x==x and x~=math.huge and x~=-math.huge end})
serverStub('OwnerTestState82',{MovementGranted=function()return false end});serverStub('OwnerCommandAccess',{IsAllowed=function()return false end})
local G=R.new('ModuleScript');G.Name='MovementGuard';G._source='MovementGuard';G.Parent=folder
-- RaycastParams that count filter rewrites.
local made,filterWrites=0,0
W.env.RaycastParams={new=function()made+=1;local store={}
 return setmetatable({},{__index=store,__newindex=function(_,k,v)if k=='FilterDescendantsInstances'then filterWrites+=1 end;store[k]=v end})end}
-- Map: barrier folders; Blockcast hits any wall part listed in the filter that lies across the path.
local mapRoot=R.new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=W.workspace
local runtime=R.new('Folder');runtime.Name='Runtime';runtime.Parent=mapRoot
local walls=R.new('Folder');walls.Name='InvisibleMapBarriersV071';walls.Parent=mapRoot
local wall=R.new('Part');wall.Name='Wall';wall.CFrame=CF(0,5,40);wall.Parent=walls
local casts={}
function W.workspace.Blockcast(_,at,size,direction,params)
 casts[#casts+1]=params
 for _,root in ipairs(params.FilterDescendantsInstances or{})do for _,p in ipairs(root:GetDescendants())do if p:IsA('Part')then
  local z=p.CFrame.Position.Z;local from=at.Position.Z;local to=from+direction.Z
  if (z-from)*(z-to)<=0 and direction.Z~=0 then return {Distance=math.abs(z-from),Instance=p,Normal=V3(0,0,-1),Position=V3(at.Position.X,at.Position.Y,z)}end
 end end end
 return nil
end
local Guard=W.require(G)
Guard.Config={GetPlayerWalkSpeed=function(_,v)return v end};Guard.Data={GetOrCreateSpeedValue=function()return {Value=60}end,IsLoaded=function()return true end};Guard.Started=true
Guard.Bases={TrainingSessions={},Map={MapRoot=mapRoot,RuntimeFolder=runtime}}
local Players=W.service('Players');local player=R.new('Player');player.Name='P';player.UserId=4;player.Parent=Players
local char=R.new('Model');char.Name='P';local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.JumpPower=50;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=CF(0,5,0);hrp.CollisionGroup='Players';hrp.Anchored=false;hrp.Parent=char
char.CFrame=hrp.CFrame;char.Parent=W.workspace;player.Character=char
Guard.Reset(player,0);R.advance(.3)
local z=0
local function walk(dz)z+=dz;hrp.CFrame=CF(0,5,z);char.CFrame=hrp.CFrame;R.advance(.1);return Guard.Check(player)end
-- 1. Twenty checks while walking: one RaycastParams, filter written once.
for _=1,20 do walk(1.5)end
check(#casts>=20,'every check sweeps the barriers ('..#casts..')')
check(made==1,'one RaycastParams for all checks ('..made..')')
check(filterWrites==2,'filter set up once and written once while the barrier list stays the same ('..filterWrites..')')
local first=casts[1];local same=true;for _,p in ipairs(casts)do if p~=first then same=false end end
check(same,'the same params object every time')
check(first.FilterType==R.Enum.RaycastFilterType.Include and first.RespectCanCollide==true and first.CollisionGroup=='Players','same filter settings as before')
-- 2. The refresh wall appears: used from the very next check.
local gate=R.new('Model');gate.Name='BiomeRefreshWall';gate.Parent=runtime
casts={};walk(1.5)
local list=casts[#casts].FilterDescendantsInstances;local hasGate=false;for _,x in ipairs(list)do if x==gate then hasGate=true end end
check(hasGate and filterWrites==3,'refresh wall in the filter on the first check after it appears')
gate:Destroy();casts={};walk(1.5)
list=casts[#casts].FilterDescendantsInstances;check(#list==1 and filterWrites==4,'and out again when it is removed')
-- 3. Still blocked at a wall: try to run through the barrier at z=40.
z=36;hrp.CFrame=CF(0,5,z);Guard.Reset(player,0);R.advance(.3);local before=Guard.Corrections or 0
check(walk(5)==false and(Guard.Corrections or 0)==before+1,'running through the wall is corrected')
check(char.CFrame.Position.Z<40 and char.CFrame.Position.Z>39,('runner put back in front of the wall (z %.2f)'):format(char.CFrame.Position.Z))
-- 4. The collision group follows the runner.
hrp.CollisionGroup='Runners';z=20;hrp.CFrame=CF(0,5,z);char.CFrame=hrp.CFrame;Guard.Reset(player,0);R.advance(.3)
casts={};walk(1.5);check(casts[#casts]and casts[#casts].CollisionGroup=='Runners','collision group follows the runner')
check(made==1,'still one RaycastParams ('..made..')')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
