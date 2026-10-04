-- R141 (owner: "a pedestal with a mystery pack ... black silhouette ... after 15 minutes of staying in the game they
-- unlock the pack, refreshes every day"): the label over every base's mystery pedestal (whose it is, 🔒 time left with a
-- bar, ✨ UNLOCKED / TAKE IT, ✓ taken and the time to the next one), the take prompt (only its owner sees it, only once
-- unlocked), a burst when yours unlocks and a slow spin on the pack. The server (MysteryPackService) owns everything
-- else; this reads the pedestal's attributes.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer
local M=require(RS:WaitForChild('MysteryPackRules'));local D=require(RS:WaitForChild('DailyRewards'))
local Audio;pcall(function()Audio=require(RS.InteractionAudio)end)
local RGB=Color3.fromRGB
local VIOLET,GOLD,MINT=RGB(190,140,255),RGB(255,214,90),RGB(120,236,110)
local entries={}
local function now()return workspace:GetServerTimeNow()end
local function label(parent,name,y,h,color)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Position=UDim2.fromScale(0,y);t.Size=UDim2.fromScale(1,h)
 t.Font=Enum.Font.FredokaOne;t.TextScaled=true;t.TextColor3=color or Color3.new(1,1,1);t.TextStrokeTransparency=.15;t.TextStrokeColor3=RGB(10,8,22);t.Text='';t.Parent=parent
 return t
end
local function build(model,anchor)
 local gui=Instance.new('BillboardGui');gui.Name='MysteryLabel';gui.Adornee=anchor;gui.Size=UDim2.fromOffset(230,96);gui.StudsOffset=Vector3.new(0,4.3,0)
 gui.MaxDistance=160;gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.ResetOnSpawn=false;gui.Enabled=false
 local title=label(gui,'Title',0,.34,VIOLET)
 local status=label(gui,'Status',.36,.36)
 local bar=Instance.new('Frame');bar.Name='Bar';bar.AnchorPoint=Vector2.new(.5,0);bar.Position=UDim2.fromScale(.5,.8);bar.Size=UDim2.fromScale(.72,.14)
 bar.BackgroundColor3=RGB(24,20,44);bar.BorderSizePixel=0;bar.Parent=gui
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(1,0);c.Parent=bar
 local edge=Instance.new('UIStroke');edge.Color=RGB(10,8,22);edge.Thickness=2;edge.Parent=bar
 local fill=Instance.new('Frame');fill.Name='Fill';fill.BackgroundColor3=VIOLET;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(0,1);fill.Parent=bar
 local fc=Instance.new('UICorner');fc.CornerRadius=UDim.new(1,0);fc.Parent=fill
 gui.Parent=model
 return gui
end
-- A short burst of light and sparks around the pack (when yours unlocks, and smaller when you take it).
local function burst(anchor,color,big)
 if not anchor or not anchor.Parent then return end
 local ring=Instance.new('Part');ring.Name='MysteryBurst';ring.Anchored=true;ring.CanCollide=false;ring.CanQuery=false;ring.CanTouch=false
 ring.Shape=Enum.PartType.Cylinder;ring.Material=Enum.Material.Neon;ring.Color=color;ring.Transparency=.1
 ring.Size=Vector3.new(.2,2,2);ring.CFrame=anchor.CFrame*CFrame.Angles(0,0,math.pi/2);ring.Parent=workspace
 local size=big and 16 or 9
 if GuiService.ReducedMotionEnabled then ring.Transparency=1 else
  Tween:Create(ring,TweenInfo.new(big and .9 or .5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(.2,size,size),Transparency=1}):Play()
 end
 local att=Instance.new('Attachment');att.Parent=ring
 local sparks=Instance.new('ParticleEmitter');sparks.Texture='rbxasset://textures/particles/sparkles_main.dds';sparks.Color=ColorSequence.new(color)
 sparks.LightEmission=1;sparks.Lifetime=NumberRange.new(.5,1);sparks.Speed=NumberRange.new(8,16);sparks.SpreadAngle=Vector2.new(180,180)
 sparks.Size=NumberSequence.new(.5,0);sparks.Rate=0;sparks.Parent=att;sparks:Emit(big and 40 or 16)
 game:GetService('Debris'):AddItem(ring,1.4)
 if Audio then pcall(Audio.Play,big and'GemClaim'or'Bubble04')end
