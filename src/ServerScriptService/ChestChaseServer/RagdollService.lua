-- V117 FIX1: Motor6D and Avatar Joint Upgrade AnimationConstraint support.
-- Reuse existing native sockets and preserve all native attachment frames.
-- Server owns joints, hit velocity and recovery; client only pauses animation/state.
-- Existing seed-drop/health ownership stays with the catch system.
local RunService=game:GetService('RunService')
local Knockback=require(game:GetService('ReplicatedStorage'):WaitForChild('KnockbackConfig'))
local FloorSafety=require(script.Parent.FloorSafety86)
local Ragdoll = {}
Ragdoll.__index = Ragdoll
local bodyNames = {Head=true,Torso=true,UpperTorso=true,LowerTorso=true,
    ['Left Arm']=true,['Right Arm']=true,['Left Leg']=true,['Right Leg']=true,
    LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,
    LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true}

-- Limits allow loose tumbling while protecting the neck and small joints.
local function jointLimits(name)
    if name == 'Neck' then return 45,55 end
    if name:find('Shoulder') then return 115,90 end
    if name:find('Hip') then return 95,60 end
    if name == 'Waist' then return 45,30 end
    if name:find('Elbow') or name:find('Knee') then return 85,8 end
    if name:find('Wrist') or name:find('Ankle') then return 35,25 end
    return 60,35
end

local socketProperties={'Enabled','LimitsEnabled','UpperAngle','TwistLimitsEnabled',
    'TwistLowerAngle','TwistUpperAngle','MaxFrictionTorque','Restitution'}
local function jointInfo(joint)
    if joint:IsA('Motor6D')then return joint.Part0,joint.Part1,joint.C0,joint.C1 end
    if joint:IsA('AnimationConstraint')then
        local a0,a1=joint.Attachment0,joint.Attachment1
        if a0 and a1 and a0.Parent and a1.Parent and a0.Parent:IsA('BasePart') and a1.Parent:IsA('BasePart')then
            -- The legacy C0/Part0 aliases are read-only on upgraded joints. Use attachments explicitly.
            return a0.Parent,a1.Parent,a0.CFrame,a1.CFrame
        end
    end
    return nil
end
local function samePair(a,b,x,y)return (a==x and b==y)or(a==y and b==x)end

function Ragdoll.new(config,restoreSpeed)
    return setmetatable({Config=config,RestoreSpeed=restoreSpeed,Records={},Random=Random.new()},Ragdoll)
end
function Ragdoll:IsActive(player)
    local record=self.Records[player]
    return record~=nil and record.Active
end
function Ragdoll:CanHit(player)
    return player~=nil and player.Parent~=nil and self.Records[player]==nil
end
function Ragdoll:_recover(player,record)
    if not record.Active then return end
    record.Active=false
    if record.TrailConnection then record.TrailConnection:Disconnect();record.TrailConnection=nil end
    -- Remove physics constraints before reconnecting the animated skeleton.
    if record.Folder then record.Folder:Destroy()end
    for _,part in ipairs(record.Parts)do if part.Item.Parent then part.Item.AssemblyAngularVelocity=Vector3.zero end end
    for _,motor in ipairs(record.Motors)do if motor.Item.Parent then motor.Item.Enabled=motor.Enabled end end
    for _,entry in ipairs(record.NativeSockets)do
        if entry.Item.Parent then
            for _,property in ipairs(socketProperties)do entry.Item[property]=entry.Properties[property]end
        end
    end
    for _,attachment in ipairs(record.Attachments)do attachment:Destroy()end
    for _,part in ipairs(record.Parts)do if part.Item.Parent then
        part.Item.CanCollide=part.CanCollide;part.Item.Massless=part.Massless
    end end
    for tool,enabled in pairs(record.Tools)do
        if tool.Parent and (tool:IsDescendantOf(record.Character) or (record.Backpack and tool:IsDescendantOf(record.Backpack)))then
            tool.Enabled=enabled
        end
    end
    local humanoid=record.Humanoid
    if humanoid.Parent then
        humanoid.RequiresNeck=record.RequiresNeck
        humanoid.EvaluateStateMachine=record.EvaluateStateMachine
        humanoid.AutoRotate=record.AutoRotate;humanoid.PlatformStand=record.PlatformStand
        humanoid.WalkSpeed=record.WalkSpeed
        humanoid.JumpPower=record.JumpPower;humanoid.JumpHeight=record.JumpHeight
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,record.Jumping)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,record.GettingUp)
        if humanoid.Health>0 and player.Character==record.Character then
            if not record.PlatformStand and record.GettingUp then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)end
            local restored,restoreError=pcall(self.RestoreSpeed,player,humanoid)
            if not restored then warn('[V117 FIX1] Speed refresh failed; restored pre-hit speed: '..tostring(restoreError))end
        end
    end
    if humanoid.Parent and humanoid.Health>0 and player.Character==record.Character and record.Root.Parent then
        FloorSafety.Recover(record.Character,humanoid,record.Root)
        player:SetAttribute('MovementResetSerial',(player:GetAttribute('MovementResetSerial')or 0)+1)
    end
    for _,entry in ipairs(record.Ownership or{})do
        if entry.Item.Parent and entry.Readable then pcall(function()
            if entry.Auto then entry.Item:SetNetworkOwnershipAuto()else entry.Item:SetNetworkOwner(entry.Owner)end
        end)end
    end
    if record.Root.Parent and record.Network.Readable then
        pcall(function()
            if record.Network.Auto then record.Root:SetNetworkOwnershipAuto()
            else record.Root:SetNetworkOwner(record.Network.Owner)end
        end)
    end
    if record.Character.Parent then record.Character:SetAttribute('ChestChaseRagdollActive',false)end
    if self.Records[player]==record then player:SetAttribute('GuardianRagdollActive',false)end
