-- R141 (owner: "a pedestal with a mystery pack ... black silhouette ... after 15 minutes of staying in the game they
-- unlock the pack, refreshes every day"): the label over every base's mystery pedestal (whose it is, 🔒 time left with a
-- bar, ✨ UNLOCKED / TAKE IT, ✓ taken and the time to the next one), the take prompt (only its owner sees it, only once
-- unlocked), a burst when yours unlocks and a slow spin on the pack. The server (MysteryPackService) owns everything
-- else; this reads the pedestal's attributes.
-- The place uses StreamingEnabled: the pedestals are Persistent models, but nothing here counts on that. A pedestal is
-- found by its tag whenever it appears (no waiting for its parts: PackAnchor and the prompt are linked as they arrive,
-- and again if they come back as new instances), and a pedestal that goes away is forgotten, so a streamed-back copy
-- starts clean. The server enables the Take prompt only while the pack is Ready; this switches it off for everyone but
-- the owner, again after any change the server makes to it.
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
local function build(model)
 local gui=Instance.new('BillboardGui');gui.Name='MysteryLabel';gui.Size=UDim2.fromOffset(230,96);gui.StudsOffset=Vector3.new(0,4.3,0)
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
-- Only the owner sees the Take prompt, and only while the pack is Ready (the server's value is overridden here).
local function applyPrompt(entry)
 local prompt=entry.Prompt;if not prompt then return end
 local m=entry.Model;local want=m:GetAttribute('OwnerUserId')==player.UserId and(m:GetAttribute('State')or'Empty')=='Ready'
 if prompt.Enabled~=want then prompt.Enabled=want end
end
local function update(entry)
 local m=entry.Model;local state=m:GetAttribute('State')or'Empty';local mine=m:GetAttribute('OwnerUserId')==player.UserId
 local gui=entry.Gui;gui.Enabled=state~='Empty'
 applyPrompt(entry)
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
local function unlinkPrompt(entry)
 if entry.PromptLink then entry.PromptLink:Disconnect();entry.PromptLink=nil end
 entry.Prompt=nil
end
-- (Re)finds the anchor and the prompt in the model: they can arrive late, or come back as new instances.
local function relink(entry)
 local anchor=entry.Model:FindFirstChild('PackAnchor');if anchor and not anchor:IsA('BasePart')then anchor=nil end
 if anchor~=entry.Anchor then entry.Anchor=anchor;entry.Gui.Adornee=anchor end
 local prompt=anchor and anchor:FindFirstChild('TakeMysteryPack')
 if prompt~=entry.Prompt then
  unlinkPrompt(entry);entry.Prompt=prompt
  if prompt then entry.PromptLink=prompt:GetPropertyChangedSignal('Enabled'):Connect(function()applyPrompt(entry)end)end
 end
 update(entry)
end
local function remove(model)
 local entry=entries[model];if not entry then return end;entries[model]=nil
 for _,c in ipairs(entry.Links)do c:Disconnect()end;unlinkPrompt(entry);if entry.Gui then entry.Gui:Destroy()end
end
local function add(model)
 if entries[model]or not model:IsA('Model')then return end
 local entry={Model=model,Links={}};entry.Gui=build(model);entries[model]=entry
 for _,key in ipairs({'State','OwnerUserId','OwnerName','UnlockAt','NextAt'})do
  entry.Links[#entry.Links+1]=model:GetAttributeChangedSignal(key):Connect(function()update(entry)end)
 end
 entry.Links[#entry.Links+1]=model.DescendantAdded:Connect(function(d)if d.Name=='PackAnchor'or d.Name=='TakeMysteryPack'then relink(entry)end end)
 entry.Links[#entry.Links+1]=model.DescendantRemoving:Connect(function(d)
  if d==entry.Anchor then entry.Anchor=nil;entry.Gui.Adornee=nil;unlinkPrompt(entry)elseif d==entry.Prompt then unlinkPrompt(entry)end
 end)
 entry.Links[#entry.Links+1]=model.AncestryChanged:Connect(function()if not model:IsDescendantOf(workspace)then remove(model)end end)
 relink(entry)
end
for _,m in ipairs(CS:GetTagged('MysteryPedestal'))do add(m)end
local added=CS:GetInstanceAddedSignal('MysteryPedestal'):Connect(add)
local removed=CS:GetInstanceRemovedSignal('MysteryPedestal'):Connect(remove)
-- The countdowns tick twice a second.
local alive=true
local function tick()
 if not alive then return end
 for model,entry in pairs(entries)do
  if not model.Parent then remove(model) -- (streamed out without a tag signal: its streamed-back copy is a new instance)
  elseif entry.State=='Locked'or entry.State=='Claimed'then update(entry)end
 end
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
