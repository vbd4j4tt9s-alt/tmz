-- R117: client-only treadmill tier effects. The server (BiomeVisuals.BuildTreadmillV131) builds static parts plus
-- DISABLED emitters, lights and beams tagged with attributes; this module turns them on and animates them only for
-- treadmills that are near, on screen and allowed by ClientFxBudget / FastMode / ReducedMotion. Gameplay never reads it.
-- R151 treadmill polish (TreadmillLook151): the belt's Texture layers (attribute BeltImage) get their image from TreadmillBeltArt151 once
-- (uploaded id, else drawn with EditableImage, else the grid texture) and scroll with the chevrons (OffsetStudsV, TreadmillScroll x the belt
-- speed: Look.Scroll); the "+N/step" label (BillboardGui, attribute HideWhileOwnerTrains) hides while its base's owner (= the local player) trains on it.
-- R153 (owner, in Studio: "the ground like the lava or the track should be moving for all treadmills not just the arrow"): the scroll lived in Animate, which only runs
-- when Policy.Animate is true (quality 2+, not FastMode, not Reduced Motion) and the belt is within 90 studs and in the view cone, while the chevrons (SpeedGainPopup) move at
-- every quality within 140 studs (90 in FastMode): in Studio ClientFxBudget drops to tier 1 after a few slow seconds, and then only the arrows moved. The scroll now has
-- its own gate, the chevrons': near (Look.Scroll.Range / RangeFast), on screen, and not with Reduced Motion; quality and FastMode no longer stop it (it is one property write
-- per layer at 20 - 30 Hz on a belt that is close). One clock per belt (record.Travel: studs at the chevrons' speed, wrapped), every layer at the same speed (Rate 1) and
-- direction, each texture's offset = base + travel x rate wrapped at its tile (no jump), a write only when the offset changed, on whatever route painted the image.
-- If Studio shows the pattern sliding sideways or against the arrows: the local player's attributes TreadmillBeltAxis ('U' / 'V') and TreadmillBeltSign (1 / -1) override
-- TreadmillLook151.Scroll.Axis / Sign live (read every .25 s).
local Fx={}
Fx.Version=117
Fx.NEAR=110      -- emitters, lights and ribbons
Fx.ANIMATE=90    -- pulses, hue, orbiters and lightning arcs
Fx.BURST=80      -- run-start burst
Fx.SCAN=1        -- seconds between base scans
Fx.CULL=.25      -- seconds between distance/visibility/budget decisions
Fx.SCROLL={Training=3.0,Idle=1.3,Sign=1,Axis='V',Range=140,RangeFast=90} -- R151: belt texture travel (studs/s) when TreadmillLook151 is not given; R153: Range = the chevrons' reach

-- quality: ClientFxBudget tier 1..3 (1 = low). FastMode forces low. ReducedMotion keeps lights and gentle particles
-- but stops every moving/flashing effect.
function Fx.Policy(quality,fast,reduced)
    quality=fast and 1 or math.clamp(math.floor(tonumber(quality)or 1),1,3)
    return {Quality=quality,Particles=quality>=2,Lights=quality>=2,Animate=quality>=2 and not reduced,Fast=fast==true,
        Bursts=quality>=2 and not reduced,Reduced=reduced==true,RateScale=(quality>=3 and 1 or .55)*(reduced and .5 or 1)}
end
function Fx.Allowed(inst,policy)
    return policy.Quality>=(tonumber(inst:GetAttribute('TreadmillFxQuality'))or 2)
end
-- Generous cone: the machine is ~20 studs long, so anything close or roughly ahead counts as visible.
function Fx.Visible(cameraFrame,position)
    local offset=position-cameraFrame.Position
    local distance=offset.Magnitude
    if distance<28 then return true,distance end
    return cameraFrame.LookVector:Dot(offset/distance)>.25,distance
end

function Fx.Collect(art)
    local lists={Emitters={},Bursts={},Lights={},Ribbons={},Arcs={},Pulse={},Spin={},Hue={},Cores={},Textures={},Labels={}}
    for _,v in ipairs(art:GetDescendants())do
        local role=v:GetAttribute('TreadmillFx')
        if v:IsA('ParticleEmitter')and role then
            table.insert(role=='Burst'and lists.Bursts or lists.Emitters,{Inst=v,Role=role,Rate=tonumber(v:GetAttribute('TreadmillFxRate'))or 0,Burst=tonumber(v:GetAttribute('TreadmillFxBurst'))or 0})
        elseif v:IsA('Light')and role=='Light'then
            table.insert(lists.Lights,{Inst=v,Brightness=tonumber(v:GetAttribute('TreadmillFxBrightness'))or v.Brightness,Flicker=v:GetAttribute('TreadmillFlicker')==true})
        elseif v:IsA('Beam')and role=='Ribbon'then
            table.insert(lists.Ribbons,{Inst=v,Speed=v.TextureSpeed})
        elseif v:IsA('Beam')and role=='Arc'then
            table.insert(lists.Arcs,{Inst=v,Curve=tonumber(v:GetAttribute('TreadmillArcCurve'))or 1,Width=v.Width0,Next=0,Off=0})
        elseif v.ClassName=='Texture'and v:GetAttribute('BeltImage')then
            table.insert(lists.Textures,{Inst=v,Rate=tonumber(v:GetAttribute('TreadmillScroll'))or 0,
                PeriodU=math.max(.01,tonumber(v.StudsPerTileU)or 1),PeriodV=math.max(.01,tonumber(v.StudsPerTileV)or 1),
                BaseU=tonumber(v.OffsetStudsU)or 0,BaseV=tonumber(v.OffsetStudsV)or 0})
        elseif v:IsA('BillboardGui')and v:GetAttribute('HideWhileOwnerTrains')then
            table.insert(lists.Labels,{Inst=v})
        end
        if v:IsA('BasePart')then
            if v:GetAttribute('TreadmillPulse')then
                table.insert(lists.Pulse,{Inst=v,Amp=v:GetAttribute('TreadmillPulse'),Speed=v:GetAttribute('TreadmillPulseSpeed')or 1,
                    Phase=v:GetAttribute('TreadmillPulsePhase')or 0,Base=v:GetAttribute('TreadmillPulseBase')or 0})
            end
            local pivot,rest=v:GetAttribute('TreadmillSpinPivot'),v:GetAttribute('TreadmillSpinRest')
            if v:GetAttribute('TreadmillSpin')and typeof(pivot)=='CFrame'and typeof(rest)=='CFrame'then
                table.insert(lists.Spin,{Inst=v,Speed=v:GetAttribute('TreadmillSpin'),Pivot=pivot,Offset=pivot:Inverse()*rest,Rest=rest})
            end
            if v:GetAttribute('TreadmillFlashCore')then table.insert(lists.Cores,{Inst=v,Base=v.Transparency})end
        end
        if v:GetAttribute('TreadmillHue')and(v:IsA('BasePart')or v:IsA('Light'))then
            table.insert(lists.Hue,{Inst=v,Phase=v:GetAttribute('TreadmillHue'),Color=v.Color})
        end
    end
    return lists
end

local function set(inst,key,value)if inst[key]~=value then inst[key]=value end end

local Controller={};Controller.__index=Controller
-- env: {Map=function()->Folder?, Camera=function()->Camera?, Quality=function()->1..3, Fast=function()->bool,
--       Reduced=function()->bool, Random=Random?, Move=function(parts,frames)?,
--       R151 (optional): Look=TreadmillLook151, Belt=TreadmillBeltArt151, UserId=function()->number, Publish=function(routes)}
function Fx.new(env)
    return setmetatable({Env=env,Records={},ScanClock=Fx.SCAN,CullClock=Fx.CULL,FrameClock=0,
        Random=env.Random or Random.new(),Policy=Fx.Policy(1,true,true)},Controller)
end
function Controller:Release(record,keepState)
    for _,c in ipairs(record.Connections)do c:Disconnect()end
    if not keepState then self:Quiet(record,true)end
end
-- Turn everything of one treadmill off and put animated parts back at rest.
function Controller:Quiet(record,all)
    local l=record.Lists;if not l then return end
    if all then
        for _,e in ipairs(l.Emitters)do if e.Inst.Parent then set(e.Inst,'Enabled',false)end end
        for _,e in ipairs(l.Lights)do if e.Inst.Parent then set(e.Inst,'Enabled',false)end end
        for _,e in ipairs(l.Ribbons)do if e.Inst.Parent then set(e.Inst,'Enabled',false)end end
        for _,e in ipairs(l.Labels)do if e.Inst.Parent then set(e.Inst,'Enabled',true)end end
    end
    if record.Animated then
        record.Animated=false
        for _,e in ipairs(l.Arcs)do if e.Inst.Parent then set(e.Inst,'Enabled',false)end end
        for _,e in ipairs(l.Pulse)do if e.Inst.Parent then set(e.Inst,'Transparency',e.Base)end end
        for _,e in ipairs(l.Cores)do if e.Inst.Parent then set(e.Inst,'Transparency',e.Base)end end
        for _,e in ipairs(l.Hue)do if e.Inst.Parent then set(e.Inst,'Color',e.Color)end end
        for _,e in ipairs(l.Lights)do if e.Inst.Parent then set(e.Inst,'Brightness',e.Brightness)end end
    end
end
function Controller:Track(base)
    local belt,art=base:FindFirstChild('Treadmill'),base:FindFirstChild('TreadmillArtV131')
    if not(belt and belt:IsA('BasePart')and art and art:GetAttribute('TreadmillFxVersion')==Fx.Version)then return end
    local record=self.Records[art]
    if record and record.Belt~=belt then self:Release(record);self.Records[art]=nil;record=nil end
    if not record then
        record={Art=art,Belt=belt,Dirty=true,Connections={},Training=belt:GetAttribute('TrainingActive')==true,
            Distance=math.huge,Visible=false,Animated=false,Scrolling=false,Travel=0,Clock=0,SpinTime=0,FlashUntil=0}
        self.Records[art]=record
        local function dirty()record.Dirty=true end
        table.insert(record.Connections,art.DescendantAdded:Connect(dirty))
        table.insert(record.Connections,art.DescendantRemoving:Connect(dirty))
        table.insert(record.Connections,belt:GetAttributeChangedSignal('TrainingActive'):Connect(function()
            local training=belt:GetAttribute('TrainingActive')==true
            local started=training and not record.Training
            record.Training=training
            if started then self:Burst(record)end
            self:Apply(record)
        end))
    end
    -- Streaming adds/removes parts; only a changed model is rescanned.
    if record.Dirty then record.Dirty=false;self:Quiet(record,false);record.Lists=Fx.Collect(art);record.Travel=0;self:Paint(record);self:Apply(record)end -- (Travel 0: the bases are the textures' offsets now)
end
function Controller:Scan()
    local seen={}
    local map=self.Env.Map();local bases=map and map:FindFirstChild('Bases')
    if bases then
        for _,base in ipairs(bases:GetChildren())do
            self:Track(base)
            local art=base:FindFirstChild('TreadmillArtV131');if art then seen[art]=true end
        end
    end
    for art,record in pairs(self.Records)do
        if not seen[art]or art.Parent==nil or record.Belt.Parent==nil then self:Release(record,art.Parent==nil);self.Records[art]=nil end
    end
end
-- R151: give every belt Texture its image (once per Texture instance; streamed-in copies are painted again from the cache).
function Controller:Paint(record)
    local belt,look=self.Env.Belt,self.Env.Look
    if not(belt and look and record.Lists)then return end
    for _,e in ipairs(record.Lists.Textures)do
        if e.Inst.Parent and e.Inst:GetAttribute('BeltRoute')==nil then
            local ok,why=pcall(belt.Paint,e.Inst,look,self.Env.Publish)
            if not ok and not self.PaintWarned then self.PaintWarned=true;warn('[R151] Treadmill belt image: '..tostring(why))end
        end
    end
end
-- R151: is this machine's owner the local player, training on it right now?
function Controller:OwnerTraining(record)
    if not(record.Training and self.Env.UserId)then return false end
    local base=record.Belt.Parent
    return base~=nil and base:GetAttribute('BaseOwnerUserId')==self.Env.UserId()
end
function Controller:Burst(record)
    local policy=self.Policy
    if not policy.Bursts or record.Distance>Fx.BURST or not record.Visible or not record.Lists then return end
    for _,e in ipairs(record.Lists.Bursts)do
        if e.Inst.Parent and Fx.Allowed(e.Inst,policy)then e.Inst:Emit(math.max(1,math.floor(e.Burst*policy.RateScale+.5)))end
    end
    record.FlashUntil=record.Clock+.6
end
-- Enable/disable decisions; runs at the cull rate and on training changes, writes only on change.
function Controller:Apply(record)
    local l=record.Lists;if not l then return end
    local policy=self.Policy
    local near=record.Distance<=Fx.NEAR and record.Visible
    for _,e in ipairs(l.Emitters)do
        local v=e.Inst
        if v.Parent then
            local on=near and policy.Particles and Fx.Allowed(v,policy)and(e.Role=='Ambient'or(e.Role=='Training'and record.Training))
            set(v,'Enabled',on)
            if on then set(v,'Rate',e.Rate*policy.RateScale)end
        end
    end
    for _,e in ipairs(l.Lights)do
        if e.Inst.Parent then set(e.Inst,'Enabled',record.Distance<=Fx.NEAR and policy.Lights and Fx.Allowed(e.Inst,policy))end
    end
    for _,e in ipairs(l.Ribbons)do
        local v=e.Inst
        if v.Parent then
            set(v,'Enabled',near and policy.Particles and Fx.Allowed(v,policy))
            set(v,'TextureSpeed',policy.Reduced and 0 or e.Speed)
        end
    end
    local hide=self:OwnerTraining(record)
    for _,e in ipairs(l.Labels)do if e.Inst.Parent then set(e.Inst,'Enabled',not hide)end end
    local animate=policy.Animate and record.Visible and record.Distance<=Fx.ANIMATE
    if not animate and record.Animated then self:Quiet(record,false)end
    record.Animated=animate
    -- R153: the belt's own gate (the chevrons': near, any quality, FastMode included; on screen; not with Reduced Motion)
    local scroll=self.Env.Look and self.Env.Look.Scroll or Fx.SCROLL
    local range=policy.Fast and(scroll.RangeFast or Fx.SCROLL.RangeFast)or(scroll.Range or Fx.SCROLL.Range)
    record.Scrolling=#l.Textures>0 and not policy.Reduced and record.Visible and record.Distance<=range
end
function Controller:Cull()
    local env=self.Env
    self.Policy=Fx.Policy(env.Quality(),env.Fast(),env.Reduced())
    if env.Tune then -- R153: the player's TreadmillBeltAxis / TreadmillBeltSign attributes (Studio: flip a belt that runs sideways or backwards)
        local axis,sign=env.Tune()
        self.Axis=(axis=='U'or axis=='V')and axis or nil;self.Sign=(sign==1 or sign==-1)and sign or nil
    end
    local camera=env.Camera()
    for _,record in pairs(self.Records)do
        if camera and record.Belt.Parent then
            record.Visible,record.Distance=Fx.Visible(camera.CFrame,record.Belt.Position)
        else record.Visible,record.Distance=false,math.huge end
        local training=record.Belt:GetAttribute('TrainingActive')==true
        if training~=record.Training then record.Training=training end
        self:Apply(record)
    end
end
-- Per-frame work only for treadmills that passed the cull (near, on screen, motion allowed).
function Controller:Animate(record,dt)
    local l=record.Lists;local rng=self.Random
    record.Clock+=dt
    local training=record.Training;local t=record.Clock
    local tempo=training and 1.8 or 1
    record.SpinTime+=dt*(training and 1.6 or 1)
    for _,e in ipairs(l.Pulse)do
        local v=e.Inst
        if v.Parent then
            local wave=.5+.5*math.sin(t*e.Speed*tempo+e.Phase)
            local alpha=math.clamp(e.Base+e.Amp*(training and 1 or .7)*wave,0,1)
            if math.abs(v.Transparency-alpha)>.01 then v.Transparency=alpha end
        end
    end
    for _,e in ipairs(l.Hue)do
        if e.Inst.Parent then e.Inst.Color=Color3.fromHSV((t*(training and .16 or .08)+e.Phase)%1,.5,1)end
    end
    if #l.Spin>0 then
        local parts,frames={},{}
        local beltFrame=record.Belt.CFrame
        for _,e in ipairs(l.Spin)do
            if e.Inst.Parent and Fx.Allowed(e.Inst,self.Policy)then
                table.insert(parts,e.Inst)
                table.insert(frames,beltFrame*e.Pivot*CFrame.Angles(0,record.SpinTime*e.Speed,0)*e.Offset)
            end
        end
        if #parts>0 then self.Env.Move(parts,frames)end
    end
    local arcOn=false
    for _,e in ipairs(l.Arcs)do
        local v=e.Inst
        if v.Parent and Fx.Allowed(v,self.Policy)then
            if v.Enabled and t>=e.Off then v.Enabled=false
            elseif not v.Enabled and t>=e.Next then
                local bend=e.Curve*(.4+rng:NextNumber()*1.4)*(rng:NextNumber()<.5 and -1 or 1)
                v.CurveSize0=bend;v.CurveSize1=-bend*(.3+rng:NextNumber())
                v.Width0=e.Width*(.6+rng:NextNumber()*.8)
                v.Enabled=true;e.Off=t+.06+rng:NextNumber()*.12
                e.Next=e.Off+(training and(.15+rng:NextNumber()*.6)or(1+rng:NextNumber()*2.5))
            end
            arcOn=arcOn or v.Enabled
        end
    end
    for _,e in ipairs(l.Cores)do if e.Inst.Parent then set(e.Inst,'Transparency',arcOn and .12 or e.Base)end end
    local flash=t<record.FlashUntil and 1+2*(record.FlashUntil-t)/.6 or 1
    for _,e in ipairs(l.Lights)do
        local v=e.Inst
        if v.Parent and v.Enabled then
            local b=e.Brightness*(training and 1.35 or 1)*flash
            if e.Flicker then b*=arcOn and 1.8 or(.85+.15*math.sin(t*7))end
            if math.abs(v.Brightness-b)>.02 then v.Brightness=b end
        end
    end
end
-- R153: the belt's textures travel with the chevrons: one clock per belt (record.Travel, studs at 3.0 training / 1.3 idle, the chevrons' speed), every layer's offset
-- = its base + travel x its rate, wrapped at its tile (the pattern tiles there: no jump), written only when it changed. Axis: which texture axis runs along the belt.
function Controller:Scroll(record,dt)
    local l=record.Lists;local scroll=self.Env.Look and self.Env.Look.Scroll or Fx.SCROLL
    local axis,sign=self.Axis or scroll.Axis or'V',self.Sign or scroll.Sign or 1
    local speed=record.Training and scroll.Training or scroll.Idle
    record.Travel=(record.Travel+dt*speed)%100000
    for _,e in ipairs(l.Textures)do
        local v=e.Inst
        if v.Parent then
            if e.Axis~=axis then -- (the axis was switched: the other one goes back to its base)
                if e.Axis then local old='OffsetStuds'..e.Axis;if v[old]~=e['Base'..e.Axis]then v[old]=e['Base'..e.Axis]end end
                e.Axis=axis;e.Wrote=nil
            end
            local period,base=e['Period'..axis],e['Base'..axis]
            local offset=(base+record.Travel*sign*e.Rate)%period
            if e.Wrote~=offset then e.Wrote=offset;v['OffsetStuds'..axis]=offset end
        end
    end
