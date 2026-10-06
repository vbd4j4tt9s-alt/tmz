do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- V147. Owner console and flight. The server independently authorizes every request.
local RunService=game:GetService('RunService')
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local UIS=game:GetService('UserInputService');local player=Players.LocalPlayer
local Layout=require(RS.NoticeLayout85);local TextService=game:GetService('TextService')
local function allowed()return RunService:IsStudio()or player:GetAttribute('ChestChaseCommandsAllowed')==true end
local function movementAllowed()return allowed()or player:GetAttribute('OwnerMovementGranted82')==true end
local help=require(RS:WaitForChild('StudioTestHelp'))
local folder=RS:WaitForChild('ChestChaseStudioTests');if not folder then return end
local request=folder:WaitForChild('Execute');local feedback=folder:WaitForChild('Feedback')
local pg=player:WaitForChild('PlayerGui')
local gui=Instance.new('ScreenGui');gui.Name='ChestChaseStudioTools';gui.ResetOnSpawn=false;gui.DisplayOrder=120;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Enabled=allowed();gui.Parent=pg
local toggle=require(RS.ButtonStyle).Create(gui,'OwnerToolsButton','Gear',UDim2.new(1,-62,.5,-24),UDim2.fromOffset(48,48),Color3.fromRGB(75,118,106),false)
local caption=Instance.new('TextLabel');caption.Name='OwnerCaption';caption.Text='TOOLS';caption.Font=Enum.Font.FredokaOne;caption.TextSize=9;caption.TextColor3=Color3.new(1,1,1);caption.BackgroundTransparency=1;caption.Size=UDim2.new(1,0,0,12);caption.Position=UDim2.new(0,0,1,-12);caption.Parent=toggle
-- Hide the owner-only shortcut on touch devices, including Studio phone emulation.
local mobileTools=false
local function syncToolsVisibility()
 toggle.Visible=not mobileTools and allowed()and pg:GetAttribute('GardenMenuExpanded')~=true and pg:GetAttribute('SeedMenu')==nil
 if mobileTools then local console=gui:FindFirstChild('TestConsole');if console then console.Visible=false end end
end
local stopToolsLayout=require(RS.HudLayout).Watch(toggle,function(m)
 mobileTools=m.HideOwnerTools==true
 toggle.Position=UDim2.fromOffset(10,8);toggle.Size=UDim2.fromOffset(48,48)
 syncToolsVisibility()
end)
local toolsMenuConnection=pg:GetAttributeChangedSignal('GardenMenuExpanded'):Connect(syncToolsVisibility)
local toolsModalConnection=pg:GetAttributeChangedSignal('SeedMenu'):Connect(syncToolsVisibility)
syncToolsVisibility()

local panel=Instance.new('Frame');panel.Name='TestConsole';panel.Size=UDim2.new(1,-24,1,-24);panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
panel.BackgroundColor3=Color3.fromRGB(238,246,242);panel.Visible=false;panel.Parent=gui
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=panel
local function label(parent,text,pos,size,fontSize)
 local l=Instance.new('TextLabel');l.Text=text;l.Position=pos;l.Size=size;l.TextSize=fontSize or 15;l.Font=Enum.Font.FredokaOne
 l.TextColor3=Color3.fromRGB(28,59,48);l.BackgroundTransparency=1;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Top;l.Parent=parent;return l
end
label(panel,'OWNER TOOLS',UDim2.fromOffset(16,12),UDim2.new(1,-165,0,24),19)
local close=Instance.new('TextButton');close.Text='×';close.TextSize=24;close.Size=UDim2.fromOffset(34,30);close.Position=UDim2.new(1,-44,0,6);close.BackgroundTransparency=1;close.Parent=panel
close.Activated:Connect(function()panel.Visible=false end)

