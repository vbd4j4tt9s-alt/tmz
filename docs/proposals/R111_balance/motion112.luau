--!nocheck
-- Dampener removal check. Runs the REAL RunnerMotion (client maths: AtPosition/Step/BoundaryStep, as RunnerController
-- uses them), the REAL server MovementGuard.Check (sampled every 0.1 s like its Heartbeat loop) and the REAL
-- BaseService:_stabilizeHorizontalVelocity on the same simulated runner, with the new ratio (1) and the old one (.4).
-- Legit movement must never be corrected; over-speed movement must be. Build: see run_all.sh.
local R=require('./roblox')
local SRC=require('./motion_src')
local simTime=0
local players={}
local RS=R.new('Folder');RS.Name='ReplicatedStorage'
local CC=R.new('Folder');CC.Name='ChestChaseServer'
local heartbeat=R.signal()
local game={GetService=function(_,s)
 if s=='ReplicatedStorage'then return RS end
 if s=='Players'then return {GetPlayers=function()return players end}end
 if s=='RunService'then return {IsStudio=function()return false end,Heartbeat=heartbeat,IsRunning=function()return true end}end
 error('service '..s)
end}
local workspace={Gravity=196.2,StreamingEnabled=false,FindFirstChild=function()return nil end}
local STUB={OwnerTestState82={MovementGranted=function()return false end},OwnerCommandAccess={IsAllowed=function()return false end}}
for _,n in ipairs({'RunnerMotion','RunnerSweep'})do local m=R.new('ModuleScript');m.Name=n;m.Parent=RS end
for _,n in ipairs({'MovementGuard','BaseService','SecurityGate','OwnerTestState82','OwnerCommandAccess'})do local m=R.new('ModuleScript');m.Name=n;m.Parent=CC end
local loaded={}
local base=getfenv(1)
local function req(m,sourceName)
 if loaded[m]~=nil then return loaded[m]end
 local name=sourceName or m.Name
 if STUB[name]then loaded[m]=STUB[name];return STUB[name]end
 local f=assert(loadstring(assert(SRC[name],'no source '..name),name))
 setfenv(f,setmetatable({script=m,require=req,game=game,workspace=workspace,Vector3=R.Vector3,CFrame=R.CFrame,typeof=R.typeof,Enum=R.Enum,
  RaycastParams={new=function()return {}end},os={clock=function()return simTime end,time=os.time}},{__index=base}))
 local r=f();loaded[m]=r;return r
end
local Motion=req(RS.RunnerMotion)
local MG=req(CC.MovementGuard)
local BS=req(CC.BaseService)
RS.RunnerMotion:SetAttribute('TrackBoundaryZ',-100)   -- MapService:146 sets these from BaseBoundaryLine
RS.RunnerMotion:SetAttribute('TrackCenterX',0)
RS.RunnerMotion:SetAttribute('TrackHalfWidth',114)
-- One runner.
local player=R.new('Player');players[1]=player
local char=R.new('Model');local hum=R.new('Humanoid');hum.Parent=char;local root=R.new('Part');root.Name='HumanoidRootPart';root.Parent=char
hum.Health=100;hum.UseJumpPower=true;hum.JumpPower=50;hum.Sit=false;hum.PlatformStand=false;hum.WalkSpeed=16
root.AssemblyLinearVelocity=R.Vector3.zero;root.Anchored=false
player.Character=char
local earned=24
MG.Started=true;MG.Config={GetPlayerWalkSpeed=function()return earned end}
MG.Data={IsLoaded=function()return true end,GetOrCreateSpeedValue=function()return {Value='0'}end}
MG.Bases={TrainingSessions={}}
local bases=setmetatable({Config={GetPlayerWalkSpeed=function()return earned end,MaxHorizontalVelocityMultiplier=1.15},
 PlayerData={GetOrCreateSpeedValue=function()return {Value='0'}end}},{__index=BS})
