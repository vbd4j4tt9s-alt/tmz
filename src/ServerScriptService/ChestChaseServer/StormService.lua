-- One server-owned strike at a time. Client messages never cause a hit.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Storage=game:GetService('ReplicatedStorage')
local Config=require(Storage:WaitForChild('StormConfig'))
local Area=require(Storage:WaitForChild('StormArea'))
local Storm={};Storm.__index=Storm
function Storm.new(map,chase)
    local self=setmetatable({Map=map,Chase=chase,Random=Random.new(),Serial=0,NextAt=0},Storm)
    local remotes=Storage:WaitForChild(chase.Config.RemoteFolderName or 'ChestChaseRemotes')
    local state=remotes:FindFirstChild('StormState')
    if state then assert(state:IsA('Folder'),'StormState must be a Folder')
    else state=Instance.new('Folder');state.Name='StormState';state.Parent=remotes end
    self.State=state
    state:SetAttribute('Phase','Idle');state:SetAttribute('StrikeId',0)
    return self
end
function Storm:_area()
    local biomes=self.Map.ObbyFolder:FindFirstChild('Biomes')
    if not biomes then return nil end
    local ground,found
    for _,biome in ipairs(biomes:GetChildren())do if biome:GetAttribute('Stage')==Config.Stage then
        if found then return nil end
        found=true
        ground=biome:FindFirstChild('BiomeGround_'..Config.Stage)
    end end
    if not ground or not ground:IsA('BasePart') or math.abs(ground.CFrame.UpVector.Y-1)>.001 then return nil end
    local area={Ground=ground,Frame=ground.CFrame*CFrame.new(0,ground.Size.Y/2,0),
        HalfX=ground.Size.X/2,HalfZ=ground.Size.Z/2,EdgeMargin=Config.EdgeMargin,Exclusions={}}
    local count=0
    for _,seed in ipairs(self.Map.Chests)do if seed.Stage==Config.Stage then
        if not seed.Body or not seed.Body:IsDescendantOf(workspace)then return nil end
        count+=1
        table.insert(area.Exclusions,{Position=seed.Body.Position,Radius=Config.SeedClearance})
    end end
    if count~=5 then return nil end
    local guardian=self.Map.GuardiansByStage[Config.Stage]
    if not guardian or not guardian.Parent then return nil end
    -- Cache is populated by ChaseService startup from the resting keeper, before movement.
    local home=self.Chase.GuardianHomeCFrames[Config.Stage]
    if typeof(home)~='CFrame'then return nil end
    table.insert(area.Exclusions,{Position=home.Position,Radius=Config.BirdClearance})
    -- A dropped Forest Pack can be in Storm: location, not origin Stage, matters.
    for _,drop in pairs(self.Chase.Drops)do
        if not drop.Claimed and drop.Model and drop.Model.Parent then
            table.insert(area.Exclusions,{Position=drop.Position,Radius=Config.SeedClearance})
        end
    end
    return area
end
function Storm:_publish(phase,strike,now)
    local state=self.State
    if strike then
        state:SetAttribute('Center',strike.Center);state:SetAttribute('Radius',Config.Radius)
        state:SetAttribute('StartAt',strike.StartAt);state:SetAttribute('HitAt',strike.HitAt)
        state:SetAttribute('GroundFrame',strike.Frame)
    end
    state:SetAttribute('Phase',phase);state:SetAttribute('ChangedAt',now)
    -- Revision is the final write; clients may also rebuild from current attributes.
    state:SetAttribute('StrikeId',self.Serial)
    state:SetAttribute('Revision',(state:GetAttribute('Revision')or 0)+1)
end
function Storm:Step(now)
    local active=self.Active
    if active then
        if now<active.HitAt then return end
        self.Active=nil -- reserve the impact before any gameplay callback
        self.NextAt=now+self.Random:NextNumber(Config.IntervalMin,Config.IntervalMax)
        local area=self:_area()
        if not area or area.Ground~=active.Ground or area.Frame~=active.Frame
            or not Area.Clear(area,active.Center,Config.Radius)then
            self:_publish('Cancelled',active,now);return
        end
        self:_publish('Impact',active,now)
        -- Evaluate the impact against one world snapshot. Drops created by this
        -- impact protect later strikes; they do not cancel other victims now.
        local victims={}
        for _,player in ipairs(Players:GetPlayers())do
            local character,_,root=self.Chase:_validCharacter(player)
            if character and Area.Hit(area,active.Center,root.Position,Config.Radius,Config.HitHeight)then
                table.insert(victims,{Player=player,Character=character})
            end
        end
        for _,victim in ipairs(victims)do
            local ok,message=pcall(function()self.Chase:HitByLightning(victim.Player,active.Center,victim.Character)end)
            if not ok then warn('[V103] Lightning hit failed: '..tostring(message))end
        end
        return
    end
    if now<self.NextAt then return end
    self.NextAt=now+1
    local area=self:_area()
    if not area then return end
    local center=Area.Choose(area,Config.Radius,self.Random,Config.MaxAttempts)
    if not center then return end
    self.Serial+=1
    self.Active={Center=center,Ground=area.Ground,Frame=area.Frame,StartAt=now,HitAt=now+Config.WarningSeconds}
    self:_publish('Warning',self.Active,now)
end
function Storm:Start()
    if self.Connection then return end
    self.NextAt=workspace:GetServerTimeNow()+Config.IntervalMin
    self.Connection=RunService.Heartbeat:Connect(function()self:Step(workspace:GetServerTimeNow())end)
end
function Storm:Destroy()
    if self.Connection then self.Connection:Disconnect();self.Connection=nil end
    self.Active=nil;self:_publish('Idle',nil,workspace:GetServerTimeNow())
end
return Storm
