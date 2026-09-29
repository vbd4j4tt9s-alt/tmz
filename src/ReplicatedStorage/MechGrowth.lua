-- Timestamp-driven mechanical growth; reused by local detail and server fallback.
local Rules=require(script.Parent.PlantRules)
local Art=require(script.Parent.MechArt)
local M={}
function M.Capture(model,id,def,crop,origin,sockets)
 local state={Mech=true,Model=model,Id=id,Def=def,Origin=origin,Parts={},Buds={},Sprout={},Sockets=sockets,Projection=Art.Growth(id),Scale=crop.PlantScale or 1}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p.Transparency<1 then
  table.insert(state.Parts,{Part=p,Frame=p:GetAttribute('HologramFrame')or origin:ToObjectSpace(p.CFrame),Size=p.Size,Alpha=p.Transparency,Query=p.CanQuery,
   Group=p:GetAttribute('GrowthGroup')or 0,Fixed=p:GetAttribute('MechFixed')==true,GroupName=p:GetAttribute('MechGroup')or''})
 end end
 return state
end
function M.Apply(state,crop,now,progress)
 local body=progress(crop,state.Def,now);local fruit={};local ready={}
 for i=1,state.Def.FruitCount do local _,f=progress(crop,state.Def,now,i);fruit[i]=f;ready[i]=Rules.FruitReady(crop,i,now)end
 local projection=state.Projection
 for _,r in ipairs(state.Parts)do if r.Part.Parent then
  local p=r.Part;local factor=1;local visible=1;local pos=r.Frame.Position
  if not r.Fixed then
   if r.Group>0 then
    local f=fruit[r.Group];local anchor=state.Sockets[r.Group]*state.Scale
    factor=.25+.75*f;pos=anchor+(pos-anchor)*factor;visible=f
    if projection and state.Id=='HoloMelonSeed'then
     local reveal=math.clamp((r.Frame.Position.Y/state.Scale-projection.bottom)/(projection.top-projection.bottom),0,1)
     visible=f<=0 and 0 or math.clamp((f-reveal)*10+.12,0,1)
     if f>=1 then visible=1 end
     pos-=Vector3.new(0,(1-f)*.74*state.Scale,0)
    end
   elseif projection then
    if r.GroupName=='ProjectionRays'then visible=math.clamp(body*4,0,1)
    else
     factor=.25+.75*math.clamp(body*1.35,0,1)
     local anchor=Vector3.new(0,projection.anchor*state.Scale,0);pos=anchor+(pos-anchor)*factor
     local reveal=math.clamp((r.Frame.Position.Y/state.Scale-projection.bottom)/(projection.top-projection.bottom),0,1)
     visible=body<=0 and 0 or math.clamp((body*1.55-reveal)*6+.06,0,1)
    end
   else
    factor=.15+.85*math.clamp(body/.78,0,1);pos*=factor;visible=math.clamp(body*8,0,1)
   end
  end
  local hidden=r.Group>0 and Rules.IsPicked(crop,r.Group)
  local home=CFrame.new(pos)*r.Frame.Rotation
  p.Size=r.Size*factor;p.CFrame=state.Origin*home
  if p:GetAttribute('HologramFrame')then p:SetAttribute('HologramFrame',home)end
  p.Transparency=hidden and 1 or 1-(1-r.Alpha)*visible;p.CanCollide=false
  p.CanQuery=r.Group>0 and ready[r.Group]and r.Query or false
 end end
 state.Model:SetAttribute('VisualGrowth',body);state.Model:SetAttribute('VisualFruitGrowth',fruit[1]or 0)
 return body,fruit[1]or 0
end
return M