local V=R.Vector3.new
-- legs: {direction, seconds}. cheat: client speed multiplier that ignores the ceiling (nil = legit client).
local function run(start,legs,cheat)
 local pos,vel=start,R.Vector3.zero
 root.CFrame=R.CFrame.new(pos);player:SetAttribute('PhysicalWalkSpeed',earned)
 MG.Records[player]=nil;simTime=0;MG.Check(player)   -- first sample creates the record
 simTime+=.3;MG.Check(player)                          -- past the reset grace
 local corrections0=MG.Corrections or 0;local clamps,wsMismatch,maxSpeed,samples=0,0,0,0
 local dt,acc=1/60,0;local history={}
 for _,leg in ipairs(legs)do
  local input=leg[1].Unit
  for _=1,math.floor(leg[2]/dt+.5)do
   simTime+=dt
   local cap=Motion.AtPosition(player:GetAttribute('PhysicalWalkSpeed'),pos)          -- RunnerController cap()
   local nextVel=Motion.Step(vel,input,cap,dt,true)
   nextVel=Motion.BoundaryStep(nextVel,pos,player:GetAttribute('PhysicalWalkSpeed'),dt)
   if cheat then nextVel=input*earned*cheat end
   vel=nextVel;pos=pos+vel*dt;maxSpeed=math.max(maxSpeed,vel.Magnitude)
   table.insert(history,pos);if #history>8 then table.remove(history,1)end
   acc+=dt
   if acc>=.1 then acc=0;samples+=1
    -- the server sees a slightly stale position (0-3 frames of replication jitter)
    local seen=history[math.max(1,#history-math.random(0,3))]
    root.CFrame=R.CFrame.new(seen);root.AssemblyLinearVelocity=vel
    local before=MG.Corrections or 0
    MG.Check(player)
    if (MG.Corrections or 0)>before then pos=MG.Records[player].Frame.Position;vel=R.Vector3.zero;history={}end
    bases:_stabilizeHorizontalVelocity(player,root,hum)
    if root.AssemblyLinearVelocity~=vel then clamps+=1 end
    if math.abs(hum.WalkSpeed-Motion.AtPosition(earned,seen))>1e-9 then wsMismatch+=1 end
   end
  end
 end
 return (MG.Corrections or 0)-corrections0,clamps,wsMismatch,maxSpeed,samples
end
local scenarios={
 {'base only (square, never on track)',V(0,3,-2500),{{V(1,0,0),1},{V(0,0,-1),1},{V(-1,0,0),1},{V(0,0,1),1},{V(1,0,-1),1}}},
 {'base -> track -> base',V(0,3,-130),{{V(0,0,1),3},{V(0,0,-1),3}}},
 {'diagonal crossings of the line',V(-40,3,-115),{{V(1,0,1),1.5},{V(-1,0,-1),1.5},{V(1,0,1),1}}},
 {'on track only',V(0,3,200),{{V(0,0,1),2},{V(1,0,0),.5},{V(0,0,-1),2}}},
}
math.randomseed(97)
print('ratio | speed | scenario                              | corrections | server clamps | WalkSpeed!=client cap | top client speed')
for _,ratio in ipairs({1,.4})do
 Motion.BaseAreaRatio=ratio
 for _,speed in ipairs({24,35,88,226,363,500})do
  earned=speed
  for _,sc in ipairs(scenarios)do
   local c,cl,ws,top=run(sc[2],sc[3])
   print(string.format('%5s | %5d | %-37s | %11d | %13d | %21d | %.1f',ratio,speed,sc[1],c,cl,ws,top))
  end
 end
end
-- Over-speed clients (ignore the ceiling): must be corrected, in the base and on the track.
print('\nOver-speed clients (x = multiple of earned speed, ignoring the ceiling):')
for _,ratio in ipairs({1,.4})do
 Motion.BaseAreaRatio=ratio
 for _,speed in ipairs({24,363})do
  earned=speed
  for _,cheat in ipairs({1,1.3,2})do
   local c1=run(V(0,3,-2500),{{V(1,0,0),3}},cheat)
   local c2=run(V(0,3,200),{{V(0,0,1),3}},cheat)
   print(string.format('ratio %-3s speed %3d client x%.1f: corrections in base %2d, on track %2d',ratio,speed,cheat,c1,c2))
  end
 end
end
