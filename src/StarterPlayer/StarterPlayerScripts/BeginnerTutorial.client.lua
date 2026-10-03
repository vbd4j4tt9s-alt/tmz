-- R111: the game owner's avatar guides new players through five short steps: a welcome pop-up on the first join,
-- an objective card at the top centre, a straight red arrow line from your feet to every goal (built on this client
-- only, so only you see it), a bouncing marker over the goal, a pointer at the pack in the hotbar, then quick tips.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService');local Tween=game:GetService('TweenService');local TextService=game:GetService('TextService')
local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local Guide=require(RS.BeginnerGuide);local Theme=require(RS.GardenTheme);local Layout=require(RS.HudLayout)
local Names=require(RS:WaitForChild('GardenDisplayNames'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
local okAudio,Audio=pcall(require,RS:WaitForChild('InteractionAudio'))
local RGB=Color3.fromRGB;local FONT=Enum.Font.FredokaOne;local INK=RGB(8,13,24)
local function sound(key)if okAudio and Audio then pcall(Audio.Play,key)end end
local function round(item,radius)local c=Instance.new('UICorner');c.CornerRadius=radius or UDim.new(1,0);c.Parent=item;return c end
local function gradient(item,a,b,rotation)local g=Instance.new('UIGradient');g.Color=ColorSequence.new(a,b);g.Rotation=rotation or 90;g.Parent=item;return g end
local function stroke(item,color,thickness)local s=Instance.new('UIStroke');s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color;s.Thickness=thickness;s.Parent=item;return s end
local function text(parent,name,value,size,color)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Font=FONT;t.Text=value;t.TextSize=size;t.TextColor3=color or Color3.new(1,1,1)
 t.TextStrokeColor3=INK;t.TextStrokeTransparency=.15;t.Parent=parent;return t
end
local function device()
 local last=Input:GetLastInputType()
 if string.find(last.Name,'Gamepad',1,true)then return'Gamepad'end
 if last==Enum.UserInputType.Touch or(Input.TouchEnabled and not Input.MouseEnabled)then return'Touch'end
 return'Mouse'
end

-- Screen pieces ---------------------------------------------------------------------------
-- R138 (owner: "make the tutorial clearly visual, oversimplified"): the card is a big step icon, two or three words and
-- one key chip ([E] HOLD, [CLICK] YOUR PACK, ➜ FOLLOW THE ARROWS), with a row of step icons (🎒 ➜ 🏠 ➜ 🎁 ➜ 🌱 ➜ 💰).
local gui=Instance.new('ScreenGui');gui.Name='BeginnerTutorial';gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local card=Instance.new('Frame');card.Name='GuideCard';card.AnchorPoint=Vector2.new(.5,0);card.BackgroundColor3=Color3.new(1,1,1);card.BorderSizePixel=0;card.Visible=false;card.Parent=gui
round(card,UDim.new(0,18));gradient(card,RGB(74,88,165),RGB(27,32,70));local rim=stroke(card,RGB(255,214,79),3);local pop=Instance.new('UIScale');pop.Parent=card
local shine=Instance.new('Frame');shine.Name='Shine';shine.BackgroundColor3=Color3.new(1,1,1);shine.BackgroundTransparency=.8;shine.BorderSizePixel=0;shine.Position=UDim2.fromOffset(16,5);shine.Size=UDim2.new(1,-32,0,3);shine.Parent=card;round(shine)
local badge=Instance.new('Frame');badge.Name='Guide';badge.AnchorPoint=Vector2.new(.5,.5);badge.BackgroundColor3=Color3.new(1,1,1);badge.ZIndex=6;badge.Parent=card
round(badge);gradient(badge,RGB(190,255,120),RGB(58,190,72));stroke(badge,Color3.new(1,1,1),2)
local face=text(badge,'Face','🌱',30);face.Size=UDim2.fromScale(1,1);face.TextScaled=true;face.TextStrokeTransparency=1;face.ZIndex=7
local avatar=Instance.new('ImageLabel');avatar.Name='Avatar';avatar.BackgroundTransparency=1;avatar.Size=UDim2.fromScale(1,1);avatar.Visible=false;avatar.ZIndex=7;avatar.Parent=badge;round(avatar)
local nameTag=Instance.new('Frame');nameTag.Name='NameTag';nameTag.BackgroundColor3=Color3.new(1,1,1);nameTag.Size=UDim2.fromOffset(0,22);nameTag.AutomaticSize=Enum.AutomaticSize.X;nameTag.ZIndex=5;nameTag.Parent=card
local tagPad=Instance.new('UIPadding');tagPad.PaddingLeft=UDim.new(0,22);tagPad.PaddingRight=UDim.new(0,10);tagPad.Parent=nameTag
round(nameTag);gradient(nameTag,RGB(190,255,120),RGB(58,190,72));stroke(nameTag,INK,2)
local tagText=text(nameTag,'Label',type(Guide.GuideName)=='string'and Guide.GuideName~=''and string.upper(Guide.GuideName)or'GUIDE',14);tagText.Size=UDim2.fromScale(0,1);tagText.AutomaticSize=Enum.AutomaticSize.X;tagText.ZIndex=6
-- The big step icon.
local stepIcon=Instance.new('Frame');stepIcon.Name='StepIcon';stepIcon.BackgroundColor3=Color3.new(1,1,1);stepIcon.BorderSizePixel=0;stepIcon.ZIndex=3;stepIcon.Parent=card
round(stepIcon);local iconFill=gradient(stepIcon,RGB(255,236,120),RGB(255,170,40));stroke(stepIcon,Color3.new(1,1,1),3)
local iconScale=Instance.new('UIScale');iconScale.Parent=stepIcon
local glyph=text(stepIcon,'Glyph','',40);glyph.AnchorPoint=Vector2.new(.5,.5);glyph.Position=UDim2.fromScale(.5,.52);glyph.Size=UDim2.fromScale(.78,.78);glyph.TextScaled=true;glyph.TextStrokeTransparency=1;glyph.ZIndex=4
-- Two or three words.
local message=text(card,'Instruction','',30,RGB(255,236,120));message.RichText=true;message.TextScaled=true;message.TextXAlignment=Enum.TextXAlignment.Left;message.ZIndex=3
local titleFit=Instance.new('UITextSizeConstraint');titleFit.MaxTextSize=32;titleFit.MinTextSize=14;titleFit.Parent=message
-- One chip: a key cap and/or a red arrow, then a word or two.
local hint=Instance.new('Frame');hint.Name='Hint';hint.BackgroundColor3=RGB(10,14,34);hint.BackgroundTransparency=.3;hint.BorderSizePixel=0;hint.ZIndex=3;hint.Parent=card;round(hint)
local keyCap=Instance.new('Frame');keyCap.Name='Key';keyCap.BackgroundColor3=Color3.new(1,1,1);keyCap.BorderSizePixel=0;keyCap.ZIndex=4;keyCap.Parent=hint;round(keyCap,UDim.new(0,7))
gradient(keyCap,RGB(255,255,255),RGB(196,204,222));stroke(keyCap,INK,2)
local keyText=text(keyCap,'Label','',17,INK);keyText.Size=UDim2.fromScale(1,1);keyText.TextStrokeTransparency=1;keyText.ZIndex=5
local hintArrow=text(hint,'Arrow','➜',20,RGB(255,72,72));hintArrow.ZIndex=4;hintArrow.TextStrokeTransparency=.2
local hintLabel=text(hint,'Label','',17);hintLabel.RichText=true;hintLabel.TextXAlignment=Enum.TextXAlignment.Left;hintLabel.ZIndex=4
-- The step row: one icon per step; done = green, now = gold and bigger.
local dots=Instance.new('Frame');dots.Name='Progress';dots.BackgroundTransparency=1;dots.ZIndex=3;dots.Parent=card
local dotFrames,links={}, {}
for i,icon in ipairs(Guide.Progress)do
 local d=Instance.new('Frame');d.Name='Dot'..i;d.AnchorPoint=Vector2.new(.5,.5);d.BorderSizePixel=0;d.ZIndex=4;d.Parent=dots;round(d)
 local g=text(d,'Glyph',icon,13);g.Size=UDim2.fromScale(1,1);g.TextScaled=true;g.TextStrokeTransparency=1;g.ZIndex=5
 local ring=stroke(d,INK,1.5);ring.Name='Ring'
 dotFrames[i]=d
 if i>1 then local l=Instance.new('Frame');l.Name='Link'..i;l.AnchorPoint=Vector2.new(0,.5);l.BorderSizePixel=0;l.ZIndex=3;l.Parent=dots;links[i]=l end
end
local stepPill=Instance.new('Frame');stepPill.Name='StepPill';stepPill.AnchorPoint=Vector2.new(1,0);stepPill.BackgroundColor3=Color3.new(1,1,1);stepPill.Position=UDim2.new(1,-44,0,-12);stepPill.Size=UDim2.fromOffset(72,22);stepPill.ZIndex=5;stepPill.Visible=false;stepPill.Parent=card
round(stepPill);local pillFill=gradient(stepPill,RGB(255,140,140),RGB(214,52,52));stroke(stepPill,INK,2)
local stepText=text(stepPill,'Label','',13);stepText.Size=UDim2.fromScale(1,1);stepText.ZIndex=6
local close=Instance.new('TextButton');close.Name='Skip';close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.new(1,-8,0,8);close.Size=UDim2.fromOffset(28,28);close.BackgroundColor3=RGB(16,20,48);close.BackgroundTransparency=.35
close.Font=FONT;close.Text='X';close.TextSize=16;close.TextColor3=RGB(227,232,240);close.AutoButtonColor=true;close.ZIndex=6;close:SetAttribute('AccessibleLabel','Skip tutorial');close.Parent=card;round(close)
-- Tips step: NEXT skips to the next slide (they also advance by themselves).
local nextTip=Instance.new('TextButton');nextTip.Name='NextTip';nextTip.AnchorPoint=Vector2.new(1,1);nextTip.Position=UDim2.new(1,-10,1,-8);nextTip.Size=UDim2.fromOffset(64,22);nextTip.BackgroundColor3=Color3.new(1,1,1);nextTip.Text='';nextTip.Visible=false;nextTip.ZIndex=6;nextTip.Parent=card
round(nextTip,UDim.new(0,10));gradient(nextTip,RGB(190,255,120),RGB(46,176,64));stroke(nextTip,INK,2)
local nextText=text(nextTip,'Label','NEXT ➜',13);nextText.Size=UDim2.fromScale(1,1);nextText.ZIndex=7

-- Welcome pop-up for a brand-new (or replaying) player: the whole game in four pictures.
local welcome=Instance.new('Frame');welcome.Name='Welcome';welcome.AnchorPoint=Vector2.new(.5,.5);welcome.Position=UDim2.fromScale(.5,.42);welcome.BackgroundColor3=Color3.new(1,1,1);welcome.Visible=false;welcome.ZIndex=10;welcome.Parent=gui
round(welcome,UDim.new(0,22));gradient(welcome,RGB(82,98,182),RGB(27,32,70));stroke(welcome,RGB(255,214,79),4);local welcomeScale=Instance.new('UIScale');welcomeScale.Parent=welcome
local bigBadge=badge:Clone();bigBadge.Name='Guide';bigBadge.Position=UDim2.new(.5,0,0,0);bigBadge.Size=UDim2.fromOffset(84,84);bigBadge.ZIndex=12;bigBadge.Face.ZIndex=13;bigBadge.Avatar.ZIndex=13;bigBadge.Parent=welcome
local welcomeTitle=text(welcome,'Title',Guide.Welcome.Title,34,RGB(255,224,71));welcomeTitle.AnchorPoint=Vector2.new(.5,0);welcomeTitle.Position=UDim2.new(.5,0,0,48);welcomeTitle.Size=UDim2.new(1,-32,0,40);welcomeTitle.TextScaled=true;welcomeTitle.ZIndex=11
local welcomeText=text(welcome,'Body','',20);welcomeText.RichText=true;welcomeText.AnchorPoint=Vector2.new(.5,0);welcomeText.Position=UDim2.new(.5,0,0,90);welcomeText.Size=UDim2.new(1,-40,0,26);welcomeText.ZIndex=11
local strip=Instance.new('Frame');strip.Name='Strip';strip.BackgroundTransparency=1;strip.AnchorPoint=Vector2.new(.5,0);strip.Position=UDim2.new(.5,0,0,124);strip.ZIndex=11;strip.Parent=welcome
local panels,joins={}, {}
for i,item in ipairs(Guide.Welcome.Strip)do
 local panel=Instance.new('Frame');panel.Name='Panel'..i;panel.BackgroundColor3=RGB(14,20,48);panel.BackgroundTransparency=.35;panel.BorderSizePixel=0;panel.ZIndex=11;panel.Parent=strip;round(panel,UDim.new(0,14))
 local circle=Instance.new('Frame');circle.Name='Icon';circle.AnchorPoint=Vector2.new(.5,0);circle.Position=UDim2.new(.5,0,0,8);circle.BackgroundColor3=Color3.new(1,1,1);circle.BorderSizePixel=0;circle.ZIndex=12;circle.Parent=panel
 round(circle);gradient(circle,RGB(255,236,120),RGB(255,170,40));stroke(circle,Color3.new(1,1,1),2)
 local g=text(circle,'Glyph',item.Icon,30);g.AnchorPoint=Vector2.new(.5,.5);g.Position=UDim2.fromScale(.5,.52);g.Size=UDim2.fromScale(.74,.74);g.TextScaled=true;g.TextStrokeTransparency=1;g.ZIndex=13
 local word=text(panel,'Word',item.Word,16);word.AnchorPoint=Vector2.new(.5,1);word.Position=UDim2.new(.5,0,1,-6);word.Size=UDim2.new(1,-6,0,20);word.TextScaled=true;word.ZIndex=12
 local fit=Instance.new('UITextSizeConstraint');fit.MaxTextSize=17;fit.MinTextSize=10;fit.Parent=word
 local num=text(panel,'Number',tostring(i),13,RGB(255,224,71));num.Position=UDim2.fromOffset(6,4);num.Size=UDim2.fromOffset(16,16);num.ZIndex=12
 panels[i]=panel
 if i<#Guide.Welcome.Strip then local j=text(strip,'Join'..i,'➜',22,RGB(255,72,72));j.AnchorPoint=Vector2.new(.5,.5);j.ZIndex=12;joins[i]=j end
end
local go=Instance.new('TextButton');go.Name='Go';go.AnchorPoint=Vector2.new(.5,1);go.Size=UDim2.fromOffset(220,54);go.BackgroundColor3=Color3.new(1,1,1);go.Text='';go.ZIndex=11;go.Parent=welcome
round(go,UDim.new(0,16));gradient(go,RGB(190,255,120),RGB(46,176,64));stroke(go,INK,3)
local goText=text(go,'Label',Guide.Welcome.Button,26);goText.Size=UDim2.fromScale(1,1);goText.ZIndex=12
local goScale=Instance.new('UIScale');goScale.Parent=go

-- R138 (owner: "a clicking indicator to visually show players to keep clicking to open a pack"): next to the pack in
-- your hand, a hand / mouse that keeps pressing with a ripple, CLICK! / TAP!, and one pip per click still needed.
local clickHint=Instance.new('Frame');clickHint.Name='ClickHint';clickHint.AnchorPoint=Vector2.new(.5,.5);clickHint.Size=UDim2.fromOffset(180,190);clickHint.BackgroundTransparency=1;clickHint.Visible=false;clickHint.ZIndex=9;clickHint.Parent=gui
local clickScale=Instance.new('UIScale');clickScale.Parent=clickHint
local ripples={}
for i=1,2 do local r=Instance.new('Frame');r.Name='Ripple'..i;r.AnchorPoint=Vector2.new(.5,.5);r.Position=UDim2.fromOffset(76,52);r.BackgroundTransparency=1;r.ZIndex=9;r.Parent=clickHint;round(r);ripples[i]={Frame=r,Stroke=stroke(r,RGB(255,236,120),3)}end
local hand=text(clickHint,'Hand','🖱️',72);hand.AnchorPoint=Vector2.new(.5,.5);hand.Position=UDim2.fromOffset(90,66);hand.Size=UDim2.fromOffset(92,92);hand.TextScaled=true;hand.TextStrokeTransparency=1;hand.ZIndex=10
local handScale=Instance.new('UIScale');handScale.Parent=hand
local clickWord=text(clickHint,'Word','CLICK!',36,RGB(255,236,120));clickWord.AnchorPoint=Vector2.new(.5,0);clickWord.Position=UDim2.fromOffset(90,118);clickWord.Size=UDim2.fromOffset(180,40);clickWord.ZIndex=10;clickWord.TextStrokeTransparency=0
local wordScale=Instance.new('UIScale');wordScale.Parent=clickWord
local pipRow=Instance.new('Frame');pipRow.Name='Pips';pipRow.AnchorPoint=Vector2.new(.5,0);pipRow.Position=UDim2.fromOffset(90,162);pipRow.Size=UDim2.fromOffset(180,20);pipRow.BackgroundTransparency=1;pipRow.ZIndex=10;pipRow.Parent=clickHint
local pips={}
local function pipCount(n)
 for i=#pips+1,n do local d=Instance.new('Frame');d.Name='Pip'..i;d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(18,18);d.BorderSizePixel=0;d.ZIndex=10;d.Parent=pipRow;round(d);stroke(d,INK,2);pips[i]=d end
 for i,d in ipairs(pips)do d.Visible=i<=n;d.Position=UDim2.fromOffset(90+(i-(n+1)/2)*25,10)end
end
-- Confetti when the tutorial is done.
local confetti=Instance.new('Frame');confetti.Name='Confetti';confetti.BackgroundTransparency=1;confetti.Size=UDim2.fromScale(1,1);confetti.ZIndex=12;confetti.Visible=false;confetti.Parent=gui
local bits={}
for i=1,32 do local b=Instance.new('Frame');b.Name='Bit'..i;b.AnchorPoint=Vector2.new(.5,.5);b.BorderSizePixel=0;b.ZIndex=12;b.Parent=confetti;bits[i]=b end

-- Bouncing arrow over the hotbar slot that holds the pack.
local function arrow(parent,color)
 local frame=Instance.new('Frame');frame.Name='Arrow';frame.Size=UDim2.fromScale(1,1);frame.BackgroundTransparency=1;frame.Parent=parent
 for _,v in ipairs({{.42,.06,.16,.60,0},{.25,.53,.16,.38,-42},{.59,.53,.16,.38,42}})do
  local p=Instance.new('Frame');p.Position=UDim2.fromScale(v[1],v[2]);p.Size=UDim2.fromScale(v[3],v[4]);p.Rotation=v[5];p.BackgroundColor3=color or RGB(255,222,86);p.BorderSizePixel=0;p.ZIndex=parent.ZIndex;p.Parent=frame;Theme.Corner(p,3)
  stroke(p,RGB(67,45,15),2)
 end
 return frame
end
local pointer=Instance.new('Frame');pointer.Name='HotbarPointer';pointer.AnchorPoint=Vector2.new(.5,1);pointer.Size=UDim2.fromOffset(34,44);pointer.BackgroundTransparency=1;pointer.Visible=false;pointer.ZIndex=8;pointer.Parent=gui;arrow(pointer)
-- R125: TRACK / BASE top-bar buttons are part of the tutorial (owner): a pulsing ring and a bouncing arrow under the
-- button the card talks about (presentation only; saved progress is unchanged).
local travelRing=Instance.new('Frame');travelRing.Name='TravelHighlight';travelRing.BackgroundTransparency=1;travelRing.Visible=false;travelRing.ZIndex=9;travelRing.Parent=gui
round(travelRing,UDim.new(0,12));local travelStroke=stroke(travelRing,RGB(255,232,72),3)
local travelPointer=Instance.new('Frame');travelPointer.Name='TravelPointer';travelPointer.AnchorPoint=Vector2.new(.5,0);travelPointer.Size=UDim2.fromOffset(30,38);travelPointer.BackgroundTransparency=1;travelPointer.Rotation=180;travelPointer.Visible=false;travelPointer.ZIndex=9;travelPointer.Parent=gui;arrow(travelPointer)
-- "NICE!" stamp when a step is done.
local stamp=text(card,'Stamp','NICE! ✔',22,RGB(150,255,100));stamp.AnchorPoint=Vector2.new(1,1);stamp.Position=UDim2.new(1,-14,1,-4);stamp.Size=UDim2.fromOffset(120,28);stamp.Rotation=-8;stamp.ZIndex=8;stamp.Visible=false
local stampScale=Instance.new('UIScale');stampScale.Parent=stamp
local edge=Instance.new('Frame');edge.Name='Direction';edge.Size=UDim2.fromOffset(30,40);edge.AnchorPoint=Vector2.new(.5,.5);edge.BackgroundTransparency=1;edge.Visible=false;edge.Parent=gui;arrow(edge,RGB(255,72,72))

-- World pieces (created by this client only, so nobody else sees them) --------------------
local folder=Instance.new('Folder');folder.Name='TutorialTrail'
local anchor=Instance.new('Part');anchor.Name='TutorialTarget';anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.CastShadow=false;anchor.Transparency=1;anchor.Size=Vector3.new(.1,.1,.1);anchor.Parent=folder
local marker=Instance.new('BillboardGui');marker.Name='Goal';marker.Adornee=anchor;marker.AlwaysOnTop=true;marker.Size=UDim2.fromOffset(130,96);marker.StudsOffsetWorldSpace=Vector3.new(0,4.5,0);marker.Enabled=false;marker.Parent=gui
local markerArrow=Instance.new('Frame');markerArrow.Name='ArrowHolder';markerArrow.AnchorPoint=Vector2.new(.5,1);markerArrow.Position=UDim2.fromScale(.5,1);markerArrow.Size=UDim2.fromOffset(40,52);markerArrow.BackgroundTransparency=1;markerArrow.Parent=marker;arrow(markerArrow,RGB(255,72,72))
local markerText=text(marker,'Label','',22);markerText.Size=UDim2.new(1,0,0,26);markerText.TextStrokeTransparency=0
local markerDistance=text(marker,'Distance','',15,RGB(255,236,160));markerDistance.Position=UDim2.fromOffset(0,24);markerDistance.Size=UDim2.new(1,0,0,18);markerDistance.TextStrokeTransparency=0
local RED,WHITE=RGB(255,48,48),RGB(255,255,255)
local TRAIL_COUNT,SPACING,FLOW,REACH=36,3,4.5,2.4
local trailParts,chevrons,lastAlpha={}, {}, {}
local function flat(name,size,color,material)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Locked=true
 p.Size=size;p.Color=color;p.Material=material;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Transparency=1;p.Parent=folder
 trailParts[#trailParts+1]=p;return p
end
-- Chevron in its own frame: forward is -Z, tip at z=-0.7. Red neon arms sit on slightly larger white rims.
local ANGLE,ARM,TIP=math.rad(45),1.7,-.7
local sa,ca=math.sin(ANGLE),math.cos(ANGLE)
local shape={
 CFrame.new(-sa*ARM/2,.03,TIP+ca*ARM/2)*CFrame.Angles(0,-ANGLE,0),CFrame.new(sa*ARM/2,.03,TIP+ca*ARM/2)*CFrame.Angles(0,ANGLE,0),
 CFrame.new(-sa*ARM/2,0,TIP+ca*ARM/2)*CFrame.Angles(0,-ANGLE,0),CFrame.new(sa*ARM/2,0,TIP+ca*ARM/2)*CFrame.Angles(0,ANGLE,0),
}
for i=1,TRAIL_COUNT do
 chevrons[i]={flat('ArmL',Vector3.new(.7,.06,ARM),RED,Enum.Material.Neon),flat('ArmR',Vector3.new(.7,.06,ARM),RED,Enum.Material.Neon),
  flat('RimL',Vector3.new(1.1,.04,ARM+.4),WHITE,Enum.Material.SmoothPlastic),flat('RimR',Vector3.new(1.1,.04,ARM+.4),WHITE,Enum.Material.SmoothPlastic)}
 lastAlpha[i]=1
end
local movable=table.move(trailParts,1,TRAIL_COUNT*4,1,{})
local ring=flat('GoalSpot',Vector3.new(.1,6,6),RED,Enum.Material.Neon);ring.Shape=Enum.PartType.Cylinder
local ringAlpha=1
local PARKED=CFrame.new(0,-5000,0)
folder.Parent=workspace

-- State ----------------------------------------------------------------------------------
local dead,busy=false,false;local info:{[string]:any}={};local step=0;local shownStep=0;local connections={};local metrics
local poll,introSeconds,revealed,welcomeUntil=0,0,0,0;local fetch,render,place,updateClick,startConfetti,updateConfetti
local welcomed,welcomeOpen,finishedUntil,skipArmedUntil,wasActive,skipped=false,false,0,0,false,false
local lastDevice,lastActual,lastTip
local highlightButton,lastOnTrack,stampUntil=nil,nil,0
local cardBottom,cardH=0,112;local packComing=false;local currentText='';local currentLook;local clickSeen,clickPopAt,confettiAt=0,-math.huge,nil

local function alphaFor(i,value)
 value=math.clamp(math.floor(value*10+.5)/10,0,1)
 if lastAlpha[i]==value then return end;lastAlpha[i]=value
 local c=chevrons[i];c[1].Transparency=value;c[2].Transparency=value;c[3].Transparency=math.max(value,.15);c[4].Transparency=math.max(value,.15)
end
local function hideTrail()
 for i=1,TRAIL_COUNT do alphaFor(i,1)end
 if ringAlpha~=1 then ringAlpha=1;ring.Transparency=1 end
end

local function currentTarget()
 local part=info.TargetPart
 if typeof(part)=='Instance'and part.Parent and part:IsA('BasePart')then return part.Position end
 return typeof(info.Target)=='Vector3'and info.Target or nil
end
local function stepSpec()return Guide.Steps[step]end
local function hasGoal()
 local spec=stepSpec()
 return spec~=nil and spec.Target~=nil and spec.Target==info.Kind and currentTarget()~=nil
end
local function blocked()return pg:GetAttribute('SeedMenu')~=nil or pg:GetAttribute('TitleActive')==true end
-- On the biome track (same test as the shovel holes); unknown geometry counts as on it, so nobody is nagged.
local function onTrack()
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart');if not root then return true end
 local motion=RS:FindFirstChild('RunnerMotion');local lineZ=motion and motion:GetAttribute('TrackBoundaryZ')
 if type(lineZ)~='number'then return true end
 local cx,half=tonumber(motion:GetAttribute('TrackCenterX'))or 0,tonumber(motion:GetAttribute('TrackHalfWidth'))or 120
 return root.Position.Z>lineZ and math.abs(root.Position.X-cx)<=half
end
local function travelButton(name)
 local t=pg:FindFirstChild('TravelButtons');local pair=t and t:FindFirstChild('TravelPair')
 return pair and pair.Visible and pair:FindFirstChild(name)or nil
end
local function updateTravel()
 local b=highlightButton and card.Visible and travelButton(highlightButton)
 if not b then if travelRing.Visible or travelPointer.Visible then travelRing.Visible=false;travelPointer.Visible=false end;return end
 local origin=gui.AbsolutePosition;local at=b.AbsolutePosition-origin;local size=b.AbsoluteSize;local t=os.clock();local calm=GuiService.ReducedMotionEnabled
 travelRing.Position=UDim2.fromOffset(at.X-5,at.Y-5);travelRing.Size=UDim2.fromOffset(size.X+10,size.Y+10);travelRing.Visible=true
 travelStroke.Transparency=calm and .1 or .1+.4*(.5+.5*math.sin(t*6))
 travelPointer.Position=UDim2.fromOffset(at.X+size.X/2,at.Y+size.Y+6+(calm and 0 or math.abs(math.sin(t*5))*6));travelPointer.Visible=true
end

-- Straight line from the player's feet to the goal, rebuilt every frame, so it never drifts away from the player.
-- It ignores walls on purpose: each arrow is dropped onto whatever floor is under its spot on the line.
local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.RespectCanCollide=true
local function ground(x,z,y)
 local hit=workspace:Raycast(Vector3.new(x,y+4,z),Vector3.new(0,-24,0),rayParams)
 if hit then local n=hit.Normal.Y>.6 and hit.Normal or Vector3.yAxis;return hit.Position+n*.06,n end
 return Vector3.new(x,y,z),Vector3.yAxis
end
local cframes=table.create(TRAIL_COUNT*4)
local function drawTrail(root,target)
 rayParams.FilterDescendantsInstances={folder,player.Character}
 local from=root.Position;local feet=from.Y-3
 local flatDelta=Vector3.new(target.X-from.X,0,target.Z-from.Z);local length=flatDelta.Magnitude
 if length<.01 then hideTrail();return end
 local look=flatDelta/length;local now=os.clock();local phase=(now*FLOW)%SPACING;local stop=length-REACH
 for i=1,TRAIL_COUNT do
  local s=.8+phase+(i-1)*SPACING;local base=(i-1)*4
  if s>stop then
   for k=1,4 do cframes[base+k]=PARKED end;alphaFor(i,1)
  else
   local y=feet+(target.Y-feet)*(s/length)
   local p,n=ground(from.X+look.X*s,from.Z+look.Z*s,y)
   local fwd=look-n*look:Dot(n);if fwd.Magnitude<.01 then fwd=look end;fwd=fwd.Unit
   local frame=CFrame.fromMatrix(p,fwd:Cross(n).Unit,n,-fwd)
   for k=1,4 do cframes[base+k]=frame*shape[k]end
   -- Fade in at the feet and out at the goal.
   alphaFor(i,1-math.min(math.clamp((s-.8)/1.5,0,1),math.clamp((stop-s)/3,0,1)))
  end
 end
 workspace:BulkMoveTo(movable,cframes,Enum.BulkMoveMode.FireCFrameChanged)
 -- Goal spot under the target, gently pulsing.
 local spot=ground(target.X,target.Z,target.Y);local pulse=.5+.08*math.sin(now*5)
 ring.CFrame=CFrame.new(spot+Vector3.new(0,.05,0))*CFrame.Angles(0,0,math.rad(90))
 if ringAlpha~=pulse then ringAlpha=pulse;ring.Transparency=pulse end
end
local function updateWorld(dt)
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local target=currentTarget()
 if not root or not target or not hasGoal()or blocked()or step==0 then hideTrail();marker.Enabled=false;edge.Visible=false;return end
 local flat2=Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z).Magnitude
 if flat2<6 then hideTrail()else drawTrail(root,target)end
 anchor.Position=target;marker.Enabled=true
 local bob=math.sin(os.clock()*4)*.5;marker.StudsOffsetWorldSpace=Vector3.new(0,4.5+bob,0)
 markerDistance.Text=flat2>12 and(math.floor(flat2+.5)..' studs')or''
 local camera=workspace.CurrentCamera;if not camera then return end
 local at,onScreen=camera:WorldToViewportPoint(target);local view=Layout.Viewport(gui)
 edge.Visible=not onScreen
 if not onScreen then
  local dx,dy=at.X-view.X/2,at.Y-view.Y/2
  if at.Z<0 then dx=-dx;dy=-dy end
  if math.abs(dx)+math.abs(dy)<1 then dy=1 end
  local scale=math.min((view.X/2-46)/math.max(math.abs(dx),.01),(view.Y/2-90)/math.max(math.abs(dy),.01))
  edge.Position=UDim2.fromOffset(view.X/2+dx*scale,view.Y/2+dy*scale);edge.Rotation=math.deg(math.atan2(dy,dx))-90
 end
end

-- Hotbar pointer: finds the slot showing the pack tool; falls back to the Bag button.
local function packTool()
 local character=player.Character
 for _,holder in ipairs({character,player:FindFirstChildOfClass('Backpack')})do
  if holder then for _,t in ipairs(holder:GetChildren())do if t:IsA('Tool')and t:GetAttribute('SeedPackTool')then return t,holder==character end end end
 end
 return nil,false
end
local function packSlot(tool)
 local hot=pg:FindFirstChild('ChestToolHotbar');local dock=hot and hot:FindFirstChild('Dock');if not dock then return nil end
 local ok,wanted=pcall(Names.Tool,tool,Catalog)
 for i=1,10 do
  local slot=dock:FindFirstChild('Slot'..i);local label=slot and slot:FindFirstChild('ItemName')
  if slot and slot.Visible and label and ok and label.Text==wanted then return slot end
 end
 local bag=dock:FindFirstChild('OpenInventory');return bag and bag.Visible and bag or nil
end
local function updatePointer()
 local show=false
 if step==3 and card.Visible then
  local tool,equipped=packTool()
  if tool and not equipped then
   local slot=packSlot(tool)
   if slot then
    local origin=gui.AbsolutePosition;local at=slot.AbsolutePosition-origin;local size=slot.AbsoluteSize
    pointer.Position=UDim2.fromOffset(at.X+size.X/2,at.Y-6+math.sin(os.clock()*6)*5);show=true
   end
  end
 end
 pointer.Visible=show
end

-- Card text, layout and animation.
local function textWidth(value,size)
 local ok,bounds=pcall(TextService.GetTextSize,TextService,Guide.Plain(value),size,FONT,Vector2.new(2000,200))
 return ok and bounds.X or #value*size*.55
end
local CHIP=17
-- The chip sizes itself to its pieces: [key cap] [➜] label.
local function layoutHint()
 local h=metrics and metrics.Phone and 24 or 28;local x=8
 hint.Size=UDim2.fromOffset(0,h)
 if keyCap.Visible then local w=math.max(h,textWidth(keyText.Text,CHIP)+16);keyCap.Position=UDim2.fromOffset(x,3);keyCap.Size=UDim2.fromOffset(w,h-6);x+=w+7 end
 if hintArrow.Visible then hintArrow.Position=UDim2.fromOffset(x,0);hintArrow.Size=UDim2.fromOffset(20,h);x+=24 end
 local lw=textWidth(hintLabel.Text,CHIP)+4;hintLabel.Position=UDim2.fromOffset(x,0);hintLabel.Size=UDim2.fromOffset(lw,h);x+=lw+10
 hint.Size=UDim2.fromOffset(x,h)
end
local function layoutDots(width)
 local n=#dotFrames;local gap=width/math.max(1,n);local now=math.clamp(step,0,n)
 for i,d in ipairs(dotFrames)do
  local done=i<now or currentLook==Guide.Finished;local here=i==now and currentLook~=Guide.Finished
  local size=here and 24 or 18
  d.Size=UDim2.fromOffset(size,size);d.Position=UDim2.fromOffset(gap*(i-.5),9)
  d.BackgroundColor3=done and RGB(120,232,110)or here and RGB(255,214,79)or RGB(14,20,48)
  d.BackgroundTransparency=(done or here)and 0 or .25;d.Glyph.TextTransparency=(done or here)and 0 or .55
  d.Glyph.Text=done and'✓'or Guide.Progress[i];d.Glyph.TextColor3=Color3.new(1,1,1)
  if links[i]then local l=links[i];l.Position=UDim2.fromOffset(gap*(i-1.5)+11,9);l.Size=UDim2.fromOffset(math.max(0,gap-22),3);l.BackgroundColor3=done and RGB(120,232,110)or RGB(255,255,255);l.BackgroundTransparency=done and 0 or .7 end
 end
end
place=function()
 if not metrics then return end
 local view=Layout.Viewport(gui);local w,h=view.X,view.Y
 local phone=metrics.Phone;cardH=phone and 100 or 112
 -- The reserved box includes the 12px the name tag sticks out above the card.
 local function reserved()return cardH+12 end
 -- Strict first; small screens may let the card reach the head, then drop the reservation.
 local c=Guide.Card(w,h,metrics,reserved)
 if not c.Clear then c=Guide.Card(w,h,metrics,reserved,1)end
 if not c.Clear then c=Guide.Card(w,h,metrics,reserved,2)end
 cardBottom=c.Top+c.Height
 card.Position=UDim2.fromOffset(c.X,c.Top+12);card.Size=UDim2.fromOffset(c.Width,c.Height-12)
 local H=c.Height-12;local icon=phone and 60 or 72;local x0=14+icon+14
 badge.Size=UDim2.fromOffset(30,30);badge.Position=UDim2.fromOffset(12,-1)
 nameTag.Position=UDim2.fromOffset(4,-12)
 stepIcon.Size=UDim2.fromOffset(icon,icon);stepIcon.Position=UDim2.fromOffset(14,math.floor((H-24-icon)/2)+10)
 message.Position=UDim2.fromOffset(x0,14);message.Size=UDim2.new(1,-x0-42,0,phone and 30 or 36);titleFit.MaxTextSize=phone and 26 or 32
 hint.Position=UDim2.fromOffset(x0,phone and 48 or 54);layoutHint()
 nextTip.AnchorPoint=Vector2.new(1,0);nextTip.Position=UDim2.new(1,-12,0,phone and 48 or 54);nextTip.Size=UDim2.fromOffset(74,phone and 24 or 28)
 stamp.AnchorPoint=Vector2.new(.5,.5);stamp.Position=UDim2.fromOffset(14+icon/2,math.floor((H-24-icon)/2)+10+icon-4);stamp.Size=UDim2.fromOffset(icon+30,26)
 dots.Position=UDim2.fromOffset(x0,H-24);dots.Size=UDim2.new(1,-x0-14,0,18);layoutDots(c.Width-x0-14)
 -- Welcome pop-up: top centre, so the player and the arrows under them stay in view.
 local ww=math.min(phone and 440 or 560,w-32);local gapW=24;local pw=math.floor((ww-32-gapW*3)/4);local ph=pw+28
 strip.Size=UDim2.fromOffset(pw*4+gapW*3,ph)
 for i,panel in ipairs(panels)do
  panel.Position=UDim2.fromOffset((i-1)*(pw+gapW),0);panel.Size=UDim2.fromOffset(pw,ph)
  panel.Icon.Size=UDim2.fromOffset(pw-26,pw-26)
  if joins[i]then joins[i].Position=UDim2.fromOffset(i*pw+(i-.5)*gapW,ph/2-8);joins[i].Size=UDim2.fromOffset(gapW,24)end
 end
 welcomeText.TextSize=phone and 18 or 20
 local wh=124+ph+18+54+18;welcome.Size=UDim2.fromOffset(ww,wh);go.Position=UDim2.new(.5,0,1,-16)
 welcome.Position=UDim2.fromOffset(w/2,math.min(50+wh/2,h-wh/2-8))
end
local function setText(value)
 if value==currentText then return end
 currentText=value;message.Text=value;place()
end
-- One look = {Icon, Title, Chip={Key, Arrow, Label}} (BeginnerGuide), filled for this device and name.
local function apply(look,titleOverride,chipOverride)
 currentLook=look
 local d,name=device(),player.DisplayName
 glyph.Text=look.Icon or''
 local chip=chipOverride or look.Chip
 hint.Visible=chip~=nil
 keyCap.Visible=chip~=nil and chip.Key~=nil;keyText.Text=chip and chip.Key and Guide.Plain(Guide.Format(chip.Key,d,name))or''
 hintArrow.Visible=chip~=nil and chip.Arrow==true
 hintLabel.Text=chip and Guide.Format(chip.Label or'',d,name)or''
 setText(Guide.Format(titleOverride or look.Title or'',d,name))
 layoutHint()
end
local function paintDots()if metrics then layoutDots(math.max(100,card.Size.X.Offset-(metrics.Phone and 88 or 100)-14))end end
local function bounce(scale,from)
 if GuiService.ReducedMotionEnabled then scale.Scale=1;return end
 scale.Scale=from;Tween:Create(scale,TweenInfo.new(.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
end
local function showWelcome(on)
 welcomeOpen=on;welcome.Visible=on
 if on then welcomeUntil=os.clock()+14;welcomeText.Text=Guide.Format(Guide.Welcome.Text,device(),player.DisplayName);place();bounce(welcomeScale,.6);sound('Bubble04')end
 render()
end
go.Activated:Connect(function()showWelcome(false)end)
nextTip.Activated:Connect(function()introSeconds=(math.floor(introSeconds/Guide.TipSeconds)+1)*Guide.TipSeconds;render()end)

-- R138: the clicking indicator next to the pack in your hand (tutorial step 3, until the pack opens).
local function heldBag()
 local character=player.Character;local bag=character and character:FindFirstChild('CarriedSeed')
 if bag and bag:GetAttribute('SeedPackCarry')and not bag:GetAttribute('RevealAt')then return bag end
 return nil
end
updateClick=function()
 local bag=step==3 and card.Visible and heldBag()
 local tool,equipped=packTool()
 if not bag or not(tool and equipped)then if clickHint.Visible then clickHint.Visible=false end;clickSeen=0;return end
 local camera=workspace.CurrentCamera;local view=Layout.Viewport(gui)
 local at,onScreen=Vector3.new(view.X/2,view.Y*.6,1),false
 local root=bag.PrimaryPart or bag:FindFirstChildWhichIsA('BasePart',true)
 if camera and root then local p,visible=camera:WorldToViewportPoint(root.Position);if visible then at,onScreen=p,true end end
 local inset=gui.AbsolutePosition
 local x=math.max(100,math.min(at.X-inset.X+(onScreen and 130 or 0),view.X-100));local y=math.max(110,math.min(at.Y-inset.Y,view.Y-120))
 clickHint.Position=UDim2.fromOffset(x,y);clickHint.Visible=true
 local d=device();local look=Guide.ClickHint[d]or Guide.ClickHint.Mouse
 hand.Text=look.Hand;clickWord.Text=look.Word
 local need=math.max(1,tonumber(bag:GetAttribute('PackClicksRequired'))or 5);local done=math.clamp(tonumber(bag:GetAttribute('PackClickCount'))or 0,0,need)
 pipCount(need)
 for i=1,need do local p=pips[i];p.BackgroundColor3=i<=done and RGB(255,214,79)or RGB(14,20,48);p.BackgroundTransparency=i<=done and 0 or .2 end
 if done>clickSeen then clickSeen=done;clickPopAt=os.clock()end
 local now=os.clock();local calm=GuiService.ReducedMotionEnabled
 -- A press every .55 s: the hand dips, a ripple rings out from it, the word pulses.
 local phase=(now%.55)/.55
 handScale.Scale=calm and 1 or(phase<.16 and 1-.18*math.sin(phase/.16*math.pi)or 1)
 hand.Rotation=calm and 0 or-12
 for i,r in ipairs(ripples)do
  local k=((now/.55)+(i-1)*.5)%1
  r.Frame.Visible=not calm
  r.Frame.Size=UDim2.fromOffset(20+k*90,20+k*90);r.Stroke.Transparency=k
 end
 wordScale.Scale=calm and 1 or 1+.08*math.max(0,math.sin(phase*math.pi*2))
 local age=now-clickPopAt;clickScale.Scale=(not calm and age<.2)and 1+.15*(1-age/.2)or 1
end
-- R138: confetti over the finish card.
startConfetti=function()
 if GuiService.ReducedMotionEnabled then return end
 confettiAt=os.clock();confetti.Visible=true
 local view=Layout.Viewport(gui);local colors={RGB(255,214,79),RGB(120,232,110),RGB(110,190,255),RGB(255,110,150),RGB(200,140,255)}
 for i,b in ipairs(bits)do
  b:SetAttribute('X',view.X/2+(math.random()-.5)*80);b:SetAttribute('Y',cardBottom-30)
  b:SetAttribute('VX',(math.random()-.5)*620);b:SetAttribute('VY',-260-math.random()*360);b:SetAttribute('Spin',(math.random()-.5)*900)
  b.BackgroundColor3=colors[(i-1)%#colors+1];b.Size=UDim2.fromOffset(6+(i%3)*3,10+(i%2)*6);b.Visible=true
 end
end
updateConfetti=function()
 if not confettiAt then return end
 local age=os.clock()-confettiAt
 if age>2.4 then confettiAt=nil;confetti.Visible=false;return end
 for _,b in ipairs(bits)do
  local x=b:GetAttribute('X')+b:GetAttribute('VX')*age;local y=b:GetAttribute('Y')+b:GetAttribute('VY')*age+520*age*age
  b.Position=UDim2.fromOffset(x,y);b.Rotation=b:GetAttribute('Spin')*age;b.BackgroundTransparency=math.clamp((age-1.6)/.8,0,1)
 end
end
render=function()
 local actual=player:GetAttribute('TutorialStep')or 0
 step=actual
 if actual==1 and player:GetAttribute('ChestChaseSeedCarrying')then step=2 end
 local spec=Guide.Steps[step]
 if actual>0 then wasActive=true end
 -- Entering step 1 of a fresh or replayed run (mask 0/1) earns a new welcome.
 if actual==1 and lastActual~=1 and(player:GetAttribute('TutorialMask')or 0)<=1 then welcomed=false end
 lastActual=actual
 -- First step of a fresh (or replayed) tutorial: welcome the player once per session.
 if step==1 and not welcomed and not blocked()and(player:GetAttribute('TutorialMask')or 0)<=1 then welcomed=true;showWelcome(true);return end
 if welcomeOpen and(step~=1 or blocked())then welcomeOpen=false;welcome.Visible=false end
 local finishing=spec==nil and os.clock()<finishedUntil
 card.Visible=(spec~=nil or finishing)and not welcomeOpen and not blocked()and pg:GetAttribute('GardenMenuExpanded')~=true
 nextTip.Visible=false;highlightButton=nil
 stepPill.Visible=os.clock()<skipArmedUntil
 if actual==5 then packComing=player:GetAttribute('StarterPackClaimed')~=true end
 if finishing then
  apply(Guide.Finished,nil,not packComing and Guide.FinishedAgain or nil);paintDots()
 elseif spec then
  local look,title,chip=spec,nil,nil
  if spec.Tips then local tip=math.clamp(math.floor(introSeconds/Guide.TipSeconds)+1,1,#Guide.Tips);lastTip=tip;look=Guide.Tips[tip];nextTip.Visible=true;highlightButton=Guide.TipButtons[tip]
  elseif step==1 and not player:GetAttribute('ChestChaseSeedCarrying')and not onTrack()then look=Guide.TravelTrack;highlightButton='TrackButton';lastOnTrack=false
  elseif step==1 and info.WaitingForPack then look=Guide.Waiting
  elseif step==3 then local tool,equipped=packTool();if tool and equipped and spec.EquippedTitle then title=spec.EquippedTitle;chip=spec.EquippedChip end end
  local before=glyph.Text
  apply(look,title,chip);paintDots()
  if glyph.Text~=before and card.Visible then bounce(iconScale,.6)end
  markerText.Text=spec.Marker or''
 end
 pg:SetAttribute('TutorialCardBottom',card.Visible and cardBottom or nil)
 if step~=shownStep then
  if step>0 and card.Visible then bounce(pop,.82);if shownStep>0 then sound('Bubble06')end end
  if step>shownStep and shownStep>0 and card.Visible then stamp.Visible=true;stamp.TextTransparency=0;stamp.TextStrokeTransparency=.15;bounce(stampScale,.4);stampUntil=os.clock()+1.2 end
  shownStep=step
 end
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

-- Two taps to skip, so a stray tap on a phone does not end the tutorial.
close.Activated:Connect(function()
 if os.clock()<skipArmedUntil then skipArmedUntil=0;finishedUntil=0;skipped=true;fetch('Skip');return end
 skipArmedUntil=os.clock()+3;stepText.Text='SKIP?';stepPill.Visible=true
 task.delay(3.05,function()if not dead and os.clock()>=skipArmedUntil then render()end end)
end)

connections[#connections+1]=Run.RenderStepped:Connect(function(dt)
 if dead then return end
 -- Nothing to animate once the tutorial is finished and every piece is hidden.
 if step==0 and not card.Visible and not welcomeOpen then if marker.Enabled or edge.Visible or pointer.Visible or travelRing.Visible or clickHint.Visible or ringAlpha~=1 then hideTrail();marker.Enabled=false;edge.Visible=false;pointer.Visible=false;travelRing.Visible=false;travelPointer.Visible=false;clickHint.Visible=false end;updateConfetti();return end
 if welcomeOpen and(os.clock()>welcomeUntil or player:GetAttribute('ChestChaseSeedCarrying'))then showWelcome(false)end
 badge.Rotation=math.sin(os.clock()*2.4)*4;bigBadge.Rotation=math.sin(os.clock()*2.4)*4
 if welcomeOpen and not GuiService.ReducedMotionEnabled then goScale.Scale=1+.04*math.sin(os.clock()*5)end
 rim.Transparency=.15+.15*math.sin(os.clock()*3)
 updateWorld(dt);updatePointer();updateTravel();updateClick();updateConfetti()
 if stamp.Visible then local left=stampUntil-os.clock();if left<=0 then stamp.Visible=false else local a=left<.4 and 1-left/.4 or 0;stamp.TextTransparency=a;stamp.TextStrokeTransparency=math.max(.15,a)end end
end)
connections[#connections+1]=Run.Heartbeat:Connect(function(dt)
 if dead or step==0 then return end
 local current=Guide.Steps[step]
 if current and current.Informational then
  if card.Visible then introSeconds+=dt end
  if introSeconds>=current.Seconds and not busy then introSeconds=0;poll=0;fetch('TreadmillInfo');return end
  if current.Tips and math.floor(introSeconds/Guide.TipSeconds)+1~=lastTip then render()end
 else introSeconds=0 end
 poll+=dt;if poll>=1 then poll=0;fetch()end
 -- Step 1: re-render when the player reaches (or leaves) the track, so the TRACK hint comes and goes.
 if step==1 then local now=onTrack();if now~=lastOnTrack then lastOnTrack=now;render()end end
end)
for _,name in ipairs({'TutorialStep','ChestChaseSeedCarrying'})do connections[#connections+1]=player:GetAttributeChangedSignal(name):Connect(function()info={};render();task.delay(.25,function()fetch()end)end)end
connections[#connections+1]=player:GetAttributeChangedSignal('TutorialDone'):Connect(function()
 if player:GetAttribute('TutorialDone')==true and wasActive and not skipped then finishedUntil=os.clock()+5;sound('GemClaim');startConfetti();task.delay(5.1,function()if not dead then render()end end)end
 wasActive=false;skipped=false;render()
end)
for _,name in ipairs({'SeedMenu','TitleActive','GardenMenuExpanded'})do connections[#connections+1]=pg:GetAttributeChangedSignal(name):Connect(render)end
connections[#connections+1]=Input.LastInputTypeChanged:Connect(function()local now=device();if now~=lastDevice then lastDevice=now;if step>0 then render()end end end)
local unwatch=Layout.Watch(gui,function(m)local was=metrics and metrics.Phone;metrics=m;if was~=m.Phone then currentText='';render()end;place();paintDots();if card.Visible then pg:SetAttribute('TutorialCardBottom',cardBottom)end end)
local function cleanup()if dead then return end;dead=true;unwatch();folder:Destroy();pg:SetAttribute('TutorialCardBottom',nil);for _,c in ipairs(connections)do c:Disconnect()end end
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
 if ok and type(image)=='string'and image~=''and not dead then
  for _,b in ipairs({badge,bigBadge})do b.Avatar.Image=image;b.Avatar.Visible=true;b.Face.Visible=false end
 end
 if type(Guide.GuideName)=='string'and Guide.GuideName~=''then tagText.Text=string.upper(Guide.GuideName);return end
 local okName,name=pcall(Players.GetNameFromUserIdAsync,Players,id)
 if okName and type(name)=='string'and name~=''and not dead then tagText.Text=string.upper(name)end
end)
paintDots();render();fetch()
