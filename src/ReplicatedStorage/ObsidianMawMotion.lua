-- Cosmetic hinged jaws; called by the existing 20 Hz client animation scheduler.
local Motion={}
local function move(part,frame,batch)if batch then batch:Set(part,frame)else part.CFrame=frame end end
function Motion.Angle(id,time,jaw)
 local h=19;for i=1,#tostring(id)do h=(h*31+string.byte(tostring(id),i))%997 end
 local phase=(time+h*.031+math.floor((jaw-1)/2)*2.4)%13
 if phase<.24 then return .96*(phase/.24)^2 end
 if phase<.62 then return .96 end
 if phase<2.05 then local t=(phase-.62)/1.43;return .96*(1-t*t*(3-2*t))end
 return .035*(1+math.sin(time*.65+math.floor((jaw-1)/2)))
end
function Motion.Capture(model,origin)
 local state={Groups={}}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p:GetAttribute('MawJaw')then
  local index=p:GetAttribute('MawJaw');local g=state.Groups[index]
  if not g then g={Pivot=origin:ToObjectSpace(p:GetAttribute('MawPivot')),Side=p:GetAttribute('MawSide'),Parts={}};g.Inverse=g.Pivot:Inverse();state.Groups[index]=g end
  table.insert(g.Parts,{Part=p,Frame=origin:ToObjectSpace(p.CFrame)})
 end end
 return state
end
function Motion.Step(state,origin,id,time,batch)
 local writes=0
 for index,g in pairs(state.Groups)do
  local angle=Motion.Angle(id,time,index)
  if g.LastAngle~=angle or g.LastOrigin~=origin then
   local transform=origin*g.Pivot*CFrame.Angles(0,0,g.Side*angle)*g.Inverse
   for _,p in ipairs(g.Parts)do if p.Part.Parent then move(p.Part,transform*p.Frame,batch);writes+=1 end end
   g.LastAngle=angle;g.LastOrigin=origin
  end
 end
 return writes
end
function Motion.Reset(state,origin,batch)
 if state then for _,g in pairs(state.Groups)do g.LastAngle=nil;g.LastOrigin=nil;for _,p in ipairs(g.Parts)do if p.Part.Parent then move(p.Part,origin*p.Frame,batch) end end end end
end
return Motion
