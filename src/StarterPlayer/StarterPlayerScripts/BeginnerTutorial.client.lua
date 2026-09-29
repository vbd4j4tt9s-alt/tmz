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
local gui=Instance.new('ScreenGui');gui.Name='BeginnerTutorial';gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local card=Instance.new('Frame');card.Name='GuideCard';card.AnchorPoint=Vector2.new(.5,0);card.BackgroundColor3=Color3.new(1,1,1);card.BorderSizePixel=0;card.Visible=false;card.Parent=gui
round(card,UDim.new(0,16));gradient(card,RGB(74,88,165),RGB(27,32,70));local rim=stroke(card,RGB(255,214,79),3);local pop=Instance.new('UIScale');pop.Parent=card
local shine=Instance.new('Frame');shine.Name='Shine';shine.BackgroundColor3=Color3.new(1,1,1);shine.BackgroundTransparency=.8;shine.BorderSizePixel=0;shine.Position=UDim2.fromOffset(14,5);shine.Size=UDim2.new(1,-28,0,3);shine.Parent=card;round(shine)
local badge=Instance.new('Frame');badge.Name='Guide';badge.AnchorPoint=Vector2.new(.5,.5);badge.BackgroundColor3=Color3.new(1,1,1);badge.ZIndex=3;badge.Parent=card
round(badge);gradient(badge,RGB(190,255,120),RGB(58,190,72));stroke(badge,Color3.new(1,1,1),3)
local face=text(badge,'Face','🌱',30);face.Size=UDim2.fromScale(1,1);face.TextScaled=true;face.TextStrokeTransparency=1;face.ZIndex=4
local avatar=Instance.new('ImageLabel');avatar.Name='Avatar';avatar.BackgroundTransparency=1;avatar.Size=UDim2.fromScale(1,1);avatar.Visible=false;avatar.ZIndex=4;avatar.Parent=badge;round(avatar)
local nameTag=Instance.new('Frame');nameTag.Name='NameTag';nameTag.BackgroundColor3=Color3.new(1,1,1);nameTag.Size=UDim2.fromOffset(0,24);nameTag.AutomaticSize=Enum.AutomaticSize.X;nameTag.ZIndex=5;nameTag.Parent=card
local tagPad=Instance.new('UIPadding');tagPad.PaddingLeft=UDim.new(0,10);tagPad.PaddingRight=UDim.new(0,10);tagPad.Parent=nameTag
round(nameTag);gradient(nameTag,RGB(190,255,120),RGB(58,190,72));stroke(nameTag,INK,2)
local tagText=text(nameTag,'Label',type(Guide.GuideName)=='string'and Guide.GuideName~=''and string.upper(Guide.GuideName)or'GUIDE',15);tagText.Size=UDim2.fromScale(0,1);tagText.AutomaticSize=Enum.AutomaticSize.X;tagText.ZIndex=6
local stepPill=Instance.new('Frame');stepPill.Name='StepPill';stepPill.AnchorPoint=Vector2.new(1,0);stepPill.BackgroundColor3=Color3.new(1,1,1);stepPill.Position=UDim2.new(1,-44,0,-12);stepPill.Size=UDim2.fromOffset(92,24);stepPill.ZIndex=5;stepPill.Parent=card
round(stepPill);local pillFill=gradient(stepPill,RGB(255,236,120),RGB(255,178,42));stroke(stepPill,INK,2)
local stepText=text(stepPill,'Label','STEP 1/'..Guide.StepCount,14);stepText.Size=UDim2.fromScale(1,1);stepText.ZIndex=6
local close=Instance.new('TextButton');close.Name='Skip';close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.new(1,-8,0,8);close.Size=UDim2.fromOffset(28,28);close.BackgroundColor3=RGB(16,20,48);close.BackgroundTransparency=.35
close.Font=FONT;close.Text='X';close.TextSize=16;close.TextColor3=RGB(227,232,240);close.AutoButtonColor=true;close.ZIndex=6;close:SetAttribute('AccessibleLabel','Skip tutorial');close.Parent=card;round(close)
local message=text(card,'Instruction','',20);message.RichText=true;message.TextWrapped=true;message.TextXAlignment=Enum.TextXAlignment.Left;message.TextYAlignment=Enum.TextYAlignment.Top;message.ZIndex=3
-- Tips step: NEXT skips to the next tip (they also advance by themselves).
local nextTip=Instance.new('TextButton');nextTip.Name='NextTip';nextTip.AnchorPoint=Vector2.new(1,1);nextTip.Position=UDim2.new(1,-10,1,-5);nextTip.Size=UDim2.fromOffset(64,20);nextTip.BackgroundColor3=Color3.new(1,1,1);nextTip.Text='';nextTip.Visible=false;nextTip.ZIndex=6;nextTip.Parent=card
round(nextTip,UDim.new(0,10));gradient(nextTip,RGB(190,255,120),RGB(46,176,64));stroke(nextTip,INK,2)
local nextText=text(nextTip,'Label','NEXT',13);nextText.Size=UDim2.fromScale(1,1);nextText.ZIndex=7
local dots=Instance.new('Frame');dots.Name='Progress';dots.BackgroundTransparency=1;dots.AnchorPoint=Vector2.new(0,1);dots.ZIndex=3;dots.Parent=card
local dotList=Instance.new('UIListLayout');dotList.FillDirection=Enum.FillDirection.Horizontal;dotList.Padding=UDim.new(0,5);dotList.VerticalAlignment=Enum.VerticalAlignment.Center;dotList.Parent=dots
local dotFrames={}
for i=1,Guide.StepCount do local d=Instance.new('Frame');d.Name='Dot'..i;d.Size=UDim2.fromOffset(8,8);d.BorderSizePixel=0;d.LayoutOrder=i;d.ZIndex=3;d.Parent=dots;round(d);dotFrames[i]=d end

