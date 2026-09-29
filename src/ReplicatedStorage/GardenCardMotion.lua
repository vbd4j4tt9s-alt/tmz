-- R68: static common/rare item borders have no animation entry or heartbeat.
local Run=game:GetService('RunService');local Players=game:GetService('Players');local Gui=game:GetService('GuiService')
local M={};local records,animated={},{};local connection;local elapsed=0;local phase=0
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
local function scheduler()
 if not next(animated)then if connection then connection:Disconnect();connection=nil;elapsed=0 end;return end
 if connection then return end
 connection=Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1/12 then return end;phase=(phase+elapsed*24)%360;elapsed=0
  local player=Players.LocalPlayer;local mode=player and player:GetAttribute('StudioPlantEffects')
  if Gui.ReducedMotionEnabled or(player and player:GetAttribute('FastMode'))or mode=='off'or mode=='low'then return end
  for card,e in pairs(animated)do if e.Stroke.Enabled and visible(card)then e.Gradient.Rotation=phase end end
 end)
end
function M.Apply(root,color,shine)
 local e=records[root]
 if not e then
  local stroke=Instance.new('UIStroke');stroke.Name='AnimatedBorder';stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Thickness=1.2;stroke.Transparency=.18;stroke.Parent=root
  e={Stroke=stroke};records[root]=e
  local function select()stroke.Enabled=root:GetAttribute('Selected')~=true end
  e.Selected=root:GetAttributeChangedSignal('Selected'):Connect(select);select()
  root.Destroying:Connect(function()e.Selected:Disconnect();records[root]=nil;animated[root]=nil;scheduler()end)
 end
 if e.Stroke.Color~=color then e.Stroke.Color=color end
 if shine~=false then
  if not e.Gradient then
   local g=Instance.new('UIGradient');g.Name='BorderShine';g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(110,110,110)),ColorSequenceKeypoint.new(.45,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.55,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(110,110,110))});g.Parent=e.Stroke;e.Gradient=g
  end
  animated[root]=e
 else
  animated[root]=nil;if e.Gradient then e.Gradient:Destroy();e.Gradient=nil end
 end
 scheduler();return e.Stroke
end
function M.Limited(root)
 local stroke=M.Apply(root,Color3.fromRGB(255,78,196),true);stroke.Thickness=3;stroke.Transparency=0
 records[root].Gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,54,188)),ColorSequenceKeypoint.new(.45,Color3.fromRGB(255,129,224)),ColorSequenceKeypoint.new(.52,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,54,188))})
 local old=root:FindFirstChild('LimitedOrbit');if old then old:Destroy()end
 return stroke
end
return M
