--!nocheck
-- R158g (owner: "remove the box at the top from the tutorial entirely, and the big red arrow should only be used when necessary ... The tutorial should really just be arrows and that's
-- all"; "each arrow has to fulfil 1 purpose, not 2 fulfilling the same purpose"; "there will be no skip tutorial button"): the real BeginnerTutorial + BeginnerGuide + HudLayout + PropCache152
-- on the Roblox mock with a perspective camera behind the player. Walks the ten steps one at a time (each moves on by itself) and, at every moment, checks EXACTLY the pointers it wants:
-- the arrow for a world goal is one of three (hovering over it when it is on screen and near, the big floating arrow when it is far and in sight, the arrow at the screen edge when it
-- would be out of sight: never two for the one goal, in no frame), a red arrow + the pressing hand on a screen button (BONUS ROLL: the arrow alone), the pressing hand on the dirt, the
-- small ring timer, the R138 clicking hand; and NOTHING else: no card, no avatar, no icon, no picture, no step dots, no pops, no sound, no confetti, no chevrons / beam / ring, no key bubble,
-- no word, nothing that takes a click or tap (no skip). Reduced Motion, no writes while hidden or idle, the phone, returning players, the owner's reset.
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
-- A perspective camera (70 degrees) behind the player, looking where he faces (heading), as Roblox's WorldToViewportPoint: a point behind the camera is off screen.
local VW,VH=1280,720;local heading=V3(0,0,1);local aimOn=true;local aimKey
function camera.WorldToViewportPoint(_,p)
 local rel=camera.CFrame:Inverse()*p;local z=-rel.Z
 if z<=.1 then return V3(VW/2-rel.X*100,VH/2+rel.Y*100,-1),false end
 local F=(VH/2)/math.tan(math.rad(35));local sx,sy=VW/2+rel.X/z*F,VH/2-rel.Y/z*F
 return V3(sx,sy,z),sx>=0 and sx<=VW and sy>=0 and sy<=VH
end
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
local commands={};local serverStep={Kind='Pack',Target=V3(40,3,90)};local mockGrant=false -- (R158h: mockGrant = the server gives the free bonus roll at the 'BonusGift' ask)
function request.InvokeServer(_,action,value)
 check(action=='Tutorial','remote action')
 commands[#commands+1]=value
 local step=player:GetAttribute('TutorialStep')or 0
 if value=='BonusGift'and mockGrant then player:SetAttribute('TreadmillBonusReady',1)end
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
-- Modules: real BeginnerGuide + HudLayout + PropCache152; small stubs for art helpers and an audio module the tutorial must never use (any sound it asked for would be listed).
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
-- The camera follows the player (written only when he or his heading changes, so the write counters below stay honest); watchFn counts the frames that show two arrows for one goal.
local doubles,watchFn=0,nil
local function aim()
 if not aimOn then return end
 local at=root.CFrame.Position;local key=at.X..','..at.Y..','..at.Z..','..heading.X..','..heading.Z;if key==aimKey then return end;aimKey=key
 camera.CFrame=R.CFrame.lookAt(at-heading*15+V3(0,8,0),at+heading*12+V3(0,-1,0))
end
local function frames(n,dt)for _=1,n do aim();R.advance(dt or 1/60);Run.RenderStepped:Fire(dt or 1/60);Run.Heartbeat:Fire(dt or 1/60);if watchFn and watchFn()=='both'then doubles+=1 end end end
-- Run --------------------------------------------------------------------------
local Guide=req(guideModule)
player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1)
local scriptInst=new('LocalScript');scriptInst.Name='BeginnerTutorial'
local ok,err=pcall(load,'BeginnerTutorial',scriptInst);check(ok,'script loads: '..tostring(err))
frames(30)
local gui=pg:FindFirstChild('BeginnerTutorial');check(gui~=nil,'gui created')
local tapGui=pg:FindFirstChild('BeginnerTutorialTap');local tapUi=tapGui and tapGui.TapHand
local function trail()return workspace:FindFirstChild('TutorialTrail')end
local function near(a,x,z,tol)return a~=nil and math.abs(a.X-x)<(tol or 1.5)and math.abs(a.Z-z)<(tol or 1.5)end
-- The big red 3D arrow: its 6 parts (3 neon red, 3 white rims), the tip and the way it points (the head's two wedges and the shaft: the tip is the head's front end).
local function arrowParts()local out={};local t=trail();if t then for _,p in ipairs(t:GetChildren())do if p.Name=='GuideArrow'then out[#out+1]=p end end end;return out end
local function arrowShown()local ps=arrowParts();return #ps==6 and ps[1].Transparency==0 and ps[3].Transparency==0 end
local function arrowFrame()
 -- the arrow's own frame from the shaft: the shaft sits at (0,0,HEAD_L+SHAFT_L/2-.05) = 5.55 studs behind the tip along the arrow's +Z
 local shaft=arrowParts()[3];local c=shaft.CFrame;local back=V3(c.R[1][3],c.R[2][3],c.R[3][3])
 return c.Position-back*5.55,-back -- tip, the way it points
end
-- What the world goal's arrow is now: 'over' (hovering over the goal, pointing down), 'way' (the big floating arrow ahead of you), 'edge' (the red arrow at the screen edge), nil (none),
-- 'both' (two arrows for the one goal: never allowed).
local function worldArrow()
 local a3,e=arrowShown(),gui.Direction.Visible
 if a3 and e then return'both'end
 if a3 then local tip,dir=arrowFrame();local t=serverStep.Target;if t and near(tip,t.X,t.Z,.7)and dir.Y<-.9 then return'over'end;return'way'end
 if e then return'edge'end
 return nil
end
watchFn=worldArrow
-- The red arrow on the screen button: next to it, pointing at it.
local function pointerAt(b)
 local p=tapUi.Pointer;if not(tapUi.Visible and p.Visible)then return false end
 local px,py=p.Position.X.Offset,p.Position.Y.Offset;local cx,cy=b.AbsolutePosition.X+b.AbsoluteSize.X/2,b.AbsolutePosition.Y+b.AbsoluteSize.Y/2
 local r=math.rad(p.Rotation);local dirX,dirY=-math.sin(r),math.cos(r) -- (the arrow points down in its box; Rotation turns it clockwise)
 local tx,ty=cx-px,cy-py;local len=math.sqrt(tx*tx+ty*ty)
 return len>20 and len<170 and(dirX*tx+dirY*ty)/len>.9
end
-- R158g: the tutorial is only pointers: no word, nothing that takes a click or tap, no card or any piece of one.
local GONE={'GuideCard','Guide','StepIcon','Progress','Row1','Row2','StepPill','Skip','Avatar','PopRing','Confetti','Goal','Shine','Instruction','Hint','NameTag','Ring','Ripple'}
local function noBox(where)
 local bad={}
 local all=gui:GetDescendants();for _,o in ipairs(tapGui:GetDescendants())do all[#all+1]=o end
 for _,o in ipairs(all)do
  if o:IsA('GuiButton')then bad[#bad+1]=o.Name..'(button)'end
  if o:IsA('GuiObject')and o.Active==true and not o:IsA('GuiButton')then bad[#bad+1]=o.Name..'(active)'end
  if o.Modal==true then bad[#bad+1]=o.Name..'(Modal)'end
  if(o:IsA('TextLabel')or o:IsA('TextButton'))and o.Text~=''and not Guide.Wordless(o.Text,o:GetAttribute('KeyGlyph')==true)then bad[#bad+1]=o.Name..'="'..o.Text..'"'end
  if o:IsA('ImageLabel')then bad[#bad+1]=o.Name..'(image)'end
  for _,n in ipairs(GONE)do if o.Name==n and not(n=='Ripple'and o.Parent and(o.Parent.Name=='TapSpot'or o.Parent.Name=='ClickHint'))then bad[#bad+1]=o.Name end end
 end
 check(#bad==0,where..': no box, no word, nothing to click ('..table.concat(bad,', ')..')')
 check(pg:GetAttribute('TutorialCardBottom')==nil,where..': no notice reservation (there is no card to keep clear)')
 local t=trail();local extra={};if t then for _,p in ipairs(t:GetChildren())do if p.Name~='GuideArrow'and p.Name~='TutorialTarget'then extra[#extra+1]=p.Name end end end
 check(#extra==0,where..': in the world only the arrow (no chevrons, beam or ring: '..table.concat(extra,',')..')')
end
-- Exactly the pointers a moment wants, nothing else: want = {world = 'over' / 'way' / 'edge', button = <the screen button the red arrow points at>, press = false (the arrow alone), dirt, timer, click}.
local function pointers(where,want)
 want=want or{}
 local got=worldArrow()
 check(got==want.world,where..': the arrow for the goal is '..tostring(want.world)..' (got '..tostring(got)..')')
 if want.button then
  check(tapUi.Visible and pointerAt(want.button),where..': a red arrow at the '..want.button.Name)
  check(tapUi.Hand.Visible==(want.press~=false),where..(want.press~=false and': with the pressing hand'or': the arrow alone, no hand'))
 else check(not tapUi.Visible,where..': no button pointer')end
 check(gui.TapSpot.Enabled==(want.dirt==true),where..': the pressing hand on the dirt is '..tostring(want.dirt==true))
 check(gui.GrowTimer.Enabled==(want.timer==true),where..': the ring timer is '..tostring(want.timer==true))
 check(gui.ClickHint.Visible==(want.click==true),where..': the clicking hand is '..tostring(want.click==true))
 noBox(where)
end
local function nothing(where)pointers(where,{})end

-- 1. A brand-new player at the base: one red arrow points at the pack, nothing else. ---------------------------------------------------------------------
check(gui.ScreenInsets==R.Enum.ScreenInsets.CoreUISafeInsets,'the tutorial lives inside the safe area (notch / home bar / top bar)')
check(tapGui and tapGui.ScreenInsets==R.Enum.ScreenInsets.None and tapGui.DisplayOrder>26,'the button pointer has its own no-inset layer above the hotbar and BONUS ROLL')
check(gui:FindFirstChild('GuideCard')==nil and gui:FindFirstChild('Confetti')==nil and gui:FindFirstChild('Goal')==nil and tapUi:FindFirstChild('Ring')==nil,'no card, no confetti, no key bubble, no ring: the top box is gone')
pointers('step 1: spawn',{world='way'})
do local tip,dir=arrowFrame();local to=(V3(40,0,90)-V3(0,0,0)).Unit;local flat=(V3(tip.X,0,tip.Z)-V3(0,0,0))
 check(flat.Magnitude>11 and flat.Magnitude<15 and(flat.Unit):Dot(to)>.97 and tip.Y>4,('far from the pack it floats ahead of you on the way, above your head (%.1f studs, dot %.2f)'):format(flat.Magnitude,flat.Unit:Dot(to)))
 check(V3(dir.X,0,dir.Z).Unit:Dot(to)>.97 and dir.Y>.2 and dir.Y<.6,'and points the way to the pack (its tip lifted, its face to the camera)')
 local red,white=0,0;for _,p in ipairs(arrowParts())do if p.Material==R.Enum.Material.Neon and p.Color.R>.9 and p.Color.G<.3 then red+=1 elseif p.Color.R>.9 and p.Color.G>.9 then white+=1 end end
 check(red==3 and white==3,'the arrow is neon red with a white rim ('..red..' red, '..white..' white)')
 local wedges=0;for _,p in ipairs(arrowParts())do if p.ClassName=='WedgePart'then wedges+=1 end;check(p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p.Anchored==true,'arrow part '..p.Name..': no collision, no query, anchored')end
 check(wedges==4,'the head is two wedges (and two rims)')
end
check(#sounds==0,'the tutorial makes no sound of its own')
-- The pack moves (taken by someone else): the arrow points at the next one.
serverStep={Kind='Pack',Target=V3(-60,3,95)};frames(70)
do local tip=arrowFrame();check(V3(tip.X,0,tip.Z).Unit:Dot(V3(-60,0,95).Unit)>.97,'the pack was taken: the arrow turns to the next one')end
-- The way arrow bobs along the way it points (not with Reduced Motion).
do local lo,hi=math.huge,-math.huge;for _=1,60 do frames(1);local tip=arrowFrame();local d=(V3(tip.X,0,tip.Z)-V3(0,0,0)).Magnitude;lo=math.min(lo,d);hi=math.max(hi,d)end
 check(hi-lo>.5 and hi-lo<1.5,('the far arrow bobs toward the pack (%.2f studs)'):format(hi-lo))end
-- 2. After the spawn arrow's few seconds: the TRACK button, an arrow and a pressing hand on it, and no other arrow (no pop: nothing was done yet).
frames(60*Guide.IntroSeconds+10)
pointers('step 2: TRACK',{button=trackB})
check(tapUi.Pointer.Rotation==180,'a red arrow under TRACK points up at it')
do local lo,hi=1,0;for _=1,50 do frames(1);local k=tapUi.Hand.Press.Scale;lo=math.min(lo,k);hi=math.max(hi,k)end;check(lo<.95 and hi>.99,'the finger keeps pressing')end
-- 3. On the track (the TRACK button took you there): the arrow to the pack.
serverStep={Kind='Pack',Target=V3(40,3,90)};root.CFrame=CF(0,3,60);frames(12)
pointers('step 3: far from the pack',{world='way'})
-- Close to the pack: the arrow hovers over it, pointing down, its flat side to the camera; the floating arrow is gone (never two for the one pack).
root.CFrame=CF(30,3,80);frames(10)
pointers('step 3: close to the pack',{world='over'})
do local tip,dir=arrowFrame();check(near(tip,40,90,.6)and tip.Y>6 and tip.Y<8.6 and dir.Y<-.97,('near the pack: over it, pointing down (tip %s, way %s)'):format(tostring(tip),tostring(dir)))
 local face=V3(arrowParts()[3].CFrame.R[1][2],arrowParts()[3].CFrame.R[2][2],arrowParts()[3].CFrame.R[3][2]);local c=camera.CFrame.Position;local toCam=(V3(c.X,0,c.Z)-V3(40,0,90)).Unit
 check(face:Dot(toCam)>.97,'its flat side faces the camera')
end
root.CFrame=CF(39,3,88);frames(10);pointers('step 3: at the pack',{world='over'})
-- Walking out of the near range and back does not flicker (a margin): 30 studs is the edge.
do local flips,last=0,nil
 for i=0,40 do root.CFrame=CF(40-(27+i/20*6)*math.sin(math.rad(30)),3,90-(27+i/20*6)*math.cos(math.rad(30)));frames(2);local w=worldArrow();if last and w~=last then flips+=1 end;last=w end
 check(flips<=1,'walking out past the near range: the arrow changes once, not back and forth ('..flips..' changes)')
 root.CFrame=CF(39,3,88);frames(10)
end
-- The pack is far off to the side: the floating arrow is still in sight, so it is the only arrow (no edge arrow too).
serverStep={Kind='Pack',Target=V3(400,3,90)};root.CFrame=CF(0,3,60);frames(70)
pointers('step 3: the pack far to the right',{world='way'})
do local tip,dir=arrowFrame();check(dir.X>.8,'the floating arrow points right, toward it ('..tostring(dir)..')')end
-- The pack is behind you: the floating arrow would be out of sight, so the one arrow is at the screen edge, pointing down / back.
serverStep={Kind='Pack',Target=V3(0,3,-200)};frames(70)
pointers('step 3: the pack behind you',{world='edge'})
do local e=gui.Direction;check(e.Position.Y.Offset>360 and math.abs(math.sin(math.rad(e.Rotation)))<.3 and math.cos(math.rad(e.Rotation))>.7,('the edge arrow sits at the bottom and points down, behind you (%s, %d)'):format(tostring(e.Position),e.Rotation))end
-- Turned toward it again: the edge arrow goes, the floating one is the only one.
heading=V3(0,0,-1);frames(70);pointers('step 3: turned around, the pack ahead',{world='way'});heading=V3(0,0,1);frames(70)
serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70);pointers('step 3: the pack is back ahead',{world='way'})
-- No pack yet: nothing to point at, nothing drawn.
serverStep={Kind='Pack',Waiting=true};frames(70);nothing('no packs out yet')
serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70);pointers('a pack shows up',{world='way'})
-- Picked up: carry it home (the arrow points at the home line; no TRACK / BASE while carrying).
serverStep={Kind='Safety',Target=V3(0,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);heading=V3(0,0,-1);frames(66)
pointers('step 3: carry it home',{world='over'})
root.CFrame=CF(0,3,0);heading=V3(0,0,1);frames(30)
pointers('step 3: carrying it, far from home',{world='way'})
do local tip,dir=arrowFrame();check(V3(dir.X,0,dir.Z).Unit:Dot(V3(0,0,1))>.97,'the arrow points home')end
-- Caught (the pack is gone): back to the pack.
root.CFrame=CF(0,3,60);player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind='Pack',Target=V3(40,3,90)};frames(70)
pointers('caught: back to the pack',{world='way'})
serverStep={Kind='Safety',Target=V3(0,3,38)};player:SetAttribute('ChestChaseSeedCarrying',true);frames(60)

-- 4. Banked: open a pack (owner: "the player can open ANY pack and it will count"; the new-player gift pack sits next to it). ----------
player:SetAttribute('ChestChaseSeedCarrying',nil);serverStep={Kind=nil,Target=nil};root.CFrame=CF(0,3,45)
local tool=new('Tool');tool.Name='Forest Pack';tool:SetAttribute('SeedPackTool',true);tool:SetAttribute('SeedInventoryId','301_2');tool:SetAttribute('PackNumber',2);tool.Parent=backpack
local gift=new('Tool');gift.Name='Gift Verity Pack';gift:SetAttribute('SeedPackTool',true);gift:SetAttribute('SeedInventoryId','301_1');gift:SetAttribute('PackNumber',9);gift.Parent=backpack
dock.Slot2.ItemName.Text='Forest Pack';dock.Slot3.ItemName.Text='Gift Verity Pack'
player:SetAttribute('TutorialStep',4);frames(60)
pointers('step 4: its slot',{button=dock.Slot3})
-- In your hand: the R138 clicking hand, no words, no other pointer.
tool.Parent=character;frames(20)
nothing('a pack in hand (any)')
local bag=new('Model');bag.Name='CarriedSeed';bag:SetAttribute('SeedPackCarry',true);bag:SetAttribute('PackClicksRequired',5);bag:SetAttribute('PackClickCount',0)
local bagPart=new('Part');bagPart.CFrame=CF(2,4,3);bagPart.Parent=bag;bag.PrimaryPart=bagPart;bag.Parent=character;frames(10)
local hintUi=gui.ClickHint
local function lit()local n=0;for i=1,5 do local p=hintUi.Pips:FindFirstChild('Pip'..i);if p and p.Visible and p.BackgroundColor3.R>.9 then n+=1 end end;return n end
pointers('step 4: clicking',{click=true})
check(hintUi.Hand.Text=='🖱️'and not hintUi.Cap.Visible and hintUi:FindFirstChild('Word')==nil,'the clicking indicator: a mouse that keeps clicking, no word')
check(lit()==0 and hintUi.Pips.Pip5.Visible,'five pips, none lit yet')
local lowest,highest=1,0;for _=1,40 do frames(1);local k=hintUi.Hand.UIScale.Scale;lowest=math.min(lowest,k);highest=math.max(highest,k)end
check(lowest<.9 and highest>.99,'the hand keeps pressing')
bag:SetAttribute('PackClickCount',2);frames(2);check(lit()==2,'each click lights a pip')
-- Phone: a finger; gamepad: the pad and its R2 key cap.
UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
check(hintUi.Visible and hintUi.Hand.Text=='👆'and not hintUi.Cap.Visible,'touch: the finger taps')
lastInput=R.Enum.UserInputType.Gamepad1;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
check(hintUi.Hand.Text=='🎮'and hintUi.Cap.Visible and hintUi.Cap.Key.Text=='R2','gamepad: the pad + the R2 key cap');noBox('step 4 (gamepad)')
lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);frames(5)
-- The menu wheel hides every pointer, then they come back. Hidden, nothing is written per frame.
pg:SetAttribute('GardenMenuExpanded',true);frames(2);check(not hintUi.Visible and not tapUi.Visible and worldArrow()==nil,'every pointer hides while the menu is open')
do local w,m=writes,moved;frames(120);check(writes==w and moved==m,'hidden: no property writes, no arrow moves for 2 s ('..(writes-w)..' writes)')end
pg:SetAttribute('GardenMenuExpanded',false);frames(2);check(hintUi.Visible,'the pointers return')

-- 5. It opens (you were by the track line): the reveal plays (the next pointer waits), then the BASE button. ----------------------------------------------------
bag:SetAttribute('RevealAt',123);frames(2);check(not hintUi.Visible,'the clicking indicator goes once the pack opens')
bag:Destroy();tool:Destroy();dock.Slot2.ItemName.Text=''
local seed=new('Tool');seed.Name='Carrot Seed';seed:SetAttribute('GardenSeed',true);seed:SetAttribute('SeedInventoryId','301_2');seed.Parent=character
serverStep={Kind='Garden',Target=V3(-20,3,10)};root.CFrame=CF(150,3,40);player:SetAttribute('TutorialStep',6);frames(6)
nothing('opened: the reveal plays first');frames(60);nothing('the reveal is still playing')
player:SetAttribute('RarePullCinematic','Mythic');frames(2);nothing('a rare pull\'s cinematic hides the pointers')
player:SetAttribute('RarePullCinematic',nil);frames(100)
pointers('step 5: away from home: the BASE button',{button=baseB})

-- 6. Home (BASE took you there): the dirt. ---------------------------------------------------------------------------------------------------------------
root.CFrame=CF(0,3,5);frames(30)
pointers('step 6: plant it',{world='over',dirt=true})
do local tip,dir=arrowFrame();check(near(tip,-20,10,.6)and dir.Y<-.97,'the red arrow over the dirt, pointing down')end
check(gui.TapSpot.Hand.Text=='👇','and a pressing 👇 on it')
-- Reduced Motion, standing still: nothing changes, so nothing is written or moved.
Gui.ReducedMotionEnabled=true;frames(10)
do local w,m=writes,moved;frames(60);check(writes==w and moved==m,'Reduced Motion, standing still: no writes, no moves for 1 s ('..(writes-w)..' writes, '..(moved-m)..' moves)')end
check(gui.TapSpot.Enabled and arrowShown(),'Reduced Motion: the hand and the arrow still show (still)')
Gui.ReducedMotionEnabled=false;frames(2)
do local w=writes;frames(60);local per=(writes-w)/60;check(per<60,('animated step 6: %.1f writes per frame (only what moves)'):format(per))end
-- The seed went back to the Bag: its slot.
seed.Parent=backpack;dock.Slot1.ItemName.Text='Carrot Seed';frames(20)
pointers('seed not in hand',{button=dock.Slot1})
seed.Parent=character;frames(20);pointers('seed in hand',{world='over',dirt=true})
-- Ran off to the track: BASE again.
root.CFrame=CF(0,3,80);frames(12);pointers('on the track in step 6: BASE',{button=baseB})
root.CFrame=CF(-10,3,5);frames(30);pointers('home again',{world='over',dirt=true})

-- 7. Planted: the first fruit grows in 10 s (a small ring timer over the plant; the timer marks the plant, so no arrow while you are by it). -------------------------
seed:Destroy();dock.Slot1.ItemName.Text=''
serverStep={Kind='Crop',Target=V3(-20,5,10),ReadyAt=1000010,ReadyIn=10,Ripe=false};player:SetAttribute('TutorialStep',7);frames(56)
pointers('step 7: the 10-second timer',{timer=true})
check(gui.GrowTimer.Size.X.Offset<=90 and gui.GrowTimer.Face.Size.X.Offset<=56,'the timer is small')
check(gui.GrowTimer.Face.Seconds.Text=='10','over the plant: the ring timer reads 10')
local function litTicks()local n=0;for i=1,12 do if gui.GrowTimer['Tick'..i].BackgroundColor3.G>.85 then n+=1 end end;return n end
check(litTicks()==0,'no tick lit yet')
frames(60*5)
check(gui.GrowTimer.Face.Seconds.Text=='4'or gui.GrowTimer.Face.Seconds.Text=='5','5 s later: about 5 left ('..gui.GrowTimer.Face.Seconds.Text..')')
check(litTicks()>=5 and litTicks()<=7,'and half the ring is lit ('..litTicks()..')')
-- the server's next poll does not move the deadline
frames(60*2);local left=tonumber(gui.GrowTimer.Face.Seconds.Text);check(left==3 or left==2,'the polls keep the same deadline ('..tostring(left)..')')
-- Looking away from the plant (it is off screen): the arrow is necessary now, one arrow, the way (or the edge).
root.CFrame=CF(-10,3,-30);heading=V3(0,0,-1);frames(3);pointers('step 7: the plant behind you',{world='edge',timer=true});heading=V3(0,0,1);frames(3)
pointers('step 7: facing the plant from afar',{world='way',timer=true})
root.CFrame=CF(-10,3,5);frames(3);pointers('step 7: back by the plant',{timer=true})

-- 8. Ripe: pick it. ---------------------------------------------------------------------------------------------------------------------------------------
serverStep.Ripe=true;frames(60*3)
pointers('step 8: harvest',{world='over'})
check(not gui.GrowTimer.Enabled,'the timer is gone once the fruit is ripe')
-- Walked away from home: BASE.
root.CFrame=CF(200,3,5);frames(20);pointers('away from the plant: BASE',{button=baseB})
root.CFrame=CF(-10,3,5);frames(20)

-- 9. Harvested: sell it at the market. ----------------------------------------------------------------------------------------------------
serverStep={Kind='Sell',Target=V3(0,3,-120)};player:SetAttribute('TutorialStep',9);heading=V3(0,0,-1);frames(60)
pointers('step 9: the market, far',{world='way'})
root.CFrame=CF(0,3,-108);frames(20);pointers('step 9: at the market',{world='over'})
-- The market window: Sell crops, then Sell all (the pointer draws over the window).
pg:SetAttribute('SeedMenu','Economy');frames(20)
pointers('the market window (Buy page): Sell crops',{button=sellMode});check(tapGui.DisplayOrder>30,'above the window')
harvestMenu.Visible=true;frames(20)
pointers('the Sell crops page: Sell all',{button=sellAll})
pg:SetAttribute('SeedMenu','Inventory');frames(5);nothing('another menu still hides the pointers')
pg:SetAttribute('SeedMenu',nil);harvestMenu.Visible=false;frames(5);heading=V3(0,0,1)

-- 10. Sold: the arrow on your treadmill (faster), then the BONUS ROLL arrow (every 6 min), then done. -------------------------------------------------------
serverStep={Kind='Treadmill',Target=V3(12,3,-6)};root.CFrame=CF(0,3,5);heading=V3(0,0,-1);player:SetAttribute('TutorialStep',10);frames(60)
pointers('step 10: your treadmill',{world='over'})
check(table.find(commands,'TreadmillInfo')==nil,'step 10 waits for you')
player:SetAttribute('StarterPackClaimed',false);frames(2)
player:SetAttribute('TreadmillTraining',true);frames(6)
pointers('step 10: on the treadmill: the BONUS ROLL arrow',{button=bonusB,press=false})
check(table.find(commands,'TreadmillInfo')==nil,'the BONUS ROLL arrow shows for a few seconds first')
frames(60*(Guide.BonusSeconds-1));check(table.find(commands,'TreadmillInfo')==nil and tapUi.Visible,'... still showing')
frames(60*2)
check(table.find(commands,'TreadmillInfo')~=nil,'then the tutorial is finished')
check(player:GetAttribute('TutorialDone')==true,'done')
nothing('the finish: nothing left');check(trail()==nil and not gui.Enabled and not tapGui.Enabled,'no card, no trophy, no confetti: the ScreenGuis are off and the world pieces are gone')
frames(60*3)
local function nothingLeft(where)
 check(not tapUi.Visible and not gui.TapSpot.Enabled and not gui.GrowTimer.Enabled and not gui.ClickHint.Visible and not gui.Direction.Visible and trail()==nil and not gui.Enabled and not tapGui.Enabled,where..': nothing left on screen or in the world')
 check(pg:GetAttribute('TutorialCardBottom')==nil,where..': no notice reservation')
end
nothingLeft('after finishing')
local movedBefore,cmdBefore,writesBefore=moved,#commands,writes;frames(120);check(moved==movedBefore and #commands==cmdBefore and writes==writesBefore,'idle after finishing: no writes, no arrow work, no polling ('..(writes-writesBefore)..' writes)')
player:SetAttribute('TreadmillTraining',false)
-- (The tutorial is started again by hand below; the Replay and Skip requests are refused by the server.)
-- Step 10 ignored: after its seconds the BONUS ROLL arrow, then it finishes by itself.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',127);player:SetAttribute('TutorialStep',10);serverStep={Kind='Treadmill',Target=V3(12,3,-6)};root.CFrame=CF(0,3,5);heading=V3(0,0,-1)
local cut=#commands;frames(60*5)
local function sentSince(n)for i=n+1,#commands do if commands[i]=='TreadmillInfo'then return true end end;return false end
check(not sentSince(cut)and worldArrow()=='over','step 10 waits a while (the treadmill arrow)')
frames(60*(Guide.Steps[10].Seconds-4));pointers('step 10: its seconds passed: the BONUS ROLL arrow',{button=bonusB,press=false});check(not sentSince(cut),'... for a few seconds')
frames(60*(Guide.BonusSeconds+1))
check(sentSince(cut)and player:GetAttribute('TutorialDone')==true,'step 10 finishes by itself after '..Guide.Steps[10].Seconds..' s + '..Guide.BonusSeconds..' s')
frames(60*2);nothingLeft('after a timed-out step 10')
-- No treadmill in your base: no treadmill arrow, the BONUS ROLL arrow, then done.
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',10);serverStep={Kind='Treadmill',Target=nil};cut=#commands;frames(90)
pointers('no treadmill: the BONUS ROLL arrow',{button=bonusB,press=false})
frames(60*(Guide.BonusSeconds+1))
check(sentSince(cut)and player:GetAttribute('TutorialDone')==true,'no treadmill: step 10 finishes by itself');frames(60*2)
-- R158h (owner: "give players a free bonus roll once they are done"): the client asks the server ONCE when the BONUS ROLL arrow starts; with the roll ready the arrow waits until it is used
-- (the ready count drops) or BonusRollSeconds pass.
do
 local function count(n)local c=0;for i=n+1,#commands do if commands[i]=='BonusGift'then c+=1 end end;return c end
 mockGrant=true
 player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',10);serverStep={Kind='Treadmill',Target=nil};cut=#commands;frames(90)
 check(count(cut)==1,'the free roll: asked exactly once when the BONUS ROLL arrow starts ('..count(cut)..')')
 pointers('the free roll is ready: the BONUS ROLL arrow',{button=bonusB,press=false})
 frames(60*(Guide.BonusSeconds+4));check(not sentSince(cut)and tapUi.Visible,'with the roll ready the arrow stays past the usual '..Guide.BonusSeconds..' s, waiting for the press')
 player:SetAttribute('TreadmillBonusReady',0);frames(60*2)
 check(sentSince(cut)and player:GetAttribute('TutorialDone')==true and count(cut)==1,'the roll used: the tutorial finishes (and no second ask)');frames(60*2)
 player:SetAttribute('TutorialDone',false);player:SetAttribute('TreadmillBonusReady',nil);player:SetAttribute('TutorialStep',10);cut=#commands;frames(90)
 check(count(cut)==1 and not sentSince(cut),'again: asked once')
 frames(60*(Guide.BonusRollSeconds-3));check(not sentSince(cut)and tapUi.Visible,'the roll never pressed: still showing just before '..Guide.BonusRollSeconds..' s')
 frames(60*5);check(sentSince(cut)and player:GetAttribute('TutorialDone')==true,'... and it finishes by itself after '..Guide.BonusRollSeconds..' s')
 mockGrant=false;player:SetAttribute('TreadmillBonusReady',nil);frames(60*2)
end
-- Resuming an old save (an R152 player who had planted: the server publishes 7): straight to the grow / harvest step.
root.CFrame=CF(-10,3,5);heading=V3(0,0,1);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',23);serverStep={Kind='Crop',Target=V3(-20,5,10),ReadyAt=1000099,ReadyIn=0,Ripe=true};player:SetAttribute('TutorialStep',7);frames(60)
pointers('an old save at the plant step resumes at the harvest (its fruit is ripe)',{world='over'})
-- Already on the track when you spawn: straight to the pack (no spawn arrow, no TRACK).
player:SetAttribute('TutorialStep',1);serverStep={Kind='Pack',Target=V3(40,3,90)};root.CFrame=CF(0,3,70);heading=V3(0,0,1);frames(60)
pointers('on the track already: straight to the pack',{world='way'})
-- The owner's /test tutorial reset / step (TutorialRestart158f): the first look again at once (the spawn arrow for its seconds, then TRACK).
root.CFrame=CF(0,3,0);player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialStep',1);player:SetAttribute('TutorialRestart158f',1);frames(30)
pointers('the owner\'s tutorial reset: the spawn arrow again',{world='way'})
frames(60*Guide.IntroSeconds+10);pointers('... then TRACK',{button=trackB})
-- No way to skip it: nothing on the screen takes a click, the client never sends Skip.
check(table.find(commands,'Skip')==nil,'the client never sends a Skip request')
check(#sounds==0,'the tutorial made no sound of its own, start to finish')
check(doubles==0,'in no frame of the whole walk did two arrows say the same thing ('..doubles..' frames with an edge arrow and a floating / hovering arrow for one goal)')

-- Phone landscape (844x390, safe area): the same pointers, a smaller clicking hand between the top and the hotbar.
UIS.TouchEnabled=true;UIS.MouseEnabled=false;lastInput=R.Enum.UserInputType.Touch;UIS.LastInputTypeChanged:Fire(lastInput);VIEW=R.Vector2.new(844,390);VW,VH=844,390;gui.AbsoluteSize=VIEW;tapGui.AbsoluteSize=VIEW
baseB.AbsolutePosition=R.Vector2.new(342,-40);trackB.AbsolutePosition=R.Vector2.new(422,-40)
player:SetAttribute('TutorialDone',false);player:SetAttribute('TutorialMask',1);player:SetAttribute('TutorialStep',1);player:SetAttribute('TutorialRestart158f',2);root.CFrame=CF(0,3,0);frames(60*6)
pointers('phone: the TRACK button',{button=trackB})
-- Phone, step 10: still just the arrows.
player:SetAttribute('TutorialStep',10);serverStep={Kind='Treadmill',Target=V3(12,3,-6)};root.CFrame=CF(0,3,5);heading=V3(0,0,-1);frames(90)
pointers('phone step 10',{world='over'})
-- Phone, opening the pack: the clicking indicator is smaller and stays above the hotbar.
do local Hud=req(hudModule);local m=Hud.Read(VIEW,true,nil);local barTop=390-m.HotbarBottom-m.SlotSize-(m.HotbarDetails~=false and 44 or 0)
 local t2=new('Tool');t2.Name='Forest Pack';t2:SetAttribute('SeedPackTool',true);t2:SetAttribute('SeedInventoryId','301_2');t2.Parent=character
 local b2=new('Model');b2.Name='CarriedSeed';b2:SetAttribute('SeedPackCarry',true);b2:SetAttribute('PackClicksRequired',5);b2:SetAttribute('PackClickCount',1)
 local p2=new('Part');p2.CFrame=CF(2,4,3);p2.Parent=b2;b2.PrimaryPart=p2;b2.Parent=character
 player:SetAttribute('TutorialStep',4);frames(90)
 local ch=gui.ClickHint;local k=ch.UIScale.Scale;local y=ch.Position.Y.Offset
 check(ch.Visible and k<.8,'phone: a smaller clicking indicator ('..k..')')
 check(y+95*k<=barTop+1 and y-95*k>=0,('phone: it sits above the hotbar (%d..%d, bar at %d)'):format(y-95*k,y+95*k,barTop))
 b2:Destroy();t2:Destroy()
end
watchFn=nil
-- Returning players: a fresh start with a finished tutorial shows nothing and builds nothing.
scriptInst.Destroying:Fire();frames(2);check(trail()==nil and pg:FindFirstChild('BeginnerTutorial')==nil and pg:FindFirstChild('BeginnerTutorialTap')==nil,'script cleanup removes everything')
player:SetAttribute('TutorialDone',true);player:SetAttribute('TutorialStep',0);player:SetAttribute('TutorialMask',255)
local again=new('LocalScript');again.Name='BeginnerTutorial';local cmdStart=#commands
local ok2,err2=pcall(load,'BeginnerTutorial',again);check(ok2,'reload: '..tostring(err2))
movedBefore=moved;frames(120)
local gui2=pg:FindFirstChild('BeginnerTutorial')
check(gui2 and trail()==nil and gui2.Enabled==false and pg.BeginnerTutorialTap.Enabled==false,'returning player: no pointers, no world pieces, the ScreenGuis off')
check(moved==movedBefore and #commands-cmdStart<=1,'returning player: no per-frame work, one state check at most')
again.Destroying:Fire()
print(('%d checks, %d failures'):format(checks,fails))
