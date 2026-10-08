do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R111: the game owner's avatar guides new players: an objective card at the top centre and a red chevron path from your feet
-- to every goal (built on this client only, so only you see it).
-- R152 (owner: "make tutorial understandable in 5 seconds for new players see player know instantly"): each step is one big
-- icon, a few words and your device's key; a light beam + ring + bubble sit on the exact thing, a pressing hand on the exact
-- button (hotbar slot, TRACK, BASE) or on your garden dirt; the step moves on by itself the moment you do it, with a ✓ NICE!!
-- pop. No welcome page, no slides; nothing here takes a click or tap but the two-tap X. The world pieces exist only while
-- the tutorial runs. Words, icons and targets: BeginnerGuide.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService');local Tween=game:GetService('TweenService');local TextService=game:GetService('TextService')
local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local Guide=require(RS.BeginnerGuide);local Theme=require(RS.GardenTheme);local Layout=require(RS.HudLayout)
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
local okAudio,Audio=pcall(require,RS:WaitForChild('InteractionAudio'))
-- R152 perf habit: everything animated per frame is written only when its value changes (PropCache152); nothing runs per frame
-- while the card is hidden; the whole ScreenGui is off while there is nothing to show.
local Cache=require(RS:WaitForChild('PropCache152'));local set=Cache.new().Set
local RGB=Color3.fromRGB;local FONT=Enum.Font.FredokaOne;local INK=RGB(8,13,24);local WHITE=Color3.new(1,1,1)
local COL={Gold=ColorSequence.new(RGB(255,236,120),RGB(255,170,40)),Green=ColorSequence.new(RGB(170,255,140),RGB(56,192,72)),Plain=ColorSequence.new(RGB(255,255,255),RGB(196,204,222)),
 Done=RGB(120,232,110),Here=RGB(255,214,79),Todo=RGB(14,20,48),Red=RGB(255,48,48),Beam=RGB(255,236,120)}
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

-- Screen pieces ---------------------------------------------------------------------------
local gui=Instance.new('ScreenGui');gui.Name='BeginnerTutorial';gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
-- The card: [big icon] TITLE / [key] chip / step row. Only the X takes input.
local card=frame(gui,'GuideCard');card.AnchorPoint=Vector2.new(.5,0);card.BackgroundColor3=WHITE;card.BackgroundTransparency=0;card.Visible=false
round(card,UDim.new(0,18));gradient(card,RGB(74,88,165),RGB(27,32,70));local rim=stroke(card,RGB(255,214,79),3);local pop=Instance.new('UIScale');pop.Parent=card
do local shine=frame(card,'Shine');shine.BackgroundColor3=WHITE;shine.BackgroundTransparency=.8;shine.Position=UDim2.fromOffset(16,5);shine.Size=UDim2.new(1,-32,0,3);round(shine) end
local badge=frame(card,'Guide',6);badge.AnchorPoint=Vector2.new(.5,.5);badge.BackgroundColor3=WHITE;badge.BackgroundTransparency=0
round(badge);gradient(badge,RGB(190,255,120),RGB(58,190,72));stroke(badge,WHITE,2)
local face=text(badge,'Face','🌱',30);face.Size=UDim2.fromScale(1,1);face.TextScaled=true;face.TextStrokeTransparency=1;face.ZIndex=7
local avatar=Instance.new('ImageLabel');avatar.Name='Avatar';avatar.BackgroundTransparency=1;avatar.Size=UDim2.fromScale(1,1);avatar.Visible=false;avatar.ZIndex=7;avatar.Parent=badge;round(avatar)
local nameTag=frame(card,'NameTag',5);nameTag.BackgroundColor3=WHITE;nameTag.BackgroundTransparency=0;nameTag.Size=UDim2.fromOffset(0,22);nameTag.AutomaticSize=Enum.AutomaticSize.X
do local tagPad=Instance.new('UIPadding');tagPad.PaddingLeft=UDim.new(0,22);tagPad.PaddingRight=UDim.new(0,10);tagPad.Parent=nameTag end
round(nameTag);gradient(nameTag,RGB(190,255,120),RGB(58,190,72));stroke(nameTag,INK,2)
local tagText=text(nameTag,'Label',type(Guide.GuideName)=='string'and Guide.GuideName~=''and string.upper(Guide.GuideName)or'GUIDE',14);tagText.Size=UDim2.fromScale(0,1);tagText.AutomaticSize=Enum.AutomaticSize.X;tagText.ZIndex=6
-- The big step icon (gold; green with a ✓ for the pop) and the ring that bursts out of it.
local stepIcon=frame(card,'StepIcon',3);stepIcon.BackgroundColor3=WHITE;stepIcon.BackgroundTransparency=0
round(stepIcon);local iconFill=gradient(stepIcon,RGB(255,236,120),RGB(255,170,40));stroke(stepIcon,WHITE,3)
local iconScale=Instance.new('UIScale');iconScale.Parent=stepIcon
local glyph=text(stepIcon,'Glyph','',40);glyph.AnchorPoint=Vector2.new(.5,.5);glyph.Position=UDim2.fromScale(.5,.52);glyph.Size=UDim2.fromScale(.78,.78);glyph.TextScaled=true;glyph.TextStrokeTransparency=1;glyph.ZIndex=4
local popRing=frame(card,'PopRing',8);popRing.AnchorPoint=Vector2.new(.5,.5);popRing.Visible=false;round(popRing);local popStroke=stroke(popRing,RGB(160,255,120),4)
-- The words: a title (4 words at most) and one chip: [key cap] or ➜, then 1-3 words.
local message=text(card,'Instruction','',30,RGB(255,236,120));message.RichText=true;message.TextScaled=true;message.TextXAlignment=Enum.TextXAlignment.Left;message.ZIndex=3
local titleFit=Instance.new('UITextSizeConstraint');titleFit.MaxTextSize=34;titleFit.MinTextSize=14;titleFit.Parent=message
local hint=frame(card,'Hint',3);hint.BackgroundColor3=RGB(10,14,34);hint.BackgroundTransparency=.3;round(hint)
local keyCap=frame(hint,'Key',4);keyCap.BackgroundColor3=WHITE;keyCap.BackgroundTransparency=0;round(keyCap,UDim.new(0,7))
local keyFill=gradient(keyCap,RGB(255,255,255),RGB(196,204,222));stroke(keyCap,INK,2)
local keyText=text(keyCap,'Label','',17,INK);keyText.Size=UDim2.fromScale(1,1);keyText.TextStrokeTransparency=1;keyText.ZIndex=5
local hintArrow=text(hint,'Arrow','➜',20,RGB(255,72,72));hintArrow.ZIndex=4;hintArrow.TextStrokeTransparency=.2
local hintLabel=text(hint,'Label','',17);hintLabel.RichText=true;hintLabel.TextXAlignment=Enum.TextXAlignment.Left;hintLabel.ZIndex=4
local KEY_STYLES={Track=ColorSequence.new(RGB(255,176,90),RGB(226,137,47)),Base=ColorSequence.new(RGB(127,216,143),RGB(78,168,96))}
-- The step row: one icon per step; done = green ✓, now = gold and bigger.
local dots=frame(card,'Progress',3)
local dotFrames,links={}, {}
for i,icon in ipairs(Guide.Progress)do
 local d=frame(dots,'Dot'..i,4);d.AnchorPoint=Vector2.new(.5,.5);d.BackgroundTransparency=0;round(d)
 local g=text(d,'Glyph',icon,13);g.Size=UDim2.fromScale(1,1);g.TextScaled=true;g.TextStrokeTransparency=1;g.ZIndex=5
 local ring=stroke(d,INK,1.5);ring.Name='Ring'
 dotFrames[i]=d
 if i>1 then local l=frame(dots,'Link'..i,3);l.AnchorPoint=Vector2.new(0,.5);l.BackgroundTransparency=0;links[i]=l end
