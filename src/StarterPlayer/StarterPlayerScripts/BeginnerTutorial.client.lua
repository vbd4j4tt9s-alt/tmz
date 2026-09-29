-- R69: one top-right instruction, one world arrow, no welcome card or modal tutorial.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local Guide=require(RS.BeginnerGuide);local Theme=require(RS.GardenTheme);local Layout=require(RS.HudLayout)
local gui=Instance.new('ScreenGui');gui.Name='BeginnerTutorial';gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.Parent=pg
local panel=Instance.new('Frame');panel.Name='GuideCard';panel.BackgroundColor3=Color3.fromRGB(15,26,28);panel.BackgroundTransparency=.34;panel.BorderSizePixel=0;panel.Visible=false;panel.Parent=gui;Theme.Corner(panel,12)
local instruction=Instance.new('TextLabel');instruction.Name='Instruction';instruction.BackgroundTransparency=1;instruction.Position=UDim2.fromOffset(12,0);instruction.Size=UDim2.new(1,-44,1,0);instruction.TextXAlignment=Enum.TextXAlignment.Left;instruction.TextWrapped=true;instruction.Parent=panel;Theme.Text(instruction,20,true,Color3.fromRGB(255,246,212));instruction.TextStrokeTransparency=.35
local skip=Instance.new('TextButton');skip.Name='Skip';skip.Text='×';skip.TextSize=20;skip.BackgroundTransparency=1;skip.Position=UDim2.new(1,-32,0,0);skip.Size=UDim2.new(0,32,1,0);skip.TextColor3=Color3.fromRGB(227,232,227);skip.Font=Enum.Font.FredokaOne;skip.Parent=panel
local anchor=Instance.new('Part');anchor.Name='TutorialTarget';anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.CastShadow=false;anchor.Transparency=1;anchor.Size=Vector3.new(.1,.1,.1);anchor.Parent=workspace
local marker=Instance.new('BillboardGui');marker.Name='Goal';marker.Adornee=anchor;marker.AlwaysOnTop=true;marker.Size=UDim2.fromOffset(48,64);marker.StudsOffsetWorldSpace=Vector3.new(0,4,0);marker.Enabled=false;marker.Parent=gui
local function arrow(parent)
 local frame=Instance.new('Frame');frame.Name='Arrow';frame.Size=UDim2.fromScale(1,1);frame.BackgroundTransparency=1;frame.Parent=parent
 for _,v in ipairs({{.42,.06,.16,.60,0},{.25,.53,.16,.38,-42},{.59,.53,.16,.38,42}})do
  local p=Instance.new('Frame');p.Position=UDim2.fromScale(v[1],v[2]);p.Size=UDim2.fromScale(v[3],v[4]);p.Rotation=v[5];p.BackgroundColor3=Color3.fromRGB(255,222,86);p.BorderSizePixel=0;p.Parent=frame;Theme.Corner(p,3)
  local outline=Instance.new('UIStroke');outline.Color=Color3.fromRGB(67,45,15);outline.Thickness=2;outline.Parent=p
 end
 return frame
end
arrow(marker)
local edge=Instance.new('Frame');edge.Name='Direction';edge.Size=UDim2.fromOffset(28,38);edge.AnchorPoint=Vector2.new(.5,.5);edge.BackgroundTransparency=1;edge.Visible=false;edge.Parent=gui;arrow(edge)
local dead,busy=false,false;local info={};local step=0;local connections={};local active;local poll,arrowClock,introSeconds=0,0,0;local fetch,render
local function paintLayout()
 local v=Layout.Viewport(gui);local m=Guide.Layout(v.X,v.Y,step);panel.Position=UDim2.fromOffset(m.X,m.Y);panel.Size=UDim2.fromOffset(m.Width,m.Height);instruction.TextSize=m.Font
end
local function stop()if active then active:Disconnect();active=nil end;marker.Enabled=false;edge.Visible=false end
local function updateArrow(dt)
 arrowClock+=dt;if arrowClock<.05 then return end;arrowClock=0
 local target=info.Target;local part=info.TargetPart
 if part and part.Parent and part:IsA('BasePart')then target=part.Position end
 local spec=Guide.Steps[step]
 if not target or not panel.Visible or not spec or not spec.Target or spec.Target~=info.Kind then marker.Enabled=false;edge.Visible=false;return end
 anchor.Position=target;marker.Enabled=true
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
render=function()
 local actual=player:GetAttribute('TutorialStep')or 0
 step=actual
 if actual==1 and player:GetAttribute('ChestChaseSeedCarrying')then step=2
 elseif actual==5 and info.Step==6 then step=6 end
 local spec=Guide.Steps[step];panel.Visible=spec~=nil and pg:GetAttribute('SeedMenu')==nil and not pg:GetAttribute('TitleActive')
 paintLayout()
 if spec then instruction.Text=info.WaitingForPack and step==1 and'Wait for packs'or spec.Text end
 marker.Enabled=panel.Visible and spec.Target~=nil and spec.Target==info.Kind and info.Target~=nil
 if actual==0 then stop();return end
 if not active then active=Run.Heartbeat:Connect(function(dt)
  local current=Guide.Steps[step]
  if current and current.Informational then
   if panel.Visible then introSeconds+=dt end
   if introSeconds>=current.Seconds and not busy then introSeconds=0;poll=0;fetch('TreadmillInfo');updateArrow(dt);return end
  else introSeconds=0 end
  poll+=dt;if poll>=1 then poll=0;fetch()end;updateArrow(dt)
 end)end
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
skip.Activated:Connect(function()fetch('Skip')end)
for _,name in ipairs({'TutorialStep','ChestChaseSeedCarrying'})do connections[#connections+1]=player:GetAttributeChangedSignal(name):Connect(function()info={};render();task.delay(.25,function()fetch()end)end)end
connections[#connections+1]=pg:GetAttributeChangedSignal('SeedMenu'):Connect(render)
connections[#connections+1]=pg:GetAttributeChangedSignal('TitleActive'):Connect(render)
local unwatch=Layout.Watch(gui,paintLayout)
local function cleanup()if dead then return end;dead=true;stop();unwatch();anchor:Destroy();for _,c in ipairs(connections)do c:Disconnect()end end
gui.Destroying:Connect(cleanup);script.Destroying:Connect(function()cleanup();gui:Destroy()end)
render();fetch()
