do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Fx=require(game:GetService('ReplicatedStorage'):WaitForChild('ClientFxBudget'))
-- V146: bounded moving glints and orbits aligned to the visible pack geometry.
local ContentProvider=game:GetService('ContentProvider')
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local CollectionService=game:GetService('CollectionService')
local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('SeedPackRules'))
local AuraGeometry=require(game:GetService('ReplicatedStorage'):WaitForChild('PackAuraGeometry'))
local RS=game:GetService('ReplicatedStorage')
local MechArt=require(RS:WaitForChild('SpecialPackArt89'))
local Gui=game:GetService('GuiService')
local Budget=require(RS:WaitForChild('CosmeticBudget'))
local View=require(RS:WaitForChild('PlantDetailPlanner'))
local BRIGHT_DISTANCE,DETAIL_DISTANCE,LIGHT_DISTANCE=900,160,42
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local WHITE=Color3.new(1,1,1)
local ACCENTS = {["Snow_01"]={{0.0,0.1,-0.5061}},["Snow_02"]={{0,0.12,-0.62}},["Snow_03"]={{0.475,0.0498,-0.5005},{-0.475,0.0499,-0.5005},{-0.0223,0.067,-0.6491}},["Snow_04"]={{-0.5196,-0.0299,-0.5595},{0.5194,0.0049,-0.582},{-0.1799,0.705,-0.4184}},["Snow_05"]={{-0.5196,-0.0299,-0.5595},{0.5194,0.0049,-0.582},{0.0,0.03,-0.7265}},["Snow_06"]={{-0.5196,-0.0299,-0.5595},{0.5194,0.0049,-0.582},{0.0,0.03,-0.7265}},["Crystal_01"]={{0.0008,0.0698,-0.6575}},["Crystal_02"]={{-0.4905,-0.2784,-0.5804},{-0.6706,-0.4807,-0.434},{0.5834,0.6359,-0.4033}},["Crystal_03"]={{-0.0006,0.1837,-0.7388},{-0.1943,-0.0503,-0.7139}},["Crystal_04"]={{0.0,0.02,-0.7468},{-0.6232,0.6926,-0.4463},{0.5338,0.6974,-0.4386}},["Crystal_05"]={{0.0,0.02,-0.7668},{-0.6232,0.6926,-0.4463},{0.5338,0.6974,-0.4386}},["Crystal_06"]={{0.0,0.03,-0.7965},{-0.5588,-0.076,-0.2964},{0.5562,-0.0751,-0.2964}}} -- GENERATED_ACCENTS
local themes={
    [1]={Name='ForestFireflies',Color=Color3.fromRGB(215,255,153),Rate=1.3,Size=.07,Acceleration=Vector3.new(0,.18,0)},
    [2]={Name='DesertShimmer',Color=Color3.fromRGB(255,214,143),Rate=2,Size=.055,Acceleration=Vector3.new(.08,.12,0)},
    [3]={Name='IceFlecks',Color=Color3.fromRGB(201,244,255),Rate=3,Size=.065,Acceleration=Vector3.new(.06,-.25,0)},
    [4]={Name='LavaEmbers',Color=Color3.fromRGB(255,160,73),Rate=3.5,Size=.08,Acceleration=Vector3.new(0,.6,0)},
    [5]={Name='PrismDust',Color=Color3.fromRGB(182,236,255),Rate=2,Size=.075,Acceleration=Vector3.new(0,.12,0)},
    [6]={Name='JungleSpores',Color=Color3.fromRGB(155,255,183),Rate=2,Size=.065,Acceleration=Vector3.new(.08,.16,0)},
    [7]={Name='StormCharge',Color=Color3.fromRGB(159,232,255),Rate=1.5,Size=.055,Acceleration=Vector3.new(0,.22,0)},
}
local records,connections={},{}
-- Deduplicated per asset, two workers, at most two requests per session.
-- PreloadAsync can return normally after a failure: inspect its callback/status.
local meshLoads,meshWorkers,meshesStopped={},0,false
local function meshStatus(id)
    local ok,status=pcall(ContentProvider.GetAssetFetchStatus,ContentProvider,id)
    return ok and status or nil
end
local function requestMesh(part,now,label)
    local id=part.MeshId
    if not id or id==''then return end
    local state=meshLoads[id]
    if not state then
        state={Id=id,Attempts=0,Next=now,Label=label};meshLoads[id]=state
    end
    state.Part=part;state.Seen=now
