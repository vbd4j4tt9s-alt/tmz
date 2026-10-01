local V=function(x,y,z)return{X=x,Y=y,Z=z}end
local src=[==========[-- R80. Bounded continuous body sweeps, shared by the owning client and server guard.
local Motion=require(script.Parent.RunnerMotion)
local M={}
function M.Hull(character,humanoid,root)
    local scale=root.Size.Y/2
    local leg=humanoid.RigType==Enum.HumanoidRigType.R6 and character:FindFirstChild('Left Leg')
    local standing=root.Size.Y/2+humanoid.HipHeight+(leg and leg.Size.Y or 0)
    -- R122: feet clear at least 1.1 studs (was 0.6-0.8), so 0.8-stud garden bed edges and similar low ledges are
    -- walked onto (the Humanoid steps up) instead of stopping the runner until they jump.
    local step=math.max(1.1,scale*1.1)
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
]==========]
src=src:gsub("local Motion=require%(script.Parent.RunnerMotion%)","local Motion={}")
local fn=loadstring(src);setfenv(fn,setmetatable({Vector3={new=V},Enum={HumanoidRigType={R6='R6',R15='R15'}},math=math},{__index=_G}));local M=fn()
local fails=0
for _,c in ipairs({{'R15 normal',2,2,nil},{'R15 small',1.4,1.2,nil},{'R15 big',3,3,nil},{'R6',2,0,2}})do
 local root={Size=V(2,c[2],1)};local hum={RigType=c[4]and'R6'or'R15',HipHeight=c[3]}
 local ch={FindFirstChild=function(_,n)if c[4]and n=='Left Leg'then return{Size=V(1,c[4],1)}end end}
 local size,off=M.Hull(ch,hum,root)
 local standing=c[2]/2+c[3]+(c[4]or 0)
 local bottom=off.Y-size.Y/2+standing -- above the feet
 local top=bottom+size.Y
 print(c[1],('clears %.2f studs, hull top %.2f above feet'):format(bottom,top))
 if bottom<=0.85 then fails+=1;print('FAIL: 0.8 edge still blocks')end
 if top<standing+0.5 then fails+=1;print('FAIL: hull no longer covers the body')end
end
print(fails==0 and'all ok'or fails..' failures')
