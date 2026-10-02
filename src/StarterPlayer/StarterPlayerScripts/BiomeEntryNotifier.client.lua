-- R69: illustrated biome crest and warm lettering; short, forward-only notices.
-- R125 redo (owner: the logos had vanished; "redo and polish"). The logo sits in its own small CanvasGroup medallion
-- (in R124's plain-Frame title the clipped artwork did not draw), faded as one piece through GroupTransparency.
-- Everything else is a plain Frame faded element by element. Layout: medallion | "ENTERING" over the biome name on a
-- soft pill, an accent underline with diamond caps, two twinkles. Motion: drops in and settles, holds, then rises and
-- fades away. ReducedMotion: fade only. HudNotices still finds BiomeEntryUI/BiomeTitle (490 x 110) and its UIScale.
local Players=game:GetService('Players');local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage')
local TextService=game:GetService('TextService');local GuiService=game:GetService('GuiService')
local Styles=require(RS:WaitForChild('BiomeTitleStyle'));local Gate=require(RS:WaitForChild('BiomeEntryGate'))
local player=Players.LocalPlayer;local playerGui=player:WaitForChild('PlayerGui');local map=workspace:WaitForChild('ChestChaseMap')
local old=playerGui:FindFirstChild('BiomeEntryUI');if old then old:Destroy()end
local RGB=Color3.fromRGB;local INK=RGB(14,20,26)
local W,H=490,110
local IN,HOLD,OUT=.25,2.4,.7 -- seconds: fade in, fully shown until HOLD, then fade away over OUT
local gui=Instance.new('ScreenGui');gui.Name='BiomeEntryUI';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder=45;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui
local group=Instance.new('Frame');group.Name='BiomeTitle';group.Size=UDim2.fromOffset(W,H);group.AnchorPoint=Vector2.new(.5,.5)
group.Position=UDim2.fromScale(.5,.18) -- User-approved original position.
group.BackgroundTransparency=1;group.Visible=false;group.Parent=gui
local scale=Instance.new('UIScale');scale.Parent=group
local content=Instance.new('Frame');content.Name='Content';content.Size=UDim2.fromScale(1,1);content.BackgroundTransparency=1;content.Parent=group
local function frame(name,parent,z,color,transparency)
 local f=Instance.new('Frame');f.Name=name;f.BorderSizePixel=0;f.Active=false;f.ZIndex=z or 1
 f.BackgroundColor3=color or Color3.new(1,1,1);f.BackgroundTransparency=transparency or 1;f.Parent=parent;return f
end
local function round(f,r)local c=Instance.new('UICorner');c.CornerRadius=r or UDim.new(1,0);c.Parent=f;return c end
local function stroke(f,color,thickness,transparency)
 local s=Instance.new('UIStroke');s.Color=color;s.Thickness=thickness;s.Transparency=transparency or 0;s.Parent=f;return s
end
-- Soft pill behind the words (fades out to the right).
local pill=frame('SoftRibbon',content,1,RGB(10,18,24),.38);round(pill)
local pillEdge=stroke(pill,Color3.new(1,1,1),1.5,.6)
local pillFade=Instance.new('UIGradient');pillFade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.14,0),NumberSequenceKeypoint.new(.78,0),NumberSequenceKeypoint.new(1,1)});pillFade.Parent=pill
-- Medallion: its own CanvasGroup (88 x 88), faded as one piece.
local medal=Instance.new('CanvasGroup');medal.Name='BiomeBadge';medal.Size=UDim2.fromOffset(88,88);medal.BackgroundTransparency=1;medal.ZIndex=3;medal.Parent=content
local pop=Instance.new('UIScale');pop.Parent=medal
local disc=frame('Disc',medal,1,Color3.new(1,1,1),0);disc.Position=UDim2.fromOffset(5,5);disc.Size=UDim2.fromOffset(78,78);round(disc)
local discShade=Instance.new('UIGradient');discShade.Rotation=90;discShade.Parent=disc
local rim=stroke(disc,INK,3,0);rim.Name='Rim'
local ring=frame('InnerRing',medal,2);ring.Position=UDim2.fromOffset(11,11);ring.Size=UDim2.fromOffset(66,66);round(ring)
local ringLine=stroke(ring,Color3.new(1,1,1),1.5,.45)
local logoHolder=frame('LogoHolder',medal,3);logoHolder.Position=UDim2.fromOffset(14,14);logoHolder.Size=UDim2.fromOffset(60,60)
local shine=frame('Shine',medal,4,Color3.new(1,1,1),.72);shine.Position=UDim2.fromOffset(20,13);shine.Size=UDim2.fromOffset(26,12);shine.Rotation=-28;round(shine)
-- Words.
local caption=Instance.new('TextLabel');caption.Name='Caption';caption.BackgroundTransparency=1;caption.Font=Enum.Font.GothamBold;caption.TextSize=14
caption.Text='ENTERING';caption.TextXAlignment=Enum.TextXAlignment.Left;caption.TextStrokeColor3=INK;caption.TextStrokeTransparency=.4;caption.ZIndex=4;caption.Parent=content
local title=Instance.new('TextLabel');title.Name='BiomeName';title.BackgroundTransparency=1;title.Font=Enum.Font.FredokaOne;title.TextSize=40
title.Text='';title.TextColor3=Color3.new(1,1,1);title.TextStrokeTransparency=1;title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=4;title.Parent=content
local titleEdge=stroke(title,INK,2.5,.05);titleEdge.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
local gradient=Instance.new('UIGradient');gradient.Rotation=90;gradient.Parent=title
local underline=frame('CrestUnderline',content,4,Color3.new(1,1,1),.15)
local taper=Instance.new('UIGradient');taper.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,0),NumberSequenceKeypoint.new(.85,0),NumberSequenceKeypoint.new(1,1)});taper.Parent=underline
local caps={}
for i=1,2 do local d=frame('Cap'..i,content,5,Color3.new(1,1,1),0);d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(7,7);d.Rotation=45;caps[i]=d end
local twinkles={}
for i=1,2 do local d=frame('Twinkle'..i,content,5,Color3.new(1,1,1),1);d.AnchorPoint=Vector2.new(.5,.5);d.Size=UDim2.fromOffset(i==1 and 8 or 5,i==1 and 8 or 5);d.Rotation=45;twinkles[d]=i end
-- Fading: every transparency outside the medallion (and except the twinkles), with its resting value.
local fades,alphaNow={},1
local function faded(x)return x~=medal and not x:IsDescendantOf(medal)and twinkles[x]==nil end
local function addFade(x)
 if not faded(x)then return end
 local function add(prop)local base=x[prop];if type(base)=='number'then fades[#fades+1]={Item=x,Prop=prop,Base=base}end end
 if x:IsA('GuiObject')then add('BackgroundTransparency')end
 if x:IsA('TextLabel')then add('TextTransparency');add('TextStrokeTransparency')
 elseif x:IsA('ImageLabel')then add('ImageTransparency')
 elseif x:IsA('UIStroke')then add('Transparency')end
end
local function setAlpha(alpha)
 alphaNow=alpha
 for _,f in ipairs(fades)do local v=f.Base+(1-f.Base)*alpha;if f.Item[f.Prop]~=v then f.Item[f.Prop]=v end end
 if medal.GroupTransparency~=alpha then medal.GroupTransparency=alpha end
end
local function captureFades()
 setAlpha(0);table.clear(fades) -- back to resting values before re-reading them
 for _,x in ipairs(content:GetDescendants())do addFade(x)end
end
local logos={};local names={[1]='Forest',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[6]='Jungle',[7]='Storm'}
local function decorate(style,stage)
 for _,logo in pairs(logos)do logo.Visible=false end
 discShade.Color=ColorSequence.new(style.Accent:Lerp(Color3.new(1,1,1),.25),style.Color:Lerp(Color3.new(0,0,0),.25))
 ringLine.Color=style.Accent;pillEdge.Color=style.Accent;caption.TextColor3=style.Accent
 underline.BackgroundColor3=style.Accent;for _,d in ipairs(caps)do d.BackgroundColor3=style.Accent end
 for d in pairs(twinkles)do d.BackgroundColor3=style.Accent:Lerp(Color3.new(1,1,1),.5)end
 gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.55,style.Accent),ColorSequenceKeypoint.new(1,style.Color)})
 local kind=names[stage];if not kind then return end
 local logo=logos[stage]
 if not logo then
  local ok,made=pcall(function()return require(RS:WaitForChild('BiomeArtwork')).Attach(logoHolder,kind)end)
  if ok and made then logo=made;logo.Name='BiomeLogo';logo.Size=UDim2.fromScale(1,1);logo.Position=UDim2.fromOffset(0,0);logos[stage]=logo end
 end
 if logo then logo.Visible=true end