end
-- Two taps to skip (a stray tap on a phone does not end it); a big target on phones.
local stepPill=frame(card,'StepPill',5);stepPill.AnchorPoint=Vector2.new(1,0);stepPill.BackgroundColor3=WHITE;stepPill.BackgroundTransparency=0;stepPill.Position=UDim2.new(1,-48,0,-12);stepPill.Size=UDim2.fromOffset(72,22);stepPill.Visible=false
round(stepPill);gradient(stepPill,RGB(255,140,140),RGB(214,52,52));stroke(stepPill,INK,2)
local stepText=text(stepPill,'Label','',13);stepText.Size=UDim2.fromScale(1,1);stepText.ZIndex=6
local close=Instance.new('TextButton');close.Name='Skip';close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.new(1,-6,0,6);close.Size=UDim2.fromOffset(30,30);close.BackgroundColor3=RGB(16,20,48);close.BackgroundTransparency=.35
close.Font=FONT;close.Text='X';close.TextSize=16;close.TextColor3=RGB(227,232,240);close.AutoButtonColor=true;close.ZIndex=6;close:SetAttribute('AccessibleLabel','Skip tutorial');close.Parent=card;round(close)

-- The pressing hand: a pulsing ring around the exact button + a 👆 that keeps pressing it. Its own ScreenGui with no insets, above
-- the card, the hotbar (25) and the BASE / TRACK row (24, which sits in Roblox's top bar, outside the safe area the card uses).
local tapGui=Instance.new('ScreenGui');tapGui.Name='BeginnerTutorialTap';tapGui.ResetOnSpawn=false;tapGui.DisplayOrder=26;tapGui.ScreenInsets=Enum.ScreenInsets.None;tapGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;tapGui.Parent=pg
local tap=frame(tapGui,'TapHand',20);tap.Size=UDim2.fromScale(1,1);tap.Visible=false
local tapRing=frame(tap,'Ring',20);round(tapRing,UDim.new(0,12));local tapStroke=stroke(tapRing,RGB(255,232,72),4)
local tapRipple=frame(tap,'Ripple',20);tapRipple.AnchorPoint=Vector2.new(.5,.5);round(tapRipple);local tapRippleStroke=stroke(tapRipple,RGB(255,236,120),3)
local finger=text(tap,'Hand','👆',48);finger.AnchorPoint=Vector2.new(.3,.06);finger.Size=UDim2.fromOffset(52,52);finger.TextScaled=true;finger.TextStrokeTransparency=1;finger.Rotation=-24;finger.ZIndex=21
local fingerScale=Instance.new('UIScale');fingerScale.Name='Press';fingerScale.Parent=finger
-- R138 (owner: "a clicking indicator to visually show players to keep clicking to open a pack"): next to the pack in
-- your hand, a hand / mouse that keeps pressing with a ripple, CLICK! / TAP!, and one pip per click still needed.
local CH={Ripples={},Pips={}}
CH.Hint=frame(gui,'ClickHint',9);CH.Hint.AnchorPoint=Vector2.new(.5,.5);CH.Hint.Size=UDim2.fromOffset(180,190);CH.Hint.Visible=false
CH.Scale=Instance.new('UIScale');CH.Scale.Parent=CH.Hint
for i=1,2 do local r=frame(CH.Hint,'Ripple'..i,9);r.AnchorPoint=Vector2.new(.5,.5);r.Position=UDim2.fromOffset(76,52);round(r);CH.Ripples[i]={Frame=r,Stroke=stroke(r,RGB(255,236,120),3)}end
CH.Hand=text(CH.Hint,'Hand','🖱️',72);CH.Hand.AnchorPoint=Vector2.new(.5,.5);CH.Hand.Position=UDim2.fromOffset(90,66);CH.Hand.Size=UDim2.fromOffset(92,92);CH.Hand.TextScaled=true;CH.Hand.TextStrokeTransparency=1;CH.Hand.ZIndex=10
CH.HandScale=Instance.new('UIScale');CH.HandScale.Parent=CH.Hand
CH.Word=text(CH.Hint,'Word','CLICK!',36,RGB(255,236,120));CH.Word.AnchorPoint=Vector2.new(.5,0);CH.Word.Position=UDim2.fromOffset(90,118);CH.Word.Size=UDim2.fromOffset(180,40);CH.Word.ZIndex=10;CH.Word.TextStrokeTransparency=0
CH.WordScale=Instance.new('UIScale');CH.WordScale.Parent=CH.Word
CH.Row=frame(CH.Hint,'Pips',10);CH.Row.AnchorPoint=Vector2.new(.5,0);CH.Row.Position=UDim2.fromOffset(90,162);CH.Row.Size=UDim2.fromOffset(180,20)
local function pipCount(n)
 local pips=CH.Pips
 for i=#pips+1,n do local d=frame(CH.Row,'Pip'..i,10);d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(18,18);d.BackgroundTransparency=0;round(d);stroke(d,INK,2);pips[i]=d end
 for i,d in ipairs(pips)do set(d,'Visible',i<=n);set(d,'Position',UDim2.fromOffset(90+(i-(n+1)/2)*25,10))end
end
-- Confetti when the tutorial is done.
local confetti=frame(gui,'Confetti',12);confetti.Size=UDim2.fromScale(1,1);confetti.Visible=false
local bits,flight={}, {}
for i=1,32 do local b=frame(confetti,'Bit'..i,12);b.AnchorPoint=Vector2.new(.5,.5);b.BackgroundTransparency=0;bits[i]=b;flight[i]={}end
-- A red arrow made of three bars (the goal marker and the screen-edge pointer).
local function arrow(parent,color)
 local holder=frame(parent,'Arrow');holder.Size=UDim2.fromScale(1,1)
 for _,v in ipairs({{.42,.06,.16,.60,0},{.25,.53,.16,.38,-42},{.59,.53,.16,.38,42}})do
  local p=frame(holder,'Bar',parent.ZIndex);p.Position=UDim2.fromScale(v[1],v[2]);p.Size=UDim2.fromScale(v[3],v[4]);p.Rotation=v[5];p.BackgroundColor3=color or RGB(255,222,86);p.BackgroundTransparency=0;Theme.Corner(p,3)
  stroke(p,RGB(67,45,15),2)
 end
 return holder
end
local edge=frame(gui,'Direction');edge.Size=UDim2.fromOffset(30,40);edge.AnchorPoint=Vector2.new(.5,.5);edge.Visible=false;arrow(edge,RGB(255,72,72))
-- Over the goal: a white bubble with the step icon, a bouncing red arrow under it and the distance above it.
local marker=Instance.new('BillboardGui');marker.Name='Goal';marker.AlwaysOnTop=true;marker.Size=UDim2.fromOffset(120,124);marker.StudsOffsetWorldSpace=Vector3.new(0,5,0);marker.Enabled=false;marker.Parent=gui
local markerDistance=text(marker,'Distance','',15,RGB(255,236,160));markerDistance.Size=UDim2.new(1,0,0,18);markerDistance.TextStrokeTransparency=0
local markerIcon;do local bubble=frame(marker,'Bubble',2);bubble.AnchorPoint=Vector2.new(.5,0);bubble.Position=UDim2.new(.5,0,0,20);bubble.Size=UDim2.fromOffset(58,58);bubble.BackgroundColor3=WHITE;bubble.BackgroundTransparency=0;round(bubble);stroke(bubble,RGB(255,72,72),3)
markerIcon=text(bubble,'Icon','',30);markerIcon.AnchorPoint=Vector2.new(.5,.5);markerIcon.Position=UDim2.fromScale(.5,.52);markerIcon.Size=UDim2.fromScale(.7,.7);markerIcon.TextScaled=true;markerIcon.TextStrokeTransparency=1;markerIcon.TextColor3=INK;markerIcon.ZIndex=3 end
do local markerArrow=frame(marker,'ArrowHolder',2);markerArrow.AnchorPoint=Vector2.new(.5,1);markerArrow.Position=UDim2.fromScale(.5,1);markerArrow.Size=UDim2.fromOffset(34,42);arrow(markerArrow,RGB(255,72,72)) end
-- On the garden dirt: a 👇 that keeps pressing it, with a ripple where it lands.
local spotHand=Instance.new('BillboardGui');spotHand.Name='TapSpot';spotHand.AlwaysOnTop=true;spotHand.Size=UDim2.fromOffset(110,120);spotHand.StudsOffsetWorldSpace=Vector3.new(0,2.6,0);spotHand.Enabled=false;spotHand.Parent=gui
local spotRipple=frame(spotHand,'Ripple',1);spotRipple.AnchorPoint=Vector2.new(.5,.5);spotRipple.Position=UDim2.new(.5,0,1,-14);round(spotRipple);local spotRippleStroke=stroke(spotRipple,RGB(255,236,120),3)
local spotFinger=text(spotHand,'Hand','👇',60);spotFinger.AnchorPoint=Vector2.new(.5,1);spotFinger.Position=UDim2.new(.5,0,1,-14);spotFinger.Size=UDim2.fromOffset(64,64);spotFinger.TextScaled=true;spotFinger.TextStrokeTransparency=1;spotFinger.ZIndex=2

-- State ----------------------------------------------------------------------------------
local dead,busy=false,false;local info:{[string]:any}={};local step=0;local connections={};local metrics
local poll,lookPoll,step5Seconds,finishRetry=0,0,0,0;local fetch,render,place,startConfetti,updateConfetti
local finishedUntil,skipArmedUntil,niceUntil,popAt,wasActive,skipped,packComing=0,0,0,-math.huge,false,false,false
local lastDevice,lastKey,lastStep,shownKey,currentKey=nil,nil,0,nil,nil
local highlightButton,goal,cardBottom,cardH=nil,nil,0,112;local currentText='';local currentLook;local clickSeen,clickPopAt,confettiAt=0,-math.huge,nil

local function blocked()return pg:GetAttribute('SeedMenu')~=nil or pg:GetAttribute('TitleActive')==true or player:GetAttribute('RarePullCinematic')~=nil end
-- On the biome track (same test as the shovel holes): true / false, or nil when the map has not said where the track is.
local function trackState()
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart');if not root then return nil end
 local motion=RS:FindFirstChild('RunnerMotion');local lineZ=motion and motion:GetAttribute('TrackBoundaryZ')
 if type(lineZ)~='number'then return nil end
 local cx,half=tonumber(motion:GetAttribute('TrackCenterX'))or 0,tonumber(motion:GetAttribute('TrackHalfWidth'))or 120
 return root.Position.Z>lineZ and math.abs(root.Position.X-cx)<=half
end
-- The track gate: the middle of the line between the bases and the track, a few studs onto the track.
local function trackGate()
 local motion=RS:FindFirstChild('RunnerMotion');local lineZ=motion and motion:GetAttribute('TrackBoundaryZ')
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 if type(lineZ)~='number'or not root then return nil end
 return Vector3.new(tonumber(motion:GetAttribute('TrackCenterX'))or 0,root.Position.Y,lineZ+8)
end
local function travelButton(name)
 local t=pg:FindFirstChild('TravelButtons');local pair=t and t:FindFirstChild('TravelPair')
 return pair and pair.Visible and pair:FindFirstChild(name)or nil
end
-- Tools: the pack (step 3) and the seed (step 4), and whether it is in your hand.
local function findTool(attribute)
 local character=player.Character
 for _,holder in ipairs({character,player:FindFirstChildOfClass('Backpack')})do
  if holder then for _,t in ipairs(holder:GetChildren())do if t:IsA('Tool')and t:GetAttribute(attribute)then return t,holder==character end end end
 end
 return nil,false
end
local function packTool()return findTool('SeedPackTool')end
local function seedTool()return findTool('GardenSeed')end
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

-- Which look the current step shows ----------------------------------------------------------
-- Returns look, key, title override, chip override. TRACK only while you're off the track in step 1; BASE only while
-- you're on the track when the goal is at your base (steps 4-5): the teleports are taught when they're needed.
local DETOUR={TravelTrack=true,TravelBase=true,PickSeed=true}
local function resolve()
 local spec=Guide.Steps[step];if not spec then return nil end
 if step==1 then
  if trackState()==false then return Guide.TravelTrack,'TravelTrack'end
  if info.WaitingForPack then return Guide.Waiting,'Waiting'end
 elseif step==3 then
  local tool,equipped=packTool()
  if tool and equipped then return spec,'Open',spec.EquippedTitle,spec.EquippedChip end
  return spec,'Pick'
 elseif spec.Home then
  if trackState()==true then return Guide.TravelBase,'TravelBase'end
  if step==4 then local seed,inHand=seedTool();if seed and not inHand then return Guide.PickSeed,'PickSeed'end end
 end
 return spec,'Step'..step
end

-- R153 hotfix (KeyboardTrack died in Studio with "Out of local registers ... exceeded limit 200": Roblox compiles without folding constant
-- locals; this chunk stood at 182 of the 200): the world pieces below live in one do-block, so their parts, constants and helpers go out of scope
-- once built; what the rest of the script uses from them is declared here. tools/tests/check_compile_O0.sh keeps every function under 180.
local folder,buildWorld,dropWorld,hideTrail,hideWorld,updateWorld
do
-- World pieces (this client only, so nobody else sees them; built while the tutorial runs, gone after) ----------------
local anchor,ring,beam,lastTarget,lastSpot,trailFrom,trailTo;local trailParts,chevrons,lastAlpha,parked={}, {}, {}, {}
local moveParts,moveFrames={}, {} -- reused every frame: only the chevrons that move are sent to BulkMoveTo
local TRAIL_COUNT,SPACING,FLOW,REACH,BEAM_HEIGHT=36,3,4.5,2.4,60
local PARKED=CFrame.new(0,-5000,0)
-- Chevron in its own frame: forward is -Z, tip at z=-0.7. Red neon arms sit on slightly larger white rims.
local ARM=1.7;local shape
do local ANGLE,TIP=math.rad(45),-.7;local sa,ca=math.sin(ANGLE),math.cos(ANGLE)
shape={
 CFrame.new(-sa*ARM/2,.03,TIP+ca*ARM/2)*CFrame.Angles(0,-ANGLE,0),CFrame.new(sa*ARM/2,.03,TIP+ca*ARM/2)*CFrame.Angles(0,ANGLE,0),
 CFrame.new(-sa*ARM/2,0,TIP+ca*ARM/2)*CFrame.Angles(0,-ANGLE,0),CFrame.new(sa*ARM/2,0,TIP+ca*ARM/2)*CFrame.Angles(0,ANGLE,0),
}end
local ringAlpha,beamAlpha=1,1
function buildWorld()
 if folder then return end
 local function flat(name,size,color,material)
  local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Locked=true
  p.Size=size;p.Color=color;p.Material=material;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Transparency=1;p.CFrame=PARKED;p.Parent=folder
  trailParts[#trailParts+1]=p;return p
 end
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
 ringAlpha,beamAlpha=1,1;marker.Adornee=anchor;spotHand.Adornee=anchor
 folder.Parent=workspace
end
function dropWorld()
 set(marker,'Enabled',false);set(spotHand,'Enabled',false);set(edge,'Visible',false);marker.Adornee=nil;spotHand.Adornee=nil
 if folder then folder:Destroy()end;folder,anchor,ring,beam,lastTarget,lastSpot=nil,nil,nil,nil,nil,nil;trailParts,chevrons,lastAlpha,parked={}, {}, {}, {}
 table.clear(moveParts);table.clear(moveFrames)
end
local function alphaFor(i,value)
 value=math.clamp(math.floor(value*100+.5)/100,0,1) -- (R153: 1/100, was 1/10: the chevrons faded in and out in ten visible steps)
 if lastAlpha[i]==value then return end;lastAlpha[i]=value
 local c=chevrons[i];c[1].Transparency=value;c[2].Transparency=value;c[3].Transparency=math.max(value,.15);c[4].Transparency=math.max(value,.15)
end
function hideTrail()
 if not folder then return end
 trailFrom=nil;for i=1,TRAIL_COUNT do alphaFor(i,1)end
 if ringAlpha~=1 then ringAlpha=1;ring.Transparency=1 end
 if beamAlpha~=1 then beamAlpha=1;beam.Transparency=1 end
end
local function currentTarget()
 if not goal then return nil end
 if goal=='Gate'then return trackGate()end
 local spec=Guide.Steps[step];if not spec or spec.Target~=info.Kind then return nil end
 local part=info.TargetPart
 if typeof(part)=='Instance'and part.Parent and part:IsA('BasePart')then return part.Position end
 return typeof(info.Target)=='Vector3'and info.Target or nil
end

-- Straight line from the player's feet to the goal, rebuilt every frame, so it never drifts away from the player.
-- It ignores walls on purpose: each arrow is dropped onto whatever floor is under its spot on the line.
local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.RespectCanCollide=true
local function ground(x,z,y,reach)
 reach=reach or 4
 local hit=workspace:Raycast(Vector3.new(x,y+reach,z),Vector3.new(0,-20-reach,0),rayParams)
 if hit then local n=hit.Normal.Y>.6 and hit.Normal or Vector3.yAxis;return hit.Position+n*.06,n end
 return Vector3.new(x,y,z),Vector3.yAxis
end
-- Only chevrons on the line move each frame; one past the goal is parked once and then left alone. With Reduced Motion
-- the chevrons stand still, so nothing moves until you or the goal do.
local function drawTrail(root,target,now)
 local from=root.Position;local feet=from.Y-3
 if calm()and trailFrom and Cache.Same(trailFrom,from)and Cache.Same(trailTo,target)then return end
 trailFrom,trailTo=calm()and from or nil,target
 local flatDelta=Vector3.new(target.X-from.X,0,target.Z-from.Z);local length=flatDelta.Magnitude
 if length<.01 then for i=1,TRAIL_COUNT do alphaFor(i,1)end;return end
 local look=flatDelta/length;local phase=(calm()and 0 or(now*FLOW)%SPACING);local stop=length-REACH
 table.clear(moveParts);table.clear(moveFrames)
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
 if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveFrames,Enum.BulkMoveMode.FireCFrameChanged)end
end
local rayFor,rayFolder
function hideWorld()hideTrail();set(marker,'Enabled',false);set(spotHand,'Enabled',false);set(edge,'Visible',false)end
function updateWorld()
 if not folder then return end
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local target=currentTarget()
 if not root or not target or blocked()or not card.Visible then hideWorld();return end
 if rayFor~=character or rayFolder~=folder then rayFor,rayFolder=character,folder;rayParams.FilterDescendantsInstances={folder,character}end
 local now=os.clock();local still=calm()
 local flat2=Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z).Magnitude
 if flat2<6 then trailFrom=nil;for i=1,TRAIL_COUNT do alphaFor(i,1)end else drawTrail(root,target,now)end
 -- Ring + beam on the floor under the goal (found again only when the goal moves), gently pulsing.
 if not(lastTarget and Cache.Same(lastTarget,target))then
  lastTarget=target;local spot=ground(target.X,target.Z,target.Y,24)
  if not(lastSpot and Cache.Same(lastSpot,spot))then
   lastSpot=spot;local up=CFrame.Angles(0,0,math.rad(90))
   ring.CFrame=CFrame.new(spot+Vector3.new(0,.05,0))*up;beam.CFrame=CFrame.new(spot+Vector3.new(0,BEAM_HEIGHT/2,0))*up;anchor.CFrame=CFrame.new(spot)
  end
 end
 local pulse=still and .45 or math.floor((.45+.1*math.sin(now*5))*100+.5)/100
 if ringAlpha~=pulse then ringAlpha=pulse;ring.Transparency=pulse end
 local glow=still and .62 or math.floor((.62+.08*math.sin(now*3))*100+.5)/100
 if beamAlpha~=glow then beamAlpha=glow;beam.Transparency=glow end
 -- The bubble (or, on the dirt, the pressing hand).
 local pressing=currentLook and currentLook.Hand==true
 set(marker,'Enabled',not pressing);set(spotHand,'Enabled',pressing)
 if pressing then
  local phase=(now%.7)/.7;local dip=(still or phase>.2)and 0 or math.sin(phase/.2*math.pi)
  set(spotFinger,'Position',UDim2.new(.5,0,1,-14+math.floor(dip*8+.5)));local k=still and .5 or math.floor(phase*20)/20
  set(spotRipple,'Size',UDim2.fromOffset(20+k*70,8+k*26));set(spotRippleStroke,'Transparency',still and .3 or k)
 else
  set(marker,'StudsOffsetWorldSpace',Vector3.new(0,5+(still and 0 or math.floor(math.sin(now*4)*10+.5)/20),0))
  set(markerDistance,'Text',flat2>12 and(math.floor(flat2+.5)..' studs')or'')
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
-- The pressing hand on a screen button: the TRACK / BASE button, or the hotbar slot of the pack / seed to pick.
local function updateTap()
 local function tapTarget()
  if not card.Visible or os.clock()<niceUntil then return nil end
  if highlightButton then return travelButton(highlightButton)end
  if currentKey=='Pick'then local tool=packTool();return tool and toolSlot(tool)end
  if currentKey=='PickSeed'then local tool=seedTool();return tool and toolSlot(tool)end
  return nil
 end
 local b=tapTarget()
 if not b then set(tap,'Visible',false);return end
 local origin=tapGui.AbsolutePosition;local at=b.AbsolutePosition-origin;local size=b.AbsoluteSize;local now=os.clock();local still=calm()
 local big=metrics and metrics.Phone and 50 or 56
 set(tapRing,'Position',UDim2.fromOffset(at.X-6,at.Y-6));set(tapRing,'Size',UDim2.fromOffset(size.X+12,size.Y+12))
 set(tapStroke,'Transparency',still and .05 or math.floor((.05+.45*(.5+.5*math.sin(now*6)))*20+.5)/20)
 -- Every .7 s the finger dips onto the button and a ripple rings out where it lands.
 local phase=(now%.7)/.7;local dip=(still or phase>.2)and 0 or math.floor(math.sin(phase/.2*math.pi)*10+.5)/10
 local tipX,tipY=math.floor(at.X+size.X*.68),math.floor(at.Y+size.Y*.62)
 set(finger,'Size',UDim2.fromOffset(big,big));set(finger,'Position',UDim2.fromOffset(tipX-dip*4,tipY-dip*6));set(fingerScale,'Scale',1-.12*dip)
 local k=still and .4 or math.floor(phase*20)/20;set(tapRipple,'Position',UDim2.fromOffset(tipX,tipY));set(tapRipple,'Size',UDim2.fromOffset(12+k*44,12+k*44));set(tapRippleStroke,'Transparency',still and .3 or k)
 set(tap,'Visible',true)
