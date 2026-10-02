-- Local weather around the view, behind UI. Never changes music or gameplay.
-- R128 (owner): particles live in the world (AmbientParticleField128); only the birth box follows the camera.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Storage=game:GetService('ReplicatedStorage')
local Styles=require(Storage:WaitForChild('BiomeWeatherConfig'))
local Fx=require(Storage.ClientFxBudget)
local Field=require(Storage:WaitForChild('AmbientParticleField128'));local field=Field.new()
local mobile=game:GetService('UserInputService').TouchEnabled
local player=Players.LocalPlayer
local folder=Instance.new('Folder');folder.Name='_BiomeWeatherV105';folder.Parent=workspace
local anchor=Instance.new('Part');anchor.Name='Weather around camera';anchor.Size=Vector3.new(34,.2,30)
anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
anchor.CastShadow=false;anchor.Parent=folder
local emitter=Instance.new('ParticleEmitter');emitter.Enabled=false;emitter.Rate=0
emitter.LockedToPart=false;emitter.VelocityInheritance=0;emitter.LightInfluence=.25
emitter.Rotation=NumberRange.new(0,360);emitter.Parent=anchor
local mist=Instance.new('ParticleEmitter');mist.Name='Jungle mist';mist.Enabled=false
mist.Texture='rbxasset://textures/particles/smoke_main.dds';mist.Color=ColorSequence.new(Color3.fromRGB(143,177,146))
mist.Size=NumberSequence.new(8);mist.Lifetime=NumberRange.new(3);mist.Rate=1.5
mist.Speed=NumberRange.new(.8);mist.LockedToPart=false;mist.VelocityInheritance=0;mist.LightInfluence=.8
mist.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.94),NumberSequenceKeypoint.new(1,1)})
mist.Parent=anchor
local stage,style=0,nil
local frameClock=0
local currentCamera=nil
local alive=true;local elapsed=0;local clock=0;local blend=0;local lastPosition;local drift=0;local lastRate=-1;local lastAnchor
local function setStage(nextStage)
    if nextStage==stage then return end
    stage=nextStage;style=Styles[stage];blend=0;drift=1;lastRate=-1;lastAnchor=nil
    emitter:Clear();mist:Clear();emitter.Enabled=false;mist.Enabled=false
    if not style then return end
    emitter.LockedToPart=false;emitter.Name=style.Name;emitter.Texture=style.Texture;emitter.Color=ColorSequence.new(style.Color)
    emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,style.Size*.65),NumberSequenceKeypoint.new(.35,style.Size),NumberSequenceKeypoint.new(1,style.Size*.5)})
    emitter.Lifetime=NumberRange.new(style.Life*.75,style.Life);emitter.Speed=NumberRange.new(style.Speed*.8,style.Speed*1.2)
    emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,style.Fade),
        NumberSequenceKeypoint.new(.8,style.Fade),NumberSequenceKeypoint.new(1,1)})
    emitter.LightEmission=style.Glow;emitter.EmissionDirection=style.Falling and Enum.NormalId.Bottom or Enum.NormalId.Top
    emitter.SpreadAngle=style.Falling and Vector2.new(8,8)or Vector2.new(70,70)
    emitter.RotSpeed=style.Swirl and NumberRange.new(35,75)or style.Rain and NumberRange.new(0)or NumberRange.new(-25,25)
    if style.Rain then emitter.Acceleration=Vector3.new(5,-10,1)end
    emitter.Rotation=style.Rain and NumberRange.new(0)or NumberRange.new(0,360)
    emitter.Squash=NumberSequence.new(style.Rain and -.8 or 0)
    emitter.Orientation=style.Rain and Enum.ParticleOrientation.VelocityParallel or Enum.ParticleOrientation.FacingCamera
    emitter.Drag=style.Falling and 0 or .5
    emitter.Enabled=true;mist.Enabled=style.Mist==true
end
local function locate(camera)
    if not alive or not camera or(Storage:GetAttribute('GlobalWeather')or'Clear')~='Clear'then return 0 end
    local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    local map=workspace:FindFirstChild('ChestChaseMap')
    if not root or not humanoid or humanoid.Health<=0 or not map then return 0 end
    local point=root.Position
    if math.abs(point.X)>(tonumber(map:GetAttribute('FieldWidth'))or 180)/2 or point.Y< -10 or point.Y>150 then return 0 end
    for id in pairs(Styles)do
        local a,b=map:GetAttribute('BiomeStartZ_'..id),map:GetAttribute('BiomeEndZ_'..id)
        if type(a)=='number'and type(b)=='number'and point.Z>=a and point.Z<b then return id end
    end
    return 0
end
local connections={}
table.insert(connections,player.CharacterRemoving:Connect(function()alive=false;setStage(0);lastPosition=nil end))
table.insert(connections,player.CharacterAdded:Connect(function()alive=true;elapsed=1;lastPosition=nil end))
table.insert(connections,Run.RenderStepped:Connect(function(dt)
    -- R128: the birth box follows the camera every frame, led ahead of a runner; particles already born stay put.
    local view=workspace.CurrentCamera
    if view and style and view==currentCamera then
        local velocity=Field.Track(field,view.CFrame.Position,dt)
        local lead,maxLead=Field.Lead(style.Height,style.Speed,style.Falling)
        local target=Field.Target(view.CFrame,9,style.Height,velocity,lead,maxLead)
        if not lastAnchor or(target-lastAnchor).Magnitude>.01 then anchor.CFrame=CFrame.new(target);lastAnchor=target end
    end
    frameClock+=dt;local tier=Fx.Get();if frameClock<(tier==1 and .1 or .05)then return end
    dt=frameClock;frameClock=0;clock+=dt;elapsed+=dt
    local camera=workspace.CurrentCamera
    if camera~=currentCamera then currentCamera=camera;emitter:Clear();mist:Clear();lastPosition=nil;elapsed=1;Field.Reset(field)end
    if elapsed>=.1 then elapsed=0;setStage(locate(camera))end
    if not camera or not style then return end
    local p=camera.CFrame.Position
    if lastPosition and (p-lastPosition).Magnitude>150 then emitter:Clear();mist:Clear();Field.Reset(field)end -- teleport (not fast running): drop the old field
    lastPosition=p
    blend=math.min(1,blend+dt*2);local cap=mobile and 90 or math.huge;local rate=math.min(cap,style.Rate*(tier==1 and .65 or tier==2 and .85 or 1))*blend
    local fog=style.Mist==true and tier>1;if mist.Enabled~=fog then mist.Enabled=fog end
    if rate~=lastRate then emitter.Rate=rate;lastRate=rate end
    drift+=dt;if drift<1/20 or style.Rain then return end;drift=0
    if style.Swirl then
        emitter.Acceleration=Vector3.new(math.sin(clock*.8)*9,math.sin(clock*1.1)*1.5,math.cos(clock*.8)*7)
    elseif style.Falling then emitter.Acceleration=Vector3.new(math.sin(clock*.5)*1.8,-1,0)
    else emitter.Acceleration=Vector3.new(math.sin(clock*.4),.2,math.cos(clock*.5))end
end))
script.Destroying:Connect(function()
    for _,connection in ipairs(connections)do connection:Disconnect()end
    emitter:Clear();mist:Clear();folder:Destroy()
end)