end
local function width(text,size,font,limit)
 local ok,v=pcall(function()return TextService:GetTextSize(text,size,font,Vector2.new(limit,200))end)
 return ok and typeof(v)=='Vector2'and v.X or #text*size*.6
end
local function layout(style)
 local nameW=math.min(320,width(style.Name,40,Enum.Font.FredokaOne,320)+6)
 local capW=width('ENTERING',14,Enum.Font.GothamBold,200)+4
 local block=math.max(nameW,capW,120)
 local left=math.floor((W-(88+12+block))/2);local x=left+100
 medal.Position=UDim2.fromOffset(left,11)
 caption.Position=UDim2.fromOffset(x+2,22);caption.Size=UDim2.fromOffset(block,16)
 title.Position=UDim2.fromOffset(x,36);title.Size=UDim2.fromOffset(nameW,48)
 underline.Position=UDim2.fromOffset(x,88);underline.Size=UDim2.fromOffset(block,2)
 caps[1].Position=UDim2.fromOffset(x-2,89);caps[2].Position=UDim2.fromOffset(x+block+2,89)
 pill.Position=UDim2.fromOffset(left+44,24);pill.Size=UDim2.fromOffset(56+block+34,64)
 local list={};for d,i in pairs(twinkles)do list[i]=d end
 list[1].Position=UDim2.fromOffset(x+nameW+4,38);list[2].Position=UDim2.fromOffset(x+nameW+14,52)
