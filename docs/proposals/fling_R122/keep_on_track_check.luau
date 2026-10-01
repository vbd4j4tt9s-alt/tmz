local attrs={TrackBoundaryZ=-99.28,TrackCenterX=0,TrackHalfWidth=89}
local V=function(x,y,z)return {X=x,Y=y,Z=z}end
local Vector3={new=V}
local workspace={Gravity=196.2}
local game={GetService=function()return {FindFirstChild=function()return {GetAttribute=function(_,k)return attrs[k]end}end}end}
local Ragdoll={}
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

local fails=0
local function land(p,v)local t=2*v.Y/196.2;return p.X+v.X*t end
-- sideways Storm fling from near the right wall
local v=Ragdoll.KeepOnTrack(V(70,5,500),V(118,182,0));local x=land(V(70,5,500),v)
print('sideways storm fling lands at x',x,'(walls at +-89)');if x>79.01 then fails+=1 end
if v.Y~=182 then fails+=1;print('FAIL height changed')end
-- along-track fling unchanged
local w=Ragdoll.KeepOnTrack(V(0,5,500),V(0,182,118));if w.X~=0 or w.Z~=118 then fails+=1 end
-- off track (lobby) unchanged
local o=Ragdoll.KeepOnTrack(V(70,5,-300),V(118,182,0));if o.X~=118 then fails+=1;print('FAIL off-track changed')end
print(fails==0 and 'all ok' or fails..' failures')
