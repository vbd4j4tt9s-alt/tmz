do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- Slowly drifting local clouds and server-timed lightning presentation.
local Run=game:GetService('RunService')
local Storage=game:GetService('ReplicatedStorage')
local Fx=require(Storage.ClientFxBudget)
local Weather=require(Storage.WeatherPresentation)
local Lightning=require(Storage.WeatherLightning)
local Gui=game:GetService('GuiService')
local Config=require(Storage:WaitForChild('StormConfig'))
local Sfx=require(Storage:WaitForChild('LocalSfx'))
local assets=Storage:FindFirstChild('ChestChaseVisualAssets')
local cloudTemplate=assets and assets:FindFirstChild('DarkCloud')
if not cloudTemplate then warn('[V104] Cloud model missing; lightning warnings remain active.');end
local remotes=Storage:WaitForChild('ChestChaseRemotes',20)
local state=remotes and remotes:WaitForChild('StormState',20)
if not state then return end
Sfx.Preload({Config.ThunderId,Config.RumbleId})
local folder=Instance.new('Folder');folder.Name='_StormVisualsV103';folder.Parent=workspace
local bolts=Lightning.New(folder)
local frameClock,cloudClock,cloudTier=0,0,nil
local moveParts,moveFrames={},{}
local ground,clouds,warning=nil,{},nil
local groundCheck,lastWarning,lastImpact=0,0,0
local impacts={}
local bloom=Instance.new('BloomEffect');bloom.Name='LightningBloomV104'
bloom.Intensity=.70;bloom.Size=24;bloom.Threshold=1.5;bloom.Enabled=false
local function part(name,size,frame,color)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=folder
    return p
end
local function cloud(index,low)
    local anchor=part(low and 'Ground mist' or 'Cloud anchor',Vector3.one,CFrame.new(),Color3.new(1,1,1));anchor.Transparency=1
    if not low and cloudTemplate then
        local model=cloudTemplate:Clone();model.Name='Dark storm cloud';model.Parent=folder
        local parts={}
        for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
            p.Color=Color3.fromRGB(49,55,71);p.Transparency=1-(1-p.Transparency)*Config.CloudOpacity
            p.Material=Enum.Material.SmoothPlastic;p.CastShadow=false;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
            table.insert(parts,{Part=p,Rest=p.CFrame})
        end end
        return {Anchor=anchor,Model=model,Parts=parts,Index=index,Low=false,Started=true}
    end
    local emitter=Instance.new('ParticleEmitter');emitter.Name='Cloud mist'
    emitter.Texture='rbxasset://textures/particles/smoke_main.dds'
    emitter.Color=ColorSequence.new(low and Color3.fromRGB(205,213,227)or Color3.fromRGB(87,94,115))
    emitter.Size=NumberSequence.new(low and 55 or 68)
    emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,.58),
        NumberSequenceKeypoint.new(.75,.58),NumberSequenceKeypoint.new(1,1)})
    emitter.Lifetime=NumberRange.new(12);emitter.Rate=.25;emitter.Speed=NumberRange.new(0)
    emitter.Rotation=NumberRange.new(-12,12);emitter.RotSpeed=NumberRange.new(-1,1)
    emitter.LockedToPart=true;emitter.LightInfluence=.25;emitter.LightEmission=.08;emitter.Parent=anchor
    return {Anchor=anchor,Emitter=emitter,Index=index,Low=low,Started=false}
end
local function clearWarning()
    if warning then warning.Anchor:Destroy();warning=nil end
end
local function clearClouds()
    for _,c in ipairs(clouds)do c.Anchor:Destroy();if c.Model then c.Model:Destroy()end end
    table.clear(clouds)
end
local function locateGround()
    local map=workspace:FindFirstChild('ChestChaseMap')
    local obby=map and map:FindFirstChild('Obby')
    local biomes=obby and obby:FindFirstChild('Biomes')
    if not biomes then return nil end
    for _,biome in ipairs(biomes:GetChildren())do if biome:GetAttribute('Stage')==Config.Stage then
        local floor=biome:FindFirstChild('BiomeGround_'..Config.Stage)
        if floor and floor:IsA('BasePart')then return floor end
    end end
end
-- R149: the keyboard's key tops stand above the (hidden) floor, so the ring / impact drawn at floor height would be under the keys:
-- lift them onto the key tops wherever the keyboard is drawn (KeyboardSurface149; no lift off the keyboard).
local function onKeys(center)
    if not ground then return center end
    local ok,lift=pcall(function()return require(Storage.KeyboardSurface149).Lift(center.X,center.Z,ground.Position.Y+ground.Size.Y/2)end)
    return ok and lift>0 and center+Vector3.new(0,lift,0)or center
