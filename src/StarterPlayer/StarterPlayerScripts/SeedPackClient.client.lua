local TextFit=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTextFit'))
-- V119. Replicated bags drive cosmetic poses/reveals on every viewer.
-- The server alone chooses and commits rewards; this script cannot grant seeds.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local ContentProvider=game:GetService("ContentProvider")
local Debris=game:GetService("Debris")
local CollectionService=game:GetService("CollectionService")
local Rules=require(ReplicatedStorage:WaitForChild("SeedPackRules"))
local Visuals=require(ReplicatedStorage:WaitForChild("SeedPackVisuals"))
local Pose=require(ReplicatedStorage:WaitForChild("SeedCarryPose"))
local remotes=ReplicatedStorage:WaitForChild("ChestChaseRemotes",20)
if not remotes then return end
local library=remotes:WaitForChild("SeedArt",20)
local catalog=remotes:WaitForChild("SeedCatalog",20)
if not library or not catalog then return end
local records={}
local connections={}
local lastHeavenlyAt=-math.huge
local effects=Instance.new("Folder");effects.Name="_LocalSeedPackEffects";effects.Parent=workspace
local preload=Instance.new("Sound");preload.SoundId=Rules.TearSoundId;preload.Volume=0;preload.Parent=effects
local bellPreload=Instance.new("Sound");bellPreload.SoundId=Rules.RevealBellSoundId;bellPreload.Volume=0;bellPreload.Parent=effects
-- Audio loading never gates the inventory transaction or visual reveal.
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({preload,bellPreload}) end) end)
Debris:AddItem(preload,12)
Debris:AddItem(bellPreload,12)
local function destroyEffect(record)
    if record.CameraState then local saved=record.CameraState;record.CameraState=nil;local camera=workspace.CurrentCamera;if camera==saved.Camera then camera.CameraType=saved.Type;camera.CFrame=saved.Frame;camera.Focus=saved.Focus end end
    if record.SeedMotion then record.SeedMotion:Destroy();record.SeedMotion=nil end
    if record.Effect then record.Effect:Destroy();record.Effect=nil end
    for _,part in ipairs(record.Hidden or {}) do
        if part.Parent then
            part.LocalTransparencyModifier=(record.Bag and record.Bag:GetAttribute("RevealAt"))and 1 or (part:GetAttribute("PackProxy")and record.Bag and record.Bag:GetAttribute("NativePackArtReady")and 1 or 0)
        end
    end
    record.Hidden=nil
end
local function remove(player)
    local record=records[player]
    if record then record.Pose:Reset();destroyEffect(record);records[player]=nil end