end
function Controller:Step(dt)
    if type(dt)~='number'or dt~=dt or dt<0 then return end
    self.ScanClock+=dt;self.CullClock+=dt;self.FrameClock+=dt
    if self.ScanClock>=Fx.SCAN then self.ScanClock=0;self:Scan()end
    if self.CullClock>=Fx.CULL then self.CullClock=0;self:Cull()end
    -- R153 (owner: "reduce jitter in effects"): every frame (was 1/30 s, 1/20 s below tier 3). Only records the cull passed are stepped: Scrolling (near, on screen,
    -- no Reduced Motion) and Animated (quality 2+, within Fx.ANIMATE, on screen); offsets / transparencies are still written only when they change.
    local step=math.min(self.FrameClock,.1);self.FrameClock=0
    for _,record in pairs(self.Records)do
        if record.Lists and record.Belt.Parent then
            if record.Scrolling then self:Scroll(record,step)end
            if record.Animated then self:Animate(record,step)end
        end
    end
end
function Controller:Destroy()
    for art,record in pairs(self.Records)do self:Release(record);self.Records[art]=nil end
end

-- Wires the controller to the live client. Returns a stop function.
function Fx.Start(player)
    local Run=game:GetService('RunService');local Gui=game:GetService('GuiService')
    local Budget=require(script.Parent:WaitForChild('ClientFxBudget'))
    local function optional(name)
        local ok,module=pcall(function()local m=script.Parent:WaitForChild(name,10);return m and require(m)end)
        if not ok then warn('[R151] '..name..' unavailable: '..tostring(module))end
        return ok and module or nil
    end
    local look,beltArt=optional('TreadmillLook151'),optional('TreadmillBeltArt151')
    local controller=Fx.new({
        Map=function()return workspace:FindFirstChild('ChestChaseMap')end,
        Camera=function()return workspace.CurrentCamera end,
        Quality=function()return Budget.Get()end,
        Fast=function()return player:GetAttribute('FastMode')==true end,
        Reduced=function()local ok,value=pcall(function()return Gui.ReducedMotionEnabled end);return ok and value==true end,
        Move=function(parts,frames)workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end,
        -- R151: the belt images and the label hide. A missing module only switches those off.
        Look=look,Belt=beltArt,UserId=function()return player.UserId end,
        Tune=function()return player:GetAttribute('TreadmillBeltAxis'),player:GetAttribute('TreadmillBeltSign')end,
        Publish=function(routes)player:SetAttribute('TreadmillBeltTextures',routes)end,
    })
    local connection=Run.Heartbeat:Connect(function(dt)controller:Step(dt)end)
    return function()connection:Disconnect();controller:Destroy()end,controller
end
return Fx
