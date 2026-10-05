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
-- R148 (owner: "the bar is on top of the pack and it enlarges and obscures everything when far away"): the label is a
-- sign in the world, not a fixed pixel size. Its Size is in studs, so it shrinks with distance (it can never cover the
-- screen from far away) and stops growing up close (DistanceLowerLimit); it shows up to 90 studs away, 120 over your own
-- pedestal. It hangs clearly ABOVE the pack: its bottom edge sits a gap over the top of the pack at its highest bob,
-- measured from the pack's own parts (a bigger pack lifts it), so nothing of it overlaps the spinning pack.
-- R150 (owner: "polish the pack pedestal that players have in base"): the sign is a friendlier pill (same size, place and ranges): a small caption,
-- a big state line and the bar, tinted by state (calm violet while Locked, gold when Ready, a quiet mint once Taken). Around the pedestal this adds,
-- for the pedestals near the camera only (MysteryPedestalFx): a halo of tumbling gems, wisps / sparkles, a padlock while Locked and a light shaft over
-- your own unlocked pack; the unlock moment (the padlock pops open and drops, a ring + flash + sparks, the pack hops, the sign pops, a chime) happens once,
-- for your own pedestal, and taking it makes the pack lift off and fly to you with a pop. Nothing runs for a pedestal that is far, streamed out, empty or
-- off screen: the one per-frame function is connected only while some pedestal is near. Low quality: no fx. Reduced motion: the same parts, standing
-- still, no particles, no flight, no hop or pop. Gameplay is untouched.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer
local M=require(RS:WaitForChild('MysteryPackRules'));local D=require(RS:WaitForChild('DailyRewards'))
local Fx;pcall(function()Fx=require(RS:WaitForChild('MysteryPedestalFx',10))end) -- (the pedestal is only plainer without it)
local Audio;pcall(function()Audio=require(RS.InteractionAudio)end)
local ClientFx;pcall(function()ClientFx=require(RS.ClientFxBudget)end)
local RGB=Color3.fromRGB
local VIOLET,GOLD,MINT=RGB(190,140,255),RGB(255,214,90),RGB(120,236,110)
local entries={}
local LABEL_W,LABEL_H=10,3.6 -- studs: reads at about 20-40 studs, about 1/12 of the screen height at 40 studs
local NEAR=18 -- (studs) closer than this the label stops growing
local FAR,FAR_MINE=90,120 -- how far away it shows
local BOB=.35 -- the pack's bob (the spin below)
local GAP=.9 -- clear space between the pack's top at its highest bob and the label's bottom edge
local DEFAULT_TOP=3.2 -- the pack's top above its centre when there is no pack to measure (about the biggest the packs get)
local ACTIVE_IN,ACTIVE_OUT=75,100 -- a pedestal this close to the camera (leaving at 100) spins its pack and wears the fx; none beyond
local TEXT_RANGE=150 -- the countdown text is only kept up to date this close (the sign itself shows up to 120)
-- Look of the sign per state: pill colour, outline, caption colour, how see-through the pill is.
local LOOK={
 Locked={Pill=RGB(30,22,58),Stroke=RGB(150,112,236),Caption=VIOLET,Alpha=.2},
 Ready={Pill=RGB(58,40,10),Stroke=GOLD,Caption=GOLD,Alpha=.12},
 Claimed={Pill=RGB(14,36,30),Stroke=RGB(72,160,108),Caption=MINT,Alpha=.38},
}
local function now()return workspace:GetServerTimeNow()end
local tierNow=3 -- the quality tier, read again every half second (and when something happens in front of you)
local function label(parent,name,y,h,color)
 local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Position=UDim2.fromScale(.06,y);t.Size=UDim2.fromScale(.88,h);t.ZIndex=2
 t.Font=Enum.Font.FredokaOne;t.TextScaled=true;t.TextColor3=color or Color3.new(1,1,1);t.TextStrokeTransparency=.2;t.TextStrokeColor3=RGB(10,8,22);t.Text='';t.Parent=parent
 return t