end
-- Card text, layout and animation.
local function textWidth(value,size)
 local ok,bounds=pcall(TextService.GetTextSize,TextService,Guide.Plain(value),size,FONT,Vector2.new(2000,200))
 return ok and bounds.X or #value*size*.55
end
-- The chip sizes itself to its pieces: [key cap] [➜] label.
local function layoutHint()
 local phone=metrics and metrics.Phone;local h=phone and 28 or 32;local size=phone and 17 or 19;local x=6
 set(keyText,'TextSize',size-1);set(hintLabel,'TextSize',size);set(hintArrow,'TextSize',size+3)
 if keyCap.Visible then local w=math.max(h,textWidth(keyText.Text,size-1)+16);set(keyCap,'Position',UDim2.fromOffset(x,3));set(keyCap,'Size',UDim2.fromOffset(w,h-6));x+=w+7 else x+=6 end
 if hintArrow.Visible then set(hintArrow,'Position',UDim2.fromOffset(x,0));set(hintArrow,'Size',UDim2.fromOffset(22,h));x+=26 end
 local lw=textWidth(hintLabel.Text,size)+4;set(hintLabel,'Position',UDim2.fromOffset(x,0));set(hintLabel,'Size',UDim2.fromOffset(lw,h));x+=lw+12
 set(hint,'Size',UDim2.fromOffset(x,h))