-- Welcome pop-up for a brand-new (or replaying) player.
local welcome=Instance.new('Frame');welcome.Name='Welcome';welcome.AnchorPoint=Vector2.new(.5,.5);welcome.Position=UDim2.fromScale(.5,.42);welcome.BackgroundColor3=Color3.new(1,1,1);welcome.Visible=false;welcome.ZIndex=10;welcome.Parent=gui
round(welcome,UDim.new(0,20));gradient(welcome,RGB(82,98,182),RGB(27,32,70));stroke(welcome,RGB(255,214,79),4);local welcomeScale=Instance.new('UIScale');welcomeScale.Parent=welcome
local bigBadge=badge:Clone();bigBadge.Name='Guide';bigBadge.Position=UDim2.new(.5,0,0,0);bigBadge.Size=UDim2.fromOffset(84,84);bigBadge.ZIndex=12;bigBadge.Face.ZIndex=13;bigBadge.Avatar.ZIndex=13;bigBadge.Parent=welcome
local welcomeTitle=text(welcome,'Title',Guide.Welcome.Title,30,RGB(255,224,71));welcomeTitle.AnchorPoint=Vector2.new(.5,0);welcomeTitle.Position=UDim2.new(.5,0,0,50);welcomeTitle.Size=UDim2.new(1,-32,0,36);welcomeTitle.TextScaled=true;welcomeTitle.ZIndex=11
local welcomeText=text(welcome,'Body','',20);welcomeText.RichText=true;welcomeText.TextWrapped=true;welcomeText.AnchorPoint=Vector2.new(.5,0);welcomeText.Position=UDim2.new(.5,0,0,94);welcomeText.ZIndex=11
local go=Instance.new('TextButton');go.Name='Go';go.AnchorPoint=Vector2.new(.5,1);go.Size=UDim2.fromOffset(200,50);go.BackgroundColor3=Color3.new(1,1,1);go.Text='';go.ZIndex=11;go.Parent=welcome
round(go,UDim.new(0,14));gradient(go,RGB(190,255,120),RGB(46,176,64));stroke(go,INK,3)
local goText=text(go,'Label',Guide.Welcome.Button,24);goText.Size=UDim2.fromScale(1,1);goText.ZIndex=12

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
local poll,introSeconds,revealed,welcomeUntil=0,0,0,0;local fetch,render,place
local welcomed,welcomeOpen,finishedUntil,skipArmedUntil,wasActive,skipped=false,false,0,0,false,false
local lastDevice,lastActual,lastTip
local cardFont,cardBadge,cardBottom=20,60,0;local currentText=''

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
local function textHeight(value,size,width)
 local ok,bounds=pcall(TextService.GetTextSize,TextService,value,size,FONT,Vector2.new(math.max(40,width),2000))
 return ok and bounds.Y or size*3
end
local function cardHeight(width)
 local area=cardBadge+24
 return math.max(cardBadge+30,textHeight(Guide.Plain(currentText),cardFont,width-area-40)+48)
end
place=function()
 if not metrics then return end
 local view=Layout.Viewport(gui);local w,h=view.X,view.Y
 cardFont=Guide.Font(metrics,w,h);cardBadge=metrics.Phone and 46 or 60
 -- The reserved box includes the 12px the name tag and step pill stick out above the card.
 local function reserved(width)return cardHeight(width)+12 end
 -- Strict first; small screens may let the card reach the head, then use a smaller font, then drop the reservation.
 local c=Guide.Card(w,h,metrics,reserved)
 if not c.Clear then c=Guide.Card(w,h,metrics,reserved,1)end
 if not c.Clear then cardFont-=2;c=Guide.Card(w,h,metrics,reserved,1)end
 if not c.Clear then c=Guide.Card(w,h,metrics,reserved,2)end
 cardBottom=c.Top+c.Height
 local area=cardBadge+24
 card.Position=UDim2.fromOffset(c.X,c.Top+12);card.Size=UDim2.fromOffset(c.Width,c.Height-12)
 badge.Size=UDim2.fromOffset(cardBadge,cardBadge);badge.Position=UDim2.new(0,12+cardBadge/2,.5,4)
 nameTag.Position=UDim2.fromOffset(12,-12)
 message.TextSize=cardFont;message.Position=UDim2.fromOffset(area,20);message.Size=UDim2.new(1,-area-40,1,-44)
 dots.Position=UDim2.new(0,area,1,-12);dots.Size=UDim2.new(1,-area-40,0,10)
 -- Welcome pop-up: top centre, so the player and the arrows under them stay in view.
 local ww=math.min(metrics.Phone and 420 or 480,w-32);local body=textHeight(Guide.Plain(welcomeText.Text),metrics.Phone and 18 or 20,ww-40)
 welcomeText.TextSize=metrics.Phone and 18 or 20;welcomeText.Size=UDim2.new(1,-40,0,body+4)
 local wh=94+body+18+50+18;welcome.Size=UDim2.fromOffset(ww,wh);go.Position=UDim2.new(.5,0,1,-16)
 welcome.Position=UDim2.fromOffset(w/2,math.min(50+wh/2,h-wh/2-8))