end
local function pumpMeshes(now)
    for _,state in pairs(meshLoads)do
        if meshesStopped or meshWorkers>=2 then break end
        if state.Busy or state.Done or state.Attempts>=2 or now<state.Next or now-state.Seen>1 then continue end
        if meshStatus(state.Id)==Enum.AssetFetchStatus.Success then state.Done=true;continue end
        local source=state.Part
        if not source or not source.Parent then continue end
        state.Busy=true;state.Attempts+=1;meshWorkers+=1
        -- A private clone remains valid if a pickup removes the world model.
        local probe=source:Clone();state.Probe=probe
        for _,child in ipairs(probe:GetChildren())do child:Destroy()end
        local finished=false
        local function complete(success)
            if finished then return end;finished=true
            if state.Timer then pcall(task.cancel,state.Timer);state.Timer=nil end
            state.Busy=false;meshWorkers-=1;probe:Destroy();state.Probe=nil
            if meshesStopped then return end
            state.Done=success;state.Next=workspace:GetServerTimeNow()+3
            if not success and state.Attempts>=2 then
                warn('[V125] Pack mesh still unavailable: '..state.Label..' / '..state.Id..
                    '. Check this asset\'s experience access, or use the exact-mesh repair. No further retries this session.')
            end
        end
        state.Timer=task.delay(12,function()
            state.Timer=nil
            if state.Thread then pcall(task.cancel,state.Thread)end
            complete(meshStatus(state.Id)==Enum.AssetFetchStatus.Success)
        end)
        state.Thread=task.spawn(function()
            local success=false
            pcall(function()
                ContentProvider:PreloadAsync({probe},function(content,status)
                    local returned=tostring(content):match('(%d+)$')
                    if returned==state.Id:match('(%d+)$')and status==Enum.AssetFetchStatus.Success then success=true end
                end)
            end)
            complete(success or meshStatus(state.Id)==Enum.AssetFetchStatus.Success)
        end)
    end
end
local function stopMeshes()
    meshesStopped=true
    for _,state in pairs(meshLoads)do
        if state.Timer then pcall(task.cancel,state.Timer)end
        if state.Thread then pcall(task.cancel,state.Thread)end
        if state.Probe then state.Probe:Destroy()end
    end
    table.clear(meshLoads)
end

local effectsRoot=Instance.new('Folder');effectsRoot.Name='_LocalPackPolishV128';effectsRoot.Parent=workspace
local function attachment(parent,name,position)
    local a=Instance.new('Attachment');a.Name=name;a.CFrame=CFrame.new(position);a.Parent=parent;return a
end
local function part(parent,name,size)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.Transparency=1
    p.Anchored=true;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Parent=parent;return p
end
local function emitter(parent,name,color,rate,size,lifetime)
    local e=Instance.new('ParticleEmitter');e.Name=name;e.Texture=SPARK
    e.Color=ColorSequence.new(color);e.LightEmission=.9;e.LightInfluence=0;e.Brightness=1.3
    e.Rate=rate;e.Lifetime=NumberRange.new(lifetime*.65,lifetime);e.Speed=NumberRange.new(.06,.22)
    e.SpreadAngle=Vector2.new(180,180);e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-12,12)
    e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.25,size),NumberSequenceKeypoint.new(1,0)})
    e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.22,.22),NumberSequenceKeypoint.new(.7,.5),NumberSequenceKeypoint.new(1,1)})
    e.LockedToPart=true;e.Enabled=true;e.Parent=parent;return e
end
local function beam(parent,name,a,b,color,width)
    local e=Instance.new('Beam');e.Name=name;e.Attachment0=a;e.Attachment1=b
    e.Color=ColorSequence.new(color);e.Width0=width;e.Width1=width;e.FaceCamera=true
    e.LightEmission=1;e.LightInfluence=0;e.Segments=10;e.Transparency=NumberSequence.new(.52)
    e.Parent=parent;return e
end
local function ring(fx,name,color,radius,height,speed,tilt,gap)
    local ringRecord={Radius=radius,Height=height,Speed=speed,Tilt=tilt,Gap=gap or 0,Arcs={}}
    for i=1,4 do
        local a=attachment(fx.OrbitAnchor,name..'A'..i,Vector3.zero)
        local b=attachment(fx.OrbitAnchor,name..'B'..i,Vector3.zero)
        local arc=beam(fx.Folder,name,a,b,color,.045*fx.Scale)
        arc.Transparency=NumberSequence.new(.32)
        table.insert(ringRecord.Arcs,{A=a,B=b,Beam=arc})
    end
    table.insert(fx.Rings,ringRecord)