end
local dotsFor
local function layoutDots(width)
 local n=#dotFrames;local gap=width/math.max(1,n);local now=math.clamp(step,0,n)
 local finished=currentLook==Guide.Finished;local nice=currentLook==Guide.Nice
 local key=width..'|'..now..'|'..tostring(finished)..'|'..tostring(nice);if key==dotsFor then return end;dotsFor=key
 for i,d in ipairs(dotFrames)do
  local done=i<now or finished;local here=i==now and not finished and not nice
  local size=here and 24 or 18
  d.Size=UDim2.fromOffset(size,size);d.Position=UDim2.fromOffset(gap*(i-.5),9)
  d.BackgroundColor3=done and COL.Done or here and COL.Here or COL.Todo
  d.BackgroundTransparency=(done or here)and 0 or .25;d.Glyph.TextTransparency=(done or here)and 0 or .55
  d.Glyph.Text=done and'✓'or Guide.Progress[i];d.Glyph.TextColor3=WHITE
  if links[i]then local l=links[i];l.Position=UDim2.fromOffset(gap*(i-1.5)+11,9);l.Size=UDim2.fromOffset(math.max(0,gap-22),3);l.BackgroundColor3=done and COL.Done or WHITE;l.BackgroundTransparency=done and 0 or .7 end
 end