end
local function setText(value)
 if value==currentText then return end
 currentText=value;message.Text=value;revealed=0;message.MaxVisibleGraphemes=0;place()
end
local function paintDots()
 for i,d in ipairs(dotFrames)do
  local done=i<step;local now=i==step
  d.BackgroundColor3=done and RGB(255,214,79)or now and RGB(150,255,100)or Color3.new(1,1,1)
  d.BackgroundTransparency=(done or now)and 0 or .7;d.Size=now and UDim2.fromOffset(12,12)or UDim2.fromOffset(8,8)
 end
end
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
 nextTip.Visible=false
 if finishing then
  stepText.Text='DONE!';setText(Guide.Format(Guide.Finished,device(),player.DisplayName));paintDots()
 elseif spec then
  local value=spec.Text
  if spec.Tips then local tip=math.clamp(math.floor(introSeconds/Guide.TipSeconds)+1,1,#Guide.Tips);lastTip=tip;value=Guide.Tips[tip];nextTip.Visible=true
  elseif step==1 and info.WaitingForPack then value=Guide.Waiting
  elseif step==3 then local tool,equipped=packTool();if tool and equipped and spec.Equipped then value=spec.Equipped end end
  if os.clock()>=skipArmedUntil then stepText.Text=('STEP %d/%d'):format(step,Guide.StepCount)end
  setText(Guide.Format(value,device(),player.DisplayName));paintDots()
  markerText.Text=spec.Marker or''
 end
 pg:SetAttribute('TutorialCardBottom',card.Visible and cardBottom or nil)
 if step~=shownStep then
  if step>0 and card.Visible then bounce(pop,.82);if shownStep>0 then sound('Bubble06')end end
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
 skipArmedUntil=os.clock()+3;stepText.Text='SKIP?';pillFill.Color=ColorSequence.new(RGB(255,140,140),RGB(214,52,52))
 task.delay(3.05,function()if not dead and os.clock()>=skipArmedUntil then pillFill.Color=ColorSequence.new(RGB(255,236,120),RGB(255,178,42));render()end end)
end)

connections[#connections+1]=Run.RenderStepped:Connect(function(dt)
 if dead then return end
 -- Nothing to animate once the tutorial is finished and every piece is hidden.
 if step==0 and not card.Visible and not welcomeOpen then if marker.Enabled or edge.Visible or pointer.Visible or ringAlpha~=1 then hideTrail();marker.Enabled=false;edge.Visible=false;pointer.Visible=false end;return end
 if welcomeOpen and(os.clock()>welcomeUntil or player:GetAttribute('ChestChaseSeedCarrying'))then showWelcome(false)end
 if card.Visible and message.MaxVisibleGraphemes>=0 then
  revealed+=dt*60;local total=utf8.len(Guide.Plain(currentText))or #currentText
  if revealed>=total then message.MaxVisibleGraphemes=-1 else message.MaxVisibleGraphemes=math.floor(revealed)end
 end
 badge.Rotation=math.sin(os.clock()*2.4)*4;bigBadge.Rotation=math.sin(os.clock()*2.4)*4
 rim.Transparency=.15+.15*math.sin(os.clock()*3)
 updateWorld(dt);updatePointer()
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
end)
for _,name in ipairs({'TutorialStep','ChestChaseSeedCarrying'})do connections[#connections+1]=player:GetAttributeChangedSignal(name):Connect(function()info={};render();task.delay(.25,function()fetch()end)end)end
connections[#connections+1]=player:GetAttributeChangedSignal('TutorialDone'):Connect(function()
 if player:GetAttribute('TutorialDone')==true and wasActive and not skipped then finishedUntil=os.clock()+5;sound('GemClaim');task.delay(5.1,function()if not dead then render()end end)end
 wasActive=false;skipped=false;render()
end)
for _,name in ipairs({'SeedMenu','TitleActive','GardenMenuExpanded'})do connections[#connections+1]=pg:GetAttributeChangedSignal(name):Connect(render)end
connections[#connections+1]=Input.LastInputTypeChanged:Connect(function()local now=device();if now~=lastDevice then lastDevice=now;if step>0 then render()end end end)
local unwatch=Layout.Watch(gui,function(m)local was=metrics and metrics.Phone;metrics=m;if was~=m.Phone then currentText='';render()end;place();if card.Visible then pg:SetAttribute('TutorialCardBottom',cardBottom)end end)
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
