-- R68: static common/rare item borders have no animation entry or heartbeat.
-- R123: rarity lives in the card border (no emblems). Each rarity has its own frame built
-- from UIStroke/UIGradient/Frames; only Legendary and up animate, on the shared 12 Hz
-- scheduler, only while visible, at most MaxAnimated cards per tick. FastMode,
-- ReducedMotion and low/off effects show a fixed (static) pose.
local Run=game:GetService('RunService');local Players=game:GetService('Players');local Gui=game:GetService('GuiService')
local M={};local records,animated={},{};local connection;local elapsed=0;local phase=0;local clock=0;local still=false
local RGB=Color3.fromRGB
M.MaxAnimated=24 -- visible animated borders updated per tick (the rest keep their last pose)
M.Rate=1/12
local function seq(stops)
 local keys={};for i,s in ipairs(stops)do keys[i]=ColorSequenceKeypoint.new(s[1],s[2])end;return ColorSequence.new(keys)
end
local function band(base,peak,width)
 return seq({{0,base},{.5-width,base},{.5,peak},{.5+width,base},{1,base}})
end
-- One entry per rarity: main line (root UIStroke), optional inner line, glow ring, corner gems, sparkles and motion.
M.Styles={
 Common={Line=RGB(146,166,142),Thickness=1,Transparency=.3},
 Uncommon={Line=RGB(74,196,98),Thickness=1.6,Transparency=0},
 Rare={Line=RGB(62,138,236),Thickness=1.6,Transparency=0,Inner={Color=RGB(150,206,255),Inset=3,Thickness=1,Transparency=.1}},
 Legendary={Line=RGB(255,255,255),Thickness=2.2,Transparency=0,Gradient=band(RGB(236,168,30),RGB(255,250,214),.12),GradientRotation=25,Motion='Sweep',Period=3.6},
 Mythic={Line=RGB(228,34,52),Thickness=2.2,Transparency=0,Glow={Color=RGB(255,64,78),Thickness=3,Spread=3,Low=.82,High=.35},Motion='Pulse',Period=1.8},
 Secret={Line=RGB(6,6,9),Thickness=2.4,Transparency=0,Inner={Color=RGB(255,255,255),Inset=2,Thickness=1,Transparency=.05,Gradient=band(RGB(150,154,164),RGB(255,255,255),.1),GradientRotation=35},Motion='Shimmer',Period=4.5},
 Cosmic={Line=RGB(255,255,255),Thickness=2.2,Transparency=0,Gradient=seq({{0,RGB(92,58,214)},{.35,RGB(174,124,255)},{.6,RGB(236,200,255)},{.8,RGB(130,92,240)},{1,RGB(92,58,214)}}),Sparkles=6,Motion='Starfield',Period=2.4},
 King={Line=RGB(255,255,255),Thickness=2.6,Transparency=0,Gradient=seq({{0,RGB(214,138,22)},{.3,RGB(255,214,92)},{.5,RGB(255,252,226)},{.7,RGB(255,214,92)},{1,RGB(214,138,22)}}),Glow={Color=RGB(255,214,104),Thickness=3,Spread=3,Low=.75,High=.3},Gems={Color=RGB(255,206,64),Edge=RGB(120,70,10),Ruby=RGB(214,18,52),RubyLight=RGB(255,96,120),RubyDeep=RGB(120,2,24),Facet=RGB(70,0,14),Core=RGB(255,236,240)},Motion='Radiant',Period=2.6},
}
M.Order={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local function visible(root)
 local p=root
 while p do
  if p:IsA('GuiObject')and not p.Visible then return false end
  if p:IsA('LayerCollector')and not p.Enabled then return false end
  if p:IsA('GuiObject')and(p.ClipsDescendants or p:IsA('ScrollingFrame'))then
   local a,b=root.AbsolutePosition,root.AbsolutePosition+root.AbsoluteSize;local c,d=p.AbsolutePosition,p.AbsolutePosition+p.AbsoluteSize
   if b.X<c.X or b.Y<c.Y or a.X>d.X or a.Y>d.Y then return false end
  end
  p=p.Parent
 end
 return root.Parent~=nil
end
M.Visible=visible
function M.Static()
 local player=Players.LocalPlayer;local mode=player and player:GetAttribute('StudioPlantEffects')
 return Gui.ReducedMotionEnabled==true or(player~=nil and player:GetAttribute('FastMode')==true)or mode=='off'or mode=='low'
end
-- Pose of one animated rarity border at time t (seconds). t=nil is the static pose.
local function pose(e,t)
 local s=M.Styles[e.Rarity];if not s then return end
 local u=t and(t%s.Period)/s.Period or .5
 if s.Motion=='Sweep'then
  -- A bright band crosses the gold line, then rests off the card for the last third.
  local x=t and math.clamp(u*1.5*2.4-1.2,-1.2,1.2)or .15;e.Gradient.Offset=Vector2.new(x,0)
 elseif s.Motion=='Pulse'then
  local k=t and(.5-.5*math.cos(u*math.pi*2))or .5;e.Glow.Transparency=s.Glow.Low+(s.Glow.High-s.Glow.Low)*k
 elseif s.Motion=='Shimmer'then
  e.InnerGradient.Offset=Vector2.new(t and(u*2.4-1.2)or .1,0)
 elseif s.Motion=='Starfield'then
  e.Gradient.Rotation=t and(u*360)or 30
  for i,star in ipairs(e.Sparkles)do
   local k=t and math.max(0,math.sin((u+i/#e.Sparkles)*math.pi*2))or(i%2==0 and .8 or .25)
   star.BackgroundTransparency=1-k*.95;local d=3+math.floor(k*2+.5);star.Size=UDim2.fromOffset(d,d)
  end
 elseif s.Motion=='Radiant'then
  e.Gradient.Rotation=t and(u*360)or 45
  local k=t and(.5-.5*math.cos(u*math.pi*2))or .5;e.Glow.Transparency=s.Glow.Low+(s.Glow.High-s.Glow.Low)*k
  if e.GemCores then for i,c in ipairs(e.GemCores)do c.BackgroundTransparency=t and .55*(1-math.max(0,math.sin((u+i*.25)*math.pi*2)))or .1 end end
 end
end
M.Pose=pose
local function tick()
 if M.Static()then
  -- Static mode: settle every border into its fixed pose once, then do no work.
  if not still then still=true;for _,e in pairs(animated)do if e.Rarity then pose(e,nil)end end end
  return 0
 end
 still=false;local count=0
 for card,e in pairs(animated)do
  if count>=M.MaxAnimated then break end
  if visible(card)then
   count+=1
   if e.Rarity then pose(e,clock)elseif e.Stroke.Enabled then e.Gradient.Rotation=phase end
  end
 end
 return count
end
M.Tick=tick
local function scheduler()
 if not next(animated)then if connection then connection:Disconnect();connection=nil;elapsed=0 end;return end
 if connection then return end
 connection=Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<M.Rate then return end;phase=(phase+elapsed*24)%360;clock+=elapsed;elapsed=0
  tick()
 end)
end
function M.Running()return connection~=nil end
function M.Count()local n=0;for _ in pairs(animated)do n+=1 end;return n end
local function record(root)
 local e=records[root]
 if not e then
  local stroke=Instance.new('UIStroke');stroke.Name='AnimatedBorder';stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Thickness=1.2;stroke.Transparency=.18;stroke.Parent=root
  e={Stroke=stroke};records[root]=e
  local function select()stroke.Enabled=root:GetAttribute('Selected')~=true end
  e.Selected=root:GetAttributeChangedSignal('Selected'):Connect(select);select()
  root.Destroying:Connect(function()e.Selected:Disconnect();records[root]=nil;animated[root]=nil;scheduler()end)
 end
 return e
end
local function clearRarity(e)
 if e.Overlay then e.Overlay:Destroy()end
 e.Overlay=nil;e.Glow=nil;e.InnerGradient=nil;e.Sparkles=nil;e.GemCores=nil;e.Rarity=nil
end
function M.Apply(root,color,shine)
 local e=record(root);if e.Rarity then clearRarity(e);root:SetAttribute('BorderRarity',nil)end
 e.Stroke.Thickness=1.2;e.Stroke.Transparency=.18
 if e.Stroke.Color~=color then e.Stroke.Color=color end
 if shine~=false then
  if not e.Gradient then
   local g=Instance.new('UIGradient');g.Name='BorderShine';g.Parent=e.Stroke;e.Gradient=g
  end
  e.Gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(110,110,110)),ColorSequenceKeypoint.new(.45,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.55,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(110,110,110))});e.Gradient.Offset=Vector2.new(0,0)
  animated[root]=e
 else
  animated[root]=nil;if e.Gradient then e.Gradient:Destroy();e.Gradient=nil end
 end
 scheduler();return e.Stroke
