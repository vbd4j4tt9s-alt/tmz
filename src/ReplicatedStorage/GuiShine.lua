-- One scheduler; only a small set of visible main buttons/cards can animate.
local Run=game:GetService('RunService');local Gui=game:GetService('GuiService');local Players=game:GetService('Players')
local S={};local entries={};local connection;local Viewport
local function show(item,value)if item.Visible~=value then item.Visible=value end end
function S.Attach(root,rays)
 if entries[root]then return end
 local pane=Instance.new('Frame');pane.Name='SubtleShine';pane.Size=UDim2.fromScale(1,1);pane.BackgroundTransparency=1;pane.ClipsDescendants=true;pane.Active=false;pane.ZIndex=(root.ZIndex or 1)+1;pane.Parent=root
 local corner=root:FindFirstChildOfClass('UICorner');if corner then corner:Clone().Parent=pane end
 local stripe=Instance.new('Frame');stripe.Name='Sweep';stripe.Size=UDim2.fromScale(.20,1.8);stripe.Position=UDim2.fromScale(-.3,-.4);stripe.Rotation=22;stripe.BorderSizePixel=0;stripe.BackgroundColor3=Color3.new(1,1,1);stripe.BackgroundTransparency=.79;stripe.Active=false;stripe.Parent=pane
 local gradient=Instance.new('UIGradient');gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.35),NumberSequenceKeypoint.new(1,1)});gradient.Parent=stripe
 local spokes
 if rays then
  spokes=Instance.new('Frame');spokes.Name='Sunrays';spokes.BackgroundTransparency=1;spokes.AnchorPoint=Vector2.new(.5,.5);spokes.Position=UDim2.fromScale(.22,.46);spokes.Size=UDim2.fromOffset(320,320);spokes.Parent=pane
  for i=0,9 do local ray=Instance.new('Frame');ray.Name='Ray';ray.AnchorPoint=Vector2.new(.5,.5);ray.Position=UDim2.fromScale(.5,.5);ray.Size=UDim2.fromScale(.035,1.6);ray.Rotation=i*18;ray.BorderSizePixel=0;ray.BackgroundColor3=Color3.new(1,1,1);ray.BackgroundTransparency=.94;ray.Active=false;ray.Parent=spokes end
 end
 entries[root]={View=root,Sweep=stripe,Rays=spokes,Phase=0}
 root.Destroying:Connect(function()entries[root]=nil;if not next(entries)and connection then connection:Disconnect();connection=nil end end)
 -- R153 (owner: "fix all jittery type effects"): the sweep and the rays move every rendered frame in RenderStepped (the sweep crossed a
 -- button in 20 Hz steps); still at most 16 visible buttons, nothing for hidden ones.
 if not connection then connection=Run.RenderStepped:Connect(function(dt)
  local step=dt
  local p=Players.LocalPlayer;local paused=Gui.ReducedMotionEnabled or(p and p:GetAttribute('FastMode'));local count=0;if paused then
  for _,e in pairs(entries)do show(e.Sweep,false)end;return
 end
  Viewport=Viewport or require(script.Parent.ShopViewport)
  for r,e in pairs(entries)do
   -- R121: most shined buttons sit in closed menus; re-check only the cached hidden ancestor.
   if count<16 and Viewport.CachedVisible(e)then
    count+=1;e.Phase=(e.Phase+step)%4.6
    local sweeping=e.Phase<1.6;show(e.Sweep,sweeping)
    if sweeping then e.Sweep.Position=UDim2.fromScale(-.35+e.Phase/1.6*1.8,-.4)end
    if e.Rays then e.Rays.Rotation=(e.Rays.Rotation+step*3)%360 end
   else show(e.Sweep,false)end
  end
 end)end
end
return S