end
local function paintDots()if metrics then layoutDots(math.max(100,card.Size.X.Offset-(metrics.Phone and 90 or 102)-14))end end
place=function()
 if not metrics then return end
 local view=Layout.Viewport(gui);local w,h=view.X,view.Y
 local phone=metrics.Phone;cardH=phone and 100 or 112
 local icon=phone and 62 or 74;local x0=14+icon+14;local skip=phone and 40 or 30
 -- The reserved box includes the 12px the name tag sticks out above the card; it is as wide as its words need.
 local function reserved()return cardH+12 end
 layoutHint()
 local want=math.floor(x0+math.max(textWidth(currentText,phone and 28 or 34)*1.12+10,hint.Size.X.Offset,phone and 170 or 190)+skip+20)
 want=math.max(phone and 300 or 360,want)
 -- With a top-bar button ringed, the card starts below the pressing hand if it still gets its full width there (on short
 -- phones it would be squeezed beside your character: then the hand just overlaps its top edge); strict first; small screens
 -- may let the card reach the head, then drop the reservation.
 local b=highlightButton and travelButton(highlightButton);local c
 if b then c=Guide.Card(w,h,metrics,reserved,nil,math.floor(b.AbsolutePosition.Y-gui.AbsolutePosition.Y+b.AbsoluteSize.Y+(phone and 26 or 34)),want)end
 if not(c and c.Clear and c.Width>=math.min(want,w-24))then c=Guide.Card(w,h,metrics,reserved,nil,nil,want)end
 if not c.Clear then c=Guide.Card(w,h,metrics,reserved,1,nil,want)end
 if not c.Clear then c=Guide.Card(w,h,metrics,reserved,2,nil,want)end
 cardBottom=c.Top+c.Height
 card.Position=UDim2.fromOffset(c.X,c.Top+12);card.Size=UDim2.fromOffset(c.Width,c.Height-12)
 local H=c.Height-12
 badge.Size=UDim2.fromOffset(30,30);badge.Position=UDim2.fromOffset(12,-1)
 nameTag.Position=UDim2.fromOffset(4,-12)
 local iconY=math.floor((H-22-icon)/2)+8
 stepIcon.Size=UDim2.fromOffset(icon,icon);stepIcon.Position=UDim2.fromOffset(14,iconY);popRing.Position=UDim2.fromOffset(14+icon/2,iconY+icon/2)
 message.Position=UDim2.fromOffset(x0,12);message.Size=UDim2.new(1,-x0-skip-12,0,phone and 32 or 38);titleFit.MaxTextSize=phone and 28 or 34
 hint.Position=UDim2.fromOffset(x0,phone and 48 or 54);layoutHint()
 close.Size=UDim2.fromOffset(skip,skip);stepPill.Position=UDim2.new(1,-skip-14,0,-12)
 dots.Position=UDim2.fromOffset(x0,H-22);dots.Size=UDim2.new(1,-x0-14,0,18);layoutDots(c.Width-x0-14)
