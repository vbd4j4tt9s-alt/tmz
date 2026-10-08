do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
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
-- R152 (owner: "sometimes the animation not playing"): a slow join used to give up after 20 s, and then no pack opened visibly in the
-- world for the whole session; it waits for the published art instead (a warning every 30 s while it does).
local function await(parent,name)
    local found=parent:FindFirstChild(name)
    while not found do found=parent:WaitForChild(name,30);if not found then warn("[SeedPackClient] still waiting for "..name)end end
    return found
end
local remotes=await(ReplicatedStorage,"ChestChaseRemotes")
local library=await(remotes,"SeedArt")
local catalog=await(remotes,"SeedCatalog")
local records={}
local connections={}
local TEAR_AUDIO_GRACE=.25
local effects=Instance.new("Folder");effects.Name="_LocalSeedPackEffects";effects.Parent=workspace
local preload=Instance.new("Sound");preload.SoundId=Rules.TearSoundId;preload.Volume=0;preload.Parent=effects
local bellPreload=Instance.new("Sound");bellPreload.SoundId=Rules.RevealBellSoundId;bellPreload.Volume=0;bellPreload.Parent=effects
-- Audio loading never gates the inventory transaction or visual reveal.
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({preload,bellPreload}) end) end)
Debris:AddItem(preload,12)
Debris:AddItem(bellPreload,12)
-- R150: onlookers hear a Secret / Cosmic / King pull as the reveal's impact at the bag (Legendary / Mythic have their own in RevealFlourish).
local LocalSfx=require(ReplicatedStorage:WaitForChild("LocalSfx"));local OnlookerId=require(ReplicatedStorage:WaitForChild("RevealFlourish")).SoundId
LocalSfx.Preload({OnlookerId})
local ONLOOKER_RANGE=160
-- R151: every pack builds suspense before the seed bursts out (wobble, a bit-by-bit tear, a glowing seam whose rarity hint flickers up the
-- ladder), for everyone watching; the seed comes out at RarePullRules.BurstAt (Secret+ unchanged) and hovers shorter, so the reveal still
-- ends with the server's RevealDuration. Secret / Cosmic / King also get the light pillar and afterglow aura (RarePullWorld).
local Ladder=require(ReplicatedStorage:WaitForChild("RarePullRules"))
local Suspense=require(ReplicatedStorage:WaitForChild("PackSuspense"))
local PropCache do local ok,m=pcall(require,ReplicatedStorage:WaitForChild("PropCache152",5));PropCache=ok and m or{new=function()return{Set=function(o,k,v)o[k]=v end}end}end -- (R152 perf)
local RareWorld do local ok,m=pcall(require,ReplicatedStorage:WaitForChild("RarePullWorld",10));RareWorld=ok and m or nil end
if not RareWorld then task.spawn(function()local m=ReplicatedStorage:WaitForChild("RarePullWorld");local ok,w=pcall(require,m);if ok then RareWorld=w end end)end -- (R152: late, not never)
local RareCinematic=nil
local function cinematic()
    if not RareCinematic then local ok,m=pcall(require,ReplicatedStorage:FindFirstChild("RarePullCinematic"));RareCinematic=ok and m or false end
    return RareCinematic or nil