local scroll=Instance.new('ScrollingFrame');scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.Position=UDim2.fromOffset(16,45)
scroll.Name='CommandScroll';scroll.Size=UDim2.new(1,-64,1,-144);scroll.ScrollBarThickness=9;scroll.ScrollBarImageColor3=Color3.fromRGB(64,128,99);scroll.ScrollingDirection=Enum.ScrollingDirection.Y;scroll.Active=true;scroll.ScrollingEnabled=true;scroll.ClipsDescendants=true;scroll.AutomaticCanvasSize=Enum.AutomaticSize.None;scroll.CanvasSize=UDim2.new();scroll.Parent=panel
local lines={'F4 closes this panel. Owner commands work in public servers. Append @username or @all. Progression changes save; movement and animation overrides are temporary.',''}
for _,entry in ipairs(help)do table.insert(lines,entry[2]==''and('\n'..entry[1])or(entry[1]..'\n'..entry[2]..'\n'))end
local helpLabel=label(scroll,table.concat(lines,'\n'),UDim2.new(),UDim2.new(1,-12,0,0),14);helpLabel.Name='CommandHelp';helpLabel.TextWrapped=true
local resizeQueued=false
local function resizeHelp()
 local width=math.max(1,scroll.AbsoluteSize.X-18)
 local measured=TextService:GetTextSize(helpLabel.Text,helpLabel.TextSize,helpLabel.Font,Vector2.new(width,100000))
 helpLabel.Size=UDim2.fromOffset(width,math.ceil(measured.Y)+12)
 scroll.CanvasSize=UDim2.fromOffset(0,math.ceil(measured.Y)+20)
 scroll.CanvasPosition=Vector2.new(0,math.clamp(scroll.CanvasPosition.Y,0,math.max(0,measured.Y+20-scroll.AbsoluteSize.Y)))
end
local function queueResize()
 if resizeQueued then return end;resizeQueued=true;task.defer(function()resizeQueued=false;if gui.Parent then resizeHelp()end end)
end
scroll:GetPropertyChangedSignal('AbsoluteSize'):Connect(queueResize);helpLabel:GetPropertyChangedSignal('Text'):Connect(queueResize)
local function showCommands()helpLabel.Text=table.concat(lines,'\n');scroll.CanvasPosition=Vector2.zero;queueResize()end
local commands=Instance.new('TextButton');commands.Name='ShowCommands';commands.Text='COMMANDS';commands.Font=Enum.Font.FredokaOne;commands.TextSize=12;commands.TextColor3=Color3.fromRGB(28,59,48);commands.BackgroundColor3=Color3.fromRGB(214,232,222);commands.Size=UDim2.fromOffset(86,26);commands.Position=UDim2.new(1,-138,0,10);commands.Parent=panel;commands.Activated:Connect(showCommands)
for i,spec in ipairs({{'▲',-1},{'▼',1}})do
 local b=Instance.new('TextButton');b.Name=i==1 and'ScrollUp'or'ScrollDown';b.Text=spec[1];b.TextSize=18;b.TextColor3=Color3.fromRGB(28,59,48);b.BackgroundColor3=Color3.fromRGB(214,232,222);b.Size=UDim2.fromOffset(30,34);b.Position=UDim2.new(1,-43,0,46+(i-1)*40);b.Parent=panel
 b.Activated:Connect(function()scroll.CanvasPosition=Vector2.new(0,math.clamp(scroll.CanvasPosition.Y+spec[2]*scroll.AbsoluteSize.Y*.8,0,math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y)))end)