end
function Ragdoll:Clear(player)
    local record=self.Records[player]
    if not record then return end
    self:_recover(player,record)
    for _,connection in ipairs(record.Connections)do connection:Disconnect()end
    self.Records[player]=nil
    if player.Parent then
        player:SetAttribute('GuardianRagdollActive',false)
        player:SetAttribute('GuardianFlingActive',false)
    end
end
-- R122: optional stunSeconds (track holes) sets an exact time on the ground; other causes are unchanged.
function Ragdoll.KeepOnTrack(position,velocity)
    local motion=game:GetService('ReplicatedStorage'):FindFirstChild('RunnerMotion')
    local lineZ=motion and motion:GetAttribute('TrackBoundaryZ');local centerX=motion and motion:GetAttribute('TrackCenterX')
    local half=motion and motion:GetAttribute('TrackHalfWidth')
    if type(lineZ)~='number'or type(centerX)~='number'or type(half)~='number'or half<=12 then return velocity end
    if position.Z<lineZ or math.abs(position.X-centerX)>half then return velocity end -- only while on the track
    local flight=2*math.max(0,velocity.Y)/math.max(1,workspace.Gravity)
    if flight<=0 then return velocity end
    local margin=half-10;local landing=position.X+velocity.X*flight
    local target=math.clamp(landing,centerX-margin,centerX+margin)
    if target==landing then return velocity end
    return Vector3.new((target-position.X)/flight,velocity.Y,velocity.Z)