end
local placedFor
local function setText(value)currentText=value;set(message,'Text',value)end
-- One look = {Icon, Title, Chip={Key, KeyStyle, Arrow, Label}} (BeginnerGuide), filled for this device and name.
local function apply(look,titleOverride,chipOverride)
 currentLook=look
 local d,name=device(),player.DisplayName
 set(glyph,'Text',look.Icon or'');set(iconFill,'Color',look==Guide.Nice and COL.Green or COL.Gold)
 local chip=chipOverride or look.Chip
 set(hint,'Visible',chip~=nil)
 set(keyCap,'Visible',chip~=nil and chip.Key~=nil);set(keyText,'Text',chip and chip.Key and Guide.Plain(Guide.Format(chip.Key,d,name))or'')
 local style=chip and KEY_STYLES[chip.KeyStyle or''];set(keyFill,'Color',style or COL.Plain)
 set(keyText,'TextColor3',style and WHITE or INK);set(keyText,'TextStrokeTransparency',style and .4 or 1)
 set(hintArrow,'Visible',chip~=nil and chip.Arrow==true)
 set(hintLabel,'Text',chip and Guide.Format(chip.Label or'',d,name)or'')
 setText(Guide.Format(titleOverride or look.Title or'',d,name))
 -- Re-place the card only when its words change (it hugs them).
 local words=currentText..'|'..keyText.Text..'|'..hintLabel.Text..'|'..tostring(hintArrow.Visible)
 if words~=placedFor then placedFor=words;place()else layoutHint()end