end
local function makeWarning(id,center,radius)
    clearWarning();center=onKeys(center)
    local anchor=part('Lightning warning',Vector3.new(radius*2,.06,radius*2),CFrame.new(center),Color3.new(1,0,0))
    anchor.Transparency=1
    local gui=Instance.new('SurfaceGui');gui.Name='Strike area';gui.Face=Enum.NormalId.Top
    gui.CanvasSize=Vector2.new(256,256);gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.Parent=anchor
    local outer=Instance.new('Frame');outer.Name='Outer ring';outer.AnchorPoint=Vector2.new(.5,.5)
    outer.Position=UDim2.fromScale(.5,.5);outer.Size=UDim2.fromScale(1,1)
    outer.BackgroundTransparency=1;outer.BorderSizePixel=0;outer.Parent=gui
    local curve=Instance.new('UICorner');curve.CornerRadius=UDim.new(1,0);curve.Parent=outer
    local stroke=Instance.new('UIStroke');stroke.Thickness=5;stroke.Color=Color3.fromRGB(255,24,36);stroke.Transparency=Config.WarningRingTransparency;stroke.Parent=outer
    local fill=Instance.new('Frame');fill.Name='Charge';fill.AnchorPoint=Vector2.new(.5,.5);fill.Position=UDim2.fromScale(.5,.5)
    fill.Size=UDim2.fromScale(0,0);fill.BackgroundColor3=Color3.fromRGB(255,24,36);fill.BackgroundTransparency=Config.WarningFillTransparency
    fill.BorderSizePixel=0;fill.Parent=outer
    local rounded=Instance.new('UICorner');rounded.CornerRadius=UDim.new(1,0);rounded.Parent=fill
    local edge=Instance.new('UIStroke');edge.Color=stroke.Color;edge.Thickness=3;edge.Transparency=.15;edge.Parent=fill
    warning={Id=id,Anchor=anchor,Fill=fill}
end
local function groundImpact(center,radius,now)
    local anchor=part('Impact ring',Vector3.new(radius*2,.05,radius*2),CFrame.new(center+Vector3.new(0,.06,0)),Color3.new(1,1,1))
    anchor.Transparency=1
    local gui=Instance.new('SurfaceGui');gui.Face=Enum.NormalId.Top;gui.CanvasSize=Vector2.new(256,256)
    gui.LightInfluence=0;gui.Parent=anchor
    local ring=Instance.new('Frame');ring.AnchorPoint=Vector2.new(.5,.5);ring.Position=UDim2.fromScale(.5,.5)
    ring.Size=UDim2.fromScale(.12,.12);ring.BackgroundTransparency=1;ring.BorderSizePixel=0;ring.Parent=gui
    local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(1,0);corner.Parent=ring
    local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(197,228,255);stroke.Thickness=8;stroke.Parent=ring
    local disc=part('Ground flash',Vector3.new(.09,6,6),CFrame.new(center+Vector3.new(0,.08,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(222,239,255))
    disc.Shape=Enum.PartType.Cylinder;disc.Material=Enum.Material.Neon
    local burst=Instance.new('ParticleEmitter');burst.Name='Impact sparks'
    burst.Texture='rbxasset://textures/particles/sparkles_main.dds'
    burst.Color=ColorSequence.new(Color3.fromRGB(226,240,255),Color3.fromRGB(108,174,255))
    burst.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,0)})
    burst.Lifetime=NumberRange.new(.25,.55);burst.Speed=NumberRange.new(12,23)
    burst.SpreadAngle=Vector2.new(60,60);burst.Acceleration=Vector3.new(0,-30,0)
    -- R123: unlit sparks that fade out instead of vanishing at full opacity; fewer under Reduced Motion.
    burst.LightEmission=1;burst.LightInfluence=0
    burst.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.6,.25),NumberSequenceKeypoint.new(1,1)})
    burst.Rate=0;burst.Parent=anchor;burst:Emit((Fx.Low()or Gui.ReducedMotionEnabled)and 10 or 22)
    table.insert(impacts,{At=now,Anchor=anchor,Ring=ring,Stroke=stroke,Disc=disc})
end
local function lightning(id,center,radius,now)
    center=onKeys(center)
    local top=center+Vector3.new(0,Config.CloudHeight,0);local closest=math.huge
    for _,c in ipairs(clouds)do if not c.Low then
        local p=c.Anchor.Position;local d=(Vector3.new(p.X,center.Y,p.Z)-center).Magnitude
        if d<closest then top=p;closest=d end
    end end
    bolts:Strike(top,center,now,Fx.Low(),Gui.ReducedMotionEnabled,id*97)
    groundImpact(center,radius,now)
    Sfx.Play(Config.ThunderId,center,Config.ThunderVolume,.90,14)