end
local function discardDetails(r)
    if r.Fx then r.Fx.Folder:Destroy();r.Fx=nil end
    if r.MechMotion then r.MechMotion:Live(false)end -- (R153: the Mech pack's hum and sparks)
end
local function discard(r)
    discardDetails(r)
    if r.Highlight then r.Highlight:Destroy();r.Highlight=nil end
    if r.Distant then r.Distant:Destroy();r.Distant=nil;r.RayRotor=nil end
end
local function highlight(r)
    if r.Highlight then return end
    local h=Instance.new('Highlight');h.Name='PackBrightness';h.Adornee=r.Bag
    h.DepthMode=Enum.HighlightDepthMode.Occluded
    -- A light, neutral fill lifts dark imported colours without replacing the artwork.
    h.FillColor=r.Mutation.Color or Color3.fromRGB(246,248,255);h.FillTransparency=(r.MutationKey=='Gold'or r.MutationKey=='Diamond')and 1 or r.Mutation.Color and .06 or .87
    h.OutlineColor=r.Rank>1 and r.Tier.Color or WHITE;h.OutlineTransparency=r.Rank>1 and .7 or .94
    h.Parent=effectsRoot;r.Highlight=h
end
local function distant(r)
    if r.Distant then return end
    local gui=Instance.new('BillboardGui');gui.Name='DistantRarityAura';gui.Adornee=r.Root
    gui.Size=UDim2.new(6.8*r.Scale,12,6.8*r.Scale,12);gui.AlwaysOnTop=false
    gui.LightInfluence=0;gui.MaxDistance=BRIGHT_DISTANCE;gui.Parent=effectsRoot
    local holder=Instance.new('Frame');holder.Name='RayRotor';holder.BackgroundTransparency=1
    holder.Size=UDim2.fromScale(1,1);holder.AnchorPoint=Vector2.new(.5,.5);holder.Position=UDim2.fromScale(.5,.5)
    holder.Parent=gui;r.Distant=gui;r.RayRotor=holder
    local count=6+math.min(r.Rank,6)*2
    for i=1,count do
        local angle=(i-1)*math.pi*2/count
        local ray=Instance.new('Frame');ray.Name='LightRay';ray.BorderSizePixel=0
        ray.BackgroundColor3=r.Mutation.Aura or r.Tier.Color
        ray.BackgroundTransparency=.22;ray.AnchorPoint=Vector2.new(.5,.5)
        ray.Size=UDim2.fromScale(.24+(i%3)*.025,.008+r.Rank*.0013)
        ray.Position=UDim2.fromScale(.5+math.cos(angle)*.335,.5+math.sin(angle)*.335)
        ray.Rotation=math.deg(angle);ray.Parent=holder
        local fade=Instance.new('UIGradient')
        fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.94),NumberSequenceKeypoint.new(.20,.10),NumberSequenceKeypoint.new(1,1)})
        fade.Parent=ray
    end
end

