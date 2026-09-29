-- Visual smoothing only; never moves the authoritative root or chooses catches.
-- R110: the server moves an anchored root, which replicates as irregular discrete steps with no
-- engine interpolation. Predict between packets from a measured velocity and decay only the
-- prediction error, so fast keepers glide instead of stepping at the network rate.
local Data=require(script.Parent.KeeperUpgradeData)
local Motion={}
local strides={[1]=16,[2]=24,[6]=18,[3]=22,[4]=26,[5]=27,[7]=28}
Motion.Correction=9 -- 1/s: how quickly a packet's prediction error is absorbed
Motion.TurnRate=22 -- 1/s: facing follows the replicated root
Motion.Window=.1 -- s: velocity baseline; averages packet arrival jitter
Motion.Lead=1.25 -- packet intervals of prediction before a missing packet counts as a stop
Motion.SnapDistance=40 -- studs beyond plausible travel: a recenter/teleport, never glide across the map
function Motion.Frequency(stage,speed)
    return math.clamp(speed/((Data[stage]and Data[stage].Motion.StrideLength)or strides[stage]or 22),0,3.6)
end
function Motion.new(frame,awake)
    return {Frame=frame,Awake=awake,Speed=0,Moving=0,Time=0,Cycle=0,Urgency=0,Turn=0,
        Raw=frame,RawAt=0,Clock=0,Interval=1/30,Velocity=Vector3.zero,Samples={}}
end
-- A new replicated root sample: update the velocity estimate, or report a teleport.
local function sample(state,frame,hint)
    local clock,raw,position=state.Clock,state.Raw,frame.Position
    local elapsed=clock-state.RawAt
    local pace=math.max(state.Velocity.Magnitude,hint)
    state.Raw=frame;state.RawAt=clock
    local samples=state.Samples
    if (position-raw.Position).Magnitude>Motion.SnapDistance+pace*math.clamp(elapsed,1/30,.25)*2 then
        table.clear(samples);state.Velocity=Vector3.zero;return false
    end
    if elapsed>math.max(.25,state.Interval*4)then
        -- After a rest or a client stall, time the step from the server's travel speed when known.
        local duration=hint>0 and(position-raw.Position).Magnitude/hint or state.Interval
        table.clear(samples);table.insert(samples,{clock-math.clamp(duration,1/240,elapsed),raw.Position})
    else
        local step=math.clamp(elapsed,1/240,.25)
        state.Interval+=(step-state.Interval)*(step>state.Interval and .5 or .2)
    end
    table.insert(samples,{clock,position})
    while #samples>2 and clock-samples[2][1]>=Motion.Window do table.remove(samples,1)end
    local base=samples[1]
    state.Velocity=clock>base[1]and(position-base[2])/(clock-base[1])or Vector3.zero
    return true
end
function Motion.Update(state,frame,speed,asleep,alerted,dt,stage,chasing,exact)
    local elapsed=math.clamp(dt,0,.5)
    dt=math.clamp(dt,0,.1)
    local active=not asleep and not alerted
    local target=active and math.max(0,speed) or 0
    -- Blend chase intention separately so the returning gait stays relaxed.
    local urgencyTarget=chasing==true and active and 1 or 0
    state.Urgency=((state.Urgency or 0)+(urgencyTarget-(state.Urgency or 0))*(1-math.exp(-dt*5)))
    local oldSpeed=state.Speed
    local blend=1-math.exp(-dt*8)
    state.Speed+=(target-state.Speed)*blend
    -- Integrate the filtered speed over the frame, not just its final sample.
    -- This keeps gait phase consistent at 30, 60 and 120 FPS.
    local average=dt>0 and target+(oldSpeed-target)*blend/(dt*8)or oldSpeed
    state.Moving+=((active and math.clamp(state.Speed/5,0,1) or 0)-state.Moving)*(1-math.exp(-dt*10))
    state.Awake+=math.clamp((asleep and 0 or 1)-state.Awake,-dt*.9,dt*1.1)
    state.Time+=dt
    state.Cycle=(state.Cycle+dt*Motion.Frequency(stage,average)*math.pi*2)%(math.pi*2)
    local cross=state.Frame.LookVector:Cross(frame.LookVector).Y
    local dot=math.clamp(state.Frame.LookVector:Dot(frame.LookVector),-1,1)
    local turnTarget=math.clamp(math.atan2(cross,dot)*3,-1,1)*state.Moving
    state.Turn=((state.Turn or 0)+(turnTarget-(state.Turn or 0))*(1-math.exp(-dt*6)))
    state.Clock+=elapsed
    local raw=state.Raw
    local rotation=state.Frame.Rotation:Lerp(frame.Rotation,1-math.exp(-dt*Motion.TurnRate))
    if exact then
        -- A client-computed path (recovery dash) is already smooth: ease onto it, then restart the estimate.
        local offset=(state.Exact and state.Offset or state.Frame.Position-frame.Position)*math.exp(-dt*20)
        state.Exact,state.Offset=true,offset
        state.Raw=frame;state.RawAt=state.Clock;state.Velocity=Vector3.zero;table.clear(state.Samples)
        state.Frame=CFrame.new(frame.Position+offset)*rotation
        return state
    end
    state.Exact=false
    if (frame.Position~=raw.Position or frame.LookVector~=raw.LookVector)
        and not sample(state,frame,math.max(0,speed))then state.Frame=frame;state.Turn=0;return state end
    -- Between packets, carry on at the measured velocity for about one packet interval.
    -- Past that the keeper has stopped; a zero travel speed outside a strike says so sooner.
    local age=state.Clock-state.RawAt
    local horizon=math.clamp(state.Interval*((speed<=0 and not alerted)and .5 or Motion.Lead),1/120,.1)
    local velocity=state.Velocity
    local carried,rate=state.Frame.Position+velocity*elapsed,Motion.Correction
    if age>horizon then
        carried,rate=state.Frame.Position,rate*2;velocity*=math.exp(-dt/.03);state.Velocity=velocity
    end
    local goal=frame.Position+velocity*math.min(age,horizon)
    local position=goal+(carried-goal)*math.exp(-dt*rate)
    if (position-goal).Magnitude>Motion.SnapDistance+velocity.Magnitude*.25 then position=goal end
    state.Frame=CFrame.new(position)*rotation
    return state
end
return Motion