end
local function build(model)
 local gui=Instance.new('BillboardGui');gui.Name='MysteryLabel';gui.Size=UDim2.fromScale(LABEL_W,LABEL_H);gui.StudsOffsetWorldSpace=Vector3.new(0,DEFAULT_TOP+BOB+GAP+LABEL_H/2,0)
 gui.DistanceLowerLimit=NEAR;gui.MaxDistance=FAR;gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.ResetOnSpawn=false;gui.Enabled=false
 -- the pill behind the text: rounded, a soft top-to-bottom shade, an outline in the state's colour
 local pill=Instance.new('Frame');pill.Name='Pill';pill.Size=UDim2.fromScale(1,1);pill.BackgroundColor3=LOOK.Locked.Pill;pill.BackgroundTransparency=.2;pill.BorderSizePixel=0;pill.ZIndex=1;pill.Parent=gui
 local pc=Instance.new('UICorner');pc.CornerRadius=UDim.new(.42,0);pc.Parent=pill
 local ps=Instance.new('UIStroke');ps.Name='Outline';ps.Color=LOOK.Locked.Stroke;ps.Thickness=3;ps.Parent=pill
 local pg=Instance.new('UIGradient');pg.Color=ColorSequence.new(Color3.new(1,1,1),RGB(170,170,185));pg.Rotation=90;pg.Parent=pill
 local title=label(gui,'Title',.07,.27,VIOLET)
 local status=label(gui,'Status',.34,.42)
 local bar=Instance.new('Frame');bar.Name='Bar';bar.AnchorPoint=Vector2.new(.5,0);bar.Position=UDim2.fromScale(.5,.8);bar.Size=UDim2.fromScale(.72,.11)
 bar.BackgroundColor3=RGB(24,20,44);bar.BorderSizePixel=0;bar.ZIndex=2;bar.Parent=gui
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(1,0);c.Parent=bar
 local edge=Instance.new('UIStroke');edge.Color=RGB(10,8,22);edge.Thickness=2;edge.Parent=bar
 local fill=Instance.new('Frame');fill.Name='Fill';fill.BackgroundColor3=VIOLET;fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(0,1);fill.ZIndex=3;fill.Parent=bar
 local fc=Instance.new('UICorner');fc.CornerRadius=UDim.new(1,0);fc.Parent=fill
 gui.Parent=model
 return gui
end
-- The sign's colours for a state (and whether it is yours: someone else's pill is quieter).
local function dress(gui,state,mine)
 local look=LOOK[state];if not look then return end
 local pill=gui.Pill;pill.BackgroundColor3=look.Pill;pill.BackgroundTransparency=look.Alpha+(mine and 0 or .12)
 pill.Outline.Color=look.Stroke;pill.Outline.Transparency=mine and 0 or .35
end
-- The sign pops in (a quick overshoot) when the pedestal's state changes in front of you. Reduced motion: no pop.
local function pop(gui)
 if GuiService.ReducedMotionEnabled then return end
 gui.Size=UDim2.fromScale(LABEL_W*.8,LABEL_H*.8)
 Tween:Create(gui,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromScale(LABEL_W,LABEL_H)}):Play()
end
-- Quality: ClientFxBudget's tier (1 = low .. 3), capped by the player's graphics level exactly like the garden's growth effects (PlantGrowthFx.Tier).
local function quality()
 local tier=3
 if ClientFx then local ok,t=pcall(ClientFx.Get);if ok and type(t)=='number'then tier=t end end
 local ok,level=pcall(function()return UserSettings():GetService('UserGameSettings').SavedQualityLevel.Value end)
 if ok and type(level)=='number'and level>=1 then if level<=3 then tier=1 elseif level<=6 then tier=math.min(tier,2)end end
 return math.clamp(tier,1,3)
end
local function readTier()tierNow=quality();return tierNow end
-- A burst of light and sparks around the pack (when yours unlocks, and smaller when you take it).
local function burst(anchor,color,big)
 if not anchor or not anchor.Parent or not Fx then return end
 Fx.Burst(anchor,color,big,GuiService.ReducedMotionEnabled)
end
-- The pack pickup cue (what the game plays whenever something comes to you: a stolen pack, a harvested fruit): Bubble06. Played only when the server
-- has confirmed the take (the pedestal turned Claimed): a refused take (not yours, not unlocked, a full Bag) changes nothing here and makes no sound.
local function pickup()if Audio then pcall(Audio.Play,'Bubble06')end end
-- Only the owner sees the Take prompt, and only while the pack is Ready (the server's value is overridden here).
local function applyPrompt(entry)
 local prompt=entry.Prompt;if not prompt then return end
 local m=entry.Model;local want=m:GetAttribute('OwnerUserId')==player.UserId and(m:GetAttribute('State')or'Empty')=='Ready'
 if prompt.Enabled~=want then prompt.Enabled=want end
end
-- Hangs the label above the pack: studs from the pack's centre to the top of its parts (its root stays at the centre however
-- it bobs and turns), or a default when the pack is not there (taken / still arriving).
local function packTop(pack)
 local root=pack.PrimaryPart;local origin=pack:GetAttribute('MysteryOrigin')
 local ref=root and root.Position.Y or origin and origin.Position.Y
 local ok,box,size=pcall(pack.GetBoundingBox,pack)
 if ok and ref and size.Y>0 then return math.max(0,box.Position.Y+size.Y/2-ref)end
