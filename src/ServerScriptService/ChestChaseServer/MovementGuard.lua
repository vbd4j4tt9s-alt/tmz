-- R80: sustained speed budget plus swept map barriers; no automatic kicks/bans.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local Gate=require(script.Parent.SecurityGate)
local Motion=require(RS.RunnerMotion)
local Sweep=require(RS.RunnerSweep)
local M={Records={},Started=false}
function M.Allowance(speed,elapsed)return Motion.Allowance(speed,elapsed)+Motion.Burst(speed)end
local function root(player)
    local c=player.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart')
    return c,h,r
end
local function earnedSpeed(player)
    return M.Config.GetPlayerWalkSpeed(player,M.Data:GetOrCreateSpeedValue(player).Value)
end
local function speed(player)
    local _,_,r=root(player)
    return Motion.AtPosition(earnedSpeed(player),r and r.Position)
end
local function serial(player)
    player:SetAttribute('MovementResetSerial',(player:GetAttribute('MovementResetSerial')or 0)+1)
end
function M.Reset(player,grace)
    local c,h,r=root(player)
    if r then
        local now=os.clock()
        M.Records[player]={Character=c,At=now,Frame=r.CFrame,Grace=now+(tonumber(grace)or .25),Budget=M.Config and Motion.Burst(speed(player))or 12}
        serial(player)
    else M.Records[player]=nil end
end
local function barriers(player,character,r)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
    params.RespectCanCollide=true;params.CollisionGroup=r.CollisionGroup
    local map=M.Bases.Map and M.Bases.Map.MapRoot or workspace:FindFirstChild('ChestChaseMap')
    local include={}
    if map then
        local walls=map:FindFirstChild('InvisibleMapBarriersV071')
        if walls then table.insert(include,walls)end
        local obby=map:FindFirstChild('Obby');walls=obby and obby:FindFirstChild('BiomeWalls')
        if walls then table.insert(include,walls)end
        local runtime=M.Bases.Map and M.Bases.Map.RuntimeFolder
        local gate=runtime and runtime:FindFirstChild('BiomeRefreshWall')
        if gate then table.insert(include,gate)end
    end
    params.FilterDescendantsInstances=include
    return params,#include>0
end
local function correct(player,c,h,r,state,now,frame)
    local target=frame or state.Frame
    c:PivotTo(target*r.CFrame:Inverse()*c:GetPivot())
    r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
    state.Frame=r.CFrame;state.At=now;state.Budget=0;state.Grace=now+.10
    serial(player)
    M.Corrections=(M.Corrections or 0)+1
    return false
end
function M.Check(player)
    if not M.Started or not M.Data:IsLoaded(player)then return true end
    local c,h,r=root(player);if not r or not h or h.Health<=0 then return false end
    local p=r.Position;local state=M.Records[player]
    if not Gate.Finite(p.X)or not Gate.Finite(p.Y)or not Gate.Finite(p.Z)then
        if state then c:PivotTo(state.Frame);r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero;serial(player)end
        return false
    end
    if not state or state.Character~=c then M.Reset(player);return true end
    local now=os.clock()
    local exempt=r.Anchored or M.Bases.TrainingSessions[player]or player:GetAttribute('GuardianRagdollActive')or player:GetAttribute('GuardianFlingActive')
    local admin=Run:IsStudio()or require(script.Parent.OwnerTestState82).MovementGranted(player)or require(script.Parent.OwnerCommandAccess).IsAllowed(player)
    if exempt or(admin and(player:GetAttribute('StudioTestFlying')or player:GetAttribute('StudioTestNoclip')))then
        state.At=now;state.Frame=r.CFrame;state.Grace=now+.65;state.Budget=Motion.Burst(speed(player));return true
    end
    if now<(state.Grace or 0)then state.At=now;state.Frame=r.CFrame;return true end
    local elapsed=math.max(0,now-state.At)
    -- Server stalls are not evidence of cheating; next regular sample resumes validation.
    if elapsed>1.5 then M.Reset(player);return true end
    local earned=earnedSpeed(player)
    local allowed,ceiling=Motion.TravelAllowance(earned,state.Frame.Position,p,elapsed,
        RS.RunnerMotion:GetAttribute('TrackBoundaryZ'),RS.RunnerMotion:GetAttribute('TrackCenterX'),RS.RunnerMotion:GetAttribute('TrackHalfWidth'))
    local offset=p-state.Frame.Position
    local distance=Vector3.new(offset.X,0,offset.Z).Magnitude
    local credit=math.min(state.Budget or 0,Motion.Burst(ceiling))+allowed
    local jump=h.UseJumpPower==false and math.sqrt(2*workspace.Gravity*math.max(0,h.JumpHeight))or math.max(0,h.JumpPower)
    local riseAllowance=18+math.max(jump,48,ceiling*.65)*elapsed*1.5
    if offset.Y>riseAllowance then return correct(player,c,h,r,state,now)end
    if distance>credit+.01 then return correct(player,c,h,r,state,now)end
    if distance>1 then
        local params,enabled=barriers(player,c,r)
        if enabled then
            local size,hullOffset=Sweep.Hull(c,h,r)
            local allowed,hit=Sweep.Cast(workspace,state.Frame,size,hullOffset,offset,params)
            if hit then
                local position=state.Frame.Position+offset.Unit*allowed
                local frame=CFrame.new(position)*r.CFrame.Rotation
                return correct(player,c,h,r,state,now,frame)
            end
        end
    end
    state.Budget=math.min(Motion.Burst(ceiling),math.max(0,credit-distance))
    state.At=now;state.Frame=r.CFrame
    return true
end
local function prefetch(player)
    if not workspace.StreamingEnabled then return end
    local state=M.Records[player];local _,_,r=root(player)
    if not state or not r or r.Anchored or state.PrefetchPending then return end
    local now=os.clock()
    if now-(state.PrefetchAt or -100)<.6 then return end
    local velocity=Motion.Flat(r.AssemblyLinearVelocity)
    local travel=math.min(velocity.Magnitude,speed(player))
    if travel<250 then return end
    state.PrefetchAt=now;state.PrefetchPending=true
    local ahead=r.Position+velocity.Unit*math.clamp(travel*.65,256,3500)
    -- One bounded request per player; ordinary streaming still controls memory/visibility.
    task.spawn(function()
        pcall(function()player:RequestStreamAroundAsync(ahead,.4)end)
        state.PrefetchPending=false
    end)
end
function M.Start(config,data,bases)
    if M.Started then return end
    M.Started=true;M.Config=config;M.Data=data;M.Bases=bases
    local elapsed=0
    M.Connection=Run.Heartbeat:Connect(function(dt)
        elapsed=elapsed+dt;if elapsed<.1 then return end;elapsed=0
        for _,player in ipairs(Players:GetPlayers())do if M.Check(player)then prefetch(player)end end
    end)
end
function M.Cleanup(player)M.Records[player]=nil end
return M
