--!nocheck
-- R152 smoke test: the real BeginnerTutorial + BeginnerGuide + HudLayout on the Roblox mock. Every step's look (icon, words,
-- device key), its pointer (beam + ring + bubble / pressing hand / ring on a button), the trigger that moves it on (with the
-- ✓ NICE!! pop), nothing taking input, the phone safe area, the finish card, skipping, replays, returning players and no
-- leftovers. (R138 checks kept: the chevron trail geometry and the clicking indicator.)
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
local Paths=service('PathfindingService');function Paths.CreatePath()pathCalls+=1;return {}end
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
-- The track starts at z=50 (the line between the bases and the track), x=0 is its middle.
local motion=new('ModuleScript');motion.Name='RunnerMotion';motion:SetAttribute('TrackBoundaryZ',50);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114);motion.Parent=RS
-- Remote: returns targets for the current step and records commands.
local remotes=new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local request=new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
local commands={};local serverStep={Kind='Pack',Target=V3(40,3,90)}
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
-- The BASE / TRACK buttons in the top bar row (TravelButtons).
local travel=new('ScreenGui');travel.Name='TravelButtons';travel.Parent=pg
local pair=new('Frame');pair.Name='TravelPair';pair.Visible=true;pair.Parent=travel
local baseB=new('TextButton');baseB.Name='BaseButton';baseB.AbsolutePosition=R.Vector2.new(560,8);baseB.AbsoluteSize=R.Vector2.new(70,36);baseB.Parent=pair
local trackB=new('TextButton');trackB.Name='TrackButton';trackB.AbsolutePosition=R.Vector2.new(650,8);trackB.AbsoluteSize=R.Vector2.new(70,36);trackB.Parent=pair
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
local cacheModule=module('PropCache152',nil);cacheModule._source='PropCache152';modules[cacheModule]=nil
-- Every property write on an instance is counted (the R152 perf habit: write only what changed, nothing while hidden or idle).
local writes=0
do local rawSet=R.instMeta.__newindex;R.instMeta.__newindex=function(o,k,v)writes+=1;return rawSet(o,k,v)end end
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,Color3=R.Color3,ColorSequence=R.ColorSequence,ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,TweenInfo=R.TweenInfo,Enum=R.Enum,RaycastParams={new=function()return {}end},typeof=R.typeof,task=R.task,require=req,os={clock=function()return R.clock end,time=os.time},utf8=utf8,warn=function(...)print('WARN',...)end},{__index=_G})
-- ScreenGuis report the viewport as their absolute size.
local VIEW=R.Vector2.new(1280,720)
local rawNew=R.Instance.new
R.Instance.new=function(class,parent)local o=rawNew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=VIEW;o.AbsolutePosition=R.Vector2.new(0,0)end;return o end
env.Instance=R.Instance
local function frames(n,dt)for _=1,n do R.advance(dt or 1/60);Run.RenderStepped:Fire(dt or 1/60);Run.Heartbeat:Fire(dt or 1/60)end end
-- Run --------------------------------------------------------------------------
local Guide=req(guideModule)
player:SetAttribute('TutorialMask',0);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1)
local scriptInst=new('LocalScript');scriptInst.Name='BeginnerTutorial'
local ok,err=pcall(load,'BeginnerTutorial',scriptInst);check(ok,'script loads: '..tostring(err))
frames(30)
local gui=pg:FindFirstChild('BeginnerTutorial');check(gui~=nil,'gui created')
local card=gui.GuideCard
local function trail()return workspace:FindFirstChild('TutorialTrail')end
local function chip()return(card.Hint.Key.Visible and('['..card.Hint.Key.Label.Text..'] ')or'')..(card.Hint.Arrow.Visible and'➜ 'or'')..Guide.Plain(card.Hint.Label.Text)end
local function says(title,chipText,msg)check(card.Visible and card.Instruction.Text==title and(chipText==nil or(card.Hint.Visible and chip()==chipText)),msg..' ('..tostring(card.Instruction.Text)..' / '..chip()..')')end
local function shownChevrons()local n=0;local t=trail();if t then for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then n+=1 end end end;return n end
local function beamAt()local t=trail();local b=t and t:FindFirstChild('GoalBeam');return b and b.Transparency<1 and b.CFrame.Position or nil end
local function near(a,x,z,tol)return a~=nil and math.abs(a.X-x)<(tol or 1.5)and math.abs(a.Z-z)<(tol or 1.5)end
local tapGui=pg:FindFirstChild('BeginnerTutorialTap');local tapUi=tapGui and tapGui.TapHand
local function ringOn(b)return tapUi.Visible and math.abs(tapUi.Ring.Position.X.Offset-(b.AbsolutePosition.X-6))<1 and math.abs(tapUi.Ring.Position.Y.Offset-(b.AbsolutePosition.Y-6))<1 end
-- Nothing in the tutorial takes a click or tap except the small two-tap X.
local function inputFree(where)
 local buttons,active={},{}
 local all=gui:GetDescendants();for _,o in ipairs(tapGui:GetDescendants())do all[#all+1]=o end
 for _,o in ipairs(all)do
  if o:IsA('GuiButton')then buttons[#buttons+1]=o.Name end
  if o:IsA('GuiObject')and o.Active==true and not o:IsA('GuiButton')then active[#active+1]=o.Name end
  if o.Modal==true then active[#active+1]=o.Name..'(Modal)'end
 end
 check(#buttons==1 and buttons[1]=='Skip'and #active==0,where..': only the X takes input (buttons: '..table.concat(buttons,',')..' / active: '..table.concat(active,',')..')')
end
local function popped(msg)
 check(card.Instruction.Text=='NICE!!'and card.StepIcon.Glyph.Text=='✓'and not card.Hint.Visible,msg..': the ✓ NICE!! pop ('..card.Instruction.Text..')')
 check(sounds[#sounds]=='Bubble06',msg..': pop sound')
 check(shownChevrons()==0 and not gui.Goal.Enabled and not tapUi.Visible,msg..': the pointers wait for the next step')
end

-- 1. A brand-new player off the track: no welcome page, straight to the TRACK button.
check(gui:FindFirstChild('Welcome')==nil and card:FindFirstChild('NextTip')==nil,'no welcome page and no NEXT button (nothing to click through)')
check(gui.ScreenInsets==R.Enum.ScreenInsets.CoreUISafeInsets,'the tutorial lives inside the safe area (notch / home bar / top bar)')
check(tapGui and tapGui.ScreenInsets==R.Enum.ScreenInsets.None and tapGui.DisplayOrder>25,'the pressing hand has its own no-inset layer above the card + hotbar (it can ring a top-bar button)')
says('GO TO THE TRACK!','[TRACK] click it','off the track: the TRACK button')
check(card.StepIcon.Glyph.Text=='🏃','off the track: 🏃 icon')
check(ringOn(trackB),'a ring + pressing hand on the TRACK button')
check(card.Position.Y.Offset>=trackB.AbsolutePosition.Y+trackB.AbsoluteSize.Y+20,'the card sits below the pressing hand ('..card.Position.Y.Offset..')')
check(beamAt()and near(beamAt(),0,58),'a beam at the track gate')
check(shownChevrons()>=5,'a ghost path to the track gate ('..shownChevrons()..')')
check(gui.Goal.Enabled and gui.Goal.Bubble.Icon.Text=='🏃','the bubble over the gate')
check(sounds[1]=='Bubble04','a hello pop when the card first shows')
check(not card.StepPill.Visible,'no SKIP? pill yet');check(card.Skip.Text=='X','skip shows a plain X')
check(card.NameTag.Label.Text=='TMZ'and card.Guide.Avatar.Visible and card.Guide.Avatar.Image:find('777',1,true)~=nil,'the owner\'s avatar + TMZ tag guide you')
check(type(pg:GetAttribute('TutorialCardBottom'))=='number','notice reservation published')
inputFree('off the track')
-- Onto the track: pop, then GRAB A PACK.
root.CFrame=CF(0,3,60);frames(12)
popped('on the track')
check(card.Progress.Dot1.BackgroundColor3.R<.9,'the step is not ticked by a detour')
frames(45)
says('GRAB A PACK!','[E] hold','step 1')
check(card.StepIcon.Glyph.Text=='🎒'and card.StepIcon.UIGradient.Color.A.R>.9,'step 1: 🎒 on gold')
check(not tapUi.Visible,'no hand on a button once on the track')
check(beamAt()and near(beamAt(),40,90),'a beam on the pack')
check(gui.Goal.Enabled and gui.Goal.Bubble.Icon.Text=='🎒'and not gui.TapSpot.Enabled,'the 🎒 bubble over the pack')
check(card.Progress.Dot1.Size.X.Offset>card.Progress.Dot2.Size.X.Offset,'step row: the current step is the big one')
-- Chevrons: straight from the feet to the pack, on the ground, pointing at it.
local t=trail();check(t~=nil,'trail folder');local count=0;for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'then count+=1 end end
check(count==36,'36 chevrons built');check(moved>10,'trail animated with BulkMoveTo');check(pathCalls==0,'no pathfinding')
local L;for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'and not L and p.Transparency<.5 then L=p end end
local idx=table.find(t:GetChildren(),L);local Rt=t:GetChildren()[idx+1]
check(Rt.Name=='ArmR','arm pairing')
local tipDir=(L.CFrame.LookVector+Rt.CFrame.LookVector).Unit;local routeDir=(V3(40,0,90)-V3(0,0,60)).Unit
check(tipDir:Dot(routeDir)>.7,('chevron points along route (dot=%.2f)'):format(tipDir:Dot(routeDir)))
check(math.abs((L.CFrame.Position+Rt.CFrame.Position).Y/2-.09)<.05,'chevrons sit on the ground')
-- R153 (owner: "fix all jittery type effects"): a chevron fading in at the feet / out at the goal changes on every drawn frame at 30 / 60 fps and in
-- steps of at most 1/100 + the frame's own fade at 144 fps (it faded in tenths: ten visible steps, a new one every few frames)
for _,fps in ipairs({30,60,144})do
 local seen,stalls,fading,worstStep={},0,0,0
 for _=1,fps do
  frames(1,1/fps)
  for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'then
   local a,last=p.Transparency,seen[p]
   if last and a>0 and a<1 and last>0 and last<1 then fading+=1;if a==last then stalls+=1 end;worstStep=math.max(worstStep,math.abs(a-last))end
   seen[p]=a
  end end
 end
 local perFrame=4.5/fps/1.5 -- (the fastest fade: 1.5 studs at 4.5 studs a second)
 check(fading>10 and worstStep<=perFrame+.011,string.format('R153: at %d fps the chevrons fade in fine steps (%d fading frames, the biggest step %.3f, the fade itself %.3f a frame)',fps,fading,worstStep,perFrame))
 if fps<=60 then check(stalls==0,string.format('R153: at %d fps a fading chevron changes on every frame (%d repeated)',fps,stalls))end
end
for i=1,20 do root.CFrame=CF(i,3,60+i*1.4);frames(3)end
local nearest=math.huge;for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then local d=p.CFrame.Position-root.CFrame.Position;nearest=math.min(nearest,math.sqrt(d.X^2+d.Z^2))end end
check(nearest<4.5,'the path starts at the player after moving ('..math.floor(nearest)..')')
do local rp=root.CFrame.Position;local dir=(V3(40,0,90)-V3(rp.X,0,rp.Z)).Unit;local worst=0
 for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then
  local rel=V3(p.CFrame.Position.X-rp.X,0,p.CFrame.Position.Z-rp.Z);local side=(rel-dir*rel:Dot(dir)).Magnitude;worst=math.max(worst,side)
 end end
 check(worst<1.6,('arrows sit on the straight line (max sideways %.2f)'):format(worst))
end
root.CFrame=CF(39,3,88);frames(10);check(shownChevrons()==0 and beamAt()~=nil,'at the pack: the path hides, the beam stays')
-- No pack yet: PACKS COMING.
serverStep={Kind='Pack',Waiting=true};frames(70);says('PACKS COMING!','hang tight','no packs yet')
check(shownChevrons()==0 and not gui.Goal.Enabled,'no pointer while waiting')
serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70);says('GRAB A PACK!','[E] hold','a pack shows up')
inputFree('step 1')

-- 2. Picked up: pop, then RUN HOME!!
local before=#sounds
serverStep={Kind='Safety',Target=V3(0,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);frames(6)
popped('picked it up');check(#sounds>before,'a sound for the pop')
check(card.Progress.Dot1.BackgroundColor3.G>.8 and card.Progress.Dot1.BackgroundColor3.R<.6 and card.Progress.Dot1.Glyph.Text=='✓','step row: step 1 ticked green')
frames(60);says('RUN HOME!!','➜ to ur base','step 2')
check(card.StepIcon.Glyph.Text=='🏠'and gui.Goal.Bubble.Icon.Text=='🏠','step 2: 🏠 icon + bubble')
check(beamAt()and near(beamAt(),0,38),'a beam on the home line')
check(not tapUi.Visible,'no BASE button while carrying (you can\'t teleport with a pack)')
-- Caught (the pack is gone): back to GRAB, no pop.
before=#sounds;player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70)
says('GRAB A PACK!','[E] hold','lost the pack: back to step 1');check(#sounds==before,'no pop going backwards')
serverStep={Kind='Safety',Target=V3(0,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);frames(60)

-- 3. Banked: OPEN IT, ring + hand on the pack's hotbar slot.
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil};root.CFrame=CF(0,3,20)
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool.Parent=backpack
dock.Slot2.ItemName.Text='Forest Pack';player:SetAttribute('TutorialStep',3);frames(6)
popped('banked')
frames(60)
says('OPEN IT!','[CLICK] ur pack','step 3');check(card.StepIcon.Glyph.Text=='🎁','step 3: 🎁')
check(ringOn(dock.Slot2),'a ring + pressing hand on the pack\'s slot')
local fx=tapUi.Hand.Position.X.Offset;check(fx>=540 and fx<=540+64,'the finger is on the slot ('..fx..')')
check(shownChevrons()==0 and not gui.Goal.Enabled,'no world pointer on step 3')
do local lo,hi=1,0;for _=1,50 do frames(1);local k=tapUi.Hand.Press.Scale;lo=math.min(lo,k);hi=math.max(hi,k)end;check(lo<.95 and hi>.99,'the finger keeps pressing')end
inputFree('step 3')
-- In your hand: KEEP CLICKING!! + the R138 clicking indicator.
tool.Parent=character;frames(20)
says('KEEP CLICKING!!','[CLICK] open it','pack in hand');check(not tapUi.Visible,'the slot hand goes once it\'s in your hand')
local bag=new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('PackClicksRequired',5);bag:SetAttribute('PackClickCount',0)
local bagPart=new('Part');bagPart.CFrame=CF(2,4,3);bagPart.Parent=bag;bag.PrimaryPart=bagPart;bag.Parent=character;frames(10)
local hintUi=gui.ClickHint
local function lit()local n=0;for i=1,5 do local p=hintUi.Pips:FindFirstChild('Pip'..i);if p and p.Visible and p.BackgroundColor3.R>.9 then n+=1 end end;return n end
check(hintUi.Visible and hintUi.Word.Text=='CLICK!'and hintUi.Hand.Text=='🖱️','clicking indicator: a mouse and CLICK! by the pack')
check(lit()==0 and hintUi.Pips.Pip5.Visible,'five pips, none lit yet')
local lowest,highest=1,0;for _=1,40 do frames(1);local k=hintUi.Hand.UIScale.Scale;lowest=math.min(lowest,k);highest=math.max(highest,k)end
check(lowest<.9 and highest>.99,'the hand keeps pressing')
bag:SetAttribute('PackClickCount',2);frames(2);check(lit()==2,'each click lights a pip')
-- Phone: the same step in tap words, a finger and TAP!
UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
says('KEEP TAPPING!!','[TAP] open it','touch wording');check(hintUi.Visible and hintUi.Word.Text=='TAP!'and hintUi.Hand.Text=='👆','touch: a finger and TAP!')
-- The menu wheel hides the card (and its pointers), then it comes back. Hidden, nothing is written per frame.
pg:SetAttribute('GardenMenuExpanded',true);frames(2);check(not card.Visible and not hintUi.Visible and pg:GetAttribute('TutorialCardBottom')==nil,'card + pointers hide while the menu is open')
do local w,m=writes,moved;frames(120);check(writes==w and moved==m,'card hidden: no property writes, no trail moves for 2 s ('..(writes-w)..' writes)')end
pg:SetAttribute('GardenMenuExpanded',false);frames(2);check(card.Visible,'card returns')
-- It opens: the reveal plays, the card waits, then PLANT IT.
bag:SetAttribute('RevealAt',123);frames(2);check(not hintUi.Visible,'the clicking indicator goes once the pack opens')
bag:Destroy();tool:Destroy();dock.Slot2.ItemName.Text=''
local seed=new('Tool');seed.Name='Carrot Seed';seed:SetAttribute('GardenSeed',true);seed.Parent=character
serverStep={Kind='Garden',Target=V3(-20,3,10)};player:SetAttribute('TutorialStep',4);frames(6)
popped('opened')
frames(60);check(card.Instruction.Text=='NICE!!','the pop waits while the reveal plays')
player:SetAttribute('RarePullCinematic','Mythic');frames(2);check(not card.Visible,'a rare pull\'s cinematic hides the card')
player:SetAttribute('RarePullCinematic',nil);frames(100)

-- 4. PLANT IT: a beam + ring + pressing hand on the dirt.
says('PLANT IT!','[TAP] the dirt','step 4 (touch)');check(card.StepIcon.Glyph.Text=='🌱','step 4: 🌱')
check(beamAt()and near(beamAt(),-20,10),'a beam on the garden dirt')
check(gui.TapSpot.Enabled and not gui.Goal.Enabled,'a pressing 👇 on the dirt instead of a bubble')
check(gui.TapSpot.Hand.Text=='👇','the dirt hand points down')
check(shownChevrons()>=3,'a ghost path to the dirt')
-- Reduced Motion, standing still: nothing changes, so nothing is written or moved.
Gui.ReducedMotionEnabled=true;frames(10)
do local w,m=writes,moved;frames(60);check(writes==w and moved==m,'Reduced Motion, standing still: no writes, no moves for 1 s ('..(writes-w)..' writes, '..(moved-m)..' moves)')end
check(shownChevrons()>=3 and gui.TapSpot.Enabled,'Reduced Motion: the path and the hand still show (still)')
Gui.ReducedMotionEnabled=false;frames(2)
do local w=writes;frames(60);local per=(writes-w)/60;check(per<60,('animated step 4: %.1f writes per frame (only what moves)'):format(per))end
inputFree('step 4')
-- The seed went back to the Bag: tap ur seed (its slot).
seed.Parent=backpack;dock.Slot1.ItemName.Text='Carrot Seed';frames(20)
says('PLANT IT!','[TAP] ur seed','seed not in hand');check(ringOn(dock.Slot1),'a ring + hand on the seed\'s slot')
check(shownChevrons()==0 and not gui.TapSpot.Enabled,'no world pointer until the seed is in hand')
seed.Parent=character;frames(12);popped('seed in hand');frames(50);says('PLANT IT!','[TAP] the dirt','back to the dirt')
-- Ran off to the track: GO HOME (BASE ringed), only then.
root.CFrame=CF(0,3,80);frames(12)
says('GO HOME!','[BASE] tap it','on the track in step 4');check(ringOn(baseB),'a ring + pressing hand on the BASE button')
check(shownChevrons()==0 and not gui.Goal.Enabled and not gui.TapSpot.Enabled,'no world pointer while BASE is asked')
root.CFrame=CF(-10,3,20);frames(12);popped('back home');frames(50);says('PLANT IT!','[TAP] the dirt','home again')

-- 5. Planted: GET FASTER! (your treadmill). Hopping on it ends the tutorial.
seed:Destroy();dock.Slot1.ItemName.Text=''
serverStep={Kind='Treadmill',Target=V3(12,3,-6)};player:SetAttribute('TutorialStep',5);frames(6);popped('planted');frames(50)
says('GET FASTER!','➜ hop on it','step 5');check(card.StepIcon.Glyph.Text=='⚡'and gui.Goal.Bubble.Icon.Text=='⚡','step 5: ⚡ icon + bubble')
check(beamAt()and near(beamAt(),12,-6),'a beam on the treadmill')
check(card.Progress.Dot4.Glyph.Text=='✓'and card.Progress.Dot5.Size.X.Offset>card.Progress.Dot4.Size.X.Offset,'step row: 4 ticked, 5 current')
check(table.find(commands,'TreadmillInfo')==nil,'step 5 waits for you')
inputFree('step 5')
player:SetAttribute('StarterPackClaimed',false);frames(2)
player:SetAttribute('TreadmillTraining',true);frames(3)
check(table.find(commands,'TreadmillInfo')~=nil,'stepping on the treadmill finishes the tutorial')
check(player:GetAttribute('TutorialDone')==true,'done')
-- The finish: U GOT THIS!! + the free pack, confetti, then nothing left.
says('U GOT THIS!!','🎁 FREE PACK!','finish card');check(card.StepIcon.Glyph.Text=='🏆'and sounds[#sounds]=='GemClaim','🏆 + the gem sound')
check(gui.Confetti.Visible,'confetti')
check(trail()==nil,'the world pieces are gone as soon as it is done')
check(not tapUi.Visible and not gui.Goal.Enabled and not gui.TapSpot.Enabled and not gui.ClickHint.Visible,'no pointer on the finish card')
for i=1,5 do check(card.Progress['Dot'..i].Glyph.Text=='✓','finish: step '..i..' ticked')end
frames(60*3);check(not gui.Confetti.Visible,'confetti clears')
frames(60*2);check(not card.Visible and pg:GetAttribute('TutorialCardBottom')==nil,'finish card gone after 4 s, reservation cleared')
local function nothingLeft(where)
 check(not card.Visible and not tapUi.Visible and not gui.Goal.Enabled and not gui.TapSpot.Enabled and not gui.ClickHint.Visible and not gui.Direction.Visible and not gui.Confetti.Visible and trail()==nil,where..': nothing left on screen or in the world')
 check(pg:GetAttribute('TutorialCardBottom')==nil,where..': no notice reservation')
end
nothingLeft('after finishing')
local movedBefore,cmdBefore,writesBefore=moved,#commands,writes;frames(120);check(moved==movedBefore and #commands==cmdBefore and writes==writesBefore,'idle after finishing: no writes, no trail work, no polling ('..(writes-writesBefore)..' writes)')
check(gui.Enabled==false and tapGui.Enabled==false,'idle: the tutorial ScreenGuis are off')
player:SetAttribute('TreadmillTraining',false)

-- Replay (Settings): starts at step 1; the free pack was given, so the finish says have fun.
player:SetAttribute('StarterPackClaimed',true);root.CFrame=CF(0,3,60)
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,90)};frames(30)
says('GRAB A PACK!','[👆] hold it','replay on a phone: step 1 again');check(trail()~=nil,'the world pieces come back for a replay')
-- Step 5 with no treadmill in your base: done at once. Then the replay finish.
serverStep={Kind='Treadmill',Target=nil};player:SetAttribute('TutorialStep',5);frames(90)
check(player:GetAttribute('TutorialDone')==true,'no treadmill: step 5 finishes by itself')
says('U GOT THIS!!','have fun Alex!','replay finish: no second free pack promised')
frames(60*5);nothingLeft('after the replay')
-- Step 5 ignored: it finishes by itself after its time, so the free pack still comes.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',31);player:SetAttribute('TutorialStep',5);serverStep={Kind='Treadmill',Target=V3(12,3,-6)};root.CFrame=CF(0,3,20)
local cut=#commands;frames(60*20)
local sent=false;for i=cut+1,#commands do if commands[i]=='TreadmillInfo'then sent=true end end
check(not sent and card.Instruction.Text=='GET FASTER!','step 5 waits a while')
frames(60*(Guide.Steps[5].Seconds-18))
sent=false;for i=cut+1,#commands do if commands[i]=='TreadmillInfo'then sent=true end end
check(sent and player:GetAttribute('TutorialDone')==true,'step 5 finishes by itself after '..Guide.Steps[5].Seconds..' s')
frames(60*5);nothingLeft('after a timed-out step 5')
-- Skip with two taps: no finish card, nothing left.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,90)};frames(30)
check(card.Visible and gui.Enabled and tapGui.Enabled,'replay shows the card again (ScreenGuis back on)')
card.Skip.Activated:Fire();frames(5);check(card.StepPill.Visible and card.StepPill.Label.Text=='SKIP?','first tap arms skip');check(table.find(commands,'Skip')==nil,'one tap does not skip')
card.Skip.Activated:Fire();frames(30);check(table.find(commands,'Skip')~=nil,'second tap skips')
nothingLeft('after skipping');frames(60*4);check(not card.StepPill.Visible,'the SKIP? pill goes away')

-- Phone landscape (844x390, safe area): the card fits inside, clear of the top bar row, with a big X.
UIS.TouchEnabled=true;VIEW=R.Vector2.new(844,390);gui.AbsoluteSize=VIEW
baseB.AbsolutePosition=R.Vector2.new(342,-40);trackB.AbsolutePosition=R.Vector2.new(422,-40)
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialStep',1);root.CFrame=CF(0,3,0);frames(40)
says('GO TO THE TRACK!','[TRACK] tap it','phone: off the track')
local left=card.Position.X.Offset-card.Size.X.Offset/2;local right=left+card.Size.X.Offset;local top=card.Position.Y.Offset-12;local bottom=card.Position.Y.Offset+card.Size.Y.Offset
check(left>=8 and right<=844-8 and top>=0 and bottom<=390-8,('phone: the card is inside the safe area (%d..%d x %d..%d)'):format(left,right,top,bottom))
check(bottom<=390*.42,'phone: the card stays above your character ('..bottom..')')
check(card.Skip.Size.X.Offset>=40,'phone: a big X to tap ('..card.Skip.Size.X.Offset..')')
check(card.Instruction.UITextSizeConstraint.MaxTextSize>=26 and card.Hint.Label.TextSize>=16,'phone: big words')
check(ringOn(trackB),'phone: the TRACK button is ringed')
check(card.Size.X.Offset<460,'phone: the card hugs its words ('..card.Size.X.Offset..')')
inputFree('phone')
-- Phone, opening the pack: the clicking indicator is smaller and stays between the card and the hotbar.
do local Hud=req(hudModule);local m=Hud.Read(VIEW,true,nil);local barTop=390-m.HotbarBottom-m.SlotSize-(m.HotbarDetails~=false and 44 or 0)
 local t2=new('Tool');t2.Name='Forest Pack';t2:SetAttribute('SeedPackTool',true);t2.Parent=character
 local b2=new('Model');b2.Name='CarriedSeed';b2:SetAttribute('SeedPackCarry',true);b2:SetAttribute('PackClicksRequired',5);b2:SetAttribute('PackClickCount',1)
 local p2=new('Part');p2.CFrame=CF(2,4,3);p2.Parent=b2;b2.PrimaryPart=p2;b2.Parent=character
 player:SetAttribute('TutorialStep',3);frames(90)
 local ch=gui.ClickHint;local k=ch.UIScale.Scale;local y=ch.Position.Y.Offset
 check(ch.Visible and k<.8,'phone: a smaller clicking indicator ('..k..')')
 check(y+95*k<=barTop+1 and y-95*k>=card.Position.Y.Offset+card.Size.Y.Offset-14,('phone: it sits between the card and the hotbar (%d..%d, bar at %d)'):format(y-95*k,y+95*k,barTop))
 b2:Destroy();t2:Destroy()
end
-- Returning players: a fresh start with a finished tutorial shows nothing and builds nothing.
scriptInst.Destroying:Fire();frames(2);check(trail()==nil and pg:FindFirstChild('BeginnerTutorial')==nil and pg:FindFirstChild('BeginnerTutorialTap')==nil,'script cleanup removes everything')
player:SetAttribute('TutorialDone',true);player:SetAttribute('TutorialStep',0);player:SetAttribute('TutorialMask',255)
local again=new('LocalScript');again.Name='BeginnerTutorial';local cmdStart=#commands
local ok2,err2=pcall(load,'BeginnerTutorial',again);check(ok2,'reload: '..tostring(err2))
movedBefore=moved;frames(120)
local gui2=pg:FindFirstChild('BeginnerTutorial')
check(gui2 and not gui2.GuideCard.Visible and trail()==nil and gui2.Enabled==false and pg.BeginnerTutorialTap.Enabled==false,'returning player: no card, no world pieces, the ScreenGuis off')
check(moved==movedBefore and #commands-cmdStart<=1,'returning player: no per-frame work, one state check at most')
again.Destroying:Fire()
print(('%d checks, %d failures'):format(checks,fails))
