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
check(welcome.Title.Text=='STEAL A PACK!','game name in welcome')
-- R138: the welcome is the whole game in four pictures.
local strip=welcome:FindFirstChild('Strip');local icons={}
for i=1,4 do local panel=strip and strip:FindFirstChild('Panel'..i);icons[i]=panel and panel.Icon.Glyph.Text..' '..panel.Word.Text or'?'end
check(table.concat(icons,' | ')=='🎒 STEAL | 🏠 RUN HOME | 🎁 OPEN | 🌱 PLANT','welcome picture strip: '..table.concat(icons,' | '))
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
local function chip()return(card.Hint.Key.Visible and('['..card.Hint.Key.Label.Text..'] ')or'')..(card.Hint.Arrow.Visible and'➜ 'or'')..card.Hint.Label.Text end
check(card.Instruction.Text=='STEAL A PACK'and card.StepIcon.Glyph.Text=='🎒','step 1: icon + three words ('..card.Instruction.Text..')')
check(chip()=='[E] HOLD','mouse chip: [E] HOLD ('..chip()..')')
check(card.Progress.Dot1.Size.X.Offset>card.Progress.Dot2.Size.X.Offset,'step row: the current step is the big one')
check(not card.StepPill.Visible,'no STEP x/5 pill (the icon row shows it)')
check(card.AnchorPoint.Y==0 and card.Position.Y.Offset<200,'card sits at the top ('..card.Position.Y.Offset..')')
check(type(pg:GetAttribute('TutorialCardBottom'))=='number','notice reservation published')
check(gui.Goal.Enabled==true,'goal marker on');check(gui.Goal.Label.Text=='😈 STEAL!','marker label')
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
check(card.Instruction.Text=='RUN HOME!'and chip()=='➜ FOLLOW THE ARROWS','step 2: RUN HOME! + follow the arrows ('..chip()..')');check(sounds[#sounds]=='Bubble06','step change sound')
check(card.Progress.Dot1.BackgroundColor3.G>.8 and card.Progress.Dot1.BackgroundColor3.R<.6,'step row: step 1 ticked green')
-- Step 3: pack in backpack; pointer over its slot; equipped wording.
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil}
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool.Parent=backpack
dock.Slot2.ItemName.Text='Forest Pack';player:SetAttribute('TutorialStep',3);frames(90)
check(card.Instruction.Text=='OPEN IT'and chip()=='[CLICK] YOUR PACK','step 3: OPEN IT [CLICK] YOUR PACK ('..chip()..')');check(gui.HotbarPointer.Visible==true,'hotbar pointer visible')
check(math.abs(gui.HotbarPointer.Position.X.Offset-(540+32))<1,'pointer over slot 2 ('..gui.HotbarPointer.Position.X.Offset..')')
local shownTrail=0;for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then shownTrail+=1 end end
check(shownTrail==0,'no trail on a step without a world goal')
tool.Parent=character;player:SetAttribute('ChestChaseSeedCarrying',false);frames(90)
check(card.Instruction.Text=='KEEP CLICKING!'and chip()=='[CLICK] OPEN IT','holding it: KEEP CLICKING! ('..card.Instruction.Text..')');check(gui.HotbarPointer.Visible==false,'pointer hides once equipped')
-- R138: the clicking indicator next to the pack in your hand, one pip per click still needed.
local bag=new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('PackClicksRequired',5);bag:SetAttribute('PackClickCount',0)
local bagPart=new('Part');bagPart.CFrame=CF(2,4,3);bagPart.Parent=bag;bag.PrimaryPart=bagPart;bag.Parent=character;frames(10)
local hintUi=gui:FindFirstChild('ClickHint')
local function lit()local n=0;for i=1,5 do local p=hintUi.Pips:FindFirstChild('Pip'..i);if p and p.Visible and p.BackgroundColor3.R>.9 then n+=1 end end;return n end
check(hintUi and hintUi.Visible and hintUi.Word.Text=='CLICK!'and hintUi.Hand.Text=='🖱️','clicking indicator: a mouse and CLICK! by the pack')
check(lit()==0 and hintUi.Pips:FindFirstChild('Pip5')and hintUi.Pips.Pip5.Visible,'five pips, none lit yet')
local lowest,highest=1,0;for _=1,40 do frames(1);local k=hintUi.Hand.UIScale.Scale;lowest=math.min(lowest,k);highest=math.max(highest,k)end
check(lowest<.9 and highest>.99,'the hand keeps pressing (scale '..string.format('%.2f..%.2f',lowest,highest)..')')
bag:SetAttribute('PackClickCount',2);frames(2);check(lit()==2,'each click lights a pip ('..lit()..')')
bag:SetAttribute('PackClickCount',4);frames(2);check(lit()==4,'four clicks, four pips')
bag:SetAttribute('RevealAt',123);frames(2);check(not hintUi.Visible,'gone once the pack opens')
bag:SetAttribute('RevealAt',nil);bag:SetAttribute('PackClickCount',0);frames(2)
-- Menu wheel open hides the card.
pg:SetAttribute('GardenMenuExpanded',true);frames(2);check(card.Visible==false,'card hides while menu open')
check(pg:GetAttribute('TutorialCardBottom')==nil,'reservation cleared while hidden')
pg:SetAttribute('GardenMenuExpanded',false);frames(2);check(card.Visible==true,'card returns')
-- Touch wording.
UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
check(card.Instruction.Text=='KEEP TAPPING!'and chip()=='[TAP] OPEN IT','touch wording ('..card.Instruction.Text..')')
check(hintUi.Visible and hintUi.Word.Text=='TAP!'and hintUi.Hand.Text=='👆','touch: a finger and TAP!')
bag:Destroy();frames(2)
-- R125: the BASE and TRACK top-bar buttons (slides 2 and 3 highlight them).
local travel=new('ScreenGui');travel.Name='TravelButtons';travel.Parent=pg
local pair=new('Frame');pair.Name='TravelPair';pair.Visible=true;pair.Parent=travel
local baseB=new('TextButton');baseB.Name='BaseButton';baseB.AbsolutePosition=R.Vector2.new(560,8);baseB.AbsoluteSize=R.Vector2.new(70,36);baseB.Parent=pair
local trackB=new('TextButton');trackB.Name='TrackButton';trackB.AbsolutePosition=R.Vector2.new(650,8);trackB.AbsoluteSize=R.Vector2.new(70,36);trackB.Parent=pair
-- Step 5: three picture slides (5 s each), NEXT skips ahead, then the tutorial completes itself.
serverStep={Kind=nil,Target=nil};player:SetAttribute('TutorialStep',5);frames(10)
check(card.NextTip.Visible==true,'NEXT shown on the slides')
check(card.Instruction.Text=='GROW ➜ PICK ➜ SELL'and chip()=='🌱 ➜ 🍎 ➜ 💰','slide 1: the loop in pictures ('..chip()..')')
frames(60*5.2)
local ringUi=pg.BeginnerTutorial:FindFirstChild('TravelHighlight');local arrowUi=pg.BeginnerTutorial:FindFirstChild('TravelPointer')
check(card.Instruction.Text=='ZOOM HOME'and chip()=='[BASE] UP TOP','slide 2 after 5 s: ZOOM HOME [BASE] ('..card.Instruction.Text..')')
check(ringUi and ringUi.Visible and ringUi.Position.X.Offset<=560 and ringUi.Position.X.Offset>=550,'BASE button ringed')
check(arrowUi and arrowUi.Visible,'arrow under the BASE button')
card.NextTip.Activated:Fire();frames(2)
check(card.Instruction.Text=='ZOOM TO TRACK'and chip()=='[TRACK] UP TOP','NEXT: slide 3, ZOOM TO TRACK')
check(ringUi.Visible and ringUi.Position.X.Offset>=640,'TRACK button ringed')
local trailOnTips=0;for _,p in ipairs(trail:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then trailOnTips+=1 end end
check(trailOnTips==0,'no arrows during tips')
for _=1,60*12 do frames(1);if card.Instruction.Text=="YOU'RE READY!"then break end end
check(table.find(commands,'TreadmillInfo')~=nil,'tips complete the tutorial')
check(card.Visible==true and card.Instruction.Text=="YOU'RE READY!"and card.StepIcon.Glyph.Text=='🏆','finish card: YOU\'RE READY! 🏆')
check(card.Hint.Label.Text=='🎁 FREE LUCKY PACK!','R138: the finish card tells them about the free pack');check(sounds[#sounds]=='GemClaim','finish sound')
check(gui.Confetti.Visible,'confetti on the finish');frames(60*3);check(not gui.Confetti.Visible,'confetti clears')
check(card.NextTip.Visible==false,'NEXT hidden on finish card')
frames(60*3);check(card.Visible==false,'finish card hides after 5 s')
-- Replay then skip with two taps: no finish card.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,60)};frames(30)
check(welcome.Visible==true,'replay shows welcome again');welcome.Go.Activated:Fire();frames(10)
card.Skip.Activated:Fire();frames(5);check(card.StepPill.Visible and card.StepPill.Label.Text=='SKIP?','first tap arms skip');check(table.find(commands,'Skip')==nil,'one tap does not skip')
card.Skip.Activated:Fire();frames(30);check(table.find(commands,'Skip')~=nil,'second tap skips')
check(card.Visible==false,'no finish card after skip')
frames(60*4);check(not card.StepPill.Visible,'the SKIP? pill goes away')
-- R125: step 1 off the track first asks for TRACK (ring on the button); on the track the steal wording returns.
local motion=new('ModuleScript');motion.Name='RunnerMotion';motion:SetAttribute('TrackBoundaryZ',50);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114);motion.Parent=RS
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',3);player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,60)}
root.CFrame=CF(0,3,0);frames(40)
check(card.Visible and card.Instruction.Text=='GO TO THE TRACK'and chip()=='[TRACK] UP TOP','off the track: '..card.Instruction.Text)
check(pg.BeginnerTutorial.TravelHighlight.Visible and pg.BeginnerTutorial.TravelHighlight.Position.X.Offset>=640,'TRACK button ringed in step 1')
root.CFrame=CF(0,3,60);frames(40)
check(card.Instruction.Text=='STEAL A PACK'and chip()=='[STEAL] HOLD','on the track (touch): steal ('..chip()..')')
check(not pg.BeginnerTutorial.TravelHighlight.Visible,'ring gone on the track')
player:SetAttribute('TutorialStep',3);frames(10)
check(card:FindFirstChild('Stamp')and card.Stamp.Visible,'NICE! stamp when a step is done')
frames(60*2);check(not card.Stamp.Visible,'stamp fades')
-- Cleanup.
scriptInst.Destroying:Fire();check(workspace:FindFirstChild('TutorialTrail')==nil,'trail removed on cleanup')
frames(5)
print(('%d checks, %d failures'):format(checks,fails))
