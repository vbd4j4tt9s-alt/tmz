do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R153 (owner picked B, "text only", from the previews): no box, no medallion, no logo. A small white "entering" over the biome's Title Case name in its own colour, both with a solid
-- dark UIStroke and an offset dark copy underneath as the soft shadow (Roblox cannot blur), so they read on any sky. 2.4 s: fade in 0.3 s with a 6 px settle, fully shown until
-- 1.8 s, fade out over 0.6 s; nothing else moves. ReducedMotion: fade only. The gate, the polling, the spawn reset and the BiomeEntryUI / BiomeTitle names are as before:
-- HudNotices finds the group by name and puts it in its 'Biome' row (HudNoticeLayout: 46 px high, 40 on landscape phones).
local Players=game:GetService('Players');local Run=game:GetService('RunService');local RS=game:GetService('ReplicatedStorage')
local TextService=game:GetService('TextService');local GuiService=game:GetService('GuiService')
local Styles=require(RS:WaitForChild('BiomeTitleStyle'));local Gate=require(RS:WaitForChild('BiomeEntryGate'));local Notice=require(RS:WaitForChild('HudNoticeLayout'))
local player=Players.LocalPlayer;local playerGui=player:WaitForChild('PlayerGui');local map=workspace:WaitForChild('ChestChaseMap')
local old=playerGui:FindFirstChild('BiomeEntryUI');if old then old:Destroy()end
local RGB=Color3.fromRGB;local INK=RGB(14,20,26);local SHADE=RGB(6,9,14)
local IN,HOLD,OUT=.3,1.8,.6 -- seconds: fade in, fully shown until HOLD, then fade out over OUT (2.4 s on screen)
local SETTLE,DROP,DISMISS=6,2,.45 -- px the words settle down while fading in; px the shadow copy sits below them; seconds to fade when you turn back or die (a respawn hides it at once)
-- Per screen (class from the safe area, like HudNoticeLayout's): text sizes and UIStroke px. "Storm Peaks" is then about 143 x 44 (pc), 125 x 39 (portrait), 113 x 37 (landscape phone).
local SIZES={pc={Name=24,Cap=12,Edge=2,CapEdge=1.5},port={Name=21,Cap=11,Edge=1.75,CapEdge=1.25},land={Name=19,Cap=11,Edge=1.5,CapEdge=1.25}}
local gui=Instance.new('ScreenGui');gui.Name='BiomeEntryUI';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder=45;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui
local group=Instance.new('Frame');group.Name='BiomeTitle';group.AnchorPoint=Vector2.new(.5,0);group.Size=UDim2.fromOffset(140,44) -- HudNotices sets the position
group.BackgroundTransparency=1;group.Visible=false;group.Parent=gui
local content=Instance.new('Frame');content.Name='Content';content.Size=UDim2.fromScale(1,1);content.BackgroundTransparency=1;content.Parent=group
-- Four labels (a dark shadow copy under each of the two lines), each with its own solid UIStroke. Every transparency fades from its resting value (list below).
local fades,alphaNow={},1
local function label(name,z,font,color,textT,edge,edgeT)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Font=font;t.Text='';t.TextColor3=color;t.TextTransparency=textT;t.TextStrokeTransparency=1
 t.TextWrapped=false;t.TextXAlignment=Enum.TextXAlignment.Center;t.ZIndex=z;t.Parent=content
 local s=Instance.new('UIStroke');s.Name='Edge';s.Color=edge;s.Thickness=1;s.Transparency=edgeT;s.Parent=t
 fades[#fades+1]={Item=t,Prop='TextTransparency',Base=textT};fades[#fades+1]={Item=s,Prop='Transparency',Base=edgeT}
 return t,s
end
local capShade,capShadeEdge=label('CaptionShadow',1,Enum.Font.GothamMedium,SHADE,.5,SHADE,.5)
local titleShade,titleShadeEdge=label('NameShadow',1,Enum.Font.FredokaOne,SHADE,.5,SHADE,.5)
local caption,captionEdge=label('Caption',2,Enum.Font.GothamMedium,Color3.new(1,1,1),.08,INK,0)
local title,titleEdge=label('BiomeName',2,Enum.Font.FredokaOne,Color3.new(1,1,1),0,INK,0)
local function setAlpha(alpha)
 alphaNow=alpha
 for _,f in ipairs(fades)do local v=f.Base+(1-f.Base)*alpha;if f.Item[f.Prop]~=v then f.Item[f.Prop]=v end end
end
local function width(text,size,font)
 local ok,v=pcall(function()return TextService:GetTextSize(text,size,font,Vector2.new(400,100))end)
 return ok and typeof(v)=='Vector2'and v.X or #text*size*.55
end
local function view() -- the safe area HudNotices lays out in
 local ok,a=pcall(function()return GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)end)
 if ok and a and(a.Width or 0)>0 and(a.Height or 0)>0 then return a.Width,a.Height end
 local c=workspace.CurrentCamera;local v=c and c.ViewportSize;return v and v.X>0 and v.X or 1280,v and v.Y>0 and v.Y or 720
end
local function layout(style)
 local vw,vh=view();local k=SIZES[vh<480 and'land'or vw<vh and'port'or'pc']
 local capH,nameH=math.floor(k.Cap*1.25+.5),math.floor(k.Name*1.2+.5)
 local w=math.ceil(math.max(width(style.Label,k.Name,Enum.Font.FredokaOne),width('entering',k.Cap,Enum.Font.GothamMedium)))
 group.Size=UDim2.fromOffset(w,capH+nameH)
 for _,l in ipairs({{caption,captionEdge,k.Cap,capH,0,k.CapEdge},{capShade,capShadeEdge,k.Cap,capH,DROP,k.CapEdge},{title,titleEdge,k.Name,nameH,capH,k.Edge},{titleShade,titleShadeEdge,k.Name,nameH,capH+DROP,k.Edge}})do
  local t=l[1];t.TextSize=l[3];t.Size=UDim2.new(1,40,0,l[4]);t.Position=UDim2.fromOffset(-20,l[5]);l[2].Thickness=l[6]
 end
 title.Text=style.Label;titleShade.Text=style.Label;title.TextColor3=style.Color;caption.Text='entering';capShade.Text='entering'
 local row=Notice.Calculate(vw,vh,0,{Biome=true}).Biome;group.Position=UDim2.fromOffset(row.X,row.Y) -- until HudNotices (which also knows the top bar / tutorial card) places it
end
local gate=Gate.new()
local shownAt,poll,lastY=-100,0,nil
local dismissAt,dismissFrom
local function dismiss()
 if group.Visible and not dismissAt then dismissAt=os.clock();dismissFrom=alphaNow end
end
local function show(stage)
 local style=Styles[stage]
 if not style then dismiss();return end
 layout(style)
 shownAt=os.clock();dismissAt=nil;dismissFrom=nil;lastY=nil
 setAlpha(1);group.Visible=true
end
local function hideNow()setAlpha(1);group.Visible=false end
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
 -- Fade in, hold, fade out; turning back also fades (without restarting the clock).
 local alpha
 if dismissAt then
  local p=math.clamp((now-dismissAt)/DISMISS,0,1);alpha=dismissFrom+(1-dismissFrom)*p*p*(3-2*p)
 elseif age<IN then alpha=1-age/IN
 else local p=math.clamp((age-HOLD)/OUT,0,1);alpha=p*p*(3-2*p) end
 if alpha~=alphaNow then setAlpha(alpha)end
 if age>=HOLD+OUT or(dismissAt and now-dismissAt>=DISMISS)then hideNow();return end
 -- The only movement: the words settle down SETTLE px while fading in (none with Reduced Motion).
 local y=0
 if not GuiService.ReducedMotionEnabled then local e=1-math.min(age/IN,1);y=-math.floor(SETTLE*e^3+.5) end
 if y~=lastY then lastY=y;content.Position=UDim2.fromOffset(0,y)end
end)
gui.Destroying:Connect(function()spawnConnection:Disconnect();renderConnection:Disconnect()end)
