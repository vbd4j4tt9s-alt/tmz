-- R128 (owner): ambient biome and weather particles live in the world. They used to be locked to a box that followed the
-- camera (moved 20 times a second), so every particle slid along with the view and jittered while walking. Now the box
-- only decides where NEW particles are born; once born, a particle stays where it is (LockedToPart=false), so you walk
-- through pollen, fireflies, sand, embers and snow like they are really there.
-- The box is moved every frame and is led ahead of where you are running (falling snow/rain by its fall time, floating
-- motes a little), so runners still see the effect around them. Same emitters and rates as before: no extra particles.
local F={Version=128,Smooth=6,Teleport=150,FloatLead=.6,FloatMaxLead=60,FallMaxLead=120,MaxFallTime=3}
function F.new()return {Velocity=Vector3.new(0,0,0),Last=nil}end
-- Smoothed horizontal camera velocity (studs/s). A jump further than Teleport studs in one step resets it.
function F.Track(state,position,dt)
 if state.Last and dt and dt>0 then
  local d=position-state.Last;d=Vector3.new(d.X,0,d.Z)
  if d.Magnitude>F.Teleport then state.Velocity=Vector3.new(0,0,0)
  else local a=1-math.exp(-dt*F.Smooth);state.Velocity=state.Velocity:Lerp(d/dt,a)end
 end
 state.Last=position
 return state.Velocity
end
function F.Reset(state)state.Last=nil;state.Velocity=Vector3.new(0,0,0)end
-- How far ahead (seconds of travel) new particles are born, and the cap in studs.
function F.Lead(height,speed,falling)
 if falling then return math.clamp(math.abs(tonumber(height)or 0)/math.max(1,tonumber(speed)or 1),0,F.MaxFallTime),F.FallMaxLead end
 return F.FloatLead,F.FloatMaxLead
end
-- Where the birth box goes: ahead of the camera on the ground plane, raised by height, led along the running direction.
function F.Target(cameraFrame,ahead,height,velocity,lead,maxLead)
 local look=cameraFrame.LookVector;local forward=Vector3.new(look.X,0,look.Z)
 forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)
 local shift=velocity*(lead or 0)
 if shift.Magnitude>(maxLead or 0)then shift=shift.Magnitude>0 and shift.Unit*(maxLead or 0)or shift end
 return cameraFrame.Position+forward*ahead+Vector3.new(0,height,0)+shift
end
return F
