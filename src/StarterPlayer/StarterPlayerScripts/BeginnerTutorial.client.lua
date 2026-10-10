do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R111: the game owner's avatar guides new players (built on this client only, so only you see it). R152: one idea per step, it moves on by itself the moment you do it.
-- R158e (owner: "shorten it even more ... a red arrow that points players towards the pack when they spawn, after that ... the track tp button, then ... they steal, then ... click via
-- the visual mouse indicator. then tp back to base using the tp button and then ... plant ... the first fruit is always 10 seconds growth time ... harvest and sell, and it ends with
-- letting them know the treadmill makes them run faster and every 6 mins gives them a bonus roll for more packs. EVERYTHING ... must be visual so no words all just arrows and pointing"):
-- ten steps, one at a time (BeginnerGuide.Steps / Looks / Resolve). Nothing here is a word: the card is a big icon, a picture row (icons, red ➜, key caps, a timer's numbers) and the
-- step row; in the world a big red 3D arrow (in front of you pointing the way, or bobbing over the goal), red chevrons on the ground, a light beam, your key in a bubble, a pressing 👇
-- on the dirt and a ring timer over the first plant; on the screen a red arrow at the screen edge when the goal is behind you, and a red arrow + pulsing ring + pressing hand on the
-- button to press (TRACK, BASE, a hotbar slot, the market's Sell buttons; the BONUS ROLL button without the hand). Nothing takes a click or tap but the two-tap ⏭. The world pieces
-- exist only while the tutorial runs. Reduced Motion: nothing bounces, pulses or flows.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService');local Tween=game:GetService('TweenService');local TextService=game:GetService('TextService')
local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local Guide=require(RS.BeginnerGuide);local Theme=require(RS.GardenTheme);local Layout=require(RS.HudLayout)
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
local okAudio,Audio=pcall(require,RS:WaitForChild('InteractionAudio'))
-- Step 10's clock: the bonus-roll interval as the server publishes it (TreadmillBonusService), else TreadmillBonusRules.IntervalSeconds (360 s = 6:00), never a number written here.
local okBonus,Bonus=pcall(function()return require(RS:WaitForChild('TreadmillBonusRules'))end)
-- R152 perf habit: everything animated per frame is written only when its value changes (PropCache152); nothing runs per frame while the card is hidden.
local Cache=require(RS:WaitForChild('PropCache152'));local set=Cache.new().Set
local RGB=Color3.fromRGB;local FONT=Enum.Font.FredokaOne;local INK=RGB(8,13,24);local WHITE=Color3.new(1,1,1)
local COL={Gold=ColorSequence.new(RGB(255,236,120),RGB(255,170,40)),Green=ColorSequence.new(RGB(170,255,140),RGB(56,192,72)),Key=ColorSequence.new(RGB(255,255,255),RGB(196,204,222)),
 Track=ColorSequence.new(RGB(255,176,90),RGB(226,137,47)),Base=ColorSequence.new(RGB(127,216,143),RGB(78,168,96)),
 Done=RGB(120,232,110),Here=RGB(255,214,79),Todo=RGB(14,20,48),Red=RGB(255,48,48),Arrow=RGB(255,38,38),Beam=RGB(255,236,120),Ring=RGB(255,232,72)}
local U,S={}, {} -- U: the pieces on screen and their parts; S: what the tutorial is doing
local function sound(key)if okAudio and Audio then pcall(Audio.Play,key)end end
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
-- A key cap (a key glyph drawn as an icon: E / X / R2): white, rounded, dark glyph. The glyph label is marked KeyGlyph (the only letters the tutorial draws).
local function keyCap(parent,name,z)
 local cap=frame(parent,name,z);cap.BackgroundColor3=WHITE;cap.BackgroundTransparency=0;round(cap,UDim.new(0,7));local fill=gradient(cap,RGB(255,255,255),RGB(196,204,222));stroke(cap,INK,2)
 local key=text(cap,'Key','',18,INK);key.Size=UDim2.fromScale(1,1);key.TextStrokeTransparency=1;key.TextScaled=true;key.ZIndex=z+1;key:SetAttribute('KeyGlyph',true)
 local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=22;fit.Parent=key
 return cap,key,fill
end

-- Screen pieces ---------------------------------------------------------------------------------------------------------------------------------------------------------
local gui=Instance.new('ScreenGui');gui.Name='BeginnerTutorial';gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local card=frame(gui,'GuideCard');card.AnchorPoint=Vector2.new(.5,0);card.BackgroundColor3=WHITE;card.BackgroundTransparency=0;card.Visible=false
do
 round(card,UDim.new(0,18));gradient(card,RGB(74,88,165),RGB(27,32,70));U.rim=stroke(card,RGB(255,214,79),3);U.pop=Instance.new('UIScale');U.pop.Parent=card
 local shine=frame(card,'Shine');shine.BackgroundColor3=WHITE;shine.BackgroundTransparency=.8;shine.Position=UDim2.fromOffset(16,5);shine.Size=UDim2.new(1,-32,0,3);round(shine)
 -- The guide: the owner's face (no name tag: no words).
 local badge=frame(card,'Guide',6);badge.AnchorPoint=Vector2.new(.5,.5);badge.BackgroundColor3=WHITE;badge.BackgroundTransparency=0;badge.Size=UDim2.fromOffset(30,30);badge.Position=UDim2.fromOffset(12,-1)
 round(badge);gradient(badge,RGB(190,255,120),RGB(58,190,72));stroke(badge,WHITE,2);U.badge=badge
 U.face=text(badge,'Face','🌱',30);U.face.Size=UDim2.fromScale(1,1);U.face.TextScaled=true;U.face.TextStrokeTransparency=1;U.face.ZIndex=7
 U.avatar=Instance.new('ImageLabel');U.avatar.Name='Avatar';U.avatar.BackgroundTransparency=1;U.avatar.Size=UDim2.fromScale(1,1);U.avatar.Visible=false;U.avatar.ZIndex=7;U.avatar.Parent=badge;round(U.avatar)
 -- The big step icon (gold; a green ✓ for the pop) and the ring that bursts out of it.
 U.icon=frame(card,'StepIcon',3);U.icon.BackgroundColor3=WHITE;U.icon.BackgroundTransparency=0
 round(U.icon);U.iconFill=gradient(U.icon,RGB(255,236,120),RGB(255,170,40));stroke(U.icon,WHITE,3)
 U.iconScale=Instance.new('UIScale');U.iconScale.Parent=U.icon
 U.glyph=text(U.icon,'Glyph','',40);U.glyph.AnchorPoint=Vector2.new(.5,.5);U.glyph.Position=UDim2.fromScale(.5,.52);U.glyph.Size=UDim2.fromScale(.78,.78);U.glyph.TextScaled=true;U.glyph.TextStrokeTransparency=1;U.glyph.ZIndex=4
 U.popRing=frame(card,'PopRing',8);U.popRing.AnchorPoint=Vector2.new(.5,.5);U.popRing.Visible=false;round(U.popRing);U.popStroke=stroke(U.popRing,RGB(160,255,120),4)
 -- The picture rows: up to 2 lines of 5 tiles, built once and reused (an emoji, a red ➜, a key cap, a coloured button pill, a number).
 U.rows,U.tiles={}, {}
 for r=1,2 do
  local row=frame(card,'Row'..r,3);U.rows[r]=row;U.tiles[r]={}
  for i=1,5 do
   local t=frame(row,'Tile'..i,4);t.Visible=false
   local cap,key,fill=keyCap(t,'Cap',4);cap.Size=UDim2.fromScale(1,1)
   local glyph=text(t,'Glyph','',24);glyph.Size=UDim2.fromScale(1,1);glyph.TextScaled=true;glyph.TextStrokeTransparency=.3;glyph.ZIndex=6
   local hold=frame(t,'Hold',5);hold.AnchorPoint=Vector2.new(.5,.5);hold.Position=UDim2.fromScale(.5,.5);round(hold);hold.Visible=false
   U.tiles[r][i]={Frame=t,Cap=cap,Key=key,Fill=fill,Glyph=glyph,Hold=hold,HoldStroke=stroke(hold,COL.Ring,3)}
  end
 end
 -- The step row: one icon per step; done = green ✓, now = gold and bigger.
 U.dots=frame(card,'Progress',3);U.dotFrames,U.links={}, {}
 for i,icon in ipairs(Guide.Progress)do
  local d=frame(U.dots,'Dot'..i,4);d.AnchorPoint=Vector2.new(.5,.5);d.BackgroundTransparency=0;round(d)
  local g=text(d,'Glyph',icon,13);g.Size=UDim2.fromScale(1,1);g.TextScaled=true;g.TextStrokeTransparency=1;g.ZIndex=5
  local ring=stroke(d,INK,1.5);ring.Name='Ring'
  U.dotFrames[i]=d
  if i>1 then local l=frame(U.dots,'Link'..i,3);l.AnchorPoint=Vector2.new(0,.5);l.BackgroundTransparency=0;U.links[i]=l end
 end
 -- ⏭ twice to skip (a stray tap on a phone does not end it): the first tap shows ❓ by it for 3 s.
 U.pill=frame(card,'StepPill',5);U.pill.AnchorPoint=Vector2.new(1,0);U.pill.BackgroundColor3=WHITE;U.pill.BackgroundTransparency=0;U.pill.Size=UDim2.fromOffset(34,24);U.pill.Visible=false
 round(U.pill);gradient(U.pill,RGB(255,140,140),RGB(214,52,52));stroke(U.pill,INK,2)
 U.pillText=text(U.pill,'Label','❓',16);U.pillText.Size=UDim2.fromScale(1,1);U.pillText.ZIndex=6;U.pillText.TextStrokeTransparency=1
 U.skip=Instance.new('TextButton');U.skip.Name='Skip';U.skip.AnchorPoint=Vector2.new(1,0);U.skip.Position=UDim2.new(1,-6,0,6);U.skip.Size=UDim2.fromOffset(30,30);U.skip.BackgroundColor3=RGB(16,20,48);U.skip.BackgroundTransparency=.35
 U.skip.Font=FONT;U.skip.Text='⏭';U.skip.TextSize=16;U.skip.TextColor3=RGB(227,232,240);U.skip.AutoButtonColor=true;U.skip.ZIndex=6;U.skip:SetAttribute('AccessibleLabel','Skip tutorial');U.skip.Parent=card;round(U.skip)
end
-- R138 (owner: "a clicking indicator to visually show players to keep clicking to open a pack"): by the pack in your hand, a mouse / finger / pad that keeps pressing with a ripple, and
-- one pip per click still needed (R158e: no word; a gamepad shows its R2 key cap).
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
-- Confetti when the tutorial is done.
local confetti=frame(gui,'Confetti',12);confetti.Size=UDim2.fromScale(1,1);confetti.Visible=false
local bits,flight={}, {}
for i=1,32 do local b=frame(confetti,'Bit'..i,12);b.AnchorPoint=Vector2.new(.5,.5);b.BackgroundTransparency=0;bits[i]=b;flight[i]={}end
-- The red arrow at the screen edge while the goal is off screen.
local edge=frame(gui,'Direction',11);edge.Size=UDim2.fromOffset(34,46);edge.AnchorPoint=Vector2.new(.5,.5);edge.Visible=false;arrow(edge,COL.Arrow)
-- Over the goal (always on top): the step icon in a bubble, or your key (E / X / 👆) in a cap that fills while you hold it.
do
 local goal=Instance.new('BillboardGui');goal.Name='Goal';goal.AlwaysOnTop=true;goal.Size=UDim2.fromOffset(84,84);goal.StudsOffsetWorldSpace=Vector3.new(0,13.5,0);goal.Enabled=false;goal.Parent=gui;U.goal=goal
 local bubble=frame(goal,'Bubble',2);bubble.AnchorPoint=Vector2.new(.5,.5);bubble.Position=UDim2.fromScale(.5,.5);bubble.Size=UDim2.fromOffset(58,58);bubble.BackgroundColor3=WHITE;bubble.BackgroundTransparency=0;round(bubble);stroke(bubble,COL.Arrow,3);U.bubble=bubble
 U.markerIcon=text(bubble,'Icon','',30);U.markerIcon.AnchorPoint=Vector2.new(.5,.5);U.markerIcon.Position=UDim2.fromScale(.5,.52);U.markerIcon.Size=UDim2.fromScale(.7,.7);U.markerIcon.TextScaled=true;U.markerIcon.TextStrokeTransparency=1;U.markerIcon.TextColor3=INK;U.markerIcon.ZIndex=3
 local cap,key=keyCap(goal,'Cap',4);cap.AnchorPoint=Vector2.new(.5,.5);cap.Position=UDim2.fromScale(.5,.5);cap.Size=UDim2.fromOffset(46,46);cap.Visible=false;U.goalCap,U.goalKey=cap,key
 U.goalHold=frame(goal,'Hold',3);U.goalHold.AnchorPoint=Vector2.new(.5,.5);U.goalHold.Position=UDim2.fromScale(.5,.5);round(U.goalHold);U.goalHoldStroke=stroke(U.goalHold,COL.Ring,4);U.goalHold.Visible=false
 -- On the garden dirt: a 👇 that keeps pressing it, with a ripple where it lands.
 local spot=Instance.new('BillboardGui');spot.Name='TapSpot';spot.AlwaysOnTop=true;spot.Size=UDim2.fromOffset(110,120);spot.StudsOffsetWorldSpace=Vector3.new(0,2.6,0);spot.Enabled=false;spot.Parent=gui;U.spot=spot
 U.spotRipple=frame(spot,'Ripple',1);U.spotRipple.AnchorPoint=Vector2.new(.5,.5);U.spotRipple.Position=UDim2.new(.5,0,1,-14);round(U.spotRipple);U.spotRippleStroke=stroke(U.spotRipple,RGB(255,236,120),3)
 U.spotFinger=text(spot,'Hand','👇',60);U.spotFinger.AnchorPoint=Vector2.new(.5,1);U.spotFinger.Position=UDim2.new(.5,0,1,-14);U.spotFinger.Size=UDim2.fromOffset(64,64);U.spotFinger.TextScaled=true;U.spotFinger.TextStrokeTransparency=1;U.spotFinger.ZIndex=2
 -- Over the first plant while it grows: 12 dots in a ring (one lights per twelfth of the wait) round the seconds left.
 local timer=Instance.new('BillboardGui');timer.Name='GrowTimer';timer.AlwaysOnTop=true;timer.Size=UDim2.fromOffset(104,104);timer.StudsOffsetWorldSpace=Vector3.new(0,7,0);timer.Enabled=false;timer.Parent=gui;U.timer=timer
 local face=frame(timer,'Face',1);face.AnchorPoint=Vector2.new(.5,.5);face.Position=UDim2.fromScale(.5,.5);face.Size=UDim2.fromOffset(62,62);face.BackgroundColor3=RGB(16,20,48);face.BackgroundTransparency=.15;round(face);stroke(face,WHITE,3)
 U.timerText=text(face,'Seconds','',30,RGB(255,236,120));U.timerText.Size=UDim2.fromScale(1,1);U.timerText.TextScaled=true;U.timerText.ZIndex=3
 U.timerDots={}
 for i=1,12 do
  local a=math.rad(i*30);local d=frame(timer,'Tick'..i,2);d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(11,11);d.BackgroundTransparency=0;d.BackgroundColor3=COL.Todo;round(d);stroke(d,WHITE,1.5)
  d.Position=UDim2.fromOffset(math.floor(52+math.sin(a)*44+.5),math.floor(52-math.cos(a)*44+.5));U.timerDots[i]=d
 end
end

-- The pointer on a screen button: a red arrow that points at it, a pulsing ring round it and a 👆 that keeps pressing it. Its own ScreenGui with no insets, above the card, the hotbar
-- (25), the BONUS ROLL button (26) and the BASE / TRACK row (24, in Roblox's top bar, outside the safe area the card uses); above the market window (30) while it points into it.
local tapGui=Instance.new('ScreenGui');tapGui.Name='BeginnerTutorialTap';tapGui.ResetOnSpawn=false;tapGui.DisplayOrder=27;tapGui.ScreenInsets=Enum.ScreenInsets.None;tapGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;tapGui.Parent=pg
local tap=frame(tapGui,'TapHand',20);tap.Size=UDim2.fromScale(1,1);tap.Visible=false
do
 U.tapRing=frame(tap,'Ring',20);round(U.tapRing,UDim.new(0,12));U.tapStroke=stroke(U.tapRing,COL.Ring,4)
 U.tapRipple=frame(tap,'Ripple',20);U.tapRipple.AnchorPoint=Vector2.new(.5,.5);round(U.tapRipple);U.tapRippleStroke=stroke(U.tapRipple,RGB(255,236,120),3)
 U.finger=text(tap,'Hand','👆',48);U.finger.AnchorPoint=Vector2.new(.3,.06);U.finger.Size=UDim2.fromOffset(52,52);U.finger.TextScaled=true;U.finger.TextStrokeTransparency=1;U.finger.Rotation=-24;U.finger.ZIndex=21
 U.fingerScale=Instance.new('UIScale');U.fingerScale.Name='Press';U.fingerScale.Parent=U.finger
 U.pointer=frame(tap,'Pointer',22);U.pointer.AnchorPoint=Vector2.new(.5,.5);U.pointer.Size=UDim2.fromOffset(34,46);arrow(U.pointer,COL.Arrow)
end

-- State -----------------------------------------------------------------------------------------------------------------------------------------------------------------
S.info={};S.step=0;S.key=nil;S.look=nil;S.lastKey=nil;S.lastStep=0;S.connections={};S.dead=false;S.busy=false
S.poll,S.lookPoll,S.stepSeconds,S.finishRetry,S.intro=0,0,0,0,0
S.finishedUntil,S.skipArmedUntil,S.niceUntil,S.popAt,S.wasActive,S.skipped,S.packComing=0,0,0,-math.huge,false,false,false
S.cardBottom,S.clickSeen,S.clickPopAt=0,0,-math.huge
S.ctx={}
local fetch,render,place
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
 c.Menu=market()
 return Guide.Resolve(c)
end

-- R153 hotfix (KeyboardTrack died in Studio with "Out of local registers"): the world pieces live in one do-block, so their parts, constants and helpers go out of scope once built;
-- tools/tests/check_compile_O0.sh keeps every function under 180.
local folder,buildWorld,dropWorld,hideWorld,updateWorld
do
-- World pieces (this client only, so nobody else sees them; built while the tutorial runs, gone after) ----------------------------------------------------------------
local anchor,ring,beam,lastTarget,lastSpot,trailFrom,trailTo;local trailParts,chevrons,lastAlpha,parked={}, {}, {}, {}
local moveParts,moveFrames={}, {} -- reused every frame: only what moves is sent to BulkMoveTo
local arrowParts,arrowShown,arrowFrom,arrowTo,arrowFace={},false,nil,nil,nil
local TRAIL_COUNT,SPACING,FLOW,REACH,BEAM_HEIGHT=36,3,4.5,2.4,60
local PARKED=CFrame.new(0,-5000,0)
-- Chevron in its own frame: forward is -Z, tip at z=-0.7. Red neon arms sit on slightly larger white rims.
local ARM=1.7;local shape
do local ANGLE,TIP=math.rad(45),-.7;local sa,ca=math.sin(ANGLE),math.cos(ANGLE)
shape={
 CFrame.new(-sa*ARM/2,.03,TIP+ca*ARM/2)*CFrame.Angles(0,-ANGLE,0),CFrame.new(sa*ARM/2,.03,TIP+ca*ARM/2)*CFrame.Angles(0,ANGLE,0),
 CFrame.new(-sa*ARM/2,0,TIP+ca*ARM/2)*CFrame.Angles(0,-ANGLE,0),CFrame.new(sa*ARM/2,0,TIP+ca*ARM/2)*CFrame.Angles(0,ANGLE,0),
}end
-- The big red 3D arrow, in its own frame: the tip at the origin, the body toward +Z, flat in X-Z (its thickness along Y). Neon red head (two wedges) and shaft over thinner white rims
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
local ringAlpha,beamAlpha=1,1
local function solid(class,name,size,color,material)
 local p=Instance.new(class);p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Locked=true
 p.Size=size;p.Color=color;p.Material=material;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Transparency=1;p.CFrame=PARKED;p.Parent=folder
 return p
end
function buildWorld()
 if folder then return end
 local function flat(name,size,color,material)local p=solid('Part',name,size,color,material);trailParts[#trailParts+1]=p;return p end
 folder=Instance.new('Folder');folder.Name='TutorialTrail';trailParts={};chevrons={};lastAlpha={};parked={};lastTarget,lastSpot,trailFrom=nil,nil,nil
 anchor=Instance.new('Part');anchor.Name='TutorialTarget';anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.CastShadow=false;anchor.Transparency=1;anchor.Size=Vector3.new(.1,.1,.1);anchor.CFrame=PARKED;anchor.Parent=folder
 for i=1,TRAIL_COUNT do
  chevrons[i]={flat('ArmL',Vector3.new(.7,.06,ARM),COL.Red,Enum.Material.Neon),flat('ArmR',Vector3.new(.7,.06,ARM),COL.Red,Enum.Material.Neon),
   flat('RimL',Vector3.new(1.1,.04,ARM+.4),WHITE,Enum.Material.SmoothPlastic),flat('RimR',Vector3.new(1.1,.04,ARM+.4),WHITE,Enum.Material.SmoothPlastic)}
  lastAlpha[i]=1;parked[i]=true
 end
 ring=flat('GoalSpot',Vector3.new(.1,6,6),COL.Beam,Enum.Material.Neon);ring.Shape=Enum.PartType.Cylinder
 -- A light beam standing on the goal, seen from far away (a cylinder lies along X, so it is turned upright).
 beam=flat('GoalBeam',Vector3.new(BEAM_HEIGHT,1.4,1.4),COL.Beam,Enum.Material.Neon);beam.Shape=Enum.PartType.Cylinder
 arrowParts={}
 for i,spec in ipairs(arrowSpec)do arrowParts[i]=solid(spec[1],'GuideArrow',spec[2],spec[4]and COL.Arrow or WHITE,spec[4]and Enum.Material.Neon or Enum.Material.SmoothPlastic)end
 arrowShown,arrowFrom,arrowTo,arrowFace=false,nil,nil,nil
 ringAlpha,beamAlpha=1,1;U.goal.Adornee=anchor;U.spot.Adornee=anchor;U.timer.Adornee=anchor
 folder.Parent=workspace
end
function dropWorld()
 set(U.goal,'Enabled',false);set(U.spot,'Enabled',false);set(U.timer,'Enabled',false);set(edge,'Visible',false);U.goal.Adornee=nil;U.spot.Adornee=nil;U.timer.Adornee=nil
 if folder then folder:Destroy()end;folder,anchor,ring,beam,lastTarget,lastSpot=nil,nil,nil,nil,nil,nil;trailParts,chevrons,lastAlpha,parked,arrowParts={}, {}, {}, {}, {}
 arrowShown=false;table.clear(moveParts);table.clear(moveFrames)
end
local function alphaFor(i,value)
 value=math.clamp(math.floor(value*100+.5)/100,0,1) -- (R153: 1/100: the chevrons fade without visible steps)
 if lastAlpha[i]==value then return end;lastAlpha[i]=value
 local c=chevrons[i];c[1].Transparency=value;c[2].Transparency=value;c[3].Transparency=math.max(value,.15);c[4].Transparency=math.max(value,.15)
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
local function hideTrail()
 if not folder then return end
 trailFrom=nil;for i=1,TRAIL_COUNT do alphaFor(i,1)end
 if ringAlpha~=1 then ringAlpha=1;ring.Transparency=1 end
 if beamAlpha~=1 then beamAlpha=1;beam.Transparency=1 end
 hideArrow()
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
-- Straight line from the player's feet to the goal, rebuilt every frame, so it never drifts away from the player. It ignores walls on purpose: each arrow is dropped onto whatever
-- floor is under its spot on the line.
local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.RespectCanCollide=true
local function ground(x,z,y,reach)
 reach=reach or 4
 local hit=workspace:Raycast(Vector3.new(x,y+reach,z),Vector3.new(0,-20-reach,0),rayParams)
 if hit then local n=hit.Normal.Y>.6 and hit.Normal or Vector3.yAxis;return hit.Position+n*.06,n end
 return Vector3.new(x,y,z),Vector3.yAxis
end
-- Only chevrons on the line move each frame; one past the goal is parked once and then left alone. With Reduced Motion the chevrons stand still.
local function drawTrail(root,target,now)
 local from=root.Position;local feet=from.Y-3
 if calm()and trailFrom and Cache.Same(trailFrom,from)and Cache.Same(trailTo,target)then return end
 trailFrom,trailTo=calm()and from or nil,target
 local flatDelta=Vector3.new(target.X-from.X,0,target.Z-from.Z);local length=flatDelta.Magnitude
 if length<.01 then for i=1,TRAIL_COUNT do alphaFor(i,1)end;return end
 local look=flatDelta/length;local phase=(calm()and 0 or(now*FLOW)%SPACING);local stop=length-REACH
 for i=1,TRAIL_COUNT do
  local s=.8+phase+(i-1)*SPACING;local c=chevrons[i]
  if s>stop then
   alphaFor(i,1)
   if not parked[i]then parked[i]=true;for k=1,4 do moveParts[#moveParts+1]=c[k];moveFrames[#moveFrames+1]=PARKED end end
  else
   parked[i]=false
   local y=feet+(target.Y-feet)*(s/length)
   local p,n=ground(from.X+look.X*s,from.Z+look.Z*s,y)
   local fwd=look-n*look:Dot(n);if fwd.Magnitude<.01 then fwd=look end;fwd=fwd.Unit
   local frame0=CFrame.fromMatrix(p,fwd:Cross(n).Unit,n,-fwd)
   for k=1,4 do moveParts[#moveParts+1]=c[k];moveFrames[#moveFrames+1]=frame0*shape[k]end
   -- Fade in at the feet and out at the goal.
   alphaFor(i,1-math.min(math.clamp((s-.8)/1.5,0,1),math.clamp((stop-s)/3,0,1)))
  end
 end
end
-- The big red 3D arrow: far from the goal it floats ahead of you above head height, pointing the way (its tip lifted a little, so its flat side faces the camera behind you); near it
-- (BeginnerGuide.NearArrow) it hovers over the goal pointing down, its flat side to the camera. It bobs along the way it points (not with Reduced Motion: then it moves only when
-- you, the goal or the camera do).
local UP=Vector3.yAxis
local function drawArrow(root,target,now,dist)
 local from=root.Position;local camera=workspace.CurrentCamera;local still=calm()
 local face=camera and camera.CFrame.Position-target or Vector3.zAxis;face=Vector3.new(face.X,0,face.Z);if face.Magnitude<.01 then face=Vector3.zAxis end;face=face.Unit
 if still and arrowShown and arrowFrom and Cache.Same(arrowFrom,from)and Cache.Same(arrowTo,target)and Cache.Same(arrowFace,face)then return end
 arrowFrom,arrowTo,arrowFace=from,target,face
 local bob=still and 0 or math.floor(math.sin(now*4)*50+.5)/100
 local A
 if dist<Guide.NearArrow then
  A=CFrame.fromMatrix(target+Vector3.new(0,4+bob,0),face:Cross(UP),face)
 else
  local d=Vector3.new(target.X-from.X,0,target.Z-from.Z).Unit
  A=CFrame.fromMatrix(from+d*(13+bob)+Vector3.new(0,2.5,0),d:Cross(UP),(UP-d*.5).Unit) -- (the tip lifts toward the way: seen from behind it points up the screen, its face to the camera)
 end
 if not arrowShown then arrowShown=true;for _,p in ipairs(arrowParts)do p.Transparency=0 end end
 for i,p in ipairs(arrowParts)do moveParts[#moveParts+1]=p;moveFrames[#moveFrames+1]=A*arrowSpec[i][3]end
end
local rayFor,rayFolder
function hideWorld()hideTrail();set(U.goal,'Enabled',false);set(U.spot,'Enabled',false);set(U.timer,'Enabled',false);set(edge,'Visible',false)end
function updateWorld()
 if not folder then return end
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local target=currentTarget();local look=S.look
 if not root or not target or blocked()or not card.Visible then hideWorld();return end
 if rayFor~=character or rayFolder~=folder then rayFor,rayFolder=character,folder;rayParams.FilterDescendantsInstances={folder,character}end
 local now=os.clock();local still=calm()
 table.clear(moveParts);table.clear(moveFrames)
 local dist=Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z).Magnitude
 if dist<6 or not look.Trail then trailFrom=nil;for i=1,TRAIL_COUNT do alphaFor(i,1)end else drawTrail(root,target,now)end
 if look.Arrow3D then drawArrow(root,target,now,dist)else parkArrow()end
 if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveFrames,Enum.BulkMoveMode.FireCFrameChanged)end
 -- Ring + beam on the floor under the goal (found again only when the goal moves), gently pulsing.
 if not(lastTarget and Cache.Same(lastTarget,target))then
  lastTarget=target;local spot=ground(target.X,target.Z,target.Y,24)
  if not(lastSpot and Cache.Same(lastSpot,spot))then
   lastSpot=spot;local up=CFrame.Angles(0,0,math.rad(90))
   ring.CFrame=CFrame.new(spot+Vector3.new(0,.05,0))*up;beam.CFrame=CFrame.new(spot+Vector3.new(0,BEAM_HEIGHT/2,0))*up;anchor.CFrame=CFrame.new(target)
  end
 end
 local pulse=still and .45 or math.floor((.45+.1*math.sin(now*5))*100+.5)/100
 if ringAlpha~=pulse then ringAlpha=pulse;ring.Transparency=pulse end
 local glow=still and .62 or math.floor((.62+.08*math.sin(now*3))*100+.5)/100
 if beamAlpha~=glow then beamAlpha=glow;beam.Transparency=glow end
 -- Over the goal: your key (the prompt looks; the market's only when you are by it), the pressing 👇 on the dirt, the ring timer over the plant, or the step icon.
 local d=device();local act=look.Prompt and(not look.PromptNear or dist<=look.PromptNear)and Guide.Act(d,look.Prompt)or nil
 local pressing=look.Hand==true;local timing=look.Timer==true
 set(U.goal,'Enabled',not pressing and not timing);set(U.spot,'Enabled',pressing);set(U.timer,'Enabled',timing)
 if pressing then
  local phase=(now%.7)/.7;local dip=(still or phase>.2)and 0 or math.sin(phase/.2*math.pi)
  set(U.spotFinger,'Position',UDim2.new(.5,0,1,-14+math.floor(dip*8+.5)));local k=still and .5 or math.floor(phase*20)/20
  set(U.spotRipple,'Size',UDim2.fromOffset(20+k*70,8+k*26));set(U.spotRippleStroke,'Transparency',still and .3 or k)
 elseif timing then
  local left=S.readyAt and math.max(0,S.readyAt-now)or 0;local total=math.max(1,S.growTotal or Guide.FirstFruitSeconds)
  set(U.timerText,'Text',tostring(math.ceil(left)));local lit=math.clamp(math.floor((1-left/total)*12+.0001),0,12)
  for i,dot in ipairs(U.timerDots)do set(dot,'BackgroundColor3',i<=lit and COL.Done or COL.Todo)end
 else
  local cap=type(act)=='table'and act.Key~=nil
  set(U.goalCap,'Visible',cap);set(U.bubble,'Visible',not cap);set(U.goalKey,'Text',cap and act.Key or'')
  set(U.markerIcon,'Text',type(act)=='string'and act or look.Marker or look.Icon or'')
  local holding=cap and look.Hold==true;set(U.goalHold,'Visible',holding)
  if holding then local k=still and .5 or(now%1.2)/1.2;set(U.goalHold,'Size',UDim2.fromOffset(52+math.floor(k*20),52+math.floor(k*20)));set(U.goalHoldStroke,'Transparency',still and .2 or math.floor(k*20)/20)end
  set(U.goal,'StudsOffsetWorldSpace',Vector3.new(0,13.5+(still and 0 or math.floor(math.sin(now*4)*10+.5)/20),0)) -- (above the 3D arrow)
 end
 local camera=workspace.CurrentCamera;if not camera then return end
 local at,onScreen=camera:WorldToViewportPoint(target)
 set(edge,'Visible',not onScreen)
 if not onScreen then
  local view=Layout.Viewport(gui);local dx,dy=at.X-view.X/2,at.Y-view.Y/2
  if at.Z<0 then dx=-dx;dy=-dy end
  if math.abs(dx)+math.abs(dy)<1 then dy=1 end
  local scale=math.min((view.X/2-46)/math.max(math.abs(dx),.01),(view.Y/2-90)/math.max(math.abs(dy),.01))
  set(edge,'Position',UDim2.fromOffset(math.floor(view.X/2+dx*scale),math.floor(view.Y/2+dy*scale)));set(edge,'Rotation',math.floor(math.deg(math.atan2(dy,dx))-90))
 end
end
end

-- The pointer on a screen button: TRACK / BASE / the market's buttons / BONUS ROLL (S.look.Button), or the hotbar slot of the pack / seed to pick (S.look.Slot).
local function updateTap()
 local look=S.look;local b
 if card.Visible and os.clock()>=S.niceUntil and look then
  if look.Button then b=screenButton(look.Button)
  elseif look.Slot then local tool=findTool(look.Slot=='Pack'and'SeedPackTool'or'GardenSeed');b=tool and toolSlot(tool)end
 end
 if not b then set(tap,'Visible',false);return end
 local origin=tapGui.AbsolutePosition;local at=b.AbsolutePosition-origin;local size=b.AbsoluteSize;local now=os.clock();local still=calm()
 local big=S.metrics and S.metrics.Phone and 50 or 56;local press=not look.NoPress
 set(U.tapRing,'Position',UDim2.fromOffset(at.X-6,at.Y-6));set(U.tapRing,'Size',UDim2.fromOffset(size.X+12,size.Y+12))
 set(U.tapStroke,'Transparency',still and .05 or math.floor((.05+.45*(.5+.5*math.sin(now*6)))*20+.5)/20)
 -- Every .7 s the finger dips onto the button and a ripple rings out where it lands.
 local phase=(now%.7)/.7;local dip=(still or phase>.2)and 0 or math.floor(math.sin(phase/.2*math.pi)*10+.5)/10
 local tipX,tipY=math.floor(at.X+size.X*.68),math.floor(at.Y+size.Y*.62)
 set(U.finger,'Visible',press);set(U.tapRipple,'Visible',press)
 if press then
  set(U.finger,'Size',UDim2.fromOffset(big,big));set(U.finger,'Position',UDim2.fromOffset(tipX-dip*4,tipY-dip*6));set(U.fingerScale,'Scale',1-.12*dip)
  local k=still and .4 or math.floor(phase*20)/20;set(U.tapRipple,'Position',UDim2.fromOffset(tipX,tipY));set(U.tapRipple,'Size',UDim2.fromOffset(12+k*44,12+k*44));set(U.tapRippleStroke,'Transparency',still and .3 or k)
 end
 -- The red arrow: on the side of the button that faces the middle of the screen, pointing at it, bobbing toward it.
 local view=tapGui.AbsoluteSize;local cx,cy=at.X+size.X/2,at.Y+size.Y/2;local dx,dy=view.X/2-cx,view.Y/2-cy
 if math.abs(dy)>=math.abs(dx)*.6 then dx=0;dy=dy>=0 and 1 or-1 else dy=0;dx=dx>=0 and 1 or-1 end
 local reach=(dx~=0 and size.X/2 or size.Y/2)+34+(press and dy>0 and 22 or 0)+(still and 0 or math.floor(math.abs(math.sin(now*5))*8+.5))
 set(U.pointer,'Position',UDim2.fromOffset(math.floor(cx+dx*reach),math.floor(cy+dy*reach)));set(U.pointer,'Rotation',dx>0 and 90 or dx<0 and-90 or dy>0 and 180 or 0) -- (the arrow points down in its box)
 set(tapGui,'DisplayOrder',(look.Button=='SellMode'or look.Button=='SellAll')and 31 or 27)
 set(tap,'Visible',true)
end
-- Card layout: [face] [big icon] [picture rows] [⏭] / step row. The card is as wide as its pictures need (BeginnerGuide.Card keeps it clear of the HUD and your character).
local function tileWidth(t,h)
 local spec=t.Spec
 if type(spec)=='table'then
  if spec.Pill then return math.floor(h*1.7)end
  if spec.Clock then return math.floor(h*2.1)end
  if spec.Timer then return math.floor(h*1.2)end
  if t.Cap.Visible then return math.max(h,#t.Key.Text*12+18)end
 end
 return t.Glyph.Text=='➜'and math.floor(h*.8)or h
end
local function layoutRows()
 local phone=S.metrics and S.metrics.Phone;local h=phone and 30 or 36;local widest=0
 for r,row in ipairs(U.rows)do
  local x=0
  for _,t in ipairs(U.tiles[r])do if t.Frame.Visible then
   local w=tileWidth(t,h);set(t.Frame,'Position',UDim2.fromOffset(x,0));set(t.Frame,'Size',UDim2.fromOffset(w,h));set(t.Hold,'Size',UDim2.fromOffset(w+12,h+12));x+=w+6
  end end
  set(row,'Size',UDim2.fromOffset(math.max(0,x-6),h));widest=math.max(widest,x-6)
 end
 return widest,h
end
local function layoutDots(width)
 local n=#U.dotFrames;local gap=width/math.max(1,n);local now=math.clamp(S.step,0,n)
 local finished=S.look==Guide.Finished or S.look==Guide.FinishedAgain;local nice=S.look==Guide.Nice
 local key=width..'|'..now..'|'..tostring(finished)..'|'..tostring(nice);if key==S.dotsFor then return end;S.dotsFor=key
 for i,d in ipairs(U.dotFrames)do
  local done=i<now or finished;local here=i==now and not finished and not nice
  local size=here and 22 or 16
  d.Size=UDim2.fromOffset(size,size);d.Position=UDim2.fromOffset(gap*(i-.5),9)
  d.BackgroundColor3=done and COL.Done or here and COL.Here or COL.Todo
  d.BackgroundTransparency=(done or here)and 0 or .25;d.Glyph.TextTransparency=(done or here)and 0 or .55
  d.Glyph.Text=done and'✓'or Guide.Progress[i];d.Glyph.TextColor3=WHITE
  if U.links[i]then local l=U.links[i];l.Position=UDim2.fromOffset(gap*(i-1.5)+10,9);l.Size=UDim2.fromOffset(math.max(0,gap-20),3);l.BackgroundColor3=done and COL.Done or WHITE;l.BackgroundTransparency=done and 0 or .7 end
 end
end
place=function()
 local m=S.metrics;if not m then return end
 local view=Layout.Viewport(gui);local w,h=view.X,view.Y
 local phone=m.Phone;local icon=phone and 62 or 74;local x0=14+icon+14;local skip=phone and 40 or 30
 local rowsW,th=layoutRows();local two=U.rows[2].Visible
 local cardH=(phone and 100 or 112)+(two and(phone and 6 or 8)or 0);S.cardH=cardH -- (two rows stand beside the icon: a few px more, so it still fits a small portrait phone)
 -- The reserved box includes the 12px the face sticks out above the card; the card is as wide as its pictures (and the 10-step row) need.
 local function reserved()return cardH+12 end
 local want=math.max(phone and 300 or 360,math.floor(x0+math.max(rowsW,phone and 210 or 240)+skip+20))
 -- With TRACK / BASE pointed at (the top bar row), the card starts below the pressing hand if it still gets its full width there; strict first; small screens may let the card
 -- reach the head, then drop the reservation.
 local name=S.look and S.look.Button;local b=(name=='TrackButton'or name=='BaseButton')and travelButton(name);local c
 if b then c=Guide.Card(w,h,m,reserved,nil,math.floor(b.AbsolutePosition.Y-gui.AbsolutePosition.Y+b.AbsoluteSize.Y+(phone and 26 or 34)),want)end
 if not(c and c.Clear and c.Width>=math.min(want,w-24))then c=Guide.Card(w,h,m,reserved,nil,nil,want)end
 if not c.Clear then c=Guide.Card(w,h,m,reserved,1,nil,want)end
 if not c.Clear then c=Guide.Card(w,h,m,reserved,2,nil,want)end
 S.cardBottom=c.Top+c.Height
 card.Position=UDim2.fromOffset(c.X,c.Top+12);card.Size=UDim2.fromOffset(c.Width,c.Height-12)
 local H=c.Height-12
 local iconY=math.floor((H-22-icon)/2)+6
 U.icon.Size=UDim2.fromOffset(icon,icon);U.icon.Position=UDim2.fromOffset(14,iconY);U.popRing.Position=UDim2.fromOffset(14+icon/2,iconY+icon/2)
 local rowsTop=math.floor((H-22-(two and th*2+6 or th))/2)+2
 U.rows[1].Position=UDim2.fromOffset(x0,rowsTop);U.rows[2].Position=UDim2.fromOffset(x0,rowsTop+th+6)
 U.skip.Size=UDim2.fromOffset(skip,skip);U.pill.Position=UDim2.new(1,-skip-14,0,-12)
 U.dots.Position=UDim2.fromOffset(x0,H-22);U.dots.Size=UDim2.new(1,-x0-14,0,18);layoutDots(c.Width-x0-14)
end
-- One tile: an emoji / ➜ / number, your device's key cap or glyph, or a button's coloured pill.
local function bonusClock()
 local seconds=tonumber(player:GetAttribute('TreadmillBonusInterval'))or(okBonus and type(Bonus)=='table'and Bonus.IntervalSeconds)or nil
 return seconds and Guide.Clock(seconds)or''
end
local function fillTile(t,spec,d)
 t.Spec=spec;local show=spec~=nil;local glyph,key,fill,hold,color='',nil,COL.Key,false,WHITE
 if type(spec)=='string'then glyph=spec;if spec=='➜'then color=COL.Arrow end
 elseif type(spec)=='table'then
  if spec.Act then local a=Guide.Act(d,spec.Act);if type(a)=='table'then key=a.Key else glyph=a or''end;hold=spec.Hold==true and key~=nil
  elseif spec.Pill then key='';fill=COL[spec.Pill]or COL.Key;glyph=spec.Pill=='Track'and'🏃'or'🏠'
  elseif spec.Timer then glyph=S.readyAt and tostring(math.ceil(math.max(0,S.readyAt-os.clock())))or'';color=COL.Here
  elseif spec.Clock then glyph=bonusClock();color=COL.Here end
 end
 set(t.Frame,'Visible',show);set(t.Cap,'Visible',key~=nil);set(t.Key,'Text',key or'');set(t.Fill,'Color',fill);set(t.Glyph,'Text',glyph);set(t.Glyph,'TextColor3',color);set(t.Hold,'Visible',hold)
end
-- One look (BeginnerGuide.Looks, Nice, Finished): the icon, the picture rows for this device; the card is placed again only when what it holds changes.
local function apply(look)
 S.look=look
 local d=device()
 set(U.glyph,'Text',look.Icon or'');set(U.iconFill,'Color',look==Guide.Nice and COL.Green or COL.Gold)
 local rows=look.Rows or{look.Row}
 for r=1,2 do
  local list=rows[r];set(U.rows[r],'Visible',list~=nil)
  for i,t in ipairs(U.tiles[r])do fillTile(t,list and list[i]or nil,d)end
 end
 local key=tostring(look.Key)..'|'..d..'|'..tostring(look.Button)..'|'..tostring(S.metrics and S.metrics.Phone)
 if key~=S.placedFor then S.placedFor=key;place()else layoutRows()end
end
local function bounce(scale,from)
 if calm()then scale.Scale=1;return end
 scale.Scale=from;Tween:Create(scale,TweenInfo.new(.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
end

-- R138: the clicking indicator by the pack in your hand (step 4, until the pack opens).
local function updateClick()
 local function heldBag()
  local character=player.Character;local bag=character and character:FindFirstChild('CarriedSeed')
  if bag and bag:GetAttribute('SeedPackCarry')and not bag:GetAttribute('RevealAt')then return bag end
  return nil
 end
 local bag=S.look and S.look.Click and card.Visible and os.clock()>=S.niceUntil and heldBag()
 if not bag then set(CH.Hint,'Visible',false);S.clickSeen=0;return end
 local camera=workspace.CurrentCamera;local view=Layout.Viewport(gui)
 local at,onScreen=Vector3.new(view.X/2,view.Y*.6,1),false
 local root=bag.PrimaryPart or bag:FindFirstChildWhichIsA('BasePart',true)
 if camera and root then local p,visible=camera:WorldToViewportPoint(root.Position);if visible then at,onScreen=p,true end end
 local inset=gui.AbsolutePosition
 -- Phones: 72% size, and kept between the card and the hotbar (it never covers the slots).
 local k=S.metrics and S.metrics.Phone and .72 or 1;local half=95*k
 local mr=S.metrics and Layout.Real(S.metrics) -- (R158: screen px; a computer's HUD is drawn at metrics.Scale)
 local barTop=mr and(view.Y-mr.HotbarBottom-mr.SlotSize-(mr.HotbarDetails~=false and(mr.HotbarDetailH or 44)or 0)-8)or view.Y-120
 local x=math.max(100*k,math.min(at.X-inset.X+(onScreen and 130*k or 0),view.X-100*k))
 local y=math.min(barTop-half,math.max(S.cardBottom+half-12,at.Y-inset.Y));if barTop-half<S.cardBottom+half-12 then y=(barTop+S.cardBottom-12)/2 end
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
-- R138: confetti over the finish card.
local function startConfetti()
 if calm()then return end
 S.confettiAt=os.clock();set(confetti,'Visible',true)
 local view=Layout.Viewport(gui);local colors={RGB(255,214,79),RGB(120,232,110),RGB(110,190,255),RGB(255,110,150),RGB(200,140,255)}
 for i,b in ipairs(bits)do
  local f=flight[i];f.X=view.X/2+(math.random()-.5)*80;f.Y=S.cardBottom-30;f.VX=(math.random()-.5)*620;f.VY=-260-math.random()*360;f.Spin=(math.random()-.5)*900
  b.BackgroundColor3=colors[(i-1)%#colors+1];b.Size=UDim2.fromOffset(6+(i%3)*3,10+(i%2)*6)
 end
end
local function updateConfetti()
 if not S.confettiAt then return end
 local age=os.clock()-S.confettiAt
 if age>2.4 then S.confettiAt=nil;set(confetti,'Visible',false);return end
 local fade=math.clamp((age-1.6)/.8,0,1)
 for i,b in ipairs(bits)do
  local f=flight[i]
  b.Position=UDim2.fromOffset(f.X+f.VX*age,f.Y+f.VY*age+520*age*age);b.Rotation=f.Spin*age;set(b,'BackgroundTransparency',fade)
 end
end
local function updatePop()
 local age=os.clock()-S.popAt
 if age>.45 or calm()then set(U.popRing,'Visible',false);return end
 local icon=U.icon.Size.X.Offset;local k=age/.45
 set(U.popRing,'Visible',true);U.popRing.Size=UDim2.fromOffset(icon*(1+.9*k),icon*(1+.9*k));U.popStroke.Transparency=k
end
-- The hold ring on a key tile and the timer tile, while the card shows.
local function updateTiles(now)
 local still=calm()
 for r=1,2 do for _,t in ipairs(U.tiles[r])do local spec=t.Spec
  if type(spec)=='table'then
   if t.Hold.Visible then local k=still and .5 or(now%1.2)/1.2;set(t.HoldStroke,'Transparency',still and .2 or math.floor(k*20)/20)end
   if spec.Timer then set(t.Glyph,'Text',S.readyAt and tostring(math.ceil(math.max(0,S.readyAt-now)))or'')end
  end
 end end
end

-- A step forward pops (a green ✓ + a bubble sound, then the next step bounces in); 1 -> 2 is the spawn arrow's time running out (no pop), a few moves inside a step pop too.
local POPS={['Grab>Carry']=true,['PickSeed>Plant']=true}
render=function()
 local stage=player:GetAttribute('TutorialStep')or 0
 if stage>0 then S.wasActive=true end
 if stage==10 then S.packComing=player:GetAttribute('StarterPackClaimed')~=true end
 local now=os.clock();local step,key=0,nil
 if stage>0 then step,key=resolve()end
 local active=key~=nil
 local finishing=not active and now<S.finishedUntil
 if active then buildWorld()elseif folder then dropWorld()end
 if active and S.lastKey and key~=S.lastKey then
  local forward=(step>S.lastStep and not(S.lastStep==1 and step==2))or POPS[S.lastKey..'>'..key]or(S.lastKey=='Base'and S.lastStep==step)
  if forward then
   S.niceUntil=now+(S.lastStep==4 and step>=5 and Guide.RevealSeconds or Guide.NiceSeconds);S.popAt=now;sound('Bubble06')
   task.delay(S.niceUntil-now+.02,function()if not S.dead then render()end end)
  end
 end
 if step~=S.lastStep then S.stepSeconds=0;S.finishRetry=0 end
 if active then S.lastKey=key;S.lastStep=step else S.lastKey=nil;S.lastStep=0;S.niceUntil=0 end
 local nice=active and now<S.niceUntil
 S.step=active and step or(finishing and Guide.StepCount+1 or 0)
 -- Nothing to show: the whole ScreenGui is off (no layout, no drawing). Back on: re-read the screen first.
 local on=active or finishing
 if on and not gui.Enabled then set(gui,'Enabled',true);S.metrics=Layout.Read(Layout.Viewport(gui),Input.TouchEnabled,Layout.Controls(gui));S.placedFor=nil;S.dotsFor=nil end
 set(gui,'Enabled',on);set(tapGui,'Enabled',on)
 set(card,'Visible',on and not blocked()and pg:GetAttribute('GardenMenuExpanded')~=true)
 set(U.pill,'Visible',now<S.skipArmedUntil)
 if finishing then apply(S.packComing and Guide.Finished or Guide.FinishedAgain)
 elseif nice then apply(Guide.Nice)
 elseif active then apply(Guide.Looks[key])
 else S.look=nil end
 if S.metrics then layoutDots(math.max(100,card.Size.X.Offset-(S.metrics.Phone and 90 or 102)-14))end
 local showing=finishing and'Finished'or nice and'Nice'or key
 if card.Visible and showing~=S.shownKey then
  if S.shownKey==nil and active then sound('Bubble04')end
  bounce(U.iconScale,.6);bounce(U.pop,.86)
 end
 S.shownKey=card.Visible and showing or S.shownKey
 if not active and not finishing then S.shownKey=nil end
 local bottom=card.Visible and S.cardBottom or nil
 if pg:GetAttribute('TutorialCardBottom')~=bottom then pg:SetAttribute('TutorialCardBottom',bottom)end
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

U.skip.Activated:Connect(function()
 if os.clock()<S.skipArmedUntil then S.skipArmedUntil=0;S.finishedUntil=0;S.skipped=true;fetch('Skip');return end
 S.skipArmedUntil=os.clock()+3;set(U.pill,'Visible',true)
 task.delay(3.05,function()if not S.dead and os.clock()>=S.skipArmedUntil then render()end end)
end)

local live=false -- pointers may be showing
local function hideAll()hideWorld();set(tap,'Visible',false);set(CH.Hint,'Visible',false);S.clickSeen=0;set(U.popRing,'Visible',false)end
local connections=S.connections
connections[#connections+1]=Run.RenderStepped:Connect(function()
 if S.dead then return end
 updateConfetti()
 -- Card hidden (finished, a menu open, the title screen, a rare pull): hide every pointer once, then nothing per frame.
 if not card.Visible then if live then live=false;hideAll()end;return end
 live=true
 local now=os.clock()
 if not calm()then set(U.badge,'Rotation',math.floor(math.sin(now*2.4)*40+.5)/10)end
 set(U.rim,'Transparency',calm()and .15 or math.floor((.15+.15*math.sin(now*3))*100+.5)/100)
 if now<S.niceUntil then hideWorld()else updateWorld()end
 updateTap();updateClick();updatePop();updateTiles(now)
end)
connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
 if S.dead or(player:GetAttribute('TutorialStep')or 0)==0 then return end
 S.poll+=dt;if S.poll>=1 then S.poll=0;fetch()end
 local shown=card.Visible and os.clock()>=S.niceUntil
 -- Step 1: the spawn arrow shows this long (on screen), then the TRACK button.
 if S.lastKey=='Spawn'and shown then S.intro+=dt end
 -- Re-render as soon as what you see changes (on / off the track, home, the pack or seed in your hand, the fruit, the market window).
 S.lookPoll+=dt
 if S.lookPoll>=.15 then S.lookPoll=0;local step,key=resolve();if key~=S.lastKey or step~=S.lastStep then render()end end
 -- Step 10: hop on your treadmill (or its seconds pass, or your base has none) and the tutorial is done.
 if S.lastKey=='Treadmill'then
  if shown then S.stepSeconds+=dt end
  local noTreadmill=S.info.Kind=='Treadmill'and S.info.Target==nil and S.info.TargetPart==nil
  if(player:GetAttribute('TreadmillTraining')==true or S.stepSeconds>=(Guide.Steps[10].Seconds or 10)or noTreadmill)and os.clock()>=S.finishRetry then
   S.finishRetry=os.clock()+1.5;fetch('TreadmillInfo')
  end
 end
end)
for _,name in ipairs({'TutorialStep','ChestChaseSeedCarrying'})do connections[#connections+1]=player:GetAttributeChangedSignal(name):Connect(function()S.info={};S.readyFor,S.readyAt=nil,nil;render();task.delay(.25,function()fetch()end)end)end
connections[#connections+1]=player:GetAttributeChangedSignal('TutorialDone'):Connect(function()
 if player:GetAttribute('TutorialDone')==true and S.wasActive and not S.skipped then S.finishedUntil=os.clock()+Guide.FinishSeconds;sound('GemClaim');startConfetti();task.delay(Guide.FinishSeconds+.1,function()if not S.dead then render()end end)end
 S.wasActive=false;S.skipped=false;render()
end)
connections[#connections+1]=player:GetAttributeChangedSignal('RarePullCinematic'):Connect(render)
for _,name in ipairs({'SeedMenu','TitleActive','GardenMenuExpanded'})do connections[#connections+1]=pg:GetAttributeChangedSignal(name):Connect(render)end
connections[#connections+1]=Input.LastInputTypeChanged:Connect(function()local now=device();if now~=S.lastDevice then S.lastDevice=now;if S.step>0 then S.placedFor=nil;render()end end end)
local unwatch=Layout.Watch(gui,function(m)local was=S.metrics and S.metrics.Phone;S.metrics=m;if was~=m.Phone then S.placedFor=nil;render()end;place();if card.Visible then pg:SetAttribute('TutorialCardBottom',S.cardBottom)end end)
local function cleanup()if S.dead then return end;S.dead=true;unwatch();dropWorld();pg:SetAttribute('TutorialCardBottom',nil);for _,c in ipairs(connections)do c:Disconnect()end;tapGui:Destroy()end
gui.Destroying:Connect(cleanup);script.Destroying:Connect(function()cleanup();gui:Destroy()end)
-- The guide is the game owner's face (or BeginnerGuide.GuideUserId); in Studio it is you. Falls back to the sprout.
task.spawn(function()
 local id=Guide.GuideUserId
 if type(id)~='number'or id<=0 then
  id=nil
  if game.CreatorType==Enum.CreatorType.User and game.CreatorId>0 then id=game.CreatorId
  elseif game.CreatorType==Enum.CreatorType.Group and game.CreatorId>0 then
   local ok,group=pcall(function()return game:GetService('GroupService'):GetGroupInfoAsync(game.CreatorId)end)
   if ok and type(group)=='table'and type(group.Owner)=='table'then id=tonumber(group.Owner.Id)end
  end
  if not id and Run:IsStudio()and player.UserId>0 then id=player.UserId end
 end
 if not id or S.dead then return end
 local ok,image=pcall(Players.GetUserThumbnailAsync,Players,id,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
 if ok and type(image)=='string'and image~=''and not S.dead then U.avatar.Image=image;U.avatar.Visible=true;U.face.Visible=false end
end)
render();fetch()