end
-- The pack on the pedestal (cached; looked up again when the pack is replaced).
local function packOf(entry)
 local pack=entry.Pack;if pack and pack.Parent then return pack end
 local holder=entry.Model:FindFirstChild('MysteryPack');pack=holder and holder:FindFirstChildWhichIsA('Model');entry.Pack=pack;return pack
end
local function place(entry)
 local pack=packOf(entry)
 local top=pack and packTop(pack)or DEFAULT_TOP
 local y=top+BOB+GAP+LABEL_H/2
 local at=entry.Gui.StudsOffsetWorldSpace;if at.Y~=y then entry.Gui.StudsOffsetWorldSpace=Vector3.new(0,y,0)end
end
-- The loop and the moving things ---------------------------------------------------------------------------------------
local loop;local flights={};local flightFolder
local failures,fxOff=0,false -- the fx are cosmetic: after 3 errors they switch themselves off (the sign, the prompt and the pack's spin go on)
local frame
local function wake()if not loop then loop=Run.RenderStepped:Connect(function()frame()end)end end
local function measure(entry)
 local cam=workspace.CurrentCamera;local anchor=entry.Anchor
 entry.Dist=(cam and anchor)and(cam.CFrame.Position-anchor.Position).Magnitude or math.huge
 return entry.Dist
end
-- Is the pedestal (a ~7 stud thing) inside the camera's view? Cheap: an angle against the view's half width / height.
local function onScreen(cam,entry)
 local at=entry.Anchor.Position;local d=at-cam.CFrame.Position;local dist=d.Magnitude
 if dist<22 then return true end
 local cos=d:Dot(cam.CFrame.LookVector)/dist
 local fov=math.rad(cam.FieldOfView or 70);local view=cam.ViewportSize;local aspect=view and view.Y>0 and view.X/view.Y or 16/9
 local half=math.atan(math.tan(fov/2)*math.max(aspect,1))+math.atan(8/dist)
 return cos>=math.cos(math.min(half,math.pi-.01))
end
local function ghostFolder()
 if flightFolder and flightFolder.Parent then return flightFolder end
 flightFolder=Instance.new('Folder');flightFolder.Name='MysteryPackFlights';flightFolder.Parent=workspace;return flightFolder
end
local function endFlight(fl,landed)
 if fl.Model then fl.Model:Destroy()end
 if landed and fl.Mine then pickup()end
 if landed and fl.Root and fl.Root.Parent and Fx then Fx.Pop(fl.Root.Position+Vector3.new(0,Fx.Tuning.AimUp,0),MINT,GuiService.ReducedMotionEnabled)end
end
-- The pack lifts off the pedestal and flies to the player who took it. `model` is a copy of the pack.
local function takeOff(entry,model,from)
 local ownerId=entry.Model:GetAttribute('OwnerUserId')
 local owner=ownerId==player.UserId and player or(type(ownerId)=='number'and Players.GetPlayerByUserId and Players:GetPlayerByUserId(ownerId))
 local character=owner and owner.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 if not root or not humanoid or humanoid.Health<=0 or #flights>=3 then model:Destroy();return false end
 model.Parent=ghostFolder()
 local fl=Fx.NewFlight(model,from,root,os.clock());fl.Mine=owner==player;fl.Humanoid=humanoid
 flights[#flights+1]=fl;wake();return true
end
-- The pack (or its snapshot) the take flight starts from: the live pack when it is still there, otherwise the copy kept while it was Ready.
local function takePack(entry)
 local pack=packOf(entry)
 local template=entry.Template;entry.Template=nil
 if pack then
  if template then template:Destroy()end
  local ok,copy=pcall(pack.Clone,pack);if ok and copy then return copy,pack:GetPivot()end
  return nil
 end
 if template then return template,entry.LastPivot or entry.Anchor and entry.Anchor.CFrame end
 return nil
end
local function dropTemplate(entry)if entry.Template then entry.Template:Destroy();entry.Template=nil end end
local function fxFailed(err)
 failures+=1;warn('[R150] Mystery pedestal fx: '..tostring(err))
 if failures>=3 and not fxOff then
  fxOff=true
  for _,entry in pairs(entries)do dropTemplate(entry);if entry.Fx then pcall(Fx.Destroy,entry.Fx);entry.Fx=nil end end
 end
end
function frame()
 local cam=workspace.CurrentCamera;local busy=false
 local reduced=GuiService.ReducedMotionEnabled;local t=os.clock()
 if cam then for _,entry in pairs(entries)do if entry.Active and entry.Anchor then
  busy=true
  if not reduced and entry.Anchor.Parent and measure(entry)<=ACTIVE_OUT and onScreen(cam,entry)then
   local pack=packOf(entry)
   if pack then
    local origin=pack:GetAttribute('MysteryOrigin')
    if origin then
     local hop=Fx and Fx.Hop(entry.HopAt and t-entry.HopAt or -1)or 0
     local at=origin*CFrame.new(0,math.sin(t*1.6)*BOB+hop,0)*CFrame.Angles(0,t*.8%(math.pi*2),0)
     pack:PivotTo(at);entry.LastPivot=at
    end
   end
   if entry.Fx then local ok,err=pcall(Fx.Step,entry.Fx,t);if not ok then fxFailed(err)end end
  end
 end end end
 for i=#flights,1,-1 do
  local fl=flights[i];local root=fl.Root
  if not fl.Model.Parent or not root.Parent or fl.Humanoid.Health<=0 then table.remove(flights,i);endFlight(fl,false)
  else
   local ok,landed=pcall(Fx.StepFlight,fl,t)
   if not ok then table.remove(flights,i);fxFailed(landed);endFlight(fl,false)
   elseif landed then table.remove(flights,i);endFlight(fl,true)
   else busy=true end
  end
 end
 if #flights>0 then busy=true end
 if not busy and loop then loop:Disconnect();loop=nil end
end
-- What each pedestal needs, for where the camera is and what the pedestal says: whether it spins its pack (Active) and wears the fx.
-- Called whenever either changes (a state change, the half-second tick).
local function refreshFx(entry,active,tier)
 local m=entry.Model;local state=entry.State or'Empty'
 local still=GuiService.ReducedMotionEnabled
 local want=active and Fx~=nil and tier>=2 and not fxOff
 if entry.Fx and(not want or entry.FxStill~=still or not entry.Fx.Folder or not entry.Fx.Folder.Parent)then Fx.Destroy(entry.Fx);entry.Fx=nil end
 if want and not entry.Fx and entry.Anchor then
  entry.Fx=Fx.Build(m,entry.Anchor.CFrame,still);entry.FxStill=still
 end
 if entry.Fx then Fx.SetState(entry.Fx,state,m:GetAttribute('OwnerUserId')==player.UserId)end
 -- a copy of the pack to fly (the server removes the real one when it is taken): kept only while it is Ready and the flight could play
 if state=='Ready'and want and not still then
  local pack=packOf(entry)
  if pack and entry.TemplateOf~=pack then dropTemplate(entry);local ok,copy=pcall(pack.Clone,pack);if ok then entry.Template=copy;entry.TemplateOf=pack end end
 else dropTemplate(entry);entry.TemplateOf=nil end
end
local function refresh(entry,tier)
 local state=entry.State or'Empty'
 measure(entry)
 local live=state=='Locked'or state=='Ready'
 local range=entry.Active and ACTIVE_OUT or ACTIVE_IN
 local active=live and entry.Anchor~=nil and entry.Dist<=range
 if active and not entry.Active then wake()end
 entry.Active=active
 local ok,err=pcall(refreshFx,entry,active,tier or tierNow)
 if not ok then fxFailed(err)end
end
-- The moments (before -> state, live in front of this client): the unlock (Locked / Empty -> Ready) and the take (Ready -> Claimed).
local function moments(entry,before,state,mine,tier)
 local gui=entry.Gui
 if state=='Ready'then
  if entry.Fx and Fx then Fx.OpenLock(entry.Fx,os.clock())end -- (the padlock pops open and drops, for whoever is looking)
  if mine and Fx then burst(entry.Anchor,GOLD,true);Fx.PlayUnlock()end -- (the ring, the flash and the chime start in the same call)
  entry.HopAt=os.clock() -- (the pack hops for everyone who is looking)
  if entry.Dist<=ACTIVE_IN then pop(gui)end
 end
 if before=='Ready'and state=='Claimed'then
  local flown=false
  local capable=Fx and entry.Anchor and tier>=2 and not fxOff and not GuiService.ReducedMotionEnabled and entry.Dist<=ACTIVE_IN
  if capable then
   local model,from=takePack(entry)
   if model and from then flown=takeOff(entry,model,from)elseif model then model:Destroy()end
  end
  if mine then
   burst(entry.Anchor,MINT,false)
   if flown then Fx.PlayLift()else pickup()end -- (a whoosh as it lifts off; the pickup cue when it reaches you, or at once when it does not fly)
  end
  if entry.Dist<=ACTIVE_IN then pop(gui)end
 end
end
local function update(entry)
 local m=entry.Model;local state=m:GetAttribute('State')or'Empty';local mine=m:GetAttribute('OwnerUserId')==player.UserId
 local gui=entry.Gui;gui.Enabled=state~='Empty';gui.MaxDistance=mine and FAR_MINE or FAR
 applyPrompt(entry);if state~='Empty'then place(entry)end
 if state=='Empty'then entry.State=state;refresh(entry);return end
 local owner=mine and'YOUR'or(tostring(m:GetAttribute('OwnerName')or'?'):upper().."'S")
 local bar,fill=gui.Bar,gui.Bar.Fill
 dress(gui,state,mine)
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
 local before=entry.State
 entry.State=state
 -- the moments: only when the state really changes in front of this client (never for a pedestal that was already like this when it was found)
 local changed=before~=nil and before~=state
 local tier=changed and readTier()or nil
 measure(entry)
 if changed then
  local ok,err=pcall(moments,entry,before,state,mine,tier)
  if not ok then fxFailed(err)end
 end
 refresh(entry,tier)
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
 for _,c in ipairs(entry.Links)do c:Disconnect()end;unlinkPrompt(entry);dropTemplate(entry)
 if entry.Fx and Fx then Fx.Destroy(entry.Fx);entry.Fx=nil end
 if entry.Gui then entry.Gui:Destroy()end
end
local function add(model)
 if entries[model]or not model:IsA('Model')then return end
 local entry={Model=model,Links={}};entry.Gui=build(model);entries[model]=entry
 for _,key in ipairs({'State','OwnerUserId','OwnerName','UnlockAt','NextAt'})do
  entry.Links[#entry.Links+1]=model:GetAttributeChangedSignal(key):Connect(function()update(entry)end)
 end
 entry.Links[#entry.Links+1]=model.DescendantAdded:Connect(function(d)
  if d.Name=='PackAnchor'or d.Name=='TakeMysteryPack'then relink(entry)elseif d.Name=='SeedPacket'then entry.Pack=nil end
 end)
 entry.Links[#entry.Links+1]=model.DescendantRemoving:Connect(function(d)
  if d==entry.Anchor then entry.Anchor=nil;entry.Gui.Adornee=nil;unlinkPrompt(entry)elseif d==entry.Prompt then unlinkPrompt(entry)end
 end)
 entry.Links[#entry.Links+1]=model.AncestryChanged:Connect(function()if not model:IsDescendantOf(workspace)then remove(model)end end)
 relink(entry)
end
readTier()
for _,m in ipairs(CS:GetTagged('MysteryPedestal'))do add(m)end
local added=CS:GetInstanceAddedSignal('MysteryPedestal'):Connect(add)
local removed=CS:GetInstanceRemovedSignal('MysteryPedestal'):Connect(remove)
-- Twice a second: the countdowns, and which pedestals are near enough to wear their fx (and which are not any more).
local alive=true
local function tick()
 if not alive then return end
 local tier=readTier()
 for model,entry in pairs(entries)do
  if not model.Parent then remove(model) -- (streamed out without a tag signal: its streamed-back copy is a new instance)
  else
   local state=entry.State;local updated=false
   if measure(entry)<=TEXT_RANGE or not entry.Anchor then
    if state=='Locked'or state=='Claimed'then update(entry);updated=true
    elseif state=='Ready'then place(entry)end -- (a pack that arrived or changed: keep the label above it)
   end
   if not updated then refresh(entry,tier)end
  end
 end
 task.delay(.5,tick)
end
task.delay(.5,tick)
script.Destroying:Connect(function()
 alive=false;if loop then loop:Disconnect();loop=nil end
 added:Disconnect();removed:Disconnect();for m in pairs(entries)do remove(m)end
 for _,fl in ipairs(flights)do if fl.Model then fl.Model:Destroy()end end;table.clear(flights);if flightFolder then flightFolder:Destroy()end
end)