end
local gate=Gate.new()
local shownAt,poll=-100,0
local dismissAt,dismissFrom
local function dismiss()
 if group.Visible and not dismissAt then dismissAt=os.clock();dismissFrom=alphaNow end
end
local function show(stage)
 local style=Styles[stage]
 if not style then dismiss();return end
 title.Text=style.Name
 layout(style);decorate(style,stage)
 shownAt=os.clock();dismissAt=nil;dismissFrom=nil
 captureFades();setAlpha(1)
 group.Visible=true
end
local function hideNow()setAlpha(1);group.Visible=false;for d in pairs(twinkles)do d.BackgroundTransparency=1 end end
local spawnConnection=player.CharacterAdded:Connect(function()
 gate:Reset();poll=0;dismissAt=nil;dismissFrom=nil;hideNow()
end)
local renderConnection
renderConnection=Run.RenderStepped:Connect(function(dt)
 if not gui.Parent then spawnConnection:Disconnect();renderConnection:Disconnect();return end
 poll+=dt
 if poll>=.12 then
  local elapsed=poll;poll=0
  local character=player.Character
  local root=character and character:FindFirstChild('HumanoidRootPart')
  local humanoid=character and character:FindFirstChildOfClass('Humanoid')
  if not root or not humanoid or humanoid.Health<=0 then
   gate:Reset();dismiss()
  else
   local position=root.Position;local stage,startZ=0,nil
   if math.abs(position.X)<=90 and position.Y>=-10 and position.Y<=150 then
    for id in pairs(Styles)do
     local a,b=map:GetAttribute('BiomeStartZ_'..id),map:GetAttribute('BiomeEndZ_'..id)
     if a and b and position.Z>=a and position.Z<b then stage,startZ=id,a;break end
    end
   end
   local announce,hide=gate:Step(position,stage,startZ,humanoid.MoveDirection.Z,elapsed,humanoid.WalkSpeed)
   if announce then show(stage)elseif hide then dismiss()end
  end
 end
 if not group.Visible then return end
 local now=os.clock();local age=now-shownAt
 -- Fade in, hold, fade away; turning back also fades without restarting the clock.
 local alpha,leaving
 if dismissAt then
  local p=math.clamp((now-dismissAt)/.45,0,1);local eased=p*p*(3-2*p);alpha=dismissFrom+(1-dismissFrom)*eased;leaving=p
 elseif age<IN then alpha=1-age/IN;leaving=0
 else local p=math.clamp((age-HOLD)/OUT,0,1);alpha=p*p*(3-2*p);leaving=p end
 if alpha~=alphaNow then setAlpha(alpha)end
 if age>=HOLD+OUT or(dismissAt and now-dismissAt>=.45)then hideNow();return end
 local camera=workspace.CurrentCamera
 local fit=group:GetAttribute('NoticeFit')or(camera and math.clamp((camera.ViewportSize.X-24)/W,.55,1)or 1)
 scale.Scale=fit
 local reduced=GuiService.ReducedMotionEnabled
 if reduced then
  content.Position=UDim2.fromOffset(0,0);pop.Scale=1
 else
  -- Drop in from 10 px above and settle; rise 8 px while fading away. The medallion pops with a small overshoot.
  local enter=math.min(age/.35,1);local settle=1-(1-enter)^3
  content.Position=UDim2.fromOffset(0,math.floor(-10*(1-settle)-8*leaving+.5))
  pop.Scale=.7+.3*settle+.08*math.sin(enter*math.pi)
 end
 for d,i in pairs(twinkles)do
  local k=reduced and .5 or(.5+.5*math.sin(age*5+i*2.1))
  d.BackgroundTransparency=math.max(alpha,1-.85*k)
 end
end)
gui.Destroying:Connect(function()spawnConnection:Disconnect();renderConnection:Disconnect()end)
