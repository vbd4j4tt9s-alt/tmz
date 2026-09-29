-- Visual smoothing only; never moves the authoritative root or chooses catches.
local Data=require(script.Parent.KeeperUpgradeData)
local Motion={}
local strides={[1]=16,[2]=24,[6]=18,[3]=22,[4]=26,[5]=27,[7]=28}
Motion.MaxPositionError=1.5
function Motion.Frequency(stage,speed)
    return math.clamp(speed/((Data[stage]and Data[stage].Motion.StrideLength)or strides[stage]or 22),0,3.6)
end
function Motion.new(frame,awake)
    return {Frame=frame,Awake=awake,Speed=0,Moving=0,Time=0,Cycle=0,Urgency=0,Turn=0}
end
function Motion.Update(state,frame,speed,asleep,alerted,dt,stage,chasing)
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
    local gap=(frame.Position-state.Frame.Position).Magnitude
    if gap>40 then state.Frame=frame;state.Turn=0
    else
        local smooth=state.Frame:Lerp(frame,1-math.exp(-dt*22))
        local error=smooth.Position-frame.Position
        if error.Magnitude>Motion.MaxPositionError then
            smooth=(smooth-smooth.Position)+(frame.Position+error.Unit*Motion.MaxPositionError)
        end
        state.Frame=smooth
    end
    return state
end
return Motion
