do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R111: the game owner's avatar guided new players. R152: one idea per step, it moves on by itself the moment you do it.
-- R158e (owner: "shorten it even more ... a red arrow that points players towards the pack when they spawn ... the track tp button ... steal ... the visual mouse indicator ... tp back
-- to base ... plant ... the first fruit is always 10 seconds ... harvest and sell ... the treadmill makes them run faster and every 6 mins gives them a bonus roll ... EVERYTHING ...
-- must be visual so no words all just arrows and pointing"): ten steps, one at a time (BeginnerGuide.Steps / Looks / Resolve).
-- R158g (owner: "remove the box at the top from the tutorial entirely, and the big red arrow should only be used when necessary: in that image there are 2 arrows so it's kind of redundant
-- to have 2 arrows. The tutorial should really just be arrows and that's all"; "it's not that we can't have 2 arrows at a moment, but each arrow has to fulfil 1 purpose, not 2 fulfilling
-- the same purpose"; "there will be no skip tutorial button"): the tutorial is ONLY pointers. No card, no avatar, no icons, no picture row, no step dots, no pops or sounds, no confetti,
-- no skip, no chevrons, no beam, no ring, no key bubble. What is left:
--  * for a goal in the world (the pack, home, your dirt, the fruit, the market, your treadmill) ONE red arrow, the one that fits: hovering over it when it is on screen and near; else the big
--    red 3D arrow floating in front of you, pointing the way (only when the goal is far and that arrow is itself in sight); else a red arrow at the screen edge (the goal is behind you);
--    the one that is not needed is not drawn, so two arrows never say the same thing;
--  * on a screen button (TRACK, BASE, a hotbar slot, the market's Sell buttons, BONUS ROLL) a red arrow and a pressing hand (BONUS ROLL: the arrow alone);
--  * the pressing 👇 on your dirt, the R138 clicking hand by the pack in your hand, and a small ring timer over the first plant (the 10-second fruit).
-- The world pieces exist only while the tutorial runs. Reduced Motion: nothing bounces, pulses or flows.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local Guide=require(RS.BeginnerGuide);local Theme=require(RS.GardenTheme);local Layout=require(RS.HudLayout)
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
-- R152 perf habit: everything animated per frame is written only when its value changes (PropCache152); nothing runs per frame while the pointers are hidden.
local Cache=require(RS:WaitForChild('PropCache152'));local set=Cache.new().Set
local RGB=Color3.fromRGB;local FONT=Enum.Font.FredokaOne;local INK=RGB(8,13,24);local WHITE=Color3.new(1,1,1)
local COL={Done=RGB(120,232,110),Here=RGB(255,214,79),Todo=RGB(14,20,48),Arrow=RGB(255,38,38)}
local U,S={}, {} -- U: the pieces on screen and their parts; S: what the tutorial is doing
local function calm()return GuiService.ReducedMotionEnabled end
local function round(item,radius)local c=Instance.new('UICorner');c.CornerRadius=radius or UDim.new(1,0);c.Parent=item;return c end
local function gradient(item,a,b,rotation)local g=Instance.new('UIGradient');g.Color=ColorSequence.new(a,b);g.Rotation=rotation or 90;g.Parent=item;return g end
local function stroke(item,color,thickness)local s=Instance.new('UIStroke');s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color;s.Thickness=thickness;s.Parent=item;return s end
local function text(parent,name,value,size,color)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Font=FONT;t.Text=value;t.TextSize=size;t.TextColor3=color or WHITE
 t.TextStrokeColor3=INK;t.TextStrokeTransparency=.15;t.Parent=parent;return t
end
local function frame(parent,name,z)local f=Instance.new('Frame');f.Name=name;f.BackgroundTransparency=1;f.BorderSizePixel=0;f.ZIndex=z or 1;f.Parent=parent;return f end
local function device()
 local last=Input:GetLastInputType()
 if string.find(last.Name,'Gamepad',1,true)then return'Gamepad'end
 if last==Enum.UserInputType.Touch or(Input.TouchEnabled and not Input.MouseEnabled)then return'Touch'end
 return'Mouse'
end
-- A red arrow made of three bars, pointing up in its box (the screen-edge pointer and the button pointer turn it).
local function arrow(parent,color)
 local holder=frame(parent,'Arrow');holder.Size=UDim2.fromScale(1,1)
 for _,v in ipairs({{.42,.06,.16,.60,0},{.25,.53,.16,.38,-42},{.59,.53,.16,.38,42}})do
  local p=frame(holder,'Bar',parent.ZIndex);p.Position=UDim2.fromScale(v[1],v[2]);p.Size=UDim2.fromScale(v[3],v[4]);p.Rotation=v[5];p.BackgroundColor3=color or COL.Arrow;p.BackgroundTransparency=0;Theme.Corner(p,3)
  stroke(p,WHITE,2)
 end
 return holder
end
-- A key cap (the clicking hand's R2 on a gamepad): white, rounded, dark glyph. The glyph label is marked KeyGlyph (the only letter the tutorial draws).
local function keyCap(parent,name,z)
 local cap=frame(parent,name,z);cap.BackgroundColor3=WHITE;cap.BackgroundTransparency=0;round(cap,UDim.new(0,7));gradient(cap,RGB(255,255,255),RGB(196,204,222));stroke(cap,INK,2)
 local key=text(cap,'Key','',18,INK);key.Size=UDim2.fromScale(1,1);key.TextStrokeTransparency=1;key.TextScaled=true;key.ZIndex=z+1;key:SetAttribute('KeyGlyph',true)
 local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=22;fit.Parent=key
 return cap,key
end

-- Screen pieces ---------------------------------------------------------------------------------------------------------------------------------------------------------
local gui=Instance.new('ScreenGui');gui.Name='BeginnerTutorial';gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
-- R138 (owner: "a clicking indicator to visually show players to keep clicking to open a pack"): by the pack in your hand, a mouse / finger / pad that keeps pressing with a ripple, and
-- one pip per click still needed (no word; a gamepad shows its R2 key cap).
local CH={Ripples={},Pips={}}
do
 CH.Hint=frame(gui,'ClickHint',9);CH.Hint.AnchorPoint=Vector2.new(.5,.5);CH.Hint.Size=UDim2.fromOffset(180,190);CH.Hint.Visible=false
 CH.Scale=Instance.new('UIScale');CH.Scale.Parent=CH.Hint
 for i=1,2 do local r=frame(CH.Hint,'Ripple'..i,9);r.AnchorPoint=Vector2.new(.5,.5);r.Position=UDim2.fromOffset(76,52);round(r);CH.Ripples[i]={Frame=r,Stroke=stroke(r,RGB(255,236,120),3)}end
 CH.Hand=text(CH.Hint,'Hand','🖱️',72);CH.Hand.AnchorPoint=Vector2.new(.5,.5);CH.Hand.Position=UDim2.fromOffset(90,66);CH.Hand.Size=UDim2.fromOffset(92,92);CH.Hand.TextScaled=true;CH.Hand.TextStrokeTransparency=1;CH.Hand.ZIndex=10
 CH.HandScale=Instance.new('UIScale');CH.HandScale.Parent=CH.Hand
 local cap,key=keyCap(CH.Hint,'Cap',10);cap.AnchorPoint=Vector2.new(.5,0);cap.Position=UDim2.fromOffset(90,120);cap.Size=UDim2.fromOffset(46,34);cap.Visible=false;CH.Cap,CH.Key=cap,key
 CH.Row=frame(CH.Hint,'Pips',10);CH.Row.AnchorPoint=Vector2.new(.5,0);CH.Row.Position=UDim2.fromOffset(90,162);CH.Row.Size=UDim2.fromOffset(180,20)
end
local function pipCount(n)
 local pips=CH.Pips
 for i=#pips+1,n do local d=frame(CH.Row,'Pip'..i,10);d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(18,18);d.BackgroundTransparency=0;round(d);stroke(d,INK,2);pips[i]=d end
 for i,d in ipairs(pips)do set(d,'Visible',i<=n);set(d,'Position',UDim2.fromOffset(90+(i-(n+1)/2)*25,10))end
end
-- The red arrow at the screen edge while the goal is behind you (the one arrow for that goal then).
local edge=frame(gui,'Direction',11);edge.Size=UDim2.fromOffset(44,60);edge.AnchorPoint=Vector2.new(.5,.5);edge.Visible=false;arrow(edge,COL.Arrow)
do
 -- On the garden dirt: a 👇 that keeps pressing it, with a ripple where it lands.
 local spot=Instance.new('BillboardGui');spot.Name='TapSpot';spot.AlwaysOnTop=true;spot.Size=UDim2.fromOffset(110,120);spot.StudsOffsetWorldSpace=Vector3.new(0,2.6,0);spot.Enabled=false;spot.Parent=gui;U.spot=spot
 U.spotRipple=frame(spot,'Ripple',1);U.spotRipple.AnchorPoint=Vector2.new(.5,.5);U.spotRipple.Position=UDim2.new(.5,0,1,-14);round(U.spotRipple);U.spotRippleStroke=stroke(U.spotRipple,RGB(255,236,120),3)
 U.spotFinger=text(spot,'Hand','👇',60);U.spotFinger.AnchorPoint=Vector2.new(.5,1);U.spotFinger.Position=UDim2.new(.5,0,1,-14);U.spotFinger.Size=UDim2.fromOffset(64,64);U.spotFinger.TextScaled=true;U.spotFinger.TextStrokeTransparency=1;U.spotFinger.ZIndex=2
 -- Over the first plant while it grows (small): 12 dots in a ring (one lights per twelfth of the wait) round the seconds left.
 local timer=Instance.new('BillboardGui');timer.Name='GrowTimer';timer.AlwaysOnTop=true;timer.Size=UDim2.fromOffset(88,88);timer.StudsOffsetWorldSpace=Vector3.new(0,6,0);timer.Enabled=false;timer.Parent=gui;U.timer=timer
 local face=frame(timer,'Face',1);face.AnchorPoint=Vector2.new(.5,.5);face.Position=UDim2.fromScale(.5,.5);face.Size=UDim2.fromOffset(52,52);face.BackgroundColor3=RGB(16,20,48);face.BackgroundTransparency=.15;round(face);stroke(face,WHITE,3)
 U.timerText=text(face,'Seconds','',26,RGB(255,236,120));U.timerText.Size=UDim2.fromScale(1,1);U.timerText.TextScaled=true;U.timerText.ZIndex=3
 U.timerDots={}
 for i=1,12 do
  local a=math.rad(i*30);local d=frame(timer,'Tick'..i,2);d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(9,9);d.BackgroundTransparency=0;d.BackgroundColor3=COL.Todo;round(d);stroke(d,WHITE,1.5)
  d.Position=UDim2.fromOffset(math.floor(44+math.sin(a)*37+.5),math.floor(44-math.cos(a)*37+.5));U.timerDots[i]=d
 end
end

-- The pointer on a screen button: a red arrow that points at it and a 👆 that keeps pressing it (BONUS ROLL: the arrow alone). Its own ScreenGui with no insets, above the hotbar (25),
-- the BONUS ROLL button (26) and the BASE / TRACK row (24, in Roblox's top bar, outside the safe area); above the market window (30) while it points into it.
local tapGui=Instance.new('ScreenGui');tapGui.Name='BeginnerTutorialTap';tapGui.ResetOnSpawn=false;tapGui.DisplayOrder=27;tapGui.ScreenInsets=Enum.ScreenInsets.None;tapGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;tapGui.Parent=pg
local tap=frame(tapGui,'TapHand',20);tap.Size=UDim2.fromScale(1,1);tap.Visible=false
do
 U.finger=text(tap,'Hand','👆',48);U.finger.AnchorPoint=Vector2.new(.3,.06);U.finger.Size=UDim2.fromOffset(52,52);U.finger.TextScaled=true;U.finger.TextStrokeTransparency=1;U.finger.Rotation=-24;U.finger.ZIndex=21
 U.fingerScale=Instance.new('UIScale');U.fingerScale.Name='Press';U.fingerScale.Parent=U.finger
 U.pointer=frame(tap,'Pointer',22);U.pointer.AnchorPoint=Vector2.new(.5,.5);U.pointer.Size=UDim2.fromOffset(40,54);arrow(U.pointer,COL.Arrow)
end

-- State -----------------------------------------------------------------------------------------------------------------------------------------------------------------
S.info={};S.step=0;S.look=nil;S.lastKey=nil;S.lastStep=0;S.connections={};S.dead=false;S.busy=false
S.poll,S.lookPoll,S.stepSeconds,S.finishRetry,S.intro=0,0,0,0,0
S.shown,S.waitUntil,S.mode,S.bonus,S.bonusSeconds=false,0,nil,false,0
S.clickSeen,S.clickPopAt=0,-math.huge
S.ctx={}
local fetch,render
local function blocked()
 local menu=pg:GetAttribute('SeedMenu')
 if menu~=nil and not(menu=='Economy'and(player:GetAttribute('TutorialStep')or 0)==9)then return true end -- (step 9 lives in the market window)
 return pg:GetAttribute('TitleActive')==true or player:GetAttribute('RarePullCinematic')~=nil
end
-- On the biome track (same test as the shovel holes): true / false, or nil when the map has not said where the track is.
local function trackState()
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart');if not root then return nil end
 local motion=RS:FindFirstChild('RunnerMotion');local lineZ=motion and motion:GetAttribute('TrackBoundaryZ')
 if type(lineZ)~='number'then return nil end
 local cx,half=tonumber(motion:GetAttribute('TrackCenterX'))or 0,tonumber(motion:GetAttribute('TrackHalfWidth'))or 120
 return root.Position.Z>lineZ and math.abs(root.Position.X-cx)<=half
end
-- The track gate (where the pack arrow points while the server has no pack to show): the middle of the line between the bases and the track, a few studs onto the track.
local function trackGate()
 local motion=RS:FindFirstChild('RunnerMotion');local lineZ=motion and motion:GetAttribute('TrackBoundaryZ')
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 if type(lineZ)~='number'or not root then return nil end
 return Vector3.new(tonumber(motion:GetAttribute('TrackCenterX'))or 0,root.Position.Y,lineZ+8)
end
-- At home: off the track and on (or right by) your base pad, which the server sends; until it does, anywhere off the track.
local function atHome(onTrack)
 if onTrack==true then return false end
 local cf,size=S.info.HomeCFrame,S.info.HomeSize
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 if typeof(cf)~='CFrame'or typeof(size)~='Vector3'or not root then return true end
 local rel=cf:Inverse()*root.Position;local m=Guide.HomeMargin
 return math.abs(rel.X)<=size.X/2+m and math.abs(rel.Z)<=size.Z/2+m
end
-- A pack / seed to point at (owner: "the player can open ANY pack and it will count"): the newest one, and whether it is in your hand.
local function findTool(attribute)
 local character=player.Character;local best,bestHeld,bestN=nil,false,-1
 for _,holder in ipairs({character,player:FindFirstChildOfClass('Backpack')})do
  if holder then for _,t in ipairs(holder:GetChildren())do if t:IsA('Tool')and t:GetAttribute(attribute)then
   local n=tonumber(t:GetAttribute('PackNumber'))or 0;if n>bestN then best,bestHeld,bestN=t,holder==character,n end
  end end end
 end
 return best,bestHeld
end
local function inHand(attribute)local tool=player.Character and player.Character:FindFirstChildOfClass('Tool');return tool~=nil and tool:GetAttribute(attribute)~=nil end
local function travelButton(name)
 local t=pg:FindFirstChild('TravelButtons');local pair=t and t:FindFirstChild('TravelPair')
 return pair and pair.Visible and pair:FindFirstChild(name)or nil
end
-- The market window: 'Sell' (its Sell crops page) / 'Buy' / nil (closed); and its buttons.
local function market()
 if pg:GetAttribute('SeedMenu')~='Economy'then return nil end
 local ui=pg:FindFirstChild('ChestEconomyUI');local panel=ui and ui:FindFirstChild('EconomyPanel')
 local sell=panel and panel:FindFirstChild('HarvestSellMenu')
 return(sell and sell.Visible)and'Sell'or'Buy',panel
end
local function screenButton(name)
 if name=='TrackButton'or name=='BaseButton'then return travelButton(name)end
 if name=='SellMode'or name=='SellAll'then
  local _,panel=market();if not panel then return nil end
  if name=='SellMode'then local modes=panel:FindFirstChild('MarketModes');return modes and modes:FindFirstChild('SellMode')end
  local menu=panel:FindFirstChild('HarvestSellMenu');local box=menu and menu:FindFirstChild('BagSummary');return box and box:FindFirstChild('SellAll')
 end
 if name=='BonusRollButton'then local hud=pg:FindFirstChild('TreadmillBonusHud');local b=hud and hud:FindFirstChild('BonusRollButton');return b and b.Visible and b or nil end
 return nil
end
-- The hotbar slot showing a tool; falls back to the Bag button.
local function toolSlot(tool)
 local hot=pg:FindFirstChild('ChestToolHotbar');local dock=hot and hot:FindFirstChild('Dock');if not dock then return nil end
 local ok,wanted=pcall(Names.Tool,tool,Catalog)
 for i=1,10 do
  local slot=dock:FindFirstChild('Slot'..i);local label=slot and slot:FindFirstChild('ItemName')
  if slot and slot.Visible and label and ok and label.Text==wanted then return slot end
 end
 local bag=dock:FindFirstChild('OpenInventory');return bag and bag.Visible and bag or nil
end
-- What you see now: BeginnerGuide.Resolve over what this client sees (a table reused every time).
local function resolve()
 local c=S.ctx;local onTrack=trackState()
 c.Stage=player:GetAttribute('TutorialStep')or 0;c.Carrying=player:GetAttribute('ChestChaseSeedCarrying')==true;c.OnTrack=onTrack
 c.IntroDone=S.intro>=Guide.IntroSeconds;c.Waiting=S.info.WaitingForPack==true and S.info.Kind=='Pack'
 c.Home=atHome(onTrack)
 c.PackInHand=c.Stage==4 and inHand('SeedPackTool');c.SeedInHand=c.Stage==6 and inHand('GardenSeed')
 c.Ripe=S.info.Ripe==true or(S.readyAt~=nil and os.clock()>=S.readyAt)
 c.Menu=market();c.Bonus=S.bonus
 return Guide.Resolve(c)
end

-- R153 hotfix (KeyboardTrack died in Studio with "Out of local registers"): the world pieces live in one do-block, so their parts, constants and helpers go out of scope once built;
-- tools/tests/check_compile_O0.sh keeps every function under 180.
local folder,buildWorld,dropWorld,hideWorld,updateWorld
do
-- World pieces (this client only, so nobody else sees them; built while the tutorial runs, gone after): the big red 3D arrow, and the invisible anchor the billboards hang on ---------
local anchor,lastTarget
local arrowParts,arrowShown,arrowFrom,arrowTo,arrowFace,arrowOver={},false,nil,nil,nil,nil
local moveParts,moveFrames={}, {} -- reused every frame: only what moves is sent to BulkMoveTo
local PARKED=CFrame.new(0,-5000,0)
-- The red 3D arrow, in its own frame: the tip at the origin, the body toward +Z, flat in X-Z (its thickness along Y). Neon red head (two wedges) and shaft over thinner white rims
-- that stick out round the edges (never the same face: no z-fighting). Parts: {class, size, frame}.
local HEAD_L,HEAD_W,THICK,SHAFT_L,SHAFT_W,RIM=3.4,2.3,.9,4.4,1.5,.4
local arrowSpec
do
 local function half(sign,w,l,z0)return CFrame.fromMatrix(Vector3.new(sign*w/2,0,z0+l/2),Vector3.new(0,-sign,0),Vector3.new(sign,0,0))end
 local rw,rl=HEAD_W+.55,HEAD_L+.95
 arrowSpec={
  {'WedgePart',Vector3.new(THICK,HEAD_W,HEAD_L),half(1,HEAD_W,HEAD_L,0),true},{'WedgePart',Vector3.new(THICK,HEAD_W,HEAD_L),half(-1,HEAD_W,HEAD_L,0),true},
  {'Part',Vector3.new(SHAFT_W,THICK,SHAFT_L),CFrame.new(0,0,HEAD_L+SHAFT_L/2-.05),true},
  {'WedgePart',Vector3.new(RIM,rw,rl),half(1,rw,rl,-.6),false},{'WedgePart',Vector3.new(RIM,rw,rl),half(-1,rw,rl,-.6),false},
  {'Part',Vector3.new(SHAFT_W+.5,RIM,SHAFT_L+.45),CFrame.new(0,0,HEAD_L+SHAFT_L/2),false},
 }
end
local function solid(class,name,size,color,material)
 local p=Instance.new(class);p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Locked=true
 p.Size=size;p.Color=color;p.Material=material;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Transparency=1;p.CFrame=PARKED;p.Parent=folder
 return p
end
function buildWorld()
 if folder then return end
 folder=Instance.new('Folder');folder.Name='TutorialTrail';lastTarget=nil
 anchor=Instance.new('Part');anchor.Name='TutorialTarget';anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.CastShadow=false;anchor.Transparency=1;anchor.Size=Vector3.new(.1,.1,.1);anchor.CFrame=PARKED;anchor.Parent=folder
 arrowParts={}
 for i,spec in ipairs(arrowSpec)do arrowParts[i]=solid(spec[1],'GuideArrow',spec[2],spec[4]and COL.Arrow or WHITE,spec[4]and Enum.Material.Neon or Enum.Material.SmoothPlastic)end
 arrowShown,arrowFrom,arrowTo,arrowFace,arrowOver=false,nil,nil,nil,nil
 U.spot.Adornee=anchor;U.timer.Adornee=anchor
 folder.Parent=workspace
end
function dropWorld()
 set(U.spot,'Enabled',false);set(U.timer,'Enabled',false);set(edge,'Visible',false);U.spot.Adornee=nil;U.timer.Adornee=nil
 if folder then folder:Destroy()end;folder,anchor,lastTarget=nil,nil,nil;arrowParts={}
 arrowShown=false;table.clear(moveParts);table.clear(moveFrames)
end
-- The arrow goes out of sight, parked with the frame's other moves (parkArrow) or on its own (hideArrow).
local function parkArrow()
 if not arrowShown then return end;arrowShown=false;arrowFrom=nil
 for _,p in ipairs(arrowParts)do p.Transparency=1;moveParts[#moveParts+1]=p;moveFrames[#moveFrames+1]=PARKED end
end
local function hideArrow()
 if not arrowShown then return end
 table.clear(moveParts);table.clear(moveFrames);parkArrow()
 workspace:BulkMoveTo(moveParts,moveFrames,Enum.BulkMoveMode.FireCFrameChanged)
end
-- The goal of the look you see now (a part the server named, else its position; the pack arrow falls back to the track gate while no pack is out).
local function currentTarget()
 local look=S.look;if not look or not look.World then return nil end
 local info=S.info
 if info.Kind==look.World then
  local part=info.TargetPart
  if typeof(part)=='Instance'and part.Parent and part:IsA('BasePart')then return part.Position end
  if typeof(info.Target)=='Vector3'then return info.Target end
 end
 if look.World=='Pack'then return trackGate()end
 return nil
end
-- The big red 3D arrow, as the way (over = false): it floats ahead of you above head height, pointing toward the goal (its tip lifted a little, so its flat side faces the camera behind
-- you); or hovering over the goal (over = true) pointing down, its flat side to the camera. It bobs along the way it points (not with Reduced Motion: then it moves only when you, the
-- goal or the camera do).
local UP=Vector3.yAxis
local WAY=13 -- studs ahead of you where the way arrow floats
local function wayDirection(from,target)
 local d=Vector3.new(target.X-from.X,0,target.Z-from.Z);if d.Magnitude<.01 then return nil end
 return d.Unit
end
local function drawArrow(root,target,now,over)
 local from=root.Position;local camera=workspace.CurrentCamera;local still=calm()
 local face=camera and camera.CFrame.Position-target or Vector3.zAxis;face=Vector3.new(face.X,0,face.Z);if face.Magnitude<.01 then face=Vector3.zAxis end;face=face.Unit
 if still and arrowShown and arrowOver==over and arrowFrom and Cache.Same(arrowFrom,from)and Cache.Same(arrowTo,target)and Cache.Same(arrowFace,face)then return end
 arrowFrom,arrowTo,arrowFace,arrowOver=from,target,face,over
 local bob=still and 0 or math.floor(math.sin(now*4)*50+.5)/100
 local A
 if over then
  A=CFrame.fromMatrix(target+Vector3.new(0,4+bob,0),face:Cross(UP),face)
 else
  local d=wayDirection(from,target)or face
  A=CFrame.fromMatrix(from+d*(WAY+bob)+Vector3.new(0,2.5,0),d:Cross(UP),(UP-d*.5).Unit) -- (the tip lifts toward the way: seen from behind it points up the screen, its face to the camera)
 end
 if not arrowShown then arrowShown=true;for _,p in ipairs(arrowParts)do p.Transparency=0 end end
 for i,p in ipairs(arrowParts)do moveParts[#moveParts+1]=p;moveFrames[#moveFrames+1]=A*arrowSpec[i][3]end
end
-- Which ONE arrow a world goal gets: 'Over' (on screen and near), 'Way' (far, or off screen, while the floating arrow itself is in sight), else 'Edge' (it would be out of sight: the
-- goal is behind you or beside you). It changes with a margin, so an arrow on the border of the screen never flickers between two.
local function pickMode(root,target,dist)
 local camera=workspace.CurrentCamera;if not camera then return'Way'end
 local _,onScreen=camera:WorldToViewportPoint(target)
 if onScreen and dist<(S.mode=='Over'and Guide.NearArrow+4 or Guide.NearArrow)then return'Over'end
 local d=wayDirection(root.Position,target)
 if d then
  local at,visible=camera:WorldToViewportPoint(root.Position+d*WAY+Vector3.new(0,2.5,0))
  local view=Layout.Viewport(gui);local pad=S.mode=='Way'and 24 or 70
  if visible and at.X>=pad and at.X<=view.X-pad and at.Y>=pad and at.Y<=view.Y-pad then return'Way'end
 end
 return'Edge'
end
function hideWorld()hideArrow();set(U.spot,'Enabled',false);set(U.timer,'Enabled',false);set(edge,'Visible',false);S.mode=nil end
function updateWorld()
 if not folder then return end
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local target=currentTarget();local look=S.look
 if not root or not target or not S.shown then hideWorld();return end
 local now=os.clock();local still=calm()
 table.clear(moveParts);table.clear(moveFrames)
 local dist=Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z).Magnitude
 local mode=pickMode(root,target,dist);S.mode=mode
 local over=mode=='Over'
 -- The one arrow: over the goal, or the way, or (below) at the screen edge. A goal with a timer over it needs no arrow when it is near: the timer marks it.
 if mode=='Edge'or(over and look.Timer)then parkArrow()else drawArrow(root,target,now,over)end
 if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveFrames,Enum.BulkMoveMode.FireCFrameChanged)end
 if not(lastTarget and Cache.Same(lastTarget,target))then lastTarget=target;anchor.CFrame=CFrame.new(target)end
 -- On the goal: the pressing 👇 on the dirt (near), or the small ring timer over the plant.
 local pressing=look.Hand==true and over;local timing=look.Timer==true
 set(U.spot,'Enabled',pressing);set(U.timer,'Enabled',timing)
 if pressing then
  local phase=(now%.7)/.7;local dip=(still or phase>.2)and 0 or math.sin(phase/.2*math.pi)
  set(U.spotFinger,'Position',UDim2.new(.5,0,1,-14+math.floor(dip*8+.5)));local k=still and .5 or math.floor(phase*20)/20
  set(U.spotRipple,'Size',UDim2.fromOffset(20+k*70,8+k*26));set(U.spotRippleStroke,'Transparency',still and .3 or k)
 end
 if timing then
  local left=S.readyAt and math.max(0,S.readyAt-now)or 0;local total=math.max(1,S.growTotal or Guide.FirstFruitSeconds)
  set(U.timerText,'Text',tostring(math.ceil(left)));local lit=math.clamp(math.floor((1-left/total)*12+.0001),0,12)
  for i,dot in ipairs(U.timerDots)do set(dot,'BackgroundColor3',i<=lit and COL.Done or COL.Todo)end
 end
 -- The red arrow at the screen edge, pointing at the goal behind you.
 set(edge,'Visible',mode=='Edge')
 if mode=='Edge'then
  local camera=workspace.CurrentCamera;if not camera then return end
  local at=camera:WorldToViewportPoint(target)
  local view=Layout.Viewport(gui);local dx,dy=at.X-view.X/2,at.Y-view.Y/2
  if at.Z<0 then dx=-dx;dy=-dy end
  if math.abs(dx)+math.abs(dy)<1 then dy=1 end
  local scale=math.min((view.X/2-46)/math.max(math.abs(dx),.01),(view.Y/2-90)/math.max(math.abs(dy),.01))
  set(edge,'Position',UDim2.fromOffset(math.floor(view.X/2+dx*scale),math.floor(view.Y/2+dy*scale)));set(edge,'Rotation',math.floor(math.deg(math.atan2(dy,dx))-90))
 end
end
end

-- The pointer on a screen button: TRACK / BASE / the market's buttons / BONUS ROLL (S.look.Button), or the hotbar slot of the pack / seed to pick (S.look.Slot): a red arrow and a
-- pressing hand (BONUS ROLL: the arrow alone).
local function updateTap()
 local look=S.look;local b
 if S.shown and look then
  if look.Button then b=screenButton(look.Button)
  elseif look.Slot then local tool=findTool(look.Slot=='Pack'and'SeedPackTool'or'GardenSeed');b=tool and toolSlot(tool)end
 end
 if not b then set(tap,'Visible',false);return end
 local origin=tapGui.AbsolutePosition;local at=b.AbsolutePosition-origin;local size=b.AbsoluteSize;local now=os.clock();local still=calm()
 local big=S.metrics and S.metrics.Phone and 50 or 56;local press=not look.NoPress
 -- Every .7 s the finger dips onto the button.
 local phase=(now%.7)/.7;local dip=(still or phase>.2)and 0 or math.floor(math.sin(phase/.2*math.pi)*10+.5)/10
 local tipX,tipY=math.floor(at.X+size.X*.68),math.floor(at.Y+size.Y*.62)
 set(U.finger,'Visible',press)
 if press then set(U.finger,'Size',UDim2.fromOffset(big,big));set(U.finger,'Position',UDim2.fromOffset(tipX-dip*4,tipY-dip*6));set(U.fingerScale,'Scale',1-.12*dip)end
 -- The red arrow: on the side of the button that faces the middle of the screen, pointing at it, bobbing toward it.
 local view=tapGui.AbsoluteSize;local cx,cy=at.X+size.X/2,at.Y+size.Y/2;local dx,dy=view.X/2-cx,view.Y/2-cy
 if math.abs(dy)>=math.abs(dx)*.6 then dx=0;dy=dy>=0 and 1 or-1 else dy=0;dx=dx>=0 and 1 or-1 end
 local reach=(dx~=0 and size.X/2 or size.Y/2)+38+(press and dy>0 and 22 or 0)+(still and 0 or math.floor(math.abs(math.sin(now*5))*8+.5))
 set(U.pointer,'Position',UDim2.fromOffset(math.floor(cx+dx*reach),math.floor(cy+dy*reach)));set(U.pointer,'Rotation',dx>0 and 90 or dx<0 and-90 or dy>0 and 180 or 0) -- (the arrow points down in its box)
 set(tapGui,'DisplayOrder',(look.Button=='SellMode'or look.Button=='SellAll')and 31 or 27)
 set(tap,'Visible',true)
end

-- R138: the clicking indicator by the pack in your hand (step 4, until the pack opens).
local function updateClick()
 local function heldBag()
  local character=player.Character;local bag=character and character:FindFirstChild('CarriedSeed')
  if bag and bag:GetAttribute('SeedPackCarry')and not bag:GetAttribute('RevealAt')then return bag end
  return nil
 end
 local bag=S.look and S.look.Click and S.shown and heldBag()
 if not bag then set(CH.Hint,'Visible',false);S.clickSeen=0;return end
 local camera=workspace.CurrentCamera;local view=Layout.Viewport(gui)
 local at,onScreen=Vector3.new(view.X/2,view.Y*.6,1),false
 local root=bag.PrimaryPart or bag:FindFirstChildWhichIsA('BasePart',true)
 if camera and root then local p,visible=camera:WorldToViewportPoint(root.Position);if visible then at,onScreen=p,true end end
 local inset=gui.AbsolutePosition
 -- Phones: 72% size, and kept above the hotbar (it never covers the slots).
 local k=S.metrics and S.metrics.Phone and .72 or 1;local half=95*k
 local mr=S.metrics and Layout.Real(S.metrics) -- (R158: screen px; a computer's HUD is drawn at metrics.Scale)
 local barTop=mr and(view.Y-mr.HotbarBottom-mr.SlotSize-(mr.HotbarDetails~=false and(mr.HotbarDetailH or 44)or 0)-8)or view.Y-120
 local x=math.max(100*k,math.min(at.X-inset.X+(onScreen and 130*k or 0),view.X-100*k))
 local y=math.min(barTop-half,math.max(half+8,at.Y-inset.Y))
 set(CH.Hint,'Position',UDim2.fromOffset(math.floor(x),math.floor(y)));set(CH.Hint,'Visible',true)
 local look=Guide.ClickHint[device()]or Guide.ClickHint.Mouse
 set(CH.Hand,'Text',look.Hand);set(CH.Cap,'Visible',look.Key~=nil);set(CH.Key,'Text',look.Key or'')
 local need=math.max(1,tonumber(bag:GetAttribute('PackClicksRequired'))or 5);local done=math.clamp(tonumber(bag:GetAttribute('PackClickCount'))or 0,0,need)
 pipCount(need)
 for i=1,need do local p=CH.Pips[i];set(p,'BackgroundColor3',i<=done and COL.Here or COL.Todo);set(p,'BackgroundTransparency',i<=done and 0 or .2)end
 if done>S.clickSeen then S.clickSeen=done;S.clickPopAt=os.clock()end
 local now=os.clock();local still=calm()
 -- A press every .55 s: the hand dips and a ripple rings out from it.
 local phase=(now%.55)/.55
 set(CH.HandScale,'Scale',still and 1 or(phase<.16 and 1-.18*math.sin(phase/.16*math.pi)or 1))
 set(CH.Hand,'Rotation',still and 0 or-12)
 for i,r in ipairs(CH.Ripples)do
  local kk=((now/.55)+(i-1)*.5)%1
  set(r.Frame,'Visible',not still)
  if not still then set(r.Frame,'Size',UDim2.fromOffset(20+kk*90,20+kk*90));set(r.Stroke,'Transparency',kk)end
 end
 local age=now-S.clickPopAt;set(CH.Scale,'Scale',k*((not still and age<.2)and 1+.15*(1-age/.2)or 1))
end

-- What the tutorial shows now: the look the steps resolve to, whether the pointers show (not behind a menu, the title screen or a rare pull; the next pointer after a pack opens waits
-- while the reveal plays), and whether the ScreenGuis are on at all.
render=function()
 local stage=player:GetAttribute('TutorialStep')or 0
 local now=os.clock();local step,key=0,nil
 if stage>0 then step,key=resolve()end
 local active=key~=nil
 if active then buildWorld()elseif folder then dropWorld()end
 if active and S.lastKey and key~=S.lastKey and S.lastStep==4 and step>=5 then
  S.waitUntil=now+Guide.RevealSeconds
  task.delay(Guide.RevealSeconds+.02,function()if not S.dead then render()end end)
 end
 if step~=S.lastStep then S.stepSeconds=0;S.finishRetry=0;S.bonus=false;S.bonusSeconds=0 end
 if active then S.lastKey=key;S.lastStep=step else S.lastKey=nil;S.lastStep=0;S.waitUntil=0 end
 S.step=active and step or 0
 -- Nothing to show: the whole ScreenGui is off (no drawing). Back on: re-read the screen first.
 if active and not gui.Enabled then set(gui,'Enabled',true);S.metrics=Layout.Read(Layout.Viewport(gui),Input.TouchEnabled,Layout.Controls(gui))end
 set(gui,'Enabled',active);set(tapGui,'Enabled',active)
 S.look=active and Guide.Looks[key]or nil
 S.shown=active and now>=S.waitUntil and not blocked()and pg:GetAttribute('GardenMenuExpanded')~=true
end
-- The grow step's timer: when the server says how long the next fruit takes, the deadline is set once per fruit (a poll does not move it).
local function adoptInfo(result)
 S.info=result
 local at=result.ReadyAt
 if type(at)=='number'and type(result.ReadyIn)=='number'then
  if at~=S.readyFor then S.readyFor=at;S.readyAt=os.clock()+result.ReadyIn;S.growTotal=math.max(result.ReadyIn,1)end
 else S.readyFor,S.readyAt=nil,nil end
end
fetch=function(command)
 if S.busy or S.dead then return end;S.busy=true
 local expected=player:GetAttribute('TutorialStep');local carrying=player:GetAttribute('ChestChaseSeedCarrying')
 task.spawn(function()
  local ok,result=pcall(request.InvokeServer,request,'Tutorial',command or'State');S.busy=false;if S.dead then return end
  if ok and type(result)=='table'and result.Success then
   if command or(expected==player:GetAttribute('TutorialStep')and carrying==player:GetAttribute('ChestChaseSeedCarrying'))then adoptInfo(result)else S.info={}end
   render()
  elseif player:GetAttribute('TutorialStep')==nil then task.delay(1,function()if not S.dead then fetch()end end)end
 end)
end

local live=false -- pointers may be showing
local function hideAll()hideWorld();set(tap,'Visible',false);set(CH.Hint,'Visible',false);S.clickSeen=0 end
local connections=S.connections
connections[#connections+1]=Run.RenderStepped:Connect(function()
 if S.dead then return end
 -- Hidden (finished, a menu open, the title screen, a rare pull): hide every pointer once, then nothing per frame.
 if not S.shown then if live then live=false;hideAll()end;return end
 live=true
 updateWorld();updateTap();updateClick()
end)
connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
 if S.dead or(player:GetAttribute('TutorialStep')or 0)==0 then return end
 S.poll+=dt;if S.poll>=1 then S.poll=0;fetch()end
 -- Step 1: the spawn arrow shows this long, then the TRACK button.
 if S.lastKey=='Spawn'and S.shown then S.intro+=dt end
 -- Re-render as soon as what you see changes (on / off the track, home, the pack or seed in your hand, the fruit, the market window).
 S.lookPoll+=dt
 if S.lookPoll>=.15 then S.lookPoll=0;local step,key=resolve();if key~=S.lastKey or step~=S.lastStep then render()end end
 -- Step 10: the arrow on your treadmill until you hop on it (or its seconds pass, or your base has none), then the BONUS ROLL arrow for a few seconds, and the tutorial is done.
 if S.lastKey=='Treadmill'then
  if S.shown then S.stepSeconds+=dt end
  local noTreadmill=S.info.Kind=='Treadmill'and S.info.Target==nil and S.info.TargetPart==nil
  if player:GetAttribute('TreadmillTraining')==true or S.stepSeconds>=(Guide.Steps[10].Seconds or 10)or noTreadmill then S.bonus=true;render()end
 elseif S.lastKey=='Bonus'then
  if S.shown then S.bonusSeconds+=dt end
  if S.bonusSeconds>=Guide.BonusSeconds and os.clock()>=S.finishRetry then S.finishRetry=os.clock()+1.5;fetch('TreadmillInfo')end
 end
end)
for _,name in ipairs({'TutorialStep','ChestChaseSeedCarrying'})do connections[#connections+1]=player:GetAttributeChangedSignal(name):Connect(function()S.info={};S.readyFor,S.readyAt=nil,nil;render();task.delay(.25,function()fetch()end)end)end
connections[#connections+1]=player:GetAttributeChangedSignal('RarePullCinematic'):Connect(render)
-- R158f: the owner's /test tutorial reset / step / newplayer (the server counts TutorialRestart158f): start from the first look at once, as on a brand-new player's screen (a normal player never sees this change)
connections[#connections+1]=player:GetAttributeChangedSignal('TutorialRestart158f'):Connect(function()
 S.intro=0;S.info={};S.readyFor,S.readyAt=nil,nil;S.waitUntil=0;S.lastKey=nil;S.lastStep=0;S.stepSeconds=0;S.finishRetry=0;S.bonus=false;S.bonusSeconds=0
 render();task.delay(.25,function()if not S.dead then fetch()end end)
end)
for _,name in ipairs({'SeedMenu','TitleActive','GardenMenuExpanded'})do connections[#connections+1]=pg:GetAttributeChangedSignal(name):Connect(render)end
local unwatch=Layout.Watch(gui,function(m)S.metrics=m end)
local function cleanup()if S.dead then return end;S.dead=true;unwatch();dropWorld();for _,c in ipairs(connections)do c:Disconnect()end;tapGui:Destroy()end
gui.Destroying:Connect(cleanup);script.Destroying:Connect(function()cleanup();gui:Destroy()end)
render();fetch()