end
local function updateImpacts(now)
    local camera=workspace.CurrentCamera;if bloom.Parent~=camera then bloom.Parent=camera end
    local lit=bolts:Step(now)and not Gui.ReducedMotionEnabled
    if bloom.Enabled~=lit then bloom.Enabled=lit end
    for i=#impacts,1,-1 do
        local item=impacts[i];local t=math.clamp((now-item.At)/Config.ImpactSeconds,0,1)
        if t>=1 then item.Anchor:Destroy();item.Disc:Destroy();table.remove(impacts,i)
        else
            local spread=1-(1-t)^2
            item.Ring.Size=UDim2.fromScale(.12+.88*spread,.12+.88*spread)
            item.Stroke.Transparency=t;item.Stroke.Thickness=8-5*t
            item.Disc.Transparency=math.clamp(t*3.2,0,1)
        end
    end
end
local connection
connection=Run.RenderStepped:Connect(function(dt)
    if not folder.Parent or not script.Parent then connection:Disconnect();clearWarning();clearClouds();bolts:Destroy();folder:Destroy();bloom:Destroy();return end
    frameClock+=dt;cloudClock+=dt;if frameClock<.05 then return end
    dt=frameClock;frameClock=0;updateImpacts(workspace:GetServerTimeNow())
    groundCheck-=dt
    if groundCheck<=0 then
        groundCheck=1
        local currentAssets=Storage:FindFirstChild('ChestChaseVisualAssets')
        local template=currentAssets and currentAssets:FindFirstChild('DarkCloud')
        if template~=cloudTemplate then clearClouds();cloudTemplate=template end
        local found=locateGround()
        if found~=ground then clearClouds();clearWarning();ground=found end
    end
    local camera=workspace.CurrentCamera
    if not camera or not ground or not ground.Parent then clearWarning();return end
    local now=workspace:GetServerTimeNow()
    local offset=ground.CFrame:PointToObjectSpace(camera.CFrame.Position)
    local distance=Vector3.new(math.max(0,math.abs(offset.X)-ground.Size.X/2),0,math.max(0,math.abs(offset.Z)-ground.Size.Z/2)).Magnitude
    local nearby=distance<Config.ViewDistance
    local tier=Fx.Get();if tier~=cloudTier then clearClouds();cloudTier=tier;cloudClock=1 end
    if nearby and #clouds==0 then
        for i=1,math.min(Config.CloudCount,tier)do table.insert(clouds,cloud(i,false))end
        for i=1,tier-1 do table.insert(clouds,cloud(i,true))end
    elseif not nearby and #clouds>0 then clearClouds()end
    if cloudClock+1e-5>=Weather.CloudInterval(tier)then
    cloudClock=0;table.clear(moveParts);table.clear(moveFrames)
    local frame=ground.CFrame*CFrame.new(0,ground.Size.Y/2,0)
    for _,c in ipairs(clouds)do
        local i=c.Index
        local z=math.sin(now*Config.CloudSpeed/math.max(ground.Size.Z*.5,1)+i*math.pi*2/Config.CloudCount)*ground.Size.Z*.42
        local x=c.Low and (i%2==0 and 1 or -1)*(ground.Size.X/2-3)
            or math.sin(i*2.4)*ground.Size.X*.32+math.sin(now*.025+i)*7
        local y=c.Low and (7+math.sin(now*.09+i)*2)or (Config.CloudHeight+math.sin(now*.06+i)*3)
        c.Anchor.CFrame=frame*CFrame.new(x,y,z)
        if c.Parts then
            for _,p in ipairs(c.Parts)do table.insert(moveParts,p.Part);table.insert(moveFrames,c.Anchor.CFrame*p.Rest)end
        end
        if not c.Started then c.Started=true;c.Emitter:Emit(2)end
    end
    if #moveParts>0 then workspace:BulkMoveTo(moveParts,moveFrames,Enum.BulkMoveMode.FireCFrameChanged)end
    end
    local phase,id=state:GetAttribute('Phase'),state:GetAttribute('StrikeId')
    local center,radius=state:GetAttribute('Center'),state:GetAttribute('Radius')
    local startAt,hitAt=state:GetAttribute('StartAt'),state:GetAttribute('HitAt')
    if type(id)~='number'or typeof(center)~='Vector3'or type(radius)~='number'or radius<=0
        or type(startAt)~='number'or type(hitAt)~='number'or math.abs(hitAt-startAt-Config.WarningSeconds)>.01 then clearWarning();return end
    if phase=='Warning' and now<hitAt and nearby then
        if not warning or warning.Id~=id then makeWarning(id,center,radius)end
        local progress=math.clamp((now-startAt)/Config.WarningSeconds,0,1)
        warning.Fill.Size=UDim2.fromScale(progress,progress)
        if id>lastWarning then lastWarning=id;Sfx.Play(Config.RumbleId,center,Config.RumbleVolume,1,10)end
    else clearWarning()end
    if phase=='Impact' and id>lastImpact and now>=hitAt then
        lastImpact=id
        if nearby and now-hitAt<.6 then lightning(id,center,radius,now)end
    end
end)
script.Destroying:Connect(function()if connection then connection:Disconnect()end;bolts:Destroy();folder:Destroy();bloom:Destroy();table.clear(impacts)end)