end
local function bounce(scale,from)
 if calm()then scale.Scale=1;return end
 scale.Scale=from;Tween:Create(scale,TweenInfo.new(.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
end

-- R138: the clicking indicator next to the pack in your hand (step 3, until the pack opens).
local function updateClick()
 local function heldBag()
  local character=player.Character;local bag=character and character:FindFirstChild('CarriedSeed')
  if bag and bag:GetAttribute('SeedPackCarry')and not bag:GetAttribute('RevealAt')then return bag end
  return nil
 end
 local bag=currentKey=='Open'and card.Visible and os.clock()>=niceUntil and heldBag()
 if not bag then set(CH.Hint,'Visible',false);clickSeen=0;return end
 local camera=workspace.CurrentCamera;local view=Layout.Viewport(gui)
 local at,onScreen=Vector3.new(view.X/2,view.Y*.6,1),false
 local root=bag.PrimaryPart or bag:FindFirstChildWhichIsA('BasePart',true)
 if camera and root then local p,visible=camera:WorldToViewportPoint(root.Position);if visible then at,onScreen=p,true end end
 local inset=gui.AbsolutePosition
 -- Phones: 72% size, and kept between the card and the hotbar (it never covers the slots).
 local k=metrics and metrics.Phone and .72 or 1;local half=95*k
 local barTop=metrics and(view.Y-metrics.HotbarBottom-metrics.SlotSize-(metrics.HotbarDetails~=false and 44 or 0)-8)or view.Y-120
 local x=math.max(100*k,math.min(at.X-inset.X+(onScreen and 130*k or 0),view.X-100*k))
 local y=math.min(barTop-half,math.max(cardBottom+half-12,at.Y-inset.Y));if barTop-half<cardBottom+half-12 then y=(barTop+cardBottom-12)/2 end
 set(CH.Hint,'Position',UDim2.fromOffset(math.floor(x),math.floor(y)));set(CH.Hint,'Visible',true)
 local d=device();local look=Guide.ClickHint[d]or Guide.ClickHint.Mouse
 set(CH.Hand,'Text',look.Hand);set(CH.Word,'Text',look.Word)
 local need=math.max(1,tonumber(bag:GetAttribute('PackClicksRequired'))or 5);local done=math.clamp(tonumber(bag:GetAttribute('PackClickCount'))or 0,0,need)
 pipCount(need)
 for i=1,need do local p=CH.Pips[i];set(p,'BackgroundColor3',i<=done and COL.Here or COL.Todo);set(p,'BackgroundTransparency',i<=done and 0 or .2)end
 if done>clickSeen then clickSeen=done;clickPopAt=os.clock()end
 local now=os.clock();local still=calm()
 -- A press every .55 s: the hand dips, a ripple rings out from it, the word pulses.
 local phase=(now%.55)/.55
 set(CH.HandScale,'Scale',still and 1 or(phase<.16 and 1-.18*math.sin(phase/.16*math.pi)or 1))
 set(CH.Hand,'Rotation',still and 0 or-12)
 for i,r in ipairs(CH.Ripples)do
  local k=((now/.55)+(i-1)*.5)%1
  set(r.Frame,'Visible',not still)
  if not still then set(r.Frame,'Size',UDim2.fromOffset(20+k*90,20+k*90));set(r.Stroke,'Transparency',k)end
 end
 set(CH.WordScale,'Scale',still and 1 or 1+.08*math.max(0,math.sin(phase*math.pi*2)))
 local age=now-clickPopAt;set(CH.Scale,'Scale',k*((not still and age<.2)and 1+.15*(1-age/.2)or 1))
end
-- R138: confetti over the finish card.
startConfetti=function()
 if calm()then return end
 confettiAt=os.clock();set(confetti,'Visible',true)
 local view=Layout.Viewport(gui);local colors={RGB(255,214,79),RGB(120,232,110),RGB(110,190,255),RGB(255,110,150),RGB(200,140,255)}
 for i,b in ipairs(bits)do
  local f=flight[i];f.X=view.X/2+(math.random()-.5)*80;f.Y=cardBottom-30;f.VX=(math.random()-.5)*620;f.VY=-260-math.random()*360;f.Spin=(math.random()-.5)*900
  b.BackgroundColor3=colors[(i-1)%#colors+1];b.Size=UDim2.fromOffset(6+(i%3)*3,10+(i%2)*6)
 end
end
updateConfetti=function()
 if not confettiAt then return end
 local age=os.clock()-confettiAt
 if age>2.4 then confettiAt=nil;set(confetti,'Visible',false);return end
 local fade=math.clamp((age-1.6)/.8,0,1)
 for i,b in ipairs(bits)do
  local f=flight[i]
  b.Position=UDim2.fromOffset(f.X+f.VX*age,f.Y+f.VY*age+520*age*age);b.Rotation=f.Spin*age;set(b,'BackgroundTransparency',fade)
 end
end
local function updatePop()
 local age=os.clock()-popAt
 if age>.45 or calm()then set(popRing,'Visible',false);return end
 local icon=stepIcon.Size.X.Offset;local k=age/.45
 set(popRing,'Visible',true);popRing.Size=UDim2.fromOffset(icon*(1+.9*k),icon*(1+.9*k));popStroke.Transparency=k
end

render=function()
 local actual=player:GetAttribute('TutorialStep')or 0
 step=actual;if actual==1 and player:GetAttribute('ChestChaseSeedCarrying')then step=2 end
 if actual>0 then wasActive=true end
 if actual==5 then packComing=player:GetAttribute('StarterPackClaimed')~=true end
 local now=os.clock();local active=Guide.Steps[step]~=nil
 local finishing=not active and now<finishedUntil
 if active then buildWorld()elseif folder then hideTrail();dropWorld()end
 local look,key,title,chip
 if active then look,key,title,chip=resolve()end
 -- The pop: a step forward, or getting where a TRACK / BASE / pick-your-seed look sent you. While a pack's reveal plays
 -- (step 3 -> 4) it waits a little longer.
 if active and lastKey and key~=lastKey and(step>lastStep or(step==lastStep and DETOUR[lastKey]and not DETOUR[key]))then
  niceUntil=now+(lastStep==3 and step==4 and Guide.RevealSeconds or Guide.NiceSeconds);popAt=now;sound('Bubble06')
  task.delay(niceUntil-now+.02,function()if not dead then render()end end)
 end
 if step~=lastStep then step5Seconds=0;finishRetry=0 end
 if active then lastKey=key;lastStep=step else lastKey=nil;lastStep=0;niceUntil=0 end
 local nice=active and now<niceUntil
 currentKey=active and not nice and key or nil
 -- Nothing to show: the whole ScreenGui is off (no layout, no drawing). Back on: re-read the screen first.
 local on=active or finishing
 if on and not gui.Enabled then set(gui,'Enabled',true);metrics=Layout.Read(Layout.Viewport(gui),Input.TouchEnabled,Layout.Controls(gui));placedFor=nil;dotsFor=nil end
 set(gui,'Enabled',on);set(tapGui,'Enabled',on)
 set(card,'Visible',on and not blocked()and pg:GetAttribute('GardenMenuExpanded')~=true)
 set(stepPill,'Visible',now<skipArmedUntil)
 local wasButton=highlightButton;highlightButton=nil;goal=nil
 if finishing then apply(Guide.Finished,nil,not packComing and Guide.FinishedAgain or nil)
 elseif nice then apply(Guide.Nice)
 elseif active then
  apply(look,title,chip);highlightButton=look.Button
  if key=='TravelTrack'then goal='Gate'elseif look==Guide.Steps[step]and look.Target then goal='Server'end
  set(markerIcon,'Text',look.Marker or look.Icon or'')
 end
 if highlightButton~=wasButton then place()end
 paintDots()
 local showing=finishing and'Finished'or nice and'Nice'or key
 if card.Visible and showing~=shownKey then
  if shownKey==nil and active then sound('Bubble04')end
  bounce(iconScale,.6);bounce(pop,.86)
 end
 shownKey=card.Visible and showing or shownKey
 if not active and not finishing then shownKey=nil end
 local bottom=card.Visible and cardBottom or nil
 if pg:GetAttribute('TutorialCardBottom')~=bottom then pg:SetAttribute('TutorialCardBottom',bottom)end
end
fetch=function(command)
 if busy or dead then return end;busy=true
 local expected=player:GetAttribute('TutorialStep');local carrying=player:GetAttribute('ChestChaseSeedCarrying')
 task.spawn(function()
  local ok,result=pcall(request.InvokeServer,request,'Tutorial',command or'State');busy=false;if dead then return end
  if ok and result and result.Success then
   if command or(expected==player:GetAttribute('TutorialStep')and carrying==player:GetAttribute('ChestChaseSeedCarrying'))then info=result else info={}end
   render()
  elseif player:GetAttribute('TutorialStep')==nil then task.delay(1,function()if not dead then fetch()end end)end
 end)
end

close.Activated:Connect(function()
 if os.clock()<skipArmedUntil then skipArmedUntil=0;finishedUntil=0;skipped=true;fetch('Skip');return end
 skipArmedUntil=os.clock()+3;stepText.Text='SKIP?';set(stepPill,'Visible',true)
 task.delay(3.05,function()if not dead and os.clock()>=skipArmedUntil then render()end end)
end)

local live=false -- pointers may be showing
local function hideAll()hideWorld();set(tap,'Visible',false);set(CH.Hint,'Visible',false);clickSeen=0;set(popRing,'Visible',false)end
connections[#connections+1]=Run.RenderStepped:Connect(function()
 if dead then return end
 updateConfetti()
 -- Card hidden (finished, a menu open, the title screen, a rare pull): hide every pointer once, then nothing per frame.
 if not card.Visible then if live then live=false;hideAll()end;return end
 live=true
 local now=os.clock()
 if not calm()then set(badge,'Rotation',math.floor(math.sin(now*2.4)*40+.5)/10)end
 set(rim,'Transparency',calm()and .15 or math.floor((.15+.15*math.sin(now*3))*100+.5)/100)
 if now<niceUntil then hideWorld()else updateWorld()end
 updateTap();updateClick();updatePop()
end)
connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
 if dead or step==0 then return end
 poll+=dt;if poll>=1 then poll=0;fetch()end
 -- Re-render as soon as what you do changes the look (on / off the track, the pack or seed in your hand).
 lookPoll+=dt
 if lookPoll>=.15 then lookPoll=0;local _,key=resolve();if key~=lastKey then render()end end
 -- Step 5: hop on your treadmill (or 40 s pass, or your base has none) and the tutorial is done.
 if step==5 then
  if card.Visible and os.clock()>=niceUntil then step5Seconds+=dt end
  local noTreadmill=info.Kind=='Treadmill'and info.Target==nil and info.TargetPart==nil
  if(player:GetAttribute('TreadmillTraining')==true or step5Seconds>=(Guide.Steps[5].Seconds or 40)or noTreadmill)and os.clock()>=finishRetry then
   finishRetry=os.clock()+1.5;fetch('TreadmillInfo')
  end
 end
end)
for _,name in ipairs({'TutorialStep','ChestChaseSeedCarrying'})do connections[#connections+1]=player:GetAttributeChangedSignal(name):Connect(function()info={};render();task.delay(.25,function()fetch()end)end)end
connections[#connections+1]=player:GetAttributeChangedSignal('TutorialDone'):Connect(function()
 if player:GetAttribute('TutorialDone')==true and wasActive and not skipped then finishedUntil=os.clock()+Guide.FinishSeconds;sound('GemClaim');startConfetti();task.delay(Guide.FinishSeconds+.1,function()if not dead then render()end end)end
 wasActive=false;skipped=false;render()
end)
connections[#connections+1]=player:GetAttributeChangedSignal('RarePullCinematic'):Connect(render)
for _,name in ipairs({'SeedMenu','TitleActive','GardenMenuExpanded'})do connections[#connections+1]=pg:GetAttributeChangedSignal(name):Connect(render)end
connections[#connections+1]=Input.LastInputTypeChanged:Connect(function()local now=device();if now~=lastDevice then lastDevice=now;if step>0 then placedFor=nil;render()end end end)
local unwatch=Layout.Watch(gui,function(m)local was=metrics and metrics.Phone;metrics=m;if was~=m.Phone then placedFor=nil;render()end;place();paintDots();if card.Visible then pg:SetAttribute('TutorialCardBottom',cardBottom)end end)
local function cleanup()if dead then return end;dead=true;unwatch();dropWorld();pg:SetAttribute('TutorialCardBottom',nil);for _,c in ipairs(connections)do c:Disconnect()end;tapGui:Destroy()end
gui.Destroying:Connect(cleanup);script.Destroying:Connect(function()cleanup();gui:Destroy()end)
-- The guide is the game owner's avatar (or BeginnerGuide.GuideUserId); in Studio it is you. Falls back to the sprout.
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
 if not id or dead then return end
 local ok,image=pcall(Players.GetUserThumbnailAsync,Players,id,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
 if ok and type(image)=='string'and image~=''and not dead then avatar.Image=image;avatar.Visible=true;face.Visible=false end
 if type(Guide.GuideName)=='string'and Guide.GuideName~=''then tagText.Text=string.upper(Guide.GuideName);return end
 local okName,name=pcall(Players.GetNameFromUserIdAsync,Players,id)
 if okName and type(name)=='string'and name~=''and not dead then tagText.Text=string.upper(name)end
end)
paintDots();render();fetch()