end
local function cosmeticPart(name,parent,color,size)
    local p=Instance.new("Part");p.Name=name;p.Color=color;p.Size=size
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Material=Enum.Material.Neon;p.Transparency=1;p.Parent=parent;return p
end
local function beginReveal(record,at,seedId,now)
    local seeds=library:FindFirstChild("Seeds")
    local template=seeds and seeds:FindFirstChild(seedId)
    local definition=catalog:FindFirstChild(seedId)
    if not template or not definition or not record.Bag.PrimaryPart then return end
    local name,rarity=Rules.GetRarity(seedId)
    record.RarityRank=rarity.Rank;record.RarityName=name
    record.Duration=record.Bag:GetAttribute("RevealDuration") or Rules.GetRevealDuration(name)
    record.HeavenlySounds={};record.HeavenlyStarted=false;record.Celestial={}
    record.SeedVisible=nil;record.LastSeedScale=nil;record.SeedFullyGrown=nil;record.TearSound=nil
    local effect=Instance.new("Model");effect.Name="SeedReveal";effect.Parent=effects
    record.Effect=effect;record.At=at;record.Hidden={};record.SeedParts={};record.SeedEffects={}
    local copy=record.Bag:Clone();copy.Name="OpeningBag";copy:SetAttribute("RevealAt",nil)
    for _,item in ipairs(copy:GetDescendants())do
        if item:IsA("WeldConstraint") or item:IsA("Motor6D") then item:Destroy()
        elseif item:IsA("ParticleEmitter") or item:IsA("PointLight") then item.Enabled=false
        elseif item:IsA("BasePart") then item.Anchored=true;item.LocalTransparencyModifier=0 end
    end
    local orbit=copy:FindFirstChild("PackOrbitEffects");if orbit then orbit:Destroy()end
    -- Opening owns its transforms; don't let the world pack animator write to this copy.
    game:GetService("CollectionService"):RemoveTag(copy,"BiomeSeedPackVisual")
    copy.Parent=effect;record.Copy=copy
    record.FlapFrames={};record.BagTransparency={}
    local bagFrame=record.Bag.PrimaryPart.CFrame
    for _,p in ipairs(record.Bag:GetDescendants())do
        if p:IsA("BasePart") then p.LocalTransparencyModifier=1;table.insert(record.Hidden,p)end
    end
    for _,p in ipairs(copy:GetDescendants())do
        if p:IsA("BasePart") then record.FlapFrames[p]=bagFrame:ToObjectSpace(p.CFrame);record.BagTransparency[p]=p.Transparency end
    end
    local paper=record.Bag:GetAttribute("PaperColor")or Color3.fromRGB(192,148,94)
    record.Mouth=cosmeticPart("Opened paper mouth",effect,Color3.fromRGB(35,25,22),Vector3.new(1.7,.025,.03))
    record.Mouth.Material=Enum.Material.SmoothPlastic
    record.Lips={};record.Scraps={}
    for i=1,8 do
        local lip=cosmeticPart("Curling torn paper",effect,paper,Vector3.new(.24,.15,.06));lip.Material=Enum.Material.SmoothPlastic
        record.Lips[i]=lip
        local scrap=cosmeticPart("Paper scrap",effect,paper,Vector3.new(.07,.11,.02));scrap.Material=Enum.Material.SmoothPlastic
        record.Scraps[i]=scrap
    end
    local seed=template:Clone();seed.Name="RewardSeed"
    seed:SetAttribute("SeedMotionManaged",true);CollectionService:RemoveTag(seed,Rules.SeedMotion.Tag)
    require(ReplicatedStorage:WaitForChild("PlantVisuals")).Coat(seed,record.Bag:GetAttribute("PackMutation"))
    seed.Parent=effect;record.Seed=seed
    record.SeedScale=Rules.SanitizeSeedScale(record.Bag:GetAttribute("SeedScale"))
    record.SeedBaseScale=record.SeedScale -- Same authored scale used by the equipped seed.
    require(ReplicatedStorage.ItemEffectAnchor).Set(record.Seed,record.Bag:GetAttribute("Weather"),nil,record.SeedScale,record.SeedScale*2)
    seed:ScaleTo(record.SeedBaseScale)
    record.SeedRadius=record.SeedBaseScale*1.1
    local light=Instance.new("PointLight");light.Name="SeedRevealLight";light.Color=rarity.Color
    light.Brightness=rarity.Rank<3 and 1+rarity.Rank*.12 or 0;light.Range=math.min(20,7+record.SeedBaseScale*2);light.Shadows=false;light.Parent=seed.PrimaryPart
    local shine=Instance.new("Highlight");shine.Adornee=seed;shine.FillColor=rarity.Color;shine.OutlineColor=rarity.Color
    shine.FillTransparency=.85;shine.OutlineTransparency=rarity.Rank<3 and .3 or 1;shine.DepthMode=Enum.HighlightDepthMode.Occluded;shine.Parent=seed
    local label=Instance.new("BillboardGui");label.Size=UDim2.fromOffset(270,66)
    label.StudsOffsetWorldSpace=Vector3.new(0,math.max(1.6,(rarity.Rank==8 and 2.8 or 1.7)*record.SeedBaseScale),0)
    label.AlwaysOnTop=false;label.MaxDistance=65;label.Parent=seed.PrimaryPart
    local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
    TextFit.Attach(text,16,9)
    text.Text=(definition:GetAttribute("DisplayName")or "Seed").."\n"..require(ReplicatedStorage.NoticeCopy83).Rarity(name)
    text.TextXAlignment=Enum.TextXAlignment.Center;text.TextYAlignment=Enum.TextYAlignment.Center;
    text.Font=Enum.Font.FredokaOne;text.TextSize=18;text.TextColor3=rarity.Color;text.TextStrokeTransparency=.2;text.Parent=label
    for _,p in ipairs(seed:GetDescendants())do
        if p:IsA("BasePart")then table.insert(record.SeedParts,p);p.LocalTransparencyModifier=1
        elseif p:IsA("ParticleEmitter")or p:IsA("PointLight")or p:IsA("BillboardGui")or p:IsA("Highlight")then
            p.Enabled=false;table.insert(record.SeedEffects,p)
            if p:IsA("ParticleEmitter")then p:Clear()end
        end
    end
    -- Common/Uncommon retain their existing reveal. Rare+ share the held-seed effects.
    local count=rarity.Rank<3 and (rarity.Rank==1 and 4 or 8)or 0
    for i=1,count do record.Celestial[i]=cosmeticPart("Rarity light",effect,rarity.Color,Vector3.one*.08)end
    if rarity.Rank>=3 then record.SeedMotion=Visuals.CreateSeedMotion(seed,effect,true)end
    if now-at<Rules.TearSeconds then
        local sound=Instance.new("Sound");sound.Name="Paper bag tearing";sound.SoundId=Rules.TearSoundId
        sound.Volume=0;sound.Looped=false;sound.RollOffMinDistance=5;sound.RollOffMaxDistance=36;sound.Parent=copy.PrimaryPart
        sound.TimePosition=Rules.TearSoundStart+math.max(0,now-at-.12);sound:Play();record.TearSound=sound
    end