end
local function update(entry)
 local m=entry.Model;local state=m:GetAttribute('State')or'Empty';local mine=m:GetAttribute('OwnerUserId')==player.UserId
 local gui=entry.Gui;gui.Enabled=state~='Empty'
 if entry.Prompt then entry.Prompt.Enabled=mine and state=='Ready'end
 if state=='Empty'then entry.State=state;return end
 local owner=mine and'YOUR'or(tostring(m:GetAttribute('OwnerName')or'?'):upper().."'S")
 local bar,fill=gui.Bar,gui.Bar.Fill
 if state=='Locked'then
  local at=tonumber(m:GetAttribute('UnlockAt'));local left=at and math.max(0,at-now())or M.UnlockSeconds
  gui.Title.Text='❓ '..owner..' MYSTERY PACK';gui.Title.TextColor3=VIOLET
  gui.Status.Text='🔒 '..M.Clock(left);gui.Status.TextColor3=Color3.new(1,1,1)
  bar.Visible=true;fill.Size=UDim2.fromScale(math.clamp(1-left/M.UnlockSeconds,0,1),1);fill.BackgroundColor3=VIOLET
 elseif state=='Ready'then
  gui.Title.Text='✨ '..owner..' MYSTERY PACK';gui.Title.TextColor3=GOLD
  gui.Status.Text=mine and'UNLOCKED! TAKE IT 🎁'or'UNLOCKED!';gui.Status.TextColor3=GOLD
  bar.Visible=true;fill.Size=UDim2.fromScale(1,1);fill.BackgroundColor3=GOLD
 else
  local at=tonumber(m:GetAttribute('NextAt'));local left=at and math.max(0,at-now())or 0
  gui.Title.Text='✓ TAKEN TODAY';gui.Title.TextColor3=MINT
  gui.Status.Text='NEW PACK IN '..D.Countdown(left);gui.Status.TextColor3=Color3.new(1,1,1)
  bar.Visible=false
 end
 if entry.State and entry.State~=state and mine then
  if state=='Ready'then burst(entry.Anchor,GOLD,true)elseif state=='Claimed'then burst(entry.Anchor,MINT,false)end
 end
 entry.State=state
end
local function add(model)
 if entries[model]or not model:IsA('Model')then return end
 local anchor=model:FindFirstChild('PackAnchor')or model:WaitForChild('PackAnchor',10)
 if not anchor or not model.Parent then return end
 local entry={Model=model,Anchor=anchor,Prompt=anchor:FindFirstChild('TakeMysteryPack'),Links={}}
 entry.Gui=build(model,anchor);entries[model]=entry
 for _,key in ipairs({'State','OwnerUserId','OwnerName','UnlockAt','NextAt'})do
  entry.Links[#entry.Links+1]=model:GetAttributeChangedSignal(key):Connect(function()update(entry)end)
 end
 entry.Links[#entry.Links+1]=anchor.ChildAdded:Connect(function(child)if child.Name=='TakeMysteryPack'then entry.Prompt=child;update(entry)end end)
 update(entry)
end
local function remove(model)
 local entry=entries[model];if not entry then return end;entries[model]=nil
 for _,c in ipairs(entry.Links)do c:Disconnect()end;if entry.Gui then entry.Gui:Destroy()end
end
for _,m in ipairs(CS:GetTagged('MysteryPedestal'))do task.spawn(add,m)end
local added=CS:GetInstanceAddedSignal('MysteryPedestal'):Connect(function(m)task.spawn(add,m)end)
local removed=CS:GetInstanceRemovedSignal('MysteryPedestal'):Connect(remove)
-- The countdowns tick twice a second.
local alive=true
local function tick()
 if not alive then return end
 for _,entry in pairs(entries)do if entry.State=='Locked'or entry.State=='Claimed'then update(entry)end end
 task.delay(.5,tick)
end
task.delay(.5,tick)
-- The pack turns slowly and bobs, for pedestals near the camera.
local spin=Run.RenderStepped:Connect(function()
 if GuiService.ReducedMotionEnabled then return end
 local cam=workspace.CurrentCamera;local at=cam and cam.CFrame.Position;if not at then return end
 local t=os.clock()
 for _,entry in pairs(entries)do
  local holder=entry.Model:FindFirstChild('MysteryPack');local pack=holder and holder:FindFirstChildWhichIsA('Model')
  local origin=pack and pack:GetAttribute('MysteryOrigin')
  if origin and(origin.Position-at).Magnitude<130 then
   pack:PivotTo(origin*CFrame.new(0,math.sin(t*1.6)*.35,0)*CFrame.Angles(0,t*.8%(math.pi*2),0))
  end
 end
end)
script.Destroying:Connect(function()alive=false;spin:Disconnect();added:Disconnect();removed:Disconnect();for m in pairs(entries)do remove(m)end end)
