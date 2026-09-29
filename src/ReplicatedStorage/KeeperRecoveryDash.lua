-- R41. Shared dash path; the server alone owns movement and catch decisions.
local Combat=require(script.Parent.KeeperCombat)
local Balance=require(script.Parent.RouteBalance83)
local M={AlertSeconds=.18,Speed=320,MinDuration=.12,MaxDuration=.20,CatchGrace=.40}
function M.Plan(stage,frame,playerPosition)
 local offset=Vector3.new(playerPosition.X-frame.Position.X,0,playerPosition.Z-frame.Position.Z)
 local distance=offset.Magnitude
 local travel=math.max(0,distance-Combat.Get(stage).Reach-4)
 if travel<.1 then return nil end -- Already close: do not jump onto or behind the thief.
 local goal=frame.Position+offset.Unit*travel
 return goal,M.MinDuration
end
function M.Sample(frame,goal,started,duration,now)
 local t=math.clamp((now-started)/duration,0,1)
 local ease=t*t*(3-2*t)
 local offset=goal-frame.Position
 local position=frame.Position+offset*ease
 return offset.Magnitude>.001 and CFrame.lookAt(position,position+offset)or frame,t>=1
end
function M.VisualFrame(model,now,fallback)
 if model:GetAttribute('GuardianBehavior')~='DASHING'
  or model:GetAttribute('KeeperDashToken')~=model:GetAttribute('GuardianLeaseToken')then return fallback end
 local from=model:GetAttribute('KeeperDashFrom');local goal=model:GetAttribute('KeeperDashTo')
 local started=model:GetAttribute('KeeperDashAt');local duration=model:GetAttribute('KeeperDashDuration')
 if typeof(from)~='CFrame'or typeof(goal)~='Vector3'or type(started)~='number'
  or type(duration)~='number'or duration<M.MinDuration or duration>M.MaxDuration then return fallback end
 return M.Sample(from,goal,started,duration,now)
end
return M