end
local function renderReveal(record,now)
    local bag=record.Bag;local t=now-record.At
    local s=bag:GetAttribute("VisualScale")or 1;local root=bag.PrimaryPart.CFrame
    local mouth=(bag:GetAttribute("TearLipY")or 1.11)*s
    if bag.Parent==Players.LocalPlayer.Character and math.max(s,record.SeedBaseScale)>10 then
     local camera=workspace.CurrentCamera
     if camera then
      if not record.CameraState then record.CameraState={Camera=camera,Type=camera.CameraType,Frame=camera.CFrame,Focus=camera.Focus}end
      local focus=root.Position+Vector3.new(0,mouth*.65,0);local radius=math.max(s*2.7,record.SeedBaseScale*3.2)
      local aspect=math.max(.25,camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y));local angle=math.atan(math.tan(math.rad(camera.FieldOfView/2))*math.min(1,aspect))
      camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=CFrame.lookAt(focus+Vector3.new(.3,.15,-1).Unit*(radius/math.sin(angle)),focus);camera.Focus=CFrame.new(focus)
     end
    end
    local progress=math.clamp(t/Rules.TearSeconds,0,1)
    local ageFromTear=math.max(0,t-Rules.TearSeconds)
    local wrapperFade=math.clamp((ageFromTear-.42)/.7,0,1)
    local wrapperRoot=root*CFrame.new(0,-ageFromTear*.12*s,0)
    for p,localFrame in pairs(record.FlapFrames)do
        local index=p:GetAttribute("TearIndex")
        if index then
            local peel=math.clamp(progress*8-(index-1),0,1)
            p.CFrame=wrapperRoot*CFrame.new(0,peel*.23*s,peel*.27*s)*localFrame*CFrame.Angles(peel*1.3,0,-peel*.16)
            p.Transparency=record.BagTransparency[p]+(1-record.BagTransparency[p])*math.max(wrapperFade,peel*.92)
        else p.CFrame=wrapperRoot*localFrame;p.Transparency=record.BagTransparency[p]+(1-record.BagTransparency[p])*wrapperFade end
    end
    record.Mouth.Size=Vector3.new(math.max(.001,1.68*progress*s),.025*s,math.max(.001,.3*progress*s))
    record.Mouth.CFrame=wrapperRoot*CFrame.new((progress-1)*.84*s,mouth+.015*s,0)
    record.Mouth.Transparency=progress==0 and 1 or wrapperFade
    for i,p in ipairs(record.Lips)do
        local peel=math.clamp(progress*8-(i-1),0,1)
        local x=-.84+(i-.5)*1.68/8
        p.Size=Vector3.new(.218,.14,.035)*s
        p.CFrame=wrapperRoot*CFrame.new(x*s,mouth+(.025+peel*.10)*s,-peel*.22*s)*CFrame.Angles(-peel*1.2,0,(i%2==0 and .08 or -.08))
        p.Transparency=peel==0 and 1 or wrapperFade
        local release=.02+(i-1)/8*(Rules.TearSeconds-.02);local age=math.max(0,t-release)
        local scrap=record.Scraps[i];scrap.Size=Vector3.new(.07,.11,.02)*math.min(s,3)
        scrap.CFrame=root*CFrame.new((x+age*.12)*s,mouth+(age*.9-age*age*1.7)*s,age*.24*s)*CFrame.Angles(age*2.5,i,age*1.7)
        scrap.Transparency=t<release and 1 or math.clamp((age-.1)/.55,0,1)
    end
    if record.TearSound then
        if t>Rules.TearSeconds+.1 then record.TearSound:Stop();record.TearSound=nil
        else record.TearSound.Volume=Rules.TearVolume*math.clamp(t/.025,0,1)*math.clamp((Rules.TearSeconds+.08-t)/.15,0,1)end
    end
    local revealStart=require(ReplicatedStorage.RarityRevealSequence).SeedAt(record.RarityRank);local age=math.max(0,t-revealStart)
    local timing=require(ReplicatedStorage.BalanceRules)
    local rise,slide=timing.SeedPhase(age);local ease=1-(1-rise)^3
    local scale=record.SeedBaseScale -- slide the seed out at its real held size
    if not record.LastSeedScale or math.abs(scale-record.LastSeedScale)>.025 or (rise==1 and not record.SeedFullyGrown)then
        record.Seed:ScaleTo(scale);record.LastSeedScale=scale;record.SeedFullyGrown=rise==1
    end
    local rank=record.RarityRank
    local centre=root*CFrame.new(0,mouth-record.SeedRadius*(1-ease)+ease*(record.SeedRadius+.8),-ease*(.4+record.SeedRadius*.22))
    local seedFrame=centre*Rules.RevealPose(rank,age,ease)
    local owner=bag.Parent;local hand=owner and(owner:FindFirstChild('RightHand')or owner:FindFirstChild('Right Arm'))
    if hand then seedFrame=seedFrame:Lerp(hand.CFrame*CFrame.new(0,-.5,0),slide*slide*(3-2*slide))end
    record.Seed:PivotTo(seedFrame)
    local fade=math.clamp((slide-.85)/.15,0,1);local visible=t>=revealStart and fade<1
    for _,p in ipairs(record.SeedParts)do if p~=record.Seed.PrimaryPart then p.LocalTransparencyModifier=visible and fade or 1 end end
    if visible~=record.SeedVisible then
        record.SeedVisible=visible
        for _,p in ipairs(record.SeedEffects)do p.Enabled=visible end
    end
    if record.SeedMotion then record.SeedMotion:Update(seedFrame,age,scale,visible and (1-fade)*ease or 0)end
    local radius=math.max(.001,math.max(1.25,record.SeedBaseScale*1.5)*ease)
    for i,p in ipairs(record.Celestial)do
        local offset=Rules.RevealAuraPoint(rank,i,#record.Celestial,age,radius)
        local frame=seedFrame;local world=frame:PointToWorldSpace(offset)
        p.Size=Vector3.one*(.065+.008*rank)*math.min(record.SeedBaseScale,2);p.CFrame=CFrame.new(world)
        p.Transparency=visible and math.clamp(.16+fade*.84+(rank==6 and .12*(1+math.sin(age*1.7+i))or 0),0,1)or 1
    end
    -- One restrained major chord for the opener, never a loop or a global server sound.
    if not record.HeavenlyStarted and t>=revealStart and rank>=4 then
        record.HeavenlyStarted=true
        local char=Players.LocalPlayer and Players.LocalPlayer.Character
        if age<.4 and char and bag:IsDescendantOf(char)and now-lastHeavenlyAt>=Rules.RevealAudioCooldown then
            lastHeavenlyAt=now
            local pitches=rank==4 and {.5,.63,.75}or rank==6 and {.375,.5,.75}or rank>=7 and {.5,.75,1,1.25}or {.5,.75,.94}
            for i,pitch in ipairs(pitches)do
                local sound=Instance.new("Sound");sound.Name="Soft reveal chime";sound.SoundId=Rules.RevealBellSoundId
                sound.Volume=0;sound.PlaybackSpeed=pitch;sound.Looped=false;sound.RollOffMaxDistance=24;sound.Parent=record.Seed.PrimaryPart
                local eq=Instance.new("EqualizerSoundEffect");eq.HighGain=-12;eq.MidGain=-3;eq.Parent=sound
                table.insert(record.HeavenlySounds,{Sound=sound,Delay=(i-1)*.14,Played=false})
            end
        end
    end
    for _,voice in ipairs(record.HeavenlySounds)do
        local elapsed=age-voice.Delay
        if elapsed>=0 and not voice.Played then voice.Played=true;voice.Sound:Play()end
        voice.Sound.Volume=Rules.RevealBellVolume*math.clamp(elapsed/.1,0,1)*math.clamp((1.6-elapsed)/1.2,0,1)*(1-fade)
        if elapsed>=1.6 then voice.Sound:Stop()end
    end
end

-- Tagged models include streamed/equipped seeds. Templates and inventory never animate.
local trackedSeeds,activeSeeds={},{}
local function untrackSeed(seed)
    trackedSeeds[seed]=nil
    local entry=activeSeeds[seed]
    if entry then entry.Motion:Destroy();activeSeeds[seed]=nil end
end
local function trackSeed(seed)
    if seed:IsA("Model")and not seed:GetAttribute("SeedMotionManaged")then trackedSeeds[seed]=true end
end
table.insert(connections,CollectionService:GetInstanceAddedSignal(Rules.SeedMotion.Tag):Connect(trackSeed))
table.insert(connections,CollectionService:GetInstanceRemovedSignal(Rules.SeedMotion.Tag):Connect(untrackSeed))
for _,seed in ipairs(CollectionService:GetTagged(Rules.SeedMotion.Tag))do trackSeed(seed)end
local seedSelection=Rules.SeedMotion.SelectionInterval
local function updateHeldSeeds(dt,now)
    seedSelection+=dt
    local camera=workspace.CurrentCamera
    if seedSelection>=Rules.SeedMotion.SelectionInterval then
        seedSelection=0
        local candidates={}
        local character=Players.LocalPlayer and Players.LocalPlayer.Character
        for seed in pairs(trackedSeeds)do
            if seed.Parent and seed.PrimaryPart and seed:IsDescendantOf(workspace)and not seed:GetAttribute("SeedMotionManaged")then
                local distance=camera and(camera.CFrame.Position-seed.PrimaryPart.Position).Magnitude or math.huge
                if distance<=Rules.SeedMotion.MaxDistance then
                    local owned=character and seed:IsDescendantOf(character)
                    table.insert(candidates,{Seed=seed,Distance=distance,Score=distance-(owned and 1000 or 0)-(activeSeeds[seed]and 2 or 0)})
                end
            end
        end
        table.sort(candidates,function(a,b)return a.Score<b.Score end)
        local selected,details={},0
        for index,item in ipairs(candidates)do
            if index>Rules.SeedMotion.MaxActive then break end
            local seed=item.Seed;local entry=activeSeeds[seed]
            -- A small hysteresis band prevents repeated construction at the detail boundary.
            local threshold=Rules.SeedMotion.DetailDistance+(entry and entry.Detailed and 8 or 0)
            local full=item.Distance<=threshold and details<Rules.SeedMotion.MaxDetailed
            if full then details+=1 end
            if entry and entry.Detailed~=full then entry.Motion:Destroy();activeSeeds[seed]=nil;entry=nil end
            if not entry then
                local motion=Visuals.CreateSeedMotion(seed,effects,full)
                if motion then entry={Motion=motion,Detailed=full,StartedAt=now};activeSeeds[seed]=entry end
            end
            selected[seed]=true
        end
        for seed,entry in pairs(activeSeeds)do
            if not selected[seed]then entry.Motion:Destroy();activeSeeds[seed]=nil end
        end
    end
    for seed,entry in pairs(activeSeeds)do
        local root=seed.PrimaryPart
        if not seed.Parent or not root or not root.Parent or not seed:IsDescendantOf(workspace)then
            entry.Motion:Destroy();activeSeeds[seed]=nil
        else
            local s=(seed:GetAttribute("SeedVisualScale")or 1)*seed:GetScale()
            local distance=camera and(camera.CFrame.Position-root.Position).Magnitude or math.huge
            local alpha=math.clamp((Rules.SeedMotion.MaxDistance-distance)/15,0,1)
            entry.Motion:Update(root.CFrame,now-entry.StartedAt,s,alpha)
        end
    end
end

-- Restore our previous override BEFORE Animator writes this frame's pose.
table.insert(connections,RunService.PreAnimation:Connect(function()
    for _,record in pairs(records) do record.Pose:Reset() end
end))
table.insert(connections,RunService.PreSimulation:Connect(function()
    local now=workspace:GetServerTimeNow()
    for _,player in ipairs(Players:GetPlayers()) do
        local char=player.Character
        local bag=char and char:FindFirstChild("CarriedSeed")
        local humanoid=char and char:FindFirstChildOfClass("Humanoid")
        if not bag or not bag:GetAttribute("SeedPackCarry") or not bag.PrimaryPart or not humanoid or humanoid.Health<=0
            or char:GetAttribute("ChestChaseRagdollActive") then remove(player);continue end
        local record=records[player]
        if record and record.Bag~=bag then remove(player);record=nil end
        if not record then
            record={Bag=bag,Pose=Pose.new(char),RefreshedAt=now};records[player]=record
        end
        if not record.Pose:IsReady() and now-record.RefreshedAt>.25 then
            record.Pose:Reset();record.Pose=Pose.new(char);record.RefreshedAt=now
        end
        record.Pose:Apply(bag,now)
    end
end))
local revealAccumulator=0
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
    revealAccumulator+=dt;if revealAccumulator<Rules.SeedMotion.UpdateInterval then return end
    local elapsed=revealAccumulator;revealAccumulator%=Rules.SeedMotion.UpdateInterval
    local now=workspace:GetServerTimeNow()
    updateHeldSeeds(elapsed,now)
    for _,record in pairs(records) do
        local bag=record.Bag
        if not bag.Parent or not bag.PrimaryPart then continue end
        local at=bag:GetAttribute("RevealAt");local id=bag:GetAttribute("RevealSeedId")
        local camera=workspace.CurrentCamera
        local nearby=bag.Parent==Players.LocalPlayer.Character or not camera or (camera.CFrame.Position-bag.PrimaryPart.Position).Magnitude<math.max(120,(bag:GetAttribute('VisualScale')or 1)*5)
        if nearby and at and id and now-at<(bag:GetAttribute("RevealDuration") or Rules.RevealSeconds) then
            if not record.Effect then beginReveal(record,at,id,now) end
            if record.Effect then renderReveal(record,now) end
        elseif record.Effect then destroyEffect(record) end
    end
end))
table.insert(connections,Players.PlayerRemoving:Connect(remove))
script.Destroying:Connect(function()
    for _,c in ipairs(connections) do c:Disconnect() end
    for player in pairs(records) do remove(player) end
    for seed in pairs(trackedSeeds)do untrackSeed(seed)end
    effects:Destroy()
end)
