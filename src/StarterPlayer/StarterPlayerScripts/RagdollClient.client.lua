do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- V117: follow server-owned ragdoll state. No input toggle or hit requests.
-- Humanoid state enablement is local to each simulation, so mirror it here.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local player=Players.LocalPlayer
local current,generation=nil,0
local connections={}
local function recover(record)
    if not record.Active then return end
    record.Active=false
    if record.PhysicsConnection then record.PhysicsConnection:Disconnect();record.PhysicsConnection=nil end
    if record.AnimationConnection then record.AnimationConnection:Disconnect();record.AnimationConnection=nil end
    local hum=record.Humanoid
    if record.Animate and record.Animate.Parent then record.Animate.Disabled=record.AnimateDisabled end
    if hum.Parent then
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,record.Jumping)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,record.GettingUp)
        if player.Character==record.Character and hum.Health>0 and record.GettingUp then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end
local function clear()
    if not current then return end
    local old=current;current=nil
    for _,connection in ipairs(old.Connections)do connection:Disconnect()end
    recover(old)
end
local function bind(character)
    generation+=1;local token=generation
    clear()
    local hum=character:WaitForChild('Humanoid',10)
    if not hum or not hum:IsA('Humanoid') or not character.Parent or token~=generation or player.Character~=character then return end
    local record={Character=character,Humanoid=hum,Active=false,Connections={}}
    current=record
    local function pauseAnimate(animate)
        if not record.Active or not animate or not animate:IsA('LocalScript') or animate.Name~='Animate'then return end
        if record.Animate~=animate then
            record.Animate=animate;record.AnimateDisabled=animate.Disabled
        end
        animate.Disabled=true
    end
    table.insert(record.Connections,character.ChildAdded:Connect(pauseAnimate))
    local function sync()
        if current~=record then return end
        local active=character:GetAttribute('ChestChaseRagdollActive')==true and hum.Health>0
        if active and not record.Active then
            record.Active=true
            record.Jumping=hum:GetStateEnabled(Enum.HumanoidStateType.Jumping)
            record.GettingUp=hum:GetStateEnabled(Enum.HumanoidStateType.GettingUp)
            record.Animate=nil;record.AnimateDisabled=nil
            pauseAnimate(character:FindFirstChild('Animate'))
            local animator=hum:FindFirstChildOfClass('Animator')
            if animator then
                for _,track in ipairs(animator:GetPlayingAnimationTracks())do track:Stop(0)end
                record.AnimationConnection=animator.AnimationPlayed:Connect(function(track)
                    if record.Active then track:Stop(0)end
                end)
            end
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
            hum:ChangeState(Enum.HumanoidStateType.Physics)
            record.PhysicsConnection=RunService.PreSimulation:Connect(function()
                if current~=record or not record.Active or hum.Health<=0 then return end
                if hum:GetState()~=Enum.HumanoidStateType.Physics then hum:ChangeState(Enum.HumanoidStateType.Physics)end
            end)
        elseif not active then recover(record)end
    end
    table.insert(record.Connections,character:GetAttributeChangedSignal('ChestChaseRagdollActive'):Connect(sync))
    table.insert(record.Connections,hum.Died:Connect(function()if current==record then clear()end end))
    sync()
end
table.insert(connections,player.CharacterAdded:Connect(bind))
table.insert(connections,player.CharacterRemoving:Connect(function(character)
    if player.Character==character or (current and current.Character==character)then
        generation+=1
        if current and current.Character==character then clear()end
    end
end))
script.Destroying:Connect(function()
    generation+=1;for _,connection in ipairs(connections)do connection:Disconnect()end;clear()
end)
if player.Character then bind(player.Character)end