end
label(panel,'Scroll ↕',UDim2.new(0,16,1,-101),UDim2.new(1,-32,0,16),11)
toggle.Activated:Connect(function()if allowed()then panel.Visible=not panel.Visible;if panel.Visible then showCommands()end end end)
queueResize()
local status=label(panel,'Type plain English below. In chat, use /test before the same phrase.',UDim2.new(0,16,1,-84),UDim2.new(1,-32,0,36),13);status.TextWrapped=true;status.TextScaled=true;local statusFit=Instance.new('UITextSizeConstraint');statusFit.MinTextSize=10;statusFit.MaxTextSize=13;statusFit.Parent=status
local input=Instance.new('TextBox');input.PlaceholderText='give me all seeds';input.Text='';input.ClearTextOnFocus=false
input.Position=UDim2.new(0,16,1,-42);input.Size=UDim2.new(1,-105,0,30);input.BackgroundColor3=Color3.fromRGB(214,232,222)
input.TextColor3=Color3.fromRGB(25,52,40);input.Font=Enum.Font.Code;input.TextSize=15;input.TextXAlignment=Enum.TextXAlignment.Left;input.Parent=panel
local run=Instance.new('TextButton');run.Text='RUN';run.TextSize=14;run.Font=Enum.Font.FredokaOne;run.Position=UDim2.new(1,-80,1,-42);run.Size=UDim2.fromOffset(64,30);run.BackgroundColor3=Color3.fromRGB(127,203,164);run.Parent=panel
local pending=false
local function submit()
 if not allowed()or pending or input.Text==''then return end;pending=true
 local text=input.Text;if text:sub(1,1)~='/'then text='/test '..text end
 task.spawn(function()
  local ok,success,message=pcall(function()return request:InvokeServer(text)end);pending=false
  if not ok then status.Text='Command failed; check Output.'else status.Text=tostring(message):match('[^\n]+')or''end
 end)
end
run.Activated:Connect(submit);input.FocusLost:Connect(function(enter)if enter then submit()end end)
local Notices=require(RS.NoticeFeed83)
feedback.OnClientEvent:Connect(function(ok,message)
 status.Text=tostring(message):match('[^\n]+')or'';print('[Studio Test] '..tostring(message))
 if tostring(message):find('\n',1,true)then panel.Visible=true;helpLabel.Text=message;scroll.CanvasPosition=Vector2.zero
 else Notices.Plain(tostring(message),ok and Color3.fromRGB(225,255,236)or Color3.fromRGB(255,190,150),5)end
end)
UIS.InputBegan:Connect(function(inputObject)
 if allowed()and inputObject.KeyCode==Enum.KeyCode.F4 and not UIS:GetFocusedTextBox()then
  panel.Visible=not panel.Visible;if panel.Visible then showCommands()end
 end
end)
local perf=label(gui,'',UDim2.fromOffset(16,110),UDim2.fromOffset(520,84),14);perf.TextColor3=Color3.fromRGB(235,255,243);perf.TextStrokeTransparency=.3;perf.Visible=false;perf.TextWrapped=true;perf.TextScaled=true;local perfFit=Instance.new('UITextSizeConstraint');perfFit.MinTextSize=10;perfFit.MaxTextSize=14;perfFit.Parent=perf
local flight=nil;local noClipParts={}
local function restoreCollisions()
 for part,original in pairs(noClipParts)do if part.Parent then part.CanCollide=original end end;table.clear(noClipParts)
end
local function stopFlight()
 if not flight then return end
 local old=flight;flight=nil
 for _,item in ipairs(old.Items)do item:Destroy()end
 if old.Root.Parent then old.Root.AssemblyLinearVelocity=Vector3.zero;old.Root.AssemblyAngularVelocity=Vector3.zero end
 if old.Humanoid.Parent then
  old.Humanoid.AutoRotate=old.AutoRotate;old.Humanoid.PlatformStand=old.PlatformStand
  if old.Humanoid.Health>0 and not old.PlatformStand then old.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)end
 end
end
local function startFlight(character,humanoid,root)
 local attachment=Instance.new('Attachment');attachment.Name='StudioFlightAttachment';attachment.Parent=root
 local velocity=Instance.new('LinearVelocity');velocity.Name='StudioFlightVelocity';velocity.Attachment0=attachment
 velocity.RelativeTo=Enum.ActuatorRelativeTo.World;velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
 velocity.ForceLimitsEnabled=false;velocity.VectorVelocity=Vector3.zero;velocity.Parent=root
 local orientation=Instance.new('AlignOrientation');orientation.Name='StudioFlightOrientation';orientation.Mode=Enum.OrientationAlignmentMode.OneAttachment
 orientation.Attachment0=attachment;orientation.MaxTorque=10000000;orientation.Responsiveness=20;orientation.CFrame=root.CFrame.Rotation;orientation.Parent=root
 flight={Character=character,Humanoid=humanoid,Root=root,Velocity=velocity,Orientation=orientation,Items={velocity,orientation,attachment},AutoRotate=humanoid.AutoRotate,PlatformStand=humanoid.PlatformStand}
 humanoid.AutoRotate=false;humanoid.PlatformStand=true