local function details(r)
    if r.Fx then return end
    local fx={Rings={},Wisps={},Rays={},Storm={},StormNodes={},Satellites={},Radials={},Scale=r.Scale,SurfaceGlints={}}
    fx.Folder=Instance.new('Folder');fx.Folder.Name='PackAura_'..r.Stage..'_'..r.Rank;fx.Folder.Parent=effectsRoot
    fx.Anchor=part(fx.Folder,'AuraAnchor',Vector3.new(1.8,2.15,.7)*r.Scale);fx.Anchor.CFrame=r.Root.CFrame
    fx.OrbitAnchor=part(fx.Folder,'PackOrbitFrame',Vector3.one*.05);fx.OrbitAnchor.CFrame=AuraGeometry.Frame(r.Root.CFrame,r.OrbitBounds)
    -- Tapered beams radiate in three dimensions. No smoke-textured glow layers.
    local glowColor=r.Mutation.Aura or r.Tier.Color
    for i=1,6+math.min(r.Rank,6)*2 do
        local a=attachment(fx.OrbitAnchor,'RarityRayStart'..i,Vector3.zero)
        local b=attachment(fx.OrbitAnchor,'RarityRayEnd'..i,Vector3.zero)
        local ray=beam(fx.Folder,'RadiantRarityRay',a,b,glowColor,(.065+r.Rank*.012)*r.Scale)
        ray.Width1=.003*r.Scale;ray.Segments=1
        ray.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.88),NumberSequenceKeypoint.new(.18,.22),NumberSequenceKeypoint.new(1,1)})
        table.insert(fx.Radials,{A=a,B=b,Beam=ray,Angle=(i-1)*math.pi*2/(6+math.min(r.Rank,6)*2),Index=i})
    end
    local profile=themes[r.Stage]or themes[1]
    local biome=emitter(fx.Anchor,profile.Name,profile.Color,profile.Rate,profile.Size*r.Scale,1.6)
    biome.Acceleration=profile.Acceleration;biome.Shape=Enum.ParticleEmitterShape.Box
    biome.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
    local fill=attachment(fx.Anchor,'FrontFill',Vector3.new(0,.55,-1.75)*r.Scale)
    fx.Light=Instance.new('PointLight');fx.Light.Name='SoftPackLight';fx.Light.Color=Color3.fromRGB(242,247,255)
    fx.Light.Brightness=.65;fx.Light.Range=4.5*r.Scale;fx.Light.Shadows=false;fx.Light.Enabled=false;fx.Light.Parent=fill
    if r.Stage~=7 then
        for i=1,3 do
            local a=attachment(fx.OrbitAnchor,'BiomeOrbit'..i,Vector3.zero)
            local orbit=emitter(a,profile.Name..'Orbit',profile.Color,r.Stage==4 and 1.5 or .8,
                (r.Stage==5 and .16 or .10)*r.Scale,1.1)
            orbit.Speed=NumberRange.new(.04,.12);orbit.Acceleration=profile.Acceleration
            table.insert(fx.Satellites,{Attachment=a,Index=i})
        end
    end
    if r.MutationKey=='Gold' then
        ring(fx,'GoldenMutationHalo',r.Mutation.Aura,1.56,1.70,.4,.45,.24)
        local gild=emitter(fx.Anchor,'GoldenShine',Color3.fromRGB(255,244,188),2,.19*r.Scale,.85)
        gild.Shape=Enum.ParticleEmitterShape.Box;gild.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
    elseif r.MutationKey=='Diamond' then
        ring(fx,'DiamondMutationOrbit',r.Mutation.Aura,1.50,1.70,.3,.6,.20)
        local glitter=emitter(fx.Anchor,'DiamondShine',WHITE,2.5,.23*r.Scale,.6)
        glitter.Shape=Enum.ParticleEmitterShape.Box;glitter.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
    end
    if r.MutationKey=='Gold'or r.MutationKey=='Diamond'then
        -- Surface-scale glints, not an opaque Highlight wash. Same effect for held bags.
        for i=1,r.MutationKey=='Diamond'and 5 or 3 do
            local a=attachment(fx.Anchor,'MutationSpecular'..i,Vector3.zero)
            local glint=emitter(a,'MaterialGlint',WHITE,0,.16*r.Scale,.65)
            glint.Speed=NumberRange.new(0);glint.LightEmission=1;glint.Brightness=2
            glint.Rotation=NumberRange.new(0,90);glint.RotSpeed=NumberRange.new(0)
            table.insert(fx.SurfaceGlints,{Attachment=a,Emitter=glint,Index=i,Last=-1})
        end
    end
    if r.Stage==3 or r.Stage==5 then
        for i,pos in ipairs(ACCENTS[r.Bag:GetAttribute('PackArtKey')]or {{0,.2,-.65}})do
            local a=attachment(fx.Anchor,'GemGlintOrigin'..i,Vector3.new(table.unpack(pos))*r.Scale)
            local glint=emitter(a,r.Stage==5 and 'CrystalGlint' or 'IceGlint',WHITE,.6,.22*r.Scale,.55)
            glint.Speed=NumberRange.new(0);glint.Rotation=NumberRange.new(0,90);glint.RotSpeed=NumberRange.new(15,30)
        end
    elseif r.Stage==7 then
        for side=1,2 do
            local last
            for i=1,9 do
                local a=attachment(fx.OrbitAnchor,'ElectricOrbitNode'..side..'_'..i,Vector3.zero)
                table.insert(fx.StormNodes,{Attachment=a,Side=side,Index=i})
                if last then
                    local bolt=beam(fx.Folder,'ThunderArc',last,a,Color3.fromRGB(160,233,255),.07*r.Scale)
                    bolt.Segments=1;bolt.Transparency=NumberSequence.new(.12)
                    table.insert(fx.Storm,{Beam=bolt,Side=side})
                end
                last=a
            end
        end
    end
    if r.Rank>=2 then
        local aura=emitter(fx.Anchor,'RarityMotes',r.Tier.Color,math.min(5,1+r.Rank*.6),(.065+r.Rank*.008)*r.Scale,1.7)
        aura.Shape=Enum.ParticleEmitterShape.Box;aura.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
        aura.Acceleration=Vector3.new(0,.28,0)
    end
    if r.Rank==3 then
        ring(fx,'RareBlueHalo',r.Tier.Color,1.22,1.48,.18,0,.08)
    elseif r.Rank==4 then
        for i=1,2 do
            local p=part(fx.Folder,'EpicWisp'..i,Vector3.one*.075*r.Scale)
            p.CFrame=r.Root.CFrame
            p.Shape=Enum.PartType.Ball;p.Material=Enum.Material.Neon;p.Color=r.Tier.Color;p.Transparency=.15
            local a=attachment(p,'TrailA',Vector3.new(0,.045,0)*r.Scale)
            local b=attachment(p,'TrailB',Vector3.new(0,-.045,0)*r.Scale)
            local trail=Instance.new('Trail');trail.Name='VioletRibbon';trail.Attachment0=a;trail.Attachment1=b
            trail.Color=ColorSequence.new(r.Tier.Color);trail.LightEmission=1;trail.LightInfluence=0
            trail.Lifetime=.48;trail.MinLength=.01;trail.FaceCamera=true
            trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.28),NumberSequenceKeypoint.new(1,1)})
            trail.Parent=p;table.insert(fx.Wisps,p)
        end
    elseif r.Rank==5 then
        ring(fx,'LegendaryGoldHalo',r.Tier.Color,1.22,1.49,.10,0,0)
        for i=1,8 do
            local a=attachment(fx.OrbitAnchor,'SunRayStart'..i,Vector3.zero)
            local b=attachment(fx.OrbitAnchor,'SunRayEnd'..i,Vector3.zero)
            local ray=beam(fx.Folder,'LegendaryRay',a,b,r.Tier.Color,.032*r.Scale)
            ray.Width1=.008*r.Scale;ray.Segments=1
            table.insert(fx.Rays,{A=a,B=b,Beam=ray,Angle=(i-1)*math.pi/4})
        end
    elseif r.Rank>=6 then
        ring(fx,'MythicRoseHalo',r.Tier.Color,1.35,1.60,.32,.20,.20)
        ring(fx,'MythicPrismHalo',Color3.fromRGB(159,247,255),1.58,1.30,-.26,-.24,.30)
    end
    r.Fx=fx
