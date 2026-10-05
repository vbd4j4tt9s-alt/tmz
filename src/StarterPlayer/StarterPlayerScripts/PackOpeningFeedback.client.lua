-- R37 local presentation. Click counts and the seed award are owned by ChestService.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Collection=game:GetService('CollectionService')
local GuiService=game:GetService('GuiService')
local Rules=require(RS:WaitForChild('SeedPackRules'))
local Audio=require(RS:WaitForChild('InteractionAudio'))
local player=Players.LocalPlayer
local pg=player:WaitForChild('PlayerGui')
local gui=Instance.new('ScreenGui');gui.Name='PackOpeningEffects';gui.IgnoreGuiInset=true;gui.ClipToDeviceSafeArea=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ScreenInsets=Enum.ScreenInsets.None;gui.ResetOnSpawn=false;gui.DisplayOrder=65;gui.Parent=pg
local function frame(name,parent,color,position,size,angle)
 local f=Instance.new('Frame');f.Name=name;f.AnchorPoint=Vector2.new(.5,.5);f.Position=position;f.Size=size
 f.BackgroundColor3=color;f.BorderSizePixel=0;f.Rotation=angle or 0;f.Parent=parent;return f
end
local sequence=require(RS.RarityRevealScreen).Create(gui);local revealAudio=require(RS.RarityRevealAudio);revealAudio.Preload()
local white=Color3.fromRGB(245,247,255)
local panel=frame('Cover',gui,Color3.fromRGB(9,9,18),UDim2.fromScale(.5,.5),UDim2.fromScale(1.06,1.06));panel.Visible=false;panel.ZIndex=1
local canvas=frame('Effects',gui,white,UDim2.fromScale(.5,.5),UDim2.fromScale(1,1));canvas.BackgroundTransparency=1;canvas.ZIndex=2
local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=1;aspect.DominantAxis=Enum.DominantAxis.Height;aspect.Parent=canvas
local ring=frame('Halo',canvas,white,UDim2.fromScale(.5,.5),UDim2.fromScale(.38,.38));ring.BackgroundTransparency=1;ring.Visible=false
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(1,0);corner.Parent=ring
local stroke=Instance.new('UIStroke');stroke.Thickness=3;stroke.Color=white;stroke.Parent=ring
local burst=frame('Opening burst',canvas,white,UDim2.fromScale(.5,.5),UDim2.fromScale(.08,.08));burst.BackgroundTransparency=1;burst.Visible=false
 local burstCorner=Instance.new('UICorner');burstCorner.CornerRadius=UDim.new(1,0);burstCorner.Parent=burst
 local burstStroke=Instance.new('UIStroke');burstStroke.Thickness=3;burstStroke.Color=white;burstStroke.Parent=burst
 local nodes={}
for i=1,24 do
 local n=frame('Rarity light '..i,canvas,white,UDim2.fromScale(.5,.5),UDim2.fromScale(.007,.007),45);n.Visible=false;nodes[i]=n
end
local crown=frame('Crown',canvas,Color3.fromRGB(255,217,111),UDim2.fromScale(.5,.48),UDim2.fromScale(.20,.05));crown.Visible=false
local crownParts={crown}
for i=1,5 do
 local p=frame('Crown point '..i,canvas,crown.BackgroundColor3,UDim2.fromScale(.40+i*.033,.435),UDim2.fromScale(.042,.082),i==1 and -18 or i==5 and 18 or 0)
 p.Visible=false;table.insert(crownParts,p)
end
local active,copy,originals,reveal,shake=nil,nil,{},nil,nil
local count=0;local pulseAt=-math.huge;local pulseStrength=0;local lastInput=-math.huge;local watched={};local connections={}
local lastCamera,lastOffset,lastWritten
local function reduced()
 local okay,value=pcall(function()return GuiService.ReducedMotionEnabled end)
 return okay and value==true
end
local function resetCamera()
 if lastCamera and lastCamera==workspace.CurrentCamera and lastOffset and lastCamera.CFrame==lastWritten then
  lastCamera.CFrame=lastCamera.CFrame*lastOffset:Inverse()
 end
 lastCamera,lastOffset,lastWritten=nil,nil,nil
end
local function kick(strength)
 if not reduced()then shake={At=os.clock(),Strength=strength}end
