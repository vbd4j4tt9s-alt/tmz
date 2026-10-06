do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R80. Uses Roblox's normal input and avatar rig. No new keybinds or animation package.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Gui=game:GetService('GuiService')
local RS=game:GetService('ReplicatedStorage')
local Motion=require(RS:WaitForChild('RunnerMotion'))
local Sweep=require(RS:WaitForChild('RunnerSweep'))
local player=Players.LocalPlayer
local playerGui=player:WaitForChild('PlayerGui')
local record,focused,alive=nil,true,true
local controls
-- Read raw controls before applying our velocity; never feed WalkSpeed back into input.
task.spawn(function()
 local module=player:WaitForChild('PlayerScripts'):WaitForChild('PlayerModule',10)
 if module then local ok,result=pcall(require,module);if ok and type(result.GetControls)=='function'then controls=result:GetControls()end end
end)
local function rawInput(humanoid)
 if not controls then return Motion.Flat(humanoid.MoveDirection)end
 local value=controls:GetMoveVector();local active=controls.activeController
 local relative=not active or active:IsMoveVectorCameraRelative()
 if not relative then return Motion.Flat(value)end
 local camera=workspace.CurrentCamera;if not camera then return Vector3.zero end
 -- Horizontal camera basis, including the straight-down/up camera case.
 local right=Motion.Flat(camera.CFrame.RightVector)
 if right.Magnitude<.001 then right=Vector3.xAxis else right=right.Unit end
 local back=right:Cross(Vector3.yAxis)
 return right*value.X+back*value.Z
end
local connections={}
local inputBinding='ChestChaseRunnerInput80'
local function cap()
 local r=record
 return Motion.AtPosition(player:GetAttribute('PhysicalWalkSpeed'),r and r.Root.Position)
end
local function suspended(r)
    if not r or player.GameplayPaused or player.Character~=r.Character or not r.Root.Parent or r.Humanoid.Health<=0
        or r.Root.Anchored or r.Humanoid.Sit or r.Humanoid.PlatformStand then return true end
    for _,key in ipairs({'TreadmillTraining','GuardianRagdollActive','GuardianFlingActive','StudioTestFlying','StudioTestNoclip'})do
        if player:GetAttribute(key)then return true end
    end
    local state=r.Humanoid:GetState()
    return state==Enum.HumanoidStateType.Physics or state==Enum.HumanoidStateType.Ragdoll
        or state==Enum.HumanoidStateType.Seated or state==Enum.HumanoidStateType.Dead
        or state==Enum.HumanoidStateType.Climbing or state==Enum.HumanoidStateType.Swimming
end
-- R110: a high-speed bump must never trip the runner. Only RagdollService's knockback owns a fall:
-- it flags GuardianRagdollActive/ChestChaseRagdollActive and sets PlatformStand/EvaluateStateMachine.
-- Humanoid state is simulated by the owning client, so this has to run here, not on the server.
local States=Enum.HumanoidStateType
local tripStates={States.FallingDown,States.Ragdoll}
local steady={[States.Running]=true,[States.RunningNoPhysics]=true,[States.Freefall]=true,[States.Landed]=true,[States.Jumping]=true}
local upright=math.cos(math.rad(30))
local function authoredFall(r)
    local h=r.Humanoid
    return player:GetAttribute('GuardianRagdollActive')==true or r.Character:GetAttribute('ChestChaseRagdollActive')==true
        or h.PlatformStand or not h.EvaluateStateMachine
end
local function allowTrips(r,allow)
    if r.TripsAllowed==allow then return end
    r.TripsAllowed=allow
    for i,state in ipairs(tripStates)do r.Humanoid:SetStateEnabled(state,allow and r.TripDefaults[i])end