end
local function setVisible(r)
    -- OpeningBag is owned by the tear animation; never override its individual pieces.
    if r.Opening then return end
    for _,p in ipairs(r.Parts or {})do if p.Parent then p.LocalTransparencyModifier=r.Hidden and 1 or 0 end end
end
local function remove(bag)
    local r=records[bag];if not r then return end;records[bag]=nil
    for _,c in ipairs(r.Connections)do c:Disconnect()end
    discard(r)
    if r.MechMotion then r.MechMotion:Reset();r.MechMotion=nil end
    if r.World and bag.Parent and r.Parts then
        for i,p in ipairs(r.Parts)do if p.Parent then p.CFrame=r.Origin*r.Frames[i]end end
    end
end
local function initialize(bag,r)
    local root=bag.PrimaryPart
    if not root or not bag:GetAttribute('CompactPackReady')then return false end
    local parts={}
    for _,p in ipairs(bag:GetDescendants())do if p:IsA('BasePart')then table.insert(parts,p)end end
    if #parts<(bag:GetAttribute('CompactPackPartCount')or math.huge)then return false end
    r.Root=root;r.Parts=parts;r.Frames={};r.Opening=bag.Name=='OpeningBag'
    r.World=bag:GetAttribute('WorldPack')==true and not r.Opening
    r.Origin=bag:GetAttribute('HoverOrigin')or root.CFrame;r.Rank=bag:GetAttribute('PackRank')or 1
    r.Stage=bag:GetAttribute('Stage')or 1;r.Scale=bag:GetAttribute('VisualScale')or 1
    r.Tier=Rules.PackTiers[r.Rank]or Rules.PackTiers[#Rules.PackTiers]
    r.MutationKey=Rules.MutationKey(bag:GetAttribute('PackMutation'));r.Mutation=Rules.PackMutations[r.MutationKey]
    r.Phase=bag:GetAttribute('HoverPhase')or 0
    for i,p in ipairs(parts)do r.Frames[i]=p:GetAttribute('PackLocalFrame')or root.CFrame:ToObjectSpace(p.CFrame)end
    if not r.Opening and bag:GetAttribute('BagVariant')=='MechLimited'then r.MechMotion=MechArt.CaptureMotion(bag)end
    r.OrbitBounds=AuraGeometry.Bounds(parts,r.Frames,r.Scale)
    r.ViewRadius=r.OrbitBounds.Half.Magnitude+r.OrbitBounds.Center.Magnitude+2*r.Scale
    for _,p in ipairs(bag:GetDescendants())do
        if p.Name=='PackRarityAura'and p:IsA('ParticleEmitter')then p.Enabled=false;p:Clear()
        elseif p.Name=='PackRarityLight'and p:IsA('PointLight')then p.Enabled=false end
    end
    r.Ready=true;r.Hidden=not r.Opening and (bag:GetAttribute('PackVisible')==false or bag:GetAttribute('RevealAt')~=nil)
    setVisible(r);return true
end
local VerityVariant=require(RS:WaitForChild('VerityCatalog')).Variant
local function track(bag)
    -- R147: the Void pack has its own motion and fx (VoidPackFx via VeiledEventClient81), so no generic rarity glints. R149: the Verity pack has no effects at all (pure yellow with her face), so it is left alone too.
    local v=bag:GetAttribute('BagVariant')
    if v=='EclipseReliquary'or v==VerityVariant then return end
    if not bag:IsA('Model')or records[bag]then return end
    local r={Bag=bag,Connections={}};records[bag]=r
    local function visibility()
        r.Hidden=bag.Name~='OpeningBag'and(bag:GetAttribute('PackVisible')==false or bag:GetAttribute('RevealAt')~=nil)
        setVisible(r);if r.Hidden then discard(r)end
    end
    for _,name in ipairs({'PackVisible','RevealAt'})do
        table.insert(r.Connections,bag:GetAttributeChangedSignal(name):Connect(visibility))
    end
    table.insert(r.Connections,bag.Destroying:Connect(function()remove(bag)end))
    initialize(bag,r)
end
for _,bag in ipairs(CollectionService:GetTagged('BiomeSeedPackVisual'))do track(bag)end
table.insert(connections,CollectionService:GetInstanceAddedSignal('BiomeSeedPackVisual'):Connect(track))
table.insert(connections,CollectionService:GetInstanceRemovedSignal('BiomeSeedPackVisual'):Connect(remove))
local function choose(camera,now,low)
    local cameraPosition=camera.CFrame.Position;local view=View.View(camera)
    local MAX_HIGHLIGHTS,MAX_DETAILS,MAX_LIGHTS,MAX_DISTANT=low and 12 or 24,low and 3 or 8,low and 1 or 4,low and 16 or 48
    local candidates={};local character=Players.LocalPlayer and Players.LocalPlayer.Character
    for bag,r in pairs(records)do
        if not r.Ready then initialize(bag,r)end
        r.Bright=false;r.Detailed=false;r.Lit=false;r.HasDistant=false
        if not r.Ready or not r.Root.Parent or not bag:IsDescendantOf(workspace)then discard(r);continue end
        local owned=character and bag:IsDescendantOf(character)
        local center=r.World and r.Origin.Position or r.Root.Position
        r.Distance=math.max(0,(cameraPosition-center).Magnitude-r.ViewRadius)
        local wasVisible=r.OnScreen
        r.OnScreen=owned or r.Opening or View.Coverage(camera,center,r.ViewRadius,view)
        if r.OnScreen and not wasVisible then r.LastMove=nil end
        if not r.Hidden and r.OnScreen and r.Distance<=240 then
            for _,p in ipairs(r.Parts)do
                if p:IsA('MeshPart')then requestMesh(p,now,bag:GetAttribute('PackArtKey')or bag.Name)end
            end
        end
        local finished=r.Opening and now-(bag:GetAttribute('RevealAt')or now)>Rules.TearSeconds+.15
        if r.Hidden or finished or not r.OnScreen or r.Distance>BRIGHT_DISTANCE then discard(r);continue end
        r.Score=r.Distance-(owned and 2000 or r.Opening and 1500 or 0)-(r.MutationKey~='None'and 100 or 0)-(r.Highlight and 3 or 0)-(r.Fx and 2 or 0)
        table.insert(candidates,r)
    end
    pumpMeshes(now)
    table.sort(candidates,function(a,b)return a.Score<b.Score end)
    local count,lights=0,0
    for i,r in ipairs(candidates)do
        r.Bright=i<=MAX_HIGHLIGHTS;r.HasDistant=i<=MAX_DISTANT
        if r.Bright and r.Distance<=DETAIL_DISTANCE and count<MAX_DETAILS then
            count+=1;r.Detailed=true
            r.Lit=r.Distance<=LIGHT_DISTANCE and lights<MAX_LIGHTS
            if r.Lit then lights+=1 end
        end
    end
    -- Release old slots before creating replacements, including Highlight slots.
    for _,r in pairs(records)do
        if not r.Bright and r.Highlight then r.Highlight:Destroy();r.Highlight=nil end
        if not r.Detailed then discardDetails(r)end
        if not r.HasDistant and r.Distant then r.Distant:Destroy();r.Distant=nil;r.RayRotor=nil end
    end
    for _,r in ipairs(candidates)do
        if r.Bright then highlight(r)end
        if r.HasDistant then distant(r);r.Distant.Enabled=not r.Detailed end
        if r.Detailed then details(r);r.Fx.Light.Enabled=r.Lit;if r.MechMotion then r.MechMotion:Live(true,low)end end
    end
end
local selectionClock,detailClock,distantClock=.25,0,0
local moveParts,moveFrames={},{}
table.insert(connections,RunService.RenderStepped:Connect(function(dt)
    local camera=workspace.CurrentCamera;if not camera then return end
    local position=camera.CFrame.Position;local now=workspace:GetServerTimeNow()
    selectionClock+=dt;detailClock+=dt;distantClock+=dt
    local select=selectionClock>=.25;if select then selectionClock=0;choose(camera,now,Fx.Low())end
    local low=Fx.Low()
    -- R153 (owner: "fix all jittery type effects"): an on-screen pack within 240 studs hovers, and a detailed one's aura / orbits / rings / rays turn,
    -- every rendered frame (they stepped at 30 Hz, 20 Hz low). Bounded by the selection: details for 8 packs (3 low) within 160 studs.
    -- What still ticks: the Highlight's faint outline pulse (+-.04, 30 Hz) and the distant rays' rotor (well under a pixel a tick); packs past 240 studs keep PackDue.
    local polish=detailClock>=(low and 1/20 or 1/30);if polish then detailClock=0 end
    local distantPolish=distantClock>=(low and 1/6 or 1/12);if distantPolish then distantClock=0 end
    table.clear(moveParts);table.clear(moveFrames)
    local function move(p,frame)moveParts[#moveParts+1]=p;moveFrames[#moveFrames+1]=frame end
    for bag,r in pairs(records)do
        if not r.Ready or not r.Root.Parent or not bag:IsDescendantOf(workspace)or r.Hidden then continue end
        local rootFrame=r.Root.CFrame;local worldMoved=false
        if r.World and(r.OnScreen and(r.Distance or math.huge)<=240 or Budget.PackDue(r.Distance or math.huge,r.OnScreen,now,r.LastMove,low))then
            local moveDt=math.min(.15,now-(r.LastMove or now-dt));r.LastMove=now
            local near=(r.Distance or math.huge)<=240
            local pos=r.Origin.Position+Vector3.new(0,.16+(near and math.sin(now*1.65+r.Phase)*.12 or 0),0)
            local target=Vector3.new(position.X,pos.Y,position.Z)
            rootFrame=(target-pos).Magnitude>.01 and CFrame.lookAt(pos,target)or CFrame.new(pos)*r.Origin.Rotation
            if near then rootFrame*=CFrame.Angles(0,0,math.sin(now*.9+r.Phase)*.025)end
            if r.LastFrame and near then rootFrame=r.LastFrame:Lerp(rootFrame,1-math.exp(-moveDt*16))end
            r.LastFrame=rootFrame
            worldMoved=true
            for i,p in ipairs(r.Parts)do if p.Parent and not(r.MechMotion and r.MechMotion.ByPart[p])then move(p,rootFrame*r.Frames[i])end end
        end
        -- The shared rig also drives held packs. Servos change joint offsets;
        -- anchored parts join this frame's batch exactly once.
        -- R128 (owner): a carried pack's aura, orbit and Mech rig follow it every frame (they trailed behind at 30 Hz).
        local carried=not r.World and r.OnScreen
        if r.MechMotion and(worldMoved or carried or(r.OnScreen and(r.Distance or math.huge)<=DETAIL_DISTANCE))then
            r.MechMotion:Step(Gui.ReducedMotionEnabled and 0 or now,rootFrame,move)
        end
        if r.Distant and not r.Detailed and distantPolish then
            r.RayRotor.Rotation=now*(r.Rank>=5 and 9 or 6)+math.deg(r.Phase)
            local pulse=1+.035*math.sin(now*1.4+r.Phase)
            r.RayRotor.Size=UDim2.fromScale(pulse,pulse)
        end
        if r.Highlight and polish then
            r.Highlight.OutlineTransparency=r.Rank==1 and .94 or math.max(.25,.80-r.Rank*.07)+.04*math.sin(now*1.4+r.Phase)
        end
        local fx=r.Fx
        if fx then
            move(fx.Anchor,rootFrame)
            local orbitFrame=AuraGeometry.Frame(rootFrame,r.OrbitBounds)
            move(fx.OrbitAnchor,orbitFrame)
            for i,p in ipairs(fx.Wisps)do
                local a=now*.9+r.Phase+(i-1)*math.pi
                move(p,orbitFrame*CFrame.new(math.cos(a)*(r.OrbitBounds.Half.X+.2*r.Scale),math.sin(a)*(r.OrbitBounds.Half.Y+.22*r.Scale),math.sin(a*2)*.5*r.Scale))
            end
            do
                for _,g in ipairs(fx.SurfaceGlints)do
                    local sweep=now*.26+r.Phase+g.Index*.19
                    local cycle=math.floor(sweep)
                    local x=math.sin(g.Index*2.4+cycle*.73)*.75
                    local y=(sweep%1)*1.9-.95
                    -- Slightly proud of the front fold so the sparkle stays visible.
                    g.Attachment.CFrame=CFrame.new(x*r.Scale,y*r.Scale,-.43*r.Scale)
                    if cycle~=g.Last then g.Last=cycle;g.Emitter:Emit(1)end
                end
                for _,ray in ipairs(fx.Radials)do
                    local a=ray.Angle+now*.12+r.Phase
                    local pulse=.5+.5*math.sin(now*1.2+r.Phase+ray.Index*.65)
                    local depth=math.sin(ray.Angle*2+now*.18)*.50
                    local direction=Vector3.new(math.cos(a),math.sin(a)*1.12,depth).Unit
                    local inner=1.10+(ray.Index%2)*.08
                    local outer=1.65+r.Rank*.10+(.14+pulse*.16)*(ray.Index%3)
                    ray.A.CFrame=CFrame.new(direction*inner*r.Scale)
                    ray.B.CFrame=CFrame.new(direction*outer*r.Scale)
                end
                for _,node in ipairs(fx.Satellites)do
                    local a=now*(r.Stage==4 and .8 or .45)+r.Phase+(node.Index-1)*math.pi*2/3
                    node.Attachment.CFrame=CFrame.new(math.cos(a)*1.22*r.Scale,
                        (.25+math.sin(a*2)*.65)*r.Scale,math.sin(a)*.85*r.Scale)
                end
                for _,node in ipairs(fx.StormNodes)do
                    local a=now*(node.Side==1 and 1.2 or -1.0)+r.Phase+(node.Index-1)*math.pi/8
                    local jag=node.Index%2==0 and .14 or -.10
                    node.Attachment.CFrame=CFrame.new(math.cos(a)*(1.22+jag)*r.Scale,
                        (math.sin(a*2)*.58+(node.Side==1 and .34 or -.34))*r.Scale,
                        math.sin(a)*(.70+jag)*r.Scale)
                end
                for _,halo in ipairs(fx.Rings)do
                    local phase=now*halo.Speed+r.Phase
                    local delta=math.pi/2-halo.Gap
                    local curve=4/3*math.tan(delta/4)
                    for i,arc in ipairs(halo.Arcs)do
                        local start=(i-1)*math.pi/2+halo.Gap/2
                        local a,alen=AuraGeometry.Ellipse(start+phase,halo,r.Scale,r.OrbitBounds)
                        local b,blen=AuraGeometry.Ellipse(start+delta+phase,halo,r.Scale,r.OrbitBounds)
                        arc.A.CFrame=a;arc.B.CFrame=b;arc.Beam.CurveSize0=curve*alen;arc.Beam.CurveSize1=curve*blen
                    end
                end
                for _,ray in ipairs(fx.Rays)do
                    local a=ray.Angle+math.sin(now*.24+r.Phase)*.06
                    local pulse=.5+.5*math.sin(now*1.3+r.Phase)
                    ray.A.CFrame=CFrame.new(math.cos(a)*1.31*r.Scale,math.sin(a)*1.57*r.Scale,.40*r.Scale)
                    ray.B.CFrame=CFrame.new(math.cos(a)*(1.49+.1*pulse)*r.Scale,math.sin(a)*(1.76+.1*pulse)*r.Scale,.40*r.Scale)
                end
                for _,arc in ipairs(fx.Storm)do
                    arc.Beam.Enabled=true
                    arc.Beam.Width0=(.065+.018*math.sin(now*8+arc.Side))*r.Scale;arc.Beam.Width1=arc.Beam.Width0
                end
            end
        end
    end
    if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveFrames,Enum.BulkMoveMode.FireCFrameChanged)end
end))
script.Destroying:Connect(function()
    stopMeshes()
    for _,c in ipairs(connections)do c:Disconnect()end
    local bags={};for bag in pairs(records)do table.insert(bags,bag)end
    for _,bag in ipairs(bags)do remove(bag)end
    effectsRoot:Destroy()
end)
