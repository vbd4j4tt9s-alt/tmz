--!nocheck
local R=require('./roblox');local B=require('./tut_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
-- World ---------------------------------------------------------------------------
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
local workspace=service('Workspace')
local camera=new('Camera');camera.ViewportSize=R.Vector2.new(1280,720);camera.CFrame=CF(0,20,-30);camera.Parent=workspace;workspace.CurrentCamera=camera
function camera.WorldToViewportPoint(_,p)return V3(640+p.X*4,360-p.Z*2,5),math.abs(p.X)<150 and math.abs(p.Z)<150 end
function workspace.Raycast(_,origin,dir)if origin.Y>0 and origin.Y+dir.Y<=0 then return {Position=V3(origin.X,0,origin.Z),Normal=V3(0,1,0),Instance=workspace}end;return nil end
local moved=0
function workspace.BulkMoveTo(_,parts,cframes)check(#parts==#cframes,'BulkMoveTo sizes match');for i,p in ipairs(parts)do p._props.CFrame=cframes[i];p._props.Position=cframes[i].Position end;moved+=1 end
local Run=service('RunService');Run.RenderStepped=R.signal();Run.Heartbeat=R.signal();Run.Stepped=R.signal();Run.IsStudio=function()return false end
local UIS=service('UserInputService');UIS.TouchEnabled=false;UIS.MouseEnabled=true;UIS.LastInputTypeChanged=R.signal()
local lastInput=R.Enum.UserInputType.MouseMovement;function UIS.GetLastInputType()return lastInput end
local Tween=service('TweenService');function Tween.Create(_,obj,_,props)return {Play=function()for k,v in pairs(props)do obj[k]=v end end,Cancel=function()end,Completed=R.signal()}end
local TextS=service('TextService');function TextS.GetTextSize(_,text,size,_,bounds)local per=math.max(1,math.floor(bounds.X/(size*.55)));return R.Vector2.new(math.min(bounds.X,#text*size*.55),math.ceil(#text/per)*size*1.2)end
local pathCalls=0
local Paths=service('PathfindingService');function Paths.CreatePath()local path={Status=R.Enum.PathStatus.NoPath};local pts
 function path.ComputeAsync(_,a,b)pathCalls+=1;path.Status=R.Enum.PathStatus.Success;local mid=V3((a.X+b.X)/2+10,0,(a.Z+b.Z)/2);pts={a,mid,b}end
 function path.GetWaypoints()local out={};for _,p in ipairs(pts)do out[#out+1]={Position=p}end;return out end
 return path end
local Gui=service('GuiService');Gui.ReducedMotionEnabled=false;function Gui.GetInsetArea()return {Min=R.Vector2.new(0,0),Width=1280,Height=720}end
local Players=service('Players');local RS=service('ReplicatedStorage')
game.CreatorType=R.Enum.CreatorType.User;game.CreatorId=777
function Players.GetUserThumbnailAsync(_,id)return 'rbxthumb://type=AvatarHeadShot&id='..id end
function Players.GetNameFromUserIdAsync(_,id)return id==777 and'OwnerName'or'someone'end

local player=new('Player');player.Name='Tester';player.DisplayName='Alex';player.Parent=Players;Players.LocalPlayer=player
local pg=new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local backpack=new('Backpack');backpack.Name='Backpack';backpack.Parent=player
local character=new('Model');character.Name='Alex';character.Parent=workspace;player.Character=character
local root=new('Part');root.Name='HumanoidRootPart';root.Parent=character;root.CFrame=CF(0,3,0)
-- Remote: returns targets for the current step and records commands.
local remotes=new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local request=new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
local commands={};local serverStep={Kind='Pack',Target=V3(40,3,60)}
function request.InvokeServer(_,action,value)
 check(action=='Tutorial','remote action')
 commands[#commands+1]=value
 local step=player:GetAttribute('TutorialStep')or 0
 if value=='Skip'or value=='TreadmillInfo'then player:SetAttribute('TutorialDone',true);player:SetAttribute('TutorialStep',0);step=0 end
 return {Success=true,Step=step,Kind=serverStep.Kind,Target=serverStep.Target,WaitingForPack=serverStep.Waiting}
end
-- Hotbar the tutorial points at.
local hot=new('ScreenGui');hot.Name='ChestToolHotbar';hot.Parent=pg
local dock=new('Frame');dock.Name='Dock';dock.Parent=hot
for i=1,5 do local s=new('TextButton');s.Name='Slot'..i;s.Parent=dock;s.AbsolutePosition=R.Vector2.new(400+i*70,640);s.AbsoluteSize=R.Vector2.new(64,64);local n=new('TextLabel');n.Name='ItemName';n.Parent=s end
-- Modules: real BeginnerGuide + HudLayout; small stubs for art/audio helpers.
local modules={}
local function module(name,value)local m=new('ModuleScript');m.Name=name;m.Parent=RS;modules[m]=value;return m end
local sounds={}
module('GardenTheme',{Corner=function(p,r)local c=new('UICorner');c.Parent=p;return c end})
module('GardenDisplayNames',{Tool=function(tool)return tool.Name end})
module('PlantCatalog',{})
module('InteractionAudio',{Play=function(k)sounds[#sounds+1]=k;return true end})
local env
local function load(name,scriptInst)
 local fn=assert(loadstring(B[name],'='..name))
 local e=setmetatable({script=scriptInst},{__index=env});setfenv(fn,e);return fn()
end
local function req(m)
 if modules[m]~=nil then return modules[m]end
 if m._source then modules[m]=load(m._source,m);return modules[m]end
 error('require of unknown module '..tostring(m))
end
local guideModule=module('BeginnerGuide',nil);guideModule._source='BeginnerGuide';modules[guideModule]=nil
local hudModule=module('HudLayout',nil);hudModule._source='HudLayout';modules[hudModule]=nil
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,Color3=R.Color3,ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,TweenInfo=R.TweenInfo,Enum=R.Enum,RaycastParams={new=function()return {}end},typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end,time=os.time},utf8=utf8,warn=function(...)print('WARN',...)end},{__index=_G})
-- ScreenGuis report the viewport as their absolute size.
local rawNew=R.Instance.new
R.Instance.new=function(class,parent)local o=rawNew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(1280,720);o.AbsolutePosition=R.Vector2.new(0,0)end;return o end
env.Instance=R.Instance
local function frames(n,dt)for _=1,n do R.advance(dt or 1/60);Run.RenderStepped:Fire(dt or 1/60);Run.Heartbeat:Fire(dt or 1/60)end end
-- Run --------------------------------------------------------------------------
player:SetAttribute('TutorialMask',0);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1)
local scriptInst=new('LocalScript');scriptInst.Name='BeginnerTutorial'
local ok,err=pcall(load,'BeginnerTutorial',scriptInst);check(ok,'script loads: '..tostring(err))
frames(90)
local gui=pg:FindFirstChild('BeginnerTutorial');check(gui~=nil,'gui created')
local card=gui.GuideCard;local welcome=gui.Welcome
check(welcome.Visible==true,'welcome shows for a new player');check(card.Visible==false,'card waits behind welcome')
check(welcome.Body.Text:find('Alex',1,true)~=nil,'welcome uses display name')
check(welcome.Title.Text=='Welcome to Steal A Pack!','game name in welcome')
check(welcome.Guide.Avatar.Visible==true and welcome.Guide.Avatar.Image:find('777',1,true)~=nil,'owner avatar on welcome badge')
check(gui.GuideCard.NameTag.Label.Text=='TMZ','guide name TMZ on tag')
check(gui.GuideCard.Skip.Text=='X','skip shows a plain X')
-- Trail: chevrons ahead of the player point at the goal.
local trail=workspace:FindFirstChild('TutorialTrail');check(trail~=nil,'trail folder')
local visible,pointing,count=0,0,0
local target=V3(40,3,60)
for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'then count+=1;if p.Transparency<1 then visible+=1
 local to=(target-p.CFrame.Position);if to.Magnitude>1 then local arm=p.CFrame.LookVector end end end end
check(count==36,'36 chevrons built');check(visible>=10,'chevrons visible during welcome: '..visible)
check(pathCalls==0,'no pathfinding');check(moved>30,'trail animated with BulkMoveTo')
-- Chevron geometry: left+right arm midpoint lies behind the tip; tip points along the route toward the goal.
local L,Rt;for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and not L and p.Transparency<.5 then L=p end end
local idx=table.find(trail:GetChildren(),L);Rt=trail:GetChildren()[idx+1]
local mid=(L.CFrame.Position+Rt.CFrame.Position)/2
local tipDir=(L.CFrame.LookVector+Rt.CFrame.LookVector).Unit
check(Rt.Name=='ArmR','arm pairing')
-- Both arms' -Z (LookVector) point toward the shared tip; their average must head roughly along the route.
local routeDir=(V3(40,0,60)-V3(0,0,0)).Unit -- straight at the goal
check(tipDir:Dot(routeDir)>.7,('chevron points along route (dot=%.2f)'):format(tipDir:Dot(routeDir)))
check(math.abs(mid.Y-.09)<.05,'chevrons sit on the ground (y='..mid.Y..')')
-- Dismiss welcome.
welcome.Go.Activated:Fire();frames(30)
check(welcome.Visible==false,'welcome closes');check(card.Visible==true,'card shows after welcome')
check(card.Instruction.Text:find('Follow the red arrows',1,true)~=nil,'step 1 text');check(card.StepPill.Label.Text=='STEP 1/5','step pill')
check(card.Instruction.Text:find('Hold E to steal',1,true)~=nil,'mouse wording (R125: hold E)')
check(card.AnchorPoint.Y==0 and card.Position.Y.Offset<200,'card sits at the top ('..card.Position.Y.Offset..')')
check(type(pg:GetAttribute('TutorialCardBottom'))=='number','notice reservation published')
check(card.Instruction.MaxVisibleGraphemes>=0,'typewriter running');frames(150);check(card.Instruction.MaxVisibleGraphemes==-1,'typewriter finishes')
check(gui.Goal.Enabled==true,'goal marker on');check(gui.Goal.Label.Text=='STEAL!','marker label')
-- Walk toward the goal; trail start follows the player.
for i=1,20 do root.CFrame=CF(i,3,i*1.4);frames(3)end
local nearest=math.huge;for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then local d=p.CFrame.Position-root.CFrame.Position;nearest=math.min(nearest,math.sqrt(d.X^2+d.Z^2))end end
check(nearest<4.5,'trail starts at the player after moving ('..math.floor(nearest)..')')
do local rp=root.CFrame.Position;local dir=(V3(40,0,60)-V3(rp.X,0,rp.Z)).Unit;local worst=0
 for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then
  local rel=V3(p.CFrame.Position.X-rp.X,0,p.CFrame.Position.Z-rp.Z);local side=(rel-dir*rel:Dot(dir)).Magnitude;worst=math.max(worst,side)
 end end
 check(worst<1.6,('arrows sit on the straight line (max sideways %.2f)'):format(worst))
end
-- Near the goal the trail hides.
root.CFrame=CF(39,3,58);frames(10)
local shown=0;for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then shown+=1 end end
check(shown==0,'trail hidden at the goal')
-- Step 2: carrying.
serverStep={Kind='Safety',Target=V3(0,3,-20)};player:SetAttribute('ChestChaseSeedCarrying',true);frames(90)
check(card.Instruction.Text:find('Run home',1,true)~=nil,'step 2 text');check(sounds[#sounds]=='Bubble06','step change sound')
-- Step 3: pack in backpack; pointer over its slot; equipped wording.
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil}
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool.Parent=backpack
dock.Slot2.ItemName.Text='Forest Pack';player:SetAttribute('TutorialStep',3);frames(90)
check(card.StepPill.Label.Text=='STEP 3/5','step 3 pill');check(gui.HotbarPointer.Visible==true,'hotbar pointer visible')
check(math.abs(gui.HotbarPointer.Position.X.Offset-(540+32))<1,'pointer over slot 2 ('..gui.HotbarPointer.Position.X.Offset..')')
local shownTrail=0;for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then shownTrail+=1 end end
check(shownTrail==0,'no trail on a step without a world goal')
tool.Parent=character;player:SetAttribute('ChestChaseSeedCarrying',false);frames(90)
check(card.Instruction.Text:find('Click to open',1,true)~=nil,'equipped wording');check(gui.HotbarPointer.Visible==false,'pointer hides once equipped')
-- Menu wheel open hides the card.
pg:SetAttribute('GardenMenuExpanded',true);frames(2);check(card.Visible==false,'card hides while menu open')
check(pg:GetAttribute('TutorialCardBottom')==nil,'reservation cleared while hidden')
pg:SetAttribute('GardenMenuExpanded',false);frames(2);check(card.Visible==true,'card returns')
-- Touch wording.
UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
check(card.Instruction.Text:find('Tap to open',1,true)~=nil,'touch wording')
-- Step 5 tips: four slides, NEXT skips ahead, then the tutorial completes itself and shows the finish card.
serverStep={Kind=nil,Target=nil};player:SetAttribute('TutorialStep',5);frames(10)
check(card.StepPill.Label.Text=='STEP 5/5','tips pill');check(card.NextTip.Visible==true,'NEXT shown on tips')
check(card.Instruction.Text:find('grows by itself',1,true)~=nil,'tip 1: '..card.Instruction.Text)
frames(60*4);check(card.Instruction.Text:find('Pick the fruit',1,true)~=nil,'tip 2 after 3.5 s: '..card.Instruction.Text)
card.NextTip.Activated:Fire();frames(2);check(card.Instruction.Text:find('Sell fruit',1,true)~=nil,'NEXT jumps to tip 3')
-- R125: tips 4 / 5 teach the BASE and TRACK top-bar buttons and highlight them.
local travel=new('ScreenGui');travel.Name='TravelButtons';travel.Parent=pg
local pair=new('Frame');pair.Name='TravelPair';pair.Visible=true;pair.Parent=travel
local baseB=new('TextButton');baseB.Name='BaseButton';baseB.AbsolutePosition=R.Vector2.new(560,8);baseB.AbsoluteSize=R.Vector2.new(70,36);baseB.Parent=pair
local trackB=new('TextButton');trackB.Name='TrackButton';trackB.AbsolutePosition=R.Vector2.new(650,8);trackB.AbsoluteSize=R.Vector2.new(70,36);trackB.Parent=pair
card.NextTip.Activated:Fire();frames(2)
local ringUi=pg.BeginnerTutorial:FindFirstChild('TravelHighlight');local arrowUi=pg.BeginnerTutorial:FindFirstChild('TravelPointer')
check(card.Instruction.Text:find('BASE',1,true)~=nil,'tip 4 teaches BASE: '..card.Instruction.Text)
check(ringUi and ringUi.Visible and ringUi.Position.X.Offset<=560 and ringUi.Position.X.Offset>=550,'BASE button ringed')
check(arrowUi and arrowUi.Visible,'arrow under the BASE button')
card.NextTip.Activated:Fire();frames(2)
check(card.Instruction.Text:find('TRACK',1,true)~=nil,'tip 5 teaches TRACK: '..card.Instruction.Text)
check(ringUi.Visible and ringUi.Position.X.Offset>=640,'TRACK button ringed')
card.NextTip.Activated:Fire();frames(2);check(card.Instruction.Text:find('faster',1,true)~=nil and not ringUi.Visible,'tip 6, no highlight')
local trailOnTips=0;for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then trailOnTips+=1 end end
check(trailOnTips==0,'no arrows during tips')
frames(60*8)
check(table.find(commands,'TreadmillInfo')~=nil,'tips complete the tutorial')
check(card.Visible==true and card.StepPill.Label.Text=='DONE!','finish card shows');check(sounds[#sounds]=='GemClaim','finish sound')
check(card.NextTip.Visible==false,'NEXT hidden on finish card')
frames(60*6);check(card.Visible==false,'finish card hides after 5 s')
-- Replay then skip with two taps: no finish card.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,60)};frames(30)
check(welcome.Visible==true,'replay shows welcome again');welcome.Go.Activated:Fire();frames(10)
card.Skip.Activated:Fire();frames(5);check(card.StepPill.Label.Text=='SKIP?','first tap arms skip');check(table.find(commands,'Skip')==nil,'one tap does not skip')
card.Skip.Activated:Fire();frames(30);check(table.find(commands,'Skip')~=nil,'second tap skips')
check(card.Visible==false,'no finish card after skip')
frames(60*4);check(card.StepPill.Label.Text~='SKIP?','pill resets')
-- R125: step 1 off the track first asks for TRACK (ring on the button); on the track the steal wording returns.
local motion=new('ModuleScript');motion.Name='RunnerMotion';motion:SetAttribute('TrackBoundaryZ',50);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114);motion.Parent=RS
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',3);player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,60)}
root.CFrame=CF(0,3,0);frames(40)
check(card.Visible and card.Instruction.Text:find('TRACK',1,true)~=nil,'off the track: '..card.Instruction.Text)
check(pg.BeginnerTutorial.TravelHighlight.Visible and pg.BeginnerTutorial.TravelHighlight.Position.X.Offset>=640,'TRACK button ringed in step 1')
root.CFrame=CF(0,3,60);frames(40)
check(card.Instruction.Text:find('Follow the red arrows',1,true)~=nil and card.Instruction.Text:find('Hold',1,true)~=nil,'on the track: steal wording ('..card.Instruction.Text..')')
check(not pg.BeginnerTutorial.TravelHighlight.Visible,'ring gone on the track')
player:SetAttribute('TutorialStep',3);frames(10)
check(card:FindFirstChild('Stamp')and card.Stamp.Visible,'NICE! stamp when a step is done')
frames(60*2);check(not card.Stamp.Visible,'stamp fades')
-- Cleanup.
scriptInst.Destroying:Fire();check(workspace:FindFirstChild('TutorialTrail')==nil,'trail removed on cleanup')
frames(5)
print(('%d checks, %d failures'):format(checks,fails))
