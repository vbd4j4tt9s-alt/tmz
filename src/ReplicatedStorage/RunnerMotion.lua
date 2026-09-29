-- R80. Horizontal movement math; the server owns the unlocked speed ceiling.
local M={Version=97,BaseSpeed=24,BaseAreaRatio=.4,TimeToTop=0,
    BrakeSeconds=.035,MinBraking=500,StoppingDistance=3,LateralStoppingDistance=3,
    AirControl=.35,Deadzone=.025,MaxStep=.1,CastLength=512,MaxCasts=16,Skin=.12}
local V=Vector3.new
function M.Finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.Cap(n)return M.Finite(n)and math.max(n,0)or M.BaseSpeed end
-- Earned speed remains separate from the temporary base-area movement limit.
function M.ZoneCap(earned,position,lineZ,centerX,halfWidth)
    earned=M.Cap(earned)
    if typeof(position)=='Vector3'and M.Finite(lineZ)and M.Finite(position.X)and M.Finite(position.Z)
        and position.Z>=lineZ and math.abs(position.X-(centerX or 0))<=(halfWidth or math.huge)then return earned end
    return earned*M.BaseAreaRatio
end
function M.AtPosition(earned,position)
    return M.ZoneCap(earned,position,script:GetAttribute('TrackBoundaryZ'),script:GetAttribute('TrackCenterX'),script:GetAttribute('TrackHalfWidth'))
end
-- The track is the intersection of the forward half-plane and its side edges.
-- Clip a segment against all three edges, including diagonal/lateral crossings.
local function trackInterval(from,to,lineZ,centerX,halfWidth)
    if typeof(from)~='Vector3'or typeof(to)~='Vector3'or not M.Finite(lineZ)
        or not M.Finite(from.X)or not M.Finite(from.Z)or not M.Finite(to.X)or not M.Finite(to.Z)then return nil end
    centerX=centerX or 0;halfWidth=halfWidth or math.huge
    if not M.Finite(centerX)or halfWidth~=halfWidth or halfWidth<0 then return nil end
    local lo,hi=0,1
    local function lower(start,delta,edge)
        if math.abs(delta)<1e-9 then return start>=edge end
        local t=(edge-start)/delta
        if delta>0 then lo=math.max(lo,t)else hi=math.min(hi,t)end
        return lo<=hi
    end
    local dx,dz=to.X-from.X,to.Z-from.Z
    if not lower(from.Z,dz,lineZ)then return nil end
    if halfWidth<math.huge then
        if not lower(from.X,dx,centerX-halfWidth)or not lower(-from.X,-dx,-centerX-halfWidth)then return nil end
    end
    if lo>1 or hi<0 then return nil end
    return math.clamp(lo,0,1),math.clamp(hi,0,1)
end
-- Allocate travel time across both zones, rather than granting an entire
-- high-speed sample whenever a packet happens to end on the track.
function M.TravelAllowance(earned,from,to,elapsed,lineZ,centerX,halfWidth)
    local b=M.ZoneCap(earned,to,lineZ,centerX,halfWidth)
    earned=M.Cap(earned)
    if earned==0 then return 0,b end
    local lo,hi=trackInterval(from,to,lineZ,centerX,halfWidth)
    local fractionInBase=lo and 1-(hi-lo)or 1
    local slow=earned*M.BaseAreaRatio
    local effective=1/(fractionInBase/slow+(1-fractionInBase)/earned)
    return M.Allowance(effective,elapsed),b
end
function M.BoundaryStep(velocity,position,earned,dt)
    local lineZ=script:GetAttribute('TrackBoundaryZ')
    local centerX,halfWidth=script:GetAttribute('TrackCenterX'),script:GetAttribute('TrackHalfWidth')
    if not M.Finite(lineZ)or typeof(position)~='Vector3'or not M.Finite(dt)or dt<=0
        or M.ZoneCap(earned,position,lineZ,centerX,halfWidth)~=M.Cap(earned)then return velocity end
    local projected=position+velocity*dt
    local lo,t=trackInterval(position,projected,lineZ,centerX,halfWidth)
    if not lo or t>=1 then return velocity end
    local ratio=M.BaseAreaRatio
    return velocity*(t+(1-t)*ratio)
end
function M.Flat(v)
    if typeof(v)~='Vector3'or not M.Finite(v.X)or not M.Finite(v.Y)or not M.Finite(v.Z)then return Vector3.zero end
    return V(v.X,0,v.Z)
end
-- Compatibility entry point: holding input no longer ramps movement speed.
function M.LaunchCap(cap,_held)return M.Cap(cap)end
function M.Braking(cap,speed,distance)
    cap=M.Cap(cap)
    -- Use the unlocked ceiling so braking does not weaken as we slow down.
    return math.max(M.MinBraking,cap/M.BrakeSeconds,cap*cap/(2*(distance or M.StoppingDistance)))
end
function M.Step(velocity,input,cap,dt,grounded,_held)
    cap=M.Cap(cap);dt=M.Finite(dt)and math.clamp(dt,0,M.MaxStep)or 0
    velocity=M.Flat(velocity);input=M.Flat(input)
    local speed=velocity.Magnitude
    if speed>cap then velocity=velocity*(cap/speed);speed=cap end
    if dt==0 then return velocity end
    local control=grounded and 1 or M.AirControl
    local magnitude=math.min(1,input.Magnitude)
    if magnitude<=M.Deadzone or cap==0 then
        if grounded or speed<.01 then return Vector3.zero end
        local nextSpeed=math.max(0,speed-M.Braking(cap,speed)*control*dt)
        return velocity*(nextSpeed/speed)
    end
    local direction=input.Unit
    -- Full input uses the earned ceiling on its first simulation step.
    -- A partial thumbstick still permits precise positioning; release brakes immediately.
    if not grounded and speed>.01 and velocity.Unit:Dot(direction)>-.95 then
        local blended=velocity.Unit:Lerp(direction,1-math.exp(-dt*control/.05))
        if blended.Magnitude>.001 then direction=blended.Unit end
    end
    return direction*(cap*magnitude*magnitude)

end
function M.Allowance(cap,dt)
    return M.Cap(cap)*math.max(0,M.Finite(dt)and dt or 0)*1.20
end
function M.Burst(cap)return 12+M.Cap(cap)*.20 end
return M