end
local function down(key)return UIS:IsKeyDown(Enum.KeyCode[key])and 1 or 0 end
local frames,elapsed=0,0
local worstFrame,hitches,measuring=0,0,false
local connection=RunService.RenderStepped:Connect(function(dt)
 local char=player.Character;local hum=char and char:FindFirstChildOfClass('Humanoid');local root=char and char:FindFirstChild('HumanoidRootPart')
 local flying=movementAllowed()and player:GetAttribute('StudioTestFlying')and hum and hum.Health>0 and root and not player:GetAttribute('GuardianRagdollActive')and not player:GetAttribute('ChestChaseRunActive')
 if flight and(not flying or flight.Character~=char)then stopFlight()end
 if flying and not flight then startFlight(char,hum,root)end
 if flight then
  local camera=workspace.CurrentCamera;local v=Vector3.zero
  if camera and not UIS:GetFocusedTextBox()then
   v=camera.CFrame.LookVector*(down('W')-down('S'))+camera.CFrame.RightVector*(down('D')-down('A'))+Vector3.yAxis*(math.max(down('Space'),down('E'))-math.max(down('LeftControl'),down('Q')))
  end
  flight.Velocity.VectorVelocity=v.Magnitude>0 and v.Unit*(player:GetAttribute('StudioTestFlySpeed')or 60)or Vector3.zero
  if camera then
   local forward=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
   if forward.Magnitude>.01 then flight.Orientation.CFrame=CFrame.lookAt(Vector3.zero,forward)end
  end
 end
 local active=player:GetAttribute('StudioTestPerf')==true
 if active and not measuring then worstFrame=0;hitches=0 end
 if active and measuring then worstFrame=math.max(worstFrame,dt);if dt>=.1 then hitches+=1 end end
 measuring=active
 frames+=1;elapsed+=dt
 if elapsed>=.5 then
  local camera=workspace.CurrentCamera
  if camera then
   local inset=game:GetService('GuiService'):GetGuiInset();local layout=Layout.Console(camera.ViewportSize.X,camera.ViewportSize.Y-inset.Y)
   local size=UDim2.fromOffset(layout.Width,layout.Height);if panel.Size~=size then panel.Size=size end
   perf.Size=UDim2.fromOffset(math.max(1,math.min(520,camera.ViewportSize.X-32)),84)
  end
  gui.Enabled=allowed()or player:GetAttribute('StudioTestPerf')==true;syncToolsVisibility();if not allowed()then panel.Visible=false end;perf.Visible=player:GetAttribute('StudioTestPerf')==true
  if perf.Visible then
   perf.Text=string.format('FPS %.0f | Worst %.0f ms | Hitches (100ms+) %d\nPlants %d | Parts %d/1400 | Effects %d/4 | Builds %d | Fruit updates %d',frames/elapsed,worstFrame*1000,hitches,player:GetAttribute('PlantDetailModels')or 0,player:GetAttribute('PlantDetailBudget')or 0,player:GetAttribute('PlantEffectModels')or 0,player:GetAttribute('PlantArtBuilds')or 0,player:GetAttribute('PlantFruitUpdates')or 0)
  end
  elapsed=0;frames=0
 end
end)
local collisionConnection=RunService.Stepped:Connect(function()
 local char=player.Character
 if movementAllowed()and player:GetAttribute('StudioTestNoclip')and char then
  for _,part in ipairs(char:GetDescendants())do if part:IsA('BasePart')then
   if noClipParts[part]==nil then noClipParts[part]=part.CanCollide end;part.CanCollide=false
  end end
 else if next(noClipParts)then restoreCollisions()end end
end)
player.CharacterRemoving:Connect(function()stopFlight();restoreCollisions()end)
script.Destroying:Connect(function()stopToolsLayout();toolsMenuConnection:Disconnect();toolsModalConnection:Disconnect();connection:Disconnect();collisionConnection:Disconnect();stopFlight();restoreCollisions();gui:Destroy()end)