end
local function keepUpright(r)
    local humanoid,root=r.Humanoid,r.Root
    local allow=authoredFall(r)
    allowTrips(r,allow)
    if allow or humanoid.Health<=0 or humanoid.Sit or root.Anchored or player:GetAttribute('GuardianFlingActive')
        or player:GetAttribute('TreadmillTraining')or player:GetAttribute('StudioTestFlying')or player:GetAttribute('StudioTestNoclip')then return end
    local frame=root.CFrame
    local state=humanoid:GetState()
    if state==States.FallingDown or state==States.Ragdoll or state==States.PlatformStanding then
        humanoid:ChangeState(frame.UpVector.Y<upright and humanoid:GetStateEnabled(States.GettingUp)and States.GettingUp or States.Running)
    elseif not steady[state]then return end -- GettingUp, climbing, swimming, seats and Physics keep their own control
    -- Contact torque, not intent: clear pitch/roll spin and stand a tipped root back up (yaw kept).
    local spin=root.AssemblyAngularVelocity
    if spin.X*spin.X+spin.Z*spin.Z>.04 then root.AssemblyAngularVelocity=Vector3.new(0,spin.Y,0)end
    if frame.UpVector.Y<upright then
        local look=Motion.Flat(frame.LookVector)
        if look.Magnitude<.2 then look=Motion.Flat(frame.UpVector*-math.sign(frame.LookVector.Y))end
        if look.Magnitude>.001 then root.CFrame=CFrame.lookAt(frame.Position,frame.Position+look.Unit)end
    end
end
local function clear()
    if record then
        for _,c in ipairs(record.Connections)do c:Disconnect()end
        if record.Humanoid.Parent then allowTrips(record,true)end
        if record.Humanoid.Parent and not suspended(record)then record.Humanoid.WalkSpeed=cap()end
    end
    record=nil
end
local function reset()
    if record then
        record.Velocity=Vector3.zero;record.Before=nil;record.Input=Vector3.zero
    end
end
local function attach(character)
    clear()
    local humanoid=character:WaitForChild('Humanoid',10)
    local root=character:WaitForChild('HumanoidRootPart',10)
    if not alive or player.Character~=character or not humanoid or not root then return end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character}
    params.RespectCanCollide=true;params.IgnoreWater=false
    record={Character=character,Humanoid=humanoid,Root=root,Params=params,Velocity=Vector3.zero,
        Input=Vector3.zero,Connections={},Tracks=setmetatable({},{__mode='k'}),HullAt=0,
        TripDefaults={humanoid:GetStateEnabled(States.FallingDown),humanoid:GetStateEnabled(States.Ragdoll)}}
    local r=record
    allowTrips(r,authoredFall(r))
    local function observe(track)
        local animation=track.Animation
        if animation and animation:GetAttribute('ChestChaseGameplayAnimation')then return end
        local name=(track.Name..' '..(animation and animation.Name or '')):lower()
        if name:find('walk',1,true)or name:find('run',1,true)then r.Tracks[track]=true end
    end
    local function bindAnimator(animator)
        for _,track in ipairs(animator:GetPlayingAnimationTracks())do observe(track)end
        table.insert(r.Connections,animator.AnimationPlayed:Connect(observe))
    end
    local animator=humanoid:FindFirstChildOfClass('Animator')
    if animator then bindAnimator(animator)else
        table.insert(r.Connections,humanoid.ChildAdded:Connect(function(child)
            if child:IsA('Animator')then bindAnimator(child)end
        end))
    end
