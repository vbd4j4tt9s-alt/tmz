-- R80. Bounded continuous body sweeps, shared by the owning client and server guard.
local Motion=require(script.Parent.RunnerMotion)
local M={}
function M.Hull(character,humanoid,root)
    local scale=root.Size.Y/2
    local leg=humanoid.RigType==Enum.HumanoidRigType.R6 and character:FindFirstChild('Left Leg')
    local standing=root.Size.Y/2+humanoid.HipHeight+(leg and leg.Size.Y or 0)
    local step=math.max(.6,scale*.8)
    local height=math.max(root.Size.Y,standing+root.Size.Y*.75-step)
    return Vector3.new(math.max(1.5,root.Size.X*.9),height,math.max(1.1,root.Size.Z*1.2)),
        Vector3.new(0,height/2-standing+step,0)
end
function M.Cast(world,frame,size,offset,delta,params)
    local length=delta.Magnitude
    if length<.001 then return length,nil end
    if not Motion.Finite(length)then return 0,{BudgetExceeded=true}end
    local count=math.ceil(length/Motion.CastLength)
    if count>Motion.MaxCasts then return 0,{BudgetExceeded=true}end
    local direction=delta/length
    local traversed=0
    for _=1,count do
        local distance=math.min(Motion.CastLength,length-traversed)
        -- An upright hull is stable while turning; feet retain ordinary step clearance.
        local at=CFrame.new(frame.Position+offset+direction*traversed)
        local hit=world:Blockcast(at,size,direction*distance,params)
        if hit then return math.max(0,traversed+hit.Distance-Motion.Skin),hit end
        traversed=traversed+distance
    end
    return length,nil
end
function M.Slide(world,frame,size,offset,delta,params)
 local moved=Vector3.zero;local remaining=delta
 for _=1,3 do
  if remaining.Magnitude<.001 then break end
  local distance,hit=M.Cast(world,frame+moved,size,offset,remaining,params)
  if not hit then moved+=remaining;break end
  moved+=remaining.Unit*distance
  if not hit.Normal then break end
  remaining=remaining-remaining.Unit*distance
  remaining=remaining-hit.Normal*math.min(0,remaining:Dot(hit.Normal))
 end
 return moved
end
return M