end
local function radius(root)
 local c=root:FindFirstChildOfClass('UICorner');return c and c.CornerRadius.Offset or 0
end
local function layer(parent,name,inset,r,z)
 local f=Instance.new('Frame');f.Name=name;f.BackgroundTransparency=1;f.BorderSizePixel=0;f.Active=false;f.ZIndex=z
 f.Position=UDim2.fromOffset(inset,inset);f.Size=UDim2.new(1,-2*inset,1,-2*inset);f.Parent=parent
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,math.max(0,r-inset));c.Parent=f;return f
end
local function line(parent,color,thickness,transparency)
 local s=Instance.new('UIStroke');s.Name='Line';s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Color=color;s.Thickness=thickness;s.Transparency=transparency or 0;s.Parent=parent;return s
end
local function dot(parent,name,x,y,size,color,rotation,z)
 local f=Instance.new('Frame');f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.new(x,0,y,0);f.Size=UDim2.fromOffset(size,size);f.BorderSizePixel=0
 f.BackgroundColor3=color;f.Rotation=rotation or 0;f.Active=false;f.ZIndex=z;f.Parent=parent;return f
end
-- Perimeter points (as scale) for sparkles, spread around the edge clockwise from the top-left.
local perimeter={{.18,0},{.62,0},{1,.3},{1,.78},{.4,1},{0,.55},{.86,1},{0,.12}}
function M.Rarity(root,rarity)
 local s=M.Styles[rarity]or M.Styles.Common;rarity=M.Styles[rarity]and rarity or'Common'
 local e=record(root)
 if e.Rarity==rarity then return e.Stroke end
 clearRarity(e);if e.Gradient then e.Gradient:Destroy();e.Gradient=nil end
 e.Rarity=rarity;root:SetAttribute('BorderRarity',rarity)
 local stroke=e.Stroke;stroke.Color=s.Line;stroke.Thickness=s.Thickness;stroke.Transparency=s.Transparency or 0
 if s.Gradient then
  local g=Instance.new('UIGradient');g.Name='BorderShine';g.Color=s.Gradient;g.Rotation=s.GradientRotation or 0;g.Parent=stroke;e.Gradient=g
 end
 if s.Inner or s.Glow or s.Gems or s.Sparkles then
  local r=radius(root);local z=(root.ZIndex or 1)+1
  local overlay=Instance.new('Frame');overlay.Name='RarityBorder';overlay.BackgroundTransparency=1;overlay.BorderSizePixel=0;overlay.Active=false;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=z;overlay.Parent=root;e.Overlay=overlay
  if s.Glow then
   local glow=layer(overlay,'Glow',-s.Glow.Spread,r,z);e.Glow=line(glow,s.Glow.Color,s.Glow.Thickness,(s.Glow.Low+s.Glow.High)/2)
  end
  if s.Inner then
   local inner=layer(overlay,'InnerLine',s.Inner.Inset,r,z);local l=line(inner,s.Inner.Color,s.Inner.Thickness,s.Inner.Transparency)
   if s.Inner.Gradient then local g=Instance.new('UIGradient');g.Name='Shimmer';g.Color=s.Inner.Gradient;g.Rotation=s.Inner.GradientRotation or 0;g.Parent=l;e.InnerGradient=g end
  end
  if s.Gems then
   -- R124: polished rubies in gold settings: gold bezel (CrownGem), faceted ruby with light-to-deep shading, a dark
   -- facet edge and a bright specular core that twinkles with the King glow.
   e.GemCores={}
   for i,p in ipairs({{0,0},{1,0},{0,1},{1,1}})do
    local gem=dot(overlay,'CrownGem'..i,p[1],p[2],11,s.Gems.Color,45,z+1);line(gem,s.Gems.Edge,1,0)
    gem.Position=UDim2.new(p[1],p[1]==0 and 4 or-4,p[2],p[2]==0 and 4 or-4) -- tucked into the corner curve
    local ruby=dot(gem,'Ruby',.5,.5,7,s.Gems.Ruby,0,z+2);local facet=line(ruby,s.Gems.Facet,1,.1);facet.Name='Facet'
    local shade=Instance.new('UIGradient');shade.Name='Shade';shade.Rotation=90
    shade.Color=seq({{0,s.Gems.RubyLight},{.45,s.Gems.Ruby},{1,s.Gems.RubyDeep}});shade.Parent=ruby
    local table_=dot(ruby,'Table',.5,.5,3,s.Gems.RubyLight,0,z+2);table_.BackgroundTransparency=.35 -- the flat top facet
    e.GemCores[i]=dot(gem,'Core',.36,.36,2,s.Gems.Core,0,z+3)
   end
  end
  if s.Sparkles then
   e.Sparkles={}
   for i=1,s.Sparkles do local p=perimeter[i];e.Sparkles[i]=dot(overlay,'Sparkle'..i,p[1],p[2],3,RGB(255,255,255),45,z+1)end
  end
 end
 if s.Motion then animated[root]=e;pose(e,M.Static()and nil or clock)else animated[root]=nil end
 scheduler();return stroke
end
function M.Limited(root)
 local stroke=M.Apply(root,Color3.fromRGB(255,78,196),true);stroke.Thickness=3;stroke.Transparency=0
 records[root].Gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,54,188)),ColorSequenceKeypoint.new(.45,Color3.fromRGB(255,129,224)),ColorSequenceKeypoint.new(.52,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,54,188))})
 local old=root:FindFirstChild('LimitedOrbit');if old then old:Destroy()end
 return stroke
end
return M
