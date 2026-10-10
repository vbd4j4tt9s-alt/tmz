--!nocheck
-- R158e (owner: "shorten it even more ... a red arrow that points players towards the pack when they spawn ... the track tp button ... steal ... the visual mouse indicator ... tp back
-- to base ... plant ... the first fruit is always 10 seconds ... harvest and sell ... the treadmill makes them run faster and every 6 mins gives them a bonus roll ... EVERYTHING ...
-- must be visual so no words"): the real BeginnerTutorial + BeginnerGuide + HudLayout + PropCache152 on the Roblox mock. Walks the ten steps one at a time (each moves on by itself),
-- with every pointer they show: the big red 3D arrow (in front of you pointing the way when the goal is far, over the goal pointing down when near), the chevrons and the beam, the key
-- bubble (+ hold ring), the 👇 on the dirt, the ring timer, the red arrow + ring + pressing hand on TRACK / BASE / a hotbar slot / the market's buttons (the BONUS ROLL button without the
-- hand), the screen-edge arrow, the R138 clicking hand (any pack counts); NO WORD anywhere at any moment on any
-- device (key glyphs only in key caps); the clock reads the bonus interval (never a number written in the script); caught / back on the track / not home; skip; the finish; Reduced
-- Motion; no writes while hidden or idle; the phone safe area; returning players. (R138 / R152 checks kept: the chevron geometry and fade, the clicking indicator, nothing takes input.)
local R=require('./roblox');local B=require('./tut_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
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
-- The track starts at z=50 (the line between the bases and the track), x=0 is its middle. Your base pad: 100 x 100 round (0, -20).
local motion=new('ModuleScript');motion.Name='RunnerMotion';motion:SetAttribute('TrackBoundaryZ',50);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',114);motion.Parent=RS
local HOME_CF,HOME_SIZE=CF(0,0,-20),V3(100,1,100)
-- Remote: returns what the server points at for the current step and records commands.
local remotes=new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local request=new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
local commands={};local serverStep={Kind='Pack',Target=V3(40,3,90)}
function request.InvokeServer(_,action,value)
 check(action=='Tutorial','remote action')
 commands[#commands+1]=value
 local step=player:GetAttribute('TutorialStep')or 0
 if value=='Skip'or value=='TreadmillInfo'then player:SetAttribute('TutorialDone',true);player:SetAttribute('TutorialStep',0);step=0 end
 return {Success=true,Step=step,Kind=serverStep.Kind,Target=serverStep.Target,WaitingForPack=serverStep.Waiting,HomeCFrame=HOME_CF,HomeSize=HOME_SIZE,
  ReadyAt=serverStep.ReadyAt,ReadyIn=serverStep.ReadyIn,Ripe=serverStep.Ripe}
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
-- The market window (EconomyClient): its Buy / Sell crops modes and the Sell all button.
local econ=new('ScreenGui');econ.Name='ChestEconomyUI';econ.Parent=pg
local panel=new('Frame');panel.Name='EconomyPanel';panel.Parent=econ
local modes=new('Frame');modes.Name='MarketModes';modes.Parent=panel
local sellMode=new('TextButton');sellMode.Name='SellMode';sellMode.AbsolutePosition=R.Vector2.new(660,170);sellMode.AbsoluteSize=R.Vector2.new(300,36);sellMode.Parent=modes
local harvestMenu=new('Frame');harvestMenu.Name='HarvestSellMenu';harvestMenu.Visible=false;harvestMenu.Parent=panel
local summary=new('Frame');summary.Name='BagSummary';summary.Parent=harvestMenu
local sellAll=new('TextButton');sellAll.Name='SellAll';sellAll.AbsolutePosition=R.Vector2.new(820,220);sellAll.AbsoluteSize=R.Vector2.new(132,40);sellAll.Parent=summary
-- The BONUS ROLL button (TreadmillBonusClient).
local bonusHud=new('ScreenGui');bonusHud.Name='TreadmillBonusHud';bonusHud.Parent=pg
local bonusB=new('TextButton');bonusB.Name='BonusRollButton';bonusB.AbsolutePosition=R.Vector2.new(1040,560);bonusB.AbsoluteSize=R.Vector2.new(190,58);bonusB.Parent=bonusHud
-- Modules: real BeginnerGuide + HudLayout + PropCache152; small stubs for art/audio helpers and the bonus rules (only IntervalSeconds is read).
local modules={}
local function module(name,value)local m=new('ModuleScript');m.Name=name;m.Parent=RS;modules[m]=value;return m end
local sounds={}
module('GardenTheme',{Corner=function(p,r)local c=new('UICorner');c.Parent=p;return c end})
module('GardenDisplayNames',{Tool=function(tool)return tool.Name end})
module('PlantCatalog',{})
module('InteractionAudio',{Play=function(k)sounds[#sounds+1]=k;return true end})
local bonusRules={IntervalSeconds=360};module('TreadmillBonusRules',bonusRules)
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
player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1)
local scriptInst=new('LocalScript');scriptInst.Name='BeginnerTutorial'
local ok,err=pcall(load,'BeginnerTutorial',scriptInst);check(ok,'script loads: '..tostring(err))
frames(30)
local gui=pg:FindFirstChild('BeginnerTutorial');check(gui~=nil,'gui created')
local card=gui.GuideCard
local tapGui=pg:FindFirstChild('BeginnerTutorialTap');local tapUi=tapGui and tapGui.TapHand
local function trail()return workspace:FindFirstChild('TutorialTrail')end
-- The picture row as text: emoji / ➜ / numbers as they are, a key cap as [K], a button pill as <Track>.
local function row(r)
 local out={}
 local line=card:FindFirstChild('Row'..(r or 1));if not line or not line.Visible then return''end
 for i=1,5 do local t=line['Tile'..i];if t.Visible then
  if t.Cap.Visible and t.Cap.Key.Text~=''then out[#out+1]='['..t.Cap.Key.Text..']'
  elseif t.Cap.Visible then out[#out+1]='<'..(t.Glyph.Text=='🏃'and'Track'or'Base')..'>'
  else out[#out+1]=t.Glyph.Text end
 end end
 return table.concat(out,' ')
end
local function shows(icon,row1,msg,row2)
 check(card.Visible and card.StepIcon.Glyph.Text==icon and row(1)==row1 and(row2==nil or row(2)==row2),msg..' ('..tostring(card.StepIcon.Glyph.Text)..' | '..row(1)..' | '..row(2)..')')
end
local function shownChevrons()local n=0;local t=trail();if t then for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'and p.Transparency<1 then n+=1 end end end;return n end
local function beamAt()local t=trail();local b=t and t:FindFirstChild('GoalBeam');return b and b.Transparency<1 and b.CFrame.Position or nil end
local function near(a,x,z,tol)return a~=nil and math.abs(a.X-x)<(tol or 1.5)and math.abs(a.Z-z)<(tol or 1.5)end
-- The big red 3D arrow: its 6 parts (3 neon red, 3 white rims), the tip and the way it points (the head's two wedges and the shaft: the tip is the head's front end).
local function arrowParts()local out={};local t=trail();if t then for _,p in ipairs(t:GetChildren())do if p.Name=='GuideArrow'then out[#out+1]=p end end end;return out end
local function arrowShown()local ps=arrowParts();return #ps==6 and ps[1].Transparency==0 and ps[3].Transparency==0 end
local function arrowFrame()
 -- the arrow's own frame from the shaft: the shaft sits at (0,0,HEAD_L+SHAFT_L/2-.05) = 5.55 studs behind the tip along the arrow's +Z
 local shaft=arrowParts()[3];local c=shaft.CFrame;local back=V3(c.R[1][3],c.R[2][3],c.R[3][3])
 return c.Position-back*5.55,-back -- tip, the way it points
end
local function ringOn(b)return tapUi.Visible and math.abs(tapUi.Ring.Position.X.Offset-(b.AbsolutePosition.X-6))<1 and math.abs(tapUi.Ring.Position.Y.Offset-(b.AbsolutePosition.Y-6))<1 end
-- The red arrow on the screen button: next to it, pointing at it.
local function pointerAt(b)
 local p=tapUi.Pointer;if not(tapUi.Visible and p.Visible)then return false end
 local px,py=p.Position.X.Offset,p.Position.Y.Offset;local cx,cy=b.AbsolutePosition.X+b.AbsoluteSize.X/2,b.AbsolutePosition.Y+b.AbsoluteSize.Y/2
 local r=math.rad(p.Rotation);local dirX,dirY=-math.sin(r),math.cos(r) -- (the arrow points down in its box; Rotation turns it clockwise)
 local tx,ty=cx-px,cy-py;local len=math.sqrt(tx*tx+ty*ty)
 return len>20 and len<160 and(dirX*tx+dirY*ty)/len>.9
end
local function pressing()return tapUi.Hand.Visible and tapUi.Ripple.Visible end
-- R158e: no word anywhere: every text the two ScreenGuis (and the billboards in them) show is wordless; a key glyph only in a key cap.
local function wordless(where)
 local bad={}
 local all=gui:GetDescendants();for _,o in ipairs(tapGui:GetDescendants())do all[#all+1]=o end
 for _,o in ipairs(all)do
  if(o:IsA('TextLabel')or o:IsA('TextButton'))and o.Text~=''then
   if not Guide.Wordless(o.Text,o:GetAttribute('KeyGlyph')==true)then bad[#bad+1]=o.Name..'="'..o.Text..'"'end
  end
 end
 check(#bad==0,where..': no word on screen ('..table.concat(bad,', ')..')')
end
-- Nothing in the tutorial takes a click or tap except the small two-tap ⏭.
local function inputFree(where)
 local buttons,active={},{}
 local all=gui:GetDescendants();for _,o in ipairs(tapGui:GetDescendants())do all[#all+1]=o end
 for _,o in ipairs(all)do
  if o:IsA('GuiButton')then buttons[#buttons+1]=o.Name end
  if o:IsA('GuiObject')and o.Active==true and not o:IsA('GuiButton')then active[#active+1]=o.Name end
  if o.Modal==true then active[#active+1]=o.Name..'(Modal)'end
 end
 check(#buttons==1 and buttons[1]=='Skip'and #active==0,where..': only the ⏭ takes input (buttons: '..table.concat(buttons,',')..' / active: '..table.concat(active,',')..')')
end
local function popped(msg)
 check(card.StepIcon.Glyph.Text=='✓'and row(1)==''and not card.Row2.Visible,msg..': the green ✓ pop ('..card.StepIcon.Glyph.Text..' | '..row(1)..')')
 check(sounds[#sounds]=='Bubble06',msg..': pop sound')
 check(shownChevrons()==0 and not gui.Goal.Enabled and not tapUi.Visible and not arrowShown(),msg..': the pointers wait for the next step')
end
local function dot(i)return card.Progress['Dot'..i]end
local function current(i)return dot(i).Size.X.Offset>dot(i==1 and 2 or 1).Size.X.Offset and dot(i).Glyph.Text==Guide.Progress[i]end

-- 1. A brand-new player at the base: the big red arrow points at the pack. -----------------------------------------------------------
check(gui.ScreenInsets==R.Enum.ScreenInsets.CoreUISafeInsets,'the tutorial lives inside the safe area (notch / home bar / top bar)')
check(tapGui and tapGui.ScreenInsets==R.Enum.ScreenInsets.None and tapGui.DisplayOrder>26,'the button pointer has its own no-inset layer above the card, hotbar and BONUS ROLL')
check(card:FindFirstChild('Instruction')==nil and card:FindFirstChild('Hint')==nil and card:FindFirstChild('NameTag')==nil,'no title, no chip, no name tag: the card has no words')
shows('🎯','🏃 ➜ 🎒','step 1: the spawn arrow')
check(current(1),'step row: step 1 is the current one')
check(arrowShown(),'step 1: the big red 3D arrow is out')
do local tip,dir=arrowFrame();local to=(V3(40,0,90)-V3(0,0,0)).Unit;local flat=(V3(tip.X,0,tip.Z)-V3(0,0,0))
 check(flat.Magnitude>11 and flat.Magnitude<15 and(flat.Unit):Dot(to)>.97 and tip.Y>4,('far from the pack it floats ahead of you on the way, above your head (%.1f studs, dot %.2f)'):format(flat.Magnitude,flat.Unit:Dot(to)))
 check(V3(dir.X,0,dir.Z).Unit:Dot(to)>.97 and dir.Y>.2 and dir.Y<.6,'and points the way to the pack (its tip lifted, its face to the camera)')
 local red,white=0,0;for _,p in ipairs(arrowParts())do if p.Material==R.Enum.Material.Neon and p.Color.R>.9 and p.Color.G<.3 then red+=1 elseif p.Color.R>.9 and p.Color.G>.9 then white+=1 end end
 check(red==3 and white==3,'the arrow is neon red with a white rim ('..red..' red, '..white..' white)')
 local wedges=0;for _,p in ipairs(arrowParts())do if p.ClassName=='WedgePart'then wedges+=1 end;check(p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p.Anchored==true,'arrow part '..p.Name..': no collision, no query, anchored')end
 check(wedges==4,'the head is two wedges (and two rims)')
end
check(beamAt()and near(beamAt(),40,90),'a light beam on the pack');check(shownChevrons()>=5,'red chevrons on the ground to it ('..shownChevrons()..')')
check(gui.Goal.Enabled and gui.Goal.Bubble.Visible and gui.Goal.Bubble.Icon.Text=='🎒'and gui.Goal.StudsOffsetWorldSpace.Y>11,'a 🎒 bubble over the pack, above the arrow')
check(not tapUi.Visible,'step 1 points at no button yet')
check(sounds[1]=='Bubble04','a hello pop when the card first shows')
check(not card.StepPill.Visible and card.Skip.Text=='⏭','skip is the ⏭ icon')
check(card.Guide.Avatar.Visible and card.Guide.Avatar.Image:find('777',1,true)~=nil,'the owner\'s face guides you')
check(type(pg:GetAttribute('TutorialCardBottom'))=='number','notice reservation published')
wordless('step 1');inputFree('step 1')
-- The pack moves (taken by someone else): the arrow points at the next one.
serverStep={Kind='Pack',Target=V3(-60,3,95)};frames(70)
do local tip=arrowFrame();check(V3(tip.X,0,tip.Z).Unit:Dot(V3(-60,0,95).Unit)>.97,'the pack was taken: the arrow turns to the next one')end
-- 2. After the spawn arrow's few seconds: the TRACK button (no pop: nothing was done yet).
local before=#sounds
frames(60*Guide.IntroSeconds+10)
shows('🏃','🖱️ ➜ <Track>','step 2: the TRACK button');check(current(2),'step row: step 2')
check(ringOn(trackB)and pressing(),'a pulsing ring + a pressing hand on TRACK')
check(pointerAt(trackB)and tapUi.Pointer.Rotation==180,'a red arrow under TRACK points up at it')
check(arrowShown(),'the 3D arrow still shows the way to the pack')
check(card.Position.Y.Offset>=trackB.AbsolutePosition.Y+trackB.AbsoluteSize.Y+20,'the card sits below the pressing hand ('..card.Position.Y.Offset..')')
check(#sounds==before,'no pop for the spawn arrow\'s time running out')
wordless('step 2');inputFree('step 2')
do local lo,hi=1,0;for _=1,50 do frames(1);local k=tapUi.Hand.Press.Scale;lo=math.min(lo,k);hi=math.max(hi,k)end;check(lo<.95 and hi>.99,'the finger keeps pressing')end
-- 3. On the track (the TRACK button took you there): pop, then the pack with your steal key.
serverStep={Kind='Pack',Target=V3(40,3,90)};root.CFrame=CF(0,3,60);frames(12)
popped('on the track')
frames(45)
shows('🎒','[E] ➜ 🎒','step 3: steal (mouse: E, hold)');check(current(3),'step row: step 3')
check(card.Row1.Tile1.Hold.Visible,'the key tile has a hold ring (hold it)')
check(gui.Goal.Enabled and gui.Goal.Cap.Visible and gui.Goal.Cap.Key.Text=='E'and gui.Goal.Hold.Visible,'over the pack: E in a key cap with a hold ring')
check(not tapUi.Visible,'no button pointer on the track')
check(beamAt()and near(beamAt(),40,90),'the beam on the pack')
-- Chevrons: straight from the feet to the pack, on the ground, pointing at it.
local t=trail();check(t~=nil,'trail folder');local count=0;for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'then count+=1 end end
check(count==36,'36 chevrons built');check(moved>10,'trail animated with BulkMoveTo')
local L;for _,p in ipairs(t:GetChildren())do if p.Name=='ArmL'and not L and p.Transparency<.5 then L=p end end
local idx=table.find(t:GetChildren(),L);local Rt=t:GetChildren()[idx+1]
check(Rt.Name=='ArmR','arm pairing')
local tipDir=(L.CFrame.LookVector+Rt.CFrame.LookVector).Unit;local routeDir=(V3(40,0,90)-V3(0,0,60)).Unit
check(tipDir:Dot(routeDir)>.7,('chevron points along route (dot=%.2f)'):format(tipDir:Dot(routeDir)))
check(math.abs((L.CFrame.Position+Rt.CFrame.Position).Y/2-.09)<.05,'chevrons sit on the ground')
-- R153 (owner: "fix all jittery type effects"): a chevron fading in at the feet / out at the goal changes on every drawn frame at 30 / 60 fps and in steps of at most 1/100 + the
-- frame's own fade at 144 fps.
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
 local perFrame=4.5/fps/1.5
 check(fading>10 and worstStep<=perFrame+.011,string.format('R153: at %d fps the chevrons fade in fine steps (%d fading frames, the biggest step %.3f, the fade itself %.3f a frame)',fps,fading,worstStep,perFrame))
 if fps<=60 then check(stalls==0,string.format('R153: at %d fps a fading chevron changes on every frame (%d repeated)',fps,stalls))end
end
-- The 3D arrow bobs along the way it points (not with Reduced Motion).
do local lo,hi=math.huge,-math.huge;for _=1,60 do frames(1);local tip=arrowFrame();local d=(V3(tip.X,0,tip.Z)-V3(0,0,60)).Magnitude;lo=math.min(lo,d);hi=math.max(hi,d)end
 check(hi-lo>.5 and hi-lo<1.5,('the far arrow bobs toward the pack (%.2f studs)'):format(hi-lo))end
-- Close to the pack: the arrow hovers over it, pointing down, its flat side to the camera.
root.CFrame=CF(30,3,80);frames(10)
do local tip,dir=arrowFrame();check(near(tip,40,90,.6)and tip.Y>6 and tip.Y<8.6 and dir.Y<-.97,('near the pack: over it, pointing down (tip %s, way %s)'):format(tostring(tip),tostring(dir)))
 local face=V3(arrowParts()[3].CFrame.R[1][2],arrowParts()[3].CFrame.R[2][2],arrowParts()[3].CFrame.R[3][2]);local toCam=(V3(0,0,-30)-V3(40,0,90)).Unit
 check(face:Dot(toCam)>.97,'its flat side faces the camera')
end
root.CFrame=CF(39,3,88);frames(10);check(shownChevrons()==0 and beamAt()~=nil and arrowShown(),'at the pack: the chevrons hide, the beam and the arrow stay')
-- The pack moves out of view: the red arrow at the screen edge points at it.
serverStep={Kind='Pack',Target=V3(400,3,90)};frames(70)
check(gui.Direction.Visible,'the goal off screen: the red arrow at the screen edge')
do local e=gui.Direction;local r=math.rad(e.Rotation);check(-math.sin(r)>.9,'and it points right, toward it ('..e.Rotation..')')end
serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70);check(not gui.Direction.Visible,'back on screen: no edge arrow')
-- No pack yet: ⏳.
serverStep={Kind='Pack',Waiting=true};frames(70);shows('⏳','🎒 ⏳','no packs out yet')
check(shownChevrons()==0 and not gui.Goal.Enabled and not arrowShown(),'no pointer while waiting')
serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70);shows('🎒','[E] ➜ 🎒','a pack shows up')
wordless('step 3');inputFree('step 3')
-- Picked up: carry it home (the arrow points at the home line; no TRACK / BASE while carrying).
before=#sounds
serverStep={Kind='Safety',Target=V3(0,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);frames(6)
popped('picked it up');check(#sounds>before,'a sound for the pop')
frames(60);shows('🏠','🎒 ➜ 🏠','step 3: carry it home')
check(beamAt()and near(beamAt(),0,38),'the beam on the home line');check(arrowShown(),'the arrow points home')
check(not tapUi.Visible,'no teleport button while carrying (you can\'t teleport with a pack)')
-- Caught (the pack is gone): back to the pack, no pop.
before=#sounds;player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70)
shows('🎒','[E] ➜ 🎒','caught: back to the pack');check(#sounds==before,'no pop going backwards')
serverStep={Kind='Safety',Target=V3(0,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);frames(60)

-- 4. Banked: open a pack (owner: "the player can open ANY pack and it will count"; the new-player gift pack sits next to it). ----------
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil};root.CFrame=CF(0,3,45)
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool:SetAttribute('SeedInventoryId','301_2');tool:SetAttribute('PackNumber',2);tool.Parent=backpack
local gift=new('Tool');gift.Name='Gift Verity Pack';gift:SetAttribute('SeedPackTool',true);gift:SetAttribute('SeedInventoryId','301_1');gift:SetAttribute('PackNumber',9);gift.Parent=backpack
dock.Slot2.ItemName.Text='Forest Pack';dock.Slot3.ItemName.Text='Gift Verity Pack'
player:SetAttribute('TutorialStep',4);frames(6)
popped('banked')
frames(60)
shows('🎁','🖱️ ➜ 🎁','step 4: open it (its slot first)');check(current(4),'step row: step 4')
check(ringOn(dock.Slot3)and pressing()and pointerAt(dock.Slot3),'a red arrow + ring + pressing hand on a pack\'s slot (the newest)')
check(shownChevrons()==0 and not gui.Goal.Enabled and not arrowShown(),'no world pointer on step 4')
wordless('step 4 (slot)');inputFree('step 4 (slot)')
-- In your hand: the R138 clicking hand, no words.
tool.Parent=character;frames(20)
shows('🎁','🖱️ ➜ 🎁','a pack in hand (any)');check(not tapUi.Visible,'the slot pointer goes once a pack is in your hand')
local bag=new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('PackClicksRequired',5);bag:SetAttribute('PackClickCount',0)
local bagPart=new('Part');bagPart.CFrame=CF(2,4,3);bagPart.Parent=bag;bag.PrimaryPart=bagPart;bag.Parent=character;frames(10)
local hintUi=gui.ClickHint
local function lit()local n=0;for i=1,5 do local p=hintUi.Pips:FindFirstChild('Pip'..i);if p and p.Visible and p.BackgroundColor3.R>.9 then n+=1 end end;return n end
check(hintUi.Visible and hintUi.Hand.Text=='🖱️'and not hintUi.Cap.Visible and hintUi:FindFirstChild('Word')==nil,'the clicking indicator: a mouse that keeps clicking, no word')
check(lit()==0 and hintUi.Pips.Pip5.Visible,'five pips, none lit yet')
local lowest,highest=1,0;for _=1,40 do frames(1);local k=hintUi.Hand.UIScale.Scale;lowest=math.min(lowest,k);highest=math.max(highest,k)end
check(lowest<.9 and highest>.99,'the hand keeps pressing')
bag:SetAttribute('PackClickCount',2);frames(2);check(lit()==2,'each click lights a pip')
wordless('step 4 (clicking)')
-- Phone: a finger; gamepad: the pad and its R2 key cap.
UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
shows('🎁','👆 ➜ 🎁','touch: a finger');check(hintUi.Visible and hintUi.Hand.Text=='👆'and not hintUi.Cap.Visible,'touch: the finger taps')
lastInput=R.Enum.UserInputType.Gamepad1;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
shows('🎁','[R2] ➜ 🎁','gamepad: R2 as a key cap');check(hintUi.Hand.Text=='🎮'and hintUi.Cap.Visible and hintUi.Cap.Key.Text=='R2','gamepad: the pad + the R2 key cap')
wordless('step 4 (gamepad)')
lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
-- The menu wheel hides the card (and its pointers), then it comes back. Hidden, nothing is written per frame.
pg:SetAttribute('GardenMenuExpanded',true);frames(2);check(not card.Visible and not hintUi.Visible and pg:GetAttribute('TutorialCardBottom')==nil,'card + pointers hide while the menu is open')
do local w,m=writes,moved;frames(120);check(writes==w and moved==m,'card hidden: no property writes, no trail moves for 2 s ('..(writes-w)..' writes)')end
pg:SetAttribute('GardenMenuExpanded',false);frames(2);check(card.Visible,'card returns')

-- 5. It opens (you were by the track line): the reveal plays, then the BASE button. ----------------------------------------------------
bag:SetAttribute('RevealAt',123);frames(2);check(not hintUi.Visible,'the clicking indicator goes once the pack opens')
bag:Destroy();tool:Destroy();dock.Slot2.ItemName.Text=''
local seed=new('Tool');seed.Name='Carrot Seed';seed:SetAttribute('GardenSeed',true);seed:SetAttribute('SeedInventoryId','301_2');seed.Parent=character
serverStep={Kind='Garden',Target=V3(-20,3,10)};root.CFrame=CF(150,3,40);player:SetAttribute('TutorialStep',6);frames(6)
popped('opened')
frames(60);check(card.StepIcon.Glyph.Text=='✓','the pop waits while the reveal plays')
player:SetAttribute('RarePullCinematic','Mythic');frames(2);check(not card.Visible,'a rare pull\'s cinematic hides the card')
player:SetAttribute('RarePullCinematic',nil);frames(100)
shows('🏠','👆 ➜ <Base>','step 5: away from home: the BASE button');check(current(5),'step row: step 5')
check(ringOn(baseB)and pressing()and pointerAt(baseB),'a red arrow + ring + pressing hand on BASE')
check(not arrowShown()and shownChevrons()==0,'no world pointer while BASE is asked')
wordless('step 5');inputFree('step 5')

-- 6. Home (BASE took you there): pop, then the dirt. -----------------------------------------------------------------------------------
root.CFrame=CF(0,3,5);frames(12);popped('home')
frames(50);shows('🌱','👆 ➜ 🟫','step 6: plant it (touch)');check(current(6),'step row: step 6')
check(beamAt()and near(beamAt(),-20,10),'the beam on the garden dirt')
check(gui.TapSpot.Enabled and gui.TapSpot.Hand.Text=='👇'and not gui.Goal.Enabled,'a pressing 👇 on the dirt')
do local tip,dir=arrowFrame();check(arrowShown()and near(tip,-20,10,.6)and dir.Y<-.97,'the red arrow over the dirt, pointing down')end
-- Reduced Motion, standing still: nothing changes, so nothing is written or moved.
Gui.ReducedMotionEnabled=true;frames(10)
do local w,m=writes,moved;frames(60);check(writes==w and moved==m,'Reduced Motion, standing still: no writes, no moves for 1 s ('..(writes-w)..' writes, '..(moved-m)..' moves)')end
check(gui.TapSpot.Enabled and arrowShown(),'Reduced Motion: the hand and the arrow still show (still)')
Gui.ReducedMotionEnabled=false;frames(2)
do local w=writes;frames(60);local per=(writes-w)/60;check(per<60,('animated step 6: %.1f writes per frame (only what moves)'):format(per))end
wordless('step 6');inputFree('step 6')
-- The seed went back to the Bag: its slot.
seed.Parent=backpack;dock.Slot1.ItemName.Text='Carrot Seed';frames(20)
shows('🌱','👆 ➜ 🌱','seed not in hand');check(ringOn(dock.Slot1)and pointerAt(dock.Slot1),'a red arrow + ring + hand on the seed\'s slot')
check(shownChevrons()==0 and not gui.TapSpot.Enabled,'no world pointer until the seed is in hand')
seed.Parent=character;frames(12);popped('seed in hand');frames(50);shows('🌱','👆 ➜ 🟫','back to the dirt')
-- Ran off to the track: BASE again.
root.CFrame=CF(0,3,80);frames(12);shows('🏠','👆 ➜ <Base>','on the track in step 6: BASE');check(ringOn(baseB),'BASE ringed')
root.CFrame=CF(-10,3,5);frames(12);popped('back home');frames(50);shows('🌱','👆 ➜ 🟫','home again')

-- 7. Planted: the first fruit grows in 10 s (a ring timer over the plant). -------------------------------------------------------------
seed:Destroy();dock.Slot1.ItemName.Text=''
serverStep={Kind='Crop',Target=V3(-20,5,10),ReadyAt=1000010,ReadyIn=10,Ripe=false};player:SetAttribute('TutorialStep',7);frames(6);popped('planted');frames(50)
shows('⏳','🌱 ⏱️ 10','step 7: the 10-second timer');check(current(7),'step row: step 7')
check(gui.GrowTimer.Enabled and gui.GrowTimer.Face.Seconds.Text=='10'and not gui.Goal.Enabled,'over the plant: the ring timer reads 10')
local function litTicks()local n=0;for i=1,12 do if gui.GrowTimer['Tick'..i].BackgroundColor3.G>.85 then n+=1 end end;return n end
check(litTicks()==0,'no tick lit yet');check(arrowShown(),'the red arrow over the plant')
frames(60*5)
check(gui.GrowTimer.Face.Seconds.Text=='4'or gui.GrowTimer.Face.Seconds.Text=='5','5 s later: about 5 left ('..gui.GrowTimer.Face.Seconds.Text..')')
check(litTicks()>=5 and litTicks()<=7,'and half the ring is lit ('..litTicks()..')')
check(row(1)=='🌱 ⏱️ '..gui.GrowTimer.Face.Seconds.Text,'the card\'s timer counts with it')
-- the server's next poll does not move the deadline
frames(60*2);local left=tonumber(gui.GrowTimer.Face.Seconds.Text);check(left==3 or left==2,'the polls keep the same deadline ('..tostring(left)..')')
wordless('step 7')

-- 8. Ripe: pick it. ---------------------------------------------------------------------------------------------------------------------
for _=1,60*6 do frames(1);if card.StepIcon.Glyph.Text=='✓'then break end end
frames(2);popped('ripe');frames(50)
shows('🍎','👆 ➜ 🍎','step 8: harvest (touch)');check(current(8),'step row: step 8')
check(gui.Goal.Enabled and gui.Goal.Bubble.Visible and gui.Goal.Bubble.Icon.Text=='👆'and not gui.GrowTimer.Enabled,'over the fruit: the 👆 to tap')
UIS.TouchEnabled=false;UIS.MouseEnabled=true;lastInput=R.Enum.UserInputType.MouseMovement;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
shows('🍎','[E] ➜ 🍎','mouse: E');check(gui.Goal.Cap.Visible and gui.Goal.Cap.Key.Text=='E'and not gui.Goal.Hold.Visible,'over the fruit: E (a press, no hold ring)')
wordless('step 8')
-- Walked away from home: BASE.
root.CFrame=CF(200,3,5);frames(20);shows('🏠','🖱️ ➜ <Base>','away from the plant: BASE');check(current(8)or current(7),'the step row keeps the step')
root.CFrame=CF(-10,3,5);frames(20)

-- 9. Harvested: sell it at the market. ----------------------------------------------------------------------------------------------------
serverStep={Kind='Sell',Target=V3(0,3,-120)};player:SetAttribute('TutorialStep',9);frames(6);popped('harvested');frames(50)
shows('💰','🍎 ➜ 💰','step 9: the market');check(current(9),'step row: step 9')
check(beamAt()and near(beamAt(),0,-120),'the beam on the market');check(arrowShown()and shownChevrons()>=5,'the arrow and the chevrons lead there')
check(gui.Goal.Enabled and gui.Goal.Bubble.Visible and gui.Goal.Bubble.Icon.Text=='💰','far away: the 💰 bubble (no key yet)')
root.CFrame=CF(0,3,-108);frames(10);check(gui.Goal.Cap.Visible and gui.Goal.Cap.Key.Text=='E','at the market: its key, E')
-- The market window: Sell crops, then Sell all (the pointer draws over the window).
pg:SetAttribute('SeedMenu','Economy');frames(20)
shows('💰','🖱️ ➜ 💰','the market window (Buy page): Sell crops')
check(card.Visible and ringOn(sellMode)and pointerAt(sellMode)and tapGui.DisplayOrder>30,'a red arrow + ring + hand on Sell crops, above the window')
harvestMenu.Visible=true;frames(20)
shows('💰','🖱️ ➜ 💵','the Sell crops page: Sell all');check(ringOn(sellAll)and pointerAt(sellAll),'on Sell all')
wordless('step 9');inputFree('step 9')
pg:SetAttribute('SeedMenu','Inventory');frames(5);check(not card.Visible,'another menu still hides the card')
pg:SetAttribute('SeedMenu',nil);harvestMenu.Visible=false;frames(5)

-- 10. Sold: the treadmill (faster) and the bonus roll every 6:00 (from TreadmillBonusRules). ----------------------------------------
serverStep={Kind='Treadmill',Target=V3(12,3,-6)};root.CFrame=CF(0,3,5);player:SetAttribute('TutorialStep',10);frames(6);popped('sold');frames(50)
shows('⚡','🏃 ➜ ⚡ ⬆️','step 10: the treadmill makes you faster','🕒 6:00 ➜ 🎁')
check(current(10),'step row: step 10')
check(beamAt()and near(beamAt(),12,-6)and arrowShown(),'the arrow and the beam on your treadmill')
check(ringOn(bonusB)and pointerAt(bonusB)and not pressing(),'a red arrow + ring on BONUS ROLL (just look: no pressing hand)')
check(table.find(commands,'TreadmillInfo')==nil,'step 10 waits for you')
wordless('step 10');inputFree('step 10')
-- The clock is read, not written: the bonus rules' interval, or what the server publishes.
bonusRules.IntervalSeconds=420;player:SetAttribute('TutorialStep',9);frames(3);player:SetAttribute('TutorialStep',10);frames(60)
check(row(2)=='🕒 7:00 ➜ 🎁','the clock follows TreadmillBonusRules.IntervalSeconds ('..row(2)..')')
player:SetAttribute('TreadmillBonusInterval',360);player:SetAttribute('TutorialStep',9);frames(3);player:SetAttribute('TutorialStep',10);frames(60)
check(row(2)=='🕒 6:00 ➜ 🎁','and the interval the server publishes first ('..row(2)..')');bonusRules.IntervalSeconds=360
player:SetAttribute('StarterPackClaimed',false);frames(2)
player:SetAttribute('TreadmillTraining',true);frames(3)
check(table.find(commands,'TreadmillInfo')~=nil,'stepping on the treadmill finishes the tutorial')
check(player:GetAttribute('TutorialDone')==true,'done')
-- The finish: 🏆 + 🎁 (the free pack), confetti, then nothing left.
shows('🏆','🎁','the finish card');check(sounds[#sounds]=='GemClaim'and gui.Confetti.Visible,'the gem sound and confetti')
check(trail()==nil,'the world pieces are gone as soon as it is done')
check(not tapUi.Visible and not gui.Goal.Enabled and not gui.TapSpot.Enabled and not gui.GrowTimer.Enabled and not gui.ClickHint.Visible,'no pointer on the finish card')
for i=1,10 do check(dot(i).Glyph.Text=='✓','finish: step '..i..' ticked')end
wordless('the finish')
frames(60*3);check(not gui.Confetti.Visible,'confetti clears')
frames(60*2);check(not card.Visible and pg:GetAttribute('TutorialCardBottom')==nil,'finish card gone after 4 s, reservation cleared')
local function nothingLeft(where)
 check(not card.Visible and not tapUi.Visible and not gui.Goal.Enabled and not gui.TapSpot.Enabled and not gui.GrowTimer.Enabled and not gui.ClickHint.Visible and not gui.Direction.Visible and not gui.Confetti.Visible and trail()==nil,where..': nothing left on screen or in the world')
 check(pg:GetAttribute('TutorialCardBottom')==nil,where..': no notice reservation')
end
nothingLeft('after finishing')
local movedBefore,cmdBefore,writesBefore=moved,#commands,writes;frames(120);check(moved==movedBefore and #commands==cmdBefore and writes==writesBefore,'idle after finishing: no writes, no trail work, no polling ('..(writes-writesBefore)..' writes)')
check(gui.Enabled==false and tapGui.Enabled==false,'idle: the tutorial ScreenGuis are off')
player:SetAttribute('TreadmillTraining',false)
-- (The tutorial is started again by hand below; the Replay request is refused since R158c.)
-- Step 10 ignored: it finishes by itself after its seconds, so the free pack still comes; the free pack already given: 🎉.
player:SetAttribute('StarterPackClaimed',true)
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',127);player:SetAttribute('TutorialStep',10);serverStep={Kind='Treadmill',Target=V3(12,3,-6)};root.CFrame=CF(0,3,5)
local cut=#commands;frames(60*5)
local sent=false;for i=cut+1,#commands do if commands[i]=='TreadmillInfo'then sent=true end end
check(not sent and card.StepIcon.Glyph.Text=='⚡','step 10 waits a while')
frames(60*(Guide.Steps[10].Seconds-3))
sent=false;for i=cut+1,#commands do if commands[i]=='TreadmillInfo'then sent=true end end
check(sent and player:GetAttribute('TutorialDone')==true,'step 10 finishes by itself after '..Guide.Steps[10].Seconds..' s')
shows('🏆','🎉','the free pack was given before: 🏆 🎉')
frames(60*5);nothingLeft('after a timed-out step 10')
-- No treadmill in your base: done at once.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',10);serverStep={Kind='Treadmill',Target=nil};frames(90)
check(player:GetAttribute('TutorialDone')==true,'no treadmill: step 10 finishes by itself');frames(60*5)
-- Resuming an old save (an R152 player who had planted: the server publishes 7): straight to the grow / harvest step.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',23);serverStep={Kind='Crop',Target=V3(-20,5,10),ReadyAt=1000099,ReadyIn=0,Ripe=true};player:SetAttribute('TutorialStep',7);frames(60)
shows('🍎','[E] ➜ 🍎','an old save at the plant step resumes at the harvest (its fruit is ripe)')
-- Already on the track when you spawn: straight to the pack (no spawn arrow, no TRACK).
player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,90)};root.CFrame=CF(0,3,70);frames(60)
shows('🎒','[E] ➜ 🎒','on the track already: straight to the pack')
-- Skip with two taps: no finish card, nothing left.
card.Skip.Activated:Fire();frames(5);check(card.StepPill.Visible and card.StepPill.Label.Text=='❓','first tap: ❓ (sure?)');check(table.find(commands,'Skip')==nil,'one tap does not skip')
wordless('skip armed')
card.Skip.Activated:Fire();frames(30);check(table.find(commands,'Skip')~=nil,'second tap skips')
nothingLeft('after skipping');frames(60*4);check(not card.StepPill.Visible,'the ❓ goes away')

-- Phone landscape (844x390, safe area): the card fits inside, clear of the top bar row, with a big ⏭.
UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);VIEW=R.Vector2.new(844,390);gui.AbsoluteSize=VIEW;tapGui.AbsoluteSize=VIEW
baseB.AbsolutePosition=R.Vector2.new(342,-40);trackB.AbsolutePosition=R.Vector2.new(422,-40)
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialStep',1);root.CFrame=CF(0,3,0);frames(60*6)
shows('🏃','👆 ➜ <Track>','phone: the TRACK button')
local function inside(where)
 local left=card.Position.X.Offset-card.Size.X.Offset/2;local right=left+card.Size.X.Offset;local top=card.Position.Y.Offset-12;local bottom=card.Position.Y.Offset+card.Size.Y.Offset
 check(left>=8 and right<=844-8 and top>=0 and bottom<=390-8,('%s: the card is inside the safe area (%d..%d x %d..%d)'):format(where,left,right,top,bottom))
 check(bottom<=390*.5,where..': the card stays above your character ('..bottom..')')
end
inside('phone step 2')
check(card.Skip.Size.X.Offset>=40,'phone: a big ⏭ to tap ('..card.Skip.Size.X.Offset..')')
check(card.Row1.Tile1.Size.Y.Offset>=28,'phone: big pictures')
check(ringOn(trackB),'phone: the TRACK button is ringed')
inputFree('phone');wordless('phone')
-- Phone, step 10: two picture rows still fit.
player:SetAttribute('TutorialStep',10);serverStep={Kind='Treadmill',Target=V3(12,3,-6)};root.CFrame=CF(0,3,5);frames(90)
shows('⚡','🏃 ➜ ⚡ ⬆️','phone step 10','🕒 6:00 ➜ 🎁');inside('phone step 10')
-- Phone, opening the pack: the clicking indicator is smaller and stays between the card and the hotbar.
do local Hud=req(hudModule);local m=Hud.Read(VIEW,true,nil);local barTop=390-m.HotbarBottom-m.SlotSize-(m.HotbarDetails~=false and 44 or 0)
 local t2=new('Tool');t2.Name='Forest Pack';t2:SetAttribute('SeedPackTool',true);t2:SetAttribute('SeedInventoryId','301_2');t2.Parent=character
 local b2=new('Model');b2.Name='CarriedSeed';b2:SetAttribute('SeedPackCarry',true);b2:SetAttribute('PackClicksRequired',5);b2:SetAttribute('PackClickCount',1)
 local p2=new('Part');p2.CFrame=CF(2,4,3);p2.Parent=b2;b2.PrimaryPart=p2;b2.Parent=character
 player:SetAttribute('TutorialStep',4);frames(90)
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