end
local function cinematicOwnsCamera()local c=cinematic();return c~=nil and c.OwnsCamera()==true end
-- R152: the opener's own Secret / Cosmic / King reveal has its own hit and fanfare (the director); the old chord at the world burst stacked on it
local function cinematicRunning()local c=cinematic();return c~=nil and c.Active()~=nil end
local function reducedMotion()local ok,v=pcall(function()return game:GetService("GuiService").ReducedMotionEnabled end);return ok and v==true end
local function ownerOf(character)for _,p in ipairs(Players:GetPlayers())do if p.Character==character then return p end end;return nil end
-- R152 fix: the seed-to-hand whoosh was a child of the seed effect, which ends at RevealDuration while the whoosh is still fading (it was cut at about 75 % volume). One that
-- is still fading then moves to an anchor of its own (a tail) that outlives the record, follows the same fade (stepTails) and is destroyed once the fade is done.
local tails={}
local function handOver(record)
    local sound,f=record.SlideWhoosh,record.SlideWhooshFlight;record.SlideWhoosh=nil
    if not(sound and f and sound.Parent)then return end
    if workspace:GetServerTimeNow()-record.At+(f.Shift or 0)-f.Peak>.45 then return end -- (its own fade is over: nothing to finish)
    local root=record.Seed and record.Seed.PrimaryPart
    local anchor=Instance.new("Part");anchor.Name="Seed flight whoosh";anchor.Size=Vector3.one*.2;anchor.Transparency=1
    anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false
    anchor.CFrame=root and root.CFrame or CFrame.new();anchor.Parent=effects
    sound.Parent=anchor;tails[#tails+1]={Sound=sound,Flight=f,Anchor=anchor,At=record.At-(f.Shift or 0)}
end
local function stepTails(now)
    for i=#tails,1,-1 do
        local tail=tails[i];local a=now-tail.At-tail.Flight.Peak
        if a>.45 or not tail.Sound.Parent then pcall(function()tail.Sound:Stop()end);tail.Anchor:Destroy();table.remove(tails,i)
        else tail.Sound.Volume=tail.Flight.Volume*math.clamp(1-(a-.15)/.3,0,1)end
    end
end
local function destroyEffect(record)
    if record.SlideWhoosh then pcall(handOver,record)end
    if record.CameraState then local saved=record.CameraState;record.CameraState=nil;local camera=workspace.CurrentCamera;if camera==saved.Camera then camera.CameraType=saved.Type;camera.CFrame=saved.Frame;camera.Focus=saved.Focus end end
    if record.SeedMotion then record.SeedMotion:Destroy();record.SeedMotion=nil end
    if record.Flourish then record.Flourish:Destroy();record.Flourish=nil end
    if record.Suspense then record.Suspense:Destroy();record.Suspense=nil end
    if record.Effect then record.Effect:Destroy();record.Effect=nil end
    for _,part in ipairs(record.Hidden or {}) do
        if part.Parent then
            part.LocalTransparencyModifier=(record.Bag and record.Bag:GetAttribute("RevealAt")and not record.FailedAt)and 1 or (part:GetAttribute("PackProxy")and record.Bag and record.Bag:GetAttribute("NativePackArtReady")and 1 or 0)
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
-- R152 (owner: "sometimes the animation not playing"): the published art and catalog are looked up again for each reveal (one rebuilt on
-- the server left this client holding a destroyed folder, and no pack opened visibly again), and a seed missing from them (not there yet,
-- left out of the catalog) is built here with the same art code (SeedPackVisuals.Seed) instead of its reveal never starting.
local function seedTemplate(seedId)
    local lib=remotes:FindFirstChild("SeedArt")or library
    local seeds=lib and lib:FindFirstChild("Seeds")
    local template=seeds and seeds:FindFirstChild(seedId)
    if template then return template,false end
    local ok,model=pcall(Visuals.Seed,{Id=seedId},1,CFrame.new(),nil,1,nil,"None")
    if ok and typeof(model)=="Instance" then return model,true end
    return nil,false
end
local function seedName(seedId)
    local cat=remotes:FindFirstChild("SeedCatalog")or catalog
    local definition=cat and cat:FindFirstChild(seedId)
    local name=definition and definition:GetAttribute("DisplayName")
    if not name then local spec=Rules.SeedDesignById and Rules.SeedDesignById[seedId];name=spec and spec.name end
    return name or "Seed"
end
local function beginReveal(record,at,seedId,now)
    if not record.Bag.PrimaryPart then return end
    local template,built=seedTemplate(seedId)
    if not template then return end
    local name,rarity=Rules.GetRarity(seedId)
    record.RarityRank=rarity.Rank;record.RarityName=name
    record.Duration=record.Bag:GetAttribute("RevealDuration") or Rules.GetRevealDuration(name)
    local mine=Players.LocalPlayer and record.Bag.Parent==Players.LocalPlayer.Character
    record.Quick=mine and Ladder.QuickFor(record.Bag)or Ladder.IsQuick(record.Bag);record.BurstAt=Ladder.BurstAt(rarity.Rank,record.Quick) -- R152: one decision per bag
    record.Hover=Ladder.Hover(rarity.Rank,record.BurstAt,record.Duration);record.TearTicks=Ladder.TearTicks(rarity.Rank,record.Quick);record.TickPlayed={[1]=true}
    record.HeavenlySounds={};record.HeavenlyStarted=false;record.Celestial={}
    record.SeedVisible=nil;record.LastSeedScale=nil;record.SeedFullyGrown=nil;record.TearSound=nil;record.SlideFlight=nil;record.SlideWhooshDone=nil;record.SlideWhoosh=nil
    local effect=Instance.new("Model");effect.Name="SeedReveal";effect.Parent=effects
    record.Effect=effect;record.At=at;record.Hidden={};record.SeedParts={};record.SeedEffects={}
    record.Set=PropCache.new().Set -- R152 perf: the reveal's per-frame values are written only when they change
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
        -- R147: a Decal (the Verity pack's picture) follows only its own properties, so it is hidden here like a part.
        if p:IsA("BasePart")or p:IsA("Decal") then p.LocalTransparencyModifier=1;table.insert(record.Hidden,p)end
    end
    record.DecalFade={}
    for _,p in ipairs(copy:GetDescendants())do
        if p:IsA("BasePart") then record.FlapFrames[p]=bagFrame:ToObjectSpace(p.CFrame);record.BagTransparency[p]=p.Transparency
        elseif p:IsA("Decal") then record.DecalFade[p]=p.Transparency end -- R147: the picture fades with the wrapper
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
    local seed=built and template or template:Clone();seed.Name="RewardSeed"
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
    text.Text=seedName(seedId).."\n"..require(ReplicatedStorage.NoticeCopy83).Rarity(name)
    text.TextXAlignment=Enum.TextXAlignment.Center;text.TextYAlignment=Enum.TextYAlignment.Center;
    text.Font=Enum.Font.FredokaOne;text.TextSize=18;text.TextColor3=rarity.Color;text.TextStrokeTransparency=.2;text.Parent=label
    for _,p in ipairs(seed:GetDescendants())do
        -- R148: a Decal (Verity's face on her seed) follows only its own properties, so the reveal hides and fades it like a part.
        if p:IsA("BasePart")or p:IsA("Decal")then table.insert(record.SeedParts,p);p.LocalTransparencyModifier=1
        elseif p:IsA("ParticleEmitter")or p:IsA("PointLight")or p:IsA("BillboardGui")or p:IsA("Highlight")then
            p.Enabled=false;table.insert(record.SeedEffects,p)
            if p:IsA("ParticleEmitter")then p:Clear()end
        end
    end
    -- Common/Uncommon retain their existing reveal. Rare+ share the held-seed effects.
    local count=rarity.Rank<3 and (rarity.Rank==1 and 4 or 8)or 0
    for i=1,count do record.Celestial[i]=cosmeticPart("Rarity light",effect,rarity.Color,Vector3.one*.08)end
    if rarity.Rank>=3 then record.SeedMotion=Visuals.CreateSeedMotion(seed,effect,true)end
    -- R136: Legendary / Mythic pulls get a charge-up and a burst (pillar, shockwave, sparkles, sound for onlookers).
    local lowFx=false;pcall(function()lowFx=require(ReplicatedStorage.ClientFxBudget).Low()end)
    -- (R152: the pack's own seam glow is there, so the flourish adds none at the mouth; its beam follows the effects budget)
    record.Flourish=require(ReplicatedStorage:WaitForChild("RevealFlourish")).Create(effect,rarity.Rank,record.Bag:GetAttribute("VisualScale")or 1,{Suspense=true,Tier=lowFx and 1 or nil})
    record.Suspense=Suspense.Create(effect,rarity.Rank,record.Bag:GetAttribute("VisualScale")or 1,record.Quick,lowFx);record.Suspense:SetPack(copy)
    if rarity.Rank>=6 and RareWorld then
        local owner=ownerOf(record.Bag.Parent)
        if owner then pcall(RareWorld.Begin,owner,record.Bag.Parent,rarity.Rank,at)end
    end
    -- R123: the reveal reaches this client one replication delay after RevealAt. Up to TEAR_AUDIO_GRACE late, the
    -- tear still plays while the paper scraps fly (its short envelope is shifted to start now); later it is skipped.
    local lag=now-at;record.TearShift=0
    if lag<Rules.TearSeconds+TEAR_AUDIO_GRACE then
        local sound=Instance.new("Sound");sound.Name="Paper bag tearing";sound.SoundId=Rules.TearSoundId
        sound.Volume=0;sound.Looped=false;sound.RollOffMinDistance=5;sound.RollOffMaxDistance=36;sound.Parent=copy.PrimaryPart
        record.TearShift=math.max(0,lag-.02)
        -- R150: the lead-in comes from SoundTiming (9125725227 = .10, the old Rules.TearSoundStart) so every cue is tuned in one place.
        sound.TimePosition=require(ReplicatedStorage:WaitForChild("SoundTiming")).Offset(sound)+math.clamp(lag,0,.02);sound:Play();record.TearSound=sound
    end
end
-- R152: the world seed's flight into the hand (RarePullRules.HandFlight) with the whoosh entered so its swell (RarePullSounds.Flight)
-- lands on the flight's fastest frame: {Start, Peak, Entry, Id, Pitch, Volume, Region, Shift} on the reveal's clock (R153: shifted by the
-- opener's skip, Shift: the slide itself stays on the server's time).
local function slideFlight(record,revealStart,shift)
    if record.SlideFlight~=nil and record.SlideShift==shift then return record.SlideFlight or nil end
    record.SlideShift=shift
    local ok,f=pcall(function()
        local def=require(ReplicatedStorage.RarePullSounds).Get("Flight")
        if not def or not def.Id or not def.Swell then return false end
        local flight=Ladder.HandFlight(revealStart,record.Hover+shift)
        local bound=def.Region and def.Region[1]or def.Start or 0
        return {Start=flight.Peak-(def.Swell-bound)/flight.Pitch,Peak=flight.Peak,Entry=bound,Id=def.Id,Pitch=flight.Pitch,Volume=def.Volume*flight.Volume,Region=def.Region,Shift=shift}
    end)
    record.SlideFlight=ok and f or false
    return record.SlideFlight or nil
end
local function renderReveal(record,now)
    -- R153: the opener skipped their card to the hit (RarePullRules.Shift): their pack jumps with it, the seed bursts out with the card; its
    -- hover grows by as much, so it still flies into the hand when the server ends the opening (the seed is the server's: nothing changes there)
    local bag=record.Bag;local shift=Ladder.Shift(bag);local t=now-record.At+shift
    local s=bag:GetAttribute("VisualScale")or 1;local root=bag.PrimaryPart.CFrame
    local mouth=(bag:GetAttribute("TearLipY")or 1.11)*s
    if bag.Parent==Players.LocalPlayer.Character and math.max(s,record.SeedBaseScale)>10 and not cinematicOwnsCamera() then
     local camera=workspace.CurrentCamera
     if camera then
      if not record.CameraState then record.CameraState={Camera=camera,Type=camera.CameraType,Frame=camera.CFrame,Focus=camera.Focus}end
      local focus=root.Position+Vector3.new(0,mouth*.65,0);local radius=math.max(s*2.7,record.SeedBaseScale*3.2)
      local aspect=math.max(.25,camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y));local angle=math.atan(math.tan(math.rad(camera.FieldOfView/2))*math.min(1,aspect))
      camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=CFrame.lookAt(focus+Vector3.new(.3,.15,-1).Unit*(radius/math.sin(angle)),focus);camera.Focus=CFrame.new(focus)
     end
    end
    -- R151: the strips peel a few at a time through the suspense; the wrapper holds (wobbling) until the seed bursts out, then empties
    local rank0=record.RarityRank;local burstAt=record.BurstAt or Ladder.BurstAt(rank0)
    local progress=0;for i=1,8 do progress+=Ladder.StripPeel(rank0,t,i,record.Quick)/8 end
    local ageFromTear=math.max(0,t-burstAt)
    local wrapperFade=math.clamp((ageFromTear-.2)/.6,0,1)
    local wobble=Ladder.Wobble(rank0,t,record.Quick,reducedMotion());wobble=CFrame.new(wobble.Position*s)*wobble.Rotation
    -- (R152: the emptied wrapper starts to sink from rest, a^2/(a+.2), instead of at full speed on the burst frame)
    local wrapperRoot=root*CFrame.new(0,-(ageFromTear*ageFromTear/(ageFromTear+.2))*.12*s,0)*wobble
    local S=record.Set
    for p,localFrame in pairs(record.FlapFrames)do
        local index=p:GetAttribute("TearIndex")
        if index then
            local peel=Ladder.StripPeel(rank0,t,index,record.Quick)
            S(p,"CFrame",wrapperRoot*CFrame.new(0,peel*.23*s,peel*.27*s)*localFrame*CFrame.Angles(peel*1.3,0,-peel*.16))
            S(p,"Transparency",record.BagTransparency[p]+(1-record.BagTransparency[p])*math.max(wrapperFade,peel*.92))
        else S(p,"CFrame",wrapperRoot*localFrame);S(p,"Transparency",record.BagTransparency[p]+(1-record.BagTransparency[p])*wrapperFade)end
    end
    for d,base in pairs(record.DecalFade or{})do S(d,"Transparency",base+(1-base)*wrapperFade)end
    S(record.Mouth,"Size",Vector3.new(math.max(.001,1.68*progress*s),.025*s,math.max(.001,.3*progress*s)))
    S(record.Mouth,"CFrame",wrapperRoot*CFrame.new((progress-1)*.84*s,mouth+.015*s,0))
    S(record.Mouth,"Transparency",progress==0 and 1 or wrapperFade)
    for i,p in ipairs(record.Lips)do
        local peel=Ladder.StripPeel(rank0,t,i,record.Quick)
        local x=-.84+(i-.5)*1.68/8
        S(p,"Size",Vector3.new(.218,.14,.035)*s)
        S(p,"CFrame",wrapperRoot*CFrame.new(x*s,mouth+(.025+peel*.10)*s,-peel*.22*s)*CFrame.Angles(-peel*1.2,0,(i%2==0 and .08 or -.08)))
        S(p,"Transparency",peel==0 and 1 or wrapperFade)
        local release=Ladder.StripStart(rank0,i,record.Quick)+.02;local age=math.max(0,t-release)
        local scrap=record.Scraps[i];S(scrap,"Size",Vector3.new(.07,.11,.02)*math.min(s,3))
        S(scrap,"CFrame",root*CFrame.new((x+age*.12)*s,mouth+(age*.9-age*age*1.7)*s,age*.24*s)*CFrame.Angles(age*2.5,i,age*1.7))
        S(scrap,"Transparency",t<release and 1 or math.clamp((age-.1)/.55,0,1))
    end
    if record.TearSound then
        local tt=t-(record.TearShift or 0)
        if tt>Rules.TearSeconds+.1 then record.TearSound:Stop();record.TearSound=nil
        else S(record.TearSound,"Volume",Rules.TearVolume*math.clamp(tt/.025,0,1)*math.clamp((Rules.TearSeconds+.08-tt)/.15,0,1))end
    end
    -- R151: a short rip each time the next strips go (on the beat of the peel; a tick reaching this client late is skipped)
    for i,tick in ipairs(record.TearTicks or{})do
        if not record.TickPlayed[i]and t>=tick then
            record.TickPlayed[i]=true
            if t-tick<=TEAR_AUDIO_GRACE then
                local sound=record.TickSound
                if not sound then sound=Instance.new("Sound");sound.Name="Paper bag tearing";sound.SoundId=Rules.TearSoundId;sound.RollOffMinDistance=5;sound.RollOffMaxDistance=36;sound.Parent=record.Copy.PrimaryPart or record.Effect;record.TickSound=sound end
                sound.Volume=Rules.TearVolume*.75;sound.PlaybackSpeed=1+.06*i
                sound.TimePosition=require(ReplicatedStorage:WaitForChild("SoundTiming")).Offset(sound);sound:Play();record.TickStop=t+.14
            end
        end
    end
    if record.TickSound and record.TickStop and t>=record.TickStop then record.TickSound:Stop();record.TickStop=nil end
    local revealStart=burstAt;local age=math.max(0,t-revealStart)
    if record.Suspense then record.Suspense:Update(wrapperRoot*CFrame.new(0,mouth,0),t)end
    if RareWorld and record.RarityRank>=6 then local owner=ownerOf(bag.Parent);if owner then RareWorld.SetMouth(owner,root*CFrame.new(0,mouth,0));if shift>0 then RareWorld.Shift(owner,shift)end end end
    if record.Flourish then
        local char=Players.LocalPlayer and Players.LocalPlayer.Character
        record.Flourish:Update(root*CFrame.new(0,mouth,0),t,revealStart,not(char and bag:IsDescendantOf(char)))
    end
    local rise,slide=Ladder.SeedPhase(age,record.Hover+shift);local ease=1-(1-rise)^3
    local scale=record.SeedBaseScale -- slide the seed out at its real held size
    if not record.LastSeedScale or math.abs(scale-record.LastSeedScale)>.025 or (rise==1 and not record.SeedFullyGrown)then
        record.Seed:ScaleTo(scale);record.LastSeedScale=scale;record.SeedFullyGrown=rise==1;record.SeedPivot=nil
    end
    local rank=record.RarityRank
    local centre=root*CFrame.new(0,mouth-record.SeedRadius*(1-ease)+ease*(record.SeedRadius+.8),-ease*(.4+record.SeedRadius*.22))
    local seedFrame=centre*Rules.RevealPose(rank,age,ease)
    local owner=bag.Parent;local hand=owner and(owner:FindFirstChild('RightHand')or owner:FindFirstChild('Right Arm'))
    if hand then seedFrame=seedFrame:Lerp(hand.CFrame*CFrame.new(0,-.5,0),slide*slide*(3-2*slide))end
    -- R152 (owner: "whoosh for the flying"): a soft whoosh at the seed as it flies into the hand, its swell on the slide's fastest frame
    if hand and not record.SlideWhooshDone then
        local f=slideFlight(record,revealStart,shift)
        if not f then record.SlideWhooshDone=true
        elseif t>=f.Start then
            record.SlideWhooshDone=true
            if t-f.Start<.2 and record.Seed.PrimaryPart then
                local sound=Instance.new("Sound");sound.Name="Seed flight";sound.SoundId=f.Id;sound.PlaybackSpeed=f.Pitch;sound.Volume=f.Volume
                sound.RollOffMinDistance=6;sound.RollOffMaxDistance=48;sound.Parent=record.Seed.PrimaryPart
                if f.Region then pcall(function()sound.PlaybackRegionsEnabled=true;sound.PlaybackRegion=NumberRange.new(f.Region[1],f.Region[2])end)end
                pcall(function()require(ReplicatedStorage.AudioMixer).Route(sound,"Effects")end)
                sound.TimePosition=f.Entry+(t-f.Start)*f.Pitch;sound:Play();record.SlideWhoosh=sound;record.SlideWhooshFlight=f
            end
        end
    end
    if record.SlideWhoosh then
        local f=record.SlideWhooshFlight;local a=t-f.Peak
        if a>.45 then record.SlideWhoosh:Stop();record.SlideWhoosh=nil
        else S(record.SlideWhoosh,"Volume",f.Volume*math.clamp(1-(a-.15)/.3,0,1))end
    end
    -- (R152 perf: a seed that holds still is not moved again every frame; only this reveal moves it, and a rescale moves it again)
    if record.SeedPivot~=seedFrame then record.Seed:PivotTo(seedFrame);record.SeedPivot=seedFrame end
    local fade=math.clamp((slide-.85)/.15,0,1);local visible=t>=revealStart and fade<1
    -- (a giant seed's parts also get GiantVisualSafety's close-up fade: the value there is read, not remembered)
    local seedAlpha=visible and fade or 1
    for _,p in ipairs(record.SeedParts)do if p~=record.Seed.PrimaryPart and p.LocalTransparencyModifier~=seedAlpha then p.LocalTransparencyModifier=seedAlpha end end
    if visible~=record.SeedVisible then
        record.SeedVisible=visible
        for _,p in ipairs(record.SeedEffects)do p.Enabled=visible end
    end
    if record.SeedMotion then record.SeedMotion:Update(seedFrame,age,scale,visible and (1-fade)*ease or 0)end
    local radius=math.max(.001,math.max(1.25,record.SeedBaseScale*1.5)*ease)
    for i,p in ipairs(record.Celestial)do
        local offset=Rules.RevealAuraPoint(rank,i,#record.Celestial,age,radius)
        local frame=seedFrame;local world=frame:PointToWorldSpace(offset)
        S(p,"Size",Vector3.one*(.065+.008*rank)*math.min(record.SeedBaseScale,2));S(p,"CFrame",CFrame.new(world))
        S(p,"Transparency",visible and math.clamp(.16+fade*.84+(rank==6 and .12*(1+math.sin(age*1.7+i))or 0),0,1)or 1)
    end
    -- One restrained major chord for the opener, never a loop or a global server sound.
    if not record.HeavenlyStarted and t>=revealStart and rank>=4 then
        record.HeavenlyStarted=true
        local char=Players.LocalPlayer and Players.LocalPlayer.Character
        local mine=char~=nil and bag:IsDescendantOf(char)
        if age<.4 and rank>=6 and not mine then
            -- R150: someone else's Secret+ pull: one impact at the seed on the frame it appears (rate-limited: LocalSfx de-dupes; one per reveal).
            local camera=workspace.CurrentCamera;local at=record.Seed.PrimaryPart.Position
            if camera and (camera.CFrame.Position-at).Magnitude<=ONLOOKER_RANGE then LocalSfx.Play(OnlookerId,at,.3,rank==8 and .88 or 1,3)end
        end
        -- (R153: no cooldown between the opener's own pulls any more (Rules.RevealAudioCooldown): each reveal has its chord, and two can never
        -- overlap: the server opens one pack at a time and the chord is over 1.6 s after its burst)
        if age<.4 and char and mine and not(rank>=6 and cinematicRunning())then
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
        S(voice.Sound,"Volume",Rules.RevealBellVolume*math.clamp(elapsed/.1,0,1)*math.clamp((1.6-elapsed)/1.2,0,1)*(1-fade))
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
-- R153 (owner: "fix all jittery type effects"): the loose / held seeds' aura and the pack reveal in the world are drawn every rendered frame (they ran at
-- Rules.SeedMotion.UpdateInterval, 30 Hz: stepped on a 60 Hz screen). Bounded as before: 12 seed auras (6 detailed) within 120 studs, reveals near the camera.
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
    local elapsed=dt
    local now=workspace:GetServerTimeNow()
    updateHeldSeeds(elapsed,now)
    if #tails>0 then stepTails(now)end
    for _,record in pairs(records) do
        local bag=record.Bag
        if not bag.Parent or not bag.PrimaryPart then continue end
        local at=bag:GetAttribute("RevealAt");local id=bag:GetAttribute("RevealSeedId")
        local camera=workspace.CurrentCamera
        local nearby=bag.Parent==Players.LocalPlayer.Character or not camera or (camera.CFrame.Position-bag.PrimaryPart.Position).Magnitude<math.max(120,(bag:GetAttribute('VisualScale')or 1)*5)
        if nearby and at and id and now-at<(bag:GetAttribute("RevealDuration") or Rules.RevealSeconds) then
            -- R152: one reveal that fails (a seed / pack this client cannot build, a part missing) is cleaned up and logged once, and the
            -- pack itself is shown again; it no longer stops this loop, so every other pack keeps opening
            if not record.Effect and record.FailedAt~=at then
                local ok,err=pcall(beginReveal,record,at,id,now)
                if not ok then record.FailedAt=at;pcall(destroyEffect,record);warn("[SeedPackClient] reveal could not start: "..tostring(err))end
            end
            if record.Effect then
                local ok,err=pcall(renderReveal,record,now)
                if ok then record.RenderErrors=nil -- (one bad frame is skipped; three in a row and this reveal is let go)
                else
                    record.RenderErrors=(record.RenderErrors or 0)+1
                    if record.RenderErrors==1 then warn("[SeedPackClient] reveal frame failed: "..tostring(err))end
                    if record.RenderErrors>=3 then record.FailedAt=at;pcall(destroyEffect,record)end
                end
            end
        elseif record.Effect then destroyEffect(record) end
    end
end))
table.insert(connections,Players.PlayerRemoving:Connect(function(player)remove(player);if RareWorld then RareWorld.Stop(player)end end))
script.Destroying:Connect(function()
    for _,c in ipairs(connections) do c:Disconnect() end
    for player in pairs(records) do remove(player) end
    for seed in pairs(trackedSeeds)do untrackSeed(seed)end
    effects:Destroy()
end)