end
function Ragdoll:Apply(player,velocity,cause,stunSeconds)
    if not self:CanHit(player)then return nil end
    local character=player.Character
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    local root=character and character:FindFirstChild('HumanoidRootPart')
    if not humanoid or not root or not root:IsA('BasePart') or humanoid.Health<=0 or root.Anchored then return nil end
    if typeof(velocity)~='Vector3' or velocity.X~=velocity.X or velocity.Y~=velocity.Y or velocity.Z~=velocity.Z
        or velocity.Magnitude==math.huge then return nil end
    if character:FindFirstChild('_ChestChaseRagdoll')then
        warn('[V117 FIX1] Existing ragdoll objects; refusing a second physics controller.');return nil
    end
    -- R122: keeper flings go much higher than the track's 48-stud side walls. On the track, limit only the sideways
    -- (X) part so the predicted landing point stays inside the walls; height and the push along the track are unchanged.
    if cause=='Keeper'then velocity=Ragdoll.KeepOnTrack(root.Position,velocity)end
    local minimum=math.clamp(tonumber(self.Config.GuardianRagdollMinDuration)or .5,.4,2)
    local maximum=math.clamp(tonumber(self.Config.GuardianRagdollMaxDuration)or 1.5,minimum,2)
    local keeperHit=cause=='Keeper'
    if keeperHit then
        minimum=math.clamp(tonumber(self.Config.KeeperRagdollMinDuration)or 1.8,.4,4)
        maximum=math.clamp(tonumber(self.Config.KeeperRagdollMaxDuration)or 2.4,minimum,4)
    end
    if cause=='Bat'then minimum=Knockback.Bat.Stun;maximum=minimum end
    if type(stunSeconds)=='number'and stunSeconds==stunSeconds then minimum=math.clamp(stunSeconds,.4,6);maximum=minimum end
    local duration=self.Random:NextNumber(minimum,maximum)
    local record={Character=character,Humanoid=humanoid,Root=root,Active=true,Duration=duration,
        AutoRotate=humanoid.AutoRotate,PlatformStand=humanoid.PlatformStand,RequiresNeck=humanoid.RequiresNeck,
        JumpPower=humanoid.JumpPower,JumpHeight=humanoid.JumpHeight,WalkSpeed=humanoid.WalkSpeed,
        EvaluateStateMachine=humanoid.EvaluateStateMachine,
        Jumping=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
        GettingUp=humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp),
        Motors={},NativeSockets={},Parts={},Attachments={},Connections={},Tools={},Network={},Ownership={},Trails={},
        Backpack=player:FindFirstChildOfClass('Backpack')}
    local network=record.Network
    network.Readable=pcall(function()network.Auto=root:GetNetworkOwnershipAuto();network.Owner=root:GetNetworkOwner()end)
    self.Records[player]=record
    local ok,message=xpcall(function()
        local folder=Instance.new('Folder');folder.Name='_ChestChaseRagdoll';folder.Parent=character;record.Folder=folder
        player:SetAttribute('GuardianRagdollActive',true)
        player:SetAttribute('GuardianFlingActive',true)
        player:SetAttribute('LastGuardianRagdollDuration',duration)
        humanoid.RequiresNeck=false
        humanoid.EvaluateStateMachine=false
        local bodies={}
        local colliders={}
        table.insert(record.Parts,{Item=root,CanCollide=root.CanCollide,Massless=root.Massless})
        root.CanCollide=false;root.Massless=true
        for _,part in ipairs(character:GetChildren())do
            if part:IsA('BasePart') and bodyNames[part.Name]then
                bodies[part]=true
                local ownership={Item=part}
                ownership.Readable=pcall(function()ownership.Auto=part:GetNetworkOwnershipAuto();ownership.Owner=part:GetNetworkOwner()end)
                table.insert(record.Ownership,ownership)
                assert(not part.Anchored,'Cannot ragdoll an anchored body part: '..part.Name)
                table.insert(record.Parts,{Item=part,CanCollide=part.CanCollide,Massless=part.Massless})
                part.CanCollide=false;part.Massless=false
                -- Humanoid-owned body collision flags cannot remove proxy ground contact.
                -- Insets avoid snagging at joint seams; size follows the actual scaled avatar.
                local collider=Instance.new('Part');collider.Name='Contact_'..part.Name
                collider.Size=Vector3.new(part.Size.X*.82,part.Size.Y*.9,part.Size.Z*.82)
                collider.CFrame=part.CFrame;collider.Transparency=1;collider.Massless=true
                collider.CanCollide=true;collider.CanTouch=false;collider.CanQuery=false
                collider.CollisionGroup=part.CollisionGroup
                collider.CustomPhysicalProperties=PhysicalProperties.new(.7,.15,0,100,100)
                collider.Parent=folder;table.insert(colliders,collider)
                local weld=Instance.new('WeldConstraint');weld.Part0=part;weld.Part1=collider;weld.Parent=collider
            end
        end
        local torso=character:FindFirstChild('UpperTorso')or character:FindFirstChild('Torso')
        if torso then
            for _,side in ipairs({-1,1})do
                local center=Vector3.new(torso.Size.X*.38*side,torso.Size.Y*.1,torso.Size.Z*.5)
                local a0=Instance.new('Attachment');a0.Name='KnockbackTrail0';a0.Position=center-Vector3.new(Knockback.Trail.Width/2,0,0);a0.Parent=torso
                local a1=Instance.new('Attachment');a1.Name='KnockbackTrail1';a1.Position=center+Vector3.new(Knockback.Trail.Width/2,0,0);a1.Parent=torso
                table.insert(record.Attachments,a0);table.insert(record.Attachments,a1)
                local trail=Instance.new('Trail');trail.Name='WhiteKnockbackTrail';trail.Attachment0=a0;trail.Attachment1=a1
                trail.Color=ColorSequence.new(Color3.new(1,1,1));trail.Transparency=NumberSequence.new(.12,1)
                trail.WidthScale=NumberSequence.new(1,0);trail.Lifetime=Knockback.Trail.Lifetime;trail.MinLength=.08
                trail.FaceCamera=true;trail.LightEmission=.6;trail.Enabled=false;trail.Parent=folder
                table.insert(record.Trails,trail)
            end
        end
        record.TrailConnection=RunService.PostSimulation:Connect(function()
            if not record.Active or not root.Parent then return end
            local enabled=record.Launched==true and root.AssemblyLinearVelocity.Magnitude>=Knockback.Trail.MinSpeed
            for _,trail in ipairs(record.Trails)do trail.Enabled=enabled end
        end)
        table.insert(record.Connections,record.TrailConnection)
        local socketCount,rootCount=0,0
        local descendants=character:GetDescendants()
        local drivers,nativeSockets={},{}
        local motorTotal,animationTotal=0,0
        -- Prefer upgraded drivers if a compatibility rig contains both joint types.
        for _,kind in ipairs({'AnimationConstraint','Motor6D'})do
            for _,joint in ipairs(descendants)do
                if joint:IsA(kind)then
                    if kind=='AnimationConstraint'then animationTotal+=1 else motorTotal+=1 end
                    if joint.Enabled then table.insert(drivers,joint)end
                end
            end
        end
        for _,item in ipairs(descendants)do
            if item:IsA('BallSocketConstraint') and item.Attachment0 and item.Attachment1 then
                table.insert(nativeSockets,item)
            end
        end
        local processed={}
        local function alreadyProcessed(p0,p1)
            for _,pair in ipairs(processed)do if samePair(p0,p1,pair[1],pair[2])then return true end end
            table.insert(processed,{p0,p1});return false
        end
        local function rememberSocket(socket)
            local entry={Item=socket,Properties={}}
            for _,property in ipairs(socketProperties)do entry.Properties[property]=socket[property]end
            table.insert(record.NativeSockets,entry)
        end
        for _,joint in ipairs(drivers)do
            local p0,p1,c0,c1=jointInfo(joint)
            local bodyJoint=p0 and p1 and bodies[p0] and bodies[p1]
            local rootJoint=p0 and p1 and ((p0==root and bodies[p1])or(p1==root and bodies[p0]))
            if bodyJoint or rootJoint then
                table.insert(record.Motors,{Item=joint,Enabled=joint.Enabled})
                joint.Enabled=false
                if not alreadyProcessed(p0,p1)then
                    local existing
                    for _,socket in ipairs(nativeSockets)do
                        if samePair(p0,p1,socket.Attachment0.Parent,socket.Attachment1.Parent)then
                            rememberSocket(socket)
                            if not existing then existing=socket else socket.Enabled=false end
                            if rootJoint then socket.Enabled=false end
                        end
                    end
                    if bodyJoint then
                        local socket=existing
                        if not socket then
                            -- Legacy rigs have no native socket. Add temporary attachments only here.
                            local a0=Instance.new('Attachment');a0.Name='RagdollJoint0'
                            a0.CFrame=c0;a0.Parent=p0;table.insert(record.Attachments,a0)
                            local a1=Instance.new('Attachment');a1.Name='RagdollJoint1'
                            a1.CFrame=c1;a1.Parent=p1;table.insert(record.Attachments,a1)
                            socket=Instance.new('BallSocketConstraint');socket.Name=joint.Name
                            socket.Attachment0=a0;socket.Attachment1=a1;socket.Parent=folder
                        end
                        local upper,twist=jointLimits(joint.Name)
                        socket.LimitsEnabled=true;socket.UpperAngle=upper
                        socket.TwistLimitsEnabled=true;socket.TwistLowerAngle=-twist;socket.TwistUpperAngle=twist
                        socket.MaxFrictionTorque=0;socket.Restitution=0;socket.Enabled=true
                        socketCount+=1
                    else
                        local weld=Instance.new('WeldConstraint');weld.Name='RootLink'
                        weld.Part0=p0;weld.Part1=p1;weld.Parent=folder
                        rootCount+=1
                    end
                end
            end
        end
        local expected=humanoid.RigType==Enum.HumanoidRigType.R6 and 5 or 14
        assert(socketCount==expected and rootCount==1,
            string.format('Unsupported/incomplete rig: %d body joints, %d root joints (%d Motor6D, %d AnimationConstraint)',
                socketCount,rootCount,motorTotal,animationTotal))
        -- Include proxy contacts in self-collision exclusions, and keep accessories from
        -- holding the body up. Restore every changed original part on every exit path.
        for _,item in ipairs(character:GetDescendants())do
            if item:IsA('BasePart') and item~=root and not bodies[item] and not item:IsDescendantOf(folder)
                and item:FindFirstAncestorOfClass('Accessory')then
                table.insert(record.Parts,{Item=item,CanCollide=item.CanCollide,Massless=item.Massless})
                item.CanCollide=false;item.Massless=true
            end
        end
        -- Proxies cannot collide with each other or the original avatar, even if an
        -- external character script writes an original limb's CanCollide flag.
        for i,collider in ipairs(colliders)do
            for j=i+1,#colliders do
                local noContact=Instance.new('NoCollisionConstraint')
                noContact.Part0=collider;noContact.Part1=colliders[j];noContact.Parent=folder
            end
            for _,entry in ipairs(record.Parts)do
                local noContact=Instance.new('NoCollisionConstraint')
                noContact.Part0=collider;noContact.Part1=entry.Item;noContact.Parent=folder
            end
        end
        local function disarm(tool)
            if not record.Active or not tool:IsA('Tool')then return end
            if record.Tools[tool]==nil then record.Tools[tool]=tool.Enabled end
            tool.Enabled=false
            if tool.Parent==character and record.Backpack then tool.Parent=record.Backpack end
        end
        if record.Backpack then
            for _,tool in ipairs(record.Backpack:GetChildren())do disarm(tool)end
            table.insert(record.Connections,record.Backpack.ChildAdded:Connect(disarm))
        end
        for _,tool in ipairs(character:GetChildren())do disarm(tool)end
        table.insert(record.Connections,character.ChildAdded:Connect(disarm))
        humanoid:UnequipTools()
        humanoid.AutoRotate=false;humanoid.PlatformStand=true;humanoid.WalkSpeed=0
        humanoid.JumpPower=0;humanoid.JumpHeight=0
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        table.insert(record.Connections,humanoid.Died:Connect(function()if self.Records[player]==record then self:Clear(player)end end))
        table.insert(record.Connections,player.CharacterRemoving:Connect(function(old)
            if old==character and self.Records[player]==record then self:Clear(player)end
        end))
        pcall(function()root:SetNetworkOwner(nil)end)
        -- Wait until Roblox has rebuilt the separated physics assemblies. Reading
        -- AssemblyRootPart immediately after disabling motors can still see the old body.
        local launchConnection
        launchConnection=RunService.PostSimulation:Connect(function()
            launchConnection:Disconnect()
            if self.Records[player]~=record or not record.Active or player.Character~=character then return end
        local flat=Vector3.new(velocity.X,0,velocity.Z)
        local axis=flat.Magnitude>.01 and Vector3.yAxis:Cross(flat.Unit)or Vector3.xAxis
        local tumble=axis*4+Vector3.new(0,.8,0)
        for _,entry in ipairs(record.Parts)do
            local part=entry.Item
            if part.Parent and (part==root or bodies[part])then
                    -- Reassert ownership after the ragdoll assemblies have actually split.
                    pcall(function()part:SetNetworkOwner(nil)end)
                    part.AssemblyLinearVelocity=velocity
                    local name=part.Name
                    local limb=name:find('Arm') or name:find('Leg') or name:find('Hand') or name:find('Foot')
                    local spin=tumble
                    if limb then
                        local side=name:find('Left') and -1 or 1
                        -- Small one-time asymmetric angular motion; no ongoing force or extra launch.
                        spin=tumble*.45+root.CFrame.LookVector*(side*2.4)
                            +root.CFrame.RightVector*self.Random:NextNumber(-1.2,1.2)
                    elseif name=='Head' then spin=tumble*.55 end
                    part.AssemblyAngularVelocity=spin
            end
        end
        record.Launched=true
        for _,trail in ipairs(record.Trails)do trail.Enabled=velocity.Magnitude>=Knockback.Trail.MinSpeed end
        end)
        table.insert(record.Connections,launchConnection)
        character:SetAttribute('ChestChaseRagdollActive',true)
    end,debug.traceback)
    if not ok then self:Clear(player);warn('[V117 FIX1] Ragdoll recovered after an error: '..tostring(message));return nil end
    task.delay(duration,function()
        if self.Records[player]~=record then return end
        if player.Character~=character then self:Clear(player);return end
        self:_recover(player,record)
    end)
    local grace=cause=='Bat'and Knockback.Bat.RecoveryGrace or keeperHit and math.clamp(tonumber(self.Config.KeeperRagdollRecoveryGrace)or .35,0,1)or 0
    task.delay(math.max(duration+grace,tonumber(self.Config.GuardianFlingProtectionTime)or 1.25),function()
        if self.Records[player]==record then self:Clear(player)end
    end)
    return record
end
return Ragdoll