end
local function clearCopy(restore)
 if copy then copy:Destroy();copy=nil end
 if restore then for p,value in pairs(originals)do if p.Parent then p.LocalTransparencyModifier=value end end end
 table.clear(originals)
end
local function hideEffects()
 sequence:Hide()
 panel.Visible=false;ring.Visible=false;burst.Visible=false
 for _,p in ipairs(nodes)do p.Visible=false end
 for _,p in ipairs(crownParts)do p.Visible=false end
end
local function clear()
 revealAudio.Stop()
 clearCopy(active and not active:GetAttribute('RevealAt'));active=nil;count=0;reveal=nil;shake=nil;hideEffects();resetCamera()
end
local function cloneBag(bag)
 if copy or not bag.PrimaryPart then return end
 copy=bag:Clone();copy.Name='_LocalClickingPack'
 for _,tag in ipairs(Collection:GetTags(copy))do Collection:RemoveTag(copy,tag)end
 for _,p in ipairs(copy:GetDescendants())do
  if p:IsA('WeldConstraint')or p:IsA('JointInstance')or p:IsA('Script')or p:IsA('LocalScript')then p:Destroy()
  elseif p:IsA('BasePart')then
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
   -- Keep the proxy hidden when the native art is present.
   p.LocalTransparencyModifier=p:GetAttribute('PackProxy')and bag:GetAttribute('NativePackArtReady')and 1 or 0
  end
 end
 copy.Parent=workspace
 for _,p in ipairs(bag:GetDescendants())do if p:IsA('BasePart')or p:IsA('Decal')then originals[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1 end end -- R147: a Decal (the Verity picture) too
end
local function pulse()
 if not active or active:GetAttribute('RevealAt')then return end
 pulseAt=os.clock();pulseStrength=.13+count*.025
 -- R150: every click the server rules accept (one per Rules.ClickInterval) sounds: the cue's own 0.09 s gap used to swallow 2 of 5 at full
 -- tapping speed while the bag still shook. The gap here is a little under the click interval, so rapid input never stacks beyond the accepted rate.
 cloneBag(active);kick(.85+count*.16);Audio.Play('Bubble04',Rules.ClickInterval*.8)
end
local function beginReveal(bag)
 if reveal or not bag:GetAttribute('RevealSeedId')then return end
 clearCopy(false)
 local _,rarity=Rules.GetRarity(bag:GetAttribute('RevealSeedId'))
 local at=bag:GetAttribute('RevealAt');if not at then return end
 reveal={At=at,Rank=rarity.Rank,Color=rarity.Color};revealAudio.Begin(rarity.Rank,workspace:GetServerTimeNow()-at)
 kick(rarity.Rank>=6 and 2.1 or 1.65)
end
local function watchTool(tool)
 if not tool:IsA('Tool')or not tool:GetAttribute('SeedPackTool')or watched[tool]then return end
 local cs={};watched[tool]=cs
 table.insert(cs,tool.Activated:Connect(function()
  if not active or active.Parent~=player.Character or active:GetAttribute('RevealAt')or not tool.Enabled then return end
  local now=os.clock();if now-lastInput<Rules.ClickInterval then return end;lastInput=now
  count=math.min(Rules.OpenClicks,count+1);pulse()
 end))
 table.insert(cs,tool.Destroying:Connect(function()for _,c in ipairs(cs)do c:Disconnect()end;watched[tool]=nil end))
end
local characterConnection
local function character(char)
 clear()
 if characterConnection then characterConnection:Disconnect()end
 for _,child in ipairs(char:GetChildren())do watchTool(child)end
 characterConnection=char.ChildAdded:Connect(watchTool)
end
table.insert(connections,player.CharacterAdded:Connect(character))
table.insert(connections,player.CharacterRemoving:Connect(clear))
if player.Character then character(player.Character)end
Run:BindToRenderStep('ChestChasePackCameraReset',Enum.RenderPriority.Camera.Value-1,resetCamera)
Run:BindToRenderStep('ChestChasePackPresentation',Enum.RenderPriority.Camera.Value+1,function()
 local char=player.Character;local bag=char and char:FindFirstChild('CarriedSeed')
 local tool=char and char:FindFirstChildOfClass('Tool')
 if bag and bag:GetAttribute('SeedPackCarry')and tool and tool:GetAttribute('SeedPackTool')then
  if active~=bag then clear();active=bag end
 elseif active then clear()end
 local now=os.clock()
 if active and active.PrimaryPart then
  local serverCount=active:GetAttribute('PackClickCount')or 0
  if serverCount>count then count=serverCount;pulse()end
  if active:GetAttribute('RevealAt')then beginReveal(active)end
  if copy and not reveal then
   local age=now-pulseAt;local envelope=math.exp(-age*15);local wave=math.cos(age*72)
   local intensity=reduced()and .22 or 1
   copy:PivotTo(active.PrimaryPart.CFrame*CFrame.new(wave*pulseStrength*envelope*intensity,math.sin(age*55)*pulseStrength*.8*envelope*intensity,pulseStrength*1.2*envelope*intensity)*CFrame.Angles(0,0,wave*.19*envelope*intensity))
  end
 end
 if reveal then
  local t=workspace:GetServerTimeNow()-reveal.At;local rank=reveal.Rank
  local sequenceState=sequence:Step(rank,t,reduced());revealAudio.Step(rank,t)
  if not reveal.Burst and t>=require(RS.RarityRevealSequence).SeedAt(rank)then reveal.Burst=true;revealAudio.Burst(rank,t);kick(rank==8 and 2.6 or rank==7 and 2 or 1.2)end
  local duration=rank>=6 and 0 or .7
  burst.Visible=rank<6 and t>=0 and t<.23
  if burst.Visible then local a=math.clamp(t/.23,0,1);burst.Size=UDim2.fromScale(.08+.38*a,.08+.38*a);burstStroke.Transparency=a;burstStroke.Color=reveal.Color end
  -- R136 (owner: polish Legendary / Mythic pulls): motes gather during their short charge-up, then the ring bursts
  -- out with a soft colour flash exactly when the seed does.
  local at=require(RS.RarityRevealSequence).SeedAt(rank)
  if rank==4 or rank==5 then
   local color=rank==5 and Color3.fromRGB(235,120,255)or Color3.fromRGB(255,213,100)
   local n=rank==5 and 16 or 10
   if t<at then
    local q=math.clamp(t/at,0,1)
    ring.Visible=false;panel.Visible=false
    for i,p in ipairs(nodes)do
     p.Visible=i<=n
     if p.Visible then
      local angle=i*math.pi*2/n+t*(rank==5 and 2.2 or 1.6);local radius=.46-q*.32
      p.Position=UDim2.fromScale(.5+math.cos(angle)*radius,.5+math.sin(angle)*radius)
      p.Size=UDim2.fromScale(.01,.01);p.Rotation=45;p.BackgroundColor3=color;p.BackgroundTransparency=1-q*.85
     end
    end
   elseif t<at+.75 then
    local tb=t-at;local fade=math.clamp((tb-.15)/.6,0,1);local rise=1-(1-math.clamp(tb/.3,0,1))^3
    panel.Visible=not reduced()and tb<.3;panel.BackgroundColor3=color;panel.BackgroundTransparency=.72+math.clamp(tb/.3,0,1)*.28
    ring.Visible=true;ring.Size=UDim2.fromScale(.15+rise*.55,.15+rise*.55);stroke.Color=color;stroke.Transparency=fade;stroke.Thickness=rank==5 and 3 or 2
    for i,p in ipairs(nodes)do
     p.Visible=i<=n
     if p.Visible then
      local angle=i*math.pi*2/n;local radius=.14+rise*(rank==5 and .30 or .24)
      p.Position=UDim2.fromScale(.5+math.cos(angle)*radius,.5+math.sin(angle)*radius)
      p.Size=UDim2.fromScale(.009,.024);p.Rotation=angle*180/math.pi+90;p.BackgroundColor3=color;p.BackgroundTransparency=fade
     end
    end
   else ring.Visible=false;panel.Visible=false;for _,p in ipairs(nodes)do p.Visible=false end end
  else
   if t<duration then
    local fade=math.clamp((t-(rank>=6 and .5 or .15))/(duration-(rank>=6 and .5 or .15)),0,1)
    local rise=1-(1-math.clamp(t/.3,0,1))^3
    -- Common to Rare use the world seed reveal. No screen-cover treatment.
    -- R138 (owner: "very little minor animations" for Common / Uncommon / Rare): a few tiny sparkles pop out in the
    -- tier colour when the seed does (4 / 6 / 8), plus a faint second ring for Rare. Skipped with reduced motion.
    if rank<=3 then
     local tb=t-at;local life=.45
     local show=tb>=0 and tb<life and not reduced()
     local k=math.clamp(tb/life,0,1);local pop=1-(1-k)^3;local n=rank==3 and 8 or rank==2 and 6 or 4
     ring.Visible=show and rank==3
     if ring.Visible then ring.Size=UDim2.fromScale(.1+pop*.22,.1+pop*.22);stroke.Color=reveal.Color;stroke.Transparency=.35+k*.65;stroke.Thickness=2 end
     for i,p in ipairs(nodes)do
      p.Visible=show and i<=n
      if p.Visible then
       local angle=i*math.pi*2/n+.4;local radius=.05+pop*(.06+rank*.025);local size=.006+rank*.0015
       p.Position=UDim2.fromScale(.5+math.cos(angle)*radius,.5+math.sin(angle)*radius)
       p.Size=UDim2.fromScale(size,size);p.Rotation=45+tb*160;p.BackgroundColor3=reveal.Color;p.BackgroundTransparency=k
      end
     end
    end
    if rank>=4 then
     panel.Visible=rank>=6
     panel.BackgroundColor3=rank==6 and Color3.fromRGB(7,7,10)or rank==7 and Color3.fromRGB(12,8,33)or Color3.fromRGB(40,25,5)
     panel.BackgroundTransparency=fade
     local color=rank==6 and white or rank==7 and Color3.fromRGB(180,159,255)or rank==5 and Color3.fromRGB(255,85,102)or Color3.fromRGB(255,213,100)
     ring.Visible=true;ring.Size=UDim2.fromScale(.15+rise*.49,.15+rise*.49);stroke.Color=color;stroke.Transparency=fade;stroke.Thickness=rank>=6 and 4 or 2
     local n=rank>=6 and 24 or 10
     for i,p in ipairs(nodes)do
      p.Visible=i<=n
      if p.Visible then
       local angle=i*math.pi*2/n+(rank==7 and t*.45 or 0);local radius=.17+rise*(rank>=6 and .39 or .20)
       p.Position=UDim2.fromScale(.5+math.cos(angle)*radius,.5+math.sin(angle)*radius)
       p.BackgroundColor3=color;p.BackgroundTransparency=fade
       if rank==6 then p.Size=UDim2.fromScale(.006,.05+rise*.08);p.Rotation=angle*180/math.pi+90
       elseif rank==7 then p.Size=UDim2.fromScale(.008+(i%3)*.004,.008+(i%3)*.004);p.Rotation=45+t*50
       elseif rank==8 then p.Size=UDim2.fromScale(.007,.10+rise*.10);p.Rotation=angle*180/math.pi+90
       else p.Size=UDim2.fromScale(.008,.018);p.Rotation=45+t*40 end
      end
     end
     for _,p in ipairs(crownParts)do p.Visible=rank==8;p.BackgroundTransparency=fade end
    end
   elseif rank<6 then hideEffects()end
  end
 end
 if shake then
  local age=now-shake.At
  if age>.22 or reduced()then shake=nil
  else
   local camera=workspace.CurrentCamera
   if camera then
    local a=(1-age/.22)^2*shake.Strength
    local offset=CFrame.new(math.cos(age*96)*.028*a,math.sin(age*73)*.018*a,-.025*a)*CFrame.Angles(0,0,math.sin(age*83)*math.rad(.22)*a)
    lastCamera=camera;lastOffset=offset;camera.CFrame=camera.CFrame*offset;lastWritten=camera.CFrame
   end
  end
 end
end)
script.Destroying:Connect(function()
 Run:UnbindFromRenderStep('ChestChasePackCameraReset');Run:UnbindFromRenderStep('ChestChasePackPresentation')
 clear();if characterConnection then characterConnection:Disconnect()end
 for _,c in ipairs(connections)do c:Disconnect()end
 for _,cs in pairs(watched)do for _,c in ipairs(cs)do c:Disconnect()end end
 gui:Destroy()
end)
