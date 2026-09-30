--!nocheck
-- R113 BASE/TRACK travel: client buttons -> remote -> FastTravelService checks -> teleport, plus MovementGuard.
-- Bundle (from a scratch folder):
--   python3 <repo>/tools/tests/bundle.py tp_bundle.luau \
--     FastTravelService=<src>/ServerScriptService/ChestChaseServer/FastTravelService.lua \
--     MovementGuard=<src>/ServerScriptService/ChestChaseServer/MovementGuard.lua \
--     SecurityGate=<src>/ServerScriptService/ChestChaseServer/SecurityGate.lua \
--     HudLayout=<src>/ReplicatedStorage/HudLayout.lua VectorIcons91=<src>/ReplicatedStorage/VectorIcons91.lua \
--     TravelButtons=<src>/StarterPlayer/StarterPlayerScripts/TravelButtons.client.lua
local R=require('./roblox');local B=require('./tp_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-3)end
-- World ---------------------------------------------------------------------------
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace')
local camera=new('Camera');camera.ViewportSize=R.Vector2.new(1280,720);camera.Parent=workspace;workspace.CurrentCamera=camera
local rays={}
function workspace.Raycast(_,origin,dir)rays[#rays+1]={origin,dir};if origin.Y>4 and origin.Y+dir.Y<=4 then return {Position=V3(origin.X,4,origin.Z),Normal=V3(0,1,0)}end;return nil end
function workspace.GetServerTimeNow()return 1000+R.clock end
local Run=service('RunService');Run.RenderStepped=R.signal();Run.Heartbeat=R.signal();Run.IsStudio=function()return false end
local UIS=service('UserInputService');UIS.TouchEnabled=false
local Gui=service('GuiService');Gui.ReducedMotionEnabled=false
local Players=service('Players');local RS=service('ReplicatedStorage');local SSS=service('ServerScriptService')
local player=new('Player');player.Name='Runner';player.UserId=1;player.Parent=Players
function Players.GetPlayers()return {player}end;Players.LocalPlayer=player
local pg=new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
-- Character: PivotTo moves the root, as in Roblox.
local character=new('Model');character.Name='Runner';character.Parent=workspace
local humanoid=new('Humanoid');humanoid.Health=100;humanoid.PlatformStand=false;humanoid.UseJumpPower=true;humanoid.JumpPower=50;humanoid.Parent=character
local root=new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(40,7,300);root.Anchored=false;root.Size=V3(2,2,1);root.Parent=character
rawset(character,'PivotTo',function(_,c)root.CFrame=c end);rawset(character,'GetPivot',function()return root.CFrame end)
player.Character=character
-- Remotes and ScreenGuis behave enough like Roblox for this flow.
local rawNew=R.Instance.new
R.Instance.new=function(class,parent)
 local o=rawNew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireServer=function(self,...)self.OnServerEvent:Fire(player,...)end end
 if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(1280,720)end
 return o
end
-- Modules --------------------------------------------------------------------------
local modules={}
local env
local function load(name,scriptInst)local fn=assert(loadstring(B[name],'='..name));setfenv(fn,setmetatable({script=scriptInst},{__index=env}));return fn()end
local function req(m)if modules[m]~=nil then return modules[m]end;if m._source then modules[m]=load(m._source,m);return modules[m]end;error('unknown module '..tostring(m))end
local function module(parent,name,value,source)local m=new('ModuleScript');m.Name=name;m.Parent=parent;if source then m._source=source else modules[m]=value end;return m end
local folder=new('Folder');folder.Name='ChestChaseServer';folder.Parent=SSS
for _,n in ipairs({'FastTravelService','MovementGuard','SecurityGate'})do module(folder,n,nil,n)end
module(folder,'OwnerTestState82',{MovementGranted=function()return false end})
module(folder,'OwnerCommandAccess',{IsAllowed=function()return false end})
local motion=module(RS,'RunnerMotion',{Allowance=function(s,e)return s*e end,Burst=function()return 12 end,AtPosition=function(s)return s end,
 Flat=function(v)return V3(v.X,0,v.Z)end,TravelAllowance=function(s,_,_,e)return s*e*1.2,s end})
motion:SetAttribute('TrackBoundaryZ',-99.28);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114)
module(RS,'RunnerSweep',{Hull=function()return V3(2,5,1),V3()end,Cast=function(_,_,_,o)return o.Magnitude,false end})
module(RS,'HudLayout',nil,'HudLayout');module(RS,'VectorIcons91',nil,'VectorIcons91')
module(RS,'GardenTextFit',{Attach=function()end})
local brightButtons={}
module(RS,'BrightUI',{Button=function(b,c)brightButtons[#brightButtons+1]=b;b.BackgroundColor3=c end,Text=function(l,s)l.TextSize=s end})
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,Color3=R.Color3,Enum=R.Enum,
 RaycastParams={new=function()return {}end},typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end,time=os.time},utf8=utf8,warn=function(...)print('WARN',...)end},{__index=_G})
-- Server ---------------------------------------------------------------------------------
local line=new('Part');line.Name='BaseBoundaryLine';line.CFrame=CF(0,4.12,-99.28);line.Size=V3(180,.24,1)
local mapRoot=new('Folder');mapRoot.Name='ChestChaseMap';mapRoot.Parent=workspace
local notes={}
local busy,opening=false,false
local base={Index=3,Spawn={CFrame=CF(-168,5.55,-358)}}
local Bases={TrainingSessions={},GetPlayerBase=function()return base end,Map={MapRoot=mapRoot}}
local Chase={IsPlayerBusy=function()return busy end,Chests={IsOpening=function()return opening end}}
local Map={BaseBoundaryLine=line,MapRoot=mapRoot,Refreshing=false}
local Config={FastTravelCooldown=4,BiomeTrackStartZ=-100,RemoteFolderName='ChestChaseRemotes',GetPlayerWalkSpeed=function()return 40 end}
local speedValue={Value=0}
local Data={IsLoaded=function()return true end,GetOrCreateSpeedValue=function()return speedValue end}
local Guard=req(folder.MovementGuard);Guard.Start(Config,Data,Bases)
local FT=req(folder.FastTravelService)
local service_=FT.new(Config,Map,Bases,Chase,{Show=function(_,p,msg)notes[#notes+1]=msg end})
service_:Start()
local remotes=RS:FindFirstChild('ChestChaseRemotes')
check(remotes and remotes:FindFirstChild('RequestBaseTeleport')and remotes:FindFirstChild('RequestTrackTeleport'),'both remotes exist')
-- Client ---------------------------------------------------------------------------------
local clientScript=new('LocalScript');clientScript.Name='TravelButtons'
load('TravelButtons',clientScript)
local gui=pg:FindFirstChild('TravelButtons');check(gui~=nil,'gui created')
local pair=gui and gui:FindFirstChild('TravelPair')
local baseButton=pair and pair:FindFirstChild('BaseButton');local trackButton=pair and pair:FindFirstChild('TrackButton')
check(baseButton and trackButton,'both buttons exist')
check(#brightButtons==2,'both styled with BrightUI.Button')
check(baseButton:FindFirstChild('Icon'):FindFirstChild('InstantIcon')~=nil and trackButton:FindFirstChild('Icon'):FindFirstChild('InstantIcon')~=nil,'vector icons drawn')
check(baseButton:FindFirstChild('Icon').InstantIcon:GetAttribute('VectorIcon91')=='Home','BASE icon is Home')
check(trackButton:FindFirstChild('Icon').InstantIcon:GetAttribute('VectorIcon91')=='Track','TRACK icon is Track')
-- R113b: rectangles centred in Roblox's top bar row (TopbarSafeInsets); only the title and full-screen menus hide them.
check(gui.ScreenInsets==R.Enum.ScreenInsets.TopbarSafeInsets,'pair lives in the top bar row')
local function frames(n)for _=1,n or 2 do R.advance(.02);if Run.Heartbeat then Run.Heartbeat:Fire(.02)end end end
gui.AbsoluteSize=R.Vector2.new(900,58);frames()
check(pair.Visible==true,'pair visible')
check(pair.AnchorPoint.X==.5 and pair.AnchorPoint.Y==.5 and pair.Position.X.Scale==.5 and pair.Position.Y.Scale==.5 and pair.Position.X.Offset==0,'pair centred')
check(baseButton.Size.X.Offset>baseButton.Size.Y.Offset*2,'BASE is a wide rectangle')
check(baseButton.Size.Y.Offset<=58-8 and baseButton.Size.Y.Offset>=30,'fits the top bar height')
check(trackButton.Position.X.Offset==baseButton.Size.X.Offset+8,'TRACK beside BASE')
check(pair.Size.X.Offset<=900,'pair fits the free top bar width')
gui.AbsoluteSize=R.Vector2.new(200,40);frames()
check(pair.Size.X.Offset<=200 and baseButton.Size.Y.Offset==32,'narrow phone top bar: pair shrinks to fit')
gui.AbsoluteSize=R.Vector2.new(900,58);frames()
pg:SetAttribute('GardenMenuExpanded',true);check(pair.Visible,'wheel open keeps the top pair');pg:SetAttribute('GardenMenuExpanded',false)
pg:SetAttribute('SeedMenu','Shop');check(not pair.Visible,'modal hides pair');pg:SetAttribute('SeedMenu',nil)
check(pair.Visible,'modal closed shows pair')
pg:SetAttribute('TitleActive',true);check(not pair.Visible,'title hides pair');pg:SetAttribute('TitleActive',nil)
-- TRACK: position and facing ------------------------------------------------------------------
local function tick(dt)R.advance(dt);Run.Heartbeat:Fire(dt);Run.RenderStepped:Fire(dt)end
for _=1,3 do tick(.11)end -- guard has a baseline at (40,7,300)
local serialBefore=player:GetAttribute('MovementResetSerial')or 0
trackButton.Activated:Fire()
local p=root.CFrame.Position
check(near(p.X,0)and near(p.Y,8)and near(p.Z,-99.28+.5+12),'TRACK lands on the line centre, 12 studs past the boundary line (Forest start), on the ground: '..tostring(p))
local look=root.CFrame.LookVector
check(near(look.Z,1)and near(look.X,0),'TRACK faces down the track (+Z)')
check(#rays>0 and rays[#rays][1].Y<=line.Position.Y+8+1e-6,'ground ray starts low (no landing on arches)')
check((player:GetAttribute('MovementResetSerial')or 0)>serialBefore,'MovementGuard reset after teleport')
check(player:GetAttribute('FastTravelReadyAt')~=nil and player:GetAttribute('FastTravelCooldown')==4,'cooldown published')
check(baseButton.Cooldown.Visible and trackButton.Cooldown.Visible,'cooldown shade shown')
-- Anti-cheat stays quiet across the jump.
local corrections=Guard.Corrections or 0
for _=1,10 do tick(.11)end
check((Guard.Corrections or 0)==corrections,'no MovementGuard correction after TRACK teleport')
check(near(root.CFrame.Position.Z,-86.78),'player not pulled back')
-- Cooldown ------------------------------------------------------------------------------------
tick(.3) -- client debounce
local z=root.CFrame.Position.Z
baseButton.Activated:Fire()
check(near(root.CFrame.Position.Z,z),'cooldown refuses BASE')
check(notes[#notes]:match('^TELEPORT READY IN'),'cooldown notice: '..tostring(notes[#notes]))
for _=1,30 do tick(.11)end
check(not baseButton.Cooldown.Visible,'cooldown shade cleared')
-- BASE --------------------------------------------------------------------------------------
baseButton.Activated:Fire()
p=root.CFrame.Position
check(near(p.X,-168)and near(p.Y,9.55)and near(p.Z,-358),'BASE lands 4 studs above own spawn: '..tostring(p))
check(notes[#notes]=='RETURNED TO BASE 3','BASE notice')
for _=1,10 do tick(.11)end
check((Guard.Corrections or 0)==corrections,'no MovementGuard correction after BASE teleport')
-- Control: the same jump without a reset IS corrected (proves the guard is live in this mock).
root.CFrame=CF(0,8,-86.78);for _=1,3 do tick(.11)end
check((Guard.Corrections or 0)>corrections,'control: unexplained jump is corrected')
-- Refusals (server side; the client could fire the remote directly) ------------------------------------
local function refused(setup,undo,remote,expect,label)
 for _=1,40 do tick(.11)end -- past cooldown and guard noise
 local before=root.CFrame.Position;setup()
 remotes[remote]:FireServer()
 check(root.CFrame.Position==before,label..' refused')
 if expect then check(notes[#notes]==expect,label..' notice: '..tostring(notes[#notes]))end
 undo()
end
refused(function()busy=true end,function()busy=false end,'RequestTrackTeleport','FAST TRAVEL IS DISABLED WHILE CARRYING A SEED','carrying (chase busy) / tutorial run home')
refused(function()player:SetAttribute('ChestChaseSeedCarrying',true)end,function()player:SetAttribute('ChestChaseSeedCarrying',nil)end,'RequestBaseTeleport','FAST TRAVEL IS DISABLED WHILE CARRYING A SEED','carrying attribute')
refused(function()player:SetAttribute('GuardianRagdollActive',true)end,function()player:SetAttribute('GuardianRagdollActive',nil)end,'RequestBaseTeleport','WAIT UNTIL YOU CAN MOVE!','ragdoll')
refused(function()player:SetAttribute('GuardianFlingActive',true)end,function()player:SetAttribute('GuardianFlingActive',nil)end,'RequestTrackTeleport','WAIT UNTIL YOU CAN MOVE!','fling')
refused(function()Bases.TrainingSessions[player]={}end,function()Bases.TrainingSessions[player]=nil end,'RequestBaseTeleport','STEP OFF THE TREADMILL FIRST!','treadmill')
refused(function()opening=true end,function()opening=false end,'RequestBaseTeleport','FINISH OPENING YOUR PACK FIRST!','pack opening')
refused(function()Map.Refreshing=true end,function()Map.Refreshing=false end,'RequestTrackTeleport','THE TRACK IS REFRESHING!','track refresh')
refused(function()humanoid.Health=0 end,function()humanoid.Health=100 end,'RequestBaseTeleport',nil,'dead')
refused(function()humanoid.SeatPart=root end,function()humanoid.SeatPart=nil end,'RequestTrackTeleport','GET UP FIRST!','seated')
-- BASE during refresh is still fine.
for _=1,40 do tick(.11)end;Map.Refreshing=true;remotes.RequestBaseTeleport:FireServer();Map.Refreshing=false
check(near(root.CFrame.Position.X,-168),'BASE allowed while the track refreshes')
-- Spam is rate limited by SecurityGate before any work.
local gate=req(folder.SecurityGate);local rejected=gate.Rejected
for _=1,30 do remotes.RequestTrackTeleport:FireServer()end
check(gate.Rejected>rejected,'SecurityGate limits remote spam')
service_:CleanupPlayer(player);check(service_.LastTravelTime[player]==nil,'cleanup on leave')
gui:Destroy()
print(('%d checks, %s'):format(checks,fails==0 and'ALL PASS'or(fails..' FAILURES')))