end
-- Run after the default input module; keyboard, controller and touch share this path.
Run:BindToRenderStep(inputBinding,Enum.RenderPriority.Input.Value+1,function()
    local r=record
    if not r then return end
    if playerGui:GetAttribute('TitleActive')or suspended(r)or not focused or Gui.MenuIsOpen or Input:GetFocusedTextBox()then r.Input=Vector3.zero;return end
    r.Input=rawInput(r.Humanoid)
end)
table.insert(connections,Run.PreSimulation:Connect(function(dt)
    local r=record
    if suspended(r)then reset();return end
    local root,humanoid=r.Root,r.Humanoid
    if playerGui:GetAttribute('TitleActive')then
        reset();humanoid:Move(Vector3.zero,false);humanoid.Jump=false
        local velocity=root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity=Vector3.new(0,velocity.Y,0)
        return
    end
    if not Motion.Finite(dt)or dt<=0 then r.Before=nil;return end
    -- Do not preserve several frames of run momentum across a severe client stall.
    local stalled=dt>Motion.MaxStep
    local grounded=humanoid.FloorMaterial~=Enum.Material.Air
    local ceiling=cap()
    local nextVelocity=stalled and Vector3.zero or Motion.Step(r.Velocity,r.Input,ceiling,dt,grounded)
    nextVelocity=Motion.BoundaryStep(nextVelocity,root.Position,player:GetAttribute('PhysicalWalkSpeed'),dt)
    if os.clock()-r.HullAt>.5 or not r.Size then
        r.Size,r.Offset=Sweep.Hull(r.Character,humanoid,root);r.HullAt=os.clock()
    end
    r.Params.CollisionGroup=root.CollisionGroup
    local movement=nextVelocity*dt
    if movement.Magnitude>.001 then
        local resolved=Sweep.Slide(workspace,root.CFrame,r.Size,r.Offset,movement,r.Params)
        nextVelocity=resolved/dt
    end
    r.Velocity=nextVelocity
    r.Before=root.CFrame
    r.Serial=player:GetAttribute('MovementResetSerial')
    humanoid.WalkSpeed=ceiling
    humanoid:Move(ceiling>.001 and nextVelocity/ceiling or Vector3.zero,false)
    local velocity=root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity=Vector3.new(nextVelocity.X,velocity.Y,nextVelocity.Z)
end))
table.insert(connections,Run.PostSimulation:Connect(function()
    local r=record
    if suspended(r)or not r.Before or r.Serial~=player:GetAttribute('MovementResetSerial')then return end
    local root=r.Root
    local before=r.Before;r.Before=nil
    local delta=root.Position-before.Position
    if delta.Magnitude<.01 then return end
    local allowed,hit=Sweep.Cast(workspace,before,r.Size,r.Offset,delta,r.Params)
    if not hit then return end
    local position=before.Position+delta.Unit*allowed
    r.Character:PivotTo(r.Character:GetPivot()+position-root.Position)
    local velocity=root.AssemblyLinearVelocity
    if hit.Normal then
        velocity=velocity-hit.Normal*math.min(0,velocity:Dot(hit.Normal))
    else velocity=Vector3.new(0,velocity.Y,0)end
    root.AssemblyLinearVelocity=velocity
    r.Velocity=Motion.Flat(velocity)
end))
table.insert(connections,Run.PostSimulation:Connect(function()
    local r=record
    if r and player.Character==r.Character and r.Root.Parent and r.Humanoid.Parent then keepUpright(r)end
end))
table.insert(connections,Run.PreAnimation:Connect(function(dt)
    local r=record
    if suspended(r)then return end
    local measured=Motion.Flat(r.Root.AssemblyLinearVelocity).Magnitude
    local forced=require(RS.DefaultCharacterAnimations).Required(player,r.Character)
    local desired=player:GetAttribute('OwnerAnimationRate82')or (forced and require(RS.Progression81).Playback(measured)or math.clamp(measured/24,.1,2.5))
    r.Playback=(r.Playback or desired)+(desired-(r.Playback or desired))*(1-math.exp(-math.min(dt or .016,.1)/.1))
    for track in pairs(r.Tracks)do
        -- Leave action, bat, carry and treadmill animation tracks under their current owners.
        if track.IsPlaying and (track.Priority==Enum.AnimationPriority.Core or track.Priority==Enum.AnimationPriority.Movement)then
            track:AdjustSpeed(r.Playback)
        end
    end
end))
table.insert(connections,Input.WindowFocusReleased:Connect(function()focused=false;if record then record.Input=Vector3.zero end end))
table.insert(connections,Input.WindowFocused:Connect(function()focused=true end))
table.insert(connections,player:GetAttributeChangedSignal('MovementResetSerial'):Connect(reset))
table.insert(connections,player.CharacterAdded:Connect(attach))
table.insert(connections,player.CharacterRemoving:Connect(clear))
if player.Character then task.spawn(attach,player.Character)end
script.Destroying:Connect(function()
    alive=false;Run:UnbindFromRenderStep(inputBinding)
    for _,c in ipairs(connections)do c:Disconnect()end
    clear()
end)
